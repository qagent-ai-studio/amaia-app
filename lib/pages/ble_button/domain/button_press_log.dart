class ButtonPressLog {
  const ButtonPressLog({
    this.id,
    required this.mac,
    required this.deviceName,
    required this.pressedAt,
    this.batteryPercent,
  });

  final int? id;
  final String mac;
  final String deviceName;
  final DateTime pressedAt;
  final int? batteryPercent;

  Map<String, dynamic> toMap() => {
        'id': id,
        'mac': mac,
        'deviceName': deviceName,
        'pressedAt': pressedAt.millisecondsSinceEpoch,
        'batteryPercent': batteryPercent,
      };

  factory ButtonPressLog.fromMap(Map<String, dynamic> map) => ButtonPressLog(
        id: map['id'] as int?,
        mac: map['mac'] as String,
        deviceName: map['deviceName'] as String,
        pressedAt:
            DateTime.fromMillisecondsSinceEpoch(map['pressedAt'] as int),
        batteryPercent: map['batteryPercent'] as int?,
      );
}
