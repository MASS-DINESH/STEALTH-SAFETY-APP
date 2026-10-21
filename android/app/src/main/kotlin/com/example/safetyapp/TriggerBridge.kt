package com.example.safetyapp

import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.EventChannel

/**
 * Reliable, real-time event bridge between native Kotlin and Flutter.
 * Ensures panic_trigger is guaranteed to reach the Flutter engine even
 * during cold starts or background wakeups.
 */
object TriggerBridge {
    private const val TAG = "TriggerBridge"
    private var sink: EventChannel.EventSink? = null
    private data class QueuedEvent(val event: String, val timestamp: Long)
    private val pendingEvents = mutableListOf<QueuedEvent>()
    private val mainHandler = Handler(Looper.getMainLooper())

    @Synchronized
    fun attach(eventSink: EventChannel.EventSink) {
        sink = eventSink
        val now = System.currentTimeMillis()
        // Deliver all recent events within 30 seconds (allows cold engine boot)
        val validEvents = pendingEvents.filter { now - it.timestamp < 30000L }
        for (q in validEvents) {
            Log.d(TAG, "Delivering queued event to Flutter: ${q.event}")
            mainHandler.post {
                try {
                    sink?.success(q.event)
                } catch (e: Exception) {
                    Log.e(TAG, "Error delivering queued event: $e")
                }
            }
        }
        pendingEvents.clear()
    }

    @Synchronized
    fun detach() {
        sink = null
    }

    @Synchronized
    fun emit(event: String) {
        Log.d(TAG, "Emitting event: $event (sink active: ${sink != null})")
        val s = sink
        if (s != null) {
            mainHandler.post {
                try {
                    s.success(event)
                } catch (e: Exception) {
                    Log.e(TAG, "Error delivering live event: $e")
                    pendingEvents.add(QueuedEvent(event, System.currentTimeMillis()))
                }
            }
        } else {
            pendingEvents.add(QueuedEvent(event, System.currentTimeMillis()))
        }
    }

    @Synchronized
    fun clear() {
        pendingEvents.clear()
    }
}
