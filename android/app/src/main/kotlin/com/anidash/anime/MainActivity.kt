package com.anidash.anime

import android.content.pm.ActivityInfo
import android.view.KeyEvent
import android.view.OrientationEventListener
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var landscapeListener: OrientationEventListener? = null
    private var volumeChannel: MethodChannel? = null
    private var interceptVolumeKeys = false

    private fun enableLandscapeRotation() {
        landscapeListener?.disable()
        landscapeListener = object : OrientationEventListener(this) {
            override fun onOrientationChanged(orientation: Int) {
                if (orientation == ORIENTATION_UNKNOWN) return
                when (orientation) {
                    in 45..135 -> requestedOrientation =
                        ActivityInfo.SCREEN_ORIENTATION_REVERSE_LANDSCAPE
                    in 225..315 -> requestedOrientation =
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
                when (call.method) {
                    "sensorLandscape" -> {
                        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
                        enableLandscapeRotation()
                        result.success(null)
                    }
                    "toggleLandscape" -> {
                        requestedOrientation =
                            if (requestedOrientation == ActivityInfo.SCREEN_ORIENTATION_REVERSE_LANDSCAPE)
                                ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
                            else ActivityInfo.SCREEN_ORIENTATION_REVERSE_LANDSCAPE
                        result.success(null)
                    }
                    "landscapeLeft" -> {
                        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
                        result.success(null)
                    }
                    "landscapeRight" -> {
                        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_REVERSE_LANDSCAPE
                        result.success(null)
                    }
                    "portrait" -> {
                        disableLandscapeRotation()
                        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        volumeChannel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "shonenx/volume").apply {
                setMethodCallHandler { call, result ->
                    when (call.method) {
                        "enableIntercept" -> {
                            interceptVolumeKeys = true
                            result.success(null)
                        }
                        "disableIntercept" -> {
                            interceptVolumeKeys = false
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                }
            }
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (interceptVolumeKeys && event.action == KeyEvent.ACTION_DOWN) {
            when (event.keyCode) {
                KeyEvent.KEYCODE_VOLUME_UP -> {
                    volumeChannel?.invokeMethod("volumeUp", null)
                    return true
                }
                KeyEvent.KEYCODE_VOLUME_DOWN -> {
                    volumeChannel?.invokeMethod("volumeDown", null)
                    return true
                }
            }
        }
        return super.dispatchKeyEvent(event)
    }

    override fun onDestroy() {
        disableLandscapeRotation()
        super.onDestroy()
    }
}

