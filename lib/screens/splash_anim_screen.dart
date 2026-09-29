import 'dart:async';
import 'package:flutter/material.dart';
import '../controllers/permission_state_controller.dart';
import '../data/db_helper.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import 'onboarding_splash_screen.dart';

class SplashAnimScreen extends StatefulWidget {
  const SplashAnimScreen({super.key});

  @override
  State<SplashAnimScreen> createState() => _SplashAnimScreenState();
}

class _SplashAnimScreenState extends State<SplashAnimScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
    _startInitializationWorkflow();
  }

  void _setupAnimation() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _startInitializationWorkflow() async {
    final startTime = DateTime.now();

    // 1. Asynchronously load DBHelper instance
    try {
      await DBHelper.instance.database;
    } catch (_) {}

    // 2. Evaluate active device permissions via native OS state machine
    final permissionController = PermissionStateController(autoInitialize: false);
    await permissionController.evaluateCurrentDevicePermissions();

    // 3. Ensure a minimum 2-second rhythmic splash display window
    final elapsedTime = DateTime.now().difference(startTime);
    const minimumDelay = Duration(seconds: 2);
    if (elapsedTime < minimumDelay) {
      await Future.delayed(minimumDelay - elapsedTime);
    }

    if (!mounted) return;

    // 4. Route based on live hardware permission evaluation
    if (permissionController.areAllPermissionsGranted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const AlarmHomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => OnboardingSplashScreen(
            permissionController: permissionController,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamCanvas,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Custom Clockwork Orange Alarm Clock Icon in Center
              AnimatedBuilder(
                animation: _scaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        color: AppTheme.cardWhite,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: AppTheme.starkBlack, width: 2.5),
                        boxShadow: const [
                          BoxShadow(
                            color: AppTheme.starkBlack,
                            offset: Offset(4, 4),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset(
                        'assets/Icon/app_icon.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.alarm,
                          size: 72,
                          color: AppTheme.starkBlack,
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 28),

              // Title
              const Text(
                'SHUT IT OFF',
                style: TextStyle(
                  fontFamily: 'serif',
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                  letterSpacing: 2.0,
                  color: AppTheme.starkBlack,
                ),
              ),

              const SizedBox(height: 6),

              // Tagline
              const Text(
                'FAIL-SAFE ESCALATION ENGINE',
                style: TextStyle(
                  fontFamily: 'serif',
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 1.5,
                  color: AppTheme.textMuted,
                ),
              ),

              const Spacer(),

              // Minimalist Rhythmic Loading Signal in Absolute Black
              AnimatedBuilder(
                animation: _opacityAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _opacityAnimation.value,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(3, (index) {
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.starkBlack,
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'EVALUATING DEVICE PROTOCOLS',
                          style: TextStyle(
                            fontFamily: 'serif',
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                            letterSpacing: 1.2,
                            color: AppTheme.starkBlack,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }
}
