package com.example.meditime

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * BroadcastReceiver que detiene el sonido y vibración de alarma inmediatamente.
 * Puede ser disparado desde CUALQUIER isolate/engine de Flutter o desde código nativo,
 * sin depender de que el MethodChannel esté registrado en el engine activo.
 *
 * Se dispara enviando el broadcast: "com.example.meditime.STOP_ALARM"
 */
class AlarmStopReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_STOP_ALARM = "com.example.meditime.STOP_ALARM"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_STOP_ALARM) {
            Log.d("AlarmStopReceiver", "📴 Broadcast recibido: deteniendo alarma...")
            AlarmSoundPlugin.stopAlarm(context)
            Log.d("AlarmStopReceiver", "✅ Alarma detenida.")
        }
    }
}
