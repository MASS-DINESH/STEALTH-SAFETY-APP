package com.example.safetyapp

import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.text.TextUtils
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val methodChannelName = "safety_app/native"
    private val eventChannelName = "safety_app/trigger_events"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openAccessibilitySettings" -> {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        result.success(null)
                    }
                    "openOverlaySettings" -> {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName"),
                        )
                        startActivity(intent)
                        result.success(null)
                    }
                    "requestIgnoreBatteryOptimizations" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val pm = getSystemService(POWER_SERVICE) as PowerManager
                            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                                val intent = Intent(
                                    Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                    Uri.parse("package:$packageName"),
                                )
                                startActivity(intent)
                            }
                        }
                        result.success(null)
                    }
                    "isAccessibilityServiceEnabled" -> {
                        result.success(isAccessibilityServiceEnabled())
                    }
                    "showFakeShutdownOverlay" -> {
                        startActivity(
                            Intent(this, FakeShutdownActivity::class.java)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                        )
                        result.success(null)
                    }
                    "hideFakeShutdownOverlay" -> {
                        TriggerState.alertActive = false
                        FakeShutdownActivity.instance?.finish()
                        result.success(null)
                    }
                    "takeNativePhotos" -> {
                        val sessionDirPath = call.argument<String>("sessionDirPath") ?: ""
                        val sessionId = call.argument<String>("sessionId") ?: ""
                        val count = call.argument<Int>("count") ?: 3

                        NativeCameraHelper.capturePhotos(
                            context = applicationContext,
                            sessionDirPath = sessionDirPath,
                            sessionId = sessionId,
                            count = count,
                            onPhotoCaptured = { savedPath, index, total ->
                                runOnUiThread {
                                    TriggerBridge.emit("photo_captured:$index:$total:$savedPath")
                                }
                            },
                            onComplete = {
                                runOnUiThread {
                                    result.success(true)
                                }
                            }
                        )
                    }
                    "startNativeAudio" -> {
                        val sessionDirPath = call.argument<String>("sessionDirPath") ?: ""
                        val sessionId = call.argument<String>("sessionId") ?: ""
                        val clipSeconds = call.argument<Int>("clipSeconds") ?: 30
                        val totalLoops = call.argument<Int>("totalLoops") ?: 1

                        NativeAudioHelper.startAudioLoops(
                            context = applicationContext,
                            sessionDirPath = sessionDirPath,
                            sessionId = sessionId,
                            clipSeconds = clipSeconds,
                            totalLoops = totalLoops,
                            onProgress = { seconds, duration ->
                                runOnUiThread {
                                    TriggerBridge.emit("audio_progress:$seconds:$duration")
                                }
                            },
                            onLoopComplete = { savedPath, loop, total ->
                                runOnUiThread {
                                    TriggerBridge.emit("audio_captured:$loop:$total:$savedPath")
                                }
                            },
                            onAllComplete = {
                                runOnUiThread {
                                    TriggerBridge.emit("audio_all_complete")
                                }
                            }
                        )
                        result.success(true)
                    }
                    "stopNativeAudio" -> {
                        NativeAudioHelper.stopRecording {
                            runOnUiThread {
                                result.success(true)
                            }
                        }
                    }
                    "playNativeAudio" -> {
                        val filePath = call.argument<String>("filePath") ?: ""
                        val success = NativeAudioPlaybackHelper.play(
                            filePath = filePath,
                            onProgress = { currentMs, durationMs ->
                                runOnUiThread {
                                    TriggerBridge.emit("playback_progress:$currentMs:$durationMs:$filePath")
                                }
                            },
                            onComplete = {
                                runOnUiThread {
                                    TriggerBridge.emit("playback_complete:$filePath")
                                }
                            }
                        )
                        result.success(success)
                    }
                    "stopNativeAudioPlayback" -> {
                        NativeAudioPlaybackHelper.stop()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    TriggerBridge.attach(events)
                }

                override fun onCancel(arguments: Any?) {
                    TriggerBridge.detach()
                }
            })
    }

    override fun onResume() {
        super.onResume()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val expectedComponentName1 = "$packageName/.VolumeAccessibilityService"
        val expectedComponentName2 = "$packageName/${VolumeAccessibilityService::class.java.name}"
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ) ?: return false
        val splitter = TextUtils.SimpleStringSplitter(':')
        splitter.setString(enabledServices)
        while (splitter.hasNext()) {
            val component = splitter.next()
            if (component.equals(expectedComponentName1, ignoreCase = true) ||
                component.equals(expectedComponentName2, ignoreCase = true)) {
                return true
            }
            val parsedComponent = ComponentName.unflattenFromString(component)
            if (parsedComponent != null &&
                parsedComponent.packageName.equals(packageName, ignoreCase = true) &&
                parsedComponent.className.equals(VolumeAccessibilityService::class.java.name, ignoreCase = true)) {
                return true
            }
        }
        return false
    }
}