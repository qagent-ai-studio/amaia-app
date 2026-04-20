import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'mk_button_devices.db');

    return await openDatabase(
      path,
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE devices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mac TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        password TEXT NOT NULL,
        batteryPercent INTEGER,
        firmwareVersion TEXT,
        hardwareVersion TEXT,
        advIntervalMs INTEGER,
        txPower INTEGER,
        isPasswordEnabled INTEGER,
        lastConnectedAt INTEGER,
        totalClicks INTEGER DEFAULT 0,
        lastSingleClick INTEGER,
        lastDoubleClick INTEGER,
        lastLongClick INTEGER,
        clickToOpenApp TEXT DEFAULT 'single',
        buttonAction TEXT DEFAULT 'sms_and_call',
        emergencyPhone TEXT
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_mac ON devices(mac)
    ''');

    await db.execute('''
      CREATE TABLE button_press_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mac TEXT NOT NULL,
        deviceName TEXT NOT NULL,
        pressedAt INTEGER NOT NULL,
        batteryPercent INTEGER
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_logs_mac ON button_press_logs(mac)
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {

      await db.execute('''
        ALTER TABLE devices ADD COLUMN clickToOpenApp TEXT DEFAULT 'single'
      ''');
    }
    if (oldVersion < 3) {

      await db.execute('''
        ALTER TABLE devices ADD COLUMN buttonAction TEXT DEFAULT 'sms_and_call'
      ''');
      await db.execute('''
        ALTER TABLE devices ADD COLUMN emergencyPhone TEXT
      ''');
    }
    if (oldVersion < 4) {
      await db.execute('''
        UPDATE devices SET buttonAction = 'sms_and_call' WHERE buttonAction = 'open_app'
      ''');
    }
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE button_press_logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          mac TEXT NOT NULL,
          deviceName TEXT NOT NULL,
          pressedAt INTEGER NOT NULL,
          batteryPercent INTEGER
        )
      ''');
      await db.execute('''
        CREATE INDEX idx_logs_mac ON button_press_logs(mac)
      ''');
    }
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  Future<void> deleteDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'mk_button_devices.db');
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }
}
