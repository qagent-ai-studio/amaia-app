import 'package:equatable/equatable.dart';

/// Represents a BLE device found during scanning
class ScannedDevice extends Equatable {
  const ScannedDevice({
    required this.mac,
    required this.name,
    required this.rssi,
  });

  factory ScannedDevice.fromMap(Map<String, dynamic> map) => ScannedDevice(
        mac: map['mac'] as String,
        name: (map['name'] as String?) ?? 'Unknown',
        rssi: (map['rssi'] as int?) ?? -100,
      );

  final String mac;
  final String name;
  final int rssi;

  @override
  List<Object?> get props => [mac, name, rssi];
}

/// Device settings and info retrieved from the connected device
class DeviceInfo extends Equatable {
  const DeviceInfo({
    required this.deviceName,
    required this.firmwareVersion,
    required this.hardwareVersion,
    required this.batteryPercent,
    required this.advIntervalMs,
    required this.txPower,
    required this.isPasswordEnabled,
    this.mac,
  });

  factory DeviceInfo.fromMap(Map<String, dynamic> map) => DeviceInfo(
        deviceName: (map['deviceName'] as String?) ?? '',
        firmwareVersion: (map['firmwareVersion'] as String?) ?? '',
        hardwareVersion: (map['hardwareVersion'] as String?) ?? '',
        batteryPercent: (map['batteryPercent'] as int?) ?? 0,
        advIntervalMs: (map['advIntervalMs'] as int?) ?? 0,
        txPower: (map['txPower'] as int?) ?? 0,
        isPasswordEnabled: (map['isPasswordEnabled'] as bool?) ?? false,
        mac: map['mac'] as String?,
      );

  final String deviceName;
  final String firmwareVersion;
  final String hardwareVersion;
  final int batteryPercent;
  final int advIntervalMs;
  final int txPower;
  final bool isPasswordEnabled;
  final String? mac;

  @override
  List<Object?> get props => [
        deviceName,
        firmwareVersion,
        hardwareVersion,
        batteryPercent,
        advIntervalMs,
        txPower,
        isPasswordEnabled,
        mac,
      ];
}

/// Represents a button press event from the device
class ButtonPressEvent extends Equatable {
  const ButtonPressEvent({
    required this.pressType,
    required this.timestamp,
  });

  final String pressType; // 'single', 'double', 'long'
  final DateTime timestamp;

  String get label {
    switch (pressType) {
      case 'single':
        return 'Presión Simple';
      case 'double':
        return 'Presión Doble';
      case 'long':
        return 'Presión Larga';
      default:
        return pressType;
    }
  }

  @override
  List<Object?> get props => [pressType, timestamp];
}

/// TX Power levels supported by the device
enum TxPowerLevel {
  neg40dBm(-40),
  neg20dBm(-20),
  neg16dBm(-16),
  neg12dBm(-12),
  neg8dBm(-8),
  neg4dBm(-4),
  zero0dBm(0),
  pos4dBm(4);

  const TxPowerLevel(this.value);

  final int value;

  String get label => '$value dBm';

  static TxPowerLevel fromValue(int value) {
    return TxPowerLevel.values.firstWhere(
      (e) => e.value == value,
      orElse: () => TxPowerLevel.zero0dBm,
    );
  }
}
