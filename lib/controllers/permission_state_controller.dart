import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class PermissionStateController extends ChangeNotifier with WidgetsBindingObserver {
  static const MethodChannel _channel = MethodChannel('com.example.shutitoff/permissions');

  bool isBatteryUnrestricted = false;
  bool isOverlayAllowed = false;
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

  Future<void> evaluateCurrentDevicePermissions() async {
    isEvaluating = true;
    notifyListeners();

    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final bool? battery = await _channel.invokeMethod<bool>('isBatteryUnrestricted');
        final bool? overlay = await _channel.invokeMethod<bool>('isOverlayAllowed');
        isBatteryUnrestricted = battery ?? false;
        isOverlayAllowed = overlay ?? false;
      } else {
        // Fallback for non-Android environments (web/preview/tests)
        isBatteryUnrestricted = true;
        isOverlayAllowed = true;
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
