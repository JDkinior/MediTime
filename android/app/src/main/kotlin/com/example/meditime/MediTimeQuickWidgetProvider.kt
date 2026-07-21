package com.example.meditime

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetProvider

class MediTimeQuickWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.meditime_quick_widget).apply {
                val medName = widgetData.getString("next_dose_med_name", null) ?: "No hay dosis pendientes"
                val doseTime = widgetData.getString("next_dose_time", null) ?: "--:--"
                val doseDetail = widgetData.getString("next_dose_detail", null) ?: "¡Todas tus dosis de hoy están al día! 🎉"
                val docId = widgetData.getString("next_dose_doc_id", null) ?: ""
                val doseIsoTime = widgetData.getString("next_dose_iso_time", null) ?: ""

                setTextViewText(R.id.quick_widget_med_name, medName)
                setTextViewText(R.id.quick_widget_time, doseTime)
                setTextViewText(R.id.quick_widget_med_detail, doseDetail)

                val hasPendingDose = docId.isNotEmpty() && doseIsoTime.isNotEmpty()

                if (hasPendingDose) {
                    // Hay dosis pendiente: Mostrar los 3 botones de icono
                    setViewVisibility(R.id.quick_widget_actions_container, View.VISIBLE)

                    // 1. Intent "Tomar"
                    val takeUri = Uri.parse("meditime://take_dose?docId=$docId&doseTime=$doseIsoTime")
                    val takeIntent = HomeWidgetBackgroundIntent.getBroadcast(context, takeUri)
                    setOnClickPendingIntent(R.id.quick_widget_btn_take, takeIntent)

                    // 2. Intent "Aplazar"
                    val postponeUri = Uri.parse("meditime://postpone_dose?docId=$docId&doseTime=$doseIsoTime")
                    val postponeIntent = HomeWidgetBackgroundIntent.getBroadcast(context, postponeUri)
                    setOnClickPendingIntent(R.id.quick_widget_btn_postpone, postponeIntent)

                    // 3. Intent "Omitir"
                    val skipUri = Uri.parse("meditime://skip_dose?docId=$docId&doseTime=$doseIsoTime")
                    val skipIntent = HomeWidgetBackgroundIntent.getBroadcast(context, skipUri)
                    setOnClickPendingIntent(R.id.quick_widget_btn_skip, skipIntent)
                } else {
                    // No hay dosis pendiente: Ocultar botones de icono
                    setViewVisibility(R.id.quick_widget_actions_container, View.GONE)
                }
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
