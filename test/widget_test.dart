import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shutitoff/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
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
      return null;
    });
  });

  testWidgets('ShutItOffApp loads and displays main app bar title',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ShutItOffApp());
    await tester.pump();
    expect(find.text('SHUT IT OFF'), findsOneWidget);
  });
}
