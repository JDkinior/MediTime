// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:meditime/services/tratamiento_service.dart';
import 'package:meditime/core/stream_cache.dart';

/// Servicio para interactuar con la base de datos de Cloud Firestore.
///
/// Abstrae todas las operaciones de lectura y escritura (CRUD) para los datos
/// de la aplicación, como perfiles de usuario y tratamientos.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final StreamCache<String, List<Tratamiento>> _medicamentosCache = StreamCache<String, List<Tratamiento>>();

  FirestoreService() {
    _db.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
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
    return _db.collection('users').doc(userId).get();
  }

  // --- Medicamentos ---

  /// Obtiene un `Stream` con la lista de todos los tratamientos de un usuario.
  ///
  /// El `Stream` se actualiza automáticamente cuando hay cambios en Firestore.
  /// Transforma los documentos de Firestore en una lista de objetos `Tratamiento`.
  Stream<List<Tratamiento>> getMedicamentosStream(String userId) {
    return _medicamentosCache.getStream(userId, () {
      return _db
          .collection('medicamentos')
          .doc(userId)
          .collection('userMedicamentos')
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
  List<Tratamiento>? getCachedMedicamentos(String userId) {
    return _medicamentosCache.getLastValue(userId);
  }

  /// Guarda un nuevo tratamiento en la base de datos para un usuario específico.
  Future<DocumentReference> saveMedicamento({
    required String userId,
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
  }) {
    // Para tratamientos indefinidos o muy largos, no generamos todas las dosis
    // El sistema lazy se encargará de generarlas bajo demanda
    final treatmentDuration = fechaFinTratamiento.difference(
      fechaInicioTratamiento,
    );
    final isLongTreatment = treatmentDuration.inDays > 365; // Más de 1 año

    Map<String, String> doseStatusMap = {};

    if (!isLongTreatment) {
      // Solo para tratamientos cortos generamos todas las dosis
      final tratamientoService = TratamientoService();
      final tempTratamiento = Tratamiento(
        id: '',
        nombreMedicamento: nombreMedicamento,
        presentacion: presentacion,
        duracion: duracion,
        cantidadActual: cantidadActual,
        cantidadTotalCaja: cantidadTotalCaja,
        dosisPorToma: dosisPorToma,
        horaPrimeraDosis: horaPrimeraDosis,
        intervaloDosis: intervaloDosis,
        prescriptionAlarmId: prescriptionAlarmId,
        fechaInicioTratamiento: fechaInicioTratamiento,
        fechaFinTratamiento: fechaFinTratamiento,
      );

      final List<DateTime> todasLasDosis = tratamientoService
          .generarDosisTotales(tempTratamiento);
      doseStatusMap = {
        for (var dosis in todasLasDosis)
          dosis.toIso8601String():
              DoseStatus.pendiente.toString().split('.').last,
      };
    }
    // Para tratamientos largos, el mapa de dosis se mantiene vacío inicialmente

    return _db
        .collection('medicamentos')
        .doc(userId)
        .collection('userMedicamentos')
        .add({
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
          'fechaInicioTratamiento': Timestamp.fromDate(fechaInicioTratamiento),
          'fechaFinTratamiento': Timestamp.fromDate(fechaFinTratamiento),
          'skippedDoses': [],
          'notas': notas,
          'doseStatus': doseStatusMap,
        });
  }

  /// Elimina un documento de tratamiento específico.
  Future<void> deleteTratamiento(String userId, String docId) {
    return _db
        .collection('medicamentos')
        .doc(userId)
        .collection('userMedicamentos')
        .doc(docId)
        .delete();
  }

  /// Elimina todos los tratamientos de un usuario de la base de datos y
  /// retorna la lista de tratamientos eliminados para poder cancelar sus alarmas.
  Future<List<Tratamiento>> clearAllMedicamentos(String userId) async {
    final snapshot = await _db
        .collection('medicamentos')
        .doc(userId)
        .collection('userMedicamentos')
        .get();

    final List<Tratamiento> tratamientos = [];
    final batch = _db.batch();

    for (var doc in snapshot.docs) {
      final tratamiento = Tratamiento.fromFirestore(
        doc as DocumentSnapshot<Map<String, dynamic>>,
      );
      tratamientos.add(tratamiento);
      batch.delete(doc.reference);
    }

    await batch.commit();
    _medicamentosCache.clearKey(userId);
    return tratamientos;
  }

  /// Obtiene la referencia a un documento de tratamiento específico.
  /// Útil para realizar actualizaciones o lecturas directas.
  DocumentReference getMedicamentoDocRef(String userId, String docId) {
    return _db
        .collection('medicamentos')
        .doc(userId)
        .collection('userMedicamentos')
        .doc(docId);
  }

  /// Actualiza el mapa completo de dosis de un tratamiento
  Future<void> updateTreatmentDoses(
    String userId,
    String docId,
    Map<String, String> doseStatusMap,
  ) async {
    final docRef = getMedicamentoDocRef(userId, docId);

    try {
      await docRef.update({'doseStatus': doseStatusMap});
      debugPrint("SUCCESS: Treatment doses updated for doc: ${docRef.path}");
    } catch (e) {
      debugPrint("ERROR updating treatment doses: $e");
      rethrow;
    }
  }

  /// Actualiza el estado de una dosis específica dentro de un tratamiento.
  ///
  /// Utiliza una transacción de Firestore para garantizar que la lectura y escritura
  /// de los datos sea atómica y consistente, evitando condiciones de carrera.
  Future<ProcesarTomaResult?> updateDoseStatus(
    String userId,
    String docId,
    DateTime doseTime,
    DoseStatus newStatus,
  ) async {
    final docRef = getMedicamentoDocRef(userId, docId);
    debugPrint("Attempting to robustly update status for doc: ${docRef.path}");

    try {
      ProcesarTomaResult? inventoryResult;

      // Usamos una transacción para garantizar la consistencia de los datos
      await _db.runTransaction((transaction) async {
        // 1. Leer el documento dentro de la transacción.
        final snapshot = await transaction.get(docRef);

        if (!snapshot.exists) {
          debugPrint(
            "ERROR: Document not found in transaction. Cannot update.",
          );
          return;
        }

        // 2. Crear el objeto Tratamiento a partir de los datos.
        final tratamiento = Tratamiento.fromFirestore(
          snapshot as DocumentSnapshot<Map<String, dynamic>>,
        );

        // 3. Modificar el mapa de estados en la memoria local.
        final updatedDoseStatus = Map<String, DoseStatus>.from(
          tratamiento.doseStatus,
        );
        final doseKey = doseTime.toIso8601String();
        final previousStatus = updatedDoseStatus[doseKey];
        updatedDoseStatus[doseKey] = newStatus;

        var treatmentToSave = tratamiento;
        if (newStatus == DoseStatus.tomada &&
            previousStatus != DoseStatus.tomada) {
          inventoryResult = tratamiento.procesarToma();
          treatmentToSave = inventoryResult!.tratamiento;
        }

        // 4. Convertimos el mapa de Enum a un mapa de String para guardarlo en Firestore.
        final mapToSave = updatedDoseStatus.map(
          (key, value) => MapEntry(key, value.toString().split('.').last),
        );

        // 5. Actualizamos el campo 'doseStatus' completo en el documento.
        transaction.update(docRef, {
          'doseStatus': mapToSave,
          'cantidadActual': treatmentToSave.cantidadActual,
          'cantidadTotalCaja': treatmentToSave.cantidadTotalCaja,
          'dosisPorToma': treatmentToSave.dosisPorToma,
        });
      });

      debugPrint("SUCCESS: Document status updated via transaction.");
      return inventoryResult;
    } catch (e) {
      debugPrint("Firebase transaction error during updateDoseStatus: $e");
      return null;
    }
  }

  /// Vincula un paciente al cuidador actual usando su correo electrónico
  Future<void> linkPatient(String userId, String patientEmail) async {
    final query = await _db.collection('users').where('email', isEqualTo: patientEmail).get();
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
}
