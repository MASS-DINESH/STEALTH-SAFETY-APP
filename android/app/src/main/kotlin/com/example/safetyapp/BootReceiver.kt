package com.example.safetyapp

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Restarts the trigger foreground service after a reboot if an alert was
 * mid-flight (rare edge case), and more importantly ensures the
 * AccessibilityService (which the OS re-binds automatically) has a
 * consistent TriggerState to start from.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            TriggerState.alertActive = false
        }
    }
}
