package com.anidash.anime

import android.content.Context
import android.content.Intent
import android.content.pm.ActivityInfo
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.hardware.display.DisplayManager
import android.view.Display
import android.view.KeyEvent
import android.view.OrientationEventListener
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import androidx.core.content.FileProvider

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
    private var pendingLandscape: Int? = null
    private var pendingLandscapeSince: Long = 0L

    private fun enableLandscapeRotation() {
        landscapeListener?.disable()
        landscapeListener = object : OrientationEventListener(this) {
            override fun onOrientationChanged(orientation: Int) {
                if (orientation == ORIENTATION_UNKNOWN) return
                val now = System.currentTimeMillis()
                val candidate = when (orientation) {
                    in 78..102 -> ActivityInfo.SCREEN_ORIENTATION_REVERSE_LANDSCAPE
                    in 258..282 -> ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
                    else -> null
                }

                if (candidate == null) {
                    pendingLandscape = null
                    return
                }
                if (pendingLandscape != candidate) {
                    pendingLandscape = candidate
                    pendingLandscapeSince = now
                    return
                }
                if (requestedOrientation != candidate &&
                    now - pendingLandscapeSince >= 900 &&
                    now - lastOrientationChangeTime >= 1200) {
                    requestedOrientation = candidate
                    lastOrientationChangeTime = now
                    pendingLandscape = null
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
                        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "anidash/updater")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canInstallPackages" -> result.success(
                        Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                            packageManager.canRequestPackageInstalls()
                    )
                    "openInstallPermission" -> {
                        startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                            data = Uri.parse("package:$packageName")
                        })
                        result.success(true)
                    }
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        val apk = path?.let(::File)
                        if (apk == null || !apk.exists() || apk.length() == 0L) {
                            result.error("INVALID_APK", "Downloaded APK is missing or empty", null)
                        } else {
                            try {
                                val uri = FileProvider.getUriForFile(
                                    this,
                                    "$packageName.fileprovider",
                                    apk
                                )
                                val intent = Intent(Intent.ACTION_VIEW).apply {
                                    setDataAndType(uri, "application/vnd.android.package-archive")
                                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(intent)
                                result.success(true)
                            } catch (e: Exception) {
                                result.error("INSTALL_FAILED", e.localizedMessage, null)
                            }
                        }
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

