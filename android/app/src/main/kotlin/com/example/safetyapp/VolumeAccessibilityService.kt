package com.example.safetyapp

import android.accessibilityservice.AccessibilityService
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import android.telephony.TelephonyManager
import android.net.ConnectivityManager
import android.util.Log
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent

/**
 * Volume button trigger & system lockdown service:
 * - VOLUME UP x3 -> AUTO-ENABLE GPS & MOBILE DATA -> START EMERGENCY (Blackout, Evidence, WhatsApp)
 * - VOLUME DOWN x3 -> STOP EMERGENCY & DISMISS BLACKOUT
 * - Blocks notifications, control center, floating windows, back, home, and recents during alert.
 */
class VolumeAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "VolumeAccessService"
        var instance: VolumeAccessibilityService? = null
    }

    private val upTimestamps   = mutableListOf<Long>()
    private val downTimestamps = mutableListOf<Long>()
    private val windowMillis    = 3500L
    private val requiredPresses = 3
    private val mainHandler     = Handler(Looper.getMainLooper())

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == Intent.ACTION_SCREEN_ON && TriggerState.alertActive) {
                launchFakeOverlay()
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        try {
            val filter = IntentFilter(Intent.ACTION_SCREEN_ON)
            registerReceiver(screenReceiver, filter)
        } catch (_: Exception) {}
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        try {
            unregisterReceiver(screenReceiver)
        } catch (_: Exception) {}
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (!TriggerState.alertActive || event == null) return

        // If another app, launcher, or floating window attempts to appear, bring blackout back to top
        when (event.eventType) {
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED,
            AccessibilityEvent.TYPE_WINDOWS_CHANGED -> {
                val activeClass = event.className?.toString() ?: ""
                if (activeClass.isNotEmpty() &&
                    !activeClass.contains("FakeShutdownActivity") &&
                    !activeClass.contains("MainActivity") &&
                    !activeClass.contains("com.example.safetyapp")) {
                    launchFakeOverlay()
                }
            }
        }

        // Dismiss notification shade and control center immediately if pulled
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            try {
                performGlobalAction(GLOBAL_ACTION_DISMISS_NOTIFICATION_SHADE)
            } catch (_: Exception) {}
        }
    }

    override fun onInterrupt() {}

    override fun onKeyEvent(event: KeyEvent?): Boolean {
        if (event == null) return false

        val keyCode = event.keyCode
        val action = event.action

        // 1. Process Volume UP (Triple press to START)
        if (keyCode == KeyEvent.KEYCODE_VOLUME_UP) {
            if (action == KeyEvent.ACTION_DOWN && event.repeatCount == 0) {
                downTimestamps.clear()
                registerPress(upTimestamps) { onPatternDetected(triggered = true) }
            }
            // Always consume volume up during alert to hide volume slider
            return true
        }

        // 2. Process Volume DOWN (Triple press to STOP)
        if (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) {
            if (action == KeyEvent.ACTION_DOWN && event.repeatCount == 0) {
                upTimestamps.clear()
                registerPress(downTimestamps) { onPatternDetected(triggered = false) }
            }
            // Always consume volume down during alert to hide volume slider
            return true
        }

        // 3. Block Back, Home, and App Switch (Recents) keys during active emergency
        if (TriggerState.alertActive) {
            when (keyCode) {
                KeyEvent.KEYCODE_BACK,
                KeyEvent.KEYCODE_HOME,
                KeyEvent.KEYCODE_APP_SWITCH,
                KeyEvent.KEYCODE_MENU -> return true
            }
            return true
        }

        return false
    }

    private fun registerPress(timestamps: MutableList<Long>, onPattern: () -> Unit) {
        val now = System.currentTimeMillis()
        // Sub-50ms debounce
        if (timestamps.isNotEmpty() && (now - timestamps.last() < 50L)) {
            return
        }
        timestamps.add(now)
        timestamps.removeAll { now - it > windowMillis }
        Log.d(TAG, "Volume press: ${timestamps.size}/$requiredPresses in ${windowMillis}ms")
        if (timestamps.size >= requiredPresses) {
            timestamps.clear()
            upTimestamps.clear()
            downTimestamps.clear()
            mainHandler.post { onPattern() }
        }
    }

    private fun launchFakeOverlay() {
        try {
            val fakeIntent = Intent(this, FakeShutdownActivity::class.java).apply {
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
                )
            }
            startActivity(fakeIntent)
        } catch (e: Exception) {
            Log.e(TAG, "Error launching blackout overlay: ${e.message}")
        }
    }

    private fun vibratePattern(timings: LongArray) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                vm?.defaultVibrator?.vibrate(VibrationEffect.createWaveform(timings, -1))
            } else {
                @Suppress("DEPRECATION")
                val v = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    v?.vibrate(VibrationEffect.createWaveform(timings, -1))
                } else {
                    @Suppress("DEPRECATION")
                    v?.vibrate(timings, -1)
                }
            }
        } catch (_: Exception) {}
    }

    // ─────────────────────────────────────────────────────────────────
    //  AUTO-ENABLE GPS & MOBILE DATA
    // ─────────────────────────────────────────────────────────────────
    private fun autoEnableLocation() {
        try {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
                Settings.Secure.putInt(
                    contentResolver,
                    Settings.Secure.LOCATION_MODE,
                    Settings.Secure.LOCATION_MODE_HIGH_ACCURACY
                )
                Log.d(TAG, "GPS enabled via Settings.Secure")
            }
        } catch (e: Exception) {
            Log.d(TAG, "Silent location enable note: ${e.message}")
        }
    }

    private fun autoEnableMobileData() {
        try {
            val tm = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
            val setDataEnabled = tm.javaClass.getDeclaredMethod("setDataEnabled", Boolean::class.java)
            setDataEnabled.isAccessible = true
            setDataEnabled.invoke(tm, true)
            Log.d(TAG, "Mobile data enabled via TelephonyManager reflection")
            return
        } catch (_: Exception) {}

        try {
            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val setMobileData = cm.javaClass.getDeclaredMethod("setMobileDataEnabled", Boolean::class.java)
            setMobileData.isAccessible = true
            setMobileData.invoke(cm, true)
            Log.d(TAG, "Mobile data enabled via ConnectivityManager reflection")
        } catch (_: Exception) {}
    }

    // ─────────────────────────────────────────────────────────────────

    private var lastTriggerTime = 0L

    private fun onPatternDetected(triggered: Boolean) {
        val now = System.currentTimeMillis()
        if (triggered) {
            if (TriggerState.alertActive || now - lastTriggerTime < 2000L) return
            lastTriggerTime = now
            TriggerState.alertActive = true
            Log.d(TAG, "🚨 PANIC TRIGGER ACTIVATED via Volume UP x3")

            // 1. Double buzz confirmation
            vibratePattern(longArrayOf(0, 150, 80, 150))

            // 2. Auto-enable GPS & Mobile Data
            autoEnableLocation()
            autoEnableMobileData()

            // 3. Start high-priority foreground service
            try {
                startForegroundService(Intent(this, TriggerForegroundService::class.java))
            } catch (_: Exception) {}

            // 4. Emit panic trigger to Flutter engine
            TriggerBridge.emit("panic_trigger")

            // 5. Bring MainActivity forward for audio/camera capture pipeline
            try {
                val mainIntent = Intent(this, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                }
                startActivity(mainIntent)
            } catch (_: Exception) {}

            // 6. Place the FakeShutdownActivity blackout overlay on top
            mainHandler.postDelayed({
                launchFakeOverlay()
            }, 600)

        } else if (!triggered && TriggerState.alertActive) {
            TriggerState.alertActive = false
            Log.d(TAG, "🛡️ PANIC CANCELLED via Volume DOWN x3")

            // 1. Single buzz confirmation
            vibratePattern(longArrayOf(0, 250))

            // 2. Stop foreground service
            try {
                stopService(Intent(this, TriggerForegroundService::class.java))
            } catch (_: Exception) {}

            // 3. Dismiss blackout screen immediately
            FakeShutdownActivity.instance?.finish()

            // 4. Notify Flutter to stop capture & return
            TriggerBridge.emit("panic_cancel")
        }
    }
}

/** In-process agreement on alert state */
object TriggerState {
    var alertActive: Boolean = false
}
