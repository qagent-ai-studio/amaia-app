part of 'ble_button_bloc.dart';

/// Base class for all BLE Button states
abstract class BleButtonState extends Equatable {
  const BleButtonState();

  @override
  List<Object?> get props => [];
}

/// Initial / idle state
class BleButtonInitial extends BleButtonState {
  const BleButtonInitial();
}

/// Currently scanning for devices
class BleButtonScanning extends BleButtonState {
  const BleButtonScanning({this.devices = const []});

  final List<ScannedDevice> devices;

  BleButtonScanning copyWith({List<ScannedDevice>? devices}) =>
      BleButtonScanning(devices: devices ?? this.devices);

  @override
  List<Object?> get props => [devices];
}

/// Connecting to a device
class BleButtonConnecting extends BleButtonState {
  const BleButtonConnecting({required this.mac});

  final String mac;

  @override
  List<Object?> get props => [mac];
}

/// Connected to a device, ready to communicate
class BleButtonConnected extends BleButtonState {
  const BleButtonConnected({
    required this.mac,
    this.deviceInfo,
    this.lastButtonPress,
    this.isLoading = false,
    this.errorMessage,
  });

  final String mac;
  final DeviceInfo? deviceInfo;
  final ButtonPressEvent? lastButtonPress;
  final bool isLoading;
  final String? errorMessage;

  BleButtonConnected copyWith({
    DeviceInfo? deviceInfo,
    ButtonPressEvent? lastButtonPress,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    bool clearButtonPress = false,
  }) =>
      BleButtonConnected(
        mac: mac,
        deviceInfo: deviceInfo ?? this.deviceInfo,
        lastButtonPress:
            clearButtonPress ? null : lastButtonPress ?? this.lastButtonPress,
        isLoading: isLoading ?? this.isLoading,
        errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      );

  @override
  List<Object?> get props => [mac, deviceInfo, lastButtonPress, isLoading, errorMessage];
}

/// Disconnected state
class BleButtonDisconnected extends BleButtonState {
  const BleButtonDisconnected({this.reason});

  final String? reason;

  @override
  List<Object?> get props => [reason];
}

/// Error state
class BleButtonError extends BleButtonState {
  const BleButtonError({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}
