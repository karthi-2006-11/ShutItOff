import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shutitoff/controllers/alarm_controller.dart';
import 'package:shutitoff/main.dart';
import 'package:shutitoff/screens/eye_clock_widget.dart';
import 'package:shutitoff/theme/app_theme.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    databaseFactory = databaseFactorySqflitePlugin;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('com.tekartik.sqflite'),
            (MethodCall methodCall) async {
      if (methodCall.method == 'getDatabasesPath') {
        return '.';
      }
      if (methodCall.method == 'openDatabase') {
        return 1;
      }
      if (methodCall.method == 'query') {
        return <Map<String, dynamic>>[];
      }
      if (methodCall.method == 'insert') {
        return 1;
      }
      if (methodCall.method == 'delete') {
        return 0;
      }
      return null;
    });
  });

  group('Phase 6: AppTheme Specifications & Visual Tokens', () {
    test('AppTheme defines retro cream canvas and geometric slab palette', () {
      expect(AppTheme.creamCanvas, equals(const Color(0xFFFAF6EE)));
      expect(AppTheme.starkBlack, equals(const Color(0xFF000000)));
      expect(AppTheme.neonCyan, equals(const Color(0xFF00E5FF)));
      expect(AppTheme.alarmOrange, equals(const Color(0xFFFF5722)));
    });

    test('AppTheme.lightTheme exports correct background and palette', () {
      final theme = AppTheme.lightTheme;
      expect(theme.scaffoldBackgroundColor, equals(const Color(0xFFFAF6EE)));
      expect(theme.brightness, equals(Brightness.light));
      expect(theme.primaryColor, equals(const Color(0xFF00E5FF)));
    });

    test('panelDecoration creates solid black border and crisp drop shadow', () {
      final decoration = AppTheme.panelDecoration();
      expect(decoration.border, isNotNull);
      expect(decoration.boxShadow, isNotEmpty);
      expect(decoration.boxShadow!.first.offset, equals(const Offset(4, 4)));
      expect(decoration.boxShadow!.first.blurRadius, equals(0));
    });
  });

  group('Phase 6: EyeClockWidget Visual Glow Tests', () {
    late AlarmController controller;

    setUp(() {
      controller = AlarmController();
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets('EyeClockWidget renders canvas, digital time and idle state badge', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: EyeClockWidget(controller: controller),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(EyeClockWidget), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.text('👁️ SYSTEM ARMED & MONITORING'), findsOneWidget);
    });

    testWidgets('EyeClockWidget morphs to warm orange halo when alarm is ringing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: EyeClockWidget(controller: controller),
          ),
        ),
      );

      // Trigger active ringing
      controller.isCurrentlyRinging = true;
      controller.notifyListeners();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('🔔 ALARM ACTIVE - RINGING'), findsOneWidget);
    });

    testWidgets('EyeClockWidget morphs to warm orange halo when alarm is escalated', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: EyeClockWidget(controller: controller),
          ),
        ),
      );

      // Trigger escalation
      controller.isEscalated = true;
      controller.notifyListeners();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('⚡ ESCALATED! WAKE HIM'), findsOneWidget);
    });
  });

  group('Phase 6: Main Dashboard Integration & Navigation Tests', () {
    testWidgets('ShutItOffApp boots into light theme and displays bottom tabs', (tester) async {
      await tester.pumpWidget(const ShutItOffApp());
      await tester.pump();

      // Verify Header
      expect(find.text('SHUT IT OFF'), findsOneWidget);

      // Verify 3 Bottom Navigation Tabs
      expect(find.text('ALARMS'), findsOneWidget);
      expect(find.text('HANDSHAKE'), findsOneWidget);
      expect(find.text('HOSTEL HUB'), findsOneWidget);

      // Verify Eye Clock on View Panel A
      expect(find.byType(EyeClockWidget), findsOneWidget);

      // Tap HANDSHAKE tab
      await tester.tap(find.text('HANDSHAKE'));
      await tester.pump();

      expect(find.text('MY CONNECTION CODE'), findsOneWidget);
      expect(find.text("ENTER FRIEND'S CODE"), findsOneWidget);

      // Tap HOSTEL HUB tab
      await tester.tap(find.text('HOSTEL HUB'));
      await tester.pump();

      expect(find.text('🏢 ROOM: '), findsOneWidget);
      expect(find.text('ACTION LEDGER RECEIPTS'), findsOneWidget);
    });
  });
}
