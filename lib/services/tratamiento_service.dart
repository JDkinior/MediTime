// lib/services/tratamiento_service.dart
import 'package:meditime/models/tratamiento.dart';

class TratamientoService {

  /// Genera una lista de todas las dosis individuales para un tratamiento
  /// desde su inicio hasta su fin.
  /// ADVERTENCIA: Puede ser muy ineficiente para tratamientos largos o crónicos.
  /// Úsalo con precaución o prefiere generarDosisEnRango.
  List<DateTime> generarDosisTotales(Tratamiento tratamiento) {
    List<DateTime> dosis = [];
    DateTime dosisActual = tratamiento.fechaInicioTratamiento;
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
  List<DateTime> generarDosisEnRango(Tratamiento tratamiento, DateTime inicio, DateTime fin) {
    List<DateTime> dosis = [];
    DateTime dosisActual = tratamiento.fechaInicioTratamiento;
    final int intervalo = tratamiento.intervaloDosis.inHours;

    if (intervalo <= 0) return dosis;

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
  List<DateTime> generarDosisPendientes(Tratamiento tratamiento, {int limit = 50}) {
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
  int getDosisCountForDay(Tratamiento tratamiento, DateTime dia) {
    final startOfDay = DateTime(dia.year, dia.month, dia.day);
    final endOfDay = DateTime(dia.year, dia.month, dia.day, 23, 59, 59);
    
    final dosisDelDia = generarDosisEnRango(tratamiento, startOfDay, endOfDay);
    return dosisDelDia.length;
  }
}