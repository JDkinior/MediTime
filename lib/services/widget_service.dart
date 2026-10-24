// lib/services/widget_service.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:meditime/core/utils.dart';
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
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }
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
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

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
          title: '¡Dosis marcada como tomada!',
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
          title: 'Dosis aplazada',
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
          title: 'Dosis omitida',
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
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await HomeWidget.registerInteractivityCallback(
        homeWidgetBackgroundCallback,
      );
    } catch (e) {
      debugPrint('Error al registrar callback de HomeWidget: $e');
    }
  }

  /// Limpia la información del Widget al cerrar sesión o eliminar la cuenta para evitar fuga de datos médicos.
  static Future<void> clearWidgetData() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await HomeWidget.saveWidgetData<String>(
        'next_dose_med_name',
        'No hay dosis pendientes',
      );
      await HomeWidget.saveWidgetData<String>('next_dose_time', '--:--');
      await HomeWidget.saveWidgetData<String>(
        'next_dose_detail',
        'Inicia sesión en MediTime para ver tus recordatorios.',
      );
      await HomeWidget.saveWidgetData<String>('next_dose_doc_id', '');
      await HomeWidget.saveWidgetData<String>('next_dose_iso_time', '');
      await HomeWidget.saveWidgetData<String>(
        'widget_summary',
        'Hoy: 0/0 tomadas',
      );
      await HomeWidget.updateWidget(androidName: androidDoseWidget);
      await HomeWidget.updateWidget(androidName: androidQuickWidget);
    } catch (e) {
      debugPrint('Error limpiando datos de HomeWidget: $e');
    }
  }

  /// Recalcula y envía la información actualizada de las dosis del día a los Widgets nativos.
  static Future<void> updateWidgetData({
    String? userId,
    List<Tratamiento>? tratamientos,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final prefService = PreferenceService();
      final activeUserId =
          userId ?? await prefService.getCurrentUserId();
      if (activeUserId == null || activeUserId.isEmpty) {
        await clearWidgetData();
        return;
      }

      final hideMedName = await prefService.getHideMedicineNameOnLockScreen(
        reload: false,
      );

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
      final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

      int tomadasHoy = 0;
      int totalHoy = 0;

      Tratamiento? proximaTratamiento;
      DateTime? proximaFechaDosis;

      for (final t in list) {
        if (t.intervaloDosis.inMinutes <= 0) continue;

        final finDelDiaTratamiento = DateTime(
          t.fechaFinTratamiento.year,
          t.fechaFinTratamiento.month,
          t.fechaFinTratamiento.day,
          23,
          59,
          59,
          999,
        );
        if (finDelDiaTratamiento.isBefore(today)) continue;

        DateTime current = DateTime(
          t.fechaInicioTratamiento.year,
          t.fechaInicioTratamiento.month,
          t.fechaInicioTratamiento.day,
          t.horaPrimeraDosis.hour,
          t.horaPrimeraDosis.minute,
        );

        if (current.isAfter(endOfToday)) continue;

        // Fast-forward directo hasta el día de hoy para evitar iterar meses/años pasados
        if (current.isBefore(today)) {
          final diffMinutes = today.difference(current).inMinutes;
          final stepsToSkip = diffMinutes ~/ t.intervaloDosis.inMinutes;
          if (stepsToSkip > 1) {
            current = current.add(t.intervaloDosis * (stepsToSkip - 1));
          }
        }

        // Pre-parsear claves del día de hoy para soporte de tolerancia de 15 minutos
        final parsedEntries = <DateTime, DoseStatus>{};
        for (final entry in t.doseStatus.entries) {
          final dt = DateTime.tryParse(entry.key);
          if (dt != null &&
              dt.year == today.year &&
              dt.month == today.month &&
              dt.day == today.day) {
            parsedEntries[dt] = entry.value;
          }
        }

        while (!current.isAfter(endOfToday) &&
            !current.isAfter(finDelDiaTratamiento)) {
          final isToday =
              current.year == today.year &&
              current.month == today.month &&
              current.day == today.day;

          if (isToday) {
            totalHoy++;
            DoseStatus? status = t.doseStatus[current.toIso8601String()];
            if (status == null && parsedEntries.isNotEmpty) {
              for (final entry in parsedEntries.entries) {
                if (entry.key.difference(current).inMinutes.abs() <= 15) {
                  status = entry.value;
                  break;
                }
              }
            }
            final effectiveStatus = status ?? DoseStatus.pendiente;
            if (effectiveStatus == DoseStatus.tomada) {
              tomadasHoy++;
            } else if (effectiveStatus != DoseStatus.omitida) {
              // Dosis pendiente, notificada o aplazada
              if (proximaFechaDosis == null ||
                  current.isBefore(proximaFechaDosis)) {
                proximaFechaDosis = current;
                proximaTratamiento = t;
              }
            }
          }
          current = current.add(t.intervaloDosis);
        }
      }

      if (proximaTratamiento != null && proximaFechaDosis != null) {
        final formattedTime = AppUtils.formatDoseTime(proximaFechaDosis);
        final displayMedName = hideMedName
            ? 'Medicamento programado'
            : proximaTratamiento.nombreMedicamento;

        await HomeWidget.saveWidgetData<String>(
          'next_dose_med_name',
          displayMedName,
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
        await HomeWidget.saveWidgetData<String>('next_dose_time', '--:--');
        await HomeWidget.saveWidgetData<String>(
          'next_dose_detail',
          '¡Todas tus dosis de hoy están al día!',
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
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      if (uri != null &&
          (uri.host == 'midi_chat' || uri.path.contains('midi_chat'))) {
        if (context.mounted) {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const ChatBotScreen()));
        }
      }
    } catch (e) {
      debugPrint('Error procesando el inicio desde HomeWidget: $e');
    }
  }
}
