package com.meditime.app

import android.app.Activity
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

class AlarmSoundPlugin : FlutterPlugin, ActivityAware, PluginRegistry.ActivityResultListener, MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null
    private var context: Context? = null
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var pendingPickerResult: MethodChannel.Result? = null

    companion object {
        private const val TAG = "AlarmSoundPlugin"
        private const val REQUEST_CODE_RINGTONE_PICKER = 9921
        private var mediaPlayer: MediaPlayer? = null
        private var previewPlayer: MediaPlayer? = null
        private var vibrator: Vibrator? = null
        private var wakeLock: PowerManager.WakeLock? = null
        private val mainHandler = Handler(Looper.getMainLooper())
        private var previewStopRunnable: Runnable? = null

        private fun getRawResourceUri(ctx: Context, resourceName: String): Uri? {
            val resId = ctx.resources.getIdentifier(resourceName, "raw", ctx.packageName)
            if (resId != 0) {
                return Uri.parse("android.resource://${ctx.packageName}/$resId")
            }
            return null
        }

        fun resolveSoundUri(
            ctx: Context,
            uriStr: String?,
            resourceName: String?,
            soundType: String?
        ): Uri {
            // 1. Tono personalizado en res/raw
            if (!resourceName.isNullOrEmpty()) {
                val rawUri = getRawResourceUri(ctx, resourceName)
                if (rawUri != null) return rawUri
            }

            // 2. URI explícito proporcionado
            if (!uriStr.isNullOrEmpty()) {
                try {
                    return Uri.parse(uriStr)
                } catch (e: Exception) {
                    Log.w(TAG, "Error parseando uriStr: $uriStr", e)
                }
            }

            // 3. Tono de llamada del sistema
            if (soundType == "system_ringtone") {
                val ringtoneUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
                if (ringtoneUri != null) return ringtoneUri
            }

            // 4. Tono de alarma del sistema (fallback principal)
            return RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                ?: Settings.System.DEFAULT_ALARM_ALERT_URI
        }

        @Synchronized
        fun startAlarm(
            ctx: Context,
            uriStr: String? = null,
            resourceName: String? = null,
            soundType: String? = null
        ) {
            stopAlarm(ctx)
            stopPreview()

            try {
                val soundUri = resolveSoundUri(ctx, uriStr, resourceName, soundType)
                Log.d(TAG, "Iniciando alarma con URI: $soundUri")

                // WakeLock para asegurar que no se duerma el CPU
                try {
                    val powerManager = ctx.getSystemService(Context.POWER_SERVICE) as PowerManager
                    wakeLock = powerManager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "MediTime:AlarmSoundWakeLock").apply {
                        setReferenceCounted(false)
                        acquire(10 * 60 * 1000L) // Máximo 10 minutos
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "No se pudo adquirir WakeLock: $e")
                }

                mediaPlayer = MediaPlayer().apply {
                    setDataSource(ctx, soundUri)
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
                Log.e(TAG, "Error iniciando alarma con sonido", e)
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
                Log.e(TAG, "Error deteniendo mediaPlayer", e)
            }

            try {
                vibrator?.cancel()
                vibrator = null
            } catch (e: Exception) {
                Log.e(TAG, "Error cancelando vibrador", e)
            }

            try {
                wakeLock?.let {
                    if (it.isHeld) it.release()
                }
                wakeLock = null
            } catch (_: Exception) {}

            // Silenciar y cancelar cualquier notificación de alarma activa en el sistema Android
            ctx?.let { c ->
                try {
                    val nm = c.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                    val active = nm?.activeNotifications
                    active?.forEach { sbn ->
                        val chId = sbn.notification.channelId ?: ""
                        if (chId.startsWith("meditime_alarm")) {
                            nm.cancel(sbn.id)
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error cancelando notificaciones de alarma", e)
                }
            }
        }

        @Synchronized
        fun playPreview(
            ctx: Context,
            uriStr: String? = null,
            resourceName: String? = null,
            soundType: String? = null
        ) {
            stopPreview()
            try {
                val soundUri = resolveSoundUri(ctx, uriStr, resourceName, soundType)
                Log.d(TAG, "Reproduciendo vista previa de tono: $soundUri")

                previewPlayer = MediaPlayer().apply {
                    setDataSource(ctx, soundUri)
                    setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ALARM)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build()
                    )
                    isLooping = false
                    prepare()
                    start()
                }

                // Auto-detener después de 5 segundos
                previewStopRunnable = Runnable {
                    stopPreview()
                }
                mainHandler.postDelayed(previewStopRunnable!!, 5000L)
            } catch (e: Exception) {
                Log.e(TAG, "Error reproduciendo preview", e)
            }
        }

        @Synchronized
        fun stopPreview() {
            previewStopRunnable?.let { mainHandler.removeCallbacks(it) }
            previewStopRunnable = null
            try {
                previewPlayer?.let {
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
                previewPlayer = null
            } catch (e: Exception) {
                Log.e(TAG, "Error deteniendo previewPlayer", e)
            }
        }

        fun getSystemRingtones(ctx: Context): List<Map<String, String>> {
            val result = mutableListOf<Map<String, String>>()
            try {
                val manager = RingtoneManager(ctx)
                manager.setType(RingtoneManager.TYPE_ALARM)
                val cursor = manager.cursor
                while (cursor != null && cursor.moveToNext()) {
                    val title = cursor.getString(RingtoneManager.TITLE_COLUMN_INDEX)
                    val uri = manager.getRingtoneUri(cursor.position)?.toString() ?: ""
                    val id = cursor.getString(RingtoneManager.ID_COLUMN_INDEX) ?: ""
                    if (uri.isNotEmpty() && !title.isNullOrEmpty()) {
                        result.add(mapOf("id" to id, "title" to title, "uri" to uri))
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error obteniendo tonos del sistema", e)
            }
            return result
        }
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.meditime.app/alarm_sound")
        channel?.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        context = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val ctx = context ?: return result.error("NO_CONTEXT", "Context is null", null)
        when (call.method) {
            "start" -> {
                val uriStr = call.argument<String>("uri")
                val resourceName = call.argument<String>("resourceName")
                val soundType = call.argument<String>("soundType")
                startAlarm(ctx, uriStr, resourceName, soundType)
                result.success(true)
            }
            "stop" -> {
                stopAlarm(ctx)
                result.success(true)
            }
            "playPreview" -> {
                val uriStr = call.argument<String>("uri")
                val resourceName = call.argument<String>("resourceName")
                val soundType = call.argument<String>("soundType")
                playPreview(ctx, uriStr, resourceName, soundType)
                result.success(true)
            }
            "stopPreview" -> {
                stopPreview()
                result.success(true)
            }
            "getRingtones" -> {
                val ringtones = getSystemRingtones(ctx)
                result.success(ringtones)
            }
            "getDefaultAlarmUri" -> {
                val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)?.toString()
                    ?: Settings.System.DEFAULT_ALARM_ALERT_URI.toString()
                result.success(uri)
            }
            "getDefaultRingtoneUri" -> {
                val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)?.toString()
                    ?: Settings.System.DEFAULT_RINGTONE_URI.toString()
                result.success(uri)
            }
            "openRingtonePicker" -> {
                val currentUriStr = call.argument<String>("currentUri")
                launchRingtonePicker(currentUriStr, result)
            }
            "sendStopBroadcast" -> {
                val intent = Intent(AlarmStopReceiver.ACTION_STOP_ALARM).apply {
                    setPackage(ctx.packageName)
                }
                ctx.sendBroadcast(intent)
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun launchRingtonePicker(currentUriStr: String?, result: MethodChannel.Result) {
        val act = activity
        if (act == null) {
            result.error("NO_ACTIVITY", "Activity no disponible para abrir selector", null)
            return
        }
        if (pendingPickerResult != null) {
            result.error("ALREADY_ACTIVE", "Ya hay un selector de tonos activo", null)
            return
        }

        pendingPickerResult = result
        try {
            val currentUri = if (!currentUriStr.isNullOrEmpty()) Uri.parse(currentUriStr) else null
            val intent = Intent(RingtoneManager.ACTION_RINGTONE_PICKER).apply {
                putExtra(
                    RingtoneManager.EXTRA_RINGTONE_TYPE,
                    RingtoneManager.TYPE_ALARM or RingtoneManager.TYPE_RINGTONE
                )
                putExtra(RingtoneManager.EXTRA_RINGTONE_TITLE, "Seleccionar tono de alarma")
                putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, true)
                putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
                putExtra(RingtoneManager.EXTRA_RINGTONE_DEFAULT_URI, RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM))
                if (currentUri != null) {
                    putExtra(RingtoneManager.EXTRA_RINGTONE_EXISTING_URI, currentUri)
                }
            }
            act.startActivityForResult(intent, REQUEST_CODE_RINGTONE_PICKER)
        } catch (e: Exception) {
            pendingPickerResult = null
            result.error("INTENT_ERROR", "Error lanzando selector: ${e.message}", null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == REQUEST_CODE_RINGTONE_PICKER) {
            val result = pendingPickerResult ?: return false
            pendingPickerResult = null

            if (resultCode == Activity.RESULT_OK && data != null) {
                val uri: Uri? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    data.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI, Uri::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    data.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
                }

                if (uri != null) {
                    val ctx = context
                    var title = "Tono del teléfono"
                    if (ctx != null) {
                        try {
                            val ringtone = RingtoneManager.getRingtone(ctx, uri)
                            val rTitle = ringtone?.getTitle(ctx)
                            if (!rTitle.isNullOrEmpty()) {
                                title = rTitle
                            }
                        } catch (_: Exception) {}
                    }
                    result.success(mapOf("uri" to uri.toString(), "title" to title))
                } else {
                    result.success(null)
                }
            } else {
                result.success(null)
            }
            return true
        }
        return false
    }
}
