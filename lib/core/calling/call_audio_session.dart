import 'dart:io';

import 'package:flutter/services.dart';

/// Keeps the microphone alive when the phone screen locks.
class CallAudioSession {
  static const _channel = MethodChannel('com.gmatez.gmatez_app/call_audio');

  static Future<void> start() async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('start');
    } catch (_) {
      // Audio still works in the foreground if the service cannot start.
    }
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (_) {}
  }
}
