package com.example.safetyapp

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.ImageFormat
import android.hardware.camera2.*
import android.media.ImageReader
import android.os.Handler
import android.os.HandlerThread
import android.util.Log
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Semaphore
import java.util.concurrent.TimeUnit

object NativeCameraHelper {
    private const val TAG = "NativeCameraHelper"
    private var cameraThread: HandlerThread? = null
    private var cameraHandler: Handler? = null
    private val cameraOpenCloseLock = Semaphore(1)

    private fun startBackgroundThread() {
        if (cameraThread == null) {
            cameraThread = HandlerThread("SafetyCameraThread").apply { start() }
            cameraHandler = Handler(cameraThread!!.looper)
        }
    }

    private fun stopBackgroundThread() {
        cameraThread?.quitSafely()
        try {
            cameraThread?.join(500)
            cameraThread = null
            cameraHandler = null
        } catch (_: Exception) {}
    }

    @SuppressLint("MissingPermission")
    fun capturePhotos(
        context: Context,
        sessionDirPath: String,
        sessionId: String,
        count: Int,
        onPhotoCaptured: (savedPath: String, index: Int, total: Int) -> Unit,
        onComplete: () -> Unit
    ) {
        // Always reset the semaphore and background thread for a clean new session
        try { cameraThread?.quitSafely() } catch (_: Exception) {}
        try { cameraThread?.join(300) } catch (_: Exception) {}
        cameraThread = null
        cameraHandler = null
        // Drain any leftover permits from a previous session so tryAcquire always works
        cameraOpenCloseLock.drainPermits()
        cameraOpenCloseLock.release()

        startBackgroundThread()
        val handler = cameraHandler ?: return

        handler.post {
            val manager = context.getSystemService(Context.CAMERA_SERVICE) as? CameraManager
            if (manager == null) {
                onComplete()
                return@post
            }

            try {
                val cameraIdList = manager.cameraIdList
                if (cameraIdList.isEmpty()) {
                    onComplete()
                    return@post
                }

                // Choose back camera if available
                var targetCameraId = cameraIdList[0]
                for (id in cameraIdList) {
                    val characteristics = manager.getCameraCharacteristics(id)
                    val facing = characteristics.get(CameraCharacteristics.LENS_FACING)
                    if (facing == CameraCharacteristics.LENS_FACING_BACK) {
                        targetCameraId = id
                        break
                    }
                }

                val imageReader = ImageReader.newInstance(1280, 720, ImageFormat.JPEG, 3)
                var cameraDevice: CameraDevice? = null
                var captureSession: CameraCaptureSession? = null

                if (!cameraOpenCloseLock.tryAcquire(2500, TimeUnit.MILLISECONDS)) {
                    onComplete()
                    return@post
                }

                manager.openCamera(targetCameraId, object : CameraDevice.StateCallback() {
                    override fun onOpened(camera: CameraDevice) {
                        cameraOpenCloseLock.release()
                        cameraDevice = camera

                        try {
                            camera.createCaptureSession(
                                listOf(imageReader.surface),
                                object : CameraCaptureSession.StateCallback() {
                                    override fun onConfigured(session: CameraCaptureSession) {
                                        captureSession = session
                                        var capturedCount = 0

                                        imageReader.setOnImageAvailableListener({ reader ->
                                            val image = reader.acquireLatestImage() ?: return@setOnImageAvailableListener
                                            val buffer = image.planes[0].buffer
                                            val bytes = ByteArray(buffer.remaining())
                                            buffer.get(bytes)
                                            image.close()

                                            capturedCount++
                                            val currentIndex = capturedCount
                                            val sessionDir = File(sessionDirPath)
                                            if (!sessionDir.exists()) sessionDir.mkdirs()
                                            val photoFile = File(sessionDir, "photo_${currentIndex}_$sessionId.jpg")
                                            try {
                                                FileOutputStream(photoFile).use { it.write(bytes) }
                                                Log.d(TAG, "Captured native photo #$currentIndex: ${photoFile.absolutePath}")
                                                onPhotoCaptured(photoFile.absolutePath, currentIndex, count)
                                            } catch (e: Exception) {
                                                Log.e(TAG, "Error saving photo: $e")
                                            }

                                            if (currentIndex >= count) {
                                                try {
                                                    captureSession?.close()
                                                    cameraDevice?.close()
                                                } catch (_: Exception) {}
                                                onComplete()
                                            }
                                        }, handler)

                                        // Capture N photos rapidly
                                        for (i in 1..count) {
                                            handler.postDelayed({
                                                try {
                                                    val builder = camera.createCaptureRequest(CameraDevice.TEMPLATE_STILL_CAPTURE).apply {
                                                        addTarget(imageReader.surface)
                                                        set(CaptureRequest.CONTROL_MODE, CameraMetadata.CONTROL_MODE_AUTO)
                                                        set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE)
                                                        set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON)
                                                        set(CaptureRequest.JPEG_QUALITY, 85.toByte())
                                                    }
                                                    session.capture(builder.build(), null, handler)
                                                } catch (e: Exception) {
                                                    Log.e(TAG, "Capture request failed: $e")
                                                }
                                            }, (i - 1) * 450L)
                                        }
                                    }

                                    override fun onConfigureFailed(session: CameraCaptureSession) {
                                        try {
                                            cameraDevice?.close()
                                        } catch (_: Exception) {}
                                        onComplete()
                                    }
                                },
                                handler
                            )
                        } catch (e: Exception) {
                            Log.e(TAG, "CreateCaptureSession error: $e")
                            try { cameraDevice?.close() } catch (_: Exception) {}
                            onComplete()
                        }
                    }

                    override fun onDisconnected(camera: CameraDevice) {
                        cameraOpenCloseLock.release()
                        camera.close()
                    }

                    override fun onError(camera: CameraDevice, error: Int) {
                        cameraOpenCloseLock.release()
                        camera.close()
                        onComplete()
                    }
                }, handler)

            } catch (e: Exception) {
                Log.e(TAG, "Failed to capture native photos: $e")
                onComplete()
            }
        }
    }
}
