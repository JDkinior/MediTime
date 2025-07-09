// lib/services/tratamiento_service.dart
import 'package:meditime/models/tratamiento.dart';

class TratamientoService {

  /// Genera una lista de todas las dosis individuales para un tratamiento
  /// desde su inicio hasta su fin.
  List<DateTime> generarDosisTotales(Tratamiento tratamiento) {
    List<DateTime> dosis = [];
    DateTime dosisActual = tratamiento.fechaInicioTratamiento;
    final int intervalo = int.tryParse(tratamiento.intervaloDosis) ?? 24;

    while (dosisActual.isBefore(tratamiento.fechaFinTratamiento)) {
      dosis.add(dosisActual);
      dosisActual = dosisActual.add(Duration(hours: intervalo));
    }
    return dosis;
  }

  /// Genera solo las dosis futuras de un tratamiento que no han sido omitidas.
  /// Ideal para la pantalla principal de "Receta".
  List<DateTime> generarDosisPendientes(Tratamiento tratamiento) {
    final ahora = DateTime.now();
    final dosisTotales = generarDosisTotales(tratamiento);

    return dosisTotales.where((dosis) {
      final esFutura = dosis.isAfter(ahora.subtract(const Duration(minutes: 1)));
      final esOmitida = tratamiento.skippedDoses.any((omitida) => omitida.isAtSameMomentAs(dosis));
      return esFutura && !esOmitida;
    }).toList();
  }

  /// Calcula cuántas dosis de un tratamiento corresponden a un día específico.
  /// Útil para la vista de calendario.
  int getDosisCountForDay(Tratamiento tratamiento, DateTime dia) {
    final dosisTotales = generarDosisTotales(tratamiento);
    return dosisTotales.where((dosis) =>
        dosis.year == dia.year &&
        dosis.month == dia.month &&
        dosis.day == dia.day
    ).length;
  }
}