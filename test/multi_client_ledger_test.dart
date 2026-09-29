import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shutitoff/controllers/alarm_controller.dart';
import 'package:shutitoff/screens/hostel_hub_screen.dart';
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

  group('Phase 5: Multi-Client SocketHub & Ledger Tests', () {
    late SocketHub serverHub;
    late SocketHub client1;
    late SocketHub client2;

    setUp(() {
      serverHub = SocketHub();
      client1 = SocketHub();
      client2 = SocketHub();
    });

    tearDown(() async {
      await client1.disconnectFromPeer();
      await client2.disconnectFromPeer();
      await serverHub.stopServer();
      client1.dispose();
      client2.dispose();
      serverHub.dispose();
    });

    test('Server tracks multi-client connection array list dynamically', () async {
      const port = 9310;
      await serverHub.hostSocketServer(port: port);
      expect(serverHub.isServerRunning, isTrue);
      expect(serverHub.connectedClientCount, equals(0));

      // Connect Client 1
      final c1Connected = await client1.connectToPeer('127.0.0.1', port: port);
      expect(c1Connected, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(serverHub.connectedClientCount, equals(1));

      // Connect Client 2
      final c2Connected = await client2.connectToPeer('127.0.0.1', port: port);
      expect(c2Connected, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(serverHub.connectedClientCount, equals(2));
      expect(serverHub.connectedClients.length, equals(2));

      // Disconnect Client 1 -> count drops to 1
      await client1.disconnectFromPeer();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(serverHub.connectedClientCount, equals(1));

      // Disconnect Client 2 -> count drops to 0
      await client2.disconnectFromPeer();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(serverHub.connectedClientCount, equals(0));
    });

    test('Server concurrently broadcasts ALARM_RINGING to all tethered clients', () async {
      const port = 9311;
      await serverHub.hostSocketServer(port: port);

      final c1Completer = Completer<Map<String, dynamic>>();
      final c2Completer = Completer<Map<String, dynamic>>();

      client1.onEventReceived = (event, payload) {
        if (event == SocketHub.eventAlarmRinging && !c1Completer.isCompleted) {
          c1Completer.complete(payload);
        }
      };

      client2.onEventReceived = (event, payload) {
        if (event == SocketHub.eventAlarmRinging && !c2Completer.isCompleted) {
          c2Completer.complete(payload);
        }
      };

      await client1.connectToPeer('127.0.0.1', port: port);
      await client2.connectToPeer('127.0.0.1', port: port);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      serverHub.broadcastAlarmRinging(888);

      final p1 = await c1Completer.future.timeout(const Duration(seconds: 3));
      final p2 = await c2Completer.future.timeout(const Duration(seconds: 3));

      expect(p1['event'], equals(SocketHub.eventAlarmRinging));
      expect(p2['event'], equals(SocketHub.eventAlarmRinging));
    });

    test('Attributed actions REMOTE_DISMISS and REMOTE_SNOOZE transmit actor identity', () async {
      const port = 9312;
      await serverHub.hostSocketServer(port: port);

      final dismissCompleter = Completer<Map<String, dynamic>>();
      final snoozeCompleter = Completer<Map<String, dynamic>>();

      serverHub.onEventReceived = (event, payload) {
        if (event == SocketHub.eventRemoteDismiss && !dismissCompleter.isCompleted) {
          dismissCompleter.complete(payload);
        } else if (event == SocketHub.eventRemoteSnooze && !snoozeCompleter.isCompleted) {
          snoozeCompleter.complete(payload);
        }
      };

      await client1.connectToPeer('127.0.0.1', port: port);
      await client2.connectToPeer('127.0.0.1', port: port);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Client 1 sends REMOTE_DISMISS attributed to "Karthi"
      client1.sendRemoteDismiss(55, 'Karthi');
      final dismissPayload = await dismissCompleter.future.timeout(const Duration(seconds: 3));
      expect(dismissPayload['event'], equals(SocketHub.eventRemoteDismiss));
      expect(dismissPayload['alarm_id'], equals(55));
      expect(dismissPayload['actor_name'], equals('Karthi'));

      // Client 2 sends REMOTE_SNOOZE attributed to "Rahul"
      client2.sendRemoteSnooze(55, 'Rahul', 10);
      final snoozePayload = await snoozeCompleter.future.timeout(const Duration(seconds: 3));
      expect(snoozePayload['event'], equals(SocketHub.eventRemoteSnooze));
      expect(snoozePayload['alarm_id'], equals(55));
      expect(snoozePayload['actor_name'], equals('Rahul'));
      expect(snoozePayload['minutes'], equals(10));
    });
  });

  group('AlarmController Phase 5 Methods & State Tests', () {
    late AlarmController controller;

    setUp(() {
      controller = AlarmController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('Initial audit ledger and room state are safe and empty', () {
      expect(controller.auditLogs, isEmpty);
      expect(controller.activeRoom, isNull);
    });

    test('sendRemoteDismissWithActor delegates properly to socket hub', () {
      expect(() => controller.sendRemoteDismissWithActor(alarmId: 10, actorName: 'Arun'), returnsNormally);
    });

    test('sendRemoteSnoozeWithActor delegates properly to socket hub', () {
      expect(() => controller.sendRemoteSnoozeWithActor(alarmId: 10, actorName: 'Arun', minutes: 7), returnsNormally);
    });
  });

  group('HostelHubScreen Widget Tests', () {
    late AlarmController controller;

    setUp(() {
      controller = AlarmController();
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets('Renders Hostel Hub Ledger components and receipts section', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HostelHubScreen(controller: controller),
        ),
      );
      await tester.pump();

      // Verify Screen Header
      expect(find.text('HOSTEL HUB LEDGER'), findsOneWidget);

      // Verify Component A: Active Room Node Badge
      expect(find.text('🏢 ROOM: '), findsOneWidget);
      expect(find.text('HOST CONNECTION CODE'), findsOneWidget);
      expect(find.text('ROOMMATE PEER NODES'), findsOneWidget);

      // Verify Component B: Action Ledger Receipt Section
      expect(find.text('ACTION LEDGER RECEIPTS'), findsOneWidget);
      expect(find.text('No Deactivation Receipts'), findsOneWidget);
    });
  });
}
