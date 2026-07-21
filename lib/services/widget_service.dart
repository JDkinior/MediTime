// lib/services/widget_service.dart
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:meditime/firebase_options.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:meditime/screens/chat/chat_bot_screen.dart';
import 'package:meditime/services/firestore_service.dart';
import 'package:meditime/services/preference_service.dart';
import 'package:meditime/services/notification_service.dart';

/// Callback estático invocado en segundo plano cuando el usuario interactúa
/// con los botones del Widget de Android ("Tomar", "Aplazar", "Omitir").
@pragma('vm:entry-point')
Future<void> homeWidgetBackgroundCallback(Uri? uri) async {
  if (uri == null) return;
  debugPrint('🤖 HomeWidget Callback recibido: $uri');

  final uriStr = uri.toString();
  String? docId = uri.queryParameters['docId'];
  String? doseTimeStr = uri.queryParameters['doseTime'];

  if (docId == null && uriStr.contains('docId=')) {
    final regExp = RegExp(r'docId=([^&]+)');
    final match = regExp.firstMatch(uriStr);
    docId = match?.group(1);
  }

  if (doseTimeStr == null && uriStr.contains('doseTime=')) {
    final regExp = RegExp(r'doseTime=([^&]+)');
    final match = regExp.firstMatch(uriStr);
    doseTimeStr = match?.group(1);
  }

  if (docId != null && doseTimeStr != null) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      final userId = await PreferenceService().getCurrentUserId();
      if (userId == null || userId.isEmpty) return;

      final doseTime = DateTime.parse(Uri.decodeComponent(doseTimeStr));
      final firestoreService = FirestoreService();

      if (uriStr.contains('take_dose')) {
        await firestoreService.updateDoseStatus(
          userId,
          docId,
          doseTime,
          DoseStatus.tomada,
        );
        await NotificationService.showSimpleNotification(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: '¡Dosis marcada como tomada! 💊',
          body: 'Se ha registrado la toma desde el Widget de MediTime.',
        );
      } else if (uriStr.contains('postpone_dose')) {
        await firestoreService.updateDoseStatus(
          userId,
          docId,
          doseTime,
          DoseStatus.aplazada,
        );
        await NotificationService.showSimpleNotification(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: 'Dosis aplazada ⏰',
          body: 'Se ha aplazado la dosis correctamente.',
        );
      } else if (uriStr.contains('skip_dose')) {
        await firestoreService.updateDoseStatus(
          userId,
          docId,
          doseTime,
          DoseStatus.omitida,
        );
        await NotificationService.showSimpleNotification(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: 'Dosis omitida 🚫',
          body: 'Has omitido esta dosis.',
        );
      }

      await WidgetService.updateWidgetData(userId: userId);
    } catch (e) {
      debugPrint('Error en callback de segundo plano de HomeWidget: $e');
    }
  }
}


/// Servicio encargado de la comunicación entre MediTime y los Widgets nativos de Android.
class WidgetService {
  static const String androidDoseWidget = 'MediTimeDoseWidgetProvider';
  static const String androidQuickWidget = 'MediTimeQuickWidgetProvider';

  /// Registra los callbacks de interactividad en segundo plano con HomeWidget.
  static Future<void> initialize() async {
    try {
      await HomeWidget.registerInteractivityCallback(homeWidgetBackgroundCallback);
    } catch (e) {
      debugPrint('Error al registrar callback de HomeWidget: $e');
    }
  }

  /// Recalcula y envía la información actualizada de las dosis del día a los Widgets nativos.
  static Future<void> updateWidgetData({
    String? userId,
    List<Tratamiento>? tratamientos,
  }) async {
    try {
      final activeUserId = userId ?? await PreferenceService().getCurrentUserId();
      if (activeUserId == null || activeUserId.isEmpty) return;

      List<Tratamiento> list = tratamientos ?? [];
      if (list.isEmpty) {
        final firestoreService = FirestoreService();
        final stream = firestoreService.getMedicamentosStream(activeUserId);
        list = await stream.first.timeout(
          const Duration(seconds: 4),
          onTimeout: () => [],
        );
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      int tomadasHoy = 0;
      int totalHoy = 0;

      Tratamiento? proximaTratamiento;
      DateTime? proximaFechaDosis;

      for (final t in list) {
        if (t.intervaloDosis.inHours <= 0) continue;

        DateTime current = DateTime(
          t.fechaInicioTratamiento.year,
          t.fechaInicioTratamiento.month,
          t.fechaInicioTratamiento.day,
          t.horaPrimeraDosis.hour,
          t.horaPrimeraDosis.minute,
        );

        while (current.isBefore(t.fechaFinTratamiento) ||
            current.isAtSameMomentAs(t.fechaFinTratamiento)) {
          final isToday = current.year == today.year &&
              current.month == today.month &&
              current.day == today.day;

          if (isToday) {
            totalHoy++;
            final status = t.doseStatus[current.toIso8601String()] ?? DoseStatus.pendiente;
            if (status == DoseStatus.tomada) {
              tomadasHoy++;
            } else if (status != DoseStatus.omitida) {
              // Dosis pendiente, notificada o aplazada
              if (proximaFechaDosis == null || current.isBefore(proximaFechaDosis)) {
                proximaFechaDosis = current;
                proximaTratamiento = t;
              }
            }
          }
          current = current.add(t.intervaloDosis);
        }
      }

      if (proximaTratamiento != null && proximaFechaDosis != null) {
        final timeFormat = DateFormat('hh:mm a');
        final formattedTime = timeFormat.format(proximaFechaDosis);

        await HomeWidget.saveWidgetData<String>(
          'next_dose_med_name',
          proximaTratamiento.nombreMedicamento,
        );
        await HomeWidget.saveWidgetData<String>(
          'next_dose_time',
          formattedTime,
        );
        await HomeWidget.saveWidgetData<String>(
          'next_dose_detail',
          '$formattedTime • Dosis: ${proximaTratamiento.dosisPorToma} (${proximaTratamiento.presentacion})',
        );
        await HomeWidget.saveWidgetData<String>(
          'next_dose_doc_id',
          proximaTratamiento.id,
        );
        await HomeWidget.saveWidgetData<String>(
          'next_dose_iso_time',
          proximaFechaDosis.toIso8601String(),
        );
      } else {
        await HomeWidget.saveWidgetData<String>(
          'next_dose_med_name',
          'No hay dosis pendientes',
        );
        await HomeWidget.saveWidgetData<String>(
          'next_dose_time',
          '--:--',
        );
        await HomeWidget.saveWidgetData<String>(
          'next_dose_detail',
          '¡Todas tus dosis de hoy están al día! 🎉',
        );
        await HomeWidget.saveWidgetData<String>('next_dose_doc_id', '');
        await HomeWidget.saveWidgetData<String>('next_dose_iso_time', '');
      }

      await HomeWidget.saveWidgetData<String>(
        'widget_summary',
        'Hoy: $tomadasHoy/$totalHoy tomadas',
      );

      // Enviar señal de actualización a Android RemoteViews
      await HomeWidget.updateWidget(androidName: androidDoseWidget);
      await HomeWidget.updateWidget(androidName: androidQuickWidget);
    } catch (e) {
      debugPrint('Error actualizando datos de HomeWidget: $e');
    }
  }

  /// Verifica si la app fue abierta desde el Widget (ej. al pulsar "Asistente Midi").
  static Future<void> handleWidgetLaunch(BuildContext context) async {
    try {
      final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      if (uri != null && (uri.host == 'midi_chat' || uri.path.contains('midi_chat'))) {
        if (context.mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const ChatBotScreen(),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error procesando el inicio desde HomeWidget: $e');
    }
  }
}
