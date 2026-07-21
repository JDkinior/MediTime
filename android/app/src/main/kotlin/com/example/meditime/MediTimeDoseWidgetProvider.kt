package com.example.meditime

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class MediTimeDoseWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.meditime_dose_widget).apply {
                val medName = widgetData.getString("next_dose_med_name", null) ?: "No hay dosis pendientes"
                val doseTime = widgetData.getString("next_dose_time", null) ?: "--:--"
                val doseDetail = widgetData.getString("next_dose_detail", null) ?: "¡Todas tus dosis de hoy están al día! 🎉"
                val summary = widgetData.getString("widget_summary", null) ?: "Hoy: 0/0 tomadas"
                val docId = widgetData.getString("next_dose_doc_id", null) ?: ""
                val doseIsoTime = widgetData.getString("next_dose_iso_time", null) ?: ""

                setTextViewText(R.id.widget_med_name, medName)
                setTextViewText(R.id.widget_dose_detail, doseDetail)
                setTextViewText(R.id.widget_summary, summary)

                val hasPendingDose = docId.isNotEmpty() && doseIsoTime.isNotEmpty()

                if (hasPendingDose) {
                    // Hay dosis pendiente: Mostrar contenedor con los 3 botones e icono azul
                    setViewVisibility(R.id.widget_actions_container, View.VISIBLE)
                    setViewVisibility(R.id.widget_status_pending_container, View.VISIBLE)
                    setViewVisibility(R.id.widget_status_done_container, View.GONE)

                    // 1. Intent "Marcar como Tomada"
                    val takeUri = Uri.parse("meditime://take_dose?docId=$docId&doseTime=$doseIsoTime")
                    val takeIntent = HomeWidgetBackgroundIntent.getBroadcast(context, takeUri)
                    setOnClickPendingIntent(R.id.widget_btn_take_dose, takeIntent)

                    // 2. Intent "Aplazarla"
                    val postponeUri = Uri.parse("meditime://postpone_dose?docId=$docId&doseTime=$doseIsoTime")
                    val postponeIntent = HomeWidgetBackgroundIntent.getBroadcast(context, postponeUri)
                    setOnClickPendingIntent(R.id.widget_btn_postpone_dose, postponeIntent)

                    // 3. Intent "Omitirla"
                    val skipUri = Uri.parse("meditime://skip_dose?docId=$docId&doseTime=$doseIsoTime")
                    val skipIntent = HomeWidgetBackgroundIntent.getBroadcast(context, skipUri)
                    setOnClickPendingIntent(R.id.widget_btn_skip_dose, skipIntent)
                } else {
                    // No hay dosis pendiente: Ocultar los 3 botones y mostrar icono verde
                    setViewVisibility(R.id.widget_actions_container, View.GONE)
                    setViewVisibility(R.id.widget_status_pending_container, View.GONE)
                    setViewVisibility(R.id.widget_status_done_container, View.VISIBLE)
                }

                // Intent Asistente Midi
                val midiUri = Uri.parse("meditime://midi_chat")
                val midiIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    midiUri
                )
                setOnClickPendingIntent(R.id.widget_header_midi_btn, midiIntent)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
