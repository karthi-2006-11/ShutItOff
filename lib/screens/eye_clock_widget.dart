import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../controllers/alarm_controller.dart';
import '../theme/app_theme.dart';

/// Enhanced Interface Glow Node displaying the Eye-Clock graphic layout
/// within custom canvas parameters.
/// Dynamically toggles glowing neon-cyan ambient trails for tethered room nodes
/// and pulsing warm-orange neon stroke halos when alarms fire or escalate.
class EyeClockWidget extends StatefulWidget {
  final AlarmController controller;
  final double size;

  const EyeClockWidget({
    super.key,
    required this.controller,
    this.size = 210.0,
  });

  @override
  State<EyeClockWidget> createState() => _EyeClockWidgetState();
}

class _EyeClockWidgetState extends State<EyeClockWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _clockTimer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.controller,
        widget.controller.socketHub,
      ]),
      builder: (context, _) {
        final isAlarmActive =
            widget.controller.isCurrentlyRinging || widget.controller.isEscalated;
        final isTethered = widget.controller.socketHub.isConnectedToPeer ||
            widget.controller.socketHub.connectedClientCount > 0;
        final clientCount = widget.controller.socketHub.connectedClientCount;

        return AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            final pulseVal = _pulseAnimation.value;

            // Compute dynamic border and glow halo according to connection & alarm health
            Border border;
            List<BoxShadow> boxShadows;
            Color irisColor;
            String statusBadgeText;
            Color statusBadgeBg;
            Color statusBadgeFg;

            if (isAlarmActive) {
              // Thick pulsing warm orange neon stroke halo
              border = Border.all(
                color: AppTheme.alarmOrange,
                width: 3.5 + 1.5 * pulseVal,
              );
              boxShadows = [
                BoxShadow(
                  color: AppTheme.alarmOrange.withValues(alpha: 0.5 + 0.4 * pulseVal),
                  blurRadius: 18 + 14 * pulseVal,
                  spreadRadius: 3 + 4 * pulseVal,
                ),
              ];
              irisColor = AppTheme.alarmOrange;
              statusBadgeText = widget.controller.isEscalated
                  ? '⚡ ESCALATED! WAKE HIM'
                  : '🔔 ALARM ACTIVE - RINGING';
              statusBadgeBg = AppTheme.alarmOrange;
              statusBadgeFg = Colors.white;
            } else if (isTethered) {
              // Glowing neon-cyan ambient trail
              border = Border.all(
                color: AppTheme.neonCyan,
                width: 3.0,
              );
              boxShadows = [
                BoxShadow(
                  color: AppTheme.neonCyan.withValues(alpha: 0.65),
                  blurRadius: 16,
                  spreadRadius: 2.5,
                ),
              ];
              irisColor = AppTheme.neonCyan;
              final peerInfo = clientCount > 0 ? '$clientCount PEER(S)' : 'PEER';
              statusBadgeText = '⚡ TETHERED HUB [$peerInfo]';
              statusBadgeBg = AppTheme.neonCyan;
              statusBadgeFg = AppTheme.starkBlack;
            } else {
              // Default clean high-contrast black outline on retro cream canvas
              border = Border.all(
                color: AppTheme.starkBlack,
                width: 2.5,
              );
              boxShadows = const [
                BoxShadow(
                  color: AppTheme.starkBlack,
                  offset: Offset(5, 5),
                  blurRadius: 0,
                ),
              ];
              irisColor = const Color(0xFF1E2024);
              statusBadgeText = '👁️ SYSTEM ARMED & MONITORING';
              statusBadgeBg = AppTheme.panelCream;
              statusBadgeFg = AppTheme.starkBlack;
            }

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.cardWhite,
                borderRadius: BorderRadius.circular(18),
                border: border,
                boxShadow: boxShadows,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Core Eye-Clock Custom Graphic Layout
                  SizedBox(
                    width: widget.size,
                    height: widget.size,
                    child: CustomPaint(
                      painter: _EyeClockPainter(
                        currentTime: _currentTime,
                        irisColor: irisColor,
                        isAlarmActive: isAlarmActive,
                        isTethered: isTethered,
                        pulse: pulseVal,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Digital Time Readout (Geometric Slab Typography)
                  Text(
                    _formatDigitalTime(_currentTime),
                    style: const TextStyle(
                      fontFamily: 'serif',
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3.0,
                      color: AppTheme.starkBlack,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Dynamic State Health Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusBadgeBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.starkBlack, width: 1.5),
                    ),
                    child: Text(
                      statusBadgeText,
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: statusBadgeFg,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatDigitalTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final second = time.second.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:$minute:$second $period';
  }
}

/// Canvas Painter drawing the Eye-Clock graphic layout:
/// - Outer circular clock face with geometric slab hour ticks
/// - Stylized central almond Eye shape with dynamic iris & pupil
/// - Geometric dial hands indicating live system time
class _EyeClockPainter extends CustomPainter {
  final DateTime currentTime;
  final Color irisColor;
  final bool isAlarmActive;
  final bool isTethered;
  final double pulse;

  _EyeClockPainter({
    required this.currentTime,
    required this.irisColor,
    required this.isAlarmActive,
    required this.isTethered,
    required this.pulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;

    // 1. Clock Face Background
    final facePaint = Paint()
      ..color = AppTheme.creamCanvas
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, facePaint);

    // 2. Outer Rim Stroke
    final rimPaint = Paint()
      ..color = AppTheme.starkBlack
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawCircle(center, radius, rimPaint);

    // 3. 12 Geometric Hour Ticks
    final tickPaint = Paint()
      ..color = AppTheme.starkBlack
      ..strokeCap = StrokeCap.square;

    for (int i = 0; i < 12; i++) {
      final angle = (i * 30) * math.pi / 180;
      final isMajor = i % 3 == 0;
      final tickLength = isMajor ? 14.0 : 7.0;
      tickPaint.strokeWidth = isMajor ? 3.5 : 2.0;

      final startX = center.dx + (radius - 4) * math.sin(angle);
      final startY = center.dy - (radius - 4) * math.cos(angle);
      final endX = center.dx + (radius - 4 - tickLength) * math.sin(angle);
      final endY = center.dy - (radius - 4 - tickLength) * math.cos(angle);

      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), tickPaint);
    }

    // 4. Stylized Eye Layout (Center)
    final eyeWidth = radius * 1.35;
    final eyeHeight = radius * 0.70;

    final eyePath = Path();
    final leftPoint = Offset(center.dx - eyeWidth / 2, center.dy);
    final rightPoint = Offset(center.dx + eyeWidth / 2, center.dy);

    eyePath.moveTo(leftPoint.dx, leftPoint.dy);
    // Upper eyelid curve
    eyePath.quadraticBezierTo(
      center.dx,
      center.dy - eyeHeight / 2,
      rightPoint.dx,
      rightPoint.dy,
    );
    // Lower eyelid curve
    eyePath.quadraticBezierTo(
      center.dx,
      center.dy + eyeHeight / 2,
      leftPoint.dx,
      leftPoint.dy,
    );
    eyePath.close();

    // Fill Eye Sclera (White)
    final scleraPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawPath(eyePath, scleraPaint);

    // Stroke Eye Contour (Stark Black)
    final eyeStrokePaint = Paint()
      ..color = AppTheme.starkBlack
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8;
    canvas.drawPath(eyePath, eyeStrokePaint);

    // Clip to eye contour so iris doesn't overflow eyelids
    canvas.save();
    canvas.clipPath(eyePath);

    // 5. Iris (Dynamic Color & Size)
    final irisRadius = eyeHeight * 0.42;
    final irisPaint = Paint()
      ..color = irisColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, irisRadius, irisPaint);

    // Iris Outline
    final irisBorderPaint = Paint()
      ..color = AppTheme.starkBlack
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, irisRadius, irisBorderPaint);

    // 6. Pupil (Stark Black with reflection)
    final pupilRadius = irisRadius * 0.48;
    final pupilPaint = Paint()
      ..color = AppTheme.starkBlack
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, pupilRadius, pupilPaint);

    // Specular Reflection Highlight
    final specularOffset = Offset(
      center.dx - pupilRadius * 0.35,
      center.dy - pupilRadius * 0.35,
    );
    final specularPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(specularOffset, pupilRadius * 0.32, specularPaint);

    canvas.restore();

    // 7. Clock Hands (Geometric Slab Rectangles)
    final hour = currentTime.hour % 12 + currentTime.minute / 60.0;
    final minute = currentTime.minute + currentTime.second / 60.0;

    final hourAngle = (hour * 30) * math.pi / 180;
    final minuteAngle = (minute * 6) * math.pi / 180;

    // Hour Hand
    _drawHand(
      canvas: canvas,
      center: center,
      angle: hourAngle,
      length: radius * 0.50,
      width: 4.5,
      color: AppTheme.starkBlack,
    );

    // Minute Hand
    _drawHand(
      canvas: canvas,
      center: center,
      angle: minuteAngle,
      length: radius * 0.72,
      width: 3.0,
      color: isAlarmActive ? AppTheme.alarmOrange : (isTethered ? AppTheme.neonCyan : AppTheme.starkBlack),
    );

    // Center Pin
    final pinPaint = Paint()
      ..color = isAlarmActive ? AppTheme.alarmOrange : AppTheme.starkBlack
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4.0, pinPaint);
  }

  void _drawHand({
    required Canvas canvas,
    required Offset center,
    required double angle,
    required double length,
    required double width,
    required Color color,
  }) {
    final handPaint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.square
      ..strokeWidth = width;

    final endPoint = Offset(
      center.dx + length * math.sin(angle),
      center.dy - length * math.cos(angle),
    );

    canvas.drawLine(center, endPoint, handPaint);
  }

  @override
  bool shouldRepaint(covariant _EyeClockPainter oldDelegate) {
    return oldDelegate.currentTime.second != currentTime.second ||
        oldDelegate.irisColor != irisColor ||
        oldDelegate.isAlarmActive != isAlarmActive ||
        oldDelegate.isTethered != isTethered ||
        oldDelegate.pulse != pulse;
  }
}
