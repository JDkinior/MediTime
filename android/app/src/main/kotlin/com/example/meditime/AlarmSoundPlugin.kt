package com.example.meditime

import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class AlarmSoundPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null
    private var context: Context? = null

    companion object {
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
                    if (it.isPlaying) {
                        it.stop()
                    }
                    it.release()
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
                // Enviar un broadcast local que el AlarmStopReceiver interceptará
                // y llamará stopAlarm() directamente en la JVM estática.
                val intent = Intent(AlarmStopReceiver.ACTION_STOP_ALARM).apply {
                    setPackage(ctx.packageName)
                }
                ctx.sendBroadcast(intent)
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }
}
