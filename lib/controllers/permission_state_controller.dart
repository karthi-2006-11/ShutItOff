import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class PermissionStateController extends ChangeNotifier with WidgetsBindingObserver {
  static const MethodChannel _channel = MethodChannel('com.example.shutitoff/permissions');

  bool isBatteryUnrestricted = false;
  bool isOverlayAllowed = false;
  String? detectedSystemAlarmTime;
  String? get localSystemAlarmTime => detectedSystemAlarmTime;
  set localSystemAlarmTime(String? value) => detectedSystemAlarmTime = value;
  bool isEvaluating = false;

  bool get areAllPermissionsGranted => isBatteryUnrestricted && isOverlayAllowed;

  PermissionStateController({bool autoInitialize = true}) {
    WidgetsBinding.instance.addObserver(this);
    if (autoInitialize) {
      evaluateCurrentDevicePermissions();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      evaluateCurrentDevicePermissions();
    }
  }

  static ({bool isCheating, String formattedTime}) parseSystemAlarmString(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return (isCheating: false, formattedTime: '');
    }
    try {
      final trimmed = raw.trim();
      int hour24;
      int minute;
      String formattedTime;

      if (trimmed.contains(',')) {
        // Kotlin returned "hour24,minute,formattedTime" (e.g., "6,30,06:30 AM")
        final parts = trimmed.split(',');
        hour24 = int.parse(parts[0].trim());
        minute = int.parse(parts[1].trim());
        formattedTime = parts.sublist(2).join(',').trim();
      } else {
        // Fallback for standard formatted string e.g. "06:30 AM"
        final parts = trimmed.split(' ');
        if (parts.length < 2) return (isCheating: false, formattedTime: '');
        final timeParts = parts[0].split(':');
        if (timeParts.length < 2) return (isCheating: false, formattedTime: '');
        var h = int.parse(timeParts[0]);
        minute = int.parse(timeParts[1]);
        final period = parts[1].toUpperCase();
        if (period == 'PM' && h != 12) {
          h += 12;
        } else if (period == 'AM' && h == 12) {
          h = 0;
        }
        hour24 = h;
        formattedTime = trimmed;
      }

      // Math Logic: bool isCheating = (hour24 >= 4 && hour24 <= 6) || (hour24 == 7 && minute == 0);
      final bool isCheating = (hour24 >= 4 && hour24 <= 6) || (hour24 == 7 && minute == 0);
      return (isCheating: isCheating, formattedTime: formattedTime);
    } catch (_) {
      return (isCheating: false, formattedTime: '');
    }
  }

  static bool isWithinMorningWindow(String? timeStr) {
    return parseSystemAlarmString(timeStr).isCheating;
  }

  Future<void> evaluateCurrentDevicePermissions() async {
    isEvaluating = true;
    notifyListeners();

    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final bool? battery = await _channel.invokeMethod<bool>('isBatteryUnrestricted');
        final bool? overlay = await _channel.invokeMethod<bool>('isOverlayAllowed');
        final String? rawAlarm = await _channel.invokeMethod<String>('getNextSystemAlarmClock');
        isBatteryUnrestricted = battery ?? false;
        isOverlayAllowed = overlay ?? false;

        final parsed = parseSystemAlarmString(rawAlarm);
        if (parsed.isCheating) {
          detectedSystemAlarmTime = parsed.formattedTime;
        } else {
          detectedSystemAlarmTime = null;
        }
      } else {
        // Fallback for non-Android environments (web/preview/tests)
        isBatteryUnrestricted = true;
        isOverlayAllowed = true;
        detectedSystemAlarmTime = null;
      }
    } catch (e) {
      debugPrint('[PermissionStateController] Evaluation error: $e');
    } finally {
      isEvaluating = false;
      notifyListeners();
    }
  }

  Future<void> requestBatteryUnrestricted() async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await _channel.invokeMethod('requestBatteryUnrestricted');
      }
    } catch (e) {
      debugPrint('[PermissionStateController] Battery request error: $e');
    }
  }

  Future<void> requestOverlayAllowed() async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await _channel.invokeMethod('requestOverlayAllowed');
      }
    } catch (e) {
      debugPrint('[PermissionStateController] Overlay request error: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
