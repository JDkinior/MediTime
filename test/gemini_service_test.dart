import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditime/models/caregiver_profile.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:meditime/services/gemini_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GeminiService - Tool Schemas', () {
    test('All function definitions strictly declare a valid parameters object', () {
      final tools = GeminiService.tools;
      expect(tools.isNotEmpty, isTrue);

      for (final tool in tools) {
        expect(tool['type'], equals('function'));
        final function = tool['function'] as Map<String, dynamic>;
        expect(function['name'], isNotNull);
        expect(function['parameters'], isNotNull,
            reason: "Function \${function['name']} must declare parameters object");
        final parameters = function['parameters'] as Map<String, dynamic>;
        expect(parameters['type'], equals('object'),
            reason: "Function \${function['name']} parameters must be of type object");
      }
    });

    test('Zero-argument tools have empty properties object to prevent Groq 400', () {
      final zeroArgToolNames = [
        'get_today_medications',
        'get_tomorrow_medications',
        'get_active_treatments',
      ];

      final tools = GeminiService.tools;
      for (final name in zeroArgToolNames) {
        final tool = tools.firstWhere(
          (t) => (t['function'] as Map<String, dynamic>)['name'] == name,
        );
        final function = tool['function'] as Map<String, dynamic>;
        final parameters = function['parameters'] as Map<String, dynamic>;
        expect(parameters['type'], equals('object'));
        expect(parameters['properties'], isA<Map<String, dynamic>>());
      }
    });

    test('show_adherence_chart declares properties for dynamic natural language intervals', () {
      final tools = GeminiService.tools;
      final tool = tools.firstWhere(
        (t) => (t['function'] as Map<String, dynamic>)['name'] == 'show_adherence_chart',
      );
      final function = tool['function'] as Map<String, dynamic>;
      final parameters = function['parameters'] as Map<String, dynamic>;
      expect(parameters['type'], equals('object'));
      final properties = parameters['properties'] as Map<String, dynamic>;
      expect(properties.containsKey('periodo'), isTrue);
      expect(properties.containsKey('dias'), isTrue);
      expect(properties.containsKey('fechaInicio'), isTrue);
      expect(properties.containsKey('fechaFin'), isTrue);
    });
  });

  group('GeminiService - API Key Resolution', () {
    test('Uses explicit API key when provided', () async {
      final service = GeminiService(apiKey: 'gsk_explicit_key');
      final effectiveKey = await service.getEffectiveApiKey();
      expect(effectiveKey, equals('gsk_explicit_key'));
    });

    test('Falls back to environment variable when explicit key is null or empty', () async {
      final service = GeminiService(apiKey: null);
      final effectiveKey = await service.getEffectiveApiKey();
      expect(effectiveKey, isA<String>());
    });
  });

  group('GeminiService - Context-Aware buildSystemPrompt', () {
    test('Base mode prompt is concise and personalized with user name', () {
      final prompt = GeminiService.buildSystemPrompt(
        userName: 'Carlos',
        isAnimalMode: false,
        isCaregiverMode: false,
      );

      expect(prompt.contains('Carlos'), isTrue);
      expect(prompt.contains('Midi'), isTrue);
      expect(prompt.contains('PERSONAL'), isTrue);
      expect(prompt.contains('veterinario'), isFalse);
    });

    test('Animal mode includes veterinary guardrails and dangerous human meds', () {
      final petProfile = CaregiverProfile(
        id: 'pet_1',
        name: 'Firulais',
        relationship: 'Perro',
        colorHex: '#4CAF50',
        isExternalUser: false,
        isAnimal: true,
        species: 'Perro',
        weight: '12 kg',
      );

      final prompt = GeminiService.buildSystemPrompt(
        activeProfile: petProfile,
        isAnimalMode: true,
        isCaregiverMode: false,
      );

      expect(prompt.contains('asistente veterinario'), isTrue);
      expect(prompt.contains('MODO ANIMALES (VETERINARIO)'), isTrue);
      expect(prompt.contains('Firulais'), isTrue);
      expect(prompt.contains('Perro'), isTrue);
      expect(prompt.contains('12 kg'), isTrue);
      // Critical veterinary safety warnings:
      expect(prompt.contains('Paracetamol'), isTrue);
      expect(prompt.contains('Ibuprofeno'), isTrue);
      expect(prompt.contains('Diclofenaco'), isTrue);
      expect(prompt.contains('xilitol'), isTrue);
      expect(prompt.contains('dosis veterinarias dependen del peso'), isTrue);
    });

    test('Caregiver clinical mode includes patient room, blood type, and 5 rights', () {
      final patientProfile = CaregiverProfile(
        id: 'patient_1',
        name: 'Doña Rosa',
        relationship: 'Paciente',
        colorHex: '#4F46E5',
        isExternalUser: false,
        roomNumber: '304-B',
        bloodType: 'O+',
        allergies: 'Penicilina, Sulfas',
      );

      final prompt = GeminiService.buildSystemPrompt(
        activeProfile: patientProfile,
        isAnimalMode: false,
        isCaregiverMode: true,
        caregiverModeType: CaregiverModeType.clinico,
      );

      expect(prompt.contains('MODO CUIDADOR CLÍNICO'), isTrue);
      expect(prompt.contains('Doña Rosa'), isTrue);
      expect(prompt.contains('304-B'), isTrue);
      expect(prompt.contains('Penicilina, Sulfas'), isTrue);
      expect(prompt.contains('O+'), isTrue);
      expect(prompt.contains('5 correctos'), isTrue);
    });

    test('Pre-injects compact active context to avoid redundant tool calls', () {
      final now = DateTime.now();
      final doseTime = DateTime(now.year, now.month, now.day, 8, 0);

      final treatment = Tratamiento(
        id: 'tx_1',
        nombreMedicamento: 'Amoxicilina 500mg',
        presentacion: 'Cápsulas',
        duracion: '7 días',
        horaPrimeraDosis: const TimeOfDay(hour: 8, minute: 0),
        intervaloDosis: const Duration(hours: 8),
        prescriptionAlarmId: 101,
        fechaInicioTratamiento: now.subtract(const Duration(days: 1)),
        fechaFinTratamiento: now.add(const Duration(days: 6)),
        notas: 'Tomar con alimentos',
        cantidadActual: 15,
        cantidadTotalCaja: 20,
        dosisPorToma: 1,
        doseStatus: {
          doseTime.toIso8601String(): DoseStatus.tomada,
        },
      );

      final prompt = GeminiService.buildSystemPrompt(
        activeTreatments: [treatment],
        isAnimalMode: false,
        isCaregiverMode: false,
      );

      expect(prompt.contains('[CONTEXTO ACTIVO HOY:'), isTrue);
      expect(prompt.contains('Amoxicilina 500mg'), isTrue);
      expect(prompt.contains('[Tomada]'), isTrue);
      expect(prompt.contains('Stock: 15/20'), isTrue);
      expect(prompt.contains('respóndela directamente sin invocar herramientas'), isTrue);
    });

    test('Animal mode differentiates Vista General from Vista Individual', () {
      final pet1 = CaregiverProfile(
        id: 'pet_1',
        name: 'Firulais',
        relationship: 'Perro',
        colorHex: '#4CAF50',
        isExternalUser: false,
        isAnimal: true,
        species: 'Perro',
        weight: '12 kg',
      );
      final pet2 = CaregiverProfile(
        id: 'pet_2',
        name: 'Michi',
        relationship: 'Gato',
        colorHex: '#FF9800',
        isExternalUser: false,
        isAnimal: true,
        species: 'Gato',
        weight: '4 kg',
      );

      // Vista General (activeProfile == null, multiple pets)
      final generalPrompt = GeminiService.buildSystemPrompt(
        activeProfile: null,
        allProfiles: [pet1, pet2],
        isAnimalMode: true,
        isCaregiverMode: false,
      );

      expect(generalPrompt.contains('VISTA GENERAL DE MASCOTAS'), isTrue);
      expect(generalPrompt.contains('Firulais'), isTrue);
      expect(generalPrompt.contains('Michi'), isTrue);
      expect(generalPrompt.contains('ACLARA SIEMPRE A QUÉ MASCOTA CORRESPONDE'), isTrue);
      expect(generalPrompt.contains('VISTA DE MASCOTA INDIVIDUAL'), isFalse);

      // Vista Individual (activeProfile == pet1)
      final individualPrompt = GeminiService.buildSystemPrompt(
        activeProfile: pet1,
        allProfiles: [pet1, pet2],
        isAnimalMode: true,
        isCaregiverMode: false,
      );

      expect(individualPrompt.contains('VISTA DE MASCOTA INDIVIDUAL'), isTrue);
      expect(individualPrompt.contains('Mascota seleccionada: Firulais'), isTrue);
      expect(individualPrompt.contains('VISTA GENERAL DE MASCOTAS'), isFalse);
    });

    test('Caregiver mode differentiates Vista General from Vista Individual', () {
      final patient1 = CaregiverProfile(
        id: 'pat_1',
        name: 'Don Carlos',
        relationship: 'Padre',
        colorHex: '#2196F3',
        isExternalUser: false,
        roomNumber: '101',
      );
      final patient2 = CaregiverProfile(
        id: 'pat_2',
        name: 'Doña Rosa',
        relationship: 'Madre',
        colorHex: '#E91E63',
        isExternalUser: false,
        roomNumber: '102',
      );

      // Vista General (activeProfile == null)
      final generalPrompt = GeminiService.buildSystemPrompt(
        activeProfile: null,
        allProfiles: [patient1, patient2],
        isAnimalMode: false,
        isCaregiverMode: true,
      );

      expect(generalPrompt.contains('VISTA GENERAL DE PACIENTES'), isTrue);
      expect(generalPrompt.contains('Don Carlos'), isTrue);
      expect(generalPrompt.contains('Doña Rosa'), isTrue);
      expect(generalPrompt.contains('DEBES SIEMPRE AGRUPAR O ESPECIFICAR EL NOMBRE DEL PACIENTE'), isTrue);
      expect(generalPrompt.contains('VISTA DE PACIENTE INDIVIDUAL'), isFalse);

      // Vista Individual (activeProfile == patient1)
      final individualPrompt = GeminiService.buildSystemPrompt(
        activeProfile: patient1,
        allProfiles: [patient1, patient2],
        isAnimalMode: false,
        isCaregiverMode: true,
      );

      expect(individualPrompt.contains('VISTA DE PACIENTE INDIVIDUAL'), isTrue);
      expect(individualPrompt.contains('Don Carlos'), isTrue);
      expect(individualPrompt.contains('VISTA GENERAL DE PACIENTES'), isFalse);
    });

    test('Calculates treatment end dates and remaining days accurately for user queries', () {
      final baseDate = DateTime(2026, 10, 16, 12, 0);

      // Fixed duration treatment (ending in 5 days)
      final txFixed = Tratamiento(
        id: 'tx_fixed',
        nombreMedicamento: 'Ciprofloxacino 500mg',
        presentacion: 'Comprimidos',
        duracion: '7 días',
        horaPrimeraDosis: const TimeOfDay(hour: 8, minute: 0),
        intervaloDosis: const Duration(hours: 12),
        prescriptionAlarmId: 201,
        fechaInicioTratamiento: DateTime(2026, 10, 14, 8, 0),
        fechaFinTratamiento: DateTime(2026, 10, 21, 20, 0),
      );

      // Indefinite / chronic treatment
      final txIndefinite = Tratamiento(
        id: 'tx_chronic',
        nombreMedicamento: 'Losartán 50mg',
        presentacion: 'Tabletas',
        duracion: 'Tratamiento indefinido',
        horaPrimeraDosis: const TimeOfDay(hour: 9, minute: 0),
        intervaloDosis: const Duration(hours: 24),
        prescriptionAlarmId: 202,
        fechaInicioTratamiento: DateTime(2026, 1, 1, 9, 0),
        fechaFinTratamiento: DateTime(2026, 12, 31, 9, 0),
      );

      final prompt = GeminiService.buildSystemPrompt(
        activeTreatments: [txFixed, txIndefinite],
        now: baseDate,
        isAnimalMode: false,
        isCaregiverMode: false,
      );

      // Verifies completion instructions are present
      expect(prompt.contains('CONSULTAS SOBRE CUÁNDO TERMINA UN TRATAMIENTO O DURACIÓN:'), isTrue);

      // Verifies fixed treatment timeline calculation
      expect(prompt.contains('Ciprofloxacino 500mg'), isTrue);
      expect(prompt.contains('quedan 5 días restantes'), isTrue);
      expect(prompt.contains('21 de octubre de 2026'), isTrue);

      // Verifies indefinite treatment timeline calculation
      expect(prompt.contains('Losartán 50mg'), isTrue);
      expect(prompt.contains('Continuo / Indefinido (sin fecha de fin programada)'), isTrue);
    });

    test('Animal mode includes strict pharmacology and route of administration guardrails', () {
      final prompt = GeminiService.buildSystemPrompt(
        isAnimalMode: true,
        isCaregiverMode: false,
      );

      // Verifies strict non-oral injection rules
      expect(prompt.contains('NUNCA INVENTES VÍAS DE ADMINISTRACIÓN'), isTrue);
      expect(prompt.contains('Ivomec Gold'), isTrue);
      expect(prompt.contains('EXCLUSIVAMENTE inyectables por vía subcutánea'), isTrue);
      expect(prompt.contains('altera la flora ruminal'), isTrue);
      expect(prompt.contains('NUNCA INVENTES CRONOGRAMAS NI REPETICIONES ARBITRARIAS'), isTrue);
      expect(prompt.contains('50 a 75 días'), isTrue);
      expect(prompt.contains('0.4 ml SC'), isTrue);
    });

    test('Mode signature isolation generates distinct signatures for clean memory segregation', () {
      final petProfile = CaregiverProfile(
        id: 'pet_max',
        name: 'Max',
        relationship: 'Bovino',
        colorHex: '#4CAF50',
        isExternalUser: false,
        isAnimal: true,
      );
      final patientProfile = CaregiverProfile(
        id: 'pat_juan',
        name: 'Juan',
        relationship: 'Paciente',
        colorHex: '#2196F3',
        isExternalUser: false,
      );

      final sigAnimal = GeminiService.computeModeSignature(
        isAnimalMode: true,
        activeProfile: petProfile,
      );
      final sigCaregiver = GeminiService.computeModeSignature(
        isCaregiverMode: true,
        caregiverModeType: CaregiverModeType.familiar,
        activeProfile: patientProfile,
      );
      final sigPersonal = GeminiService.computeModeSignature();

      expect(sigAnimal, equals('animal_pet_max'));
      expect(sigCaregiver, equals('caregiver_familiar_pat_juan'));
      expect(sigPersonal, equals('personal'));
      expect(sigAnimal, isNot(equals(sigCaregiver)));
      expect(sigCaregiver, isNot(equals(sigPersonal)));
    });

    test('Animal mode detects ruminants/bovines and applies livestock criteria', () {
      final bovineProfile = CaregiverProfile(
        id: 'pet_cow',
        name: 'Margarita',
        relationship: 'Vaca',
        colorHex: '#4CAF50',
        isExternalUser: false,
        isAnimal: true,
        species: 'Bovino',
        breed: 'Holstein',
        weight: '450 kg',
      );

      final prompt = GeminiService.buildSystemPrompt(
        activeProfile: bovineProfile,
        isAnimalMode: true,
        isCaregiverMode: false,
      );

      expect(prompt.contains('RUMIANTE'), isTrue);
      expect(prompt.contains('NUNCA hables de "plato de comida", "tazón" ni "vómitos"'), isTrue);
      expect(prompt.contains('tabla del cuello'), isTrue);
      expect(prompt.contains('período de retiro en carne y leche'), isTrue);
    });

    test('Animal mode detects lagomorphs/rabbits and warns about fipronil and oral penicillins', () {
      final rabbitProfile = CaregiverProfile(
        id: 'pet_rabbit',
        name: 'Tambor',
        relationship: 'Conejo',
        colorHex: '#9C27B0',
        isExternalUser: false,
        isAnimal: true,
        species: 'Conejo',
        breed: 'Belier',
        weight: '2.1 kg',
      );

      final prompt = GeminiService.buildSystemPrompt(
        activeProfile: rabbitProfile,
        isAnimalMode: true,
        isCaregiverMode: false,
      );

      expect(prompt.contains('LAGOMORFO / ROEDOR'), isTrue);
      expect(prompt.contains('Fipronil'), isTrue);
      expect(prompt.contains('PROHIBIDO Y ES MORTAL'), isTrue);
      expect(prompt.contains('enterotoxemia mortal por Clostridium'), isTrue);
      expect(prompt.contains('Incapaces de vomitar'), isTrue);
    });

    test('Animal mode detects felines/cats and warns about paracetamol, permethrin, and glucuronyl transferase', () {
      final catProfile = CaregiverProfile(
        id: 'pet_cat',
        name: 'Michi',
        relationship: 'Gato',
        colorHex: '#FF9800',
        isExternalUser: false,
        isAnimal: true,
        species: 'Felino',
        breed: 'Siamés',
        weight: '4 kg',
      );

      final prompt = GeminiService.buildSystemPrompt(
        activeProfile: catProfile,
        isAnimalMode: true,
        isCaregiverMode: false,
      );

      expect(prompt.contains('FELINO'), isTrue);
      expect(prompt.contains('glucuroniltransferasa'), isTrue);
      expect(prompt.contains('Paracetamol (Acetaminofén) es MORTAL'), isTrue);
      expect(prompt.contains('metahemoglobinemia'), isTrue);
      expect(prompt.contains('Permetrinas'), isTrue);
    });

    test('Animal mode detects chelonians/turtles and warns about ivermectin and renal portal system', () {
      final turtleProfile = CaregiverProfile(
        id: 'pet_turtle',
        name: 'Manuelita',
        relationship: 'Tortuga',
        colorHex: '#009688',
        isExternalUser: false,
        isAnimal: true,
        species: 'Reptil',
        breed: 'Galápago',
        weight: '800 g',
      );

      final prompt = GeminiService.buildSystemPrompt(
        activeProfile: turtleProfile,
        isAnimalMode: true,
        isCaregiverMode: false,
      );

      expect(prompt.contains('QUELONIO / REPTIL'), isTrue);
      expect(prompt.contains('Ivermectina en quelonios (tortugas) es MORTAL'), isTrue);
      expect(prompt.contains('parálisis flácida'), isTrue);
      expect(prompt.contains('sistema porta-renal'), isTrue);
      expect(prompt.contains('tercio craneal o extremidades anteriores'), isTrue);
    });

    test('Animal mode detects equines and warns about inability to vomit and ionophores toxicity', () {
      final horseProfile = CaregiverProfile(
        id: 'pet_horse',
        name: 'Tornado',
        relationship: 'Caballo',
        colorHex: '#795548',
        isExternalUser: false,
        isAnimal: true,
        species: 'Equino',
        breed: 'Pura Sangre',
        weight: '500 kg',
      );

      final prompt = GeminiService.buildSystemPrompt(
        activeProfile: horseProfile,
        isAnimalMode: true,
        isCaregiverMode: false,
      );

      expect(prompt.contains('ÉQUIDO'), isTrue);
      expect(prompt.contains('Incapaz anatómicamente de vomitar'), isTrue);
      expect(prompt.contains('Ionóforos (Monensina, Lasalocid)'), isTrue);
      expect(prompt.contains('fulminantemente cardiotóxicos'), isTrue);
    });

    test('Animal mode detects avians and warns about pectoral injection and PTFE teflon fumes', () {
      final birdProfile = CaregiverProfile(
        id: 'pet_bird',
        name: 'Paco',
        relationship: 'Loro',
        colorHex: '#4CAF50',
        isExternalUser: false,
        isAnimal: true,
        species: 'Ave',
        breed: 'Loro Amazonas',
        weight: '400 g',
      );

      final prompt = GeminiService.buildSystemPrompt(
        activeProfile: birdProfile,
        isAnimalMode: true,
        isCaregiverMode: false,
      );

      expect(prompt.contains('AVE'), isTrue);
      expect(prompt.contains('teflón caliente (PTFE)'), isTrue);
      expect(prompt.contains('musculatura pectoral'), isTrue);
    });

    test('detectAnimalTaxon accurately identifies diverse species across multiple fields', () {
      expect(GeminiService.detectAnimalTaxon(species: 'Bovino'), equals(AnimalTaxon.ruminant));
      expect(GeminiService.detectAnimalTaxon(relationship: 'Vaca'), equals(AnimalTaxon.ruminant));
      expect(GeminiService.detectAnimalTaxon(breed: 'Holstein'), equals(AnimalTaxon.ruminant));

      expect(GeminiService.detectAnimalTaxon(species: 'Equino'), equals(AnimalTaxon.equine));
      expect(GeminiService.detectAnimalTaxon(relationship: 'Caballo'), equals(AnimalTaxon.equine));

      expect(GeminiService.detectAnimalTaxon(species: 'Conejo'), equals(AnimalTaxon.lagomorphRodent));
      expect(GeminiService.detectAnimalTaxon(breed: 'Cobaya'), equals(AnimalTaxon.lagomorphRodent));

      expect(GeminiService.detectAnimalTaxon(species: 'Tortuga'), equals(AnimalTaxon.reptileChelonian));
      expect(GeminiService.detectAnimalTaxon(breed: 'Iguana'), equals(AnimalTaxon.reptileChelonian));

      expect(GeminiService.detectAnimalTaxon(species: 'Ave'), equals(AnimalTaxon.avian));
      expect(GeminiService.detectAnimalTaxon(relationship: 'Loro'), equals(AnimalTaxon.avian));

      expect(GeminiService.detectAnimalTaxon(species: 'Gato'), equals(AnimalTaxon.feline));
      expect(GeminiService.detectAnimalTaxon(breed: 'Siamés'), equals(AnimalTaxon.feline));

      expect(GeminiService.detectAnimalTaxon(species: 'Perro'), equals(AnimalTaxon.canine));
      expect(GeminiService.detectAnimalTaxon(breed: 'Collie'), equals(AnimalTaxon.canine));

      expect(GeminiService.detectAnimalTaxon(species: 'Cerdo'), equals(AnimalTaxon.swine));
    });

    test('Vista General compiles directives for all diverse species registered', () {
      final dog = CaregiverProfile(
        id: 'p1',
        name: 'Rex',
        relationship: 'Perro',
        colorHex: '#4CAF50',
        isExternalUser: false,
        isAnimal: true,
        species: 'Perro',
      );
      final rabbit = CaregiverProfile(
        id: 'p2',
        name: 'Bunny',
        relationship: 'Conejo',
        colorHex: '#9C27B0',
        isExternalUser: false,
        isAnimal: true,
        species: 'Conejo',
      );

      final prompt = GeminiService.buildSystemPrompt(
        activeProfile: null,
        allProfiles: [dog, rabbit],
        isAnimalMode: true,
        isCaregiverMode: false,
      );

      expect(prompt.contains('DIRECTIVAS DE LAS ESPECIES REGISTRADAS EN ESTE PERFIL:'), isTrue);
      expect(prompt.contains('CANINO - Perros'), isTrue);
      expect(prompt.contains('LAGOMORFO / ROEDOR - Conejos'), isTrue);
    });

    test('Human personal mode includes clinical pharmacology, emergency red flags, and no veterinary references', () {
      final prompt = GeminiService.buildSystemPrompt(
        userName: 'María',
        isAnimalMode: false,
        isCaregiverMode: false,
      );

      expect(prompt.contains('MODO PERSONAL'), isTrue);
      expect(prompt.contains('REGLAS FARMACOLÓGICAS Y DE SEGURIDAD EN SALUD HUMANA:'), isTrue);
      expect(prompt.contains('PREVENCIÓN DE AUTOMEDICACIÓN'), isTrue);
      expect(prompt.contains('los antibióticos requieren receta médica y no tienen efecto contra infecciones virales'), isTrue);
      expect(prompt.contains('paracetamol máximo 3-4 g/día'), isFalse); // en caregiver
      expect(prompt.contains('hepatotoxicidad por exceso de paracetamol'), isTrue);
      expect(prompt.contains('BANDERAS ROJAS'), isTrue);
      expect(prompt.contains('dolor opresivo en el pecho'), isTrue);
      expect(prompt.contains('accidente cerebrovascular'), isTrue);
      expect(prompt.contains('veterinario'), isFalse);
    });

    test('Human caregiver mode applies nursing 5 rights, special populations, and allergy cross-checks', () {
      final prompt = GeminiService.buildSystemPrompt(
        isAnimalMode: false,
        isCaregiverMode: true,
        caregiverModeType: CaregiverModeType.familiar,
      );

      expect(prompt.contains('REGLAS CLÍNICAS Y DE FARMACOVIGILANCIA EN HUMANOS (MODO CUIDADOR):'), isTrue);
      expect(prompt.contains('LOS 5 CORRECTOS UNIVERSALES DE ADMINISTRACIÓN CLÍNICA:'), isTrue);
      expect(prompt.contains('Paciente correcto'), isTrue);
      expect(prompt.contains('Medicamento correcto'), isTrue);
      expect(prompt.contains('Dosis correcta'), isTrue);
      expect(prompt.contains('Vía correcta'), isTrue);
      expect(prompt.contains('Hora y frecuencia correcta'), isTrue);
      expect(prompt.contains('medicamentos con nombres o fonética similar (LASA)'), isTrue);
      expect(prompt.contains('liberación prolongada (LP/XR/CR)'), isTrue);
      expect(prompt.contains('Síndrome de Reye'), isTrue);
      expect(prompt.contains('Coteja siempre las alergias conocidas'), isTrue);
      expect(prompt.contains('veterinario'), isFalse);
    });

    test('Prompt in Caregiver mode lists profiles and enforces targetProfileName instruction', () {
      final p1 = CaregiverProfile(
        id: 'patient_1',
        name: 'Juan David',
        relationship: 'Hijo',
        colorHex: '#4F46E5',
        isExternalUser: false,
        isAnimal: false,
      );

      final prompt = GeminiService.buildSystemPrompt(
        isAnimalMode: false,
        isCaregiverMode: true,
        allProfiles: [p1],
      );

      expect(prompt.contains('Juan David'), isTrue);
      expect(prompt.contains('ASIGNACIÓN EXACTA DE PERFILES EN RECORDATORIOS'), isTrue);
      expect(prompt.contains('targetProfileName'), isTrue);
    });
  });

  group('GeminiService - Target Profile Schema Validation', () {
    test('create_treatment tool declares targetProfileName in parameters', () {
      final tools = GeminiService.tools;
      final createTool = tools.firstWhere(
        (t) => (t['function'] as Map<String, dynamic>)['name'] == 'create_treatment',
      );
      final function = createTool['function'] as Map<String, dynamic>;
      final params = function['parameters'] as Map<String, dynamic>;
      final props = params['properties'] as Map<String, dynamic>;

      expect(props.containsKey('targetProfileName'), isTrue);
      expect(props['targetProfileName']['type'], equals('string'));
    });

    test('update_dose_status tool declares targetProfileName in parameters', () {
      final tools = GeminiService.tools;
      final updateTool = tools.firstWhere(
        (t) => (t['function'] as Map<String, dynamic>)['name'] == 'update_dose_status',
      );
      final function = updateTool['function'] as Map<String, dynamic>;
      final params = function['parameters'] as Map<String, dynamic>;
      final props = params['properties'] as Map<String, dynamic>;

      expect(props.containsKey('targetProfileName'), isTrue);
      expect(props['targetProfileName']['type'], equals('string'));
    });

    test('CaregiverProfile equality and hashCode are based on id', () {
      final p1 = CaregiverProfile(
        id: 'p_123',
        name: 'Juan David',
        relationship: 'Hijo',
        colorHex: '#4F46E5',
        isExternalUser: false,
      );

      final p2 = CaregiverProfile(
        id: 'p_123',
        name: 'Juan David Updated',
        relationship: 'Hijo',
        colorHex: '#00FF00',
        isExternalUser: false,
      );

      final p3 = CaregiverProfile(
        id: 'p_456',
        name: 'María',
        relationship: 'Mamá',
        colorHex: '#4F46E5',
        isExternalUser: false,
      );

      expect(p1 == p2, isTrue);
      expect(p1 == p3, isFalse);
      expect(p1.hashCode, equals(p2.hashCode));
    });

    test('GeminiService.detectCriticalConcurrentInteractions identifies Warfarina and Cefalexina', () {
      final now = DateTime(2026, 10, 17, 10, 0);
      final cefalexina = Tratamiento(
        id: 'tx_cefa',
        nombreMedicamento: 'Cefalexina',
        dosisPorToma: 1,
        presentacion: 'Cápsulas 500 mg',
        horaPrimeraDosis: const TimeOfDay(hour: 8, minute: 0),
        intervaloDosis: const Duration(hours: 6),
        duracion: '7 días',
        prescriptionAlarmId: 101,
        fechaInicioTratamiento: now.subtract(const Duration(days: 6)),
        fechaFinTratamiento: now.add(const Duration(days: 1)),
        doseStatus: {},
      );

      final warfarina = Tratamiento(
        id: 'tx_warfa',
        nombreMedicamento: 'Warfarina',
        dosisPorToma: 1,
        presentacion: 'Comprimidos 5 mg',
        horaPrimeraDosis: const TimeOfDay(hour: 8, minute: 0),
        intervaloDosis: const Duration(hours: 24),
        duracion: '14 días',
        prescriptionAlarmId: 102,
        fechaInicioTratamiento: now.subtract(const Duration(days: 5)),
        fechaFinTratamiento: now.add(const Duration(days: 9)),
        doseStatus: {},
      );

      final alerts = GeminiService.detectCriticalConcurrentInteractions(
        treatments: [cefalexina, warfarina],
        isAnimalMode: false,
      );

      expect(alerts.isNotEmpty, isTrue);
      expect(alerts.first.contains('Cefalexina'), isTrue);
      expect(alerts.first.contains('Warfarina'), isTrue);
      expect(alerts.first.contains('flora bacteriana intestinal'), isTrue);
      expect(alerts.first.contains('vitamina K'), isTrue);
      expect(alerts.first.contains('INR'), isTrue);
      expect(alerts.first.contains('hemorragia'), isTrue);
    });

    test('GeminiService.detectCriticalConcurrentInteractions identifies Warfarina and Ibuprofeno NSAID risk', () {
      final now = DateTime(2026, 10, 17, 10, 0);
      final warfarina = Tratamiento(
        id: 'tx_warfa',
        nombreMedicamento: 'Warfarina sódica',
        dosisPorToma: 1,
        presentacion: 'Comprimidos 5 mg',
        horaPrimeraDosis: const TimeOfDay(hour: 8, minute: 0),
        intervaloDosis: const Duration(hours: 24),
        duracion: '14 días',
        prescriptionAlarmId: 201,
        fechaInicioTratamiento: now,
        fechaFinTratamiento: now.add(const Duration(days: 14)),
        doseStatus: {},
      );

      final ibuprofeno = Tratamiento(
        id: 'tx_ibu',
        nombreMedicamento: 'Ibuprofeno',
        dosisPorToma: 1,
        presentacion: 'Tabletas 600 mg',
        horaPrimeraDosis: const TimeOfDay(hour: 8, minute: 0),
        intervaloDosis: const Duration(hours: 8),
        duracion: '5 días',
        prescriptionAlarmId: 202,
        fechaInicioTratamiento: now,
        fechaFinTratamiento: now.add(const Duration(days: 5)),
        doseStatus: {},
      );

      final alerts = GeminiService.detectCriticalConcurrentInteractions(
        treatments: [warfarina, ibuprofeno],
        isAnimalMode: false,
      );

      expect(alerts.isNotEmpty, isTrue);
      expect(alerts.first.contains('sangrado gastrointestinal'), isTrue);
      expect(alerts.first.contains('AINE'), isTrue);
    });

    test('buildSystemPrompt injects pharmacovigilance interaction block when Cefalexina and Warfarina are co-prescribed', () {
      final now = DateTime(2026, 10, 17, 10, 0);
      final cefalexina = Tratamiento(
        id: 'tx_cefa',
        nombreMedicamento: 'Cefalexina',
        dosisPorToma: 1,
        presentacion: 'Cápsulas 500 mg',
        horaPrimeraDosis: const TimeOfDay(hour: 8, minute: 0),
        intervaloDosis: const Duration(hours: 6),
        duracion: '7 días',
        prescriptionAlarmId: 301,
        fechaInicioTratamiento: now.subtract(const Duration(days: 6)),
        fechaFinTratamiento: now.add(const Duration(days: 1)),
        doseStatus: {},
      );

      final warfarina = Tratamiento(
        id: 'tx_warfa',
        nombreMedicamento: 'Warfarina',
        dosisPorToma: 1,
        presentacion: 'Comprimidos 5 mg',
        horaPrimeraDosis: const TimeOfDay(hour: 8, minute: 0),
        intervaloDosis: const Duration(hours: 24),
        duracion: '14 días',
        prescriptionAlarmId: 302,
        fechaInicioTratamiento: now.subtract(const Duration(days: 5)),
        fechaFinTratamiento: now.add(const Duration(days: 9)),
        doseStatus: {},
      );

      final prompt = GeminiService.buildSystemPrompt(
        userName: 'Usuario',
        isAnimalMode: false,
        isCaregiverMode: false,
        activeTreatments: [cefalexina, warfarina],
        now: now,
      );

      expect(prompt.contains('[FARMACOVIGILANCIA: ALERTAS DE INTERACCIÓN DETECTADAS]:'), isTrue);
      expect(prompt.contains('flora bacteriana intestinal'), isTrue);
      expect(prompt.contains('vitamina K'), isTrue);
      expect(prompt.contains('INR con alto riesgo de hemorragia'), isTrue);
      expect(prompt.contains('FARMACOVIGILANCIA E INTERACCIONES CRUZADAS (CRÍTICO)'), isTrue);
      expect(prompt.contains('dando prioridad absoluta a interacciones farmacológicas activas detectadas'), isTrue);
    });

    test('calculateDosesForDate generates accurate scheduled doses for tomorrow', () {
      final now = DateTime(2026, 10, 17, 10, 0);
      final tomorrow = DateTime(2026, 10, 18);
      final cefalexina = Tratamiento(
        id: 'tx_cefa',
        nombreMedicamento: 'Cefalexina',
        dosisPorToma: 1,
        presentacion: 'Cápsulas',
        horaPrimeraDosis: const TimeOfDay(hour: 6, minute: 0),
        intervaloDosis: const Duration(hours: 6),
        duracion: '7 días',
        prescriptionAlarmId: 301,
        fechaInicioTratamiento: now.subtract(const Duration(days: 4)),
        fechaFinTratamiento: now.add(const Duration(days: 3)),
        doseStatus: {},
      );

      final doses = GeminiService.calculateDosesForDate(cefalexina, tomorrow);
      expect(doses.length, equals(4));
      expect(doses[0].hour, equals(0));
      expect(doses[1].hour, equals(6));
      expect(doses[2].hour, equals(12));
      expect(doses[3].hour, equals(18));
    });

    test('calculateAdherenceSummary computes accurate adherence rate and breakdown', () {
      final now = DateTime(2026, 10, 17, 12, 0);
      final pastDose1 = now.subtract(const Duration(days: 1)).toIso8601String();
      final pastDose2 = now.subtract(const Duration(days: 2)).toIso8601String();

      final warfarina = Tratamiento(
        id: 'tx_warfa',
        nombreMedicamento: 'Warfarina',
        dosisPorToma: 1,
        presentacion: 'Comprimidos',
        horaPrimeraDosis: const TimeOfDay(hour: 8, minute: 0),
        intervaloDosis: const Duration(hours: 24),
        duracion: '10 días',
        prescriptionAlarmId: 302,
        fechaInicioTratamiento: now.subtract(const Duration(days: 3)),
        fechaFinTratamiento: now.add(const Duration(days: 7)),
        doseStatus: {
          pastDose1: DoseStatus.tomada,
          pastDose2: DoseStatus.tomada,
        },
      );

      final summary = GeminiService.calculateAdherenceSummary([warfarina], now: now);
      expect(summary['tomadas'], greaterThanOrEqualTo(2));
      expect(summary['periodo'], contains('oct'));
      expect(summary['breakdown'], contains('Warfarina'));
    });

    test('executeToolFunction returns rich adherence summary and no wait note directives for show_adherence_chart', () {
      final now = DateTime(2026, 10, 17, 12, 0);
      final service = GeminiService();
      final warfarina = Tratamiento(
        id: 'tx_warfa',
        nombreMedicamento: 'Warfarina',
        dosisPorToma: 1,
        presentacion: 'Comprimidos',
        horaPrimeraDosis: const TimeOfDay(hour: 8, minute: 0),
        intervaloDosis: const Duration(hours: 24),
        duracion: '10 días',
        prescriptionAlarmId: 302,
        fechaInicioTratamiento: now.subtract(const Duration(days: 3)),
        fechaFinTratamiento: now.add(const Duration(days: 7)),
        doseStatus: {},
      );

      final result = service.executeToolFunction('show_adherence_chart', {}, [warfarina]);
      expect(result.contains('Gráfico de adherencia desplegado en pantalla'), isTrue);
      expect(result.contains('Datos reales calculados:'), isTrue);
      expect(result.contains('DIRECTIVA AL ASISTENTE:'), isTrue);
      expect(result.contains('sin emitir notas de espera'), isTrue);
      expect(result.contains('Warfarina'), isTrue);
    });

    test('executeToolFunction get_tomorrow_medications returns scheduled times even with empty doseStatus', () {
      final now = DateTime.now();
      final service = GeminiService();
      final warfarina = Tratamiento(
        id: 'tx_warfa',
        nombreMedicamento: 'Warfarina',
        dosisPorToma: 1,
        presentacion: 'Comprimidos',
        horaPrimeraDosis: const TimeOfDay(hour: 8, minute: 0),
        intervaloDosis: const Duration(hours: 24),
        duracion: '10 días',
        prescriptionAlarmId: 302,
        fechaInicioTratamiento: now.subtract(const Duration(days: 2)),
        fechaFinTratamiento: now.add(const Duration(days: 8)),
        doseStatus: {},
      );

      final result = service.executeToolFunction('get_tomorrow_medications', {}, [warfarina]);
      expect(result.contains('Warfarina'), isTrue);
      expect(result.contains('08:00: programada'), isTrue);
      expect(result.contains('No doses scheduled'), isFalse);
      expect(result.contains('No hay dosis programadas'), isFalse);
    });

    test('buildSystemPrompt includes tool confidentiality and adherence analysis instructions', () {
      final prompt = GeminiService.buildSystemPrompt(
        userName: 'Usuario',
        isAnimalMode: false,
        isCaregiverMode: false,
      );

      expect(prompt.contains('CONFIDENCIALIDAD DE FUNCIONES Y HERRAMIENTAS:'), isTrue);
      expect(prompt.contains('NUNCA menciones nombres de funciones o herramientas técnicas en el texto visible'), isTrue);
      expect(prompt.contains('MANEJO DE GRÁFICO E INFORME DE ADHERENCIA:'), isTrue);
      expect(prompt.contains('NUNCA emitas notas de espera como "Se está generando tu reporte... espera unos segundos"'), isTrue);
      expect(prompt.contains('ANALIZA DE INMEDIATO los datos de adherencia'), isTrue);
    });

    test('calculateDayDoses accurately prioritizes explicit advance omissions without duplicates', () {
      final fixedDate = DateTime(2026, 10, 17);
      final earlyMorning = DateTime(2026, 10, 17, 5, 18);
      final scheduledDoseTime = DateTime(2026, 10, 17, 6, 59);

      final warfarina = Tratamiento(
        id: 'tx_warfa',
        nombreMedicamento: 'Warfarina',
        dosisPorToma: 1,
        presentacion: 'Comprimidos',
        horaPrimeraDosis: const TimeOfDay(hour: 1, minute: 58),
        intervaloDosis: const Duration(hours: 24),
        duracion: '10 días',
        prescriptionAlarmId: 302,
        fechaInicioTratamiento: fixedDate.subtract(const Duration(days: 2)),
        fechaFinTratamiento: fixedDate.add(const Duration(days: 8)),
        doseStatus: {
          scheduledDoseTime.toIso8601String(): DoseStatus.omitida,
        },
      );

      final doses = GeminiService.calculateDayDoses(warfarina, fixedDate, now: earlyMorning);
      expect(doses.length, equals(1));
      expect(doses.first['time'], equals(scheduledDoseTime));
      expect(doses.first['status'], equals(DoseStatus.omitida));
      expect(doses.first['isRecorded'], isTrue);
    });

    test('executeToolFunction get_today_medications and get_missed_doses detect advance omissions', () {
      final now = DateTime.now();
      final doseTime = DateTime(now.year, now.month, now.day, 23, 0); // Later today
      final service = GeminiService();

      final warfarina = Tratamiento(
        id: 'tx_warfa',
        nombreMedicamento: 'Warfarina',
        dosisPorToma: 1,
        presentacion: 'Comprimidos',
        horaPrimeraDosis: const TimeOfDay(hour: 8, minute: 0),
        intervaloDosis: const Duration(hours: 24),
        duracion: '10 días',
        prescriptionAlarmId: 302,
        fechaInicioTratamiento: now.subtract(const Duration(days: 2)),
        fechaFinTratamiento: now.add(const Duration(days: 8)),
        doseStatus: {
          doseTime.toIso8601String(): DoseStatus.omitida,
        },
      );

      final todayResult = service.executeToolFunction('get_today_medications', {}, [warfarina]);
      expect(todayResult.contains('Warfarina'), isTrue);
      expect(todayResult.contains('omitida'), isTrue);

      final missedResult = service.executeToolFunction('get_missed_doses', {'days': 7}, [warfarina]);
      expect(missedResult.contains('Warfarina'), isTrue);
      expect(missedResult.contains('missed on'), isTrue);
    });
  });
}

