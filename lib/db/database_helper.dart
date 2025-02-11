import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'amaia.db');

    return await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE information(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        value INTEGER
      )
    ''');
  }

  Future<void> deleteDatabaseFile(String dbName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, dbName);

    try {
      await deleteDatabase(path);
      print('Base de datos "$dbName" eliminada correctamente.');
    } catch (e) {
      print('Error al eliminar la base de datos: $e');
    }
  }

  Future<int> insertItem(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('information', data);
  }

  Future<List<Map<String, dynamic>>> getItems() async {
    final db = await database;
    return await db.query('information', orderBy: "id DESC", limit: 1);
  }

  Future<int> updateItem(int id, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update(
      'information',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteItem(int id) async {
    final db = await database;
    return await db.delete(
      'information',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
