import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EscalationOverlay extends StatefulWidget {
  final String friendName;
  final VoidCallback onWakeHim;
  final VoidCallback? onDismiss;

  const EscalationOverlay({
    super.key,
    required this.friendName,
    required this.onWakeHim,
    this.onDismiss,
  });

  @override
  State<EscalationOverlay> createState() => _EscalationOverlayState();
}

class _EscalationOverlayState extends State<EscalationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _flashController;
  late Animation<double> _flashAnimation;
  bool _hasTriggeredWake = false;

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _flashAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _flashController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _flashController.dispose();
    super.dispose();
  }

  void _handleWakeHimPressed() {
    // Ongoing vibration feedback signature
    HapticFeedback.heavyImpact();
    HapticFeedback.vibrate();

    setState(() {
      _hasTriggeredWake = true;
    });

    widget.onWakeHim();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('MAX VOLUME SIREN FORCED ON ${widget.friendName.toUpperCase()}!'),
        backgroundColor: const Color(0xFFFF6D00),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _flashAnimation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFFF6D00).withAlpha((_flashAnimation.value * 255).toInt()),
              width: 3.0,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6D00).withAlpha((_flashAnimation.value * 100).toInt()),
                blurRadius: 18,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Flashing neon-orange alert banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6D00).withAlpha((_flashAnimation.value * 40).toInt()),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: const Color(0xFFFF6D00).withAlpha((_flashAnimation.value * 255).toInt()),
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'ESCALATION WATCHDOG TRIGGERED',
                        style: TextStyle(
                          color: Color(0xFFFF6D00),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Exact display text node requirement:
              // "🔔 [Friend's Name] has been sleeping through their alarm for 1 minute!"
              Text(
                "🔔 ${widget.friendName} has been sleeping through their alarm for 1 minute!",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111315),
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 20),
              // Massive, unmissable [WAKE HIM] text action button
              SizedBox(
                height: 64,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _hasTriggeredWake
                        ? const Color(0xFFD32F2F)
                        : const Color(0xFFFF6D00),
                    foregroundColor: Colors.white,
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _handleWakeHimPressed,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.volume_up_rounded, size: 28),
                      const SizedBox(width: 12),
                      Text(
                        _hasTriggeredWake ? '[WAKE SIGNAL ACTIVE]' : '[WAKE HIM]',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.onDismiss != null) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: widget.onDismiss,
                  child: const Text(
                    'DISMISS ALARM REMOTELY',
                    style: TextStyle(
                      color: Color(0xFF5F6368),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
