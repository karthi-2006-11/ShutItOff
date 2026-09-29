import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DBHelper {
  static final DBHelper instance = DBHelper._init();
  static Database? _database;

  DBHelper._init();

  // Web fallback storage (enables browser preview without native SQLite plugins)
  final List<Map<String, dynamic>> _webAlarms = [
    {'id': 1, 'alarm_time': '07:00', 'is_enabled': 1},
    {'id': 2, 'alarm_time': '08:30', 'is_enabled': 0},
  ];
  final List<Map<String, dynamic>> _webPairedDevices = [
    {
      'id': 1,
      'friend_name': 'Karthi (Hostel Lead)',
      'connection_code': '482910',
      'is_authorized': 1,
      'can_snooze': 1,
      'can_turn_off': 1,
    }
  ];
  final List<Map<String, dynamic>> _webRooms = [
    {'id': 1, 'room_name': 'B204', 'host_code': '748291'}
  ];
  final List<Map<String, dynamic>> _webAuditLogs = [
    {
      'id': 1,
      'alarm_id': 1,
      'actor_name': 'Karthi',
      'action_type': 'DISMISS',
      'timestamp': '07:02 AM',
    }
  ];
  int _webIdCounter = 10;
  final Map<String, String> _webSettings = {};

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
    await _createSettingsTable(db);
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createPairedDevicesTable(db);
    }
    if (oldVersion < 3) {
      await _createHostelTables(db);
    }
    await _createSettingsTable(db);
  }

  Future<void> _createSettingsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
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
    if (kIsWeb) {
      final newId = ++_webIdCounter;
      _webAlarms.add({
        'id': newId,
        'alarm_time': alarmTime,
        'is_enabled': isEnabled ? 1 : 0,
      });
      return newId;
    }

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
    if (kIsWeb) {
      final copy = List<Map<String, dynamic>>.from(_webAlarms);
      copy.sort((a, b) => (a['alarm_time'] as String).compareTo(b['alarm_time'] as String));
      return copy;
    }

    final db = await database;
    return await db.query('custom_alarms', orderBy: 'alarm_time ASC');
  }

  Future<Map<String, dynamic>?> getAlarm(int id) async {
    if (kIsWeb) {
      return _webAlarms.cast<Map<String, dynamic>?>().firstWhere(
        (element) => element?['id'] == id,
        orElse: () => null,
      );
    }

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
    if (kIsWeb) {
      final idx = _webAlarms.indexWhere((element) => element['id'] == id);
      if (idx != -1) {
        final updated = Map<String, dynamic>.from(_webAlarms[idx]);
        updated['is_enabled'] = isEnabled ? 1 : 0;
        _webAlarms[idx] = updated;
        return 1;
      }
      return 0;
    }

    final db = await database;
    return await db.update(
      'custom_alarms',
      {'is_enabled': isEnabled ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateAlarmTime(int id, String alarmTime) async {
    if (kIsWeb) {
      final idx = _webAlarms.indexWhere((element) => element['id'] == id);
      if (idx != -1) {
        final updated = Map<String, dynamic>.from(_webAlarms[idx]);
        updated['alarm_time'] = alarmTime;
        _webAlarms[idx] = updated;
        return 1;
      }
      return 0;
    }

    final db = await database;
    return await db.update(
      'custom_alarms',
      {'alarm_time': alarmTime},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAlarm(int id) async {
    if (kIsWeb) {
      final count = _webAlarms.where((element) => element['id'] == id).length;
      _webAlarms.removeWhere((element) => element['id'] == id);
      return count;
    }

    final db = await database;
    return await db.delete(
      'custom_alarms',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- paired_devices helper methods ---

  Future<int> insertPairing(Map<String, dynamic> row) async {
    if (kIsWeb) {
      final newId = row['id'] as int? ?? ++_webIdCounter;
      final rowCopy = Map<String, dynamic>.from(row);
      rowCopy['id'] = newId;
      _webPairedDevices.removeWhere((element) => element['connection_code'] == row['connection_code']);
      _webPairedDevices.insert(0, rowCopy);
      return newId;
    }

    final db = await database;
    return await db.insert(
      'paired_devices',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getPairedDevices() async {
    if (kIsWeb) {
      return List<Map<String, dynamic>>.from(_webPairedDevices);
    }

    final db = await database;
    return await db.query('paired_devices', orderBy: 'id DESC');
  }

  Future<Map<String, dynamic>?> getPairedDevice(int id) async {
    if (kIsWeb) {
      return _webPairedDevices.cast<Map<String, dynamic>?>().firstWhere(
        (element) => element?['id'] == id,
        orElse: () => null,
      );
    }

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
    if (kIsWeb) {
      return _webPairedDevices.cast<Map<String, dynamic>?>().firstWhere(
        (element) => element?['connection_code'] == connectionCode,
        orElse: () => null,
      );
    }

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
    if (kIsWeb) {
      final idx = _webPairedDevices.indexWhere((element) => element['id'] == id);
      if (idx != -1) {
        final updated = Map<String, dynamic>.from(_webPairedDevices[idx]);
        updated['is_authorized'] = 0;
        _webPairedDevices[idx] = updated;
        return 1;
      }
      return 0;
    }

    final db = await database;
    return await db.update(
      'paired_devices',
      {'is_authorized': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deletePairing(int id) async {
    if (kIsWeb) {
      final count = _webPairedDevices.where((element) => element['id'] == id).length;
      _webPairedDevices.removeWhere((element) => element['id'] == id);
      return count;
    }

    final db = await database;
    return await db.delete(
      'paired_devices',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Phase 5: hostel_rooms & alarm_audit_logs helper methods ---

  Future<int> createRoom(String roomName, String hostCode) async {
    if (kIsWeb) {
      final newId = ++_webIdCounter;
      _webRooms.insert(0, {
        'id': newId,
        'room_name': roomName,
        'host_code': hostCode,
      });
      return newId;
    }

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
    if (kIsWeb) {
      return List<Map<String, dynamic>>.from(_webRooms);
    }

    final db = await database;
    return await db.query('hostel_rooms', orderBy: 'id DESC');
  }

  Future<Map<String, dynamic>?> getActiveRoom() async {
    if (kIsWeb) {
      return _webRooms.isNotEmpty ? _webRooms.first : null;
    }

    final db = await database;
    final results = await db.query('hostel_rooms', orderBy: 'id DESC', limit: 1);
    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  Future<int> insertAuditLog(int alarmId, String actor, String action) async {
    final now = DateTime.now();
    final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final period = now.hour >= 12 ? 'PM' : 'AM';
    final minuteStr = now.minute.toString().padLeft(2, '0');
    final formattedTime = '${hour.toString().padLeft(2, '0')}:$minuteStr $period';

    if (kIsWeb) {
      final newId = ++_webIdCounter;
      _webAuditLogs.insert(0, {
        'id': newId,
        'alarm_id': alarmId,
        'actor_name': actor,
        'action_type': action,
        'timestamp': formattedTime,
      });
      return newId;
    }

    final db = await database;
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
    if (kIsWeb) {
      return List<Map<String, dynamic>>.from(_webAuditLogs);
    }

    final db = await database;
    return await db.query('alarm_audit_logs', orderBy: 'id DESC');
  }

  Future<int> clearAuditLogs() async {
    if (kIsWeb) {
      final count = _webAuditLogs.length;
      _webAuditLogs.clear();
      return count;
    }

    final db = await database;
    return await db.delete('alarm_audit_logs');
  }

  // --- app_settings helper methods ---

  Future<bool> isOnboardingComplete() async {
    if (kIsWeb) {
      return _webSettings['onboarding_complete'] == 'true';
    }

    final db = await database;
    await _createSettingsTable(db);
    final results = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: ['onboarding_complete'],
      limit: 1,
    );
    if (results.isNotEmpty) {
      return results.first['value'] == 'true';
    }
    return false;
  }

  Future<void> setOnboardingComplete(bool complete) async {
    if (kIsWeb) {
      _webSettings['onboarding_complete'] = complete ? 'true' : 'false';
      return;
    }

    final db = await database;
    await _createSettingsTable(db);
    await db.insert(
      'app_settings',
      {
        'key': 'onboarding_complete',
        'value': complete ? 'true' : 'false',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> close() async {
    if (!kIsWeb && _database != null) {
      final db = await database;
      await db.close();
      _database = null;
    }
  }
}
