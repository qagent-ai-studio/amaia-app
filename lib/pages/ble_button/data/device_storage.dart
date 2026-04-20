import 'package:sqflite/sqflite.dart';

import '../domain/button_press_log.dart';
import '../domain/saved_device.dart';
import 'database_helper.dart';

class DeviceStorage {
  DeviceStorage._();
  static final DeviceStorage instance = DeviceStorage._();

  Future<Database> get _db async => DatabaseHelper.instance.database;

  Future<int> saveDevice(SavedDevice device) async {
    final db = await _db;

    final existing = await getDeviceByMac(device.mac);

    if (existing != null) {

      await db.update(
        'devices',
        device.copyWith(id: existing.id).toMap(),
        where: 'id = ?',
        whereArgs: [existing.id],
      );
      return existing.id!;
    } else {

      return await db.insert('devices', device.toMap());
    }
  }

  Future<List<SavedDevice>> getAllDevices() async {
    final db = await _db;
    final maps = await db.query(
      'devices',
      orderBy: 'lastConnectedAt DESC',
    );

    return maps.map((map) => SavedDevice.fromMap(map)).toList();
  }

  Future<SavedDevice?> getDeviceByMac(String mac) async {
    final db = await _db;
    final maps = await db.query(
      'devices',
      where: 'mac = ?',
      whereArgs: [mac],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return SavedDevice.fromMap(maps.first);
  }

  Future<SavedDevice?> getLastConnectedDevice() async {
    final db = await _db;
    final maps = await db.query(
      'devices',
      orderBy: 'lastConnectedAt DESC',
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return SavedDevice.fromMap(maps.first);
  }

  Future<void> updateLastConnected(String mac) async {
    final db = await _db;
    await db.update(
      'devices',
      {'lastConnectedAt': DateTime.now().millisecondsSinceEpoch},
      where: 'mac = ?',
      whereArgs: [mac],
    );
  }

  Future<void> incrementClickCount(String mac, String clickType) async {
    final db = await _db;
    final device = await getDeviceByMac(mac);

    if (device == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final updates = <String, dynamic>{
      'totalClicks': device.totalClicks + 1,
    };

    switch (clickType) {
      case 'single':
        updates['lastSingleClick'] = now;
        break;
      case 'double':
        updates['lastDoubleClick'] = now;
        break;
      case 'long':
        updates['lastLongClick'] = now;
        break;
    }

    await db.update(
      'devices',
      updates,
      where: 'mac = ?',
      whereArgs: [mac],
    );
  }

  Future<void> updateDeviceInfo(String mac, Map<String, dynamic> info) async {
    final db = await _db;
    await db.update(
      'devices',
      info,
      where: 'mac = ?',
      whereArgs: [mac],
    );
  }

  Future<int> deleteDevice(String mac) async {
    final db = await _db;
    await db.delete('button_press_logs', where: 'mac = ?', whereArgs: [mac]);
    return await db.delete('devices', where: 'mac = ?', whereArgs: [mac]);
  }

  Future<void> deleteAllDevices() async {
    final db = await _db;
    await db.delete('devices');
  }

  Future<void> updateClickToOpenApp(String mac, String clickType) async {
    final db = await _db;
    await db.update(
      'devices',
      {'clickToOpenApp': clickType},
      where: 'mac = ?',
      whereArgs: [mac],
    );
  }

  Future<void> insertPressLog(ButtonPressLog log) async {
    final db = await _db;
    await db.insert('button_press_logs', log.toMap());
  }

  Future<List<ButtonPressLog>> getLogsForDevice(String mac,
      {int limit = 100}) async {
    final db = await _db;
    final maps = await db.query(
      'button_press_logs',
      where: 'mac = ?',
      whereArgs: [mac],
      orderBy: 'pressedAt DESC',
      limit: limit,
    );
    return maps.map((m) => ButtonPressLog.fromMap(m)).toList();
  }
}
