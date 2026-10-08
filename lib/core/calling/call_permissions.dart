import 'package:permission_handler/permission_handler.dart';

enum CallPermissionResult {
  granted,
  denied,
  permanentlyDenied,
  restricted,
}

/// Runtime mic/camera permissions for voice/video calls.
class CallPermissions {
  const CallPermissions();

  Future<CallPermissionResult> ensureForCall({required bool video}) async {
    final mic = await Permission.microphone.request();
    if (mic.isPermanentlyDenied || mic.isRestricted) {
      return mic.isRestricted
          ? CallPermissionResult.restricted
          : CallPermissionResult.permanentlyDenied;
    }
    if (!mic.isGranted) {
      return CallPermissionResult.denied;
    }
    try {
      await Permission.notification.request();
    } catch (_) {}
    if (!video) {
      return CallPermissionResult.granted;
    }
    final cam = await Permission.camera.request();
    if (cam.isPermanentlyDenied || cam.isRestricted) {
      return cam.isRestricted
          ? CallPermissionResult.restricted
          : CallPermissionResult.permanentlyDenied;
    }
    if (!cam.isGranted) {
      return CallPermissionResult.denied;
    }
    return CallPermissionResult.granted;
  }

  Future<bool> openSettings() => openAppSettings();
}
