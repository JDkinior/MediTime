import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:meditime/models/caregiver_profile.dart';
import 'package:meditime/models/tratamiento.dart';

/// Result of a function call that the chat screen should handle.
class ToolCallResult {
  const ToolCallResult({
    required this.functionName,
    required this.arguments,
    required this.result,
  });

  final String functionName;
  final Map<String, dynamic> arguments;
  final String result;
}

/// Animal taxonomic groups for veterinary safety and cross-species pharmacological safeguards.
enum AnimalTaxon {
  canine,
  feline,
  ruminant,
  equine,
  lagomorphRodent,
  reptileChelonian,
  avian,
  swine,
  other,
}

/// Service responsible for chat interactions using Groq API with function calling.
///
/// Note: The class name is kept for backward compatibility with the existing
/// Provider wiring in the app.
class GeminiService {
  GeminiService({String? apiKey})
      : _explicitApiKey = apiKey?.trim();

  /// Infers the animal taxonomic group based on profile attributes and context.
  static AnimalTaxon detectAnimalTaxon({
    String? species,
    String? relationship,
    String? breed,
    String? category,
    String? notes,
  }) {
    final text = '${species ?? ''} ${relationship ?? ''} ${breed ?? ''} ${category ?? ''} ${notes ?? ''}'
        .toLowerCase()
        .trim();
    if (text.isEmpty) return AnimalTaxon.other;

    // Ruminants / Bovine / Ovine / Caprine (Vacas, terneros, ovejas, cabras)
    if (text.contains('bovin') ||
        text.contains('vaca') ||
        text.contains('toro') ||
        text.contains('terner') ||
        text.contains('buey') ||
        text.contains('ovin') ||
        text.contains('oveja') ||
        text.contains('corder') ||
        text.contains('caprin') ||
        text.contains('cabra') ||
        text.contains('chivo') ||
        text.contains('rumiant') ||
        text.contains('holstein') ||
        text.contains('jersey') ||
        text.contains('angus') ||
        text.contains('brahman') ||
        text.contains('cebú') ||
        text.contains('cebu') ||
        text.contains('simmental') ||
        text.contains('charolais') ||
        text.contains('dorper') ||
        text.contains('saanen') ||
        text.contains('boer')) {
      return AnimalTaxon.ruminant;
    }

    // Equines (Caballos, yeguas, potros, burros, mulas)
    if (text.contains('equin') ||
        text.contains('caball') ||
        text.contains('yegua') ||
        text.contains('potr') ||
        text.contains('burr') ||
        text.contains('mula') ||
        text.contains('asno') ||
        text.contains('cuarto de milla') ||
        text.contains('pura sangre') ||
        text.contains('percherón') ||
        text.contains('percheron') ||
        text.contains('árabe') ||
        text.contains('arabe') ||
        text.contains('andaluz') ||
        text.contains('criollo')) {
      return AnimalTaxon.equine;
    }

    // Lagomorphs & Rodents (Conejos, cobayas/cuyes, chinchillas, hámsteres)
    if (text.contains('conej') ||
        text.contains('lagomorf') ||
        text.contains('cuy') ||
        text.contains('cobay') ||
        text.contains('chinchilla') ||
        text.contains('hamster') ||
        text.contains('hámster') ||
        text.contains('roedor') ||
        text.contains('jerbo') ||
        text.contains('belier')) {
      return AnimalTaxon.lagomorphRodent;
    }

    // Chelonians & Reptiles (Tortugas, galápagos, iguanas, serpientes)
    if (text.contains('tortug') ||
        text.contains('quelon') ||
        text.contains('reptil') ||
        text.contains('galapago') ||
        text.contains('galápago') ||
        text.contains('iguana') ||
        text.contains('serpiente') ||
        text.contains('camaleon') ||
        text.contains('camaleón') ||
        text.contains('gecko') ||
        text.contains('varano')) {
      return AnimalTaxon.reptileChelonian;
    }

    // Avians (Loros, periquitos, canarios, aves de corral)
    if (text.contains('ave') ||
        text.contains('pajar') ||
        text.contains('pájaro') ||
        text.contains('loro') ||
        text.contains('peric') ||
        text.contains('periquit') ||
        text.contains('canari') ||
        text.contains('gallin') ||
        text.contains('pollo') ||
        text.contains('gallo') ||
        text.contains('paloma') ||
        text.contains('cacatua') ||
        text.contains('cacatúa') ||
        text.contains('ninfa') ||
        text.contains('agapornis')) {
      return AnimalTaxon.avian;
    }

    // Swine (Cerdos, lechones, porcinos)
    if (text.contains('cerd') ||
        text.contains('porcin') ||
        text.contains('chanch') ||
        text.contains('puerc') ||
        text.contains('lechon') ||
        text.contains('lechón')) {
      return AnimalTaxon.swine;
    }

    // Felines (Gatos, felinos)
    if (text.contains('gat') ||
        text.contains('felin') ||
        text.contains('cat') ||
        text.contains('minino') ||
        text.contains('siames') ||
        text.contains('siamés') ||
        text.contains('persa') ||
        text.contains('bengala') ||
        text.contains('maine coon') ||
        text.contains('sphynx') ||
        text.contains('ragdoll')) {
      return AnimalTaxon.feline;
    }

    // Canines (Perros, caninos)
    if (text.contains('perr') ||
        text.contains('canin') ||
        text.contains('dog') ||
        text.contains('cachorr') ||
        text.contains('labrador') ||
        text.contains('golden') ||
        text.contains('pastor') ||
        text.contains('pitbull') ||
        text.contains('chihuahua') ||
        text.contains('poodle') ||
        text.contains('caniche') ||
        text.contains('husky') ||
        text.contains('bulldog') ||
        text.contains('beagle') ||
        text.contains('pug') ||
        text.contains('schnauzer') ||
        text.contains('rottweiler') ||
        text.contains('collie') ||
        text.contains('terrier')) {
      return AnimalTaxon.canine;
    }

    return AnimalTaxon.other;
  }

  /// Formulates targeted clinical directives for the detected animal taxon.
  static String getTaxonDirectives(AnimalTaxon taxon) {
    switch (taxon) {
      case AnimalTaxon.ruminant:
        return 'DIRECTIVA CLÍNICA ESPECÍFICA (RUMIANTE - Bovinos, Ovinos, Caprinos):\n'
            '• Adopta estrictamente el criterio zootécnico y veterinario de grandes animales.\n'
            '• NUNCA hables de "plato de comida", "tazón" ni "vómitos" (fisiología digestiva poligástrica ruminal).\n'
            '• VÍAS: Subcutánea (SC en tabla del cuello) o intramuscular (IM profunda). Suspensiones inyectables y antiparasitarios jamás por vía oral (destruyen la microflora ruminal).\n'
            '• TIEMPOS DE RETIRO: Advertir siempre de manera obligatoria el período de retiro en carne y leche para consumo humano.';
      case AnimalTaxon.equine:
        return 'DIRECTIVA CLÍNICA ESPECÍFICA (ÉQUIDO - Caballos, Yeguas, Burros, Mulas):\n'
            '• Herbívoro monogástrico cecocólico. Incapaz anatómicamente de vomitar (esfínter cardias no lo permite; cualquier vómito indica rotura gástrica o catástrofe).\n'
            '• CONTRAINDICACIÓN FATAL: Ionóforos (Monensina, Lasalocid) en alimentos son fulminantemente cardiotóxicos y letales en équidos.\n'
            '• VÍAS: Pasta oral bucal hacia la comisura lingual, IV yugular con estricta asepsia o IM en tabla del cuello/pectoral.';
      case AnimalTaxon.lagomorphRodent:
        return 'DIRECTIVA CLÍNICA ESPECÍFICA (LAGOMORFO / ROEDOR - Conejos, Cobayas, Chinchillas):\n'
            '• Fermentadores cecales monogástricos con cecotrofia. Incapaces de vomitar.\n'
            '• CONTRAINDICACIÓN FATAL 1: Fipronil (pipetas para perros/gatos) está PROHIBIDO Y ES MORTAL (causa convulsiones intratables y muerte fulminante).\n'
            '• CONTRAINDICACIÓN FATAL 2: Antibióticos orales contra bacterias Gram-positivas (penicilinas, amoxicilina, ampicilina, lincomicina, clindamicina) causan enterotoxemia mortal por Clostridium en 24-48 horas.\n'
            '• VÍAS: Jeringa dosificadora oral lateral tras los incisivos (papillas/suspensiones autorizadas) o SC.';
      case AnimalTaxon.reptileChelonian:
        return 'DIRECTIVA CLÍNICA ESPECÍFICA (QUELONIO / REPTIL - Tortugas, Galápagos, Lagartos, Serpientes):\n'
            '• Ectotermos (poiquilotermos, metabolismo dependiente de temperatura ambiental POTZ) con sistema porta-renal.\n'
            '• CONTRAINDICACIÓN FATAL: Ivermectina en quelonios (tortugas) es MORTAL (atraviesa la barrera hematoencefálica causando parálisis flácida completa y asfixia).\n'
            '• VÍAS: Inyecciones SC/IM SIEMPRE en el tercio craneal o extremidades anteriores para evitar que el sistema porta-renal excrete prematuramente el fármaco o cause toxicidad renal.';
      case AnimalTaxon.avian:
        return 'DIRECTIVA CLÍNICA ESPECÍFICA (AVE - Loros, Pericos, Canarios, Aves de corral):\n'
            '• Tasa metabólica muy alta. Sacos aéreos hipersensibles: humos de teflón caliente (PTFE), ambientadores y aerosoles provocan edema hemorrágico y muerte en minutos.\n'
            '• VÍAS: Inyecciones IM EXCLUSIVAMENTE en la musculatura pectoral (nunca en patas o muslos debido al sistema porta-renal aviar).';
      case AnimalTaxon.feline:
        return 'DIRECTIVA CLÍNICA ESPECÍFICA (FELINO - Gatos):\n'
            '• Carnívoro estricto con déficit congénito de la enzima hepática glucuroniltransferasa.\n'
            '• CONTRAINDICACIÓN FATAL 1: Paracetamol (Acetaminofén) es MORTAL en miligramos (causa metahemoglobinemia fulminante, sangre achocolatada y asfixia celular).\n'
            '• CONTRAINDICACIÓN FATAL 2: Permetrinas y piretroides concentrados (pipetas caninas) causan neurotoxicidad severa con convulsiones y muerte.\n'
            '• AINEs humanos (ibuprofeno, aspirina en dosis de perro) son nefrotóxicos y letales.';
      case AnimalTaxon.canine:
        return 'DIRECTIVA CLÍNICA ESPECÍFICA (CANINO - Perros):\n'
            '• Carnívoro/omnívoro monogástrico con reflejo del vómito.\n'
            '• TOXICIDADES CRÍTICAS: AINEs humanos (ibuprofeno, diclofenaco, naproxeno) causan úlceras gástricas perforantes y fallo renal agudo. Xilitol causa hipoglucemia severa y necrosis hepática letal.\n'
            '• SENSIBILIDAD GENÉTICA MDR1/ABCB1: En razas pastoras (Collies, Pastores Australianos, etc.), ivermectina y loperamida atraviesan la barrera hematoencefálica causando neurotoxicidad letal.';
      case AnimalTaxon.swine:
        return 'DIRECTIVA CLÍNICA ESPECÍFICA (PORCINO - Cerdos, Lechones):\n'
            '• Monogástrico omnívoro. Inyecciones IM profundas en el cuello tras la oreja. Control estricto y advertencia de tiempos de retiro para faena.';
      case AnimalTaxon.other:
        return 'DIRECTIVA CLÍNICA ESPECÍFICA (ANIMAL / ESPECIE EXÓTICA):\n'
            '• Verifica siempre la especie, peso y estado fisiológico exactos antes de brindar cualquier indicación farmacológica.\n'
            '• Nunca asumas que un medicamento o dosis segura para caninos/felinos se puede extrapolar a otras especies.';
    }
  }

  final String? _explicitApiKey;

  Future<String> getEffectiveApiKey() async {
    if (_explicitApiKey != null && _explicitApiKey.isNotEmpty) {
      return _explicitApiKey;
    }
    return const String.fromEnvironment('GROQ_API_KEY').trim();
  }

  // Production chat models supported across Groq accounts on LPU platform.
  static const String _model = 'openai/gpt-oss-20b';
  // Fast, universally active fallback model on Groq to prevent 404 model_not_found
  static const String _fallbackModel = 'openai/gpt-oss-120b';
  // Vision model supported by Groq
  static const String _visionModel = 'qwen/qwen3.8-27b';
  static const String _baseUrl =
      'https://api.groq.com/openai/v1/chat/completions';
  static const int _maxHistoryMessages = 4;
  static const int _maxCompletionTokens = 1200;
  final List<Map<String, dynamic>> _history = <Map<String, dynamic>>[];
  String? _lastModeSignature;

  static bool _isAnticoagulant(String name) {
    final lower = name.toLowerCase();
    return lower.contains('warfar') ||
        lower.contains('acenocumar') ||
        lower.contains('sintrom') ||
        lower.contains('coumadin') ||
        lower.contains('rivaroxab') ||
        lower.contains('apixab') ||
        lower.contains('dabigatran') ||
        lower.contains('edoxaban');
  }

  static bool _isAntibiotic(String name) {
    final lower = name.toLowerCase();
    return lower.contains('cefalex') ||
        lower.contains('cefalot') ||
        lower.contains('cefurox') ||
        lower.contains('cefdinir') ||
        lower.contains('cefadrox') ||
        lower.contains('ceftriax') ||
        lower.contains('amoxicil') ||
        lower.contains('ampicil') ||
        lower.contains('ciproflox') ||
        lower.contains('cipro') ||
        lower.contains('levoflox') ||
        lower.contains('azitromic') ||
        lower.contains('claritromic') ||
        lower.contains('eritromic') ||
        lower.contains('trimetoprim') ||
        lower.contains('bactrim') ||
        lower.contains('cotrimox') ||
        lower.contains('doxiciclin') ||
        lower.contains('metronidazol') ||
        lower.contains('clindamic');
  }

  static bool _isNsaid(String name) {
    final lower = name.toLowerCase();
    return lower.contains('ibuprofen') ||
        lower.contains('naproxen') ||
        lower.contains('diclofenac') ||
        lower.contains('ketorolac') ||
        lower.contains('meloxicam') ||
        lower.contains('celecoxib') ||
        lower.contains('piroxicam') ||
        lower.contains('indometacin') ||
        lower.contains('aspirin') ||
        lower.contains('ácido acetilsalicílico') ||
        lower.contains('acido acetilsalicilico');
  }

  /// Detects clinically critical pairwise interactions among concurrent active treatments
  /// belonging to the same patient or profile.
  static List<String> detectCriticalConcurrentInteractions({
    required List<Tratamiento> treatments,
    bool isAnimalMode = false,
  }) {
    if (treatments.length < 2 || isAnimalMode) return const [];

    final interactions = <String>[];
    final seenPairs = <String>{};

    for (int i = 0; i < treatments.length; i++) {
      for (int j = i + 1; j < treatments.length; j++) {
        final t1 = treatments[i];
        final t2 = treatments[j];

        // In caregiver or multi-profile mode, only correlate treatments of the same profile
        if (t1.profileId != null && t2.profileId != null && t1.profileId != t2.profileId) {
          continue;
        }

        final n1 = t1.nombreMedicamento.trim();
        final n2 = t2.nombreMedicamento.trim();

        final isAnticoag1 = _isAnticoagulant(n1);
        final isAnticoag2 = _isAnticoagulant(n2);
        final isAb1 = _isAntibiotic(n1);
        final isAb2 = _isAntibiotic(n2);
        final isNsaid1 = _isNsaid(n1);
        final isNsaid2 = _isNsaid(n2);

        // 1. Anticoagulante (Warfarina/Acenocumarol/etc) + Antibiótico (Cefalexina/Amoxicilina/etc)
        if ((isAnticoag1 && isAb2) || (isAnticoag2 && isAb1)) {
          final sorted = [n1.toLowerCase(), n2.toLowerCase()]..sort();
          final pairKey = 'anticoag_ab_${sorted.join("_")}';
          if (!seenPairs.contains(pairKey)) {
            seenPairs.add(pairKey);
            final anti = isAnticoag1 ? n1 : n2;
            final ab = isAb1 ? n1 : n2;
            interactions.add(
              'Interacción crítica entre $anti y $ab: Los antibióticos pueden alterar la flora bacteriana intestinal (reduciendo la síntesis de vitamina K) y potenciar el efecto anticoagulante de $anti, disparando peligrosamente el INR con alto riesgo de hemorragia. Conducta médica requerida: Es indispensable que el médico tratante programe control cercano de INR y evalúe un ajuste temporal en la dosis de $anti.',
            );
          }
        }

        // 2. Anticoagulante + AINE
        if ((isAnticoag1 && isNsaid2) || (isAnticoag2 && isNsaid1)) {
          final sorted = [n1.toLowerCase(), n2.toLowerCase()]..sort();
          final pairKey = 'anticoag_nsaid_${sorted.join("_")}';
          if (!seenPairs.contains(pairKey)) {
            seenPairs.add(pairKey);
            final anti = isAnticoag1 ? n1 : n2;
            final nsaid = isNsaid1 ? n1 : n2;
            interactions.add(
              'Interacción de alto riesgo entre $anti y $nsaid: La combinación de anticoagulantes con AINEs multiplica el riesgo de sangrado gastrointestinal severo y daño de mucosa gástrica. Se debe consultar al médico tratante antes de coadministrarlos.',
            );
          }
        }
      }
    }

    return interactions;
  }

  /// Generates the schedule of doses for a specific day based on start time, first dose hour, and interval.
  static List<DateTime> calculateDosesForDate(Tratamiento t, DateTime date) {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    if (t.fechaInicioTratamiento.isAfter(dayEnd)) return const [];
    final isIndefinite = t.duracion.toLowerCase().contains('indefinid') || t.duracion == '0';
    if (!isIndefinite && t.fechaFinTratamiento.isBefore(dayStart)) return const [];

    final interval = t.intervaloDosis.inMinutes > 0 ? t.intervaloDosis : const Duration(hours: 8);

    DateTime currentDose = DateTime(
      t.fechaInicioTratamiento.year,
      t.fechaInicioTratamiento.month,
      t.fechaInicioTratamiento.day,
      t.horaPrimeraDosis.hour,
      t.horaPrimeraDosis.minute,
    );

    if (currentDose.isBefore(dayStart)) {
      final diffMinutes = dayStart.difference(currentDose).inMinutes;
      final jumps = diffMinutes ~/ interval.inMinutes;
      if (jumps > 0) {
        currentDose = currentDose.add(interval * jumps);
      }
      while (currentDose.isBefore(dayStart)) {
        currentDose = currentDose.add(interval);
      }
    }

    final result = <DateTime>[];
    int count = 0;
    while (currentDose.isBefore(dayEnd) && count < 100) {
      if (!isIndefinite && currentDose.isAfter(t.fechaFinTratamiento)) break;
      result.add(currentDose);
      currentDose = currentDose.add(interval);
      count++;
    }

    return result;
  }

  /// Generates the schedule of doses within a date range [start, end].
  static List<DateTime> calculateDosesInRange(Tratamiento t, DateTime start, DateTime end) {
    if (t.fechaInicioTratamiento.isAfter(end)) return const [];
    final isIndefinite = t.duracion.toLowerCase().contains('indefinid') || t.duracion == '0';
    if (!isIndefinite && t.fechaFinTratamiento.isBefore(start)) return const [];

    final interval = t.intervaloDosis.inMinutes > 0 ? t.intervaloDosis : const Duration(hours: 8);

    DateTime currentDose = DateTime(
      t.fechaInicioTratamiento.year,
      t.fechaInicioTratamiento.month,
      t.fechaInicioTratamiento.day,
      t.horaPrimeraDosis.hour,
      t.horaPrimeraDosis.minute,
    );

    if (currentDose.isBefore(start)) {
      final diffMinutes = start.difference(currentDose).inMinutes;
      final jumps = diffMinutes ~/ interval.inMinutes;
      if (jumps > 0) {
        currentDose = currentDose.add(interval * jumps);
      }
      while (currentDose.isBefore(start)) {
        currentDose = currentDose.add(interval);
      }
    }

    final result = <DateTime>[];
    int count = 0;
    final limit = (!isIndefinite && t.fechaFinTratamiento.isBefore(end)) ? t.fechaFinTratamiento : end;
    while (!currentDose.isAfter(limit) && count < 1000) {
      if (!currentDose.isBefore(start)) {
        result.add(currentDose);
      }
      currentDose = currentDose.add(interval);
      count++;
    }

    return result;
  }

  /// Generates the complete, accurate schedule of doses for [treatment] on [date].
  /// Matches the exact logic of RecetaPage:
  /// 1. Prioritizes explicit doses recorded in [doseStatus] for this day (with their real status: tomada, omitida, etc.).
  /// 2. For remaining scheduled slots, calculates planned future/pending doses.
  static List<Map<String, dynamic>> calculateDayDoses(
    Tratamiento t,
    DateTime date, {
    DateTime? now,
  }) {
    final effectiveNow = now ?? DateTime.now();
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

    final List<Map<String, dynamic>> result = [];
    final List<DateTime> recordedTimes = [];

    // 1. Recopilar todas las dosis explícitamente registradas en doseStatus para este día
    t.doseStatus.forEach((key, status) {
      final parsedTime = DateTime.tryParse(key);
      if (parsedTime != null &&
          !parsedTime.isBefore(startOfDay) &&
          !parsedTime.isAfter(endOfDay)) {
        recordedTimes.add(parsedTime);
        result.add({
          'time': parsedTime,
          'status': status,
          'isRecorded': true,
        });
      }
    });

    recordedTimes.sort();

    // 2. Generar dosis calculadas del día y agregar aquellas que no tienen registro asociado
    final isIndefinite = t.duracion.toLowerCase().contains('indefinid') || t.duracion == '0';
    if (!t.fechaInicioTratamiento.isAfter(endOfDay) &&
        (isIndefinite || !t.fechaFinTratamiento.isBefore(startOfDay))) {
      final intervalMin = t.intervaloDosis.inMinutes > 0 ? t.intervaloDosis.inMinutes : 240;
      final maxTolerance = (intervalMin / 2).clamp(30.0, 180.0);

      // Si el tratamiento se toma 1 vez al día (cada 24 horas) y ya tiene una dosis registrada hoy,
      // no agregamos dosis sintéticas adicionales.
      final bool alreadyHasDailyDose = intervalMin >= 1200 && recordedTimes.isNotEmpty;

      if (!alreadyHasDailyDose) {
        final dosisCalculadas = calculateDosesForDate(t, date);
        for (final doseTime in dosisCalculadas) {
          bool isRecorded = false;
          for (final rec in recordedTimes) {
            if (rec.difference(doseTime).inMinutes.abs() <= maxTolerance) {
              isRecorded = true;
              break;
            }
          }

          if (!isRecorded) {
            final isPast = doseTime.isBefore(effectiveNow);
            result.add({
              'time': doseTime,
              'status': isPast ? DoseStatus.pendiente : DoseStatus.pendiente,
              'isRecorded': false,
              'isProgramada': !isPast,
            });
          }
        }
      }
    }

    result.sort((a, b) => (a['time'] as DateTime).compareTo(b['time'] as DateTime));
    return result;
  }

  /// Calculates dynamic adherence summary across active treatments.
  /// Supports:
  /// - specific day ("dia" / daysCount: 1)
  /// - week ("semana" / daysCount: 7)
  /// - month ("mes" / daysCount: 30)
  /// - year ("anio" / daysCount: 365)
  /// - custom date range ([customStart], [customEnd]) or custom days ([daysCount]).
  static Map<String, dynamic> calculateAdherenceSummary(
    List<Tratamiento> treatments, {
    DateTime? now,
    DateTime? customStart,
    DateTime? customEnd,
    String? periodoType,
    int? daysCount,
  }) {
    final effectiveNow = now ?? DateTime.now();
    DateTime startDate;
    DateTime endDate = customEnd != null
        ? DateTime(customEnd.year, customEnd.month, customEnd.day, 23, 59, 59, 999)
        : DateTime(effectiveNow.year, effectiveNow.month, effectiveNow.day, 23, 59, 59, 999);

    final pType = periodoType?.toLowerCase().trim();
    String periodo;
    const months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

    if (customStart != null) {
      startDate = DateTime(customStart.year, customStart.month, customStart.day);
      periodo = '${startDate.day} ${months[startDate.month - 1]} - ${endDate.day} ${months[endDate.month - 1]} ${endDate.year}';
    } else if (pType == 'dia' || daysCount == 1) {
      startDate = DateTime(effectiveNow.year, effectiveNow.month, effectiveNow.day);
      endDate = DateTime(effectiveNow.year, effectiveNow.month, effectiveNow.day, 23, 59, 59, 999);
      periodo = '${effectiveNow.day} ${months[effectiveNow.month - 1]} ${effectiveNow.year} (Hoy)';
    } else if (pType == 'mes' || daysCount == 30) {
      startDate = DateTime(effectiveNow.year, effectiveNow.month, 1);
      periodo = '${startDate.day} ${months[startDate.month - 1]} - ${effectiveNow.day} ${months[effectiveNow.month - 1]} ${effectiveNow.year} (Mes en curso)';
    } else if (pType == 'anio' || daysCount == 365) {
      startDate = DateTime(effectiveNow.year, 1, 1);
      periodo = '${effectiveNow.year} (Año en curso)';
    } else if (daysCount != null && daysCount > 0) {
      startDate = effectiveNow.subtract(Duration(days: daysCount - 1));
      startDate = DateTime(startDate.year, startDate.month, startDate.day);
      periodo = '${startDate.day} ${months[startDate.month - 1]} - ${effectiveNow.day} ${months[effectiveNow.month - 1]} ${effectiveNow.year} (Últimos $daysCount días)';
    } else {
      startDate = effectiveNow.subtract(const Duration(days: 6));
      startDate = DateTime(startDate.year, startDate.month, startDate.day);
      periodo = '${startDate.day} ${months[startDate.month - 1]} - ${effectiveNow.day} ${months[effectiveNow.month - 1]} ${effectiveNow.year}';
    }

    int totalTomadas = 0;
    int totalOmitidas = 0;
    int totalProgramadas = 0;
    final breakdownList = <String>[];

    for (final t in treatments) {
      int tTomadas = 0;
      int tOmitidas = 0;
      final recordedTimes = <DateTime>[];

      t.doseStatus.forEach((key, status) {
        final parsed = DateTime.tryParse(key);
        if (parsed != null && !parsed.isBefore(startDate) && !parsed.isAfter(endDate)) {
          recordedTimes.add(parsed);
          if (status == DoseStatus.tomada) {
            tTomadas++;
          } else if (status == DoseStatus.omitida || status == DoseStatus.pendiente) {
            tOmitidas++;
          }
        }
      });

      final todasLasDosis = calculateDosesInRange(t, startDate, endDate);
      final intervalMin = t.intervaloDosis.inMinutes > 0 ? t.intervaloDosis.inMinutes : 240;
      final tolerance = (intervalMin / 2).clamp(30.0, 180.0);

      for (final dose in todasLasDosis) {
        if (!dose.isBefore(startDate) && dose.isBefore(effectiveNow)) {
          bool recorded = false;
          for (final rec in recordedTimes) {
            if (rec.difference(dose).inMinutes.abs() <= tolerance) {
              recorded = true;
              break;
            }
          }
          if (!recorded) {
            tOmitidas++;
          }
        }
      }

      final tProgramadas = tTomadas + tOmitidas;
      final tAdh = tProgramadas > 0 ? (tTomadas / tProgramadas * 100).toInt() : 100;
      breakdownList.add('${t.nombreMedicamento}: $tAdh% ($tTomadas tomadas, $tOmitidas omitidas/pendientes)');

      totalTomadas += tTomadas;
      totalOmitidas += tOmitidas;
      totalProgramadas += tProgramadas;
    }

    final overall = totalProgramadas > 0 ? (totalTomadas / totalProgramadas * 100).toInt() : 100;

    return {
      'adherence': overall,
      'tomadas': totalTomadas,
      'omitidas': totalOmitidas,
      'programadas': totalProgramadas,
      'periodo': periodo,
      'breakdown': breakdownList.join('; '),
    };
  }

  /// Returns a unique signature for the active chat mode and profile.
  static String computeModeSignature({
    bool isAnimalMode = false,
    bool isCaregiverMode = false,
    CaregiverModeType? caregiverModeType,
    CaregiverProfile? activeProfile,
  }) {
    if (isAnimalMode) {
      return 'animal_${activeProfile?.id ?? "general"}';
    } else if (isCaregiverMode) {
      final type = caregiverModeType?.name ?? 'familiar';
      return 'caregiver_${type}_${activeProfile?.id ?? "general"}';
    } else {
      return 'personal';
    }
  }

  /// Builds a mode-aware, token-optimized system instruction.
  static String buildSystemPrompt({
    bool isAnimalMode = false,
    bool isCaregiverMode = false,
    CaregiverModeType? caregiverModeType,
    CaregiverProfile? activeProfile,
    List<CaregiverProfile>? allProfiles,
    String? userName,
    String language = 'es',
    List<Tratamiento>? activeTreatments,
    DateTime? now,
  }) {
    final effectiveNow = now ?? DateTime.now();
    final todayStr = '${effectiveNow.year}-${effectiveNow.month.toString().padLeft(2, '0')}-${effectiveNow.day.toString().padLeft(2, '0')}';
    final userLabel = userName?.trim().isNotEmpty == true ? userName!.trim() : 'Usuario';

    // Helper para formatear fechas de forma legible
    String formatFriendlyDate(DateTime dt) {
      const months = [
        'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
        'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
      ];
      return '${dt.day} de ${months[dt.month - 1]} de ${dt.year}';
    }

    final buffer = StringBuffer();

    // 1. Role & Mode Persona
    if (isAnimalMode) {
      if (activeProfile != null) {
        // Vista de Mascota Individual
        final petName = activeProfile.name.trim();
        final species = activeProfile.species?.trim().isNotEmpty == true ? activeProfile.species!.trim() : 'Mascota';
        final breed = activeProfile.breed?.trim().isNotEmpty == true ? ', raza ${activeProfile.breed!.trim()}' : '';
        final weight = activeProfile.weight?.trim().isNotEmpty == true ? ', peso ${activeProfile.weight!.trim()}' : '';

        buffer.writeln('Eres Midi, el asistente veterinario especializado de MediTime.');
        buffer.writeln('MODO ACTIVO: 🐾 MODO ANIMALES (VETERINARIO) - VISTA DE MASCOTA INDIVIDUAL.');
        buffer.writeln('Tutor: $userLabel | Mascota seleccionada: $petName ($species$breed$weight).');
        if (activeProfile.allergies?.trim().isNotEmpty == true) {
          buffer.writeln('Alergias conocidas: ${activeProfile.allergies!.trim()}.');
        }
        if (activeProfile.notes?.trim().isNotEmpty == true) {
          buffer.writeln('Notas clínicas veterinarias: ${activeProfile.notes!.trim()}.');
        }
        buffer.writeln('ENFOQUE: Todas las consultas de medicamentos, horarios y fin de tratamientos corresponden exclusivamente a **$petName**.');

        final taxon = detectAnimalTaxon(
          species: activeProfile.species,
          relationship: activeProfile.relationship,
          breed: activeProfile.breed,
          category: activeProfile.category,
          notes: activeProfile.notes,
        );
        buffer.writeln();
        buffer.writeln(getTaxonDirectives(taxon));
      } else {
        // Vista General de Animales / Varias Mascotas
        final petProfiles = (allProfiles ?? []).where((p) => p.isAnimal).toList();
        buffer.writeln('Eres Midi, el asistente veterinario especializado de MediTime.');
        buffer.writeln('MODO ACTIVO: 🐾 MODO ANIMALES (VETERINARIO) - VISTA GENERAL DE MASCOTAS.');
        buffer.writeln('Tutor: $userLabel.');
        buffer.writeln('Estás en la VISTA GENERAL. El tutor tiene ${petProfiles.length} mascota(s) registrada(s):');
        final detectedTaxa = <AnimalTaxon>{};
        for (final pet in petProfiles) {
          final sp = pet.species?.trim().isNotEmpty == true ? pet.species!.trim() : 'Mascota';
          final br = pet.breed?.trim().isNotEmpty == true ? ', raza ${pet.breed!.trim()}' : '';
          final wt = pet.weight?.trim().isNotEmpty == true ? ', peso ${pet.weight!.trim()}' : '';
          final al = pet.allergies?.trim().isNotEmpty == true ? ', Alergias: ${pet.allergies!.trim()}' : '';
          buffer.writeln('- Mascota: **${pet.name}** ($sp$br$wt$al)');
          detectedTaxa.add(detectAnimalTaxon(
            species: pet.species,
            relationship: pet.relationship,
            breed: pet.breed,
            category: pet.category,
            notes: pet.notes,
          ));
        }
        buffer.writeln();
        buffer.writeln('REGLAS DE VISTA GENERAL DE MASCOTAS:');
        buffer.writeln('1. NUNCA asumas que hay una sola mascota ni una sola especie. Supervisas múltiples animales con necesidades y fisiologías radicalmente distintas.');
        buffer.writeln('2. Al responder sobre tratamientos, dosis o cuándo termina un tratamiento, ACLARA SIEMPRE A QUÉ MASCOTA CORRESPONDE cada información para evitar confusiones o intoxicaciones entre especies.');
        buffer.writeln('3. Ten sumo cuidado: medicamentos seguros para perros pueden ser mortales para gatos y viceversa (ej: permetrina o paracetamol en gatos, fipronil en conejos, ivermectina en quelonios o perros con gen MDR1).');
        buffer.writeln('4. Si el usuario pregunta por una mascota en particular, responde enfocándote solo en ella adoptando su criterio clínico particular.');
        if (detectedTaxa.isNotEmpty) {
          buffer.writeln();
          buffer.writeln('DIRECTIVAS DE LAS ESPECIES REGISTRADAS EN ESTE PERFIL:');
          for (final t in detectedTaxa) {
            buffer.writeln(getTaxonDirectives(t));
          }
        }
      }

      buffer.writeln();
      buffer.writeln('REGLAS VETERINARIAS Y DE SEGURIDAD FARMACOLÓGICA OBLIGATORIAS:');
      buffer.writeln('1. NUNCA INVENTES VÍAS DE ADMINISTRACIÓN:');
      buffer.writeln('   • Si un fármaco es inyectable (SC, IM, IV), NUNCA digas que se puede tomar por vía oral, ni mezclar con agua o comida.');
      buffer.writeln('   • Grandes animales/rumiantes (Bovino, Ovino, Caprino, Equino): antiparasitarios inyectables como Ivomec Gold (ivermectina al 3.15%), doramectina o suspensiones inyectables son EXCLUSIVAMENTE inyectables por vía subcutánea (SC en la tabla del cuello). Vía oral altera la flora ruminal, es ineficaz y potencialmente tóxico.');
      buffer.writeln('   • Presentaciones dérmicas (Pour-on/Spot-on/pipetas): aplicación tópica externa. NUNCA ingestión oral.');
      buffer.writeln('   • Si el usuario formula preguntas asumiendo una vía incorrecta, corrígelo de inmediato.');
      buffer.writeln('2. NUNCA INVENTES CRONOGRAMAS NI REPETICIONES ARBITRARIAS (ej: Día 1, Día 8, Día 15):');
      buffer.writeln('   • Fármacos de larga acción (como Ivomec Gold 3.15%) tienen persistencia tisular prolongada de 50 a 75 días. Aplicarlo semanalmente causa sobredosificación acumulativa.');
      buffer.writeln('3. VERACIDAD TÉCNICA DE CONCENTRACIONES Y MARCAS COMERCIALES:');
      buffer.writeln('   • Ivermectina clásica al 1% = 10 mg/ml (dosis estándar bovina: 200 mcg/kg = 0.2 mg/kg = 1 ml cada 50 kg SC).');
      buffer.writeln('   • Ivomec Gold al 3.15% = 31.5 mg/ml formulación de larga acción (dosis técnica bovina oficial: 630 mcg/kg = 0.63 mg/kg = 1 ml cada 50 kg SC; para 20 kg equivale a exactamente 0.4 ml SC = 12.60 mg de principio activo).');
      buffer.writeln('   • Si no se especifica concentración, advierte diferencias (1% vs 3.15%) y exige confirmar en etiqueta. NUNCA asumas volumen en ml.');
      buffer.writeln('4. FISIOLOGÍA SEGÚN ESPECIE (RUMIANTES / GRANDES ANIMALES VS CARNÍVOROS):');
      buffer.writeln('   • Bovinos, ovinos o equinos requieren vocabulario zootécnico y veterinario de grandes animales (dosis por peso con jeringa, vía subcutánea, tiempo de retiro para carne y leche). NUNCA hables de plato de comida ni de vómitos.');
      buffer.writeln('5. TOXICIDAD HUMANA Y SENSIBILIDAD GENÉTICA:');
      buffer.writeln('   • Fármacos humanos (Paracetamol, Ibuprofeno, Aspirina, Naproxeno, Diclofenaco) son ALTAMENTE TÓXICOS o MORTALES en perros y gatos.');
      buffer.writeln('   • Sensibilidad genética gen MDR1/ABCB1 (Collies, Pastores): ivermectina causa neurotoxicidad letal. Alimentos tóxicos: chocolate, xilitol, cebolla, uvas.');
      buffer.writeln('6. CONTRAINDICACIONES FATALES: GATOS: Paracetamol, permetrinas. CONEJOS: Fipronil, penicilinas orales. TORTUGAS: Ivermectina. AVES: humos de teflón caliente (PTFE). CABALLOS: ionóforos.');
      buffer.writeln('7. TIEMPOS DE RETIRO: Advertir siempre período de retiro en carne y leche en animales de producción.');
      buffer.writeln('8. ROL ASISTENCIAL: Las dosis veterinarias dependen del peso, especie y condición. Remite a la prescripción del veterinario tratante.');
      buffer.writeln('9. Tono empático, riguroso y profesional.');
    } else if (isCaregiverMode) {
      final isClinico = caregiverModeType == CaregiverModeType.clinico;
      if (activeProfile != null) {
        // Vista de Paciente Individual
        final patientName = activeProfile.name.trim();
        final rel = activeProfile.relationship.trim();
        final room = activeProfile.roomNumber?.trim().isNotEmpty == true ? ', Hab/Cama ${activeProfile.roomNumber!.trim()}' : '';
        final cat = activeProfile.category?.trim().isNotEmpty == true ? ', Área ${activeProfile.category!.trim()}' : '';

        buffer.writeln('Eres Midi, el asistente de cuidado especializado de MediTime.');
        buffer.writeln('MODO ACTIVO: ${isClinico ? "🩺 MODO CUIDADOR CLÍNICO" : "👨‍👩‍👧 MODO CUIDADOR FAMILIAR"} (VISTA DE PACIENTE INDIVIDUAL).');
        buffer.writeln('Cuidador responsable: $userLabel.');
        buffer.writeln('PACIENTE SELECCIONADO EN PANTALLA: $patientName ($rel$room$cat).');
        if (activeProfile.bloodType?.trim().isNotEmpty == true) {
          buffer.writeln('Tipo de sangre: ${activeProfile.bloodType!.trim()}.');
        }
        if (activeProfile.allergies?.trim().isNotEmpty == true) {
          buffer.writeln('Alergias conocidas: ${activeProfile.allergies!.trim()}.');
        }
        if (activeProfile.notes?.trim().isNotEmpty == true) {
          buffer.writeln('Notas del paciente: ${activeProfile.notes!.trim()}.');
        }
        buffer.writeln('ENFOQUE: Todas las consultas de medicación, dosis y finalización de tratamientos se refieren a **$patientName**.');
      } else {
        // Vista General de Cuidador (Todos los Pacientes)
        final patientProfiles = (allProfiles ?? []).where((p) => !p.isAnimal).toList();
        buffer.writeln('Eres Midi, el asistente de cuidado especializado de MediTime.');
        buffer.writeln('MODO ACTIVO: ${isClinico ? "🩺 MODO CUIDADOR CLÍNICO" : "👨‍👩‍👧 MODO CUIDADOR FAMILIAR"} (VISTA GENERAL DE PACIENTES).');
        buffer.writeln('Cuidador responsable: $userLabel.');
        buffer.writeln('Estás en la VISTA GENERAL. Gestionas a ${patientProfiles.length} paciente(s) a tu cargo:');
        for (final patient in patientProfiles) {
          final rm = patient.roomNumber?.trim().isNotEmpty == true ? ', Hab/Cama ${patient.roomNumber!.trim()}' : '';
          final rl = patient.relationship.trim().isNotEmpty == true ? ' (${patient.relationship.trim()}$rm)' : '';
          final al = patient.allergies?.trim().isNotEmpty == true ? ' [Alergias: ${patient.allergies!.trim()}]' : '';
          buffer.writeln('- Paciente: **${patient.name}**$rl$al');
        }
        buffer.writeln();
        buffer.writeln('REGLAS OBLIGATORIAS DE LA VISTA GENERAL DE CUIDADOR:');
        buffer.writeln('1. Supervisas a múltiples pacientes. NUNCA asumas que hay un solo paciente.');
        buffer.writeln('2. Al responder sobre tratamientos, tomas o finalización, DEBES SIEMPRE AGRUPAR O ESPECIFICAR EL NOMBRE DEL PACIENTE.');
        buffer.writeln('3. Si preguntan por un paciente específico, filtra solo por él. Si es general, resume paciente por paciente.');
      }

      buffer.writeln();
      buffer.writeln('REGLAS CLÍNICAS Y DE FARMACOVIGILANCIA EN HUMANOS (MODO CUIDADOR):');
      buffer.writeln('1. LOS 5 CORRECTOS UNIVERSALES DE ADMINISTRACIÓN CLÍNICA:');
      buffer.writeln('   • Paciente correcto: confirma siempre a qué paciente corresponde cada indicación o dosis.');
      buffer.writeln('   • Medicamento correcto: distingue principios activos y comerciales; alerta ante medicamentos con nombres o fonética similar (LASA).');
      buffer.writeln('   • Dosis correcta: nunca inventes dosis ni avales superar dosis máximas (paracetamol máx 3-4 g/día, ibuprofeno máx 1200-2400 mg/día).');
      buffer.writeln('   • Vía correcta: oral, parenteral, tópica, etc. NUNCA triturar ni partir comprimidos de liberación prolongada (LP/XR/CR) o cubierta entérica.');
      buffer.writeln('   • Hora y frecuencia correcta: respetar intervalos y relación con alimentos.');
      buffer.writeln('2. SEGURIDAD EN POBLACIONES ESPECIALES:');
      buffer.writeln('   • Geriátricos: riesgo de sedación, caídas con psicofármacos, y daño renal/gástrico con AINEs.');
      buffer.writeln('   • Pediátricos: dosificación por peso (mg/kg). Aspirina contraindicada en niños y adolescentes con fiebre o infección viral por riesgo de Síndrome de Reye.');
      buffer.writeln('3. TRAZABILIDAD: ${isClinico ? "Aplica rigor clínico hospitalario y verificación de los 5 correctos (paciente, medicamento, dosis, vía, hora)." : "Brinda apoyo empático y tranquilidad al cuidador familiar."} Coteja siempre las alergias conocidas del paciente.');
      buffer.writeln('4. FARMACOVIGILANCIA E INTERACCIONES CRUZADAS (CRÍTICO):');
      buffer.writeln('   • Evalúa siempre interacciones entre medicamentos concurrentes del paciente (ej: Warfarina + Cefalexina/antibióticos con riesgo de INR/hemorragia, o anticoagulantes + AINEs).');
      buffer.writeln('   • Prioriza esta alerta en la tarjeta destacada (> ⚠️ **Atención:**) indicando el mecanismo, riesgo y la acción médica requerida.');
    } else {
      buffer.writeln('Eres Midi, el asistente virtual y organizador de salud personal de MediTime.');
      buffer.writeln('MODO ACTIVO: 👤 MODO PERSONAL.');
      buffer.writeln('Usuario: $userLabel.');
      buffer.writeln();
      buffer.writeln('REGLAS FARMACOLÓGICAS Y DE SEGURIDAD EN SALUD HUMANA:');
      buffer.writeln('1. ORGANIZACIÓN Y ADHERENCIA: Ayuda a cumplir tratamientos, dosis, horarios y stock con explicaciones claras.');
      buffer.writeln('2. PREVENCIÓN DE AUTOMEDICACIÓN:');
      buffer.writeln('   • Si consulta por síntomas o fármacos no registrados: información objetiva, advertencias y remisión al médico.');
      buffer.writeln('   • los antibióticos requieren receta médica y no tienen efecto contra infecciones virales (gripe, resfriado).');
      buffer.writeln('   • Alerta sobre hepatotoxicidad por exceso de paracetamol o daño gástrico por AINEs. Nunca duplicar dosis ante olvidos.');
      buffer.writeln('3. POBLACIONES VULNERABLES: En embarazo, lactancia o enfermedades crónicas (hipertensión, diabetes, insuficiencia renal), exigir valoración médica.');
      buffer.writeln('4. INTERACCIONES Y FORMAS: Peligro de combinar alcohol con sedantes. No partir comprimidos de liberación prolongada (LP/XR/CR).');
      buffer.writeln('5. FARMACOVIGILANCIA E INTERACCIONES CRUZADAS (CRÍTICO):');
      buffer.writeln('   • Al resumir o hablar sobre los tratamientos activos, SIEMPRE revisa si coexisten medicamentos con interacciones clínicamente relevantes.');
      buffer.writeln('   • Interacción de alto riesgo: Anticoagulantes (Warfarina, Acenocumarol) + Antibióticos (Cefalexina, Amoxicilina, etc.): advierte que los antibióticos pueden alterar la flora bacteriana intestinal (que sintetiza vitamina K) o el metabolismo, potenciando el efecto anticoagulante y disparando peligrosamente el INR con alto riesgo de hemorragia. Conducta obligatoria: Notificar al médico tratante para programar control estrecho de INR y evaluar ajuste de dosis.');
      buffer.writeln('   • Anticoagulantes + AINEs (ibuprofeno, naproxeno, aspirina): multiplican el riesgo de hemorragia gastrointestinal severa.');
      buffer.writeln('   • PRIORIDAD DE ALERTA: Si existe una interacción activa de este tipo, la ÚNICA tarjeta destacada (> ⚠️ **Atención:**) DEBE estar dedicada a advertir esta interacción por encima de cualquier consejo genérico.');
      buffer.writeln('6. PROTOCOLO DE SIGNOS DE ALARMA Y EMERGENCIAS (BANDERAS ROJAS):');
      buffer.writeln('   • Ante dolor opresivo en el pecho, dificultad respiratoria severa, sospecha de accidente cerebrovascular, sangrado abundante o anafilaxia: INDICA DE INMEDIATO LLAMAR A URGENCIAS (911 o número de emergencias local).');
    }

    // 2. Behavioral guidelines & Visual Presentation
    buffer.writeln();
    buffer.writeln('DIRECTRICES DE FORMATO Y PRESENTACIÓN VISUAL:');
    buffer.writeln('- Responde siempre en el idioma del usuario (${language.startsWith("en") ? "Inglés" : language.startsWith("pt") ? "Portugués" : "Español"}), conciso y estructurado.');
    buffer.writeln('- ESTRUCTURACIÓN VISUAL:');
    // Determine dynamic table structure based on active mode and view
    final String tableHeaderExample;
    if (!isAnimalMode && !isCaregiverMode) {
      tableHeaderExample = '| Medicamento | Presentación | Fin de tratamiento | Días restantes |';
    } else if (activeProfile != null) {
      tableHeaderExample = '| Medicamento | Presentación | Fin de tratamiento | Días restantes |';
    } else {
      tableHeaderExample = isAnimalMode
          ? '| Mascota | Medicamento | Fin de tratamiento | Días restantes |'
          : '| Paciente | Medicamento | Fin de tratamiento | Días restantes |';
    }

    buffer.writeln('  • Para resumir/comparar tratamientos, dosis o fechas de fin, usa una TABLA MARKDOWN ($tableHeaderExample) o viñetas (•).');
    if (!isAnimalMode && !isCaregiverMode) {
      buffer.writeln('  • En Modo Personal, NUNCA incluyas una columna de "Paciente" ni repitas el nombre del usuario en las filas; todos los medicamentos son personales.');
    } else if (activeProfile != null) {
      buffer.writeln('  • En Vista Individual, NO incluyas columna de Paciente o Mascota en la tabla; ya está indicado en el encabezado.');
    }
    buffer.writeln('  • EQUILIBRIO VISUAL (EVITA SATURAR CON TARJETAS):');
    buffer.writeln('    - La mayor parte de la respuesta (explicación de medicamentos, para qué sirven, recomendaciones habituales) debe ser TEXTO NORMAL o LISTAS DE VIÑETAS ESTÁNDAR (•), FUERA de citas.');
    buffer.writeln('    - Reserva las tarjetas destacadas (> ⚠️ **Atención:** o > 💡 **Nota:**) ÚNICAMENTE para máximo 1 alerta de seguridad clínica crítica cuando sea estrictamente necesaria (dando prioridad absoluta a interacciones farmacológicas activas detectadas entre sus tratamientos concurrentes).');
    buffer.writeln('    - NUNCA encierres toda la información dentro de cajas de llamada ni apiles 3 o 4 tarjetas seguidas.');
    buffer.writeln('  • Medicamentos en negrita: **Nombre**. Emojis adecuados (🐾, 🩺, 💊, 📅, ⏳, ⚠️, 💡).');
    buffer.writeln('- CONFIDENCIALIDAD DE FUNCIONES Y HERRAMIENTAS:');
    buffer.writeln('  • NUNCA menciones nombres de funciones o herramientas técnicas en el texto visible al usuario (como create_treatment, update_dose_status, show_adherence_chart, get_today_medications, etc.). Está estrictamente prohibido.');
    buffer.writeln('  • Comunícate siempre en lenguaje natural médico y empático (ej: "Con gusto programo el recordatorio para...", "He registrado tu dosis de...", "Aquí tienes tu informe de adherencia...").');
    buffer.writeln('  • NUNCA escribas llamadas a funciones como texto visible ni JSON {"function": ...}.');
    buffer.writeln('- MANEJO DE GRÁFICO E INFORME DE ADHERENCIA:');
    buffer.writeln('  • Cuando el usuario pida ver su progreso, estadísticas o reporte de adherencia (ej: "mi reporte de hoy", "reporte del día", "reporte de la semana", "reporte del mes", "reporte del año", "reporte de los últimos 15 días", "reporte del 1 al 10 de octubre", "muéstrame mi progreso", "dame mi reporte"):');
    buffer.writeln('    - INVOCA SIEMPRE la herramienta show_adherence_chart pasando los argumentos del período solicitado:');
    buffer.writeln('      * "periodo": "dia", "semana", "mes", "anio" o "personalizado".');
    buffer.writeln('      * "dias": número entero de días (ej: 1 para hoy, 7 para semana, 30 para mes, o el número pedido).');
    buffer.writeln('      * "fechaInicio" / "fechaFin": si el usuario pide un rango de fechas específico (formato YYYY-MM-DD).');
    buffer.writeln('    - NUNCA emitas notas de espera como "Se está generando tu reporte... espera unos segundos". El widget de adherencia se despliega instantáneamente en la interfaz.');
    buffer.writeln('    - Responde de forma concisa y profesional (máximo 100-140 palabras): confirma el informe ("Aquí tienes tu informe de adherencia del [periodo]:"), resalta el porcentaje global y da 2 o 3 recomendaciones clínicas breves en viñetas.');
    buffer.writeln('    - NUNCA escribas una tabla markdown larga repitiendo los datos numéricos que la tarjeta visual ya despliega, para evitar respuestas excesivas que se corten.');
    buffer.writeln('  • Cuando el usuario diga "Analízalo", "Qué opinas", o pida interpretar su adherencia:');
    buffer.writeln('    - ANALIZA DE INMEDIATO los datos de adherencia que ya tienes en el contexto o en la herramienta sin decir que no hay datos y sin volver a invocar show_adherence_chart.');
    buffer.writeln('    - Evalúa el porcentaje global, medicamentos con mejor cumplimiento y oportunidades de mejora de manera constructiva.');
    buffer.writeln('- REGLAS DE INVOCACIÓN DE HERRAMIENTAS VS RESPUESTAS DIRECTAS:');
    buffer.writeln('  • REPORTE / PROGRESO / ADHERENCIA: Si el usuario solicita su reporte, progreso, estadísticas o adherencia (ej: "dame mi reporte", "reporte del día", "mi progreso de hoy", "adherencia de este mes", "cómo voy con mis dosis"), INVOCA la herramienta show_adherence_chart indicando el período solicitado (dia, semana, mes, anio, o días). Acompaña SIEMPRE tu respuesta con un saludo breve, resumen del cumplimiento y recomendaciones clínicas prácticas.');
    buffer.writeln('  • RECORDATORIOS / CAMBIOS DE DOSIS: Invoca create_treatment o update_dose_status según corresponda.');
    buffer.writeln('  • CONSULTAS INFORMATIVAS: Si la información sobre tratamientos, horarios, fechas de fin o stock está en el [CONTEXTO ACTIVO HOY] abajo, respóndela directamente sin invocar herramientas.');
    buffer.writeln('- ASIGNACIÓN EXACTA DE PERFILES EN RECORDATORIOS (create_treatment / update_dose_status):');
    buffer.writeln('  • En Modo Cuidador o Modo Animales, incluye OBLIGATORIAMENTE el parámetro "targetProfileName" con el nombre exacto del paciente o mascota destinatario (ej: "targetProfileName": "Juan David").');
    buffer.writeln('  • En vista individual, usa ese paciente/mascota por defecto en "targetProfileName". Si se menciona en el mensaje, usa ese nombre exacto. NUNCA lo omitas cuando haya un perfil identificado.');
    buffer.writeln();
    buffer.writeln('CONSULTAS DE RECORDATORIOS Y DOSIS DEL DÍA (HOY O MAÑANA):');
    buffer.writeln('- Revisa "Dosis hoy" en [CONTEXTO ACTIVO HOY] abajo o las dosis de la fecha solicitada.');
    buffer.writeln('- FORMATO PREFERIDO EN VIÑETAS (MÁS LEGIBLE Y LIMPIO EN MÓVIL):');
    buffer.writeln('  • **Cefalexina**: 05:21 a. m. — Tomada');
    buffer.writeln('  • **Warfarina**: 06:59 a. m. — Omitida');
    buffer.writeln('  • **Cefalexina**: 11:21 a. m. — Programada');
    buffer.writeln('- SI USAS TABLA MARKDOWN, DEBE TENER ESTRICTAMENTE 3 COLUMNAS COMPLETAS:');
    buffer.writeln('  | Medicamento | Hora | Estado |');
    buffer.writeln('  | :--- | :--- | :--- |');
    buffer.writeln('  | Cefalexina | 05:21 a. m. | Tomada |');
    buffer.writeln('  | Warfarina | 06:59 a. m. | Omitida |');
    buffer.writeln('  | Cefalexina | 11:21 a. m. | Programada |');
    buffer.writeln('  REGLA INQUEBRANTABLE DE TABLAS: La columna "Hora" solo lleva la hora (ej: 05:21 a. m.). La columna "Estado" lleva el estado (Tomada, Omitida, Pendiente o Programada). NUNCA dejes la columna "Estado" vacía ni coloques el estado dentro de la columna "Hora".');
    buffer.writeln('- SI EL USUARIO PREGUNTA SI OMITIÓ ALGUNA DOSIS HOY ("¿hoy omití alguna?"):');
    buffer.writeln('  • Revisa si hay alguna dosis con estado [Omitida] o [omitida] en el día de hoy.');
    buffer.writeln('  • Si hay dosis con [Omitida] o [omitida] (incluso si fue omitida antes de que sonara la alarma), RESPONDE AFIRMATIVAMENTE indicando de inmediato el medicamento y la hora exacta (ej: "Sí, omitiste la toma de Warfarina de las 06:59 a. m.").');
    buffer.writeln('  • NUNCA digas que una dosis omitida está "pendiente", ni digas que "no has omitido ninguna dosis hoy" si aparece [Omitida] o [omitida].');
    buffer.writeln();
    buffer.writeln('CONSULTAS SOBRE CUÁNDO TERMINA UN TRATAMIENTO O DURACIÓN:');
    buffer.writeln('- Revisa "Periodo" y días restantes en [CONTEXTO ACTIVO HOY].');
    buffer.writeln('- ORDEN PRIORITARIO EN TABLAS: Ordena SIEMPRE por urgencia de fecha de fin (primero los que terminan HOY o MAÑANA, luego los de menor a mayor días restantes, y al final los continuos/indefinidos).');
    buffer.writeln('- Para un medicamento específico, indica fecha de fin exacta y días restantes. Si es indefinido o crónico, aclara que está registrado como Continuo / Indefinido (sin fecha de fin programada).');
    buffer.writeln('- Si termina HOY o MAÑANA, destácalo de inmediato (ej: "¡Hoy es tu último día de tratamiento!"). En vista general de cuidador o mascotas, aclara a qué paciente o mascota pertenece cada tratamiento.');
    buffer.writeln('- RECOMENDACIONES Y ADVERTENCIAS: Redáctalas principalmente en viñetas estándar (•). Si hay una advertencia médica crítica, usa a lo sumo UNA caja destacada (> ⚠️ **Atención:** ...). NUNCA dejes signos ">" sueltos como texto visible.');

    // 3. Compact Context Pre-Injection
    final treatments = (activeTreatments != null)
        ? List<Tratamiento>.from(activeTreatments)
        : <Tratamiento>[];

    // Ordenar clínicamente por urgencia de finalización:
    // 1. Los que terminan hoy o mañana primero
    // 2. Los que terminan pronto por fecha ascendente
    // 3. Los indefinidos / continuos al final
    treatments.sort((a, b) {
      final aIndefinite = a.duracion.toLowerCase().contains('indefinid') || a.duracion == '0';
      final bIndefinite = b.duracion.toLowerCase().contains('indefinid') || b.duracion == '0';
      if (aIndefinite && !bIndefinite) return 1;
      if (!aIndefinite && bIndefinite) return -1;
      if (aIndefinite && bIndefinite) return a.nombreMedicamento.compareTo(b.nombreMedicamento);
      return a.fechaFinTratamiento.compareTo(b.fechaFinTratamiento);
    });

    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln('[CONTEXTO ACTIVO HOY: $todayStr]');
    if (treatments.isEmpty) {
      buffer.writeln('No hay tratamientos activos registrados.');
    } else {
      buffer.writeln('Tratamientos activos (${treatments.length}):');
      for (final t in treatments) {
        final dayDoses = calculateDayDoses(t, effectiveNow, now: effectiveNow);
        final todayDoses = <String>[];

        for (final item in dayDoses) {
          final dt = item['time'] as DateTime;
          final timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
          final DoseStatus st = item['status'] as DoseStatus;
          final bool isProg = item['isProgramada'] == true;
          final label = isProg ? 'Programada' : st.displayName;
          todayDoses.add('$timeStr [$label]');
        }

        final dosesStr = todayDoses.isNotEmpty ? ' | Dosis hoy: ${todayDoses.join(", ")}' : ' | Sin dosis programadas hoy';
        final stockStr = t.cantidadTotalCaja > 0 ? ' | Stock: ${t.cantidadActual}/${t.cantidadTotalCaja}${t.hasStockBajo ? " (BAJO)" : ""}' : '';

        // Owner identification ONLY for multi-patient or multi-pet general views
        String ownerTag = '';
        if ((isAnimalMode || isCaregiverMode) && activeProfile == null && t.profileId != null && allProfiles != null) {
          final owner = allProfiles.cast<CaregiverProfile?>().firstWhere(
            (p) => p?.id == t.profileId,
            orElse: () => null,
          );
          if (owner != null) {
            ownerTag = ' [${owner.isAnimal ? "Mascota" : "Paciente"}: ${owner.name}]';
          }
        }

        // Duration & End Date calculation
        final startDt = t.fechaInicioTratamiento;
        final endDt = t.fechaFinTratamiento;
        final isIndefinite = t.duracion.toLowerCase().contains('indefinid') || t.duracion == '0';

        String timelineStr;
        if (isIndefinite) {
          timelineStr = 'Inicio: ${formatFriendlyDate(startDt)} | Duración: Continuo / Indefinido (sin fecha de fin programada)';
        } else {
          final endDayOnly = DateTime(endDt.year, endDt.month, endDt.day);
          final todayDayOnly = DateTime(effectiveNow.year, effectiveNow.month, effectiveNow.day);
          final daysDiff = endDayOnly.difference(todayDayOnly).inDays;

          String remainingTag;
          if (daysDiff < 0) {
            remainingTag = 'Finalizó hace ${-daysDiff} día(s)';
          } else if (daysDiff == 0) {
            remainingTag = '¡Finaliza HOY!';
          } else if (daysDiff == 1) {
            remainingTag = 'Finaliza MAÑANA (queda 1 día)';
          } else {
            remainingTag = 'quedan $daysDiff días restantes';
          }

          timelineStr = 'Inicio: ${formatFriendlyDate(startDt)} | Fin: ${formatFriendlyDate(endDt)} ($remainingTag | Duración: ${t.duracion})';
        }

        buffer.writeln('- **${t.nombreMedicamento}**$ownerTag (${t.presentacion}, ${t.dosisPorToma} por toma c/${t.intervaloDosis.inHours}h$dosesStr$stockStr)');
        buffer.writeln('  • Periodo: $timelineStr');
        if (t.notas.isNotEmpty) {
          buffer.writeln('  • Notas: ${t.notas}');
        }
      }

      final adhSummary = calculateAdherenceSummary(treatments, now: effectiveNow);
      buffer.writeln();
      buffer.writeln('[RESUMEN DE ADHERENCIA RECIENTE (ÚLTIMOS 7 DÍAS: ${adhSummary["periodo"]})]:');
      buffer.writeln('• Cumplimiento global: ${adhSummary["adherence"]}% (${adhSummary["tomadas"]} tomadas de ${adhSummary["programadas"]} programadas, ${adhSummary["omitidas"]} omitidas o pendientes).');
      buffer.writeln('• Detalle por medicamento: ${adhSummary["breakdown"]}.');

      final detectedInteractions = detectCriticalConcurrentInteractions(
        treatments: treatments,
        isAnimalMode: isAnimalMode,
      );
      if (detectedInteractions.isNotEmpty) {
        buffer.writeln();
        buffer.writeln('[FARMACOVIGILANCIA: ALERTAS DE INTERACCIÓN DETECTADAS]:');
        for (final alert in detectedInteractions) {
          buffer.writeln('• ⚠️ $alert');
        }
        buffer.writeln('DIRECTIVA OBLIGATORIA: En cualquier resumen o consulta de tratamientos activos, DEBES priorizar esta alerta en la tarjeta destacada (> ⚠️ **Atención:**), detallando el mecanismo, riesgo de incremento de INR/sangrado y la indicación de contactar al médico tratante para control y ajuste.');
      }
    }
    buffer.writeln('---');

    return buffer.toString().trim();
  }

  @visibleForTesting
  static List<Map<String, dynamic>> get tools => _tools;

  /// Tool definitions for Groq function calling.
  static const List<Map<String, dynamic>> _tools = [
    {
      'type': 'function',
      'function': {
        'name': 'get_today_medications',
        'description': 'Get today\'s medications and statuses.',
        'parameters': {
          'type': 'object',
          'properties': <String, dynamic>{},
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'get_tomorrow_medications',
        'description': 'Get tomorrow\'s medications.',
        'parameters': {
          'type': 'object',
          'properties': <String, dynamic>{},
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'get_active_treatments',
        'description': 'Get summary of active treatments.',
        'parameters': {
          'type': 'object',
          'properties': <String, dynamic>{},
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'create_treatment',
        'description': 'Create a new medication reminder.',
        'parameters': {
          'type': 'object',
          'properties': {
            'nombreMedicamento': {'type': 'string'},
            'presentacion': {'type': 'string'},
            'dosisPorToma': {'type': 'integer', 'default': 1},
            'intervaloDosis': {'type': 'integer', 'default': 8},
            'duracion': {'type': 'integer', 'default': 7},
            'notas': {'type': 'string'},
            'targetProfileName': {
              'type': 'string',
              'description': 'Nombre del paciente o mascota para quien es este tratamiento (ej: "Juan David", "Margarita").',
            },
          },
          'required': ['nombreMedicamento'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'update_dose_status',
        'description': 'Mark dose as tomada, omitida, or aplazada.',
        'parameters': {
          'type': 'object',
          'properties': {
            'medicamento': {'type': 'string'},
            'status': {'type': 'string', 'enum': ['tomada', 'omitida', 'aplazada']},
            'minutosAplazo': {'type': 'integer', 'default': 30},
            'updateAll': {'type': 'boolean', 'default': false},
            'targetProfileName': {
              'type': 'string',
              'description': 'Nombre del paciente o mascota asignado al medicamento.',
            },
          },
          'required': ['medicamento', 'status'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'show_adherence_chart',
        'description': 'Show interactive adherence chart and stats for a specific period (day, week, month, year, or custom interval).',
        'parameters': {
          'type': 'object',
          'properties': {
            'periodo': {
              'type': 'string',
              'description': 'Requested interval: "dia" (today), "semana" (last 7 days / week), "mes" (month), "anio" (year), or "personalizado" (custom days or range).',
            },
            'dias': {
              'description': 'Number of days to evaluate (e.g. 1 for today, 7 for week, 30 for month, 15 for 15 days).',
            },
            'fechaInicio': {
              'type': 'string',
              'description': 'Start date in YYYY-MM-DD format if user requested a custom range.',
            },
            'fechaFin': {
              'type': 'string',
              'description': 'End date in YYYY-MM-DD format if user requested a custom range.',
            },
          },
          'required': <String>[],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'get_treatment_inventory',
        'description': 'Check medication inventory.',
        'parameters': {
          'type': 'object',
          'properties': {
            'medicamento': {'type': 'string', 'default': ''},
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'get_missed_doses',
        'description': 'Get missed/skipped doses.',
        'parameters': {
          'type': 'object',
          'properties': {
            'days': {'type': 'integer', 'default': 7},
          },
        },
      },
    },
  ];

  /// Executes a tool function locally and returns the result string.
  /// The [activeTreatments] must be pre-filtered to only active ones.
  String executeToolFunction(
    String functionName,
    Map<String, dynamic> arguments,
    List<Tratamiento> activeTreatments,
  ) {
    switch (functionName) {
      case 'get_today_medications':
        return _getScheduledMedications(activeTreatments, DateTime.now());
      case 'get_tomorrow_medications':
        return _getScheduledMedications(
          activeTreatments,
          DateTime.now().add(const Duration(days: 1)),
        );
      case 'get_active_treatments':
        return _getActiveTreatmentsSummary(activeTreatments);
      case 'get_treatment_inventory':
        final medName = arguments['medicamento']?.toString() ?? '';
        return _getInventory(activeTreatments, medName);
      case 'get_missed_doses':
        final days = (arguments['days'] as int?) ?? 7;
        return _getMissedDoses(activeTreatments, days);
      case 'create_treatment':
        return 'Acción "crear recordatorio" procesada por la aplicación.';
      case 'update_dose_status':
        return 'Acción "actualizar dosis" procesada por la aplicación.';
      case 'show_adherence_chart':
        DateTime? customStart;
        DateTime? customEnd;
        if (arguments['fechaInicio'] != null && arguments['fechaInicio'].toString().isNotEmpty) {
          customStart = DateTime.tryParse(arguments['fechaInicio'].toString());
        }
        if (arguments['fechaFin'] != null && arguments['fechaFin'].toString().isNotEmpty) {
          customEnd = DateTime.tryParse(arguments['fechaFin'].toString());
        }
        final periodo = arguments['periodo']?.toString();
        final dias = arguments['dias'] is int
            ? arguments['dias'] as int
            : int.tryParse(arguments['dias']?.toString() ?? '');

        final summary = calculateAdherenceSummary(
          activeTreatments,
          customStart: customStart,
          customEnd: customEnd,
          periodoType: periodo,
          daysCount: dias,
        );
        return 'Gráfico de adherencia desplegado en pantalla para el periodo ${summary["periodo"]}. '
            'Datos reales calculados: Adherencia general ${summary["adherence"]}%, '
            '${summary["tomadas"]} dosis tomadas de ${summary["programadas"]} programadas, '
            '${summary["omitidas"]} omitidas o pendientes. '
            'Desglose por medicamento: ${summary["breakdown"]}. '
            'DIRECTIVA AL ASISTENTE: Confirma directamente la presentación con una frase natural como "Aquí tienes tu informe de adherencia del [periodo]...", resume los datos reales y ofrece tu análisis clínico sin emitir notas de espera ("espera unos segundos").';
      default:
        return 'Unknown function: $functionName';
    }
  }

  /// Sends a message and handles the full function-calling loop.
  /// Returns a stream of progressive text updates for the final response.
  /// [onToolCalls] is invoked when the model requests tool calls that
  /// the UI needs to handle (create_treatment, update_dose_status, show_adherence_chart).
  Stream<String> streamResponse(
    String userMessage, {
    List<Tratamiento>? activeTreatments,
    CaregiverProfile? activeProfile,
    List<CaregiverProfile>? allProfiles,
    bool isAnimalMode = false,
    bool isCaregiverMode = false,
    CaregiverModeType? caregiverModeType,
    String? userName,
    String language = 'es',
    void Function(List<ToolCallResult>)? onToolCalls,
  }) async* {
    final prompt = userMessage.trim();
    if (prompt.isEmpty) {
      throw ArgumentError('User message cannot be empty.');
    }

    final apiKey = await getEffectiveApiKey();
    if (apiKey.isEmpty) {
      throw StateError(
        'Falta la clave de Groq API. Configúrala en la app o ejecuta con --dart-define=GROQ_API_KEY=TU_CLAVE.',
      );
    }

    final treatments = activeTreatments ?? <Tratamiento>[];

    final systemContent = buildSystemPrompt(
      isAnimalMode: isAnimalMode,
      isCaregiverMode: isCaregiverMode,
      caregiverModeType: caregiverModeType,
      activeProfile: activeProfile,
      allProfiles: allProfiles,
      userName: userName,
      language: language,
      activeTreatments: treatments,
    );

    // Isolate conversation history per mode and profile to prevent cross-contamination
    final currentSignature = computeModeSignature(
      isAnimalMode: isAnimalMode,
      isCaregiverMode: isCaregiverMode,
      caregiverModeType: caregiverModeType,
      activeProfile: activeProfile,
    );
    if (_lastModeSignature != null && _lastModeSignature != currentSignature) {
      debugPrint('GeminiService: Mode changed from $_lastModeSignature to $currentSignature. Wiping chat history.');
      clearHistory();
    }
    _lastModeSignature = currentSignature;

    // Build messages array
    final messages = <Map<String, dynamic>>[
      <String, String>{
        'role': 'system',
        'content': systemContent,
      },
      ..._history,
      <String, String>{'role': 'user', 'content': prompt},
    ];

    // Step 1: Send initial request (non-streaming) to check for tool calls
    final initialResponse = await _sendChatRequest(
      messages,
      apiKey: apiKey,
      useTools: true,
    );

    final choice = initialResponse['choices']?[0] as Map<String, dynamic>?;
    if (choice == null) {
      final adhSummary = calculateAdherenceSummary(treatments, now: DateTime.now());
      yield 'Aquí tienes el reporte con el progreso de tus tratamientos (${adhSummary["adherence"]}% de cumplimiento). '
          'Recuerda tomar cada dosis según los intervalos programados para mantener la efectividad de tus medicamentos.';
      return;
    }

    final messageRaw = choice['message'];
    if (messageRaw is! Map<String, dynamic>) {
      throw StateError('Invalid API response format (missing message): $choice');
    }
    final message = messageRaw;
    if (message['content'] == null) {
      message['content'] = '';
    }
    final toolCalls = message['tool_calls'] as List<dynamic>?;

    if (toolCalls != null && toolCalls.isNotEmpty) {
      // Model wants to call tools — execute them
      final List<ToolCallResult> uiToolCalls = [];
      
      // Add assistant message with tool_calls to the messages
      messages.add(message);

      for (final tc in toolCalls) {
        final tcMap = tc as Map<String, dynamic>;
        final fnObj = tcMap['function'] as Map<String, dynamic>;
        final fnName = fnObj['name'] as String;
        final argsString = fnObj['arguments'] as String? ?? '{}';
        final dynamic decodedArgs = jsonDecode(argsString.isEmpty ? '{}' : argsString);
        final fnArgs = decodedArgs is Map<String, dynamic> ? decodedArgs : <String, dynamic>{};
        final toolCallId = tcMap['id'] as String;

        // Sanitize string-numbers to int to prevent UI crashes if Groq leaks them
        for (final key in fnArgs.keys.toList()) {
          final val = fnArgs[key];
          if (val is String && (key == 'dosisPorToma' || key == 'intervaloDosis' || key == 'duracion' || key == 'minutosAplazo' || key == 'days')) {
            final parsed = int.tryParse(val);
            if (parsed != null) fnArgs[key] = parsed;
          }
        }

        // Execute locally or flag for UI
        final isUiAction = fnName == 'create_treatment' ||
            fnName == 'update_dose_status' ||
            fnName == 'show_adherence_chart';

        final result = executeToolFunction(fnName, fnArgs, treatments);

        if (isUiAction) {
          uiToolCalls.add(ToolCallResult(
            functionName: fnName,
            arguments: fnArgs,
            result: result,
          ));
        }

        // Add tool result to messages
        messages.add({
          'role': 'tool',
          'tool_call_id': toolCallId,
          'name': fnName,
          'content': result,
        });
      }

      // Notify UI of actions that need handling
      if (uiToolCalls.isNotEmpty && onToolCalls != null) {
        onToolCalls(uiToolCalls);
      }

      // Step 2: Send follow-up with tool results (streaming for final response)
      yield* _streamFinalResponse(messages, prompt, apiKey: apiKey);
    } else {
      // No tool calls — stream the direct response
      String content = message['content'] as String? ?? '';
      if (content.trim().isEmpty) {
        final adhSummary = calculateAdherenceSummary(treatments, now: DateTime.now());
        content = 'Aquí tienes el resumen de tu medicación y adherencia (${adhSummary["adherence"]}% de cumplimiento). '
            'Recuerda registrar cada toma para mantener actualizado tu historial.';
      }
      
      // Save sanitized output to history
      final cleanContent = _sanitizeModelOutput(content).trim();
      _history.add(<String, String>{'role': 'user', 'content': prompt});
      _history.add(<String, String>{'role': 'assistant', 'content': _compactHistoryText(cleanContent)});
      _trimHistory();

      yield content;
    }
  }

  /// Sends a non-streaming chat request (used for tool-call detection).
  Future<Map<String, dynamic>> _sendChatRequest(
    List<Map<String, dynamic>> messages, {
    required String apiKey,
    bool useTools = false,
    bool isRetry = false,
  }) async {
    final body = <String, dynamic>{
      'model': isRetry ? _fallbackModel : _model,
      'messages': messages,
      'stream': false,
      'temperature': 0.3,
      'max_tokens': _maxCompletionTokens,
    };

    if (useTools) {
      body['tools'] = _tools;
      body['tool_choice'] = 'auto';
    }

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: <String, String>{
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if ((response.statusCode == 429 || response.statusCode == 400 || response.statusCode == 404) && !isRetry) {
      debugPrint('GeminiService: ${response.statusCode} Error. Retrying with $_fallbackModel without tools');
      return _sendChatRequest(messages, apiKey: apiKey, useTools: false, isRetry: true);
    }

    if (response.statusCode != 200) {
      final errorBody = response.body;
      debugPrint('Groq API error (${response.statusCode}): $errorBody');
      if (response.statusCode == 401 || errorBody.contains('invalid_api_key')) {
        throw StateError('Error de autenticación (401): La clave de Groq API es inválida o expiró. Verifica tu clave en console.groq.com.');
      } else if (response.statusCode == 404 || errorBody.contains('model_not_found') || errorBody.contains('does not exist')) {
        throw StateError('El modelo de IA solicitado no está disponible en tu cuenta de Groq (Error 404).');
      } else if (response.statusCode == 413 || errorBody.contains('too large')) {
        throw StateError('El mensaje es demasiado extenso para el modelo (413).');
      } else if (response.statusCode == 429 || errorBody.contains('rate_limit')) {
        throw StateError('Límite de solicitudes alcanzado (429). Espera unos segundos e intenta nuevamente.');
      }
      throw StateError('Error al procesar la solicitud (${response.statusCode}): ${response.reasonPhrase ?? "Error de conexión"}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Streams the final response after tool results have been added.
  Stream<String> _streamFinalResponse(
    List<Map<String, dynamic>> messages,
    String originalPrompt, {
    required String apiKey,
    bool isRetry = false,
  }) async* {
    final request = http.Request('POST', Uri.parse(_baseUrl))
      ..headers.addAll(<String, String>{
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      })
      ..body = jsonEncode(<String, dynamic>{
        'model': isRetry ? _fallbackModel : _model,
        'stream': true,
        'temperature': 0.3,
        'max_tokens': _maxCompletionTokens,
        'messages': messages,
      });

    final client = http.Client();
    try {
      final response = await client.send(request);
      
      if ((response.statusCode == 429 || response.statusCode == 400 || response.statusCode == 404) && !isRetry) {
        debugPrint('GeminiService: ${response.statusCode} Error on Stream. Retrying with $_fallbackModel');
        yield* _streamFinalResponse(messages, originalPrompt, apiKey: apiKey, isRetry: true);
        return;
      }

      if (response.statusCode != 200) {
        final errorBody = await response.stream.bytesToString();
        debugPrint('Groq API error (${response.statusCode}): $errorBody');
        if (response.statusCode == 401 || errorBody.contains('invalid_api_key')) {
          throw StateError('Error de autenticación (401): La clave de Groq API es inválida o expiró. Verifica tu clave en console.groq.com.');
        } else if (response.statusCode == 404 || errorBody.contains('model_not_found') || errorBody.contains('does not exist')) {
          throw StateError('El modelo de IA solicitado no está disponible en tu cuenta de Groq (Error 404).');
        } else if (response.statusCode == 429 || errorBody.contains('rate_limit')) {
          throw StateError('Límite de solicitudes alcanzado (429). Espera un momento e intenta de nuevo.');
        }
        throw StateError('Error temporal (${response.statusCode}). Por favor, intenta de nuevo.');
      }

      final fullText = StringBuffer();
      final stream = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final rawLine in stream) {
        final line = rawLine.trim();
        if (!line.startsWith('data: ')) continue;

        final payload = line.substring(6).trim();
        if (payload == '[DONE]') break;

        try {
          final dynamic decoded = jsonDecode(payload);
          final decodedMap = decoded is Map<String, dynamic> ? decoded : null;
          final choices = decodedMap?['choices'] as List<dynamic>? ?? const [];
          if (choices.isEmpty) continue;

          final firstChoice = choices.first;
          if (firstChoice is! Map<String, dynamic>) continue;
          final deltaMap = firstChoice['delta'] as Map<String, dynamic>?;
          final delta = deltaMap?['content'] as String?;
          if (delta == null || delta.isEmpty) continue;

          fullText.write(delta);
          // Apply real-time filter before yielding to prevent artifacts appearing in UI
          yield _sanitizeModelOutput(fullText.toString());
        } catch (_) {
          // Skip malformed SSE lines
          continue;
        }
      }

      if (fullText.isEmpty) {
        yield 'Acción completada.';
      } else {
        // Final pass: strip all hallucinated function output patterns
        final cleanText = _sanitizeModelOutput(fullText.toString()).trim();
        // If after sanitizing nothing remains, yield a fallback
        if (cleanText.isEmpty) {
          yield 'Acción completada.';
        }
      }

      // Save sanitized output to history
      final cleanAssistantText = _sanitizeModelOutput(fullText.toString()).trim();
      final contentToSave = cleanAssistantText.isNotEmpty ? cleanAssistantText : 'Acción completada.';
      _history.add(<String, String>{'role': 'user', 'content': originalPrompt});
      _history.add(<String, String>{
        'role': 'assistant',
        'content': _compactHistoryText(contentToSave),
      });
      _trimHistory();
    } finally {
      client.close();
    }
  }

  // ─── Tool Implementation Functions ───

  /// Compacts assistant text before storing in conversational history to prevent
  /// excessive token accumulation across turns while retaining key clinical facts.
  static String _compactHistoryText(String text) {
    final clean = text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    // Preserve full content if within reasonable token budget (~180 tokens = 750 chars)
    if (clean.length <= 750) {
      return clean;
    }
    // Cap very long outputs in history so turns don't balloon input token costs
    return '${clean.substring(0, 750).trim()}...';
  }

  /// Strips hallucinated function call patterns from model text output.
  /// Handles: JSON {"function": "..."}, XML function tags, and similar artifacts.
  static String _sanitizeModelOutput(String text) {
    // Remove JSON-style function calls: {"function": "name", ...} or {"function":"name"}
    // This catches single-line and multi-line JSON function blobs
    var clean = text.replaceAll(
      RegExp(r'\{[^{}]*"function"[^{}]*\}', multiLine: true),
      '',
    );

    // Remove XML-style function tags: <function=name> or <function>...</function>
    clean = clean.replaceAll(RegExp(r'</?function[^>]*>', caseSensitive: false), '');

    // Remove leftover tool call markers that some models emit
    clean = clean.replaceAll(RegExp(r'<\|[^|]*\|>', caseSensitive: false), '');

    // Remove <think>...</think> reasoning blocks that reasoning models may emit
    clean = clean.replaceAll(RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false), '');

    // Clean up multiple consecutive blank lines left behind by removed blocks
    clean = clean.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return clean;
  }


  String _getScheduledMedications(List<Tratamiento> treatments, DateTime date) {
    if (treatments.isEmpty) {
      return 'No hay tratamientos activos registrados.';
    }

    final dateStart = DateTime(date.year, date.month, date.day);
    final now = DateTime.now();
    final lines = <String>[];

    for (final t in treatments) {
      final dayDoses = calculateDayDoses(t, dateStart, now: now);
      if (dayDoses.isEmpty) continue;

      final doses = <String>[];
      for (final item in dayDoses) {
        final doseTime = item['time'] as DateTime;
        final status = item['status'] as DoseStatus;
        final isRecorded = item['isRecorded'] as bool? ?? false;
        final isProgramada = item['isProgramada'] as bool? ?? false;

        final timeStr =
            '${doseTime.hour.toString().padLeft(2, '0')}:${doseTime.minute.toString().padLeft(2, '0')}';

        final String statusStr;
        if (isRecorded) {
          statusStr = status.displayName.toLowerCase();
        } else if (isProgramada) {
          statusStr = 'programada';
        } else {
          statusStr = 'pendiente';
        }

        doses.add('  - $timeStr: $statusStr');
      }

      if (doses.isNotEmpty) {
        lines.add('${t.nombreMedicamento} (${t.presentacion}, ${t.dosisPorToma} por toma c/${t.intervaloDosis.inHours}h):');
        lines.addAll(doses);
      }
    }

    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    if (lines.isEmpty) {
      return 'No hay dosis programadas para $dateStr.';
    }

    return 'Medicamentos programados para $dateStr:\n${lines.join('\n')}';
  }

  String _getActiveTreatmentsSummary(List<Tratamiento> treatments) {
    if (treatments.isEmpty) {
      return 'No active treatments.';
    }

    final now = DateTime.now();
    final todayDay = DateTime(now.year, now.month, now.day);

    final lines = treatments.map((t) {
      final startStr = '${t.fechaInicioTratamiento.year}-${t.fechaInicioTratamiento.month.toString().padLeft(2, '0')}-${t.fechaInicioTratamiento.day.toString().padLeft(2, '0')}';
      final endStr = '${t.fechaFinTratamiento.year}-${t.fechaFinTratamiento.month.toString().padLeft(2, '0')}-${t.fechaFinTratamiento.day.toString().padLeft(2, '0')}';
      final endDay = DateTime(t.fechaFinTratamiento.year, t.fechaFinTratamiento.month, t.fechaFinTratamiento.day);
      final daysDiff = endDay.difference(todayDay).inDays;
      final isIndefinite = t.duracion.toLowerCase().contains('indefinid') || t.duracion == '0';

      final durationInfo = isIndefinite
          ? 'continuous / indefinite (no end date)'
          : (daysDiff == 0
              ? 'ends TODAY ($endStr)'
              : (daysDiff > 0
                  ? 'ends $endStr ($daysDiff days remaining, duration: ${t.duracion})'
                  : 'ended $endStr (${-daysDiff} days ago)'));

      return '- ${t.nombreMedicamento}: ${t.presentacion}, '
          '${t.dosisPorToma} per dose every ${t.intervaloDosis.inHours}h, '
          'starts $startStr, $durationInfo'
          '${t.notas.isNotEmpty ? ', notes: ${t.notas}' : ''}';
    }).toList();

    return 'Active treatments (${treatments.length}):\n${lines.join('\n')}';
  }

  String _getInventory(List<Tratamiento> treatments, String medName) {
    if (treatments.isEmpty) {
      return 'No active treatments.';
    }

    final filtered = medName.isEmpty
        ? treatments
        : treatments
            .where((t) => t.nombreMedicamento.toLowerCase().contains(medName.toLowerCase()))
            .toList();

    if (filtered.isEmpty) {
      return 'No medication found matching "$medName".';
    }

    final lines = filtered.map((t) {
      final remaining = t.cantidadActual;
      final total = t.cantidadTotalCaja;
      final isLow = t.hasStockBajo;
      return '- ${t.nombreMedicamento}: $remaining/$total remaining${isLow ? ' ⚠️ LOW STOCK' : ''}';
    }).toList();

    return 'Medication inventory:\n${lines.join('\n')}';
  }

  String _getMissedDoses(List<Tratamiento> treatments, int days) {
    if (treatments.isEmpty) {
      return 'No active treatments.';
    }

    final now = DateTime.now();
    final cutoff = now.subtract(Duration(days: days));
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    final missed = <String>[];

    for (final t in treatments) {
      t.doseStatus.forEach((key, status) {
        if (status == DoseStatus.omitida) {
          final doseTime = DateTime.tryParse(key);
          if (doseTime != null && doseTime.isAfter(cutoff) && !doseTime.isAfter(endOfToday)) {
            final dateStr = '${doseTime.year}-${doseTime.month.toString().padLeft(2, '0')}-${doseTime.day.toString().padLeft(2, '0')} ${doseTime.hour.toString().padLeft(2, '0')}:${doseTime.minute.toString().padLeft(2, '0')}';
            missed.add('- ${t.nombreMedicamento}: missed on $dateStr');
          }
        }
      });
    }

    if (missed.isEmpty) {
      return 'No missed doses in the last $days days. Great adherence!';
    }

    return 'Missed doses (last $days days):\n${missed.join('\n')}';
  }

  /// Extracts prescription data from a Base64 image using Groq's vision model.
  Future<Map<String, dynamic>?> analyzePrescriptionImage(String base64Image, String mimeType) async {
    final apiKey = await getEffectiveApiKey();
    if (apiKey.isEmpty) {
      throw StateError(
        'Falta la clave de Groq API. Configúrala en la app o ejecuta con --dart-define=GROQ_API_KEY=TU_CLAVE.',
      );
    }

    final messages = <Map<String, dynamic>>[
      <String, dynamic>{
        'role': 'system',
        'content': 'You are a precise medical prescription extractor. Extract the details of the prescription from the image and output them in a structured JSON format. Ensure all text properties are in Spanish. Output ONLY the raw JSON object, starting with { and ending with }.',
      },
      <String, dynamic>{
        'role': 'user',
        'content': <dynamic>[
          <String, dynamic>{
            'type': 'text',
            'text': 'Analyze this medical prescription image and return a JSON object with the following fields: '
                '"nombreMedicamento" (String, name of the drug/medication), '
                '"presentacion" (String, e.g., "pastillas", "jarabe", "cápsulas"), '
                '"duracion" (String, e.g., "7 días", "30 días", "uso continuo"), '
                '"intervaloDosis" (int, hours between doses, e.g., 8, 12, 24), '
                '"dosisPorToma" (int, number of units/pills per dose, e.g., 1, 2), '
                '"notas" (String, extra medical recommendations or instructions). '
                'CRITICAL: Return only the raw JSON. Do not include markdown code block formatting (like ```json) or any conversational text.',
          },
          <String, dynamic>{
            'type': 'image_url',
            'image_url': <String, String>{
              'url': 'data:$mimeType;base64,$base64Image',
            },
          },
        ],
      },
    ];

    // Direct query to Groq vision model with timeout and fallback handling
    final visionModels = [
      _visionModel,
    ];
    http.Response? lastResponse;
    Object? lastException;

    for (final model in visionModels) {
      try {
        final response = await http.post(
          Uri.parse(_baseUrl),
          headers: <String, String>{
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(<String, dynamic>{
            'model': model,
            'temperature': 0.1,
            'max_completion_tokens': 1024,
            'messages': messages,
          }),
        ).timeout(const Duration(seconds: 35));

        if (response.statusCode == 200) {
          lastResponse = response;
          break;
        }

        lastResponse = response;
        debugPrint('Vision model $model failed (${response.statusCode}): ${response.body}');

        // If 401 (auth error), don't keep trying models
        if (response.statusCode == 401) {
          break;
        }
      } catch (e) {
        lastException = e;
        debugPrint('Exception querying vision model $model: $e');
      }
    }

    if (lastResponse == null || lastResponse.statusCode != 200) {
      final errorBody = lastResponse?.body ?? '';
      final statusCode = lastResponse?.statusCode ?? 0;
      debugPrint('Groq Vision API error ($statusCode): $errorBody');

      String? apiErrorMessage;
      try {
        if (errorBody.isNotEmpty) {
          final errJson = jsonDecode(errorBody) as Map<String, dynamic>;
          if (errJson['error'] is Map && errJson['error']['message'] != null) {
            apiErrorMessage = errJson['error']['message'].toString();
          }
        }
      } catch (_) {}

      String errorMsg;
      if (statusCode == 401 || errorBody.contains('invalid_api_key')) {
        errorMsg = 'Error de autenticación (401): La clave de Groq API es inválida o expiró. Verifica tu clave en console.groq.com.';
      } else if (statusCode == 413 || errorBody.contains('too large') || errorBody.contains('request_entity_too_large')) {
        errorMsg = 'La imagen es demasiado pesada para el modelo de visión (413). Toma una foto más cercana o comprimida.';
      } else if (statusCode == 404 || errorBody.contains('model_not_found') || errorBody.contains('do not have access')) {
        errorMsg = 'El modelo de visión no está disponible en tu cuenta de Groq (Error 404)${apiErrorMessage != null ? ": $apiErrorMessage" : ""}.';
      } else if (statusCode == 429 || errorBody.contains('rate_limit')) {
        errorMsg = 'Se alcanzó el límite de peticiones de Groq (Error 429). Espera unos segundos e intenta nuevamente.';
      } else if (lastException != null && lastResponse == null) {
        errorMsg = 'No se pudo conectar con el servicio de visión. Comprueba tu conexión a internet e inténtalo de nuevo.';
      } else if (apiErrorMessage != null && apiErrorMessage.isNotEmpty) {
        errorMsg = 'Error al analizar la imagen ($statusCode): $apiErrorMessage';
      } else {
        errorMsg = 'No se pudo analizar la imagen en este momento. Intenta de nuevo o ingresa los datos manualmente.';
      }
      throw StateError(errorMsg);
    }

    final decoded = jsonDecode(lastResponse.body) as Map<String, dynamic>;
    final choices = decoded['choices'] as List<dynamic>;
    if (choices.isEmpty) return null;
    final messageData = choices.first['message'] as Map<String, dynamic>;
    final rawContent = messageData['content'] as String;

    // Strip <think>...</think> reasoning blocks (Qwen and other reasoning models)
    // Strip markdown code fences (```json ... ```)
    // Then extract the first { ... } JSON object
    String jsonStr = rawContent
        .replaceAll(RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false), '')
        .replaceAll(RegExp(r'```json\s*'), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();

    // If still not starting with {, find the first { character
    final braceStart = jsonStr.indexOf('{');
    final braceEnd = jsonStr.lastIndexOf('}');
    if (braceStart != -1 && braceEnd != -1 && braceEnd > braceStart) {
      jsonStr = jsonStr.substring(braceStart, braceEnd + 1);
    }

    try {
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Failed to parse prescription JSON: $jsonStr, error: $e');
      throw const FormatException('No se pudo interpretar el formato de los datos de la receta. Intenta tomar una foto más nítida.');
    }
  }

  /// Evaluates potential drug-drug interactions between a new medication and active treatments.
  /// Returns a map containing:
  /// - `hasInteraction`: bool
  /// - `severity`: 'mild' | 'moderate' | 'severe'
  /// - `warningMessage`: String (Empathetic warning in Spanish advising doctor consultation)
  Future<Map<String, dynamic>> checkDrugInteractions({
    required String newDrugName,
    required List<Tratamiento> activeTreatments,
  }) async {
    final cleanNewName = newDrugName.trim();
    if (cleanNewName.isEmpty || activeTreatments.isEmpty) {
      return {'hasInteraction': false};
    }

    final otherTreatments = activeTreatments
        .where((t) => t.nombreMedicamento.trim().toLowerCase() != cleanNewName.toLowerCase())
        .toList();

    if (otherTreatments.isEmpty) {
      return {'hasInteraction': false};
    }

    final activeMedsList = otherTreatments
        .map((t) => '${t.nombreMedicamento} (${t.presentacion})')
        .join(', ');

    final apiKey = await getEffectiveApiKey();
    if (apiKey.isEmpty) {
      return {'hasInteraction': false};
    }

    try {
      var response = await http.post(
        Uri.parse(_baseUrl),
        headers: <String, String>{
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{
          'model': _model,
          'response_format': {'type': 'json_object'},
          'max_completion_tokens': 1024,
          'temperature': 0.1,
          'messages': <Map<String, dynamic>>[
            <String, String>{
              'role': 'system',
              'content':
                  'Eres un experto en farmacología clínica. Analiza si existen interacciones medicamentosas reales y clínicamente relevantes entre el nuevo fármaco y los tratamientos activos. '
                  'REGLA CRÍTICA: Si alguno de los fármacos no existe, es inventado, es desconocido, o NO hay interacción comprobada, DEBES retornar estrictamente {"hasInteraction": false, "severity": "", "warningMessage": ""}. '
                  'Si SÍ hay interacción comprobada médica y científicamente, retorna {"hasInteraction": true, "severity": "mild"|"moderate"|"severe", "warningMessage": "Advertencia breve y empática explicando el posible efecto."}. '
                  'IMPORTANTE: Responde ÚNICAMENTE con el objeto JSON. No inventes interacciones ni asumas similitudes.',
            },
            <String, String>{
              'role': 'user',
              'content':
                  'Nuevo fármaco a agregar: "$cleanNewName".\n'
                  'Tratamientos activos del paciente: $activeMedsList.',
            },
          ],
        }),
      );

      if (response.statusCode != 200) {
        response = await http.post(
          Uri.parse(_baseUrl),
          headers: <String, String>{
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(<String, dynamic>{
            'model': _model,
            'max_completion_tokens': 1024,
            'temperature': 0.1,
            'messages': <Map<String, dynamic>>[
              <String, String>{
                'role': 'system',
                'content':
                    'Eres un experto en farmacología clínica. Analiza si existen interacciones medicamentosas reales y clínicamente relevantes entre el nuevo fármaco y los tratamientos activos. '
                    'REGLA CRÍTICA: Si alguno de los fármacos no existe, es inventado, es desconocido, o NO hay interacción comprobada, DEBES retornar estrictamente {"hasInteraction": false, "severity": "", "warningMessage": ""}. '
                    'Si SÍ hay interacción comprobada médica y científicamente, retorna {"hasInteraction": true, "severity": "mild"|"moderate"|"severe", "warningMessage": "Advertencia breve y empática explicando el posible efecto."}. '
                    'IMPORTANTE: Responde ÚNICAMENTE con el objeto JSON. No inventes interacciones ni asumas similitudes.',
              },
              <String, String>{
                'role': 'user',
                'content':
                    'Nuevo fármaco a agregar: "$cleanNewName".\n'
                    'Tratamientos activos del paciente: $activeMedsList.',
              },
            ],
          }),
        );
      }

      if (response.statusCode != 200) {
        return {'hasInteraction': false};
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = decoded['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) return {'hasInteraction': false};
      final messageData = choices.first['message'] as Map<String, dynamic>?;
      final content = messageData?['content'] as String?;
      if (content == null || content.isEmpty) return {'hasInteraction': false};

      String cleanContent = content
          .replaceAll(RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false), '')
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();

      final bStart = cleanContent.indexOf('{');
      final bEnd = cleanContent.lastIndexOf('}');
      if (bStart != -1 && bEnd != -1 && bEnd > bStart) {
        cleanContent = cleanContent.substring(bStart, bEnd + 1);
      }

      final parsed = jsonDecode(cleanContent) as Map<String, dynamic>;
      return <String, dynamic>{
        'hasInteraction': parsed['hasInteraction'] == true,
        'severity': parsed['severity'] ?? 'moderate',
        'warningMessage': parsed['warningMessage']?.toString() ?? '',
      };
    } catch (e) {
      debugPrint('Error checking drug interactions: $e');
      return {'hasInteraction': false};
    }
  }

  /// Keeps context short to reduce token usage on free plans.
  void _trimHistory() {
    if (_history.length <= _maxHistoryMessages) {
      return;
    }

    _history.removeRange(0, _history.length - _maxHistoryMessages);
    // Ensure history starts on a 'user' turn for optimal model coherence
    while (_history.isNotEmpty && _history.first['role'] != 'user') {
      _history.removeAt(0);
    }
  }

  /// Clears the in-memory conversation history.
  /// Call this when starting a new chat or switching chat sessions
  /// to prevent stale context from bleeding between conversations.
  void clearHistory() {
    _history.clear();
  }

  /// Synchronizes the internal history with a provided history state.
  /// Useful when rewriting chat history (e.g., editing past messages).
  void syncHistory(List<Map<String, dynamic>> newHistory) {
    _history.clear();
    _history.addAll(newHistory);
    _trimHistory();
  }

  /// Generates 2-3 short, personalized tips based on active treatments, adherence, and active profile/mode.
  Future<List<Map<String, String>>> generateTreatmentTips({
    required List<Tratamiento> treatments,
    required int pendingCount,
    required int takenCount,
    required double adherenceRate,
    bool isAnimalMode = false,
    CaregiverModeType? caregiverModeType,
    CaregiverProfile? profile,
    String language = 'es',
  }) async {
    // Filtrar estrictamente solo tratamientos activos (excluyendo historial médico finalizado)
    final activeTreatments = treatments.where((t) => t.isActivo).toList();
    final effectiveTreatments = activeTreatments.isNotEmpty
        ? activeTreatments
        : treatments.where((t) => !t.isFinalizado).toList();

    final isAnimal = isAnimalMode || (profile != null && profile.isAnimal);

    if (effectiveTreatments.isEmpty) {
      if (isAnimal) {
        if (language == 'en') {
          return [
            {
              'title': '🐾 Pet Up to Date',
              'content': 'Add your pet\'s medications with the "+" button to receive reminders and veterinary tips.',
              'isAi': 'false',
            },
            {
              'title': '🐾 Animal Wellness',
              'content': 'Keeping their doses on schedule prevents relapses and ensures a stress-free recovery.',
              'isAi': 'false',
            },
          ];
        } else if (language == 'pt') {
          return [
            {
              'title': '🐾 Pet em Dia',
              'content': 'Adicione os medicamentos do seu pet com o botão "+" para receber lembretes e dicas veterinárias.',
              'isAi': 'false',
            },
            {
              'title': '🐾 Bem-estar Animal',
              'content': 'Manter as doses no horário evita recaídas e garante uma recuperação tranquila.',
              'isAi': 'false',
            },
          ];
        }
        return [
          {
            'title': '🐾 Mascota al Día',
            'content': 'Agrega los medicamentos de tu mascota con el botón "+" para recibir recordatorios y tips veterinarios.',
            'isAi': 'false',
          },
          {
            'title': '🐾 Bienestar Animal',
            'content': 'Mantener sus dosis a tiempo previene recaídas y asegura una recuperación sin estrés.',
            'isAi': 'false',
          },
        ];
      } else if (caregiverModeType == CaregiverModeType.clinico) {
        if (language == 'en') {
          return [
            {
              'title': '🩺 Clinical Record',
              'content': 'Add the patient\'s prescription with the "+" button to begin dosing and traceability.',
              'isAi': 'false',
            },
            {
              'title': '🩺 Clinical Safety',
              'content': 'MediTime assists you in following the 5 rights and safe medication administration.',
              'isAi': 'false',
            },
          ];
        } else if (language == 'pt') {
          return [
            {
              'title': '🩺 Registro Clínico',
              'content': 'Adicione a prescrição do paciente com o botão "+" para iniciar a dosagem e rastreabilidade.',
              'isAi': 'false',
            },
            {
              'title': '🩺 Segurança Clínica',
              'content': 'O MediTime auxilia no cumprimento dos 5 certos e na administração segura.',
              'isAi': 'false',
            },
          ];
        }
        return [
          {
            'title': '🩺 Registro Clínico',
            'content': 'Añade la prescripción del paciente con el botón "+" para iniciar la dosificación y trazabilidad.',
            'isAi': 'false',
          },
          {
            'title': '🩺 Seguridad Clínica',
            'content': 'MediTime te asiste en el cumplimiento de los 5 correctos y la administración segura.',
            'isAi': 'false',
          },
        ];
      } else if (caregiverModeType == CaregiverModeType.familiar) {
        if (language == 'en') {
          return [
            {
              'title': '👨‍👩‍👧 Family Care',
              'content': 'Add your family member\'s medications with the "+" button to organize their daily schedule with care.',
              'isAi': 'false',
            },
            {
              'title': '👨‍👩‍👧 Peace of Mind',
              'content': 'Receive timely alerts and practical advice to accompany your loved one with every dose.',
              'isAi': 'false',
            },
          ];
        } else if (language == 'pt') {
          return [
            {
              'title': '👨‍👩‍👧 Cuidado Familiar',
              'content': 'Adicione os medicamentos do seu familiar com o botão "+" para organizar o calendário com carinho.',
              'isAi': 'false',
            },
            {
              'title': '👨‍👩‍👧 Tranquilidade em Casa',
              'content': 'Receba alertas pontuais e dicas práticas para acompanhar seu familiar em cada dose.',
              'isAi': 'false',
            },
          ];
        }
        return [
          {
            'title': '👨‍👩‍👧 Cuidado Familiar',
            'content': 'Agrega los medicamentos de tu familiar con el botón "+" para organizar su calendario diario con amor.',
            'isAi': 'false',
          },
          {
            'title': '👨‍👩‍👧 Tranquilidad en Casa',
            'content': 'Recibe alertas puntuales y consejos prácticos para acompañar a tu familiar en cada toma.',
            'isAi': 'false',
          },
        ];
      }

      if (language == 'en') {
        return [
          {
            'title': 'Start your Record',
            'content': 'Add your medications with the "+" button to receive reminders and AI tips.',
            'isAi': 'false',
          },
          {
            'title': 'Wellness and Health',
            'content': 'Keeping your treatments on schedule prevents complications and ensures your recovery.',
            'isAi': 'false',
          },
        ];
      } else if (language == 'pt') {
        return [
          {
            'title': 'Comece seu Registro',
            'content': 'Adicione seus medicamentos com o botão "+" para receber lembretes e dicas com IA.',
            'isAi': 'false',
          },
          {
            'title': 'Bem-estar e Saúde',
            'content': 'Manter seus tratamentos em dia evita complicações e garante sua recuperação.',
            'isAi': 'false',
          },
        ];
      }

      return [
        {
          'title': 'Comienza tu Registro',
          'content': 'Agrega tus medicamentos con el botón "+" para recibir recordatorios y tips con IA.',
          'isAi': 'false',
        },
        {
          'title': 'Bienestar y Salud',
          'content': 'Mantener tus tratamientos al día previene complicaciones y asegura tu recuperación.',
          'isAi': 'false',
        },
      ];
    }

    final fallbackTips = getFallbackTips(
      treatments: effectiveTreatments,
      pendingCount: pendingCount,
      takenCount: takenCount,
      adherenceRate: adherenceRate,
      isAnimalMode: isAnimalMode,
      caregiverModeType: caregiverModeType,
      profile: profile,
      language: language,
    );

    final apiKey = await getEffectiveApiKey();
    if (apiKey.isEmpty) {
      return fallbackTips;
    }

    try {
      final activeMeds = effectiveTreatments.take(4).toList();
      final medsSummary = activeMeds.map((t) {
        final hours = t.intervaloDosis.inHours;
        final interval = hours > 0 ? '${hours}h' : '${t.intervaloDosis.inMinutes}min';
        return '- ${t.nombreMedicamento} (${t.presentacion}, c/$interval, dosis: ${t.dosisPorToma})';
      }).join('\n');

      String modeContext;
      if (isAnimal) {
        final petName = profile?.name.isNotEmpty == true ? profile!.name : 'la mascota';
        final species = profile?.species?.isNotEmpty == true ? profile!.species! : 'mascota';
        final breed = profile?.breed?.isNotEmpty == true ? ', ${profile!.breed}' : '';
        final weight = profile?.weight?.isNotEmpty == true ? ', ${profile!.weight}' : '';
        modeContext = 'VETERINARIO (Mascota: $petName, $species$breed$weight). '
            'Consejos veterinarios: toma con premio/comida permitida, jeringa lateral para líquidos, refuerzo positivo. NUNCA fármacos humanos (paracetamol/ibuprofeno).';
      } else if (caregiverModeType == CaregiverModeType.clinico) {
        final patientName = profile?.name.isNotEmpty == true ? profile!.name : 'el paciente';
        final room = profile?.roomNumber?.isNotEmpty == true ? ', Hab: ${profile!.roomNumber}' : '';
        modeContext = 'CUIDADOR CLÍNICO ($patientName$room). Aplicar los 5 correctos, registro clínico y vigilancia de efectos.';
      } else if (caregiverModeType == CaregiverModeType.familiar) {
        final famName = profile?.name.isNotEmpty == true ? profile!.name : 'el familiar';
        modeContext = 'CUIDADOR FAMILIAR ($famName). Rutinas con cariño, deglución con agua y observación.';
      } else {
        modeContext = 'MODO PERSONAL. Gestión diaria de medicación y adherencia.';
      }

      final String prompt;
      final String systemInstruction;
      if (language == 'en') {
        systemInstruction = 'Expert physician & pharmacologist delivering concise micro-tips in JSON.';
        prompt = '''
Generate 2-3 brief practical tips in English.
CONTEXT: $modeContext
TREATMENTS:
$medsSummary
ADHERENCE: ${adherenceRate.toStringAsFixed(0)}% ($takenCount taken, $pendingCount pending).
RULES:
1. Specific to active meds or mode.
2. 'title': 3-5 words max. 'content': 70-130 chars.
3. Return ONLY JSON: {"tips": [{"title": "...", "content": "..."}]}
''';
      } else if (language == 'pt') {
        systemInstruction = 'Médico especialista gerando microdicas concisas em formato JSON.';
        prompt = '''
Gere 2-3 dicas práticas breves em português.
CONTEXTO: $modeContext
TRATAMENTOS:
$medsSummary
ADESÃO: ${adherenceRate.toStringAsFixed(0)}% ($takenCount tomadas, $pendingCount pendentes).
REGRAS:
1. Específica para medicamentos ou modo.
2. 'title': máx 3-5 palavras. 'content': 70-130 caracteres.
3. Responda APENAS JSON: {"tips": [{"title": "...", "content": "..."}]}
''';
      } else {
        systemInstruction = 'Médico y farmacólogo experto que entrega micro-consejos de salud concisos en formato JSON.';
        prompt = '''
Genera 2 o 3 consejos muy breves y prácticos en español.
CONTEXTO: $modeContext
TRATAMIENTOS:
$medsSummary
ADHERENCIA: ${adherenceRate.toStringAsFixed(0)}% ($takenCount tomadas, $pendingCount pendientes).
REGLAS:
1. Al menos un tip específico a los fármacos listados o al modo activo.
2. 'title': Máx 3-5 palabras. 'content': Entre 70 y 130 caracteres.
3. Responde ÚNICAMENTE en JSON: {"tips": [{"title": "...", "content": "..."}]}
''';
      }

      http.Response response = await http.post(
        Uri.parse(_baseUrl),
        headers: <String, String>{
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{
          'model': _model,
          'response_format': {'type': 'json_object'},
          'max_completion_tokens': 1024,
          'temperature': 0.2,
          'messages': <Map<String, dynamic>>[
            {
              'role': 'system',
              'content': systemInstruction,
            },
            {
              'role': 'user',
              'content': prompt,
            },
          ],
        }),
      ).timeout(const Duration(seconds: 8));

      // Si falla la validación estricta de JSON (código 400 json_validate_failed), reintentar sin forzar response_format
      if (response.statusCode != 200) {
        response = await http.post(
          Uri.parse(_baseUrl),
          headers: <String, String>{
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(<String, dynamic>{
            'model': _model,
            'max_completion_tokens': 1024,
            'temperature': 0.2,
            'messages': <Map<String, dynamic>>[
              {
                'role': 'system',
                'content': systemInstruction,
              },
              {
                'role': 'user',
                'content': prompt,
              },
            ],
          }),
        ).timeout(const Duration(seconds: 8));
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final contentStr = data['choices']?[0]?['message']?['content'] as String?;
        if (contentStr != null && contentStr.trim().isNotEmpty) {
          String cleaned = contentStr
              .replaceAll(RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false), '')
              .replaceAll(RegExp(r'```json\s*'), '')
              .replaceAll(RegExp(r'```\s*'), '')
              .trim();

          final bStart = cleaned.indexOf('{');
          final bEnd = cleaned.lastIndexOf('}');
          if (bStart != -1 && bEnd != -1 && bEnd > bStart) {
            cleaned = cleaned.substring(bStart, bEnd + 1);
          }

          final parsed = jsonDecode(cleaned);
          if (parsed is Map && parsed['tips'] is List) {
            final List<Map<String, String>> tips = [];
            for (var item in parsed['tips']) {
              if (item is Map && item['title'] != null && item['content'] != null) {
                tips.add({
                  'title': item['title'].toString().trim(),
                  'content': item['content'].toString().trim(),
                  'isAi': 'true',
                });
              }
            }
            if (tips.isNotEmpty) {
              return tips;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error generating treatment tips via AI: $e');
    }

    return fallbackTips;
  }

  List<Map<String, String>> getFallbackTips({
    required List<Tratamiento> treatments,
    required int pendingCount,
    required int takenCount,
    required double adherenceRate,
    bool isAnimalMode = false,
    CaregiverModeType? caregiverModeType,
    CaregiverProfile? profile,
    String language = 'es',
  }) {
    // Filtrar estrictamente solo tratamientos activos (excluyendo historial médico finalizado)
    final activeTreatments = treatments.where((t) => t.isActivo).toList();
    final effectiveTreatments = activeTreatments.isNotEmpty
        ? activeTreatments
        : treatments.where((t) => !t.isFinalizado).toList();

    final List<Map<String, String>> medTips = [];
    final isAnimal = isAnimalMode || (profile != null && profile.isAnimal);
    final petName = profile?.name.isNotEmpty == true
        ? profile!.name
        : (language == 'en' ? 'your pet' : (language == 'pt' ? 'seu pet' : 'tu mascota'));
    final famName = profile?.name.isNotEmpty == true
        ? profile!.name
        : (language == 'en' ? 'your family member' : (language == 'pt' ? 'seu familiar' : 'tu familiar'));

    // ─── 1. Consejos Específicos por Medicamento ───
    for (var t in effectiveTreatments) {
      final name = t.nombreMedicamento.toLowerCase();
      final pres = t.presentacion.toLowerCase();

      // Protectores gástricos
      if (name.contains('omeprazol') || name.contains('pantoprazol') || name.contains('esomeprazol') || name.contains('lansoprazol')) {
        String title;
        String content;
        if (isAnimal) {
          title = language == 'en' ? '🐾 Gastric protector' : (language == 'pt' ? '🐾 Protetor gástrico' : '🐾 Protector gástrico');
          content = language == 'en'
              ? 'Administer the protector to $petName about 30 min before meals to protect their stomach.'
              : (language == 'pt'
                  ? 'Administre o protetor a $petName cerca de 30 min antes da ração para cuidar do estômago.'
                  : 'Administra el protector a $petName unos 30 min antes de su ración para cuidar su estómago.');
        } else {
          title = language == 'en' ? 'Take on empty stomach' : (language == 'pt' ? 'Tome em jejum' : 'Toma en ayunas');
          content = language == 'en'
              ? 'Take ${t.nombreMedicamento} about 30 min before breakfast for maximum stomach protection.'
              : (language == 'pt'
                  ? 'Tome o ${t.nombreMedicamento} cerca de 30 min antes do café da manhã para máxima proteção gástrica.'
                  : 'Toma el ${t.nombreMedicamento} unos 30 min antes del desayuno para máxima protección gástrica.');
        }
        medTips.add({'title': title, 'content': content});
      }
      // AINEs y analgésicos
      else if (name.contains('ibuprofeno') || name.contains('naproxeno') || name.contains('diclofenaco') || name.contains('ketorolaco') || name.contains('celecoxib') || name.contains('meloxicam')) {
        String title;
        String content;
        if (isAnimal) {
          title = language == 'en' ? '🐾 Caution with NSAIDs' : (language == 'pt' ? '🐾 Cuidado com AINEs' : '🐾 Cuidado con AINEs');
          content = language == 'en'
              ? 'Only use NSAIDs prescribed by your veterinarian and always give with food.'
              : (language == 'pt'
                  ? 'Use apenas anti-inflamatórios receitados pelo veterinário e sempre com alimento.'
                  : 'Usa solo antiinflamatorios recetados por el veterinario y siempre junto a su comida.');
        } else {
          title = language == 'en' ? 'Take with food' : (language == 'pt' ? 'Acompanhe com comida' : 'Acompaña con comida');
          content = language == 'en'
              ? 'Take ${t.nombreMedicamento} with food or milk to protect your stomach lining.'
              : (language == 'pt'
                  ? 'Tome o ${t.nombreMedicamento} com alimentos ou leite para proteger a mucosa do estômago.'
                  : 'Toma el ${t.nombreMedicamento} con alimentos o leche para proteger la mucosa de tu estómago.');
        }
        medTips.add({'title': title, 'content': content});
      }
      // Paracetamol / Acetaminofén
      else if (name.contains('paracetamol') || name.contains('acetaminofen') || name.contains('acetaminofén') || name.contains('tylenol')) {
        if (isAnimal) {
          final title = language == 'en' ? '🐾 Toxicity alert!' : (language == 'pt' ? '🐾 Alerta de toxicidade!' : '🐾 ¡Alerta toxicidad!');
          final content = language == 'en'
              ? 'NEVER give paracetamol or acetaminophen to $petName; it is highly toxic and fatal to animals.'
              : (language == 'pt'
                  ? 'NUNCA dê paracetamol ou acetaminofeno a $petName; é altamente tóxico e mortal em animais.'
                  : 'NUNCA des paracetamol o acetaminofén a $petName; es altamente tóxico y mortal en animales.');
          medTips.add({'title': title, 'content': content});
        } else {
          final title = language == 'en' ? 'Safe interval' : (language == 'pt' ? 'Intervalo seguro' : 'Intervalo seguro');
          final content = language == 'en'
              ? 'Follow schedules for ${t.nombreMedicamento} without exceeding the maximum daily recommended dose.'
              : (language == 'pt'
                  ? 'Respeite os horários de ${t.nombreMedicamento} sem exceder a dose máxima diária recomendada.'
                  : 'Respeta los horarios de ${t.nombreMedicamento} sin exceder la dosis máxima diaria recomendada.');
          medTips.add({'title': title, 'content': content});
        }
      }
      // Antibióticos
      else if (name.contains('amoxicilina') || name.contains('azitromicina') || name.contains('ciprofloxacino') || name.contains('cefalexina') || name.contains('doxiciclina') || name.contains('claritromicina')) {
        String title;
        String content;
        if (isAnimal) {
          title = language == 'en' ? '🐾 Full course' : (language == 'pt' ? '🐾 Ciclo completo' : '🐾 Ciclo completo');
          content = language == 'en'
              ? 'Complete all antibiotic days prescribed for $petName even if they are active and seem better.'
              : (language == 'pt'
                  ? 'Complete todos os dias de antibiótico prescritos para $petName mesmo que já brinque e pareça bem.'
                  : 'Completa todos los días de antibiótico recetados a $petName aunque ya juegue y se vea mejor.');
        } else {
          title = language == 'en' ? 'Complete antibiotic' : (language == 'pt' ? 'Antibiótico regular' : 'Antibiótico regular');
          content = language == 'en'
              ? 'Complete the full duration of antibiotic ${t.nombreMedicamento} even if you feel better.'
              : (language == 'pt'
                  ? 'Complete a duração total do antibiótico ${t.nombreMedicamento} mesmo se já se sentir melhor.'
                  : 'Completa la duración total del antibiótico ${t.nombreMedicamento} aunque te sientas mejor.');
        }
        medTips.add({'title': title, 'content': content});
      }
      // Cardiovasculares / Antihipertensivos
      else if (name.contains('losartan') || name.contains('losartán') || name.contains('enalapril') || name.contains('amlodipino') || name.contains('atenolol') || name.contains('carvedilol') || name.contains('valsartan')) {
        String title;
        String content;
        if (caregiverModeType == CaregiverModeType.clinico) {
          title = language == 'en' ? '🩺 BP Check' : (language == 'pt' ? '🩺 Controle de PA' : '🩺 Control de TA');
          content = language == 'en'
              ? 'Evaluate blood pressure and pulse before administering ${t.nombreMedicamento}.'
              : (language == 'pt'
                  ? 'Avalie pressão arterial e pulso antes de administrar ${t.nombreMedicamento}.'
                  : 'Evalúa tensión arterial y pulso antes de suministrar ${t.nombreMedicamento}.');
        } else {
          title = language == 'en' ? 'Blood pressure' : (language == 'pt' ? 'Pressão arterial' : 'Presión arterial');
          content = language == 'en'
              ? 'Take ${t.nombreMedicamento} at the same time each day to maintain stable cardiovascular control.'
              : (language == 'pt'
                  ? 'Tome ${t.nombreMedicamento} no mesmo horário todos os dias para manter o controle cardiovascular estável.'
                  : 'Toma ${t.nombreMedicamento} a la misma hora cada día para mantener un control cardiovascular estable.');
        }
        medTips.add({'title': title, 'content': content});
      }
      // Antidiabéticos orales
      else if (name.contains('metformina') || name.contains('glibenclamida') || name.contains('gliclazida')) {
        final title = language == 'en' ? 'Glucose and food' : (language == 'pt' ? 'Glicose e refeição' : 'Glucosa y comida');
        final content = language == 'en'
            ? 'Take ${t.nombreMedicamento} during or immediately after main meals.'
            : (language == 'pt'
                ? 'Tome a ${t.nombreMedicamento} durante ou logo após as principais refeições.'
                : 'Toma la ${t.nombreMedicamento} durante o inmediatamente después de las comidas principales.');
        medTips.add({'title': title, 'content': content});
      }
      // Insulina
      else if (name.contains('insulina') || name.contains('glargina') || name.contains('lantus') || name.contains('lispro')) {
        String title;
        String content;
        if (caregiverModeType == CaregiverModeType.clinico) {
          title = language == 'en' ? '🩺 Pre-dose glucose' : (language == 'pt' ? '🩺 Glicemia prévia' : '🩺 Glucemia previa');
          content = language == 'en'
              ? 'Check capillary blood glucose before administering the indicated dose of insulin.'
              : (language == 'pt'
                  ? 'Verifique a glicemia capilar antes de aplicar a dose prescrita de insulina.'
                  : 'Verifica la glucemia capilar antes de aplicar la dosis indicada de insulina.');
        } else {
          title = language == 'en' ? 'Insulin care' : (language == 'pt' ? 'Cuidados com insulina' : 'Cuidado de insulina');
          content = language == 'en'
              ? 'Keep in-use insulin at room temperature and rotate injection sites.'
              : (language == 'pt'
                  ? 'Mantenha a insulina em uso em temperatura ambiente e alterne os locais de aplicação.'
                  : 'Mantén la insulina en uso a temperatura ambiente y alterna los sitios de aplicación.');
        }
        medTips.add({'title': title, 'content': content});
      }
      // Levotiroxina
      else if (name.contains('levotiroxina') || name.contains('eutirox')) {
        final title = language == 'en' ? 'Strict fasting' : (language == 'pt' ? 'Jejum estrito' : 'Ayuno estricto');
        final content = language == 'en'
            ? 'Take levothyroxine with water only upon waking, and wait 30-60 min before breakfast.'
            : (language == 'pt'
                ? 'Tome a levotiroxina apenas com água ao acordar e aguarde 30-60 min antes do café.'
                : 'Toma la levotiroxina solo con agua al despertar y espera 30-60 min antes de desayunar.');
        medTips.add({'title': title, 'content': content});
      }
      // Inhaladores
      else if (pres.contains('inhalador') || name.contains('salbutamol') || name.contains('budesonida') || name.contains('fluticasona')) {
        final title = language == 'en' ? 'Rinse mouth' : (language == 'pt' ? 'Enxágue bucal' : 'Enjuague bucal');
        final content = language == 'en'
            ? 'After using ${t.nombreMedicamento} inhaler, rinse your mouth with water to prevent thrush.'
            : (language == 'pt'
                ? 'Após usar o inalador de ${t.nombreMedicamento}, enxágue a boca com água para evitar sapinho.'
                : 'Tras usar el inhalador de ${t.nombreMedicamento}, enjuágate la boca con agua para evitar aftas.');
        medTips.add({'title': title, 'content': content});
      }
      // Corticoides
      else if (name.contains('prednisona') || name.contains('prednisolona') || name.contains('dexametasona')) {
        String title;
        String content;
        if (isAnimal) {
          title = language == 'en' ? '🐾 With food' : (language == 'pt' ? '🐾 Com alimento' : '🐾 Con alimento');
          content = language == 'en'
              ? 'Give the corticosteroid to $petName always with their food to avoid stomach irritation.'
              : (language == 'pt'
                  ? 'Dê o corticoide a $petName sempre com a ração para não irritar o estômago.'
                  : 'Da el corticoide a $petName siempre con su comida para no irritar su estómago.');
        } else {
          title = language == 'en' ? 'Morning dose' : (language == 'pt' ? 'Dose matinal' : 'Toma matutina');
          content = language == 'en'
              ? 'Take ${t.nombreMedicamento} in the morning with breakfast, respecting your body\'s hormone rhythm.'
              : (language == 'pt'
                  ? 'Tome ${t.nombreMedicamento} pela manhã com o café respeitando o ciclo hormonal.'
                  : 'Toma ${t.nombreMedicamento} en la mañana con el desayuno respetando el ciclo hormonal.');
        }
        medTips.add({'title': title, 'content': content});
      }
      // Gotas oftálmicas
      else if (pres.contains('gota') || pres.contains('colirio') || name.contains('gotas')) {
        final title = language == 'en' ? 'Drop hygiene' : (language == 'pt' ? 'Higiene nas gotas' : 'Higiene en gotas');
        final content = language == 'en'
            ? 'Wash your hands before applying drops and avoid touching the dropper tip to any surface.'
            : (language == 'pt'
                ? 'Lave as mãos antes de aplicar as gotas e evite encostar o bico dosador em qualquer superfície.'
                : 'Lava tus manos antes de aplicar las gotas y evita que la punta del gotero toque superficies.');
        medTips.add({'title': title, 'content': content});
      }
      // Jarabes y suspensiones
      else if (pres.contains('jarabe') || pres.contains('suspension') || pres.contains('suspensión')) {
        String title;
        String content;
        if (isAnimal) {
          title = language == 'en' ? '🐾 With syringe' : (language == 'pt' ? '🐾 Com seringa' : '🐾 Con jeringa');
          content = language == 'en'
              ? 'Give syrup to $petName slowly with a syringe through the corner of their mouth.'
              : (language == 'pt'
                  ? 'Aplique o xarope a $petName devagar com seringa pelo canto da boca.'
                  : 'Aplica el jarabe a $petName con jeringa despacio por la comisura lateral de su boca.');
        } else {
          title = language == 'en' ? 'Shake before use' : (language == 'pt' ? 'Agite antes de usar' : 'Agitar antes de usar');
          content = language == 'en'
              ? 'Shake the ${t.nombreMedicamento} bottle well before each dose to homogenize the medicine.'
              : (language == 'pt'
                  ? 'Agite bem o frasco de ${t.nombreMedicamento} antes de cada dose para homogeneizar o remédio.'
                  : 'Agita bien el frasco de ${t.nombreMedicamento} antes de cada toma para homogeneizar la dosis.');
        }
        medTips.add({'title': title, 'content': content});
      }
    }

    // ─── 2. Consejos Específicos por Modo (Mascotas, Familiar, Clínico) ───
    final List<Map<String, String>> modeTips = [];
    if (isAnimal) {
      modeTips.add({
        'title': language == 'en' ? '🐾 Praise & love' : (language == 'pt' ? '🐾 Carinho e reforço' : '🐾 Refuerzo y caricias'),
        'content': language == 'en'
            ? 'Pet and praise $petName after taking their dose to create a positive routine.'
            : (language == 'pt'
                ? 'Faça carinho e recompense $petName após a dose para associar o remédio a algo positivo.'
                : 'Acaricia y premia a $petName después de su toma para que asocie la medicación a algo positivo.'),
      });
      modeTips.add({
        'title': language == 'en' ? '🐾 Food technique' : (language == 'pt' ? '🐾 Técnica na ração' : '🐾 Técnica en comida'),
        'content': language == 'en'
            ? 'For pills, you can hide the dose inside a treat or allowable wet food.'
            : (language == 'pt'
                ? 'Para comprimidos, você pode envolver a dose em um petisco ou alimento úmido permitido.'
                : 'Para comprimidos, puedes envolver la dosis en una bolita de comida húmeda o snack apto.'),
      });
      modeTips.add({
        'title': language == 'en' ? '🐾 Warning signs' : (language == 'pt' ? '🐾 Sinais de alerta' : '🐾 Signos de alerta'),
        'content': language == 'en'
            ? 'If you notice loss of appetite, lethargy or vomiting after dosing, contact your veterinarian promptly.'
            : (language == 'pt'
                ? 'Se notar falta de apetite, letargia ou vômitos após a dose, contate o veterinário imediatamente.'
                : 'Si notas inapetencia, letargo o vómitos tras la dosis, contacta de inmediato con su veterinario.'),
      });
    } else if (caregiverModeType == CaregiverModeType.clinico) {
      modeTips.add({
        'title': language == 'en' ? '🩺 The 5 Rights' : (language == 'pt' ? '🩺 Os 5 certos' : '🩺 Los 5 correctos'),
        'content': language == 'en'
            ? 'Verify patient, drug, dose, route and time before administering any medication.'
            : (language == 'pt'
                ? 'Verifique paciente, medicamento, dose, via e horário antes de administrar qualquer fármaco.'
                : 'Comprueba paciente, medicamento, dosis, vía y horario antes de suministrar cualquier fármaco.'),
      });
      modeTips.add({
        'title': language == 'en' ? '🩺 Vital signs' : (language == 'pt' ? '🩺 Sinais vitais' : '🩺 Signos vitales'),
        'content': language == 'en'
            ? 'Assess patient vital signs before and after administering controlled or sedative drugs.'
            : (language == 'pt'
                ? 'Avalie os sinais vitais do paciente antes e após administrar fármacos de controle ou sedativos.'
                : 'Evalúa las constantes del paciente antes y después de administrar fármacos de control o sedantes.'),
      });
      modeTips.add({
        'title': language == 'en' ? '🩺 Immediate chart' : (language == 'pt' ? '🩺 Registro imediato' : '🩺 Registro inmediato'),
        'content': language == 'en'
            ? 'Record every administered or refused dose in the clinical chart to guarantee traceability.'
            : (language == 'pt'
                ? 'Anote no prontuário cada dose administrada ou recusada para garantir a rastreabilidade.'
                : 'Anota en la ficha clínica cada toma administrada o rechazada para garantizar la trazabilidad.'),
      });
    } else if (caregiverModeType == CaregiverModeType.familiar) {
      modeTips.add({
        'title': language == 'en' ? '👨‍👩‍👧 Shared routine' : (language == 'pt' ? '👨‍👩‍👧 Rotina compartilhada' : '👨‍👩‍👧 Rutina compartida'),
        'content': language == 'en'
            ? 'Pair $famName\'s doses with pleasant moments like breakfast or a calm conversation.'
            : (language == 'pt'
                ? 'Associe as doses de $famName a momentos agradáveis como o café ou uma conversa tranquila.'
                : 'Asocia las tomas de $famName a hábitos agradables como el desayuno o una charla tranquila.'),
      });
      modeTips.add({
        'title': language == 'en' ? '👨‍👩‍👧 Gentle care' : (language == 'pt' ? '👨‍👩‍👧 Supervisão gentil' : '👨‍👩‍👧 Supervisión suave'),
        'content': language == 'en'
            ? 'Accompany $famName with a glass of water and make sure with patience that they swallow the dose.'
            : (language == 'pt'
                ? 'Acompanhe $famName com um copo d\'água e certifique-se com paciência de que engoliu a dose.'
                : 'Acompaña a $famName con un vaso de agua y asegúrate con paciencia de que trague la dosis.'),
      });
      modeTips.add({
        'title': language == 'en' ? '👨‍👩‍👧 Daily observation' : (language == 'pt' ? '👨‍👩‍👧 Observação diária' : '👨‍👩‍👧 Observación diaria'),
        'content': language == 'en'
            ? 'Watch for changes in mood, balance or drowsiness after new doses and note them for their doctor.'
            : (language == 'pt'
                ? 'Observe mudanças de humor, locomoção ou sonolência após novas doses e anote para o médico.'
                : 'Observa cambios de ánimo, marcha o somnolencia tras nuevas tomas y anótalos para su médico.'),
      });
    }

    // ─── 3. Consejos Generales de Adherencia e Hidratación ───
    final List<Map<String, String>> generalTips = [];
    if (adherenceRate >= 100 && takenCount > 0) {
      generalTips.add({
        'title': language == 'en' ? 'Great consistency!' : (language == 'pt' ? 'Excelente constância!' : '¡Excelente constancia!'),
        'content': language == 'en'
            ? '100% of your doses are on track today. Punctuality ensures the best health outcomes.'
            : (language == 'pt'
                ? 'Você está com 100% das suas doses em dia. A disciplina nos horários garante os melhores resultados.'
                : 'Llevas el 100% de tus dosis al día. La disciplina en los horarios asegura los mejores resultados.'),
      });
    } else if (pendingCount > 0) {
      generalTips.add({
        'title': language == 'en' ? 'Pending doses' : (language == 'pt' ? 'Doses pendentes' : 'Dosis pendientes'),
        'content': language == 'en'
            ? 'You have $pendingCount dose${pendingCount > 1 ? 's' : ''} pending today. Remember to log them on time.'
            : (language == 'pt'
                ? 'Você tem $pendingCount dose${pendingCount > 1 ? 's' : ''} pendente${pendingCount > 1 ? 's' : ''} hoje. Lembre-se de registrá-las a tempo.'
                : 'Tienes $pendingCount toma${pendingCount > 1 ? 's' : ''} pendiente${pendingCount > 1 ? 's' : ''} hoy. Recuerda registrarlas a tiempo.'),
      });
    }

    generalTips.add({
      'title': isAnimal
          ? (language == 'en' ? '🐾 Fresh water' : (language == 'pt' ? '🐾 Água fresca' : '🐾 Agua fresca'))
          : (language == 'en' ? 'Hydration key' : (language == 'pt' ? 'Hidratação chave' : 'Hidratación clave')),
      'content': isAnimal
          ? (language == 'en'
              ? 'Ensure $petName has clean, fresh water readily available after taking medicine.'
              : (language == 'pt'
                  ? 'Certifique-se de que $petName tenha água limpa e fresca disponível após tomar o remédio.'
                  : 'Asegúrate de que $petName tenga agua limpia y fresca disponible tras tomar su medicina.'))
          : (language == 'en'
              ? 'Always accompany your pills with a full glass of water for optimal digestive absorption.'
              : (language == 'pt'
                  ? 'Acompanhe sempre seus comprimidos com um copo cheio de água para melhor absorção.'
                  : 'Acompaña siempre tus comprimidos con un vaso lleno de agua para una absorción digestiva óptima.')),
    });

    // ─── 4. Combinación balanceada de 2 a 3 consejos ───
    final List<Map<String, String>> selectedTips = [];

    // Prioridad 1: Al menos 1 consejo específico del medicamento
    if (medTips.isNotEmpty) {
      selectedTips.add(medTips.first);
    }

    // Prioridad 2: Al menos 1 consejo adaptado al modo
    if (modeTips.isNotEmpty) {
      selectedTips.add(modeTips.first);
    }

    // Prioridad 3: Añadir segundo tip de medicamento o tip general
    if (selectedTips.length < 3 && medTips.length > 1) {
      selectedTips.add(medTips[1]);
    }

    for (var gen in generalTips) {
      if (selectedTips.length >= 3) break;
      if (!selectedTips.any((t) => t['title'] == gen['title'])) {
        selectedTips.add(gen);
      }
    }

    while (selectedTips.length < 2) {
      selectedTips.add({
        'title': language == 'en' ? 'Daily wellness' : (language == 'pt' ? 'Bem-estar diário' : 'Bienestar diario'),
        'content': language == 'en'
            ? 'Taking your medications at the exact time prevents complications and speeds recovery.'
            : (language == 'pt'
                ? 'Tomar seus medicamentos no horário exato evita complicações e acelera a recuperação.'
                : 'Tomar tus medicamentos a la hora exacta previene complicaciones y acelera tu recuperación.'),
      });
    }

    return selectedTips.take(3).map((tip) {
      return {
        'title': tip['title'] ?? '',
        'content': tip['content'] ?? '',
        'isAi': 'false',
      };
    }).toList();
  }
}
