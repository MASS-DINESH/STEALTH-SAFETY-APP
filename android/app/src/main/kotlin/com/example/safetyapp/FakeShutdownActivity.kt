package com.example.safetyapp

import android.app.Activity
import android.app.KeyguardManager
import android.content.pm.ActivityInfo
import android.os.Build
import android.os.Bundle
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager

/**
 * Fixed 100% pitch-black screen overlay that completely locks down the device
 * during an active emergency:
 *
 *  - Screen is locked to PORTRAIT — never rotates.
 *  - All touch / gesture / navigation events are silently consumed.
 *  - Status bar, notification shade and control center are hidden.
 *  - Only Volume DOWN ×3 dismisses and stops the emergency alert.
 */
class FakeShutdownActivity : Activity() {

    companion object {
        var instance: FakeShutdownActivity? = null
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        instance = this

        try {
            requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
        } catch (_: Exception) {}

        overridePendingTransition(0, 0)

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(true)
                setTurnScreenOn(true)
                val km = getSystemService(KeyguardManager::class.java)
                km?.requestDismissKeyguard(this, null)
            }
        } catch (_: Exception) {}

        try {
            val lp = window.attributes
            lp.screenBrightness = 0.01f
            window.attributes = lp
        } catch (_: Exception) {}

        @Suppress("DEPRECATION")
        try {
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_FULLSCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
            )
        } catch (_: Exception) {}

        applyImmersiveMode()
        setContentView(R.layout.activity_fake_shutdown)

        // Intercept touch on root decor view
        window.decorView.setOnTouchListener { _, _ -> true }
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        applyImmersiveMode()
    }

    override fun onResume() {
        super.onResume()
        overridePendingTransition(0, 0)
        applyImmersiveMode()
    }

    private fun applyImmersiveMode() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                window.insetsController?.let { ctrl ->
                    ctrl.hide(
                        android.view.WindowInsets.Type.statusBars() or
                        android.view.WindowInsets.Type.navigationBars() or
                        android.view.WindowInsets.Type.systemBars()
                    )
                    ctrl.systemBarsBehavior =
                        android.view.WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                }
            }

            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = (
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_FULLSCREEN
            )
        } catch (_: Exception) {}
    }

    // Completely swallow all touch and motion events
    override fun dispatchTouchEvent(ev: MotionEvent?): Boolean = true
    override fun onTouchEvent(event: MotionEvent?): Boolean = true
    override fun onGenericMotionEvent(event: MotionEvent?): Boolean = true
    override fun onTrackballEvent(event: MotionEvent?): Boolean = true

    // Completely swallow all key inputs except volume (handled by AccessibilityService)
    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean = true
    override fun onKeyUp(keyCode: Int, event: KeyEvent?): Boolean = true
    override fun onKeyLongPress(keyCode: Int, event: KeyEvent?): Boolean = true
    override fun onKeyMultiple(keyCode: Int, repeatCount: Int, event: KeyEvent?): Boolean = true

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        // Intentionally does nothing
    }

    override fun onDestroy() {
        super.onDestroy()
        overridePendingTransition(0, 0)
        if (instance == this) {
            instance = null
        }
    }
}
