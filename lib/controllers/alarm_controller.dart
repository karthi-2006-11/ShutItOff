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

  List<Map<String, dynamic>> alarms = [];
  ReceivePort? _receivePort;

  final SocketHub socketHub = SocketHub();
  final NetworkDiscoveryService discoveryService = NetworkDiscoveryService();

  Future<void> initialize() async {
    _setupIsolateListener();
    _setupSocketListener();
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
        // STEP 4 Requirement: If "REMOTE_DISMISS" is received, kill audio loop immediately
        final id = payload['alarm_id'] as int? ?? activeRingingAlarmId ?? 0;
        turnOffLocalAlarm(id);
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

        // STEP 4: Inside execution callback, push out "ALARM_RINGING" over active socket connections
        socketHub.hostSocketServer().then((_) {
          socketHub.broadcastAlarmRinging(id);
        });

        notifyListeners();
      }
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

  @override
  void dispose() {
    _receivePort?.close();
    IsolateNameServer.removePortNameMapping(AlarmService.isolatePortName);
    socketHub.dispose();
    discoveryService.dispose();
    super.dispose();
  }
}
