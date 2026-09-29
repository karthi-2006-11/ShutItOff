import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class PermissionStateController extends ChangeNotifier with WidgetsBindingObserver {
  static const MethodChannel _channel = MethodChannel('com.example.shutitoff/permissions');

  bool isBatteryUnrestricted = false;
  bool isOverlayAllowed = false;
  String? detectedSystemAlarmTime;
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

  static bool isWithinMorningWindow(String? timeStr) {
    if (timeStr == null || timeStr.trim().isEmpty) return false;
    try {
      final parts = timeStr.trim().split(' ');
      if (parts.length < 2) return false;
      final timeParts = parts[0].split(':');
      if (timeParts.length < 2) return false;
      var hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      final period = parts[1].toUpperCase();
      if (period == 'PM' && hour != 12) {
        hour += 12;
      } else if (period == 'AM' && hour == 12) {
        hour = 0;
      }
      final totalMinutes = hour * 60 + minute;
      // Strict minute-by-minute window: 04:00 (240m) up to and including 07:00 (420m)
      return totalMinutes >= (4 * 60) && totalMinutes <= (7 * 60);
    } catch (_) {
      return false;
    }
  }

  Future<void> evaluateCurrentDevicePermissions() async {
    isEvaluating = true;
    notifyListeners();

    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final bool? battery = await _channel.invokeMethod<bool>('isBatteryUnrestricted');
        final bool? overlay = await _channel.invokeMethod<bool>('isOverlayAllowed');
        final String? systemAlarm = await _channel.invokeMethod<String>('getNextSystemAlarmClock');
        isBatteryUnrestricted = battery ?? false;
        isOverlayAllowed = overlay ?? false;
        if (systemAlarm != null && systemAlarm.isNotEmpty && isWithinMorningWindow(systemAlarm)) {
          detectedSystemAlarmTime = systemAlarm;
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
