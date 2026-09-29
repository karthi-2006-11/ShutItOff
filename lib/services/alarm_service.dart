import 'dart:isolate';
import 'dart:ui';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
void alarmFireCallback(int id) async {
  WidgetsFlutterBinding.ensureInitialized();
  await AlarmService.playRingtone();
  await AlarmService.showAlarmNotification(id);

  final SendPort? sendPort = IsolateNameServer.lookupPortByName(AlarmService.isolatePortName);
  sendPort?.send({'action': 'ALARM_FIRED', 'id': id});
}

class AlarmService {
  static const String isolatePortName = 'shutitoff_alarm_isolate_port';
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  static AudioPlayer? _audioPlayer;

  static Future<void> initialize() async {
    try {
      await AndroidAlarmManager.initialize();
    } catch (_) {}

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    try {
      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          final payload = response.payload;
          if (payload != null) {
            final id = int.tryParse(payload);
            if (id != null) {
              final SendPort? sendPort =
                  IsolateNameServer.lookupPortByName(isolatePortName);
              sendPort?.send({'action': 'ALARM_FIRED', 'id': id});
            }
          }
        },
      );

      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
        await androidImplementation.requestExactAlarmsPermission();
      }
    } catch (_) {}
  }

  static Future<void> playRingtone() async {
    try {
      _audioPlayer ??= AudioPlayer();
      await _audioPlayer!.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer!.setVolume(1.0);
      await _audioPlayer!.play(AssetSource('audio/alarm.mp3'));
    } catch (_) {
      try {
        _audioPlayer ??= AudioPlayer();
        await _audioPlayer!.setReleaseMode(ReleaseMode.loop);
        await _audioPlayer!.play(AssetSource('audio/alarm.wav'));
      } catch (_) {}
    }
  }

  static Future<void> forceMaxVolumeFranticMode() async {
    try {
      _audioPlayer ??= AudioPlayer();
      await _audioPlayer!.setReleaseMode(ReleaseMode.loop);
      // Force audioplayers stream to 1.0 (100% max volume)
      await _audioPlayer!.setVolume(1.0);
      // Toggle tone into frantic max-frequency state (accelerated frantic siren pattern)
      await _audioPlayer!.setPlaybackRate(1.5);
      if (_audioPlayer!.state != PlayerState.playing) {
        await _audioPlayer!.play(AssetSource('audio/alarm.mp3'));
      }
    } catch (_) {
      try {
        await _audioPlayer?.play(AssetSource('audio/alarm.wav'));
      } catch (_) {}
    }
  }

  static Future<void> stopRingtone() async {
    try {
      if (_audioPlayer != null) {
        try {
          await _audioPlayer!.setPlaybackRate(1.0);
        } catch (_) {}
        await _audioPlayer!.stop();
        await _audioPlayer!.dispose();
        _audioPlayer = null;
      }
    } catch (_) {}
  }

  static Future<void> showAlarmNotification(int id) async {
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'shutitoff_alarm_channel_high_v1',
        'ShutItOff Critical Alarms',
        channelDescription: 'High priority overlay alerts for scheduled alarms',
        importance: Importance.max,
        priority: Priority.high,
        fullScreenIntent: true,
        ongoing: true,
        autoCancel: false,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        ticker: 'Alarm Triggered',
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: true,
        interruptionLevel: InterruptionLevel.critical,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.show(
        id: id,
        title: 'ALARM RINGING',
        body: 'Tap to open ShutItOff and take action.',
        notificationDetails: notificationDetails,
        payload: id.toString(),
      );
    } catch (_) {}
  }

  static Future<void> cancelNotification(int id) async {
    try {
      await _notificationsPlugin.cancel(id: id);
    } catch (_) {}
  }

  static Future<void> scheduleAlarm({
    required int id,
    required DateTime targetTime,
  }) async {
    try {
      await AndroidAlarmManager.oneShotAt(
        targetTime,
        id,
        alarmFireCallback,
        exact: true,
        wakeup: true,
        alarmClock: true,
        allowWhileIdle: true,
        rescheduleOnReboot: true,
      );
    } catch (_) {}
  }

  static Future<void> cancelAlarm(int id) async {
    try {
      await AndroidAlarmManager.cancel(id);
    } catch (_) {}
  }
}
