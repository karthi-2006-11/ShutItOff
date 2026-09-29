import 'package:flutter/material.dart';
import '../controllers/alarm_controller.dart';
import '../theme/app_theme.dart';

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
          dotColor = AppTheme.neonCyan;
          final ip = socketHub.connectedPeerIp ?? 'Roommate IP';
          statusText = '[Tethered to $ip]';
        } else if (socketHub.isServerRunning) {
          dotColor = AppTheme.neonCyan;
          statusText = '[Hosting Alarm Sync: Port 8080]';
        } else if (discovery.isBrowsing) {
          dotColor = AppTheme.warningAmber;
          statusText = '[Scanning Subnet...]';
        } else {
          dotColor = AppTheme.alarmOrange;
          statusText = '[Offline - Check Wi-Fi]';
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.cardWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.starkBlack, width: 2.0),
            boxShadow: const [
              BoxShadow(
                color: AppTheme.starkBlack,
                offset: Offset(3, 3),
                blurRadius: 0,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.starkBlack, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: dotColor.withValues(alpha: 0.6),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        statusText,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'serif',
                          color: AppTheme.starkBlack,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: onScanTap,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.starkBlack,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.starkBlack, width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (discovery.isBrowsing)
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      else
                        const Icon(
                          Icons.radar,
                          size: 14,
                          color: Colors.white,
                        ),
                      const SizedBox(width: 6),
                      const Text(
                        'SCAN',
                        style: TextStyle(
                          fontFamily: 'serif',
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
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
