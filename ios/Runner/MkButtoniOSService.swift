import Foundation
import UserNotifications
import CoreBluetooth
import MKBeaconXDButton

protocol MkButtoniOSChannelDelegate: AnyObject {
    func onDeviceScanned(mac: String, name: String, rssi: Int)
    func onConnectionStatus(connected: Bool)
    func onTaskResult(data: [String: Any])
    func onButtonPress(pressType: String)
}

class MkButtoniOSService: NSObject {

    static let shared = MkButtoniOSService()

    private static let activeBackgroundMacKey = "mk_active_bg_mac"

    weak var channelDelegate: MkButtoniOSChannelDelegate?

    private struct DeviceConfig {
        let mac: String
        let password: String
        let clickType: String
        let buttonAction: String
        let deviceName: String
    }

    private var deviceConfig: DeviceConfig?
    private var scannedPeripherals: [String: CBPeripheral] = [:]
    private var peripheralUUIDToMac: [String: String] = [:]
    private var isInitialized = false
    private var isConnected = false
    private var isConnecting = false
    private var isBackgroundMode = false
    private var restorationPressWindow = false
    private var reconnectAttempts = 0
    private var reconnectWorkItem: DispatchWorkItem?
    private var disconnectNotifyWork: DispatchWorkItem?
    private var lastClickTime: TimeInterval = 0
    private var lastAdvTriggerCount: String = ""

    private override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onConnectStatusChanged(_:)),
            name: .mk_bxd_peripheralConnectStateChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onLongConnectionModeData(_:)),
            name: NSNotification.Name("mk_bxd_receiveLongConnectionModeDataNotification"),
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - State restoration

    func configureStateRestoration(relaunchedForBluetooth: Bool) {
        let identifier = Bundle.main.bundleIdentifier ?? "cl.mistatas.amaia.want"
        MKBXDCentralManager.enableStateRestoration(withIdentifier: identifier)
        MKBXDCentralManager.shared().restorationDelegate = self

        guard relaunchedForBluetooth else { return }
        NSLog("[MK] launched from state restoration")

        reloadActiveConfigFromDefaults()
        guard deviceConfig != nil else { return }

        isBackgroundMode = true
        isInitialized = false
        restorationPressWindow = true
        reconnectAttempts = 0
        MKBXDCentralManager.shared().eventDelegate = self
        MKBXDCentralManager.shared().delegate = self
        scheduleReconnect()
    }

    private func reloadActiveConfigFromDefaults() {
        let d = UserDefaults.standard
        guard let mac = d.string(forKey: Self.activeBackgroundMacKey), !mac.isEmpty else {
            NSLog("[MK] reloadActiveConfigFromDefaults: no active mac")
            return
        }
        deviceConfig = DeviceConfig(
            mac: mac,
            password:     d.string(forKey: "\(mac)_password") ?? "",
            clickType:    d.string(forKey: "\(mac)_clickType") ?? "single",
            buttonAction: d.string(forKey: "\(mac)_buttonAction") ?? "",
            deviceName:   d.string(forKey: "\(mac)_deviceName") ?? "MK Button"
        )
        NSLog("[MK] reloadActiveConfigFromDefaults: restored config for mac=\(mac)")
    }

    // MARK: - Foreground

    func startScan() {
        isBackgroundMode = false
        MKBXDCentralManager.shared().delegate = self
        MKBXDCentralManager.shared().startScan()
    }

    func stopScan() {
        MKBXDCentralManager.shared().stopScan()
    }

    func connectForeground(mac: String, password: String) {
        guard let peripheral = scannedPeripherals[mac] else {
            NSLog("[MK] connectForeground: peripheral not found for mac=\(mac)")
            DispatchQueue.main.async { [weak self] in
                self?.channelDelegate?.onConnectionStatus(connected: false)
            }
            return
        }
        NSLog("[MK] connectForeground: starting connection mac=\(mac)")
        isConnecting = true
        MKBXDCentralManager.shared().connectPeripheral(
            peripheral,
            password: password,
            sucBlock: { [weak self] _ in
                NSLog("[MK] connectForeground sucBlock: fired, self=\(self != nil)")
                guard let strongSelf = self else {
                    NSLog("[MK] connectForeground sucBlock: self is nil!")
                    return
                }
                DispatchQueue.main.async {
                    NSLog("[MK] connectForeground sucBlock: main async running")
                    strongSelf.isConnecting = false
                    strongSelf.isConnected = true
                    strongSelf.channelDelegate?.onConnectionStatus(connected: true)
                    strongSelf.enableNotificationsAfterDelay()
                }
            },
            failedBlock: { [weak self] error in
                NSLog("[MK] connectForeground failedBlock: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.isConnecting = false
                    self?.channelDelegate?.onConnectionStatus(connected: false)
                }
            }
        )
    }

    func disconnectForeground() {
        isConnected = false
        isConnecting = false
        isInitialized = false
        disconnectNotifyWork?.cancel()
        disconnectNotifyWork = nil
        MKBXDCentralManager.shared().disconnect()
    }

    func readBattery() {
        MKBXDInterface.bxd_readDeviceBatteryPercent(
            sucBlock: { [weak self] returnData in
                NSLog("[MK] readBattery sucBlock returnData: \(String(describing: returnData))")
                guard
                    let result = (returnData as? [String: Any])?["result"] as? [String: Any],
                    let percentStr = result["percent"] as? String,
                    let percent = Int(percentStr)
                else {
                    NSLog("[MK] readBattery guard failed, raw: \(String(describing: returnData))")
                    return
                }
                NSLog("[MK] readBattery percent: \(percent)")
                if let mac = self?.deviceConfig?.mac {
                    UserDefaults.standard.set(percent, forKey: "\(mac)_batteryPercent")
                }
                DispatchQueue.main.async { [weak self] in
                    self?.channelDelegate?.onTaskResult(data: ["type": "battery", "batteryPercent": percent])
                }
            },
            failedBlock: { error in
                NSLog("[MK] readBattery failedBlock: \(error.localizedDescription)")
            }
        )
    }

    // MARK: - Background service

    func startBackgroundService(
        mac: String,
        password: String,
        clickType: String,
        buttonAction: String,
        deviceName: String
    ) {
        let d = UserDefaults.standard
        d.set(password,     forKey: "\(mac)_password")
        d.set(clickType,    forKey: "\(mac)_clickType")
        d.set(buttonAction, forKey: "\(mac)_buttonAction")
        d.set(deviceName,   forKey: "\(mac)_deviceName")
        d.set(mac,          forKey: Self.activeBackgroundMacKey)

        let config = DeviceConfig(
            mac: mac,
            password: password,
            clickType: clickType,
            buttonAction: buttonAction,
            deviceName: deviceName
        )

        if isBackgroundMode, let existing = deviceConfig, existing.mac == mac {
            deviceConfig = config
            MKBXDCentralManager.shared().eventDelegate = self
            return
        }

        deviceConfig = config
        MKBXDCentralManager.shared().eventDelegate = self

        if isConnected {
            isBackgroundMode = true
            return
        }

        isBackgroundMode = true
        isInitialized = false
        reconnectAttempts = 0

        MKBXDCentralManager.shared().delegate = self
        MKBXDCentralManager.shared().startScan()

        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            guard let self = self, !self.isConnected else { return }
            MKBXDCentralManager.shared().stopScan()
            self.scheduleReconnect()
        }
    }

    func stopBackgroundService() {
        isBackgroundMode = false
        isInitialized = false
        restorationPressWindow = false
        isConnected = false
        isConnecting = false
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
        disconnectNotifyWork?.cancel()
        disconnectNotifyWork = nil
        MKBXDCentralManager.shared().eventDelegate = nil
        MKBXDCentralManager.shared().disconnect()
        deviceConfig = nil
        UserDefaults.standard.removeObject(forKey: Self.activeBackgroundMacKey)
    }

    func removeDevice(mac: String, clearConfig: Bool) {
        stopBackgroundService()
        guard clearConfig else { return }
        let d = UserDefaults.standard
        for suffix in ["_password", "_clickType", "_buttonAction", "_deviceName", "_batteryPercent"] {
            d.removeObject(forKey: "\(mac)\(suffix)")
        }
    }

    func getPendingLogs() -> String {
        let d = UserDefaults.standard
        let logs = (d.array(forKey: "mk_pending_logs") as? [[String: Any]]) ?? []
        d.removeObject(forKey: "mk_pending_logs")
        guard
            let data = try? JSONSerialization.data(withJSONObject: logs),
            let json = String(data: data, encoding: .utf8)
        else { return "[]" }
        return json
    }

    // MARK: - Private

    private func enableNotificationsAfterDelay() {
        NSLog("[MK] enableNotificationsAfterDelay: scheduled")
        restorationPressWindow = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let self = self, self.isConnected else {
                NSLog("[MK] enableNotificationsAfterDelay: skipped isConnected=\(self?.isConnected ?? false)")
                return
            }
            NSLog("[MK] enableNotificationsAfterDelay: enabling notifications")
            let longConResult = MKBXDCentralManager.shared().notifyLongConModeData(true)
            NSLog("[MK] notifyLongConModeData result: \(longConResult)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self, self.isConnected else { return }
                self.isInitialized = true
                NSLog("[MK] enableNotificationsAfterDelay: isInitialized = true, resuming scan for ADV events")
                MKBXDCentralManager.shared().delegate = self
                MKBXDCentralManager.shared().startScan()
                self.readBattery()
                self.configureDeviceForAlarmMode()
            }
        }
    }

    private func configureDeviceForAlarmMode() {
        guard let config = deviceConfig else { return }
        let channelType: MKBXDChannelAlarmType
        switch config.clickType {
        case "double": channelType = .double
        case "long":   channelType = .long
        default:       channelType = .single
        }
        MKBXDInterface.bxd_configChannelContentAlarmInfo(channelType, sucBlock: {
            NSLog("[MK] configChannelContentAlarmInfo success")
            MKBXDInterface.bxd_configStayAdvertising(beforeTriggered: channelType, isOn: true, sucBlock: {
                NSLog("[MK] configStayAdvertisingBeforeTriggered success")
            }, failedBlock: { error in
                NSLog("[MK] configStayAdvertisingBeforeTriggered failed: \(error.localizedDescription)")
            })
        }, failedBlock: { error in
            NSLog("[MK] configChannelContentAlarmInfo failed: \(error.localizedDescription)")
        })
    }

    private func scheduleReconnect() {
        guard isBackgroundMode, deviceConfig != nil, reconnectAttempts < 10 else { return }
        reconnectAttempts += 1
        let delay = min(5.0 * pow(2.0, Double(reconnectAttempts - 1)), 300.0)

        reconnectWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self, self.isBackgroundMode, !self.isConnected else { return }
            MKBXDCentralManager.shared().startScan()
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
                guard let self = self, self.isBackgroundMode, !self.isConnected else { return }
                MKBXDCentralManager.shared().stopScan()
                self.scheduleReconnect()
            }
        }
        reconnectWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func handleButtonPress(alarmType: Int) {
        NSLog("[MK] handleButtonPress alarmType=\(alarmType) isInitialized=\(isInitialized) restorationWindow=\(restorationPressWindow) isBackgroundMode=\(isBackgroundMode) deviceConfig=\(deviceConfig != nil)")
        guard isInitialized || restorationPressWindow, let config = deviceConfig else {
            NSLog("[MK] handleButtonPress blocked: isInitialized=\(isInitialized) restorationWindow=\(restorationPressWindow) deviceConfig=\(deviceConfig != nil)")
            return
        }

        let now = Date().timeIntervalSince1970
        guard now - lastClickTime > 2.0 else {
            NSLog("[MK] handleButtonPress debounced")
            return
        }

        let pressType: String
        switch alarmType {
        case 0: pressType = "single"
        case 1: pressType = "double"
        case 2: pressType = "long"
        default: pressType = "single"
        }

        NSLog("[MK] handleButtonPress pressType=\(pressType) config.clickType=\(config.clickType)")
        guard pressType == config.clickType else {
            NSLog("[MK] handleButtonPress ignored: pressType mismatch")
            return
        }
        lastClickTime = now

        savePressLog(config: config)
        channelDelegate?.onButtonPress(pressType: pressType)

        if isBackgroundMode {
            callEmergencyApi(config: config)
        }
    }

    private func callEmergencyApi(config: DeviceConfig) {
        let d = UserDefaults.standard
        let phone     = d.string(forKey: "flutter.phone") ?? ""
        let geo       = d.string(forKey: "flutter.geo") ?? "SIN_GEO"
        let battery   = d.integer(forKey: "\(config.mac)_batteryPercent")
        let apiUrlStr = d.string(forKey: "flutter.URL_SMS_IOS") ?? ""

        NSLog("[MK] callEmergencyApi phone=\(phone) apiUrl=\(apiUrlStr) geo=\(geo) battery=\(battery)")
        guard !apiUrlStr.isEmpty, let apiUrl = URL(string: apiUrlStr) else {
            NSLog("[MK] callEmergencyApi blocked: apiUrl empty or invalid")
            return
        }

        let geoEncoded = Data(geo.utf8).base64EncodedString()
        let payload: [String: Any] = [
            "phone":   phone,
            "body":    "ALERTAMOVIL ORIGIN=MK-BUTTON",
            "geo":     geoEncoded,
            "BATTERY": battery
        ]

        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }

        var request = URLRequest(url: apiUrl)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        URLSession.shared.dataTask(with: request) { [weak self] _, _, _ in
            DispatchQueue.main.async {
                self?.showNotification(deviceName: config.deviceName)
            }
        }.resume()
    }

    private func showNotification(deviceName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Alerta enviada"
        content.body  = "SMS de emergencia enviado desde \(deviceName)"
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    private func savePressLog(config: DeviceConfig) {
        let d = UserDefaults.standard
        let battery = d.integer(forKey: "\(config.mac)_batteryPercent")
        var entry: [String: Any] = [
            "mac":        config.mac,
            "deviceName": config.deviceName,
            "pressedAt":  Int64(Date().timeIntervalSince1970 * 1000)
        ]
        if battery > 0 { entry["batteryPercent"] = battery }

        var logs = (d.array(forKey: "mk_pending_logs") as? [[String: Any]]) ?? []
        logs.append(entry)
        d.set(logs, forKey: "mk_pending_logs")
    }

    @objc private func onConnectStatusChanged(_ notification: Notification) {
        let connected = MKBXDCentralManager.shared().peripheral() != nil
        NSLog("[MK] onConnectStatusChanged: connected=\(connected) isConnected=\(isConnected) isInitialized=\(isInitialized)")
        if connected && !isConnected {
            isConnected = true
            reconnectAttempts = 0
            reconnectWorkItem?.cancel()
            reconnectWorkItem = nil
            disconnectNotifyWork?.cancel()
            disconnectNotifyWork = nil
            NSLog("[MK] onConnectStatusChanged: connected, cancelled pending disconnect notify")
            if isBackgroundMode {
                enableNotificationsAfterDelay()
            }
        } else if !connected && isConnected {
            isConnected = false
            isConnecting = false
            lastAdvTriggerCount = ""
            NSLog("[MK] onConnectStatusChanged: disconnect detected, isInitialized stays=\(isInitialized), scheduling dart notify in 2s")
            MKBXDCentralManager.shared().stopScan()
            if isBackgroundMode {
                scheduleReconnect()
            }
            disconnectNotifyWork?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self = self, !self.isConnected else {
                    NSLog("[MK] disconnectNotifyWork: cancelled (reconnected)")
                    return
                }
                NSLog("[MK] disconnectNotifyWork: notifying dart disconnect")
                self.channelDelegate?.onConnectionStatus(connected: false)
            }
            disconnectNotifyWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: work)
        }
    }

    @objc private func onLongConnectionModeData(_ notification: Notification) {
        let count = (notification.userInfo?["count"] as? String) ?? ""
        NSLog("[MK] onLongConnectionModeData: count=\(count) isInitialized=\(isInitialized) restorationWindow=\(restorationPressWindow) deviceConfig=\(deviceConfig != nil)")
        guard !count.isEmpty, isInitialized || restorationPressWindow, let config = deviceConfig else { return }
        let alarmType: Int
        switch config.clickType {
        case "double": alarmType = 1
        case "long":   alarmType = 2
        default:       alarmType = 0
        }
        handleButtonPress(alarmType: alarmType)
    }
}

// MARK: - mk_bxd_centralManagerScanDelegate

extension MkButtoniOSService: mk_bxd_centralManagerScanDelegate {

    func mk_bxd_receiveAdvData(_ deviceList: [MKBXDBaseAdvModel]) {
        for model in deviceList {
            let peripheral = model.peripheral
            let name = peripheral.name ?? "MK Button"
            let peripheralUUID = peripheral.identifier.uuidString

            var mac: String
            if let respondModel = model as? MKBXDAdvRespondDataModel,
               !respondModel.macAddress.isEmpty {
                mac = respondModel.macAddress
                peripheralUUIDToMac[peripheralUUID] = mac
            } else {
                mac = peripheralUUIDToMac[peripheralUUID] ?? peripheralUUID
            }

            scannedPeripherals[mac] = peripheral

            if let alarmModel = model as? MKBXDAdvDataModel,
               alarmModel.triggerStatus != 0,
               let config = deviceConfig,
               config.mac == mac {
                let count = alarmModel.triggerCount ?? ""
                if count != lastAdvTriggerCount {
                    lastAdvTriggerCount = count
                    NSLog("[MK] ADV alarm: alarmType=\(alarmModel.alarmType.rawValue) count=\(count) mac=\(mac)")
                    let alarmType = Int(alarmModel.alarmType.rawValue)
                    DispatchQueue.main.async { [weak self] in
                        self?.handleButtonPress(alarmType: alarmType)
                    }
                }
                continue
            }

            if !isBackgroundMode {
                let capturedMac = mac
                let capturedName = name
                let capturedRssi = model.rssi.intValue
                DispatchQueue.main.async { [weak self] in
                    self?.channelDelegate?.onDeviceScanned(
                        mac: capturedMac,
                        name: capturedName,
                        rssi: capturedRssi
                    )
                }
            } else if let config = deviceConfig, config.mac == mac, !isConnected, !isConnecting {
                isConnecting = true
                MKBXDCentralManager.shared().stopScan()
                MKBXDCentralManager.shared().connectPeripheral(
                    peripheral,
                    password: config.password,
                    sucBlock: { [weak self] _ in
                        self?.isConnecting = false
                    },
                    failedBlock: { [weak self] _ in
                        self?.isConnecting = false
                        self?.scheduleReconnect()
                    }
                )
            }
        }
    }
}

// MARK: - mk_bxd_centralManagerAlarmEventDelegate

extension MkButtoniOSService: mk_bxd_centralManagerAlarmEventDelegate {

    func mk_bxd_receiveAlarmEventData(_ contentData: [AnyHashable: Any]) {
        NSLog("[MK] receiveAlarmEventData: \(contentData)")
        guard let alarmTypeRaw = contentData["alarmType"],
              let alarmType = Int("\(alarmTypeRaw)")
        else {
            NSLog("[MK] receiveAlarmEventData: no alarmType in data")
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.handleButtonPress(alarmType: alarmType)
        }
    }
}

// MARK: - mk_bxd_stateRestorationDelegate

extension MkButtoniOSService: mk_bxd_stateRestorationDelegate {

    @objc func mk_bxd_didRestoreState(withPeripherals peripherals: [CBPeripheral]) {
        NSLog("[MK] didRestoreState: \(peripherals.count) peripherals")

        if deviceConfig == nil {
            reloadActiveConfigFromDefaults()
        }
        guard let config = deviceConfig else {
            NSLog("[MK] didRestoreState: no deviceConfig, ignoring")
            return
        }

        isBackgroundMode = true
        isInitialized = false
        MKBXDCentralManager.shared().eventDelegate = self
        MKBXDCentralManager.shared().delegate = self

        guard let peripheral = peripherals.first else {
            NSLog("[MK] didRestoreState: no peripheral restored, scheduling reconnect")
            scheduleReconnect()
            return
        }

        scannedPeripherals[config.mac] = peripheral
        peripheralUUIDToMac[peripheral.identifier.uuidString] = config.mac

        if peripheral.state == .connected {
            NSLog("[MK] didRestoreState: peripheral already connected, re-auth")
        }

        isConnecting = true
        MKBXDCentralManager.shared().connectPeripheral(
            peripheral,
            password: config.password,
            sucBlock: { [weak self] _ in
                NSLog("[MK] didRestoreState: re-auth success")
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.isConnecting = false
                    self.isConnected = true
                    self.reconnectAttempts = 0
                    self.enableNotificationsAfterDelay()
                }
            },
            failedBlock: { [weak self] error in
                NSLog("[MK] didRestoreState: re-auth failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.isConnecting = false
                    self?.scheduleReconnect()
                }
            }
        )
    }
}
