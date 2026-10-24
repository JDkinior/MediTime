// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:meditime/services/preference_service.dart';
import 'package:meditime/services/widget_service.dart';
import 'package:meditime/models/caregiver_profile.dart';
import 'package:meditime/core/stream_cache.dart';

/// Servicio para interactuar con la base de datos de Cloud Firestore.
///
/// Abstrae todas las operaciones de lectura y escritura (CRUD) para los datos
/// de la aplicación, como perfiles de usuario y tratamientos, con soporte
/// resiliente para operación 100% offline.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final StreamCache<String, List<Tratamiento>> _medicamentosCache =
      StreamCache<String, List<Tratamiento>>();

  FirestoreService() {
    _db.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  /// Lectura rápida de un documento con fallback inmediato a la caché local de Firestore
  /// cuando el dispositivo no tiene internet o la red presenta alta latencia.
  Future<DocumentSnapshot<Map<String, dynamic>>> _getDocFast(
    DocumentReference docRef, {
    Duration timeout = const Duration(milliseconds: 1500),
  }) async {
    final typedRef = docRef.withConverter<Map<String, dynamic>>(
      fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
      toFirestore: (data, _) => data,
    );
    try {
      return await typedRef.get().timeout(timeout);
    } catch (_) {
      return await typedRef.get(const GetOptions(source: Source.cache));
    }
  }

  /// Lectura rápida de una colección con fallback inmediato a la caché local de Firestore.
  Future<QuerySnapshot<Map<String, dynamic>>> _getQueryFast(
    CollectionReference colRef, {
    Duration timeout = const Duration(milliseconds: 2000),
  }) async {
    final typedCol = colRef.withConverter<Map<String, dynamic>>(
      fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
      toFirestore: (data, _) => data,
    );
    try {
      return await typedCol.get().timeout(timeout);
    } catch (_) {
      return await typedCol.get(const GetOptions(source: Source.cache));
    }
  }

  // --- Perfil de Usuario ---

  /// Guarda o actualiza los datos del perfil de un usuario.
  ///
  /// Utiliza `SetOptions(merge: true)` para no sobrescribir campos existentes
  /// si solo se actualiza una parte del perfil.
  Future<void> saveUserProfile(String userId, Map<String, dynamic> data) {
    return _db
        .collection('users')
        .doc(userId)
        .set(data, SetOptions(merge: true));
  }

  /// Obtiene el documento del perfil de un usuario específico.
  Future<DocumentSnapshot> getUserProfile(String userId) {
    return _getDocFast(_db.collection('users').doc(userId));
  }

  // --- Perfil de Cuidador (Caregiver Mode) ---
  
  Future<List<CaregiverProfile>> getCaregiverProfiles(String userId) async {
    try {
      final query = await _getQueryFast(
        _db.collection('users').doc(userId).collection('managed_profiles'),
      );
      return query.docs.map((doc) => CaregiverProfile.fromMap(doc.id, doc.data())).toList();
    } catch (e) {
      debugPrint('Error obteniendo CaregiverProfiles: $e');
      return [];
    }
  }

  Future<void> saveCaregiverProfile(String userId, CaregiverProfile profile) {
    return _db.collection('users').doc(userId).collection('managed_profiles').doc(profile.id).set(profile.toMap());
  }

  Future<void> deleteCaregiverProfile(String userId, String profileId) {
    return _db.collection('users').doc(userId).collection('managed_profiles').doc(profileId).delete();
  }

  Future<CaregiverProfile?> getCaregiverProfile(String userId, String profileId) async {
    try {
      final doc = await _getDocFast(
        _db.collection('users').doc(userId).collection('managed_profiles').doc(profileId),
      );
      if (doc.exists && doc.data() != null) {
        return CaregiverProfile.fromMap(doc.id, doc.data()!);
      }
    } catch (e) {
      debugPrint('Error obteniendo CaregiverProfile: $e');
    }
    return null;
  }

  /// Resuelve la referencia del documento de tratamiento y su perfil asociado.
  /// Si [profile] es provisto, retorna la referencia directamente.
  /// Si [profileId] es provisto, busca en ese perfil.
  /// Si ambos son nulos, primero verifica la colección personal y, si no existe allí,
  /// busca automáticamente en los perfiles gestionados (modo cuidador / modo animales).
  Future<({DocumentReference docRef, CaregiverProfile? profile})?> resolveMedicamentoWithProfile(
    String userId,
    String docId, {
    CaregiverProfile? profile,
    String? profileId,
  }) async {
    if (profile != null) {
      return (docRef: getMedicamentoDocRef(userId, docId, profile), profile: profile);
    }

    if (profileId != null && profileId.isNotEmpty) {
      final loadedProfile = await getCaregiverProfile(userId, profileId);
      final docRef = (loadedProfile != null &&
              loadedProfile.isExternalUser &&
              loadedProfile.linkedUid != null)
          ? _db
              .collection('medicamentos')
              .doc(loadedProfile.linkedUid!)
              .collection('userMedicamentos')
              .doc(docId)
          : _db
              .collection('users')
              .doc(userId)
              .collection('managed_profiles')
              .doc(profileId)
              .collection('userMedicamentos')
              .doc(docId);
      return (docRef: docRef, profile: loadedProfile);
    }

    // 1. Probar ruta personal por defecto
    final personalRef = _db
        .collection('medicamentos')
        .doc(userId)
        .collection('userMedicamentos')
        .doc(docId);
    try {
      final personalSnap = await _getDocFast(personalRef);
      if (personalSnap.exists) {
        return (docRef: personalRef, profile: null);
      }
    } catch (e) {
      debugPrint("Error verificando colección personal: $e");
    }

    // 2. Buscar en perfiles gestionados del usuario (cuidador / animales)
    try {
      final profilesSnap = await _getQueryFast(
        _db.collection('users').doc(userId).collection('managed_profiles'),
      );

      for (final profileDoc in profilesSnap.docs) {
        final managedRef = profileDoc.reference
            .collection('userMedicamentos')
            .doc(docId);
        try {
          final managedSnap = await _getDocFast(managedRef);
          if (managedSnap.exists) {
            final foundProfile = CaregiverProfile.fromMap(profileDoc.id, profileDoc.data());
            return (docRef: managedRef, profile: foundProfile);
          }
        } catch (_) {}

        // Si es usuario externo vinculado
        final data = profileDoc.data();
        if (data['isExternalUser'] == true && data['linkedUid'] != null) {
          final extRef = _db
              .collection('medicamentos')
              .doc(data['linkedUid'] as String)
              .collection('userMedicamentos')
              .doc(docId);
          try {
            final extSnap = await _getDocFast(extRef);
            if (extSnap.exists) {
              final foundProfile = CaregiverProfile.fromMap(profileDoc.id, profileDoc.data());
              return (docRef: extRef, profile: foundProfile);
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint("Error buscando documento en perfiles gestionados: $e");
    }

    return null;
  }

  /// Atajo para resolver únicamente la referencia del documento de tratamiento.
  Future<DocumentReference?> resolveMedicamentoDocRef(
    String userId,
    String docId, {
    CaregiverProfile? profile,
    String? profileId,
  }) async {
    final result = await resolveMedicamentoWithProfile(
      userId,
      docId,
      profile: profile,
      profileId: profileId,
    );
    return result?.docRef;
  }

  // --- Medicamentos ---

  CollectionReference _getMedicamentosCollection(String userId, [CaregiverProfile? profile]) {
    if (profile == null) {
      return _db.collection('medicamentos').doc(userId).collection('userMedicamentos');
    }
    if (profile.isExternalUser && profile.linkedUid != null) {
      return _db.collection('medicamentos').doc(profile.linkedUid!).collection('userMedicamentos');
    }
    return _db.collection('users').doc(userId).collection('managed_profiles').doc(profile.id).collection('userMedicamentos');
  }

  /// Obtiene un `Stream` con la lista de todos los tratamientos de un usuario.
  ///
  /// El `Stream` se actualiza automáticamente cuando hay cambios en Firestore.
  /// Transforma los documentos de Firestore en una lista de objetos `Tratamiento`.
  Stream<List<Tratamiento>> getMedicamentosStream(String userId, [CaregiverProfile? profile]) {
    final cacheKey = profile == null ? userId : '${userId}_${profile.id}';
    return _medicamentosCache.getStream(cacheKey, () {
      return _getMedicamentosCollection(userId, profile)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          return Tratamiento.fromFirestore(
            doc as DocumentSnapshot<Map<String, dynamic>>,
          );
        }).toList();
      });
    });
  }

  /// Obtiene los medicamentos de la cache de forma sincrónica.
  List<Tratamiento>? getCachedMedicamentos(String userId, [CaregiverProfile? profile]) {
    final cacheKey = profile == null ? userId : '${userId}_${profile.id}';
    return _medicamentosCache.getLastValue(cacheKey);
  }

  /// Obtiene la lista de medicamentos de una sola vez desde Firestore o caché.
  Future<List<Tratamiento>> getMedicamentos(String userId, [CaregiverProfile? profile]) async {
    final cached = getCachedMedicamentos(userId, profile);
    if (cached != null) return cached;
    try {
      final snapshot = await _getQueryFast(_getMedicamentosCollection(userId, profile));
      return snapshot.docs.map((doc) {
        return Tratamiento.fromFirestore(doc);
      }).toList();
    } catch (e) {
      debugPrint("Error obteniendo medicamentos de Firestore: $e");
      return [];
    }
  }

  /// Obtiene los tratamientos de todos los perfiles de cuidadores humanos.
  Future<List<Tratamiento>> getCaregiverTreatments(String userId, [List<CaregiverProfile>? profiles]) async {
    final targetProfiles = profiles ?? await getCaregiverProfiles(userId);
    final List<Tratamiento> result = [];
    for (final profile in targetProfiles.where((p) => !p.isAnimal)) {
      final meds = await getMedicamentos(userId, profile);
      result.addAll(meds);
    }
    return result;
  }

  /// Obtiene los tratamientos de todos los perfiles de animales / mascotas.
  Future<List<Tratamiento>> getAnimalTreatments(String userId, [List<CaregiverProfile>? profiles]) async {
    final targetProfiles = profiles ?? await getCaregiverProfiles(userId);
    final List<Tratamiento> result = [];
    for (final profile in targetProfiles.where((p) => p.isAnimal)) {
      final meds = await getMedicamentos(userId, profile);
      result.addAll(meds);
    }
    return result;
  }

  /// Invalida la caché de medicamentos para un usuario o perfil específico, o toda la caché.
  void clearMedicamentosCache([String? userId, CaregiverProfile? profile]) {
    if (userId == null) {
      _medicamentosCache.clearAll();
    } else {
      final cacheKey = profile == null ? userId : '${userId}_${profile.id}';
      _medicamentosCache.clearKey(cacheKey);
    }
  }

  /// Guarda un nuevo tratamiento en la base de datos para un usuario específico.
  Future<DocumentReference> saveMedicamento({
    required String userId,
    CaregiverProfile? profile,
    required String nombreMedicamento,
    required String presentacion,
    required String duracion,
    required int cantidadActual,
    required int cantidadTotalCaja,
    required int dosisPorToma,
    required TimeOfDay horaPrimeraDosis,
    required Duration intervaloDosis,
    required int prescriptionAlarmId,
    required DateTime fechaInicioTratamiento,
    required DateTime fechaFinTratamiento,
    required String notas,
  }) async {
    // Todos los tratamientos utilizan el sistema lazy: el mapa de dosis se mantiene vacío inicialmente
    // y las dosis se calculan bajo demanda, guardando en Firestore únicamente los cambios de estado.
    final Map<String, String> doseStatusMap = {};

    final ref = _getMedicamentosCollection(userId, profile).doc();

    // Asegurar que la fecha de inicio almacenada tenga segundos y milisegundos en 0
    final cleanInicio = DateTime(
      fechaInicioTratamiento.year,
      fechaInicioTratamiento.month,
      fechaInicioTratamiento.day,
      fechaInicioTratamiento.hour,
      fechaInicioTratamiento.minute,
    );

    final Map<String, dynamic> dataToSave = {
      'nombreMedicamento': nombreMedicamento,
      'presentacion': presentacion,
      'duracion': duracion,
      'cantidadActual': cantidadActual,
      'cantidadTotalCaja': cantidadTotalCaja,
      'dosisPorToma': dosisPorToma,
      'horaPrimeraDosis':
          '${horaPrimeraDosis.hour}:${horaPrimeraDosis.minute}',
      'intervaloDosis': intervaloDosis.inHours.toString(),
      'prescriptionAlarmId': prescriptionAlarmId,
      'fechaInicioTratamiento': Timestamp.fromDate(cleanInicio),
      'fechaFinTratamiento': Timestamp.fromDate(fechaFinTratamiento),
      'skippedDoses': [],
      'notas': notas,
      'doseStatus': doseStatusMap,
    };
    if (profile != null) {
      dataToSave['profileId'] = profile.id;
    }

    // Con persistencia offline habilitada, set() escribe inmediatamente en la caché local
    // pero el Future espera confirmación del servidor. Usamos timeout para no bloquear en modo offline.
    await ref.set(dataToSave).timeout(
      const Duration(seconds: 2),
      onTimeout: () {
        debugPrint('saveMedicamento guardado en caché local offline (pendiente de red).');
      },
    );

    try {
      WidgetService.updateWidgetData(userId: userId);
    } catch (e) {
      debugPrint('Error actualizando widget tras guardar medicamento: $e');
    }
    return ref;
  }

  /// Actualiza los datos de un tratamiento existente.
  Future<void> updateMedicamento({
    required String userId,
    CaregiverProfile? profile,
    required String docId,
    required String nombreMedicamento,
    required String presentacion,
    required String duracion,
    required int cantidadActual,
    required int cantidadTotalCaja,
    required int dosisPorToma,
    required TimeOfDay horaPrimeraDosis,
    required Duration intervaloDosis,
    required DateTime fechaInicioTratamiento,
    required DateTime fechaFinTratamiento,
    required String notas,
  }) async {
    final ref = _getMedicamentosCollection(userId, profile).doc(docId);
    final cleanInicio = DateTime(
      fechaInicioTratamiento.year,
      fechaInicioTratamiento.month,
      fechaInicioTratamiento.day,
      fechaInicioTratamiento.hour,
      fechaInicioTratamiento.minute,
    );
    await ref.update({
      'nombreMedicamento': nombreMedicamento,
      'presentacion': presentacion,
      'duracion': duracion,
      'cantidadActual': cantidadActual,
      'cantidadTotalCaja': cantidadTotalCaja,
      'dosisPorToma': dosisPorToma,
      'horaPrimeraDosis': '${horaPrimeraDosis.hour}:${horaPrimeraDosis.minute}',
      'intervaloDosis': intervaloDosis.inHours.toString(),
      'fechaInicioTratamiento': Timestamp.fromDate(cleanInicio),
      'fechaFinTratamiento': Timestamp.fromDate(fechaFinTratamiento),
      'notas': notas,
    }).timeout(
      const Duration(seconds: 2),
      onTimeout: () {
        debugPrint('updateMedicamento aplicado en caché local offline.');
      },
    );
    try {
      WidgetService.updateWidgetData(userId: userId);
    } catch (e) {
      debugPrint('Error actualizando widget tras editar medicamento: $e');
    }
  }

  /// Elimina un documento de tratamiento específico.
  Future<void> deleteTratamiento(String userId, String docId, [CaregiverProfile? profile]) async {
    await _getMedicamentosCollection(userId, profile).doc(docId).delete().timeout(
      const Duration(seconds: 2),
      onTimeout: () {
        debugPrint('deleteTratamiento aplicado en caché local offline.');
      },
    );
    try {
      WidgetService.updateWidgetData(userId: userId);
    } catch (e) {
      debugPrint('Error actualizando widget tras borrar tratamiento: $e');
    }
  }

  /// Elimina todos los tratamientos de un usuario de la base de datos y
  /// retorna la lista de tratamientos eliminados para poder cancelar sus alarmas.
  Future<List<Tratamiento>> clearAllMedicamentos(String userId, [CaregiverProfile? profile]) async {
    final snapshot = await _getQueryFast(_getMedicamentosCollection(userId, profile));

    final List<Tratamiento> tratamientos = [];
    final batch = _db.batch();

    for (var doc in snapshot.docs) {
      final tratamiento = Tratamiento.fromFirestore(doc);
      tratamientos.add(tratamiento);
      batch.delete(doc.reference);
    }

    await batch.commit().timeout(
      const Duration(seconds: 2),
      onTimeout: () {},
    );
    final cacheKey = profile == null ? userId : '${userId}_${profile.id}';
    _medicamentosCache.clearKey(cacheKey);
    try {
      WidgetService.updateWidgetData(userId: userId);
    } catch (e) {
      debugPrint('Error actualizando widget tras limpiar medicamentos: $e');
    }
    return tratamientos;
  }


  /// Obtiene la referencia a un documento de tratamiento específico.
  /// Útil para realizar actualizaciones o lecturas directas.
  DocumentReference getMedicamentoDocRef(String userId, String docId, [CaregiverProfile? profile]) {
    return _getMedicamentosCollection(userId, profile).doc(docId);
  }

  /// Actualiza el mapa completo de dosis de un tratamiento
  Future<void> updateTreatmentDoses(
    String userId,
    String docId,
    Map<String, String> doseStatusMap,
    [CaregiverProfile? profile]
  ) async {
    final docRef = getMedicamentoDocRef(userId, docId, profile);

    try {
      await docRef.update({'doseStatus': doseStatusMap}).timeout(
        const Duration(seconds: 2),
        onTimeout: () {},
      );
      debugPrint("SUCCESS: Treatment doses updated for doc: ${docRef.path}");
    } catch (e) {
      debugPrint("ERROR updating treatment doses: $e");
      rethrow;
    }
  }

  /// Aplaza o modifica la hora de una dosis puntual de forma segura tanto online como offline.
  Future<Tratamiento?> deferOrMoveSingleDose({
    required String userId,
    required String docId,
    required DateTime oldDoseTime,
    required DateTime newDoseTime,
    DoseStatus newStatus = DoseStatus.pendiente,
    CaregiverProfile? profile,
  }) async {
    DocumentReference docRef = getMedicamentoDocRef(userId, docId, profile);
    if (profile == null) {
      final resolved = await resolveMedicamentoWithProfile(userId, docId);
      if (resolved != null) {
        docRef = resolved.docRef;
        profile = resolved.profile;
      }
    }

    // 1. Actualizar registro local inmediatamente
    await PreferenceService().replaceLocalDoseKey(
      userId: userId,
      docId: docId,
      oldDoseTime: oldDoseTime,
      newDoseTime: newDoseTime,
      status: newStatus.value,
    );

    try {
      final snapshot = await _getDocFast(docRef);
      if (!snapshot.exists) return null;

      final t = Tratamiento.fromFirestore(snapshot);
      final updatedMap = Map<String, DoseStatus>.from(t.doseStatus);
      final oldKey = oldDoseTime.toIso8601String();

      // Eliminar también cualquier clave dentro de los 15 minutos de oldDoseTime
      String? matchedOldKey;
      if (updatedMap.containsKey(oldKey)) {
        matchedOldKey = oldKey;
      } else {
        for (final k in updatedMap.keys) {
          final dt = DateTime.tryParse(k);
          if (dt != null && dt.difference(oldDoseTime).inMinutes.abs() <= 15) {
            matchedOldKey = k;
            break;
          }
        }
      }
      if (matchedOldKey != null) {
        updatedMap.remove(matchedOldKey);
      }

      updatedMap[newDoseTime.toIso8601String()] = newStatus;

      await docRef.update({
        'doseStatus': updatedMap.map((k, v) => MapEntry(k, v.value)),
      }).timeout(
        const Duration(milliseconds: 1500),
        onTimeout: () {
          debugPrint('deferOrMoveSingleDose aplicado en caché local offline.');
        },
      );

      final updatedTratamiento = t.copyWith(doseStatus: updatedMap);
      try {
        WidgetService.updateWidgetData(userId: userId);
      } catch (_) {}
      return updatedTratamiento;
    } catch (e) {
      debugPrint('Error en deferOrMoveSingleDose: $e');
      return null;
    }
  }

  /// Actualiza el estado de una dosis específica dentro de un tratamiento.
  ///
  /// Soporta operación tanto online (vía transacción) como 100% offline (usando
  /// la persistencia local de Firestore y el registro local de [PreferenceService]),
  /// evitando además que una alarma tardía sobrescriba con `notificada` una dosis
  /// que el usuario ya marcó como `tomada` u `omitida`.
  Future<ProcesarTomaResult?> updateDoseStatus(
    String userId,
    String docId,
    DateTime doseTime,
    DoseStatus newStatus, [
    CaregiverProfile? profile,
  ]) async {
    final prefs = PreferenceService();

    // 1. Registrar inmediatamente en el ledger local (<5ms, 100% offline-safe)
    final bool allowedByLocal = await prefs.saveLocalDoseStatus(
      userId: userId,
      docId: docId,
      doseTime: doseTime,
      status: newStatus.value,
      profileId: profile?.id,
      queueForSync: true,
      preventOverwriteCompleted: newStatus == DoseStatus.notificada,
    );

    if (!allowedByLocal && newStatus == DoseStatus.notificada) {
      debugPrint("updateDoseStatus: La dosis $doseTime ya fue tomada u omitida localmente; se omite sobrescritura a notificada.");
      return null;
    }

    DocumentReference docRef = getMedicamentoDocRef(userId, docId, profile);
    
    // Si no se pasó profile, verificar si el documento existe en la ruta personal
    // o si debe resolverse en perfiles gestionados (modo animales / cuidador)
    if (profile == null) {
      try {
        final initialSnap = await _getDocFast(docRef);
        if (!initialSnap.exists) {
          final resolved = await resolveMedicamentoWithProfile(userId, docId);
          if (resolved != null) {
            docRef = resolved.docRef;
            profile = resolved.profile;
          }
        }
      } catch (e) {
        debugPrint("Error preliminar resolviendo docRef: $e");
      }
    }

    debugPrint("Attempting to robustly update status for doc: ${docRef.path}");

    ProcesarTomaResult? inventoryResult;

    // 2. Intentar actualización mediante lectura rápida + escritura compatible con caché offline.
    // Nota: _db.runTransaction falla siempre cuando no hay internet porque exige round-trip al servidor.
    // Por ello intentamos primero una transacción con timeout corto (1.5s) y, si el dispositivo
    // está offline o sin red, aplicamos inmediatamente la actualización sobre la caché local de Firestore.
    bool updatedInFirestore = false;

    try {
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return;

        final tratamiento = Tratamiento.fromFirestore(
          snapshot as DocumentSnapshot<Map<String, dynamic>>,
        );

        final updatedDoseStatus = Map<String, DoseStatus>.from(
          tratamiento.doseStatus,
        );
        final doseKey = doseTime.toIso8601String();
        final int tolerance = tratamiento.doseMatchToleranceMinutes;

        String targetKey = doseKey;
        if (!updatedDoseStatus.containsKey(doseKey)) {
          int bestDiff = tolerance + 1;
          for (final existingKey in updatedDoseStatus.keys) {
            final parsedDate = DateTime.tryParse(existingKey);
            if (parsedDate != null) {
              final diff = parsedDate.difference(doseTime).inMinutes.abs();
              if (diff <= 15 && diff < bestDiff) {
                bestDiff = diff;
                targetKey = existingKey;
              }
            }
          }
        }

        final previousStatus = updatedDoseStatus[targetKey];
        // No sobrescribir una toma ya completada con 'notificada'
        if (newStatus == DoseStatus.notificada &&
            (previousStatus == DoseStatus.tomada ||
                previousStatus == DoseStatus.omitida)) {
          return;
        }

        updatedDoseStatus[targetKey] = newStatus;

        var treatmentToSave = tratamiento;
        if (newStatus == DoseStatus.tomada &&
            previousStatus != DoseStatus.tomada) {
          inventoryResult = tratamiento.procesarToma();
          treatmentToSave = inventoryResult!.tratamiento;
        }

        final mapToSave = updatedDoseStatus.map(
          (key, value) => MapEntry(key, value.value),
        );

        transaction.update(docRef, {
          'doseStatus': mapToSave,
          'cantidadActual': treatmentToSave.cantidadActual,
          'cantidadTotalCaja': treatmentToSave.cantidadTotalCaja,
          'dosisPorToma': treatmentToSave.dosisPorToma,
        });
      }).timeout(const Duration(milliseconds: 1500));

      updatedInFirestore = true;
      await prefs.removePendingOfflineDoseAction(
        userId: userId,
        docId: docId,
        doseTimeIso: doseTime.toIso8601String(),
      );
      debugPrint("SUCCESS: Document status updated via transaction.");
    } catch (txError) {
      debugPrint("Transacción online omitida (modo offline/latencia): $txError. Aplicando vía caché local...");
    }

    // 3. Fallback offline-first usando la caché de persistencia local de Firestore
    if (!updatedInFirestore) {
      try {
        final snapshot = await _getDocFast(
          docRef,
          timeout: const Duration(milliseconds: 800),
        );
        if (snapshot.exists) {
          final tratamiento = Tratamiento.fromFirestore(snapshot);
          final updatedDoseStatus = Map<String, DoseStatus>.from(
            tratamiento.doseStatus,
          );
          final doseKey = doseTime.toIso8601String();

          String targetKey = doseKey;
          if (!updatedDoseStatus.containsKey(doseKey)) {
            for (final existingKey in updatedDoseStatus.keys) {
              final parsedDate = DateTime.tryParse(existingKey);
              if (parsedDate != null &&
                  parsedDate.difference(doseTime).inMinutes.abs() <= 15) {
                targetKey = existingKey;
                break;
              }
            }
          }

          final previousStatus = updatedDoseStatus[targetKey];
          if (!(newStatus == DoseStatus.notificada &&
              (previousStatus == DoseStatus.tomada ||
                  previousStatus == DoseStatus.omitida))) {
            updatedDoseStatus[targetKey] = newStatus;

            var treatmentToSave = tratamiento;
            if (newStatus == DoseStatus.tomada &&
                previousStatus != DoseStatus.tomada) {
              inventoryResult = tratamiento.procesarToma();
              treatmentToSave = inventoryResult!.tratamiento;
            }

            final mapToSave = updatedDoseStatus.map(
              (key, value) => MapEntry(key, value.value),
            );

            // docRef.update actualiza la caché local de Firestore de inmediato y encola la mutación
            await docRef.update({
              'doseStatus': mapToSave,
              'cantidadActual': treatmentToSave.cantidadActual,
              'cantidadTotalCaja': treatmentToSave.cantidadTotalCaja,
              'dosisPorToma': treatmentToSave.dosisPorToma,
            }).timeout(
              const Duration(milliseconds: 500),
              onTimeout: () {},
            );

            await prefs.removePendingOfflineDoseAction(
              userId: userId,
              docId: docId,
              doseTimeIso: doseTime.toIso8601String(),
            );
            debugPrint("SUCCESS: Estado de dosis aplicado en caché local de Firestore (Offline-First).");
          }
        }
      } catch (offlineError) {
        debugPrint("Acción conservada en cola local de PreferenceService para sincronización posterior: $offlineError");
      }
    }

    try {
      WidgetService.updateWidgetData(userId: userId);
    } catch (e) {
      debugPrint("Error actualizando widget tras cambio de dosis: $e");
    }
    return inventoryResult;
  }

  /// Sincroniza cualquier acción de dosis tomada/omitida/aplazada en segundo plano
  /// cuando Firebase no estaba disponible.
  Future<void> syncPendingOfflineActions(String userId) async {
    final prefs = PreferenceService();
    final pending = await prefs.getPendingOfflineDoseActions();
    if (pending.isEmpty) return;

    for (final action in pending) {
      final actionUserId = action['userId'] as String?;
      final docId = action['docId'] as String?;
      final doseTimeIso = action['doseTimeIso'] as String?;
      final statusStr = action['status'] as String?;
      final profileId = action['profileId'] as String?;

      if (actionUserId != userId ||
          docId == null ||
          doseTimeIso == null ||
          statusStr == null) {
        continue;
      }

      final doseTime = DateTime.tryParse(doseTimeIso);
      if (doseTime == null) {
        await prefs.removePendingOfflineDoseAction(
          userId: actionUserId!,
          docId: docId,
          doseTimeIso: doseTimeIso,
        );
        continue;
      }

      try {
        final resolved = await resolveMedicamentoWithProfile(
          userId,
          docId,
          profileId: profileId,
        );
        await updateDoseStatus(
          userId,
          docId,
          doseTime,
          DoseStatus.fromString(statusStr),
          resolved?.profile,
        );
      } catch (e) {
        debugPrint("Error sincronizando acción offline pendiente ($docId @ $doseTimeIso): $e");
      }
    }
  }

  /// Vincula un paciente al cuidador actual usando su correo electrónico
  Future<void> linkPatient(String userId, String patientEmail) async {
    final query = await _db
        .collection('users')
        .where('email', isEqualTo: patientEmail.trim().toLowerCase())
        .limit(1)
        .get();
    if (query.docs.isEmpty) {
      throw Exception('No se encontró ningún usuario con ese correo electrónico.');
    }
    final patientId = query.docs.first.id;
    // Guardar en el perfil del cuidador el UID y email del paciente
    await saveUserProfile(userId, {'patientUid': patientId, 'patientEmail': patientEmail});
    // Guardar en el perfil del paciente el UID del cuidador
    await saveUserProfile(patientId, {'caregiverUid': userId});
  }

  /// Desvincula el paciente del cuidador
  Future<void> unlinkPatient(String userId) async {
    final doc = await getUserProfile(userId);
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>?;
      final patientId = data?['patientUid'] as String?;
      if (patientId != null) {
        await saveUserProfile(patientId, {'caregiverUid': null});
      }
    }
    await saveUserProfile(userId, {'patientUid': null, 'patientEmail': null});
  }

  /// Asegura de forma idempotente que el paciente tenga registrado al cuidador
  /// para garantizar permisos de acceso y consistencia bidireccional en Firestore.
  Future<void> ensureCaregiverLink(String caregiverUid, String patientUid) async {
    try {
      await _db.collection('users').doc(patientUid).set({
        'caregiverUid': caregiverUid,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Aviso al asegurar vínculo de cuidador con el paciente $patientUid: $e');
    }
  }

  // --- Historial de Chat con IA ---

  /// Obtiene la lista de chats ordenados por fecha de actualización
  Stream<QuerySnapshot> getChatSessionsStream(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('chats')
        .orderBy('lastUpdated', descending: true)
        .snapshots();
  }

  /// Guarda una sesión de chat (crea o actualiza)
  Future<void> saveChatSession(
    String userId,
    String chatId,
    String title,
    List<Map<String, dynamic>> messages,
  ) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('chats')
        .doc(chatId)
        .set({
      'title': title,
      'lastUpdated': FieldValue.serverTimestamp(),
      'messages': messages,
    }, SetOptions(merge: true));
  }

  /// Elimina una sesión de chat
  Future<void> deleteChatSession(String userId, String chatId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('chats')
        .doc(chatId)
        .delete();
  }

  /// Elimina todas las sesiones de chat de un usuario
  Future<void> clearAllChatSessions(String userId) async {
    final query = await _db
        .collection('users')
        .doc(userId)
        .collection('chats')
        .get();
    
    final batch = _db.batch();
    for (final doc in query.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// Elimina permanentemente todos los datos asociados a un usuario en Firestore:
  /// tratamientos, perfiles gestionados, historial de chats y el perfil del usuario.
  Future<void> deleteUserData(String userId) async {
    // 1. Limpiar subcolección de medicamentos del usuario
    final medsQuery = await _db
        .collection('medicamentos')
        .doc(userId)
        .collection('userMedicamentos')
        .get();
    
    final batch1 = _db.batch();
    for (final doc in medsQuery.docs) {
      batch1.delete(doc.reference);
    }
    batch1.delete(_db.collection('medicamentos').doc(userId));
    await batch1.commit();

    // 2. Limpiar chats
    await clearAllChatSessions(userId);

    // 3. Limpiar perfiles gestionados (managed_profiles) y sus medicamentos
    final profilesQuery = await _db
        .collection('users')
        .doc(userId)
        .collection('managed_profiles')
        .get();

    for (final profileDoc in profilesQuery.docs) {
      final data = profileDoc.data();
      // Si el perfil gestionado era un usuario externo vinculado, desvincularnos primero
      if (data['isExternalUser'] == true && data['linkedUid'] != null) {
        try {
          await _db.collection('users').doc(data['linkedUid'] as String).update({
            'caregiverUid': null,
            'caregivers': FieldValue.arrayRemove([userId]),
          });
        } catch (_) {}
      }
      final profileMeds = await profileDoc.reference.collection('userMedicamentos').get();
      if (profileMeds.docs.isNotEmpty) {
        final profileBatch = _db.batch();
        for (final medDoc in profileMeds.docs) {
          profileBatch.delete(medDoc.reference);
        }
        await profileBatch.commit();
      }
      await profileDoc.reference.delete();
    }

    // 4. Eliminar el documento de perfil principal del usuario
    await _db.collection('users').doc(userId).delete();

    // 5. Limpiar caché en memoria
    _medicamentosCache.clearAll();
  }
}
