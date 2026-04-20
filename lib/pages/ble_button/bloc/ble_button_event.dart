part of 'ble_button_bloc.dart';

abstract class BleButtonEvent extends Equatable {
  const BleButtonEvent();

  @override
  List<Object?> get props => [];
}

class ScanStarted extends BleButtonEvent {
  const ScanStarted();
}

class ScanStopped extends BleButtonEvent {
  const ScanStopped();
}

class DeviceConnectRequested extends BleButtonEvent {
  const DeviceConnectRequested({required this.mac, this.password});

  final String mac;
  final String? password;

  @override
  List<Object?> get props => [mac, password];
}

class DeviceDisconnectRequested extends BleButtonEvent {
  const DeviceDisconnectRequested();
}

class BatteryReadRequested extends BleButtonEvent {
  const BatteryReadRequested();
}

class DeviceInfoReadRequested extends BleButtonEvent {
  const DeviceInfoReadRequested();
}

class AdvIntervalUpdateRequested extends BleButtonEvent {
  const AdvIntervalUpdateRequested({required this.intervalMs});

  final int intervalMs;

  @override
  List<Object?> get props => [intervalMs];
}

class TxPowerUpdateRequested extends BleButtonEvent {
  const TxPowerUpdateRequested({required this.txPower});

  final int txPower;

  @override
  List<Object?> get props => [txPower];
}

class DeviceNameUpdateRequested extends BleButtonEvent {
  const DeviceNameUpdateRequested({required this.name});

  final String name;

  @override
  List<Object?> get props => [name];
}

class PasswordUpdateRequested extends BleButtonEvent {
  const PasswordUpdateRequested({
    required this.oldPassword,
    required this.newPassword,
  });

  final String oldPassword;
  final String newPassword;

  @override
  List<Object?> get props => [oldPassword, newPassword];
}

class ButtonNotifyToggled extends BleButtonEvent {
  const ButtonNotifyToggled({required this.enable});

  final bool enable;

  @override
  List<Object?> get props => [enable];
}

class DeviceResetRequested extends BleButtonEvent {
  const DeviceResetRequested();
}

class _DeviceScanned extends BleButtonEvent {
  const _DeviceScanned({required this.device});

  final ScannedDevice device;

  @override
  List<Object?> get props => [device];
}

class _ConnectionStatusChanged extends BleButtonEvent {
  const _ConnectionStatusChanged({required this.connected});

  final bool connected;

  @override
  List<Object?> get props => [connected];
}

class _ButtonPressReceived extends BleButtonEvent {
  const _ButtonPressReceived({required this.pressType});

  final String pressType;

  @override
  List<Object?> get props => [pressType];
}

class _TaskResultReceived extends BleButtonEvent {
  const _TaskResultReceived({required this.result});

  final Map<String, dynamic> result;

  @override
  List<Object?> get props => [result];
}

class SavedDevicesLoadRequested extends BleButtonEvent {
  const SavedDevicesLoadRequested();
}

class SavedDeviceDeleteRequested extends BleButtonEvent {
  const SavedDeviceDeleteRequested({required this.mac});

  final String mac;

  @override
  List<Object?> get props => [mac];
}

class AutoReconnectRequested extends BleButtonEvent {
  const AutoReconnectRequested();
}

class BuzzerTriggered extends BleButtonEvent {
  const BuzzerTriggered({this.durationMs = 3000, this.intervalMs = 0});

  final int durationMs;
  final int intervalMs;

  @override
  List<Object?> get props => [durationMs, intervalMs];
}

class BuzzerStopped extends BleButtonEvent {
  const BuzzerStopped();
}
