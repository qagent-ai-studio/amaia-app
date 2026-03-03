part of 'ble_button_bloc.dart';

/// Base class for all BLE Button events
abstract class BleButtonEvent extends Equatable {
  const BleButtonEvent();

  @override
  List<Object?> get props => [];
}

/// Start scanning for BLE devices
class ScanStarted extends BleButtonEvent {
  const ScanStarted();
}

/// Stop scanning for BLE devices
class ScanStopped extends BleButtonEvent {
  const ScanStopped();
}

/// Connect to a specific BLE device
class DeviceConnectRequested extends BleButtonEvent {
  const DeviceConnectRequested({required this.mac, this.password});

  final String mac;
  final String? password;

  @override
  List<Object?> get props => [mac, password];
}

/// Disconnect from the current BLE device
class DeviceDisconnectRequested extends BleButtonEvent {
  const DeviceDisconnectRequested();
}

/// Read battery level from device
class BatteryReadRequested extends BleButtonEvent {
  const BatteryReadRequested();
}

/// Read all device settings at once
class DeviceInfoReadRequested extends BleButtonEvent {
  const DeviceInfoReadRequested();
}

/// Update advertising interval (unit: 100ms, range: 1~100)
class AdvIntervalUpdateRequested extends BleButtonEvent {
  const AdvIntervalUpdateRequested({required this.intervalMs});

  final int intervalMs;

  @override
  List<Object?> get props => [intervalMs];
}

/// Update TX power level
class TxPowerUpdateRequested extends BleButtonEvent {
  const TxPowerUpdateRequested({required this.txPower});

  final int txPower;

  @override
  List<Object?> get props => [txPower];
}

/// Update device name
class DeviceNameUpdateRequested extends BleButtonEvent {
  const DeviceNameUpdateRequested({required this.name});

  final String name;

  @override
  List<Object?> get props => [name];
}

/// Update password
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

/// Toggle button notify (capture button presses)
class ButtonNotifyToggled extends BleButtonEvent {
  const ButtonNotifyToggled({required this.enable});

  final bool enable;

  @override
  List<Object?> get props => [enable];
}

/// Reset device to factory defaults
class DeviceResetRequested extends BleButtonEvent {
  const DeviceResetRequested();
}

/// Internal: Native side reported a device was scanned
class _DeviceScanned extends BleButtonEvent {
  const _DeviceScanned({required this.device});

  final ScannedDevice device;

  @override
  List<Object?> get props => [device];
}

/// Internal: Native side reported connection status changed
class _ConnectionStatusChanged extends BleButtonEvent {
  const _ConnectionStatusChanged({required this.connected});

  final bool connected;

  @override
  List<Object?> get props => [connected];
}

/// Internal: Native side reported button was pressed
class _ButtonPressReceived extends BleButtonEvent {
  const _ButtonPressReceived({required this.pressType});

  final String pressType;

  @override
  List<Object?> get props => [pressType];
}

/// Internal: Native side reported task result
class _TaskResultReceived extends BleButtonEvent {
  const _TaskResultReceived({required this.result});

  final Map<String, dynamic> result;

  @override
  List<Object?> get props => [result];
}
