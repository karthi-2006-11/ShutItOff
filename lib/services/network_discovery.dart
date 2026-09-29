import 'dart:async';
import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/foundation.dart';
import '../data/db_helper.dart';

class DiscoveredPeer {
  final String name;
  final String connectionCode;
  final String ipAddress;
  final int port;

  const DiscoveredPeer({
    required this.name,
    required this.connectionCode,
    required this.ipAddress,
    required this.port,
  });

  @override
  String toString() => '$name ($ipAddress:$port, code: $connectionCode)';
}

class NetworkDiscoveryService extends ChangeNotifier {
  static const String serviceType = '_shutitoff._tcp';
  static const int servicePort = 8080;

  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;
  StreamSubscription<BonsoirBroadcastEvent>? _broadcastSubscription;
  StreamSubscription<BonsoirDiscoveryEvent>? _discoverySubscription;

  bool isAdvertising = false;
  bool isBrowsing = false;
  String? activeBroadcastCode;

  final Map<String, DiscoveredPeer> discoveredPeers = {};

  void Function(DiscoveredPeer peer)? onPeerDiscovered;

  Future<void> startAdvertising(String connectionCode) async {
    await stopAdvertising();

    try {
      activeBroadcastCode = connectionCode;
      final service = BonsoirService(
        name: 'ShutItOff-$connectionCode',
        type: serviceType,
        port: servicePort,
        attributes: {
          'code': connectionCode,
          'app': 'shutitoff',
        },
      );

      _broadcast = BonsoirBroadcast(service: service);
      await _broadcast!.initialize();

      _broadcastSubscription = _broadcast!.eventStream?.listen((event) {
        if (event is BonsoirBroadcastStartedEvent) {
          isAdvertising = true;
          notifyListeners();
        } else if (event is BonsoirBroadcastStoppedEvent) {
          isAdvertising = false;
          notifyListeners();
        }
      });

      await _broadcast!.start();
      isAdvertising = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[NetworkDiscovery] Advertising error: $e');
    }
  }

  Future<void> stopAdvertising() async {
    try {
      await _broadcastSubscription?.cancel();
      _broadcastSubscription = null;
      if (_broadcast != null) {
        await _broadcast!.stop();
        _broadcast = null;
      }
      isAdvertising = false;
      activeBroadcastCode = null;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> startBrowsing() async {
    await stopBrowsing();

    try {
      _discovery = BonsoirDiscovery(type: serviceType);
      await _discovery!.initialize();

      _discoverySubscription = _discovery!.eventStream?.listen((event) async {
        if (event is BonsoirDiscoveryServiceFoundEvent) {
          // Resolve service to determine host IP address
          _discovery?.serviceResolver.resolveService(event.service);
        } else if (event is BonsoirDiscoveryServiceResolvedEvent) {
          final service = event.service;
          final ip = service.hostAddress;
          final code = service.attributes['code'] ?? '';
          final name = service.name;

          if (ip != null && code.isNotEmpty) {
            final peer = DiscoveredPeer(
              name: name,
              connectionCode: code,
              ipAddress: ip,
              port: service.port,
            );

            discoveredPeers[code] = peer;
            notifyListeners();

            // Hook into pairing register if previously authorized
            await _hookIntoPairingRegister(peer);
            onPeerDiscovered?.call(peer);
          }
        } else if (event is BonsoirDiscoveryServiceLostEvent) {
          final code = event.service.attributes['code'];
          if (code != null) {
            discoveredPeers.remove(code);
            notifyListeners();
          }
        }
      });

      await _discovery!.start();
      isBrowsing = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[NetworkDiscovery] Browsing error: $e');
    }
  }

  Future<void> stopBrowsing() async {
    try {
      await _discoverySubscription?.cancel();
      _discoverySubscription = null;
      if (_discovery != null) {
        await _discovery!.stop();
        _discovery = null;
      }
      isBrowsing = false;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _hookIntoPairingRegister(DiscoveredPeer peer) async {
    try {
      final existing = await DBHelper.instance.getPairedDeviceByCode(peer.connectionCode);
      if (existing != null) {
        debugPrint('[NetworkDiscovery] Verified authorized peer online: ${peer.ipAddress}');
      }
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
    stopAdvertising();
    stopBrowsing();
    super.dispose();
  }
}
