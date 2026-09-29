import 'package:flutter/material.dart';
import '../controllers/permission_state_controller.dart';
import '../data/db_helper.dart';
import '../main.dart';
import '../theme/app_theme.dart';

class OnboardingSplashScreen extends StatefulWidget {
  final PermissionStateController? permissionController;
  final VoidCallback? onComplete;

  const OnboardingSplashScreen({
    super.key,
    this.permissionController,
    this.onComplete,
  });

  @override
  State<OnboardingSplashScreen> createState() => _OnboardingSplashScreenState();
}

class _OnboardingSplashScreenState extends State<OnboardingSplashScreen> {
  late final PermissionStateController _controller;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    if (widget.permissionController != null) {
      _controller = widget.permissionController!;
    } else {
      _controller = PermissionStateController();
      _ownsController = true;
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _routeToDashboard() async {
    await DBHelper.instance.setOnboardingComplete(true);
    if (widget.onComplete != null) {
      widget.onComplete!();
    } else if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AlarmHomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final bool showBatteryCard = !_controller.isBatteryUnrestricted;
        final bool showOverlayCard = !_controller.isOverlayAllowed;
        final bool allPermissionsGranted = _controller.areAllPermissionsGranted;

        return Scaffold(
          backgroundColor: AppTheme.creamCanvas,
          appBar: AppBar(
            backgroundColor: AppTheme.creamCanvas,
            elevation: 0,
            title: const Text('SHUT IT OFF'),
            centerTitle: true,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(2.0),
              child: Container(
                color: AppTheme.starkBlack,
                height: 2.0,
              ),
            ),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 8),

                          // Top Warning Graphic Badge
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: allPermissionsGranted
                                    ? AppTheme.neonCyan.withValues(alpha: 0.25)
                                    : AppTheme.alarmOrange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: allPermissionsGranted
                                      ? AppTheme.starkBlack
                                      : AppTheme.alarmOrange,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    allPermissionsGranted
                                        ? Icons.verified_user_outlined
                                        : Icons.warning_amber_rounded,
                                    color: allPermissionsGranted
                                        ? AppTheme.starkBlack
                                        : AppTheme.alarmOrange,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    allPermissionsGranted
                                        ? 'ALL PROTOCOLS VERIFIED'
                                        : 'SYSTEM LIFECYCLE GUARD',
                                    style: TextStyle(
                                      fontFamily: 'serif',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2,
                                      color: allPermissionsGranted
                                          ? AppTheme.starkBlack
                                          : AppTheme.alarmOrange,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Title Header Node
                          const Text(
                            'CRITICAL APP CONFIGURATION SETUP REQUIRED',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'serif',
                              fontWeight: FontWeight.w900,
                              fontSize: 21,
                              letterSpacing: 0.8,
                              color: AppTheme.starkBlack,
                              height: 1.25,
                            ),
                          ),

                          const SizedBox(height: 12),

                          Text(
                            allPermissionsGranted
                                ? 'All native OS hardware permissions have been successfully authorized. You may now proceed into the application.'
                                : 'ShutItOff requires real-time native OS permissions to guarantee alarm delivery across device sleep cycles. Configure each required item below:',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textMuted,
                              height: 1.35,
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Crucial Filtering Rule: Render ONLY missing instruction panels
                          if (showBatteryCard) ...[
                            _buildInstructionCard(
                              icon: Icons.battery_charging_full_outlined,
                              tag: 'PERMISSION REQUIREMENT 01',
                              title: 'Battery Optimization -> Unrestricted Mode',
                              explanation:
                                  'Keeps local Wi-Fi WebSocket background sockets running smoothly while you sleep to capture incoming signals.',
                              actionLabel: '[ CONFIGURE BATTERY SETTINGS ]',
                              onActionPressed: () => _controller.requestBatteryUnrestricted(),
                            ),
                            const SizedBox(height: 16),
                          ],

                          if (showOverlayCard) ...[
                            _buildInstructionCard(
                              icon: Icons.layers_outlined,
                              tag: 'PERMISSION REQUIREMENT 02',
                              title: 'Draw Over Other Apps -> Allowed Mode',
                              explanation:
                                  'Enables 6:00 AM alert panels to light up and wake your phone even when it is completely locked.',
                              actionLabel: '[ ALLOW OVERLAY DRAW RIGHTS ]',
                              onActionPressed: () => _controller.requestOverlayAllowed(),
                            ),
                            const SizedBox(height: 16),
                          ],

                          if (allPermissionsGranted) ...[
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: AppTheme.cardWhite,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppTheme.starkBlack, width: 2.0),
                                boxShadow: const [
                                  BoxShadow(
                                    color: AppTheme.starkBlack,
                                    offset: Offset(3, 3),
                                    blurRadius: 0,
                                  ),
                                ],
                              ),
                              child: const Column(
                                children: [
                                  Icon(Icons.check_circle, color: AppTheme.successGreen, size: 48),
                                  SizedBox(height: 12),
                                  Text(
                                    'HARDWARE PRIVILEGES ACTIVE',
                                    style: TextStyle(
                                      fontFamily: 'serif',
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      color: AppTheme.starkBlack,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'Background sockets and lockscreen alert draw rights are fully operational.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Confirmation Action Button: Exactly "[ I Understand ]"
                  // Hardcoded state: Disabled and visually grayed out until BOTH permissions are true.
                  Container(
                    decoration: BoxDecoration(
                      boxShadow: allPermissionsGranted
                          ? const [
                              BoxShadow(
                                color: AppTheme.starkBlack,
                                offset: Offset(3, 3),
                                blurRadius: 0,
                              ),
                            ]
                          : null,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              allPermissionsGranted ? AppTheme.starkBlack : Colors.grey.shade400,
                          foregroundColor:
                              allPermissionsGranted ? Colors.white : Colors.grey.shade700,
                          disabledBackgroundColor: Colors.grey.shade300,
                          disabledForegroundColor: Colors.grey.shade600,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: allPermissionsGranted ? AppTheme.starkBlack : Colors.grey.shade500,
                              width: 2.0,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onPressed: allPermissionsGranted ? _routeToDashboard : null,
                        child: const Text(
                          '[ I Understand ]',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'serif',
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInstructionCard({
    required IconData icon,
    required String tag,
    required String title,
    required String explanation,
    required String actionLabel,
    required VoidCallback onActionPressed,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.starkBlack, width: 2.0),
        boxShadow: const [
          BoxShadow(
            color: AppTheme.starkBlack,
            offset: Offset(3, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.neonCyan.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.starkBlack, width: 1.5),
                ),
                child: Icon(icon, color: AppTheme.starkBlack, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tag,
                  style: const TextStyle(
                    fontFamily: 'serif',
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    color: AppTheme.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'serif',
              fontWeight: FontWeight.w900,
              fontSize: 15,
              color: AppTheme.starkBlack,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            explanation,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textMuted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: AppTheme.creamCanvas,
                foregroundColor: AppTheme.starkBlack,
                side: const BorderSide(color: AppTheme.starkBlack, width: 2.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: onActionPressed,
              child: Text(
                actionLabel,
                style: const TextStyle(
                  fontFamily: 'serif',
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
