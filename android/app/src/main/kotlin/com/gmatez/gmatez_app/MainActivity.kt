package com.gmatez.gmatez_app

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.gmatez.gmatez_app/call_audio",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    CallForegroundService.start(applicationContext)
                    result.success(null)
                }
                "stop" -> {
                    CallForegroundService.stop(applicationContext)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
