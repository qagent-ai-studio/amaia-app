import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/ble_button_repository.dart';
import '../data/device_storage.dart';
import '../domain/models.dart';
import '../domain/saved_device.dart';

part 'ble_button_event.dart';
part 'ble_button_state.dart';

/// BLoC that manages all BLE Button device interactions.
///
/// Listens to native SDK events via [BleButtonRepository] and
/// exposes clean state transitions for the UI.
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

  // ---------------------------------------------------------------------------
  // Event handlers
  // ---------------------------------------------------------------------------

  Future<void> _onScanStarted(
    ScanStarted event,
    Emitter<BleButtonState> emit,
  ) async {
    try {
      // Solicitar permisos de Bluetooth en runtime (Android 12+)
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

      // Solicitar permiso de ubicación (requerido para escaneo BLE en Android)
      final locationStatus = await Permission.location.request();
      if (!locationStatus.isGranted) {
        emit(const BleButtonError(
          message:
              'Se requiere permiso de ubicación para escanear dispositivos BLE',
        ));
        return;
      }

      // Cargar dispositivos guardados de la BD
      final savedDevices = await DeviceStorage.instance.getAllDevices();
      print('[BLE] Loaded ${savedDevices.length} saved devices from database');

      await _repo.startScan();
      print('[BLE] Scan started successfully');
      emit(BleButtonScanning(savedDevices: savedDevices));
    } on BleButtonException catch (e) {
      print('[BLE] Scan error: ${e.message}');
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
      await _repo.connect(event.mac, password: event.password ?? '123456');

      // Guardar dispositivo en la BD (o actualizar si ya existe)
      // Buscar el nombre del dispositivo en la lista de escaneo
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
    // Detener servicio en segundo plano
    try {
      await _repo.stopBackgroundService();
    } catch (e) {
      print('Failed to stop background service: $e');
    }
  }

  Future<void> _onBatteryReadRequested(
    BatteryReadRequested event,
    Emitter<BleButtonState> emit,
  ) async {
    // ADVERTENCIA: Leer batería después de init puede causar desconexión
    // Este comando se ejecuta SOLO cuando el usuario presiona el botón manualmente
    await _sendCommand(emit, () => _repo.readBattery());
  }

  Future<void> _onDeviceInfoReadRequested(
    DeviceInfoReadRequested event,
    Emitter<BleButtonState> emit,
  ) async {
    // NOTE: MK Button NO soporta comandos después de la inicialización.
    // Deshabilitado para prevenir desconexiones.
    // La información del dispositivo se lee durante la secuencia de init (0x2C).
    if (state is BleButtonConnected) {
      // No hacer nada - el comando está deshabilitado en el nativo
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

      // Actualizar timestamp de última conexión en la BD
      await DeviceStorage.instance.updateLastConnected(mac);

      // Iniciar servicio en segundo plano si está configurado
      final device = await DeviceStorage.instance.getDeviceByMac(mac);
      if (device != null && device.clickToOpenApp != 'disabled') {
        try {
          // Leer número de emergencia del .env
          String? emergencyPhone;
          String buttonAction = device.buttonAction;

          if (buttonAction == 'call' ||
              buttonAction == 'sms' ||
              buttonAction == 'sms_and_call') {
            // Para 'call' y 'sms_and_call' usar el número de llamadas
            // Para 'sms' usar el número de SMS
            emergencyPhone =
                (buttonAction == 'call' || buttonAction == 'sms_and_call')
                    ? dotenv.env['RECIPIENTS_CALL_EMERGENCY']
                    : dotenv.env['LIST_RECIPIENTS_SMS_EMERGENCY'];
          }

          await _repo.startBackgroundService(
            device.mac,
            device.password,
            device.clickToOpenApp,
            buttonAction: buttonAction,
            emergencyPhone: emergencyPhone,
          );
        } catch (e) {
          // Log error pero no bloquear la conexión
          print('Failed to start background service: $e');
        }
      }

      // Emitir estado conectado SIN isLoading ya que no esperamos device info
      // El MK Button NO tolera comandos adicionales después de la inicialización
      emit(BleButtonConnected(mac: mac, isLoading: false));
    } else {
      emit(const BleButtonDisconnected());
    }
  }

  void _onButtonPressReceived(
    _ButtonPressReceived event,
    Emitter<BleButtonState> emit,
  ) async {
    if (state is BleButtonConnected) {
      final current = state as BleButtonConnected;

      // Incrementar contador de clicks en la BD
      await DeviceStorage.instance.incrementClickCount(
        current.mac,
        event.pressType,
      );

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

        // Actualizar información en la base de datos
        await DeviceStorage.instance.updateDeviceInfo(current.mac, result);

        emit(current.copyWith(deviceInfo: info, isLoading: false));
      } else {
        emit(current.copyWith(isLoading: false));
      }
    }
  }

  /// Helper to wrap write commands with loading state
  Future<void> _sendCommand(
    Emitter<BleButtonState> emit,
    Future<void> Function() command,
  ) async {
    if (state is! BleButtonConnected) return;
    final current = state as BleButtonConnected;
    emit(current.copyWith(isLoading: true, clearError: true));
    try {
      await command();
      // Inmediatamente quitar el loading después de enviar el comando
      // ya que el MK Button no envía respuestas TaskResult para la mayoría de comandos
      if (state is BleButtonConnected) {
        emit((state as BleButtonConnected).copyWith(isLoading: false));
      }
    } on BleButtonException catch (e) {
      emit(current.copyWith(isLoading: false, errorMessage: e.message));
    }
  }

  // ---------------------------------------------------------------------------
  // Saved devices handlers
  // ---------------------------------------------------------------------------

  Future<void> _onSavedDevicesLoadRequested(
    SavedDevicesLoadRequested event,
    Emitter<BleButtonState> emit,
  ) async {
    final savedDevices = await DeviceStorage.instance.getAllDevices();

    if (state is BleButtonScanning) {
      emit((state as BleButtonScanning).copyWith(savedDevices: savedDevices));
    } else {
      // Si no estamos escaneando, iniciar con los dispositivos guardados
      emit(BleButtonScanning(savedDevices: savedDevices));
    }
  }

  Future<void> _onSavedDeviceDeleteRequested(
    SavedDeviceDeleteRequested event,
    Emitter<BleButtonState> emit,
  ) async {
    await DeviceStorage.instance.deleteDevice(event.mac);

    // Detener servicio en segundo plano si estaba activo
    try {
      await _repo.stopBackgroundService();
    } catch (e) {
      print('Failed to stop background service: $e');
    }

    // Recargar la lista de dispositivos guardados
    final savedDevices = await DeviceStorage.instance.getAllDevices();

    if (state is BleButtonScanning) {
      emit((state as BleButtonScanning).copyWith(savedDevices: savedDevices));
    }
  }

  Future<void> _onAutoReconnectRequested(
    AutoReconnectRequested event,
    Emitter<BleButtonState> emit,
  ) async {
    final lastDevice = await DeviceStorage.instance.getLastConnectedDevice();

    if (lastDevice != null) {
      emit(BleButtonConnecting(mac: lastDevice.mac));
      try {
        await _repo.connect(lastDevice.mac, password: lastDevice.password);
      } on BleButtonException catch (e) {
        emit(BleButtonError(message: e.message));
      }
    }
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

// Extension to allow DeviceInfo serialization for merging
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
