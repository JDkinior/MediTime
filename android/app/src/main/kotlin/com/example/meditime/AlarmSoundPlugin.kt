package com.example.meditime

import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class AlarmSoundPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null
    private var context: Context? = null

    companion object {
        private const val TAG = "AlarmSoundPlugin"
        private var mediaPlayer: MediaPlayer? = null
        private var vibrator: Vibrator? = null

        @Synchronized
        fun startAlarm(ctx: Context) {
            stopAlarm(ctx)
            try {
                val alertUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                    ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
                    ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)

                mediaPlayer = MediaPlayer().apply {
                    setDataSource(ctx, alertUri)
                    setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ALARM)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build()
                    )
                    isLooping = true
                    prepare()
                    start()
                }

                // Iniciar vibración en bucle
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    val vibratorManager = ctx.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                    vibrator = vibratorManager.defaultVibrator
                } else {
                    @Suppress("DEPRECATION")
                    vibrator = ctx.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                }

                val pattern = longArrayOf(0, 1000, 500, 1000, 500)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    vibrator?.vibrate(VibrationEffect.createWaveform(pattern, 0))
                } else {
                    @Suppress("DEPRECATION")
                    vibrator?.vibrate(pattern, 0)
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        @Synchronized
        fun stopAlarm(ctx: Context? = null) {
            try {
                mediaPlayer?.let {
                    try {
                        if (it.isPlaying) {
                            it.stop()
                        }
                    } catch (_: Exception) {}
                    try {
                        it.reset()
                        it.release()
                    } catch (_: Exception) {}
                }
                mediaPlayer = null
            } catch (e: Exception) {
                e.printStackTrace()
            }

            try {
                vibrator?.cancel()
                vibrator = null
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.example.meditime/alarm_sound")
        channel?.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        context = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val ctx = context ?: return result.error("NO_CONTEXT", "Context is null", null)
        when (call.method) {
            "start" -> {
                startAlarm(ctx)
                result.success(true)
            }
            "stop" -> {
                stopAlarm(ctx)
                result.success(true)
            }
            "sendStopBroadcast" -> {
                val intent = Intent(AlarmStopReceiver.ACTION_STOP_ALARM).apply {
                    setPackage(ctx.packageName)
                }
                ctx.sendBroadcast(intent)
                result.success(true)
            }
            "attachDismissListener" -> {
                // Adjunta un deleteIntent a una notificación existente para que,
                // al ser descartada (swipe, clear all, timeout), Android envíe
                // automáticamente el broadcast STOP_ALARM y detenga el sonido.
                val notificationId = call.argument<Int>("notificationId")
                if (notificationId == null) {
                    result.error("INVALID_ARGS", "notificationId is required", null)
                    return
                }
                try {
                    val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    val activeNotifications = nm.activeNotifications
                    val target = activeNotifications.find { it.id == notificationId }

                    if (target != null) {
                        val notification = target.notification
                        // Crear PendingIntent que dispara AlarmStopReceiver al descartar
                        val deleteIntent = PendingIntent.getBroadcast(
                            ctx,
                            notificationId,
                            Intent(AlarmStopReceiver.ACTION_STOP_ALARM).apply {
                                setPackage(ctx.packageName)
                            },
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )
                        notification.deleteIntent = deleteIntent
                        // Re-publicar la notificación con el deleteIntent adjunto
                        nm.notify(notificationId, notification)
                        Log.d(TAG, "✅ deleteIntent adjuntado a notificación $notificationId")
                        result.success(true)
                    } else {
                        Log.w(TAG, "⚠️ Notificación $notificationId no encontrada en activas")
                        result.success(false)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error adjuntando deleteIntent: ${e.message}")
                    result.error("ATTACH_ERROR", e.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }
}
