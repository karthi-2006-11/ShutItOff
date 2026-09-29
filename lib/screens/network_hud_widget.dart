import 'package:flutter/material.dart';
import '../controllers/alarm_controller.dart';

class NetworkHudWidget extends StatelessWidget {
  final AlarmController controller;
  final VoidCallback? onScanTap;

  const NetworkHudWidget({
    super.key,
    required this.controller,
    this.onScanTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        controller,
        controller.socketHub,
        controller.discoveryService,
      ]),
      builder: (context, _) {
        final socketHub = controller.socketHub;
        final discovery = controller.discoveryService;

        Color dotColor;
        String statusText;

        if (socketHub.isConnectedToPeer) {
          dotColor = const Color(0xFF30D158);
          final ip = socketHub.connectedPeerIp ?? 'Roommate IP';
          statusText = '[Tethered to $ip]';
        } else if (socketHub.isServerRunning) {
          dotColor = const Color(0xFF0A84FF);
          statusText = '[Hosting Alarm Sync: Port 8080]';
        } else if (discovery.isBrowsing) {
          dotColor = const Color(0xFFFF9F0A);
          statusText = '[Scanning Subnet...]';
        } else {
          dotColor = const Color(0xFFFF453A);
          statusText = '[Offline - Check Wi-Fi]';
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF13151D),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: dotColor.withAlpha(60),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: dotColor.withAlpha(150),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: dotColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              if (!socketHub.isConnectedToPeer && !discovery.isBrowsing)
                InkWell(
                  onTap: () {
                    if (onScanTap != null) {
                      onScanTap!();
                    } else {
                      controller.discoveryService.startBrowsing();
                    }
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF222530),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'SCAN',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: Colors.white,
                      ),
                    ),
                  ),
                )
              else if (discovery.isBrowsing)
                InkWell(
                  onTap: () => controller.discoveryService.stopBrowsing(),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF332015),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'STOP',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: Color(0xFFFF9F0A),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
