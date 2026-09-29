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

  HttpServer? _server;
  final Set<WebSocket> _serverSockets = {};
  WebSocket? _peerSocket;

  bool isServerRunning = false;
  bool isConnectedToPeer = false;
  String? connectedPeerIp;

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
              _serverSockets.add(socket);

              // Immediately sync active alarm state to newly tethered roommate
              final initialPayload = {
                'event': eventAlarmRinging,
                'timestamp': DateTime.now().toIso8601String(),
              };
              socket.add(jsonEncode(initialPayload));

              socket.listen(
                (dynamic data) => _handleIncomingData(data),
                onDone: () => _serverSockets.remove(socket),
                onError: (_) => _serverSockets.remove(socket),
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

  void sendRemoteDismiss([int? alarmId]) {
    final payload = {
      'event': eventRemoteDismiss,
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

    // Broadcast to all connected clients if we are host
    for (final client in _serverSockets) {
      if (client.readyState == WebSocket.open) {
        client.add(encoded);
      }
    }
  }

  void _handleIncomingData(dynamic rawData) {
    try {
      final parsed = jsonDecode(rawData.toString()) as Map<String, dynamic>;
      final event = parsed['event'] as String?;

      // STRICT PROTOCOL REQUIREMENT: Listen and act ONLY upon ALARM_RINGING and REMOTE_DISMISS
      if (event != null && (event == eventAlarmRinging || event == eventRemoteDismiss)) {
        onEventReceived?.call(event, parsed);
      }
    } catch (e) {
      debugPrint('[SocketHub] Invalid payload format: $e');
    }
  }

  Future<void> stopServer() async {
    try {
      for (final client in _serverSockets) {
        await client.close();
      }
      _serverSockets.clear();
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
