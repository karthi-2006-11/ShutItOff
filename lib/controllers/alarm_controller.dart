import 'dart:async';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import '../data/db_helper.dart';
import '../services/alarm_service.dart';
import '../services/network_discovery.dart';
import '../services/socket_hub.dart';

class AlarmController extends ChangeNotifier {
  bool isCurrentlyRinging = false;
  int? activeRingingAlarmId;

  // Phase 4: Chronological Escalation Engine tracking variables
  int ringingDurationSeconds = 0;
  Timer? _escalationTimer;
  bool isEscalated = false;
  String? escalatedFriendName;

  // Phase 5: Multi-Node Ledger & Shared Group Spaces
  List<Map<String, dynamic>> alarms = [];
  List<Map<String, dynamic>> auditLogs = [];
  Map<String, dynamic>? activeRoom;

  ReceivePort? _receivePort;

  final SocketHub socketHub = SocketHub();
  final NetworkDiscoveryService discoveryService = NetworkDiscoveryService();

  bool _isDisposed = false;

  AlarmController() {
    _setupSocketListener();
  }

  Future<void> initialize() async {
    _setupIsolateListener();
    await loadAlarms();
    await loadAuditLogs();
    await loadActiveRoom();
  }

  void _setupSocketListener() {
    socketHub.onEventReceived = (String event, Map<String, dynamic> payload) {
      if (event == SocketHub.eventAlarmRinging) {
        final id = payload['alarm_id'] as int?;
        isCurrentlyRinging = true;
        activeRingingAlarmId = id;
        notifyListeners();
      } else if (event == SocketHub.eventRemoteDismiss) {
        final id = payload['alarm_id'] as int? ?? activeRingingAlarmId ?? 0;
        final actor = payload['actor_name'] as String? ?? 'Roommate';
        turnOffLocalAlarm(id, actorName: actor, logAction: true);
      } else if (event == SocketHub.eventRemoteSnooze) {
        final id = payload['alarm_id'] as int? ?? activeRingingAlarmId ?? 0;
        final actor = payload['actor_name'] as String? ?? 'Roommate';
        final minutes = payload['minutes'] as int? ?? 5;
        snoozeLocalAlarm(id, minutes, actorName: actor, logAction: true);
      } else if (event == SocketHub.eventAlarmEscalated) {
        // Roommate's client captures ALARM_ESCALATED: activate override UI
        isEscalated = true;
        escalatedFriendName = payload['friend_name'] as String? ?? 'Roommate';
        notifyListeners();
      } else if (event == SocketHub.eventForceWake) {
        // Sleeper captures FORCE_WAKE: immediately force 100% volume and frantic siren loop
        AlarmService.forceMaxVolumeFranticMode();
        notifyListeners();
      }
    };
  }

  void _setupIsolateListener() {
    _receivePort?.close();
    _receivePort = ReceivePort();

    IsolateNameServer.removePortNameMapping(AlarmService.isolatePortName);
    IsolateNameServer.registerPortWithName(
      _receivePort!.sendPort,
      AlarmService.isolatePortName,
    );

    _receivePort!.listen((dynamic message) {
      int? id;
      if (message is Map && message['action'] == 'ALARM_FIRED') {
        id = message['id'] as int?;
      } else if (message is int) {
        id = message;
      }

      if (id != null) {
        isCurrentlyRinging = true;
        activeRingingAlarmId = id;

        // Start 60-second watchdog counter loop the exact instant alarm fires
        _startEscalationWatchdog(id);

        socketHub.hostSocketServer().then((_) {
          socketHub.broadcastAlarmRinging(id);
        });

        notifyListeners();
      }
    });
  }

  void _startEscalationWatchdog(int id) {
    _escalationTimer?.cancel();
    ringingDurationSeconds = 0;
    isEscalated = false;

    _escalationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      ringingDurationSeconds++;
      if (ringingDurationSeconds == 60) {
        isEscalated = true;
        socketHub.broadcastAlarmEscalated(alarmId: id);
      }
      notifyListeners();
    });
  }

  Future<void> loadAlarms() async {
    alarms = await DBHelper.instance.getAlarms();
    notifyListeners();
  }

  Future<void> loadAuditLogs() async {
    auditLogs = await DBHelper.instance.getAuditLogs();
    notifyListeners();
  }

  Future<void> loadActiveRoom() async {
    activeRoom = await DBHelper.instance.getActiveRoom();
    notifyListeners();
  }

  Future<void> clearAuditLogs() async {
    await DBHelper.instance.clearAuditLogs();
    await loadAuditLogs();
  }

  Future<void> createRoom(String roomName, String hostCode) async {
    await DBHelper.instance.createRoom(roomName, hostCode);
    await loadActiveRoom();
  }

  DateTime computeNextAlarmTime(String timeString, {bool forceNextDay = false}) {
    final parts = timeString.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final now = DateTime.now();

    var target = DateTime(now.year, now.month, now.day, hour, minute);
    if (forceNextDay || target.isBefore(now)) {
      target = target.add(const Duration(days: 1));
    }
    return target;
  }

  Future<void> addAlarm(String alarmTime) async {
    final id = await DBHelper.instance.insertAlarm(alarmTime, isEnabled: true);
    final nextTime = computeNextAlarmTime(alarmTime);
    await AlarmService.scheduleAlarm(id: id, targetTime: nextTime);
    await loadAlarms();
  }

  Future<void> toggleAlarm(int id, bool isEnabled) async {
    await DBHelper.instance.updateAlarmStatus(id, isEnabled);
    if (isEnabled) {
      final alarm = await DBHelper.instance.getAlarm(id);
      if (alarm != null) {
        final nextTime = computeNextAlarmTime(alarm['alarm_time'] as String);
        await AlarmService.scheduleAlarm(id: id, targetTime: nextTime);
      }
    } else {
      await AlarmService.cancelAlarm(id);
    }
    await loadAlarms();
  }

  Future<void> deleteAlarm(int id) async {
    if (activeRingingAlarmId == id) {
      turnOffLocalAlarm(id);
    }
    await AlarmService.cancelAlarm(id);
    await DBHelper.instance.deleteAlarm(id);
    await loadAlarms();
  }

  void turnOffLocalAlarm(int id, {String? actorName, bool logAction = true}) {
    _escalationTimer?.cancel();
    _escalationTimer = null;
    ringingDurationSeconds = 0;
    isEscalated = false;
    escalatedFriendName = null;

    final SendPort? bgPort =
        IsolateNameServer.lookupPortByName('shutitoff_background_cmd_port');
    if (bgPort != null) {
      bgPort.send('STOP_AUDIO');
    }

    AlarmService.stopRingtone();
    IsolateNameServer.removePortNameMapping('shutitoff_background_cmd_port');
    AlarmService.cancelNotification(id);
    isCurrentlyRinging = false;
    activeRingingAlarmId = null;

    final actor = actorName ?? 'Host (Self)';

    if (logAction) {
      try {
        DBHelper.instance.insertAuditLog(id, actor, 'DISMISS').then((_) {
          loadAuditLogs();
        }).catchError((_) {});
      } catch (_) {}
    }

    // Send REMOTE_DISMISS notification across network & stop server
    socketHub.sendRemoteDismiss(id, actor);
    socketHub.stopServer();

    final match = alarms.where((element) => element['id'] == id);
    if (match.isNotEmpty) {
      final alarm = match.first;
      if (alarm['is_enabled'] == 1) {
        final nextDayTime = computeNextAlarmTime(
          alarm['alarm_time'] as String,
          forceNextDay: true,
        );
        AlarmService.scheduleAlarm(id: id, targetTime: nextDayTime);
      }
    }

    notifyListeners();
  }

  void snoozeLocalAlarm(int id, int minutes, {String? actorName, bool logAction = true}) {
    _escalationTimer?.cancel();
    _escalationTimer = null;
    ringingDurationSeconds = 0;
    isEscalated = false;
    escalatedFriendName = null;

    final SendPort? bgPort =
        IsolateNameServer.lookupPortByName('shutitoff_background_cmd_port');
    if (bgPort != null) {
      bgPort.send('STOP_AUDIO');
    }

    AlarmService.stopRingtone();
    IsolateNameServer.removePortNameMapping('shutitoff_background_cmd_port');
    AlarmService.cancelNotification(id);
    isCurrentlyRinging = false;
    activeRingingAlarmId = null;

    final actor = actorName ?? 'Host (Self)';

    if (logAction) {
      try {
        DBHelper.instance.insertAuditLog(id, actor, 'SNOOZE').then((_) {
          loadAuditLogs();
        }).catchError((_) {});
      } catch (_) {}
    }

    socketHub.sendRemoteSnooze(id, actor, minutes);
    socketHub.stopServer();

    final targetTime = DateTime.now().add(Duration(minutes: minutes));
    AlarmService.scheduleAlarm(id: id, targetTime: targetTime);

    notifyListeners();
  }

  void triggerRemoteDismiss(int id, [String? actorName]) {
    socketHub.sendRemoteDismiss(id, actorName);
  }

  void triggerRemoteSnooze(int id, [String? actorName, int minutes = 5]) {
    socketHub.sendRemoteSnooze(id, actorName, minutes);
  }

  void sendRemoteDismissWithActor({int? alarmId, required String actorName}) {
    socketHub.sendRemoteDismiss(alarmId ?? activeRingingAlarmId, actorName);
  }

  void sendRemoteSnoozeWithActor({int? alarmId, required String actorName, int minutes = 5}) {
    socketHub.sendRemoteSnooze(alarmId ?? activeRingingAlarmId, actorName, minutes);
  }

  /// Roommate taps [WAKE HIM] to force max volume frantic mode on host phone
  void sendForceWakeCommand([int? alarmId]) {
    socketHub.sendForceWake(alarmId ?? activeRingingAlarmId);
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _escalationTimer?.cancel();
    _receivePort?.close();
    IsolateNameServer.removePortNameMapping(AlarmService.isolatePortName);
    IsolateNameServer.removePortNameMapping('shutitoff_background_cmd_port');
    socketHub.dispose();
    discoveryService.dispose();
    super.dispose();
  }
}
