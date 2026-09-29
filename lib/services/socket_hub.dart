import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

enum NetworkConnectionState {
  offline,
  scanning,
  connectedToPeer,
  hostingServer,
}

class SocketHub extends ChangeNotifier {
  static const int defaultPort = 8080;
  static const String eventAlarmRinging = 'ALARM_RINGING';
  static const String eventRemoteDismiss = 'REMOTE_DISMISS';
  static const String eventRemoteSnooze = 'REMOTE_SNOOZE';
  static const String eventAlarmEscalated = 'ALARM_ESCALATED';
  static const String eventForceWake = 'FORCE_WAKE';

  HttpServer? _server;
  // Step 2 Requirement: Active tracker array list maintaining multi-client connections
  final List<WebSocket> _connectedClients = [];
  WebSocket? _peerSocket;

  bool isServerRunning = false;
  bool isConnectedToPeer = false;
  String? connectedPeerIp;

  int get connectedClientCount => _connectedClients.length;
  List<WebSocket> get connectedClients => List.unmodifiable(_connectedClients);

  void Function(String event, Map<String, dynamic> payload)? onEventReceived;

  NetworkConnectionState get connectionState {
    if (isConnectedToPeer) return NetworkConnectionState.connectedToPeer;
    if (isServerRunning) return NetworkConnectionState.hostingServer;
    return NetworkConnectionState.offline;
  }

  Future<void> hostSocketServer({int port = defaultPort}) async {
    if (_server != null) return;

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      isServerRunning = true;
      notifyListeners();

      _server!.listen(
        (HttpRequest request) async {
          if (WebSocketTransformer.isUpgradeRequest(request)) {
            try {
              final socket = await WebSocketTransformer.upgrade(request);
              // Capture and track incoming multi-client connection
              _connectedClients.add(socket);
              notifyListeners();

              // Immediately sync active alarm state to newly tethered roommate
              final initialPayload = {
                'event': eventAlarmRinging,
                'timestamp': DateTime.now().toIso8601String(),
              };
              socket.add(jsonEncode(initialPayload));

              socket.listen(
                (dynamic data) => _handleIncomingData(data),
                onDone: () {
                  // Cleanse list automatically when a socket drops out
                  _connectedClients.remove(socket);
                  notifyListeners();
                },
                onError: (_) {
                  _connectedClients.remove(socket);
                  notifyListeners();
                },
              );
            } catch (_) {}
          } else {
            request.response.statusCode = HttpStatus.forbidden;
            await request.response.close();
          }
        },
        onError: (dynamic error) {
          debugPrint('[SocketHub] Server error: $error');
        },
      );
    } catch (e) {
      debugPrint('[SocketHub] Could not host socket server: $e');
    }
  }

  Future<bool> connectToPeer(String ipAddress, {int port = defaultPort}) async {
    await disconnectFromPeer();

    try {
      final uri = 'ws://$ipAddress:$port';
      _peerSocket = await WebSocket.connect(uri).timeout(const Duration(seconds: 4));
      isConnectedToPeer = true;
      connectedPeerIp = ipAddress;
      notifyListeners();

      _peerSocket!.listen(
        (dynamic data) => _handleIncomingData(data),
        onDone: () {
          isConnectedToPeer = false;
          connectedPeerIp = null;
          notifyListeners();
        },
        onError: (_) {
          isConnectedToPeer = false;
          connectedPeerIp = null;
          notifyListeners();
        },
      );
      return true;
    } catch (e) {
      debugPrint('[SocketHub] Failed to connect to $ipAddress: $e');
      isConnectedToPeer = false;
      connectedPeerIp = null;
      notifyListeners();
      return false;
    }
  }

  void broadcastAlarmRinging([int? alarmId]) {
    final payload = {
      'event': eventAlarmRinging,
      'alarm_id': alarmId,
      'timestamp': DateTime.now().toIso8601String(),
    };
    _sendJsonPayload(payload);
  }

  void sendRemoteDismiss([int? alarmId, String? actorName]) {
    final payload = {
      'event': eventRemoteDismiss,
      'alarm_id': alarmId,
      'actor_name': ?actorName,
      'timestamp': DateTime.now().toIso8601String(),
    };
    _sendJsonPayload(payload);
  }

  void sendRemoteSnooze([int? alarmId, String? actorName, int minutes = 5]) {
    final payload = {
      'event': eventRemoteSnooze,
      'alarm_id': alarmId,
      'actor_name': ?actorName,
      'minutes': minutes,
      'timestamp': DateTime.now().toIso8601String(),
    };
    _sendJsonPayload(payload);
  }

  void broadcastAlarmEscalated({int? alarmId, String? friendName}) {
    final payload = {
      'event': eventAlarmEscalated,
      'alarm_id': alarmId,
      'friend_name': ?friendName,
      'timestamp': DateTime.now().toIso8601String(),
    };
    _sendJsonPayload(payload);
  }

  void sendForceWake([int? alarmId]) {
    final payload = {
      'event': eventForceWake,
      'alarm_id': alarmId,
      'timestamp': DateTime.now().toIso8601String(),
    };
    _sendJsonPayload(payload);
  }

  void _sendJsonPayload(Map<String, dynamic> payload) {
    final encoded = jsonEncode(payload);

    // Send to peer if we are connected as client
    if (_peerSocket != null && _peerSocket!.readyState == WebSocket.open) {
      _peerSocket!.add(encoded);
    }

    // Step 2 Requirement: Concurrently broadcast to all active multi-client array connections
    final activeClients = List<WebSocket>.from(_connectedClients);
    for (final client in activeClients) {
      if (client.readyState == WebSocket.open) {
        client.add(encoded);
      }
    }
  }

  void _handleIncomingData(dynamic rawData) {
    try {
      final parsed = jsonDecode(rawData.toString()) as Map<String, dynamic>;
      final event = parsed['event'] as String?;

      // STRICT PROTOCOL REQUIREMENT: Listen and act ONLY upon recognized room protocol events
      if (event != null &&
          (event == eventAlarmRinging ||
              event == eventRemoteDismiss ||
              event == eventRemoteSnooze ||
              event == eventAlarmEscalated ||
              event == eventForceWake)) {
        onEventReceived?.call(event, parsed);
      }
    } catch (e) {
      debugPrint('[SocketHub] Invalid payload format: $e');
    }
  }

  Future<void> stopServer() async {
    try {
      final activeClients = List<WebSocket>.from(_connectedClients);
      for (final client in activeClients) {
        await client.close();
      }
      _connectedClients.clear();
      if (_server != null) {
        await _server!.close(force: true);
        _server = null;
      }
      isServerRunning = false;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> disconnectFromPeer() async {
    try {
      if (_peerSocket != null) {
        await _peerSocket!.close();
        _peerSocket = null;
      }
      isConnectedToPeer = false;
      connectedPeerIp = null;
      notifyListeners();
    } catch (_) {}
  }

  bool _isDisposed = false;

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    stopServer();
    disconnectFromPeer();
    super.dispose();
  }
}
