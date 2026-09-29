import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shutitoff/controllers/alarm_controller.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    databaseFactory = databaseFactorySqflitePlugin;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('com.tekartik.sqflite'),
            (MethodCall methodCall) async {
      if (methodCall.method == 'getDatabasesPath') {
        return '.';
      }
      if (methodCall.method == 'openDatabase') {
        return 1;
      }
      if (methodCall.method == 'query') {
        return <Map<String, dynamic>>[];
      }
      if (methodCall.method == 'insert') {
        return 1;
      }
      if (methodCall.method == 'delete') {
        return 0;
      }
      return null;
    });
  });

  group('AlarmController Unit Tests', () {
    late AlarmController controller;

    setUp(() {
      controller = AlarmController();
    });

    test('Initial state of AlarmController is inactive', () {
      expect(controller.isCurrentlyRinging, isFalse);
      expect(controller.activeRingingAlarmId, isNull);
      expect(controller.alarms, isEmpty);
    });

    test('computeNextAlarmTime calculates next valid occurrence', () {
      final now = DateTime.now();
      final targetHour = (now.hour + 1) % 24;
      final targetTimeStr =
          '${targetHour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      final scheduled = controller.computeNextAlarmTime(targetTimeStr);
      expect(scheduled.hour, equals(targetHour));
      expect(scheduled.minute, equals(now.minute));
    });

    test('turnOffLocalAlarm terminates ringing state and clears active alarm id', () {
      controller.isCurrentlyRinging = true;
      controller.activeRingingAlarmId = 42;

      controller.turnOffLocalAlarm(42);

      expect(controller.isCurrentlyRinging, isFalse);
      expect(controller.activeRingingAlarmId, isNull);
    });

    test('snoozeLocalAlarm clears ringing state and schedules snooze instance', () {
      controller.isCurrentlyRinging = true;
      controller.activeRingingAlarmId = 99;

      controller.snoozeLocalAlarm(99, 5);

      expect(controller.isCurrentlyRinging, isFalse);
      expect(controller.activeRingingAlarmId, isNull);
    });

    test('isWithinMorningWindow evaluates minute-by-minute 4:00 AM - 7:00 AM window', () {
      // Standard formatted strings
      expect(AlarmController.isWithinMorningWindow('06:30 AM'), isTrue);
      expect(AlarmController.isWithinMorningWindow('04:01 AM'), isTrue);
      expect(AlarmController.isWithinMorningWindow('04:00 AM'), isTrue);
      expect(AlarmController.isWithinMorningWindow('07:00 AM'), isTrue);
      expect(AlarmController.isWithinMorningWindow('11:00 PM'), isFalse);
      expect(AlarmController.isWithinMorningWindow('07:01 AM'), isFalse);
      expect(AlarmController.isWithinMorningWindow('03:59 AM'), isFalse);
      expect(AlarmController.isWithinMorningWindow(''), isFalse);
      expect(AlarmController.isWithinMorningWindow(null), isFalse);

      // Comma-separated strings from Kotlin method channel (hour24,minute,formattedTime)
      expect(AlarmController.isWithinMorningWindow('6,30,06:30 AM'), isTrue);
      expect(AlarmController.isWithinMorningWindow('4,1,04:01 AM'), isTrue);
      expect(AlarmController.isWithinMorningWindow('4,0,04:00 AM'), isTrue);
      expect(AlarmController.isWithinMorningWindow('7,0,07:00 AM'), isTrue);
      expect(AlarmController.isWithinMorningWindow('7,1,07:01 AM'), isFalse);
      expect(AlarmController.isWithinMorningWindow('23,0,11:00 PM'), isFalse);
      expect(AlarmController.isWithinMorningWindow('3,59,03:59 AM'), isFalse);

      final parsed = AlarmController.parseSystemAlarmString('6,30,06:30 AM');
      expect(parsed.isCheating, isTrue);
      expect(parsed.formattedTime, equals('06:30 AM'));
    });
  });
}
