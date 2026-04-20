import 'dart:async';
import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/ble_button_repository.dart';
import '../data/device_storage.dart';
import '../domain/button_press_log.dart';
import '../domain/models.dart';
import '../domain/saved_device.dart';

part 'ble_button_event.dart';
part 'ble_button_state.dart';

class BleButtonBloc extends Bloc<BleButtonEvent, BleButtonState> {
  BleButtonBloc({required BleButtonRepository repository})
      : _repo = repository,
        super(const BleButtonInitial()) {
    on<ScanStarted>(_onScanStarted);
    on<ScanStopped>(_onScanStopped);
    on<DeviceConnectRequested>(_onDeviceConnectRequested);
    on<DeviceDisconnectRequested>(_onDeviceDisconnectRequested);
    on<BatteryReadRequested>(_onBatteryReadRequested);
    on<DeviceInfoReadRequested>(_onDeviceInfoReadRequested);
    on<AdvIntervalUpdateRequested>(_onAdvIntervalUpdateRequested);
    on<TxPowerUpdateRequested>(_onTxPowerUpdateRequested);
    on<DeviceNameUpdateRequested>(_onDeviceNameUpdateRequested);
    on<PasswordUpdateRequested>(_onPasswordUpdateRequested);
    on<ButtonNotifyToggled>(_onButtonNotifyToggled);
    on<DeviceResetRequested>(_onDeviceResetRequested);
    on<SavedDevicesLoadRequested>(_onSavedDevicesLoadRequested);
    on<SavedDeviceDeleteRequested>(_onSavedDeviceDeleteRequested);
    on<AutoReconnectRequested>(_onAutoReconnectRequested);
    on<BuzzerTriggered>(_onBuzzerTriggered);
    on<BuzzerStopped>(_onBuzzerStopped);
    on<_DeviceScanned>(_onDeviceScanned);
    on<_ConnectionStatusChanged>(_onConnectionStatusChanged);
    on<_ButtonPressReceived>(_onButtonPressReceived);
    on<_TaskResultReceived>(_onTaskResultReceived);

    _subscribeToNativeStreams();
  }

  final BleButtonRepository _repo;

  StreamSubscription<ScannedDevice>? _scanSub;
  StreamSubscription<bool>? _connectionSub;
  StreamSubscription<String>? _buttonSub;
  StreamSubscription<Map<String, dynamic>>? _taskSub;

  void _subscribeToNativeStreams() {
    _scanSub = _repo.onDeviceScanned
        .listen((device) => add(_DeviceScanned(device: device)));
    _connectionSub = _repo.onConnectionStatusChanged.listen(
        (connected) => add(_ConnectionStatusChanged(connected: connected)));
    _buttonSub = _repo.onButtonPress
        .listen((type) => add(_ButtonPressReceived(pressType: type)));
    _taskSub = _repo.onTaskResult
        .listen((result) => add(_TaskResultReceived(result: result)));
  }

  Future<void> _onScanStarted(
    ScanStarted event,
    Emitter<BleButtonState> emit,
  ) async {
    try {
      final savedDevices = await DeviceStorage.instance.getAllDevices();

      if (savedDevices.isNotEmpty) {
        emit(BleButtonScanning(savedDevices: savedDevices));
        await _ensureAllDevicesInBackground(savedDevices);
        return;
      }

      final bluetoothScanStatus = await Permission.bluetoothScan.request();
      final bluetoothConnectStatus =
          await Permission.bluetoothConnect.request();

      if (!bluetoothScanStatus.isGranted || !bluetoothConnectStatus.isGranted) {
        emit(const BleButtonError(
          message:
              'Se requieren permisos de Bluetooth para escanear dispositivos',
        ));
        return;
      }

      final locationStatus = await Permission.location.request();
      if (!locationStatus.isGranted) {
        emit(const BleButtonError(
          message:
              'Se requiere permiso de ubicación para escanear dispositivos BLE',
        ));
        return;
      }

      await _repo.startScan();
      emit(BleButtonScanning(savedDevices: const []));
      await _ensureAllDevicesInBackground(savedDevices);
    } on BleButtonException catch (e) {
      emit(BleButtonError(message: e.message));
    }
  }

  Future<void> _onScanStopped(
    ScanStopped event,
    Emitter<BleButtonState> emit,
  ) async {
    await _repo.stopScan();
    emit(const BleButtonDisconnected());
  }

  Future<void> _onDeviceConnectRequested(
    DeviceConnectRequested event,
    Emitter<BleButtonState> emit,
  ) async {
    await _repo.stopScan();
    emit(BleButtonConnecting(mac: event.mac));
    try {
      try {
        await _repo.prepareConnect(event.mac);
        await _repo.removeDeviceFromBackgroundService(event.mac);
        await Future.delayed(const Duration(milliseconds: 800));
      } catch (_) {}

      await _repo.connect(event.mac, password: event.password ?? '123456');

      String deviceName = 'MK Button';
      if (state is BleButtonScanning) {
        final scannedDevice = (state as BleButtonScanning).devices.firstWhere(
            (d) => d.mac == event.mac,
            orElse: () =>
                ScannedDevice(mac: event.mac, name: deviceName, rssi: -100));
        deviceName = scannedDevice.name;
      }

      final savedDevice = SavedDevice(
        mac: event.mac,
        name: deviceName,
        password: event.password ?? '123456',
        lastConnectedAt: DateTime.now(),
      );

      await DeviceStorage.instance.saveDevice(savedDevice);
    } on BleButtonException catch (e) {
      emit(BleButtonError(message: e.message));
    }
  }

  Future<void> _onDeviceDisconnectRequested(
    DeviceDisconnectRequested event,
    Emitter<BleButtonState> emit,
  ) async {
    await _repo.disconnect();
  }

  Future<void> _onBatteryReadRequested(
    BatteryReadRequested event,
    Emitter<BleButtonState> emit,
  ) async {

    await _sendCommand(emit, () => _repo.readBattery());
  }

  Future<void> _onDeviceInfoReadRequested(
    DeviceInfoReadRequested event,
    Emitter<BleButtonState> emit,
  ) async {

    if (state is BleButtonConnected) {

    }
  }

  Future<void> _onAdvIntervalUpdateRequested(
    AdvIntervalUpdateRequested event,
    Emitter<BleButtonState> emit,
  ) async {
    await _sendCommand(emit, () => _repo.setAdvInterval(event.intervalMs));
  }

  Future<void> _onTxPowerUpdateRequested(
    TxPowerUpdateRequested event,
    Emitter<BleButtonState> emit,
  ) async {
    await _sendCommand(emit, () => _repo.setTxPower(event.txPower));
  }

  Future<void> _onDeviceNameUpdateRequested(
    DeviceNameUpdateRequested event,
    Emitter<BleButtonState> emit,
  ) async {
    await _sendCommand(emit, () => _repo.setDeviceName(event.name));
  }

  Future<void> _onPasswordUpdateRequested(
    PasswordUpdateRequested event,
    Emitter<BleButtonState> emit,
  ) async {
    await _sendCommand(
      emit,
      () => _repo.changePassword(event.oldPassword, event.newPassword),
    );
  }

  Future<void> _onButtonNotifyToggled(
    ButtonNotifyToggled event,
    Emitter<BleButtonState> emit,
  ) async {
    await _sendCommand(
      emit,
      () => _repo.enableButtonNotify(enable: event.enable),
    );
  }

  Future<void> _onDeviceResetRequested(
    DeviceResetRequested event,
    Emitter<BleButtonState> emit,
  ) async {
    await _sendCommand(emit, _repo.resetDevice);
  }

  void _onDeviceScanned(_DeviceScanned event, Emitter<BleButtonState> emit) {
    print(
        '[BLE] Device scanned: ${event.device.name} (${event.device.mac}) RSSI: ${event.device.rssi}');
    if (state is BleButtonScanning) {
      final current = state as BleButtonScanning;
      final devices = List<ScannedDevice>.from(current.devices);
      final index = devices.indexWhere((d) => d.mac == event.device.mac);
      if (index >= 0) {
        devices[index] = event.device;
      } else {
        devices.add(event.device);
      }
      print('[BLE] Total devices in list: ${devices.length}');
      emit(current.copyWith(devices: devices));
    }
  }

  void _onConnectionStatusChanged(
    _ConnectionStatusChanged event,
    Emitter<BleButtonState> emit,
  ) async {
    if (event.connected) {
      final mac = state is BleButtonConnecting
          ? (state as BleButtonConnecting).mac
          : '';

      if (mac.isEmpty) return;

      await DeviceStorage.instance.updateLastConnected(mac);
      final savedDevice = await DeviceStorage.instance.getDeviceByMac(mac);

      if (savedDevice != null && savedDevice.clickToOpenApp != 'disabled') {
        try {
          await _startDeviceInBackground(savedDevice);
        } catch (_) {}
      }

      emit(BleButtonConnected(
        mac: mac,
        isLoading: false,
        deviceInfo: savedDevice != null
            ? DeviceInfo(
                deviceName: savedDevice.name,
                firmwareVersion: savedDevice.firmwareVersion ?? '',
                hardwareVersion: savedDevice.hardwareVersion ?? '',
                batteryPercent: savedDevice.batteryPercent ?? 0,
                advIntervalMs: savedDevice.advIntervalMs ?? 0,
                txPower: savedDevice.txPower ?? 0,
                isPasswordEnabled: savedDevice.isPasswordEnabled ?? false,
              )
            : null,
      ));
    } else {
      final mac = state is BleButtonConnected
          ? (state as BleButtonConnected).mac
          : null;

      if (mac != null && mac.isNotEmpty) {
        final device = await DeviceStorage.instance.getDeviceByMac(mac);
        if (device != null && device.clickToOpenApp != 'disabled') {
          try {
            await _startDeviceInBackground(device);
          } catch (e) {
            print('Failed to re-add device to background service: $e');
          }
        }
      }

      emit(const BleButtonDisconnected());
    }
  }

  void _onButtonPressReceived(
    _ButtonPressReceived event,
    Emitter<BleButtonState> emit,
  ) async {
    if (state is BleButtonConnected) {
      final current = state as BleButtonConnected;

      await DeviceStorage.instance.incrementClickCount(
        current.mac,
        event.pressType,
      );

      final savedDevice =
          await DeviceStorage.instance.getDeviceByMac(current.mac);
      if (savedDevice != null &&
          const ['call', 'sms', 'sms_and_call']
              .contains(savedDevice.buttonAction) &&
          event.pressType == savedDevice.clickToOpenApp) {
        await DeviceStorage.instance.insertPressLog(ButtonPressLog(
          mac: current.mac,
          deviceName: current.deviceInfo?.deviceName?.isNotEmpty == true
              ? current.deviceInfo!.deviceName
              : savedDevice.name,
          pressedAt: DateTime.now(),
          batteryPercent: current.deviceInfo?.batteryPercent,
        ));
      }

      emit(current.copyWith(
        lastButtonPress: ButtonPressEvent(
          pressType: event.pressType,
          timestamp: DateTime.now(),
        ),
      ));
    }
  }

  void _onTaskResultReceived(
    _TaskResultReceived event,
    Emitter<BleButtonState> emit,
  ) async {
    if (state is BleButtonConnected) {
      final current = state as BleButtonConnected;
      final result = event.result;

      if (result.containsKey('batteryPercent') ||
          result.containsKey('deviceName')) {
        final info = DeviceInfo.fromMap({
          ...?current.deviceInfo?.toMap(),
          ...result,
        });

        await DeviceStorage.instance.updateDeviceInfo(current.mac, result);

        emit(current.copyWith(deviceInfo: info, isLoading: false));
      } else {
        emit(current.copyWith(isLoading: false));
      }
    }
  }

  Future<void> _sendCommand(
    Emitter<BleButtonState> emit,
    Future<void> Function() command,
  ) async {
    if (state is! BleButtonConnected) return;
    final current = state as BleButtonConnected;
    emit(current.copyWith(isLoading: true, clearError: true));
    try {
      await command();

      if (state is BleButtonConnected) {
        emit((state as BleButtonConnected).copyWith(isLoading: false));
      }
    } on BleButtonException catch (e) {
      emit(current.copyWith(isLoading: false, errorMessage: e.message));
    }
  }

  Future<void> _onSavedDevicesLoadRequested(
    SavedDevicesLoadRequested event,
    Emitter<BleButtonState> emit,
  ) async {
    final savedDevices = await DeviceStorage.instance.getAllDevices();

    if (state is BleButtonScanning) {
      emit((state as BleButtonScanning).copyWith(savedDevices: savedDevices));
    } else {

      emit(BleButtonScanning(savedDevices: savedDevices));
    }
  }

  Future<void> _onSavedDeviceDeleteRequested(
    SavedDeviceDeleteRequested event,
    Emitter<BleButtonState> emit,
  ) async {
    emit(const BleButtonScanning(savedDevices: []));

    await DeviceStorage.instance.deleteDevice(event.mac);

    try {
      await _repo.removeDeviceFromBackgroundService(event.mac, clearConfig: true);
    } catch (e) {
      print('Failed to remove device from background service: $e');
    }

    add(const ScanStarted());
  }

  Future<void> _onBuzzerTriggered(
    BuzzerTriggered event,
    Emitter<BleButtonState> emit,
  ) async {
    await _sendCommand(
      emit,
      () => _repo.triggerBuzzer(
        durationMs: event.durationMs,
        intervalMs: event.intervalMs,
      ),
    );
  }

  Future<void> _onBuzzerStopped(
    BuzzerStopped event,
    Emitter<BleButtonState> emit,
  ) async {
    await _sendCommand(emit, _repo.stopBuzzer);
  }

  Future<void> _onAutoReconnectRequested(
    AutoReconnectRequested event,
    Emitter<BleButtonState> emit,
  ) async {
    await _importBackgroundLogs();
    final allDevices = await DeviceStorage.instance.getAllDevices();
    emit(const BleButtonDisconnected());
    await _ensureAllDevicesInBackground(allDevices);
  }

  Future<void> _importBackgroundLogs() async {
    try {
      final raw = await _repo.getPendingLogs();
      final list = jsonDecode(raw) as List<dynamic>;
      for (final entry in list) {
        final map = entry as Map<String, dynamic>;
        await DeviceStorage.instance.insertPressLog(ButtonPressLog(
          mac: map['mac'] as String,
          deviceName: map['deviceName'] as String,
          pressedAt: DateTime.fromMillisecondsSinceEpoch(
              map['pressedAt'] as int),
          batteryPercent: map['batteryPercent'] as int?,
        ));
      }
    } catch (_) {}
  }

  Future<void> _ensureAllDevicesInBackground(
      List<SavedDevice> devices) async {
    for (final device in devices) {
      if (device.clickToOpenApp == 'disabled') continue;
      try {
        await _startDeviceInBackground(device);
      } catch (e) {
        print('Failed to add ${device.mac} to background: $e');
      }
    }
  }

  Future<void> _startDeviceInBackground(SavedDevice device) async {
    String? emergencyPhone;
    String? smsPhone;
    if (device.buttonAction == 'call' || device.buttonAction == 'sms_and_call') {
      emergencyPhone = dotenv.env['RECIPIENTS_CALL_EMERGENCY'];
    }
    if (device.buttonAction == 'sms' || device.buttonAction == 'sms_and_call') {
      smsPhone = dotenv.env['LIST_RECIPIENTS_SMS_EMERGENCY'];
    }
    await _repo.startBackgroundService(
      device.mac,
      device.password,
      device.clickToOpenApp,
      buttonAction: device.buttonAction,
      emergencyPhone: emergencyPhone,
      smsPhone: smsPhone,
      deviceName: device.name,
    );
  }

  @override
  Future<void> close() {
    _scanSub?.cancel();
    _connectionSub?.cancel();
    _buttonSub?.cancel();
    _taskSub?.cancel();
    return super.close();
  }
}

extension _DeviceInfoMapX on DeviceInfo {
  Map<String, dynamic> toMap() => {
        'deviceName': deviceName,
        'firmwareVersion': firmwareVersion,
        'hardwareVersion': hardwareVersion,
        'batteryPercent': batteryPercent,
        'advIntervalMs': advIntervalMs,
        'txPower': txPower,
        'isPasswordEnabled': isPasswordEnabled,
        'mac': mac,
      };
}
