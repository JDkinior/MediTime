import 'dart:ui';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:meditime/models/caregiver_profile.dart';
import 'package:meditime/services/firestore_service.dart';
import 'package:meditime/services/notification_service.dart';
import 'package:meditime/services/preference_service.dart';
import 'package:meditime/services/tratamiento_service.dart';
import 'package:meditime/firebase_options.dart';

/// Punto de entrada para la ejecución de alarmas en segundo plano.
///
/// Esta función está marcada con `@pragma('vm:entry-point')`, lo que permite
/// que el sistema operativo Android la ejecute en un "Isolate" (hilo) separado,
/// incluso si la aplicación está completamente cerrada o el dispositivo no tiene internet.
///
/// [id] es el ID único de la alarma de `android_alarm_manager_plus`.
/// [params] es un mapa que contiene toda la información necesaria para procesar
/// la alarma, incluyendo los datos del tratamiento y del usuario. Esto es crucial
/// para permitir el funcionamiento 100% offline y mantener la rejilla de dosis exacta.
@pragma('vm:entry-point')
void alarmCallbackLogic(int id, Map<String, dynamic> params) async {
  debugPrint("🚨 INICIO alarmCallbackLogic (Offline-First / Zero-Drift) - ID: $id");
  debugPrint("Parámetros recibidos: ${params.keys.toList()}");

  try {
    // Asegura que los plugins estén registrados en el isolate de fondo (Android)
    DartPluginRegistrant.ensureInitialized();
    WidgetsFlutterBinding.ensureInitialized();

    // 1. Inicializar el servicio de notificaciones de inmediato
    await NotificationService.initializeCore();

    final preferenceService = PreferenceService();

    // 2. Extraer datos directamente del payload (100% offline)
    final userId = params['userId'] as String?;
    final docId = params['docId'] as String?;
    final doseTimeString = params['doseTime'] as String?;

    // Validaciones críticas
    if (userId == null || docId == null || doseTimeString == null) {
      debugPrint("ERROR: Parámetros críticos son null - userId: $userId, docId: $docId, doseTime: $doseTimeString");
      return;
    }

    final DateTime rawDoseTime = DateTime.parse(doseTimeString);
    final String? canonicalDoseTimeStr = params['canonicalDoseTime'] as String?;
    final DateTime rawCanonicalTime = canonicalDoseTimeStr != null
        ? (DateTime.tryParse(canonicalDoseTimeStr) ?? rawDoseTime)
        : rawDoseTime;
    final bool isSnooze = params['isSnooze'] as bool? ?? false;

    // Datos del tratamiento incluidos en el payload
    final nombreMedicamento = params['nombreMedicamento'] ?? 'Medicamento';
    final int rawInterval = (params['intervaloHoras'] as int?) ?? 8;
    final int intervaloHoras = rawInterval > 0 ? rawInterval : 8;
    final pacienteNombre = params['pacienteNombre'] as String?;
    final habitacion = params['habitacion'] as String?;
    final categoria = params['categoria'] as String?;
    final dosisPorToma = params['dosisPorToma'] ?? 1;
    final presentacion = params['presentacion'] as String? ?? 'dosis';
    final String? fechaFinStr = params['fechaFinTratamientoString'] as String?;
    final DateTime? fechaFinTratamiento =
        fechaFinStr != null ? DateTime.tryParse(fechaFinStr) : null;

    // 3. Leer modo de recordatorio (automático, activo o alarma)
    DoseReminderMode reminderMode = DoseReminderMode.automatic;
    try {
      reminderMode = await preferenceService.getReminderMode();
    } catch (e) {
      debugPrint("ERROR leyendo preferencias: $e. Usando modo automático como default");
      reminderMode = DoseReminderMode.automatic;
    }

    // 4. Validación de usuario y revocación local (sin requerir internet)
    try {
      final currentUserId = await preferenceService.getCurrentUserId();
      final isRevoked = await preferenceService.isTreatmentRevoked(userId, docId);
      final int seriesId = (params['prescriptionAlarmId'] as int?) ?? 0;

      if (currentUserId == null || currentUserId != userId || isRevoked) {
        debugPrint(
          "Guard: Bloqueando notificación. currentUserId=$currentUserId, payloadUserId=$userId, revoked=$isRevoked",
        );
        if (seriesId != 0) {
          await NotificationService.cancelTreatmentAlarms(seriesId, docId: docId);
          debugPrint("Guard: Serie de alarmas cancelada para ID: $seriesId");
        }
        return;
      }

      // 4.1 Validación de Modo Cuidador / Modo Animales
      final profileId = params['profileId'] as String?;
      if (profileId != null && profileId.isNotEmpty) {
        bool isAnimal = params['isAnimal'] as bool? ?? await preferenceService.isAnimalProfile(profileId);
        final isCaregiverModeActive = await preferenceService.getCaregiverModeActive();
        final isAnimalModeActive = await preferenceService.getAnimalModeActive();
        final notifyPatientDoses = await preferenceService.getCaregiverNotifyPatientDoses();

        bool shouldBlock = false;
        String reason = '';

        if (isAnimal) {
          if (!isAnimalModeActive) {
            shouldBlock = true;
            reason = 'Modo Animales desactivado';
          }
        } else {
          if (!isCaregiverModeActive) {
            shouldBlock = true;
            reason = 'Modo Cuidador desactivado';
          }
        }

        if (!shouldBlock && !notifyPatientDoses) {
          shouldBlock = true;
          reason = 'Notificaciones de pacientes/animales desactivadas';
        }

        if (!shouldBlock && !isAnimalModeActive && !isCaregiverModeActive) {
          shouldBlock = true;
          reason = 'Modo Cuidador y Modo Animales desactivados';
        }

        if (shouldBlock) {
          debugPrint("Guard: Bloqueando alarma de perfil ($profileId, isAnimal=$isAnimal): $reason");
          if (seriesId != 0) {
            await NotificationService.cancelTreatmentAlarms(seriesId, docId: docId);
            debugPrint("Guard: Serie de alarmas cancelada para ID: $seriesId ($reason)");
          }
          return;
        }
      }
    } catch (e) {
      debugPrint("ERROR en guard de usuario/revocado/modo: $e");
    }

    // 4.2 Manejo de teléfono apagado durante varios ciclos:
    // Si la alarma se dispara con horas de retraso (>= 1 intervalo completo) porque el
    // teléfono estuvo apagado, avanzamos sobre la rejilla canónica hasta la última toma vencida
    // del ciclo actual y verificamos que el tratamiento no haya finalizado hace días.
    final now = DateTime.now();
    DateTime effectiveCanonicalTime = DateTime(
      rawCanonicalTime.year,
      rawCanonicalTime.month,
      rawCanonicalTime.day,
      rawCanonicalTime.hour,
      rawCanonicalTime.minute,
    );
    DateTime effectiveDoseTime = rawDoseTime;

    if (!isSnooze &&
        now.difference(effectiveCanonicalTime).inMinutes >= intervaloHoras * 60) {
      while (effectiveCanonicalTime
              .add(Duration(hours: intervaloHoras))
              .isBefore(now) &&
          (fechaFinTratamiento == null ||
              !effectiveCanonicalTime
                  .add(Duration(hours: intervaloHoras))
                  .isAfter(fechaFinTratamiento))) {
        effectiveCanonicalTime = effectiveCanonicalTime.add(
          Duration(hours: intervaloHoras),
        );
      }
      effectiveDoseTime = effectiveCanonicalTime;

      // Si incluso la última dosis del tratamiento quedó atrás por más de un intervalo completo,
      // el tratamiento ya concluyó mientras el dispositivo estaba apagado.
      if (fechaFinTratamiento != null &&
          now.isAfter(fechaFinTratamiento) &&
          now.difference(effectiveCanonicalTime).inMinutes >= intervaloHoras * 60) {
        debugPrint("Tratamiento ya finalizado mientras el dispositivo estuvo apagado. No se dispara alarma obsoleta.");
        return;
      }
    }

    final Map<String, dynamic> effectiveParams = {
      ...params,
      'doseTime': effectiveDoseTime.toIso8601String(),
      'canonicalDoseTime': effectiveCanonicalTime.toIso8601String(),
    };

    // 4.3 Verificar en el registro local si esta dosis ya fue tomada u omitida por adelantado
    final int toleranceMinutes = ((intervaloHoras * 60) ~/ 2).clamp(15, 180);
    try {
      final localStatuses = await preferenceService.getLocalDoseStatuses(userId, docId);
      bool alreadyCompleted = false;
      for (final entry in localStatuses.entries) {
        final dt = DateTime.tryParse(entry.key);
        if (dt != null &&
            (dt.difference(effectiveDoseTime).inMinutes.abs() <= toleranceMinutes ||
                dt.difference(effectiveCanonicalTime).inMinutes.abs() <= toleranceMinutes) &&
            (entry.value == 'tomada' || entry.value == 'omitida')) {
          alreadyCompleted = true;
          break;
        }
      }

      if (alreadyCompleted) {
        debugPrint("Guard: La dosis de las $effectiveDoseTime ya fue registrada como tomada/omitida. Se omite notificación y se asegura la siguiente.");
        if (!isSnooze) {
          await _reprogramarSiguienteDosisOffline(effectiveParams, preferenceService);
        }
        return;
      }
    } catch (e) {
      debugPrint("Aviso verificando estado local previo en alarmCallbackLogic: $e");
    }

    final int notificationId = (params['currentNotificationId'] as int?) ??
        NotificationService.getNotificationIdForDose(docId, effectiveCanonicalTime);

    // Perfil de paciente/cuidador si aplica
    CaregiverProfile? dummyProfile;
    final profileId = params['profileId'] as String?;
    final bool isAnimalParam = params['isAnimal'] as bool? ?? false;
    if (profileId != null && profileId.isNotEmpty) {
      dummyProfile = CaregiverProfile(
        id: profileId,
        name: params['pacienteNombre'] as String? ?? '',
        relationship: 'dummy',
        colorHex: '#000000',
        isExternalUser: params['isExternalUser'] as bool? ?? false,
        linkedUid: params['linkedUid'] as String?,
        isAnimal: isAnimalParam,
      );
    }

    // Construcción de textos de notificación
    String notificationTitle = 'Hora de tomar: $nombreMedicamento';
    String notificationBody = 'Por favor, confirma si tomaste tu dosis.';

    if (pacienteNombre != null && pacienteNombre.isNotEmpty) {
      notificationTitle = 'Suministrar $nombreMedicamento a $pacienteNombre';

      String body = 'Es momento de darle $dosisPorToma $presentacion.';

      if (habitacion != null && habitacion.isNotEmpty) {
        if (categoria != null && categoria.isNotEmpty) {
          body += ' Se encuentra en la Hab. $habitacion ($categoria).';
        } else {
          body += ' Se encuentra en la Hab. $habitacion.';
        }
      } else if (categoria != null && categoria.isNotEmpty) {
        body += ' Ubicación: $categoria.';
      }

      notificationBody = body;
    }

    // 5. DISPARAR NOTIFICACIÓN Y ALARMA DE FORMA INMEDIATA (CRÍTICO: ANTES DE CUALQUIER RED)
    final cleanMedName = nombreMedicamento.replaceAll('|', '-');
    final cleanPres = presentacion.replaceAll('|', '-');
    final cleanPacName = (pacienteNombre ?? "").replaceAll('|', '-');
    final cleanHab = (habitacion ?? "").replaceAll('|', '-');

    if (reminderMode == DoseReminderMode.alarm) {
      debugPrint("🚨 Modo Alarma disparándose de inmediato para: $nombreMedicamento");

      final alarmPayload =
          'alarm_mode|$userId|$docId|${effectiveDoseTime.toIso8601String()}|$cleanMedName|$dosisPorToma|$cleanPres|$cleanPacName|$cleanHab|$notificationId|${profileId ?? ""}';

      await NotificationService.showAlarmModeNotification(
        id: notificationId,
        title: notificationTitle,
        body: notificationBody,
        payload: alarmPayload,
      );
    } else if (reminderMode == DoseReminderMode.active) {
      debugPrint("🔔 Modo Activo disparándose de inmediato para: $nombreMedicamento");

      await NotificationService.showActiveNotification(
        id: notificationId,
        title: notificationTitle,
        body: notificationBody,
        payload: 'active_notification|$userId|$docId|${effectiveDoseTime.toIso8601String()}|${profileId ?? ""}',
      );
    } else {
      debugPrint("✅ Modo Automático detectado para: $nombreMedicamento");

      await NotificationService.showSimpleNotification(
        id: notificationId,
        title: notificationTitle,
        body: pacienteNombre != null && pacienteNombre.isNotEmpty
            ? notificationBody
            : 'Dosis registrada automáticamente. Próxima dosis en $intervaloHoras horas.',
      );
    }

    final statusToUpdate = reminderMode == DoseReminderMode.automatic
        ? DoseStatus.tomada
        : DoseStatus.notificada;

    // 5.1 Guardar estado inmediatamente en almacenamiento local (<5ms, 100% offline)
    await preferenceService.saveLocalDoseStatus(
      userId: userId,
      docId: docId,
      doseTime: effectiveDoseTime,
      status: statusToUpdate.value,
      profileId: profileId,
      queueForSync: true,
      preventOverwriteCompleted: statusToUpdate == DoseStatus.notificada,
      toleranceMinutes: toleranceMinutes,
    );

    // 6. SINCRONIZACIÓN ASÍNCRONA CON FIREBASE (NO BLOQUEANTE, CON TIMEOUT CORTO)
    bool syncSuccess = false;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ).timeout(const Duration(seconds: 2));
      }

      final firestoreService = FirestoreService();

      await firestoreService
          .updateDoseStatus(
            userId,
            docId,
            effectiveDoseTime,
            statusToUpdate,
            dummyProfile,
          )
          .timeout(const Duration(seconds: 2));

      debugPrint("Estado sincronizado en Firestore: $statusToUpdate");

      if (!isSnooze) {
        await _reprogramarSiguienteDosis(
          effectiveParams,
          userId,
          firestoreService,
          dummyProfile,
          effectiveCanonicalTime,
          preferenceService,
        );
      }
      syncSuccess = true;
    } catch (syncError) {
      debugPrint("Sincronización en segundo plano omitida o en cola offline (sin conexión): $syncError");
    }

    // 7. SI NO HUBO SINCRONIZACIÓN EXITOSA CON FIREBASE, REPROGRAMAR OFFLINE INMEDIATAMENTE
    // Aplica a TODOS los modos para garantizar que el tratamiento nunca pierda continuidad ni exactitud.
    if (!syncSuccess && !isSnooze) {
      debugPrint("Reprogramando siguiente dosis en modo offline sobre la rejilla canónica...");
      await _reprogramarSiguienteDosisOffline(effectiveParams, preferenceService);
    }

    debugPrint("FIN alarmCallbackLogic - ID: $id - SUCCESS");
  } catch (e) {
    debugPrint("ERROR CRÍTICO en alarmCallbackLogic: $e");

    // FALLBACK DE EMERGENCIA: Mostrar notificación básica y asegurar siguiente alarma
    try {
      final notificationId = (params['currentNotificationId'] as int?) ?? Random().nextInt(100000);
      final nombreMedicamento = (params['nombreMedicamento'] as String?) ?? 'Medicamento';

      await NotificationService.showSimpleNotification(
        id: notificationId,
        title: 'Hora de tomar: $nombreMedicamento',
        body: 'Confirma tu dosis en la aplicación.',
      );
      await _reprogramarSiguienteDosisOffline(params, PreferenceService());
      debugPrint("Notificación de emergencia mostrada y siguiente alarma asegurada");
    } catch (emergencyError) {
      debugPrint("ERROR CRÍTICO mostrando notificación de emergencia: $emergencyError");
    }
  }
}

/// Reprograma la siguiente dosis utilizando datos de Firestore (o su caché local),
/// garantizando que el cálculo parta estrictamente después de la ranura canónica actual.
Future<void> _reprogramarSiguienteDosis(
  Map<String, dynamic> params,
  String userId,
  FirestoreService firestoreService,
  CaregiverProfile? dummyProfile,
  DateTime currentCanonicalTime,
  PreferenceService preferenceService,
) async {
  try {
    final docId = params['docId'] as String?;
    if (docId == null) {
      await _reprogramarSiguienteDosisOffline(params, preferenceService);
      return;
    }

    final docRef = firestoreService.getMedicamentoDocRef(userId, docId, dummyProfile);
    DocumentSnapshot doc;
    try {
      doc = await docRef.get().timeout(const Duration(seconds: 2));
    } catch (_) {
      doc = await docRef.get(const GetOptions(source: Source.cache));
    }

    if (doc.exists) {
      final tratamiento = Tratamiento.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
      final now = DateTime.now();
      // Garantizar que si Android disparó la alarma unos milisegundos antes de currentCanonicalTime,
      // la búsqueda de la siguiente dosis sea estrictamente posterior a currentCanonicalTime.
      final referenceTime = now.isAfter(currentCanonicalTime) ? now : currentCanonicalTime;
      await NotificationService.rescheduleNextPendingDose(
        tratamiento,
        userId,
        dummyProfile,
        referenceTime,
      );
      debugPrint("Siguiente dosis reprogramada con datos de Firestore/caché");
    } else {
      await _reprogramarSiguienteDosisOffline(params, preferenceService);
    }
  } catch (e) {
    debugPrint("ERROR reprogramando con Firebase: $e");
    await _reprogramarSiguienteDosisOffline(params, preferenceService);
  }
}

/// Reprograma la siguiente dosis utilizando únicamente los datos pasados en [params] y el registro local,
/// manteniendo las tomas futuras estrictamente ancladas a la rejilla canónica (`horaPrimeraDosis + k * intervalo`).
Future<void> _reprogramarSiguienteDosisOffline(
  Map<String, dynamic> params,
  PreferenceService preferenceService,
) async {
  try {
    final doseTimeString = params['doseTime'] as String?;
    if (doseTimeString == null) {
      debugPrint("ERROR: doseTime es null en _reprogramarSiguienteDosisOffline");
      return;
    }

    final doseTime = DateTime.parse(doseTimeString);
    final canonicalDoseTimeStr = params['canonicalDoseTime'] as String?;
    final canonicalDoseTime =
        canonicalDoseTimeStr != null ? DateTime.tryParse(canonicalDoseTimeStr) : null;
    final fechaInicioStr = params['fechaInicioTratamientoString'] as String?;
    final fechaInicio =
        fechaInicioStr != null ? DateTime.tryParse(fechaInicioStr) : null;
    final int? horaHour = params['horaPrimeraDosisHour'] as int?;
    final int? horaMinute = params['horaPrimeraDosisMinute'] as int?;
    final rawInterval = (params['intervaloHoras'] as int?) ?? 8;
    final intervaloHoras = rawInterval > 0 ? rawInterval : 8;
    final fechaFinTratamientoString = params['fechaFinTratamientoString'] as String?;
    final prescriptionAlarmId = (params['prescriptionAlarmId'] as int?) ?? 0;
    final userId = params['userId'] as String?;
    final docId = params['docId'] as String?;

    if (fechaFinTratamientoString == null || prescriptionAlarmId == 0) {
      debugPrint("Datos insuficientes para reprogramación offline - fechaFin: $fechaFinTratamientoString, alarmId: $prescriptionAlarmId");
      return;
    }

    final fechaFinTratamiento = DateTime.parse(fechaFinTratamientoString);

    Map<String, DoseStatus>? localStatuses;
    if (userId != null && docId != null) {
      final rawLocal = await preferenceService.getLocalDoseStatuses(userId, docId);
      if (rawLocal.isNotEmpty) {
        localStatuses = rawLocal.map(
          (k, v) => MapEntry(k, DoseStatus.fromString(v)),
        );
      }
    }

    final DateTime? siguienteDosis = TratamientoService.computeNextCanonicalDoseOffline(
      doseTime: doseTime,
      canonicalDoseTime: canonicalDoseTime,
      fechaInicioTratamiento: fechaInicio,
      horaPrimeraDosisHour: horaHour,
      horaPrimeraDosisMinute: horaMinute,
      intervaloHoras: intervaloHoras,
      fechaFinTratamiento: fechaFinTratamiento,
      referenceNow: DateTime.now(),
      localDoseStatuses: localStatuses,
    );

    if (siguienteDosis != null) {
      final nextNotifId = docId != null
          ? NotificationService.getNotificationIdForDose(docId, siguienteDosis)
          : Random().nextInt(100000);
      await NotificationService.scheduleOfflineAlarm(
        scheduleTime: siguienteDosis,
        alarmId: prescriptionAlarmId,
        params: {
          ...params,
          'doseTime': siguienteDosis.toIso8601String(),
          'canonicalDoseTime': siguienteDosis.toIso8601String(),
          'currentNotificationId': nextNotifId,
          'isSnooze': false,
        },
      );
      debugPrint("Siguiente dosis reprogramada offline en rejilla exacta para: $siguienteDosis");
    } else {
      debugPrint("Tratamiento completado, no se reprograma más de forma offline");
    }
  } catch (e) {
    debugPrint("ERROR en reprogramación offline: $e");
  }
}
