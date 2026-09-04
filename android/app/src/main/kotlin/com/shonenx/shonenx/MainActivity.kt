package com.shonenx.shonenx

import android.content.pm.ActivityInfo
import android.view.OrientationEventListener
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var landscapeListener: OrientationEventListener? = null

    private fun enableLandscapeRotation() {
        landscapeListener?.disable()
        landscapeListener = object : OrientationEventListener(this) {
            override fun onOrientationChanged(orientation: Int) {
                if (orientation == ORIENTATION_UNKNOWN) return
                when (orientation) {
                    in 60..120 -> requestedOrientation =
                        ActivityInfo.SCREEN_ORIENTATION_REVERSE_LANDSCAPE
                    in 240..300 -> requestedOrientation =
                        ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
                }
            }
        }.also { if (it.canDetectOrientation()) it.enable() }
    }

    private fun disableLandscapeRotation() {
        landscapeListener?.disable()
        landscapeListener = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "shonenx/orientation")
            .setMethodCallHandler { call, result ->
                if (call.method == "sensorLandscape") {
                    requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
                    enableLandscapeRotation()
                    result.success(null)
                } else if (call.method == "portrait") {
                    disableLandscapeRotation()
                    requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        disableLandscapeRotation()
        super.onDestroy()
    }
}
