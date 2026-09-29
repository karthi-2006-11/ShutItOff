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

  List<Map<String, dynamic>> alarms = [];
  ReceivePort? _receivePort;

  final SocketHub socketHub = SocketHub();
  final NetworkDiscoveryService discoveryService = NetworkDiscoveryService();

  AlarmController() {
    _setupSocketListener();
  }

  Future<void> initialize() async {
    _setupIsolateListener();
    await loadAlarms();
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
        turnOffLocalAlarm(id);
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

        // Step 1: Start 60-second watchdog counter loop the exact instant alarm fires
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
      // Step 1 & 2: When crossing 60 seconds, broadcast "ALARM_ESCALATED"
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

  void turnOffLocalAlarm(int id) {
    _escalationTimer?.cancel();
    _escalationTimer = null;
    ringingDurationSeconds = 0;
    isEscalated = false;
    escalatedFriendName = null;

    AlarmService.stopRingtone();
    AlarmService.cancelNotification(id);
    isCurrentlyRinging = false;
    activeRingingAlarmId = null;

    // Send REMOTE_DISMISS notification across network & stop server
    socketHub.sendRemoteDismiss(id);
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

  void snoozeLocalAlarm(int id, int minutes) {
    _escalationTimer?.cancel();
    _escalationTimer = null;
    ringingDurationSeconds = 0;
    isEscalated = false;
    escalatedFriendName = null;

    AlarmService.stopRingtone();
    AlarmService.cancelNotification(id);
    isCurrentlyRinging = false;
    activeRingingAlarmId = null;

    socketHub.stopServer();

    final targetTime = DateTime.now().add(Duration(minutes: minutes));
    AlarmService.scheduleAlarm(id: id, targetTime: targetTime);

    notifyListeners();
  }

  void triggerRemoteDismiss(int id) {
    socketHub.sendRemoteDismiss(id);
  }

  /// Roommate taps [WAKE HIM] to force max volume frantic mode on host phone
  void sendForceWakeCommand([int? alarmId]) {
    socketHub.sendForceWake(alarmId ?? activeRingingAlarmId);
  }

  @override
  void dispose() {
    _escalationTimer?.cancel();
    _receivePort?.close();
    IsolateNameServer.removePortNameMapping(AlarmService.isolatePortName);
    socketHub.dispose();
    discoveryService.dispose();
    super.dispose();
  }
}
