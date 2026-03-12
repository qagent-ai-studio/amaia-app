import 'package:sqflite/sqflite.dart';

import '../domain/saved_device.dart';
import 'database_helper.dart';

/// Servicio para gestionar el almacenamiento de dispositivos MK Button
class DeviceStorage {
  DeviceStorage._();
  static final DeviceStorage instance = DeviceStorage._();

  Future<Database> get _db async => DatabaseHelper.instance.database;

  /// Guarda o actualiza un dispositivo
  /// Si el MAC ya existe, actualiza el registro
  Future<int> saveDevice(SavedDevice device) async {
    final db = await _db;

    // Verificar si ya existe
    final existing = await getDeviceByMac(device.mac);

    if (existing != null) {
      // Actualizar registro existente
      await db.update(
        'devices',
        device.copyWith(id: existing.id).toMap(),
        where: 'id = ?',
        whereArgs: [existing.id],
      );
      return existing.id!;
    } else {
      // Insertar nuevo registro
      return await db.insert('devices', device.toMap());
    }
  }

  /// Obtiene todos los dispositivos guardados
  /// Ordenados por última conexión (más reciente primero)
  Future<List<SavedDevice>> getAllDevices() async {
    final db = await _db;
    final maps = await db.query(
      'devices',
      orderBy: 'lastConnectedAt DESC',
    );

    return maps.map((map) => SavedDevice.fromMap(map)).toList();
  }

  /// Obtiene un dispositivo por su MAC address
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

  /// Obtiene el último dispositivo conectado
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

  /// Actualiza la fecha de última conexión
  Future<void> updateLastConnected(String mac) async {
    final db = await _db;
    await db.update(
      'devices',
      {'lastConnectedAt': DateTime.now().millisecondsSinceEpoch},
      where: 'mac = ?',
      whereArgs: [mac],
    );
  }

  /// Incrementa el contador de clicks
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

  /// Actualiza la información del dispositivo (batería, firmware, etc.)
  Future<void> updateDeviceInfo(String mac, Map<String, dynamic> info) async {
    final db = await _db;
    await db.update(
      'devices',
      info,
      where: 'mac = ?',
      whereArgs: [mac],
    );
  }

  /// Elimina un dispositivo por su MAC
  Future<int> deleteDevice(String mac) async {
    final db = await _db;
    return await db.delete(
      'devices',
      where: 'mac = ?',
      whereArgs: [mac],
    );
  }

  /// Elimina todos los dispositivos
  Future<void> deleteAllDevices() async {
    final db = await _db;
    await db.delete('devices');
  }

  /// Actualiza la configuración de click para abrir app
  Future<void> updateClickToOpenApp(String mac, String clickType) async {
    final db = await _db;
    await db.update(
      'devices',
      {'clickToOpenApp': clickType},
      where: 'mac = ?',
      whereArgs: [mac],
    );
  }
}
