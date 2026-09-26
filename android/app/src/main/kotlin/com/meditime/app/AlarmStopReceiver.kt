package com.meditime.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * BroadcastReceiver que controla el sonido y vibración de alarma inmediatamente.
 * Puede ser disparado desde CUALQUIER isolate/engine de Flutter o desde código nativo,
 * sin depender de que el MethodChannel esté registrado en el engine activo.
 *
 * Acciones soportadas:
 * - "com.meditime.app.STOP_ALARM": Detiene inmediatamente el audio y vibración.
 * - "com.meditime.app.START_ALARM": Inicia el audio y vibración con el tono configurado.
 */
class AlarmStopReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_STOP_ALARM = "com.meditime.app.STOP_ALARM"
        const val ACTION_START_ALARM = "com.meditime.app.START_ALARM"
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_STOP_ALARM -> {
                Log.d("AlarmStopReceiver", "📴 Broadcast recibido: deteniendo alarma...")
                AlarmSoundPlugin.stopAlarm(context)
                Log.d("AlarmStopReceiver", "✅ Alarma detenida.")
            }
            ACTION_START_ALARM -> {
                Log.d("AlarmStopReceiver", "🚨 Broadcast recibido: iniciando alarma...")
                val uriStr = intent.getStringExtra("uri")
                val resourceName = intent.getStringExtra("resourceName")
                val soundType = intent.getStringExtra("soundType")
                AlarmSoundPlugin.startAlarm(context, uriStr, resourceName, soundType)
                Log.d("AlarmStopReceiver", "✅ Alarma iniciada.")
            }
        }
    }
}
