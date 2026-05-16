package com.thenowavideoplayer.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.ActivityManager
import android.content.Context

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.thenowavideoplayer.app/hardware"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getTotalRAM") {
                try {
                    val actManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                    val memInfo = ActivityManager.MemoryInfo()
                    actManager.getMemoryInfo(memInfo)
                    val totalRamInBytes = memInfo.totalMem
                    result.success(totalRamInBytes.toString())
                } catch (e: Exception) {
                    result.error("RAM_ERROR", "Failed to get RAM", e.toString())
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
