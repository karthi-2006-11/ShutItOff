import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DBHelper {
  static final DBHelper instance = DBHelper._init();
  static Database? _database;

  DBHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('shutitoff.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE custom_alarms (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        alarm_time TEXT NOT NULL,
        is_enabled INTEGER NOT NULL
      )
    ''');
  }

  Future<int> insertAlarm(String alarmTime, {bool isEnabled = true}) async {
    final db = await database;
    return await db.insert(
      'custom_alarms',
      {
        'alarm_time': alarmTime,
        'is_enabled': isEnabled ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getAlarms() async {
    final db = await database;
    return await db.query('custom_alarms', orderBy: 'alarm_time ASC');
  }

  Future<Map<String, dynamic>?> getAlarm(int id) async {
    final db = await database;
    final results = await db.query(
      'custom_alarms',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  Future<int> updateAlarmStatus(int id, bool isEnabled) async {
    final db = await database;
    return await db.update(
      'custom_alarms',
      {'is_enabled': isEnabled ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateAlarmTime(int id, String alarmTime) async {
    final db = await database;
    return await db.update(
      'custom_alarms',
      {'alarm_time': alarmTime},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAlarm(int id) async {
    final db = await database;
    return await db.delete(
      'custom_alarms',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
