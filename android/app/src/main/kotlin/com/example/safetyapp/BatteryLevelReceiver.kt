package com.example.safetyapp

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Android fires ACTION_BATTERY_LOW once when the system considers battery
 * "low" (historically ~15%, OEM-dependent) -- not a precise 20% threshold.
 * For the exact "<20%" behavior described in the plan, the Dart side polls
 * battery_plus on a timer instead (see home_screen.dart _watchBattery).
 * This receiver is kept as a coarse backup signal that can also trigger
 * the same Dart-side send via the event channel if desired.
 */
class BatteryLevelReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        TriggerBridge.emit("battery_low_system_signal")
    }
}
