import 'package:equatable/equatable.dart';

/// Modelo para un dispositivo MK Button guardado en la base de datos local
class SavedDevice extends Equatable {
  const SavedDevice({
    this.id,
    required this.mac,
    required this.name,
    required this.password,
    this.batteryPercent,
    this.firmwareVersion,
    this.hardwareVersion,
    this.advIntervalMs,
    this.txPower,
    this.isPasswordEnabled,
    this.lastConnectedAt,
    this.totalClicks = 0,
    this.lastSingleClick,
    this.lastDoubleClick,
    this.lastLongClick,
    this.clickToOpenApp = 'single', // 'single', 'double', o 'disabled'
    this.buttonAction =
        'sms_and_call', // 'open_app', 'call', 'sms', 'sms_and_call'
    this.emergencyPhone,
  });

  final int? id; // ID autoincremental de SQLite
  final String mac; // Dirección MAC (único)
  final String name; // Nombre del dispositivo
  final String password; // Contraseña para conectar

  // Información del dispositivo
  final int? batteryPercent;
  final String? firmwareVersion;
  final String? hardwareVersion;
  final int? advIntervalMs;
  final int? txPower;
  final bool? isPasswordEnabled;

  // Metadatos de conexión
  final DateTime? lastConnectedAt;

  // Historial de clicks
  final int totalClicks;
  final DateTime? lastSingleClick;
  final DateTime? lastDoubleClick;
  final DateTime? lastLongClick;

  // Configuración de apertura de app
  final String clickToOpenApp; // 'single', 'double', o 'disabled'

  // Configuración de acción del botón
  final String buttonAction; // 'open_app', 'call', 'sms', 'sms_and_call'
  final String? emergencyPhone; // Número para llamar o enviar SMS

  @override
  List<Object?> get props => [
        id,
        mac,
        name,
        password,
        batteryPercent,
        firmwareVersion,
        hardwareVersion,
        advIntervalMs,
        txPower,
        isPasswordEnabled,
        lastConnectedAt,
        totalClicks,
        lastSingleClick,
        lastDoubleClick,
        lastLongClick,
        clickToOpenApp,
        buttonAction,
        emergencyPhone,
      ];

  SavedDevice copyWith({
    int? id,
    String? mac,
    String? name,
    String? password,
    int? batteryPercent,
    String? firmwareVersion,
    String? hardwareVersion,
    int? advIntervalMs,
    int? txPower,
    bool? isPasswordEnabled,
    DateTime? lastConnectedAt,
    int? totalClicks,
    DateTime? lastSingleClick,
    DateTime? lastDoubleClick,
    DateTime? lastLongClick,
    String? clickToOpenApp,
    String? buttonAction,
    String? emergencyPhone,
  }) {
    return SavedDevice(
      id: id ?? this.id,
      mac: mac ?? this.mac,
      name: name ?? this.name,
      password: password ?? this.password,
      batteryPercent: batteryPercent ?? this.batteryPercent,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      hardwareVersion: hardwareVersion ?? this.hardwareVersion,
      advIntervalMs: advIntervalMs ?? this.advIntervalMs,
      txPower: txPower ?? this.txPower,
      isPasswordEnabled: isPasswordEnabled ?? this.isPasswordEnabled,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
      totalClicks: totalClicks ?? this.totalClicks,
      lastSingleClick: lastSingleClick ?? this.lastSingleClick,
      lastDoubleClick: lastDoubleClick ?? this.lastDoubleClick,
      lastLongClick: lastLongClick ?? this.lastLongClick,
      clickToOpenApp: clickToOpenApp ?? this.clickToOpenApp,
      buttonAction: buttonAction ?? this.buttonAction,
      emergencyPhone: emergencyPhone ?? this.emergencyPhone,
    );
  }

  /// Convierte el modelo a un Map para SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'mac': mac,
      'name': name,
      'password': password,
      'batteryPercent': batteryPercent,
      'firmwareVersion': firmwareVersion,
      'hardwareVersion': hardwareVersion,
      'advIntervalMs': advIntervalMs,
      'txPower': txPower,
      'isPasswordEnabled': isPasswordEnabled == true ? 1 : 0,
      'lastConnectedAt': lastConnectedAt?.millisecondsSinceEpoch,
      'totalClicks': totalClicks,
      'lastSingleClick': lastSingleClick?.millisecondsSinceEpoch,
      'lastDoubleClick': lastDoubleClick?.millisecondsSinceEpoch,
      'lastLongClick': lastLongClick?.millisecondsSinceEpoch,
      'clickToOpenApp': clickToOpenApp,
      'buttonAction': buttonAction,
      'emergencyPhone': emergencyPhone,
    };
  }

  /// Crea un modelo desde un Map de SQLite
  factory SavedDevice.fromMap(Map<String, dynamic> map) {
    return SavedDevice(
      id: map['id'] as int?,
      mac: map['mac'] as String,
      name: map['name'] as String,
      password: map['password'] as String,
      batteryPercent: map['batteryPercent'] as int?,
      firmwareVersion: map['firmwareVersion'] as String?,
      hardwareVersion: map['hardwareVersion'] as String?,
      advIntervalMs: map['advIntervalMs'] as int?,
      txPower: map['txPower'] as int?,
      isPasswordEnabled: map['isPasswordEnabled'] == 1,
      lastConnectedAt: map['lastConnectedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastConnectedAt'] as int)
          : null,
      totalClicks: map['totalClicks'] as int? ?? 0,
      lastSingleClick: map['lastSingleClick'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastSingleClick'] as int)
          : null,
      lastDoubleClick: map['lastDoubleClick'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastDoubleClick'] as int)
          : null,
      lastLongClick: map['lastLongClick'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastLongClick'] as int)
          : null,
      clickToOpenApp:
          map['clickToOpenApp'] as String? ?? 'single', // Default: single click
      buttonAction:
          map['buttonAction'] as String? ?? 'open_app', // Default: abrir app
      emergencyPhone: map['emergencyPhone'] as String?,
    );
  }
}
