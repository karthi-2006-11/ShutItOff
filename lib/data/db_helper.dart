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
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
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

    await _createPairedDevicesTable(db);
    await _createHostelTables(db);
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createPairedDevicesTable(db);
    }
    if (oldVersion < 3) {
      await _createHostelTables(db);
    }
  }

  Future<void> _createPairedDevicesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS paired_devices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        friend_name TEXT NOT NULL,
        connection_code TEXT NOT NULL,
        is_authorized INTEGER NOT NULL,
        can_snooze INTEGER NOT NULL,
        can_turn_off INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _createHostelTables(Database db) async {
    // Table A: hostel_rooms
    await db.execute('''
      CREATE TABLE IF NOT EXISTS hostel_rooms (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        room_name TEXT NOT NULL,
        host_code TEXT NOT NULL
      )
    ''');

    // Table B: alarm_audit_logs
    await db.execute('''
      CREATE TABLE IF NOT EXISTS alarm_audit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        alarm_id INTEGER,
        actor_name TEXT NOT NULL,
        action_type TEXT NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');
  }

  // --- custom_alarms helper methods ---

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

  // --- paired_devices helper methods ---

  Future<int> insertPairing(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert(
      'paired_devices',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getPairedDevices() async {
    final db = await database;
    return await db.query('paired_devices', orderBy: 'id DESC');
  }

  Future<Map<String, dynamic>?> getPairedDevice(int id) async {
    final db = await database;
    final results = await db.query(
      'paired_devices',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  Future<Map<String, dynamic>?> getPairedDeviceByCode(String connectionCode) async {
    final db = await database;
    final results = await db.query(
      'paired_devices',
      where: 'connection_code = ?',
      whereArgs: [connectionCode],
      limit: 1,
    );
    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  Future<int> revokeAuthorization(int id) async {
    final db = await database;
    return await db.update(
      'paired_devices',
      {'is_authorized': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deletePairing(int id) async {
    final db = await database;
    return await db.delete(
      'paired_devices',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Phase 5: hostel_rooms & alarm_audit_logs helper methods ---

  Future<int> createRoom(String roomName, String hostCode) async {
    final db = await database;
    return await db.insert(
      'hostel_rooms',
      {
        'room_name': roomName,
        'host_code': hostCode,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getRooms() async {
    final db = await database;
    return await db.query('hostel_rooms', orderBy: 'id DESC');
  }

  Future<Map<String, dynamic>?> getActiveRoom() async {
    final db = await database;
    final results = await db.query('hostel_rooms', orderBy: 'id DESC', limit: 1);
    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  Future<int> insertAuditLog(int alarmId, String actor, String action) async {
    final db = await database;
    final now = DateTime.now();
    final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final period = now.hour >= 12 ? 'PM' : 'AM';
    final minuteStr = now.minute.toString().padLeft(2, '0');
    final formattedTime = '${hour.toString().padLeft(2, '0')}:$minuteStr $period';

    return await db.insert(
      'alarm_audit_logs',
      {
        'alarm_id': alarmId,
        'actor_name': actor,
        'action_type': action,
        'timestamp': formattedTime,
      },
    );
  }

  Future<List<Map<String, dynamic>>> getAuditLogs() async {
    final db = await database;
    return await db.query('alarm_audit_logs', orderBy: 'id DESC');
  }

  Future<int> clearAuditLogs() async {
    final db = await database;
    return await db.delete('alarm_audit_logs');
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
