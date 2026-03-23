package com.hbp.quoteoftheday

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import android.os.Debug
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.hbp.quoteoftheday/device_performance",
        ).setMethodCallHandler { call, result ->
            if (call.method != "getProfile") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val activityManager =
                getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
            if (activityManager == null) {
                result.success(
                    mapOf(
                        "platformLabel" to "android",
                        "isLowRamDevice" to false,
                        "memoryClassMb" to 192,
                        "largeMemoryClassMb" to 256,
                        "totalMemoryMb" to 4096,
                        "processorCount" to Runtime.getRuntime().availableProcessors(),
                    ),
                )
                return@setMethodCallHandler
            }

            val memoryInfo = ActivityManager.MemoryInfo()
            activityManager.getMemoryInfo(memoryInfo)
            val totalMemoryMb = (memoryInfo.totalMem / (1024L * 1024L)).toInt()

            result.success(
                mapOf(
                    "platformLabel" to "android",
                    "sdkInt" to Build.VERSION.SDK_INT,
                    "isLowRamDevice" to activityManager.isLowRamDevice,
                    "memoryClassMb" to activityManager.memoryClass,
                    "largeMemoryClassMb" to activityManager.largeMemoryClass,
                    "totalMemoryMb" to totalMemoryMb,
                    "nativeHeapMb" to (Debug.getNativeHeapAllocatedSize() / (1024L * 1024L)).toInt(),
                    "processorCount" to Runtime.getRuntime().availableProcessors(),
                ),
            )
        }
    }
}
