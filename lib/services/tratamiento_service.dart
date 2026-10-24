// lib/services/tratamiento_service.dart
import 'package:meditime/models/tratamiento.dart';

/// Resultado del cálculo de la próxima dosis a programar.
/// Separa la hora efectiva de disparo ([fireTime], que puede incluir un aplazamiento
/// puntual) de la hora canónica de la rejilla ([canonicalDoseTime], que mantiene
/// intacta la cadencia del tratamiento).
class ScheduledDoseTarget {
  final DateTime fireTime;
  final DateTime canonicalDoseTime;
  final bool isDeferredOrEdited;

  const ScheduledDoseTarget({
    required this.fireTime,
    required this.canonicalDoseTime,
    this.isDeferredOrEdited = false,
  });
}

class TratamientoService {

  /// Genera una lista de todas las dosis individuales para un tratamiento
  /// desde su inicio hasta su fin.
  /// ADVERTENCIA: Puede ser muy ineficiente para tratamientos largos o crónicos.
  /// Úsalo con precaución o prefiere generarDosisEnRango.
  static List<DateTime> generarDosisTotales(Tratamiento tratamiento) {
    List<DateTime> dosis = [];
    DateTime dosisActual = tratamiento.canonicalFirstDoseDateTime;
    final int intervalo = tratamiento.intervaloDosis.inHours;

    if (intervalo <= 0) return dosis;

    // Límite de seguridad para evitar bloqueos si la fecha de fin es muy lejana (ej. crónica)
    int count = 0;
    while (dosisActual.isBefore(tratamiento.fechaFinTratamiento) && count < 10000) {
      dosis.add(dosisActual);
      dosisActual = dosisActual.add(Duration(hours: intervalo));
      count++;
    }
    return dosis;
  }

  /// Genera solo las dosis dentro de un rango de fechas.
  /// Es mucho más eficiente que generarDosisTotales para períodos cortos.
  static List<DateTime> generarDosisEnRango(Tratamiento tratamiento, DateTime inicio, DateTime fin) {
    List<DateTime> dosis = [];
    final int intervalo = tratamiento.intervaloDosis.inHours;

    if (intervalo <= 0) return dosis;
    final DateTime anchor = tratamiento.canonicalFirstDoseDateTime;
    if (anchor.isAfter(fin)) return dosis;
    if (tratamiento.fechaFinTratamiento.isBefore(inicio)) return dosis;

    DateTime dosisActual = anchor;

    // Fast-forward si inicio es muy posterior al inicio del tratamiento
    if (dosisActual.isBefore(inicio)) {
      final hoursDiff = inicio.difference(dosisActual).inHours;
      final jumps = hoursDiff ~/ intervalo;
      if (jumps > 0) {
        dosisActual = dosisActual.add(Duration(hours: jumps * intervalo));
      }
      // Asegurarnos de no estar por debajo de inicio
      while (dosisActual.isBefore(inicio)) {
        dosisActual = dosisActual.add(Duration(hours: intervalo));
      }
    }

    final fechaLimite = tratamiento.fechaFinTratamiento.isBefore(fin)
        ? tratamiento.fechaFinTratamiento
        : fin;

    // Límite de seguridad para el while loop
    int count = 0;
    while (!dosisActual.isAfter(fechaLimite) && count < 10000) {
      if (!dosisActual.isBefore(inicio)) {
        dosis.add(dosisActual);
      }
      dosisActual = dosisActual.add(Duration(hours: intervalo));
      count++;
    }

    return dosis;
  }

  /// Genera solo las dosis futuras de un tratamiento que no han sido omitidas.
  /// Ideal para la pantalla principal de "Receta".
  static List<DateTime> generarDosisPendientes(Tratamiento tratamiento, {int limit = 50}) {
    final ahora = DateTime.now();
    // En lugar de generar todas las dosis, generamos un bloque razonable hacia el futuro.
    // Asumimos un máximo de 30 días para buscar dosis pendientes.
    final finEstimado = ahora.add(const Duration(days: 30));
    
    final dosisEnRango = generarDosisEnRango(
      tratamiento,
      ahora.subtract(const Duration(minutes: 1)),
      finEstimado
    );

    return dosisEnRango.where((dosis) {
      final esFutura = dosis.isAfter(ahora.subtract(const Duration(minutes: 1)));
      final esOmitida = tratamiento.skippedDoses.any((omitida) => omitida.isAtSameMomentAs(dosis));
      return esFutura && !esOmitida;
    }).take(limit).toList();
  }

  /// Calcula cuántas dosis de un tratamiento corresponden a un día específico.
  /// Útil para la vista de calendario.
  static int getDosisCountForDay(Tratamiento tratamiento, DateTime dia) {
    final startOfDay = DateTime(dia.year, dia.month, dia.day);
    final endOfDay = DateTime(dia.year, dia.month, dia.day, 23, 59, 59);
    
    final dosisDelDia = generarDosisEnRango(tratamiento, startOfDay, endOfDay);
    return dosisDelDia.length;
  }

  /// Ajusta cualquier [dateTime] a la ranura canónica más cercana de la rejilla
  /// definida por [anchor] e [intervaloHoras].
  static DateTime snapToCanonicalGrid({
    required DateTime dateTime,
    required DateTime anchor,
    required int intervaloHoras,
  }) {
    final safeHours = intervaloHoras > 0 ? intervaloHoras : 8;
    final intervalMinutes = safeHours * 60;
    final cleanAnchor = DateTime(
      anchor.year,
      anchor.month,
      anchor.day,
      anchor.hour,
      anchor.minute,
    );
    final cleanTarget = DateTime(
      dateTime.year,
      dateTime.month,
      dateTime.day,
      dateTime.hour,
      dateTime.minute,
    );
    final diffMinutes = cleanTarget.difference(cleanAnchor).inMinutes;
    final int k = (diffMinutes / intervalMinutes).round();
    return cleanAnchor.add(Duration(minutes: k * intervalMinutes));
  }

  /// Encuentra la próxima dosis pendiente para programar en [AndroidAlarmManager],
  /// manteniendo las tomas futuras estrictamente ancladas a la rejilla canónica
  /// (`canonicalFirstDoseDateTime + k * intervaloDosis`).
  static ScheduledDoseTarget? findNextScheduledDose({
    required Tratamiento tratamiento,
    DateTime? referenceTime,
    Map<String, DoseStatus>? localDoseStatuses,
  }) {
    final now = referenceTime ?? DateTime.now();
    final int safeHours = tratamiento.intervaloDosis.inHours > 0
        ? tratamiento.intervaloDosis.inHours
        : 8;
    final Duration interval = Duration(hours: safeHours);
    final int toleranceMinutes = tratamiento.doseMatchToleranceMinutes;
    final DateTime anchor = tratamiento.canonicalFirstDoseDateTime;

    if (now.isAfter(tratamiento.fechaFinTratamiento)) {
      return null;
    }

    // Fusionar estados de Firestore con estados locales offline (si existen)
    final Map<String, DoseStatus> mergedStatuses = Map<String, DoseStatus>.from(
      tratamiento.doseStatus,
    );
    if (localDoseStatuses != null && localDoseStatuses.isNotEmpty) {
      localDoseStatuses.forEach((key, localStatus) {
        final existing = mergedStatuses[key];
        // Los estados terminales (tomada/omitida) o aplazada tienen prioridad
        if (existing == null ||
            localStatus == DoseStatus.tomada ||
            localStatus == DoseStatus.omitida ||
            localStatus == DoseStatus.aplazada ||
            existing == DoseStatus.pendiente) {
          mergedStatuses[key] = localStatus;
        }
      });
    }

    // Pre-parsear entradas de estado para búsqueda eficiente
    final List<MapEntry<DateTime, DoseStatus>> parsedEntries = [];
    mergedStatuses.forEach((key, status) {
      final dt = DateTime.tryParse(key);
      if (dt != null) {
        parsedEntries.add(MapEntry(dt, status));
      }
    });
    parsedEntries.sort((a, b) => a.key.compareTo(b.key));

    // Fast-forward hasta la ventana relevante alrededor de 'now'
    DateTime currentCanonical = anchor;
    final DateTime searchFloor = now.subtract(Duration(minutes: toleranceMinutes));
    if (currentCanonical.isBefore(searchFloor)) {
      final hoursDiff = searchFloor.difference(currentCanonical).inHours;
      final jumps = hoursDiff ~/ safeHours;
      if (jumps > 0) {
        currentCanonical = currentCanonical.add(Duration(hours: jumps * safeHours));
      }
      while (currentCanonical.isBefore(searchFloor)) {
        currentCanonical = currentCanonical.add(interval);
      }
    }

    int safetyCount = 0;
    while (!currentCanonical.isAfter(tratamiento.fechaFinTratamiento) &&
        safetyCount < 10000) {
      safetyCount++;

      final bool isSkipped = tratamiento.skippedDoses.any(
        (d) => d.difference(currentCanonical).inMinutes.abs() <= toleranceMinutes,
      );

      if (!isSkipped) {
        // Buscar la entrada registrada más cercana dentro de la ventana de tolerancia de esta ranura
        MapEntry<DateTime, DoseStatus>? matchedEntry;
        int bestDiff = toleranceMinutes + 1;
        for (final entry in parsedEntries) {
          final diff = entry.key.difference(currentCanonical).inMinutes.abs();
          if (diff <= toleranceMinutes && diff < bestDiff) {
            bestDiff = diff;
            matchedEntry = entry;
          }
        }

        if (matchedEntry != null) {
          final status = matchedEntry.value;
          final recordedTime = matchedEntry.key;

          if (status == DoseStatus.tomada || status == DoseStatus.omitida) {
            // Esta ranura canónica ya fue completada (incluso si fue tomada por adelantado)
          } else if (status == DoseStatus.notificada) {
            // Si ya fue notificada en el pasado o justo ahora, pasamos a la siguiente ranura.
            // Solo si por alguna razón está muy en el futuro (> 1 min) se mantiene.
            if (recordedTime.isAfter(now.add(const Duration(minutes: 1)))) {
              return ScheduledDoseTarget(
                fireTime: recordedTime,
                canonicalDoseTime: currentCanonical,
                isDeferredOrEdited: !recordedTime.isAtSameMomentAs(currentCanonical),
              );
            }
          } else if (status == DoseStatus.aplazada || status == DoseStatus.pendiente) {
            if (recordedTime.isAfter(now)) {
              return ScheduledDoseTarget(
                fireTime: recordedTime,
                canonicalDoseTime: currentCanonical,
                isDeferredOrEdited: !recordedTime.isAtSameMomentAs(currentCanonical),
              );
            }
          }
        } else {
          // Sin estado registrado para esta ranura canónica
          if (currentCanonical.isAfter(now)) {
            return ScheduledDoseTarget(
              fireTime: currentCanonical,
              canonicalDoseTime: currentCanonical,
              isDeferredOrEdited: false,
            );
          }
        }
      }

      currentCanonical = currentCanonical.add(interval);
    }

    return null;
  }

  /// Calcula de forma 100% offline la siguiente dosis canónica a partir de los parámetros
  /// del payload de alarma, garantizando que nunca se arrastre el desfase de una alarma
  /// tardía, pospuesta o adelantada.
  static DateTime? computeNextCanonicalDoseOffline({
    required DateTime doseTime,
    DateTime? canonicalDoseTime,
    DateTime? fechaInicioTratamiento,
    int? horaPrimeraDosisHour,
    int? horaPrimeraDosisMinute,
    required int intervaloHoras,
    required DateTime fechaFinTratamiento,
    DateTime? referenceNow,
    Map<String, DoseStatus>? localDoseStatuses,
  }) {
    final int safeHours = intervaloHoras > 0 ? intervaloHoras : 8;
    final Duration interval = Duration(hours: safeHours);
    final DateTime now = referenceNow ?? DateTime.now();

    // 1. Determinar el ancla canónica exacta (segundos y milisegundos en 0)
    DateTime anchor;
    if (canonicalDoseTime != null) {
      anchor = DateTime(
        canonicalDoseTime.year,
        canonicalDoseTime.month,
        canonicalDoseTime.day,
        canonicalDoseTime.hour,
        canonicalDoseTime.minute,
      );
    } else if (horaPrimeraDosisHour != null && horaPrimeraDosisMinute != null) {
      final baseDate = fechaInicioTratamiento ?? doseTime;
      final dayAnchor = DateTime(
        baseDate.year,
        baseDate.month,
        baseDate.day,
        horaPrimeraDosisHour,
        horaPrimeraDosisMinute,
      );
      anchor = snapToCanonicalGrid(
        dateTime: doseTime,
        anchor: dayAnchor,
        intervaloHoras: safeHours,
      );
    } else if (fechaInicioTratamiento != null) {
      anchor = snapToCanonicalGrid(
        dateTime: doseTime,
        anchor: fechaInicioTratamiento,
        intervaloHoras: safeHours,
      );
    } else {
      anchor = DateTime(
        doseTime.year,
        doseTime.month,
        doseTime.day,
        doseTime.hour,
        doseTime.minute,
      );
    }

    // 2. La siguiente dosis debe ser estrictamente posterior tanto a la ranura actual
    // como al instante actual 'now' (por si la alarma se ejecutó unos segundos antes o muy tarde).
    final DateTime effectiveFloor = now.isAfter(anchor) ? now : anchor;
    DateTime nextDose = anchor.add(interval);

    if (nextDose.isBefore(effectiveFloor)) {
      final hoursDiff = effectiveFloor.difference(nextDose).inHours;
      final jumps = hoursDiff ~/ safeHours;
      if (jumps > 0) {
        nextDose = nextDose.add(Duration(hours: jumps * safeHours));
      }
    }

    final int toleranceMinutes = ((safeHours * 60) ~/ 2).clamp(15, 180);
    int safetyCount = 0;
    while (!nextDose.isAfter(fechaFinTratamiento) && safetyCount < 10000) {
      safetyCount++;
      if (nextDose.isAfter(effectiveFloor)) {
        // Verificar si ya fue tomada u omitida en el registro local offline
        bool alreadyDone = false;
        if (localDoseStatuses != null && localDoseStatuses.isNotEmpty) {
          for (final entry in localDoseStatuses.entries) {
            final dt = DateTime.tryParse(entry.key);
            if (dt != null &&
                dt.difference(nextDose).inMinutes.abs() <= toleranceMinutes &&
                (entry.value == DoseStatus.tomada ||
                    entry.value == DoseStatus.omitida)) {
              alreadyDone = true;
              break;
            }
          }
        }
        if (!alreadyDone) {
          return nextDose;
        }
      }
      nextDose = nextDose.add(interval);
    }

    return null;
  }
}
