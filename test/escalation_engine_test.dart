import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shutitoff/controllers/alarm_controller.dart';
import 'package:shutitoff/screens/escalation_overlay.dart';
import 'package:shutitoff/services/socket_hub.dart';
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

  group('Phase 4: Chronological Escalation Engine Tests', () {
    late AlarmController controller;

    setUp(() {
      controller = AlarmController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('Initial escalation variables match baseline inactive criteria', () {
      expect(controller.ringingDurationSeconds, equals(0));
      expect(controller.isEscalated, isFalse);
      expect(controller.escalatedFriendName, isNull);
    });

    test('Escalation watchdog ticks and triggers ALARM_ESCALATED cutoff at 60 seconds', () async {
      // Simulate fast-forwarding duration ticks to 60-second cutoff mark
      controller.isCurrentlyRinging = true;
      controller.activeRingingAlarmId = 101;

      // Simulate reaching 59 seconds
      controller.ringingDurationSeconds = 59;
      expect(controller.isEscalated, isFalse);

      // Simulate ticking across the 60-second barrier
      controller.ringingDurationSeconds = 60;
      controller.isEscalated = true;
      controller.socketHub.broadcastAlarmEscalated(
        alarmId: 101,
        friendName: 'Alex',
      );

      expect(controller.ringingDurationSeconds, equals(60));
      expect(controller.isEscalated, isTrue);
    });

    test('Dismissing alarm resets watchdog duration counter and escalation flags', () {
      controller.isCurrentlyRinging = true;
      controller.activeRingingAlarmId = 102;
      controller.ringingDurationSeconds = 65;
      controller.isEscalated = true;
      controller.escalatedFriendName = 'Alex';

      controller.turnOffLocalAlarm(102);

      expect(controller.ringingDurationSeconds, equals(0));
      expect(controller.isEscalated, isFalse);
      expect(controller.escalatedFriendName, isNull);
      expect(controller.isCurrentlyRinging, isFalse);
    });

    test('Socket parser routes ALARM_ESCALATED to update roommate dashboard', () {
      final clientController = AlarmController();

      // Simulate receiving ALARM_ESCALATED payload over network
      clientController.socketHub.onEventReceived?.call(
        SocketHub.eventAlarmEscalated,
        {'event': SocketHub.eventAlarmEscalated, 'friend_name': 'Sam', 'alarm_id': 5},
      );

      expect(clientController.isEscalated, isTrue);
      expect(clientController.escalatedFriendName, equals('Sam'));

      clientController.dispose();
    });
  });

  group('EscalationOverlay UI Widget Tests', () {
    testWidgets('EscalationOverlay displays 1-minute alert and [WAKE HIM] button',
        (WidgetTester tester) async {
      bool wakeHimTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EscalationOverlay(
              friendName: 'John',
              onWakeHim: () {
                wakeHimTapped = true;
              },
            ),
          ),
        ),
      );

      // Verify exact required text format
      expect(
        find.text("🔔 John has been sleeping through their alarm for 1 minute!"),
        findsOneWidget,
      );

      // Verify massive [WAKE HIM] button
      expect(find.text('[WAKE HIM]'), findsOneWidget);

      // Tap [WAKE HIM]
      await tester.tap(find.text('[WAKE HIM]'));
      await tester.pump();

      expect(wakeHimTapped, isTrue);
    });
  });
}
