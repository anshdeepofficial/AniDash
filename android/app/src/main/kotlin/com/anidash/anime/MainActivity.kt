import android.content.Context
import android.content.pm.ActivityInfo
import android.hardware.display.DisplayManager
import android.view.Display
import android.view.KeyEvent
import android.view.OrientationEventListener
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var landscapeListener: OrientationEventListener? = null
    private var volumeChannel: MethodChannel? = null
    private var interceptVolumeKeys = false
    private var isScreenshotPrivacyEnabled = false
    private var displayListener: DisplayManager.DisplayListener? = null

    private fun updateSecureFlag() {
        val displayManager = getSystemService(Context.DISPLAY_SERVICE) as? DisplayManager
        val isCasting = displayManager?.displays?.any { it.displayId != Display.DEFAULT_DISPLAY } == true

        runOnUiThread {
            if (isScreenshotPrivacyEnabled && !isCasting) {
                window.setFlags(
                    android.view.WindowManager.LayoutParams.FLAG_SECURE,
                    android.view.WindowManager.LayoutParams.FLAG_SECURE
                )
            } else {
                window.clearFlags(android.view.WindowManager.LayoutParams.FLAG_SECURE)
            }
        }
    }

    private var lastOrientationChangeTime: Long = 0L

    private fun enableLandscapeRotation() {
        landscapeListener?.disable()
        landscapeListener = object : OrientationEventListener(this) {
            override fun onOrientationChanged(orientation: Int) {
                if (orientation == ORIENTATION_UNKNOWN) return
                val now = System.currentTimeMillis()
                if (now - lastOrientationChangeTime < 500) return

                when (orientation) {
                    // Deliberate 55%+ tilt towards 90 deg (Reverse Landscape)
                    in 65..115 -> {
                        if (requestedOrientation != ActivityInfo.SCREEN_ORIENTATION_REVERSE_LANDSCAPE) {
                            requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_REVERSE_LANDSCAPE
                            lastOrientationChangeTime = now
                        }
                    }
                    // Deliberate 55%+ tilt towards 270 deg (Regular Landscape)
                    in 245..295 -> {
                        if (requestedOrientation != ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE) {
                            requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
                            lastOrientationChangeTime = now
                        }
                    }
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
                    "lockCurrent" -> {
                        disableLandscapeRotation()
                        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_LOCKED
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
                        disableLandscapeRotation()
                        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
                        result.success(null)
                    }
                    "landscapeRight" -> {
                        disableLandscapeRotation()
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

        val displayManager = getSystemService(Context.DISPLAY_SERVICE) as? DisplayManager
        if (displayListener == null && displayManager != null) {
            displayListener = object : DisplayManager.DisplayListener {
                override fun onDisplayAdded(displayId: Int) { updateSecureFlag() }
                override fun onDisplayRemoved(displayId: Int) { updateSecureFlag() }
                override fun onDisplayChanged(displayId: Int) { updateSecureFlag() }
            }
            displayManager.registerDisplayListener(displayListener, null)
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "shonenx/security")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setSecureFlag" -> {
                        isScreenshotPrivacyEnabled = call.argument<Boolean>("enable") ?: false
                        updateSecureFlag()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (interceptVolumeKeys) {
            when (event.keyCode) {
                KeyEvent.KEYCODE_VOLUME_UP -> {
                    if (event.action == KeyEvent.ACTION_DOWN) {
                        volumeChannel?.invokeMethod("volumeUp", null)
                    }
                    return true
                }
                KeyEvent.KEYCODE_VOLUME_DOWN -> {
                    if (event.action == KeyEvent.ACTION_DOWN) {
                        volumeChannel?.invokeMethod("volumeDown", null)
                    }
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

