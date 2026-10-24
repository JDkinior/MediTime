// lib/services/widget_service.dart
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'package:meditime/services/tratamiento_service.dart';

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
      DartPluginRegistrant.ensureInitialized();
      WidgetsFlutterBinding.ensureInitialized();
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      await NotificationService.initializeCore();
      await NotificationService.stopAlarmSound();

      final prefs = PreferenceService();
      final userId = await prefs.getCurrentUserId();
      if (userId == null || userId.isEmpty) return;

      final doseTime = DateTime.parse(Uri.decodeComponent(doseTimeStr));

      if (Firebase.apps.isEmpty) {
        try {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          ).timeout(const Duration(seconds: 2));
        } catch (_) {}
      }

      final firestoreService = FirestoreService();
      final resolved = await firestoreService.resolveMedicamentoWithProfile(
        userId,
        docId,
      );
      final profile = resolved?.profile;

      if (uriStr.contains('take_dose')) {
        await NotificationService.cancelSnoozeForTreatment(
          docId: docId,
          doseTime: doseTime,
        );
        await firestoreService.updateDoseStatus(
          userId,
          docId,
          doseTime,
          DoseStatus.tomada,
          profile,
        );
        final docRef = resolved?.docRef ??
            firestoreService.getMedicamentoDocRef(userId, docId, profile);
        try {
          final snap = await docRef.get(const GetOptions(source: Source.cache));
          if (snap.exists) {
            final t = Tratamiento.fromFirestore(
              snap as DocumentSnapshot<Map<String, dynamic>>,
            );
            await NotificationService.rescheduleNextPendingDose(
              t,
              userId,
              profile,
            );
          }
        } catch (_) {}
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
          profile,
        );
        final snoozeMinutes = await prefs.getSnoozeDuration();
        final payload =
            'active_notification|$userId|$docId|${doseTime.toIso8601String()}|${profile?.id ?? ""}';
        await NotificationService.snoozeNotification(
          NotificationService.getNotificationIdForDose(docId, doseTime),
          payload,
          doseTime,
          snoozeMinutes,
        );
        await NotificationService.showSimpleNotification(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: 'Dosis aplazada',
          body: 'Se ha aplazado la dosis por $snoozeMinutes minutos.',
        );
      } else if (uriStr.contains('skip_dose')) {
        await NotificationService.cancelSnoozeForTreatment(
          docId: docId,
          doseTime: doseTime,
        );
        await firestoreService.updateDoseStatus(
          userId,
          docId,
          doseTime,
          DoseStatus.omitida,
          profile,
        );
        final docRef = resolved?.docRef ??
            firestoreService.getMedicamentoDocRef(userId, docId, profile);
        try {
          final snap = await docRef.get(const GetOptions(source: Source.cache));
          if (snap.exists) {
            final t = Tratamiento.fromFirestore(
              snap as DocumentSnapshot<Map<String, dynamic>>,
            );
            await NotificationService.rescheduleNextPendingDose(
              t,
              userId,
              profile,
            );
          }
        } catch (_) {}
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
        list = await firestoreService.getMedicamentos(activeUserId);
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final startOfToday = today;
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

        final int tolerance = t.doseMatchToleranceMinutes;
        final dosisHoy = TratamientoService.generarDosisEnRango(
          t,
          startOfToday,
          endOfToday,
        );

        for (final current in dosisHoy) {
          totalHoy++;
          DoseStatus status = DoseStatus.pendiente;
          DateTime effectiveTime = current;

          for (final entry in t.doseStatus.entries) {
            final dt = DateTime.tryParse(entry.key);
            if (dt != null && dt.difference(current).inMinutes.abs() <= tolerance) {
              status = entry.value;
              effectiveTime = dt;
              break;
            }
          }

          if (status == DoseStatus.tomada) {
            tomadasHoy++;
          } else if (status != DoseStatus.omitida) {
            if (proximaFechaDosis == null ||
                effectiveTime.isBefore(proximaFechaDosis)) {
              proximaFechaDosis = effectiveTime;
              proximaTratamiento = t;
            }
          }
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
