import 'package:flutter/foundation.dart';
import '../data/db_helper.dart';
import '../models/pairing_handshake.dart';

class PermissionController extends ChangeNotifier {
  List<PairingSession> pairedDevices = [];

  // Hardcoded immutable security policy constants
  static const Set<String> _blockedRemoteActions = {
    'CREATE_ALARM',
    'UPDATE_ALARM',
    'DELETE_ALARM',
    'MODIFY_BASE_TIME',
    'READ_DATABASE_FILES',
    'DUMP_TABLES',
  };

  Future<void> loadPairedDevices() async {
    final rows = await DBHelper.instance.getPairedDevices();
    pairedDevices = rows.map((r) => PairingSession.fromMap(r)).toList();
    notifyListeners();
  }

  Future<int> registerPairing(PairingSession session) async {
    final id = await DBHelper.instance.insertPairing(session.toMap());
    await loadPairedDevices();
    return id;
  }

  Future<void> revokeDevice(int pairedDeviceId) async {
    await DBHelper.instance.revokeAuthorization(pairedDeviceId);
    await loadPairedDevices();
  }

  /// Synchronous permission check against currently loaded session cache
  bool verifyCanExecuteTurnOff(int pairedDeviceId) {
    final match = pairedDevices.where((device) => device.id == pairedDeviceId);
    if (match.isEmpty) return false;
    final device = match.first;
    return device.isAuthorized && device.canTurnOff;
  }

  /// Synchronous permission check against currently loaded session cache
  bool verifyCanExecuteSnooze(int pairedDeviceId) {
    final match = pairedDevices.where((device) => device.id == pairedDeviceId);
    if (match.isEmpty) return false;
    final device = match.first;
    return device.isAuthorized && device.canSnooze;
  }

  /// Direct database safety check for Turn Off
  Future<bool> verifyCanExecuteTurnOffFromDb(int pairedDeviceId) async {
    final row = await DBHelper.instance.getPairedDevice(pairedDeviceId);
    if (row == null) return false;
    final isAuthorized = (row['is_authorized'] as int? ?? 0) == 1;
    final canTurnOff = (row['can_turn_off'] as int? ?? 0) == 1;
    return isAuthorized && canTurnOff;
  }

  /// Direct database safety check for Snooze
  Future<bool> verifyCanExecuteSnoozeFromDb(int pairedDeviceId) async {
    final row = await DBHelper.instance.getPairedDevice(pairedDeviceId);
    if (row == null) return false;
    final isAuthorized = (row['is_authorized'] as int? ?? 0) == 1;
    final canSnooze = (row['can_snooze'] as int? ?? 0) == 1;
    return isAuthorized && canSnooze;
  }

  // --- HARDCODED PROTOCOL SAFETY BLOCKS ---
  // Any remote instruction attempting to create, update, or completely delete
  // the Sleeper's core custom_alarms runtime table array parameters is strictly blocked.

  bool canChangeBaseTime(int pairedDeviceId) => false;

  bool canReadDatabaseFiles(int pairedDeviceId) => false;

  bool canAlterAlarmTable(int pairedDeviceId) => false;

  /// Comprehensive gatekeeper for incoming remote actions.
  /// Strictly prevents unauthorized operations or database tampering.
  bool validateRemoteInstruction({
    required int pairedDeviceId,
    required String action,
  }) {
    final normalizedAction = action.trim().toUpperCase();

    // 1. Strictly block any tampering with custom_alarms or database access
    if (_blockedRemoteActions.contains(normalizedAction)) {
      return false;
    }

    // 2. Validate authorized actions against permissions
    switch (normalizedAction) {
      case 'TURN_OFF':
        return verifyCanExecuteTurnOff(pairedDeviceId);
      case 'SNOOZE':
        return verifyCanExecuteSnooze(pairedDeviceId);
      default:
        // Unknown or unspecified actions are rejected by default
        return false;
    }
  }
}
