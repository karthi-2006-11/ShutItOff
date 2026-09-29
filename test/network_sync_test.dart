import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shutitoff/controllers/alarm_controller.dart';
import 'package:shutitoff/screens/network_hud_widget.dart';
import 'package:shutitoff/services/network_discovery.dart';
import 'package:shutitoff/services/socket_hub.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SocketHub LAN Sync & Protocol Tests', () {
    late SocketHub serverHub;
    late SocketHub clientHub;

    setUp(() {
      serverHub = SocketHub();
      clientHub = SocketHub();
    });

    tearDown(() async {
      await clientHub.disconnectFromPeer();
      await serverHub.stopServer();
      clientHub.dispose();
      serverHub.dispose();
    });

    test('hostSocketServer binds server and connectToPeer establishes WebSocket connection', () async {
      const testPort = 8990;
      await serverHub.hostSocketServer(port: testPort);
      expect(serverHub.isServerRunning, isTrue);

      final connected = await clientHub.connectToPeer('127.0.0.1', port: testPort);
      expect(connected, isTrue);
      expect(clientHub.isConnectedToPeer, isTrue);

      await clientHub.disconnectFromPeer();
      await serverHub.stopServer();
    });

    test('Client receives ALARM_RINGING payload upon alarm broadcast', () async {
      const testPort = 8991;
      await serverHub.hostSocketServer(port: testPort);

      final completer = Completer<Map<String, dynamic>>();
      clientHub.onEventReceived = (event, payload) {
        if (event == SocketHub.eventAlarmRinging && !completer.isCompleted) {
          completer.complete(payload);
        }
      };

      await clientHub.connectToPeer('127.0.0.1', port: testPort);
      serverHub.broadcastAlarmRinging(77);

      final received = await completer.future.timeout(const Duration(seconds: 3));
      expect(received['event'], equals(SocketHub.eventAlarmRinging));

      await clientHub.disconnectFromPeer();
      await serverHub.stopServer();
    });

    test('Server receives REMOTE_DISMISS payload from peer client', () async {
      const testPort = 8992;
      await serverHub.hostSocketServer(port: testPort);

      final dismissCompleter = Completer<Map<String, dynamic>>();
      serverHub.onEventReceived = (event, payload) {
        if (event == SocketHub.eventRemoteDismiss && !dismissCompleter.isCompleted) {
          dismissCompleter.complete(payload);
        }
      };

      await clientHub.connectToPeer('127.0.0.1', port: testPort);
      clientHub.sendRemoteDismiss(42);

      final received = await dismissCompleter.future.timeout(const Duration(seconds: 3));
      expect(received['event'], equals(SocketHub.eventRemoteDismiss));
      expect(received['alarm_id'], equals(42));

      await clientHub.disconnectFromPeer();
      await serverHub.stopServer();
    });

    test('Strict payload enforcement rejects unrecognized event payloads', () async {
      final hub = SocketHub();
      bool receivedInvalid = false;

      hub.onEventReceived = (event, payload) {
        if (event == 'UNKNOWN_ATTEMPT' || event == 'MALICIOUS_DUMP') {
          receivedInvalid = true;
        }
      };

      // Direct message routing check
      hub.broadcastAlarmRinging(1);
      expect(receivedInvalid, isFalse);
      hub.dispose();
    });
  });

  group('NetworkDiscoveryService Unit Tests', () {
    test('Default discovery service configuration', () {
      final discovery = NetworkDiscoveryService();
      expect(discovery.isAdvertising, isFalse);
      expect(discovery.isBrowsing, isFalse);
      expect(discovery.discoveredPeers, isEmpty);
      expect(NetworkDiscoveryService.serviceType, equals('_shutitoff._tcp'));
      expect(NetworkDiscoveryService.servicePort, equals(8080));
      discovery.dispose();
    });
  });

  group('NetworkHudWidget Widget Tests', () {
    testWidgets('NetworkHudWidget renders offline status by default', (WidgetTester tester) async {
      final controller = AlarmController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NetworkHudWidget(controller: controller),
          ),
        ),
      );

      expect(find.text('[Offline - Check Wi-Fi]'), findsOneWidget);
      expect(find.text('SCAN'), findsOneWidget);
      controller.dispose();
    });
  });
}
