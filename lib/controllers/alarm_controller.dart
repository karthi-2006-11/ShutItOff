import 'dart:async';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

  // Real-Time Schedule Sync & Preemptive Skip Contracts
  static const String eventAlarmSyncList = "ALARM_SYNC_LIST";
  static const String eventPreemptiveSkip = "PREEMPTIVE_SKIP";
  Map<String, List<Map<String, dynamic>>> remotePeerAlarmSchedules = {};

  // Native Android External System Alarm Detection & Cheat Exposure
  static const String eventSystemAlarmAlert = "SYSTEM_ALARM_ALERT";
  static const MethodChannel _permissionsChannel = MethodChannel('com.example.shutitoff/permissions');
  String? localSystemAlarmTime;
  Map<String, String> peerCheaterSystemAlarms = {};
  Timer? _systemAlarmTimer;

  // Protocol Version Check Guard
  static const String currentProtocolVersion = "1.1.0";
  static const String eventVersionCheck = "VERSION_CHECK";
  Map<String, String> peerProtocolStatus = {};
  Map<String, String> peerVersions = {};

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

    socketHub.onClientConnected = (_) {
      socketHub.sendVersionCheck(currentProtocolVersion, activeRoom?['room_name'] ?? 'Host');
      broadcastAlarmSync();
      if (localSystemAlarmTime != null) {
        broadcastSystemAlarmAlert(localSystemAlarmTime!);
      }
    };

    discoveryService.onPeerDiscovered = (peer) {
      socketHub.connectToPeer(peer.ipAddress, port: peer.port).then((connected) {
        if (connected) {
          socketHub.sendVersionCheck(currentProtocolVersion, activeRoom?['room_name'] ?? 'Host');
          broadcastAlarmSync();
          if (localSystemAlarmTime != null) {
            broadcastSystemAlarmAlert(localSystemAlarmTime!);
          }
        }
      });
    };

    await checkLocalSystemAlarmAndBroadcast();
    _systemAlarmTimer?.cancel();
    _systemAlarmTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      checkLocalSystemAlarmAndBroadcast();
    });
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
      } else if (event == SocketHub.eventAlarmSyncList || event == eventAlarmSyncList) {
        final rawList = payload['alarms'] as List<dynamic>? ?? [];
        final sender = payload['sender_name'] as String? ??
            socketHub.connectedPeerIp ??
            'Roommate';
        final parsedAlarms = rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        remotePeerAlarmSchedules[sender] = parsedAlarms;
        remotePeerAlarmSchedules['default'] = parsedAlarms;
        notifyListeners();
      } else if (event == SocketHub.eventPreemptiveSkip || event == eventPreemptiveSkip) {
        final id = payload['alarm_id'] as int?;
        final actor = payload['actor_name'] as String? ?? 'Roommate';
        if (id != null) {
          handlePreemptiveSkip(id, actorName: actor);
        }
      } else if (event == SocketHub.eventSystemAlarmAlert || event == eventSystemAlarmAlert) {
        final alarmTime = payload['alarm_time'] as String? ?? '';
        final sender = payload['friend_name'] as String? ??
            payload['sender_name'] as String? ??
            socketHub.connectedPeerIp ??
            'Roommate';
        if (alarmTime.isNotEmpty && isWithinMorningWindow(alarmTime)) {
          peerCheaterSystemAlarms[sender] = alarmTime;
          peerCheaterSystemAlarms['default'] = alarmTime;
          if (socketHub.connectedPeerIp != null) {
            peerCheaterSystemAlarms[socketHub.connectedPeerIp!] = alarmTime;
          }
        } else {
          peerCheaterSystemAlarms.remove(sender);
          peerCheaterSystemAlarms.remove('default');
          if (socketHub.connectedPeerIp != null) {
            peerCheaterSystemAlarms.remove(socketHub.connectedPeerIp!);
          }
        }
        notifyListeners();
      } else if (event == SocketHub.eventVersionCheck || event == eventVersionCheck) {
        final version = payload['version'] as String? ?? '1.0.0';
        final sender = payload['friend_name'] as String? ??
            payload['sender_name'] as String? ??
            socketHub.connectedPeerIp ??
            'Roommate';
        peerVersions[sender] = version;
        peerVersions['default'] = version;
        if (isVersionOlder(version, currentProtocolVersion)) {
          peerProtocolStatus[sender] = "OUTDATED_PROTOCOL";
          peerProtocolStatus['default'] = "OUTDATED_PROTOCOL";
          if (socketHub.connectedPeerIp != null) {
            peerProtocolStatus[socketHub.connectedPeerIp!] = "OUTDATED_PROTOCOL";
          }
        } else {
          peerProtocolStatus[sender] = "VALID";
          peerProtocolStatus['default'] = "VALID";
          if (socketHub.connectedPeerIp != null) {
            peerProtocolStatus[socketHub.connectedPeerIp!] = "VALID";
          }
        }
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
    broadcastAlarmSync();
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
    broadcastAlarmSync();
  }

  Future<void> deleteAlarm(int id) async {
    if (activeRingingAlarmId == id) {
      turnOffLocalAlarm(id);
    }
    await AlarmService.cancelAlarm(id);
    await DBHelper.instance.deleteAlarm(id);
    await loadAlarms();
    broadcastAlarmSync();
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

  void broadcastAlarmSync() {
    socketHub.broadcastAlarmSyncList(
      alarms,
      senderName: activeRoom?['room_name'] ?? 'Host',
    );
  }

  Future<void> handlePreemptiveSkip(int id, {String? actorName}) async {
    final actor = actorName ?? 'Roommate';

    try {
      await DBHelper.instance.insertAuditLog(id, actor, 'PREEMPTIVE_SKIP');
      await loadAuditLogs();
    } catch (_) {}

    await AlarmService.cancelAlarm(id);

    final alarm = await DBHelper.instance.getAlarm(id);
    if (alarm != null && alarm['is_enabled'] == 1) {
      final alarmTimeStr = alarm['alarm_time'] as String;
      final tomorrowTime = computeNextAlarmTime(alarmTimeStr, forceNextDay: true);
      await AlarmService.scheduleAlarm(id: id, targetTime: tomorrowTime);
    }

    if (activeRingingAlarmId == id) {
      turnOffLocalAlarm(id, actorName: actor, logAction: false);
    }

    broadcastAlarmSync();
    notifyListeners();
  }

  void sendPreemptiveSkipCommand(int alarmId, {String? actorName}) {
    final actor = actorName ?? 'Roommate';
    socketHub.sendPreemptiveSkip(alarmId, actor);
  }

  String getNextPeerAlarmDisplay([String? peerKey]) {
    List<Map<String, dynamic>>? peerAlarms;
    if (peerKey != null && remotePeerAlarmSchedules.containsKey(peerKey)) {
      peerAlarms = remotePeerAlarmSchedules[peerKey];
    } else if (remotePeerAlarmSchedules.containsKey('default')) {
      peerAlarms = remotePeerAlarmSchedules['default'];
    } else if (remotePeerAlarmSchedules.isNotEmpty) {
      peerAlarms = remotePeerAlarmSchedules.values.first;
    }

    if (peerAlarms != null && peerAlarms.isNotEmpty) {
      final enabledAlarms = peerAlarms.where((a) => a['is_enabled'] == 1).toList();
      if (enabledAlarms.isNotEmpty) {
        final timeStr = enabledAlarms.first['alarm_time'] as String? ?? '06:00';
        return _formatAlarmTime(timeStr);
      }
    }
    return '06:00 AM';
  }

  int getNextPeerAlarmId([String? peerKey]) {
    List<Map<String, dynamic>>? peerAlarms;
    if (peerKey != null && remotePeerAlarmSchedules.containsKey(peerKey)) {
      peerAlarms = remotePeerAlarmSchedules[peerKey];
    } else if (remotePeerAlarmSchedules.containsKey('default')) {
      peerAlarms = remotePeerAlarmSchedules['default'];
    } else if (remotePeerAlarmSchedules.isNotEmpty) {
      peerAlarms = remotePeerAlarmSchedules.values.first;
    }

    if (peerAlarms != null && peerAlarms.isNotEmpty) {
      final enabledAlarms = peerAlarms.where((a) => a['is_enabled'] == 1).toList();
      if (enabledAlarms.isNotEmpty) {
        return enabledAlarms.first['id'] as int? ?? 1;
      }
      return peerAlarms.first['id'] as int? ?? 1;
    }
    return 1;
  }

  String _formatAlarmTime(String rawTime) {
    try {
      final parts = rawTime.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final period = hour >= 12 ? 'PM' : 'AM';
      final formattedHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '${formattedHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
    } catch (_) {
      return '$rawTime AM';
    }
  }

  static bool isWithinMorningWindow(String? timeStr) {
    if (timeStr == null || timeStr.trim().isEmpty) return false;
    try {
      final parts = timeStr.trim().split(' ');
      if (parts.length < 2) return false;
      final timeParts = parts[0].split(':');
      var hour = int.parse(timeParts[0]);
      final period = parts[1].toUpperCase();
      if (period == 'PM' && hour != 12) {
        hour += 12;
      } else if (period == 'AM' && hour == 12) {
        hour = 0;
      }
      return hour >= 4 && hour <= 7;
    } catch (_) {
      return false;
    }
  }

  Future<void> checkLocalSystemAlarmAndBroadcast() async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final String? result = await _permissionsChannel.invokeMethod<String>('getNextSystemAlarmClock');
        final formatted = (result != null && result.isNotEmpty && isWithinMorningWindow(result))
            ? result
            : null;
        if (formatted != localSystemAlarmTime) {
          localSystemAlarmTime = formatted;
          notifyListeners();
          if (localSystemAlarmTime != null) {
            broadcastSystemAlarmAlert(localSystemAlarmTime!);
          } else {
            socketHub.broadcastSystemAlarmAlert('');
          }
        }
      }
    } catch (e) {
      debugPrint('[AlarmController] System alarm check error: $e');
    }
  }

  void broadcastSystemAlarmAlert(String alarmTime) {
    final senderName = activeRoom?['room_name'] ?? 'Host';
    if (alarmTime.isNotEmpty && !isWithinMorningWindow(alarmTime)) {
      socketHub.broadcastSystemAlarmAlert('', friendName: senderName);
      return;
    }
    socketHub.broadcastSystemAlarmAlert(alarmTime, friendName: senderName);
  }

  String? getCheaterSystemAlarm([String? peerKey]) {
    if (peerKey != null && peerCheaterSystemAlarms.containsKey(peerKey)) {
      return peerCheaterSystemAlarms[peerKey];
    }
    if (peerKey != null) {
      for (final entry in peerCheaterSystemAlarms.entries) {
        if (entry.key.toLowerCase() == peerKey.toLowerCase()) {
          return entry.value;
        }
      }
    }
    if (peerCheaterSystemAlarms.containsKey('default')) {
      return peerCheaterSystemAlarms['default'];
    }
    if (peerCheaterSystemAlarms.isNotEmpty) {
      return peerCheaterSystemAlarms.values.first;
    }
    return null;
  }

  static bool isVersionOlder(String peerVer, String targetVer) {
    try {
      final peerParts = peerVer.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final targetParts = targetVer.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      while (peerParts.length < targetParts.length) {
        peerParts.add(0);
      }
      while (targetParts.length < peerParts.length) {
        targetParts.add(0);
      }
      for (int i = 0; i < targetParts.length; i++) {
        if (peerParts[i] < targetParts[i]) return true;
        if (peerParts[i] > targetParts[i]) return false;
      }
      return false;
    } catch (_) {
      return true;
    }
  }

  bool isPeerOutdated([String? peerKey]) {
    if (peerKey != null && peerProtocolStatus.containsKey(peerKey)) {
      return peerProtocolStatus[peerKey] == "OUTDATED_PROTOCOL";
    }
    if (peerKey != null) {
      for (final entry in peerProtocolStatus.entries) {
        if (entry.key.toLowerCase() == peerKey.toLowerCase()) {
          return entry.value == "OUTDATED_PROTOCOL";
        }
      }
    }
    if (peerProtocolStatus.containsKey('default')) {
      return peerProtocolStatus['default'] == "OUTDATED_PROTOCOL";
    }
    return false;
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
    _systemAlarmTimer?.cancel();
    _escalationTimer?.cancel();
    _receivePort?.close();
    IsolateNameServer.removePortNameMapping(AlarmService.isolatePortName);
    IsolateNameServer.removePortNameMapping('shutitoff_background_cmd_port');
    socketHub.dispose();
    discoveryService.dispose();
    super.dispose();
  }
}
