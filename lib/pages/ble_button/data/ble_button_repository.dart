import 'dart:async';

import 'package:flutter/services.dart';

import '../domain/models.dart';

/// Contract for the BLE Button data source.
/// Abstracts the platform channel for testability.
abstract class BleButtonRepository {
  Stream<ScannedDevice> get onDeviceScanned;
  Stream<bool> get onConnectionStatusChanged;
  Stream<String> get onButtonPress;
  Stream<Map<String, dynamic>> get onTaskResult;

  Future<void> startScan();
  Future<void> stopScan();
  Future<void> prepareConnect(String mac);
  Future<void> connect(String mac, {String password = '123456'});
  Future<void> disconnect();
  Future<void> readDeviceInfo();
  Future<void> readBattery();
  Future<void> setAdvInterval(int intervalMs);
  Future<void> setTxPower(int txPower);
  Future<void> setDeviceName(String name);
  Future<void> changePassword(String oldPassword, String newPassword);
  Future<void> enableButtonNotify({required bool enable});
  Future<void> resetDevice();
  Future<void> startBackgroundService(
      String mac, String password, String clickType,
      {String buttonAction = 'open_app',
      String? emergencyPhone,
      String? smsPhone,
      String deviceType = 'button',
      String deviceName = 'Dispositivo MK'});
  Future<void> stopBackgroundService();
  Future<void> removeDeviceFromBackgroundService(String mac);
  Future<void> executeEmergencyAction(
      String mac, String buttonAction, String? emergencyPhone, String deviceName);
  Future<void> triggerBuzzer({int durationMs = 3000, int intervalMs = 0});
  Future<void> stopBuzzer();
  Future<String> getPendingLogs();
}

/// Implementation using Flutter MethodChannel to communicate with
/// the native MKButton SDK on Android.
class BleButtonRepositoryImpl implements BleButtonRepository {
  BleButtonRepositoryImpl() {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  static const _channelName = 'com.example.app/mk_button';

  final MethodChannel _channel = const MethodChannel(_channelName);

  final StreamController<ScannedDevice> _deviceScannedController =
      StreamController<ScannedDevice>.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  final StreamController<String> _buttonPressController =
      StreamController<String>.broadcast();
  final StreamController<Map<String, dynamic>> _taskResultController =
      StreamController<Map<String, dynamic>>.broadcast();

  @override
  Stream<ScannedDevice> get onDeviceScanned => _deviceScannedController.stream;

  @override
  Stream<bool> get onConnectionStatusChanged => _connectionController.stream;

  @override
  Stream<String> get onButtonPress => _buttonPressController.stream;

  @override
  Stream<Map<String, dynamic>> get onTaskResult => _taskResultController.stream;

  Future<void> _handleNativeCall(MethodCall call) async {
    final args = (call.arguments as Map?)?.cast<String, dynamic>() ?? {};
    switch (call.method) {
      case 'onDeviceScanned':
        _deviceScannedController.add(ScannedDevice.fromMap(args));
      case 'onConnectionStatus':
        _connectionController.add(args['connected'] as bool? ?? false);
      case 'onButtonPress':
        _buttonPressController.add(args['type'] as String? ?? 'unknown');
      case 'onTaskResult':
        _taskResultController.add(args);
      default:
        // Unhandled native call — ignore
        break;
    }
  }

  @override
  Future<void> startScan() => _invoke('startScan');

  @override
  Future<void> stopScan() => _invoke('stopScan');

  @override
  Future<void> prepareConnect(String mac) =>
      _invoke('prepareConnect', {'mac': mac});

  @override
  Future<void> connect(String mac, {String password = '123456'}) =>
      _invoke('connect', {'mac': mac, 'password': password});

  @override
  Future<void> disconnect() => _invoke('disconnect');

  @override
  Future<void> readDeviceInfo() => _invoke('readDeviceInfo');

  @override
  Future<void> readBattery() => _invoke('readBattery');

  @override
  Future<void> setAdvInterval(int intervalMs) =>
      _invoke('setAdvInterval', {'intervalMs': intervalMs});

  @override
  Future<void> setTxPower(int txPower) =>
      _invoke('setTxPower', {'txPower': txPower});

  @override
  Future<void> setDeviceName(String name) =>
      _invoke('setDeviceName', {'name': name});

  @override
  Future<void> changePassword(String oldPassword, String newPassword) =>
      _invoke('changePassword', {
        'oldPassword': oldPassword,
        'newPassword': newPassword,
      });

  @override
  Future<void> enableButtonNotify({required bool enable}) =>
      _invoke('enableButtonNotify', {'enable': enable});

  @override
  Future<void> resetDevice() => _invoke('resetDevice');

  @override
  Future<void> startBackgroundService(
    String mac,
    String password,
    String clickType, {
    String buttonAction = 'open_app',
    String? emergencyPhone,
    String? smsPhone,
    String deviceType = 'button',
    String deviceName = 'Dispositivo MK',
  }) =>
      _invoke('startBackgroundService', {
        'mac': mac,
        'password': password,
        'clickType': clickType,
        'buttonAction': buttonAction,
        'emergencyPhone': emergencyPhone,
        'smsPhone': smsPhone,
        'deviceType': deviceType,
        'deviceName': deviceName,
      });

  @override
  Future<void> stopBackgroundService() => _invoke('stopBackgroundService');

  @override
  Future<void> removeDeviceFromBackgroundService(String mac) =>
      _invoke('removeDeviceFromBackgroundService', {'mac': mac});

  @override
  Future<void> executeEmergencyAction(
          String mac, String buttonAction, String? emergencyPhone, String deviceName) =>
      _invoke('executeEmergencyAction', {
        'mac': mac,
        'buttonAction': buttonAction,
        'emergencyPhone': emergencyPhone,
        'deviceName': deviceName,
      });

  @override
  Future<void> triggerBuzzer({int durationMs = 3000, int intervalMs = 0}) =>
      _invoke('triggerBuzzer', {'durationMs': durationMs, 'intervalMs': intervalMs});

  @override
  Future<void> stopBuzzer() => _invoke('stopBuzzer');

  @override
  Future<String> getPendingLogs() async {
    try {
      final result = await _channel.invokeMethod<String>('getPendingLogs');
      return result ?? '[]';
    } on PlatformException {
      return '[]';
    }
  }

  Future<void> _invoke(String method, [Map<String, dynamic>? args]) async {
    try {
      await _channel.invokeMethod<void>(method, args);
    } on PlatformException catch (e) {
      throw BleButtonException(
        code: e.code,
        message: e.message ?? 'Unknown error from native layer',
      );
    }
  }

  void dispose() {
    _deviceScannedController.close();
    _connectionController.close();
    _buttonPressController.close();
    _taskResultController.close();
  }
}

/// Exception thrown when the native channel reports an error
class BleButtonException implements Exception {
  const BleButtonException({required this.code, required this.message});

  final String code;
  final String message;

  @override
  String toString() => 'BleButtonException[$code]: $message';
}
