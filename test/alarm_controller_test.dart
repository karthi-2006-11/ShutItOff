import 'package:flutter_test/flutter_test.dart';
import 'package:shutitoff/controllers/alarm_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
  });
}
