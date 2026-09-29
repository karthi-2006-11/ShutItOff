import 'package:flutter/material.dart';
import '../data/db_helper.dart';
import '../main.dart';
import '../theme/app_theme.dart';

class OnboardingSplashScreen extends StatelessWidget {
  final VoidCallback? onComplete;

  const OnboardingSplashScreen({
    super.key,
    this.onComplete,
  });

  Future<void> _handleComplete(BuildContext context) async {
    await DBHelper.instance.setOnboardingComplete(true);
    if (onComplete != null) {
      onComplete!();
    } else if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AlarmHomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 10),
                      // Top Eye / Warning Graphic Node
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.alarmOrange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.alarmOrange, width: 1.5),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.warning_amber_rounded, color: AppTheme.alarmOrange, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'SYSTEM LIFECYCLE GUARD',
                                style: TextStyle(
                                  fontFamily: 'serif',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                  color: AppTheme.alarmOrange,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      // Title Header Node
                      const Text(
                        'CRITICAL APP CONFIGURATION SETUP REQUIRED',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          letterSpacing: 1.0,
                          color: AppTheme.starkBlack,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'ShutItOff requires high-priority native Android system execution privileges to ensure fail-safe wake-up delivery across network sleep cycles.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textMuted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 26),

                      // Educational Content Card 1
                      _buildEducationalCard(
                        icon: Icons.battery_charging_full_outlined,
                        tag: 'PERMISSION REQUIREMENT 01',
                        title: 'Battery Optimization -> Unrestricted Mode',
                        explanation:
                            'Keeps local Wi-Fi WebSocket background sockets running smoothly while you sleep to capture incoming signals.',
                      ),
                      const SizedBox(height: 18),

                      // Educational Content Card 2
                      _buildEducationalCard(
                        icon: Icons.layers_outlined,
                        tag: 'PERMISSION REQUIREMENT 02',
                        title: 'Draw Over Other Apps -> Allowed Mode',
                        explanation:
                            'Enables 6:00 AM alert panels to light up and wake your phone even when it is completely locked.',
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              // Action Lock Button
              Container(
                decoration: const BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.starkBlack,
                      offset: Offset(3, 3),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.starkBlack,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: AppTheme.starkBlack, width: 2.0),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onPressed: () => _handleComplete(context),
                    child: const Text(
                      '[ I UNDERSTAND, READY TO SHUT IT OFF ]',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
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
  }

  Widget _buildEducationalCard({
    required IconData icon,
    required String tag,
    required String title,
    required String explanation,
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
        ],
      ),
    );
  }
}
