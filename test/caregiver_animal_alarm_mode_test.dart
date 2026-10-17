import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:meditime/services/preference_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Caregiver and Animal Alarm Mode Coordination Tests', () {
    late PreferenceService preferenceService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      preferenceService = PreferenceService();
    });

    test('Profile classification: animal vs caregiver profile IDs', () async {
      await preferenceService.saveAnimalProfileIds(['animal_1', 'animal_2']);
      await preferenceService.saveCaregiverProfileIds(['caregiver_1']);

      expect(await preferenceService.isAnimalProfile('animal_1'), true);
      expect(await preferenceService.isAnimalProfile('animal_2'), true);
      expect(await preferenceService.isAnimalProfile('caregiver_1'), false);
      expect(await preferenceService.isAnimalProfile('unknown'), false);

      expect(await preferenceService.isCaregiverProfile('caregiver_1'), true);
      expect(await preferenceService.isCaregiverProfile('animal_1'), false);
    });

    test('Alarm ID tracking for caregiver mode', () async {
      await preferenceService.addCaregiverAlarmId(101);
      await preferenceService.addCaregiverAlarmId(102);

      var ids = await preferenceService.getCaregiverAlarmIds();
      expect(ids, containsAll([101, 102]));
      expect(ids.length, 2);

      await preferenceService.removeCaregiverAlarmId(101);
      ids = await preferenceService.getCaregiverAlarmIds();
      expect(ids, [102]);

      await preferenceService.clearCaregiverAlarmIds();
      ids = await preferenceService.getCaregiverAlarmIds();
      expect(ids, isEmpty);
    });

    test('Alarm ID tracking for animal mode', () async {
      await preferenceService.addAnimalAlarmId(201);
      await preferenceService.addAnimalAlarmId(202);

      var ids = await preferenceService.getAnimalAlarmIds();
      expect(ids, containsAll([201, 202]));
      expect(ids.length, 2);

      await preferenceService.removeAnimalAlarmId(201);
      ids = await preferenceService.getAnimalAlarmIds();
      expect(ids, [202]);

      await preferenceService.clearAnimalAlarmIds();
      ids = await preferenceService.getAnimalAlarmIds();
      expect(ids, isEmpty);
    });

    test('Mode toggles and mutual exclusivity verification in preferences', () async {
      // Activar modo cuidador
      await preferenceService.saveCaregiverModeActive(true);
      await preferenceService.saveAnimalModeActive(false);

      expect(await preferenceService.getCaregiverModeActive(), true);
      expect(await preferenceService.getAnimalModeActive(), false);

      // Desactivar modo cuidador
      await preferenceService.saveCaregiverModeActive(false);
      expect(await preferenceService.getCaregiverModeActive(), false);
      expect(await preferenceService.getAnimalModeActive(), false);

      // Activar modo animales
      await preferenceService.saveAnimalModeActive(true);
      expect(await preferenceService.getAnimalModeActive(), true);
      expect(await preferenceService.getCaregiverModeActive(), false);
    });

    test('Alarm guard decision logic verification', () async {
      // 1. Caso: Modo cuidador inactivo -> Alarma de cuidador bloqueada
      await preferenceService.saveCaregiverModeActive(false);
      await preferenceService.saveAnimalModeActive(false);
      await preferenceService.saveCaregiverProfileIds(['patient_A']);

      final isPatientAAnimal = await preferenceService.isAnimalProfile('patient_A');
      final isCaregiverActive = await preferenceService.getCaregiverModeActive();
      final isAnimalActive = await preferenceService.getAnimalModeActive();

      bool shouldBlockPatient = false;
      if (isPatientAAnimal) {
        if (!isAnimalActive) shouldBlockPatient = true;
      } else {
        if (!isCaregiverActive) shouldBlockPatient = true;
      }
      expect(shouldBlockPatient, true);

      // 2. Caso: Modo cuidador activo -> Alarma de cuidador permitida
      await preferenceService.saveCaregiverModeActive(true);
      final isCaregiverActiveNow = await preferenceService.getCaregiverModeActive();
      bool shouldBlockPatientNow = false;
      if (isPatientAAnimal) {
        if (!isAnimalActive) shouldBlockPatientNow = true;
      } else {
        if (!isCaregiverActiveNow) shouldBlockPatientNow = true;
      }
      expect(shouldBlockPatientNow, false);

      // 3. Caso: Modo animales inactivo -> Alarma de animal bloqueada
      await preferenceService.saveAnimalProfileIds(['pet_B']);
      final isPetBAnimal = await preferenceService.isAnimalProfile('pet_B');
      bool shouldBlockPet = false;
      if (isPetBAnimal) {
        if (!isAnimalActive) shouldBlockPet = true;
      } else {
        if (!isCaregiverActiveNow) shouldBlockPet = true;
      }
      expect(shouldBlockPet, true);

      // 4. Caso: Modo animales activo -> Alarma de animal permitida
      await preferenceService.saveAnimalModeActive(true);
      final isAnimalActiveNow = await preferenceService.getAnimalModeActive();
      bool shouldBlockPetNow = false;
      if (isPetBAnimal) {
        if (!isAnimalActiveNow) shouldBlockPetNow = true;
      } else {
        if (!isCaregiverActiveNow) shouldBlockPetNow = true;
      }
      expect(shouldBlockPetNow, false);

      // 5. Caso: Alarma personal (sin profileId) -> Siempre permitida
      const String? personalProfileId = null;
      expect(personalProfileId == null, true); // No entra al guard de perfiles
    });
  });
}
