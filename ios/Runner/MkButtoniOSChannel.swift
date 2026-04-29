import Flutter
import Foundation
import UserNotifications

class MkButtoniOSChannel: NSObject, MkButtoniOSChannelDelegate {

    static let channelName = "com.example.app/mk_button"

    private let channel: FlutterMethodChannel
    private let service = MkButtoniOSService.shared

    init(channel: FlutterMethodChannel) {
        self.channel = channel
        super.init()
        service.channelDelegate = self
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]

        switch call.method {

        case "startScan":
            service.startScan()
            result(nil)

        case "stopScan":
            service.stopScan()
            result(nil)

        case "prepareConnect":
            result(nil)

        case "connect":
            let mac      = args["mac"] as? String ?? ""
            let password = args["password"] as? String ?? "123456"
            service.connectForeground(mac: mac, password: password)
            result(nil)

        case "disconnect":
            service.disconnectForeground()
            result(nil)

        case "readBattery":
            NSLog("[MK] channel: readBattery called")
            service.readBattery()
            result(nil)

        case "readDeviceInfo":
            result(nil)

        case "startBackgroundService":
            let mac          = args["mac"] as? String ?? ""
            let password     = args["password"] as? String ?? "Moko4321"
            let clickType    = args["clickType"] as? String ?? "single"
            let buttonAction = args["buttonAction"] as? String ?? "open_app"
            let deviceName   = args["deviceName"] as? String ?? "MK Button"
            NSLog("[MK] channel: startBackgroundService mac=\(mac) clickType=\(clickType)")
            service.startBackgroundService(
                mac: mac,
                password: password,
                clickType: clickType,
                buttonAction: buttonAction,
                deviceName: deviceName
            )
            result(nil)

        case "stopBackgroundService":
            service.stopBackgroundService()
            result(nil)

        case "removeDeviceFromBackgroundService":
            let mac         = args["mac"] as? String ?? ""
            let clearConfig = args["clearConfig"] as? Bool ?? false
            service.removeDevice(mac: mac, clearConfig: clearConfig)
            result(nil)

        case "getPendingLogs":
            result(service.getPendingLogs())

        case "checkPermissions":
            checkPermissions(result: result)

        case "requestNotificationPermission":
            UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            ) { _, _ in
                DispatchQueue.main.async { result(nil) }
            }

        case "requestBatteryOptimization",
             "requestOverlayPermission",
             "triggerBuzzer",
             "stopBuzzer",
             "setAdvInterval",
             "setTxPower",
             "setDeviceName",
             "changePassword",
             "resetDevice",
             "enableButtonNotify",
             "executeEmergencyAction":
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func checkPermissions(result: @escaping FlutterResult) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                result([
                    "notificationPermission":      settings.authorizationStatus == .authorized,
                    "batteryOptimizationDisabled": true,
                    "overlayPermission":           true,
                ])
            }
        }
    }

    // MARK: - MkButtoniOSChannelDelegate

    func onDeviceScanned(mac: String, name: String, rssi: Int) {
        channel.invokeMethod("onDeviceScanned", arguments: [
            "mac":  mac,
            "name": name,
            "rssi": rssi,
        ])
    }

    func onConnectionStatus(connected: Bool) {
        channel.invokeMethod("onConnectionStatus", arguments: ["connected": connected])
    }

    func onTaskResult(data: [String: Any]) {
        channel.invokeMethod("onTaskResult", arguments: data)
    }

    func onButtonPress(pressType: String) {
        channel.invokeMethod("onButtonPress", arguments: ["type": pressType])
    }
}
