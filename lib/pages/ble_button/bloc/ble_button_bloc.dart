import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/ble_button_repository.dart';
import '../domain/models.dart';

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
      await _repo.startScan();
      emit(const BleButtonScanning());
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
      await _repo.connect(event.mac, password: event.password ?? '123456');
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
    if (state is BleButtonConnected) {
      final current = state as BleButtonConnected;
      emit(current.copyWith(isLoading: true));
      try {
        await _repo.readDeviceInfo();
      } on BleButtonException catch (e) {
        emit(current.copyWith(isLoading: false, errorMessage: e.message));
      }
    }
  }

  Future<void> _onDeviceInfoReadRequested(
    DeviceInfoReadRequested event,
    Emitter<BleButtonState> emit,
  ) async {
    if (state is BleButtonConnected) {
      final current = state as BleButtonConnected;
      emit(current.copyWith(isLoading: true));
      try {
        await _repo.readDeviceInfo();
      } on BleButtonException catch (e) {
        emit(current.copyWith(isLoading: false, errorMessage: e.message));
      }
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
    if (state is BleButtonScanning) {
      final current = state as BleButtonScanning;
      final devices = List<ScannedDevice>.from(current.devices);
      final index = devices.indexWhere((d) => d.mac == event.device.mac);
      if (index >= 0) {
        devices[index] = event.device;
      } else {
        devices.add(event.device);
      }
      emit(current.copyWith(devices: devices));
    }
  }

  void _onConnectionStatusChanged(
    _ConnectionStatusChanged event,
    Emitter<BleButtonState> emit,
  ) {
    if (event.connected) {
      final mac = state is BleButtonConnecting
          ? (state as BleButtonConnecting).mac
          : '';
      emit(BleButtonConnected(mac: mac));
      // NO leemos device info automáticamente para evitar timeouts del Nordic BLE Manager
      // El usuario puede leerlo manualmente si lo necesita
    } else {
      emit(const BleButtonDisconnected());
    }
  }

  void _onButtonPressReceived(
    _ButtonPressReceived event,
    Emitter<BleButtonState> emit,
  ) {
    if (state is BleButtonConnected) {
      final current = state as BleButtonConnected;
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
  ) {
    if (state is BleButtonConnected) {
      final current = state as BleButtonConnected;
      final result = event.result;

      if (result.containsKey('batteryPercent') ||
          result.containsKey('deviceName')) {
        final info = DeviceInfo.fromMap({
          ...?current.deviceInfo?.toMap(),
          ...result,
        });
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
    } on BleButtonException catch (e) {
      emit(current.copyWith(isLoading: false, errorMessage: e.message));
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
