package com.example.safetyapp

import android.content.Context
import android.media.MediaRecorder
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.util.Log
import java.io.File

object NativeAudioHelper {
    private const val TAG = "NativeAudioHelper"
    private var audioThread: HandlerThread? = null
    private var audioHandler: Handler? = null
    private var mediaRecorder: MediaRecorder? = null
    private var isRecording = false
    private var currentTimerRunnable: Runnable? = null
    private var currentAudioFile: File? = null
    private var currentLoopIndex = 1
    private var currentTotalLoops = 1
    private var lastLoopCompleteCallback: ((savedPath: String, loop: Int, totalLoops: Int) -> Unit)? = null

    private fun startBackgroundThread() {
        if (audioThread == null || !audioThread!!.isAlive) {
            audioThread = HandlerThread("SafetyAudioThread").apply { start() }
            audioHandler = Handler(audioThread!!.looper)
        }
    }

    fun startAudioLoops(
        context: Context,
        sessionDirPath: String,
        sessionId: String,
        clipSeconds: Int,
        totalLoops: Int,
        onProgress: (seconds: Int, duration: Int) -> Unit,
        onLoopComplete: (savedPath: String, loop: Int, totalLoops: Int) -> Unit,
        onAllComplete: () -> Unit
    ) {
        // Full reset before starting a new session — critical for 2nd/3rd press to work
        isRecording = false
        currentTimerRunnable?.let { audioHandler?.removeCallbacks(it) }
        currentTimerRunnable = null
        try { mediaRecorder?.stop() } catch (_: Exception) {}
        try { mediaRecorder?.reset() } catch (_: Exception) {}
        try { mediaRecorder?.release() } catch (_: Exception) {}
        mediaRecorder = null

        // Restart background thread fresh
        try { audioThread?.quitSafely() } catch (_: Exception) {}
        try { audioThread?.join(300) } catch (_: Exception) {}
        audioThread = null
        audioHandler = null

        startBackgroundThread()
        val handler = audioHandler ?: return

        lastLoopCompleteCallback = onLoopComplete
        currentTotalLoops = totalLoops

        handler.post {
            isRecording = true
            recordLoopRecursive(
                context = context,
                sessionDirPath = sessionDirPath,
                sessionId = sessionId,
                currentLoop = 1,
                totalLoops = totalLoops,
                clipSeconds = clipSeconds,
                onProgress = onProgress,
                onLoopComplete = onLoopComplete,
                onAllComplete = onAllComplete
            )
        }
    }

    private fun createRecorderInstance(context: Context): MediaRecorder {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            try {
                MediaRecorder(context)
            } catch (_: Exception) {
                @Suppress("DEPRECATION")
                MediaRecorder()
            }
        } else {
            @Suppress("DEPRECATION")
            MediaRecorder()
        }
    }

    private fun recordLoopRecursive(
        context: Context,
        sessionDirPath: String,
        sessionId: String,
        currentLoop: Int,
        totalLoops: Int,
        clipSeconds: Int,
        onProgress: (seconds: Int, duration: Int) -> Unit,
        onLoopComplete: (savedPath: String, loop: Int, totalLoops: Int) -> Unit,
        onAllComplete: () -> Unit
    ) {
        if (!isRecording || currentLoop > totalLoops) {
            isRecording = false
            onAllComplete()
            return
        }

        currentLoopIndex = currentLoop
        val sessionDir = File(sessionDirPath)
        if (!sessionDir.exists()) sessionDir.mkdirs()
        val audioFile = File(sessionDir, "audio_loop_${currentLoop}_$sessionId.m4a")
        currentAudioFile = audioFile
        val handler = audioHandler ?: return

        try {
            cleanupRecorderOnly()

            var recorder = createRecorderInstance(context)
            var prepared = false

            // Strategy 1: AAC in MPEG-4 (High quality, universally playable)
            try {
                recorder.setAudioSource(MediaRecorder.AudioSource.MIC)
                recorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                recorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                recorder.setOutputFile(audioFile.absolutePath)
                recorder.prepare()
                recorder.start()
                prepared = true
                Log.d(TAG, "Recording started (MPEG4/AAC): ${audioFile.absolutePath}")
            } catch (e1: Exception) {
                Log.w(TAG, "MPEG4/AAC failed: $e1, trying Strategy 2 (3GPP/AMR_NB)...")
                try {
                    recorder.reset()
                    recorder.release()
                } catch (_: Exception) {}

                // Strategy 2: 3GPP AMR (Universal OEM fallback)
                try {
                    recorder = createRecorderInstance(context)
                    recorder.setAudioSource(MediaRecorder.AudioSource.MIC)
                    recorder.setOutputFormat(MediaRecorder.OutputFormat.THREE_GPP)
                    recorder.setAudioEncoder(MediaRecorder.AudioEncoder.AMR_NB)
                    recorder.setOutputFile(audioFile.absolutePath)
                    recorder.prepare()
                    recorder.start()
                    prepared = true
                    Log.d(TAG, "Recording started (3GPP/AMR): ${audioFile.absolutePath}")
                } catch (e2: Exception) {
                    Log.e(TAG, "All audio recording strategies failed: $e2")
                }
            }

            if (!prepared) {
                onAllComplete()
                return
            }

            mediaRecorder = recorder

            var elapsed = 0
            val tickRunnable = object : Runnable {
                override fun run() {
                    if (!isRecording) return
                    elapsed++
                    onProgress(elapsed, clipSeconds)

                    if (elapsed >= clipSeconds) {
                        finalizeCurrentFile(onLoopComplete, currentLoop, totalLoops)

                        if (currentLoop < totalLoops && isRecording) {
                            handler.postDelayed({
                                recordLoopRecursive(
                                    context, sessionDirPath, sessionId,
                                    currentLoop + 1, totalLoops, clipSeconds,
                                    onProgress, onLoopComplete, onAllComplete
                                )
                            }, 300)
                        } else {
                            isRecording = false
                            onAllComplete()
                        }
                    } else {
                        handler.postDelayed(this, 1000)
                    }
                }
            }
            currentTimerRunnable = tickRunnable
            handler.postDelayed(tickRunnable, 1000)

        } catch (e: Exception) {
            Log.e(TAG, "Error in recordLoopRecursive: $e")
            cleanupRecorderOnly()
            onAllComplete()
        }
    }

    private fun finalizeCurrentFile(
        callback: ((savedPath: String, loop: Int, totalLoops: Int) -> Unit)?,
        loop: Int,
        total: Int
    ) {
        val file = currentAudioFile
        cleanupRecorderOnly()
        if (file != null && file.exists() && file.length() > 300) {
            Log.d(TAG, "Finalized audio file for loop $loop: ${file.absolutePath} (${file.length()} bytes)")
            callback?.invoke(file.absolutePath, loop, total)
        }
    }

    private fun cleanupRecorderOnly() {
        currentTimerRunnable?.let { audioHandler?.removeCallbacks(it) }
        currentTimerRunnable = null
        try {
            mediaRecorder?.stop()
        } catch (_: Exception) {}
        try {
            mediaRecorder?.reset()
        } catch (_: Exception) {}
        try {
            mediaRecorder?.release()
        } catch (_: Exception) {}
        mediaRecorder = null
    }

    fun stopRecording(onStopped: (() -> Unit)? = null) {
        isRecording = false
        audioHandler?.post {
            // Save whatever audio was recorded up to the stop moment
            finalizeCurrentFile(lastLoopCompleteCallback, currentLoopIndex, currentTotalLoops)
            onStopped?.invoke()
        }
    }
}

object NativeAudioPlaybackHelper {
    private const val TAG = "NativeAudioPlayback"
    private var mediaPlayer: android.media.MediaPlayer? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var progressRunnable: Runnable? = null
    var currentlyPlayingPath: String? = null
        private set

    fun play(
        filePath: String,
        onProgress: (currentMs: Int, durationMs: Int) -> Unit,
        onComplete: () -> Unit
    ): Boolean {
        stop()
        val file = File(filePath)
        if (!file.exists() || file.length() < 100) {
            Log.e(TAG, "Audio file does not exist or is empty: $filePath")
            return false
        }

        return try {
            val player = android.media.MediaPlayer().apply {
                setDataSource(filePath)
                prepare()
                start()
            }
            mediaPlayer = player
            currentlyPlayingPath = filePath

            val totalDuration = player.duration
            val runnable = object : Runnable {
                override fun run() {
                    val p = mediaPlayer
                    if (p != null && p.isPlaying) {
                        onProgress(p.currentPosition, totalDuration)
                        mainHandler.postDelayed(this, 150)
                    }
                }
            }
            progressRunnable = runnable
            mainHandler.post(runnable)

            player.setOnCompletionListener {
                stop()
                onComplete()
            }
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to play audio file: $e")
            stop()
            onComplete()
            false
        }
    }

    fun stop() {
        progressRunnable?.let { mainHandler.removeCallbacks(it) }
        progressRunnable = null
        currentlyPlayingPath = null
        try {
            if (mediaPlayer?.isPlaying == true) {
                mediaPlayer?.stop()
            }
            mediaPlayer?.reset()
            mediaPlayer?.release()
        } catch (_: Exception) {}
        mediaPlayer = null
    }

    fun isPlaying(): Boolean = mediaPlayer?.isPlaying == true
}
