// lib/screens/receta_page.dart

// Imports necesarios (asegúrate de que todos estén presentes)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:meditime/alarm_callback_handler.dart';
import 'agregar_receta_page.dart';
import 'detalle_receta_page.dart';


// --- PASO 1: CONVERTIR A STATEFULWIDGET ---

class RecetaPage extends StatefulWidget {
  const RecetaPage({super.key});

  @override
  State<RecetaPage> createState() => _RecetaPageState();
}

class _RecetaPageState extends State<RecetaPage> {
  // Mueve toda la lógica y el método build dentro de la clase _RecetaPageState

  List<DateTime> _generarDosisDiarias(Map<String, dynamic> receta) {
    // CAMBIO 1: Usar las fechas de inicio y fin reales del tratamiento guardadas en Firestore.
    final DateTime fechaInicio = (receta['fechaInicioTratamiento'] as Timestamp).toDate();
    final DateTime fechaFin = (receta['fechaFinTratamiento'] as Timestamp).toDate();
    final int intervalo = int.parse(receta['intervaloDosis']);
    List<DateTime> dosis = [];
    
    // CAMBIO 2: Empezar el cálculo desde la fecha de inicio real.
    DateTime dosisActual = fechaInicio;

    // CAMBIO 3: El bucle debe continuar mientras la dosis sea ANTES de la fecha de fin.
    while (dosisActual.isBefore(fechaFin)) {
      // Solo mostramos las dosis que aún no han pasado.
      if (dosisActual.isAfter(DateTime.now().subtract(const Duration(minutes: 1)))) {
        dosis.add(dosisActual);
      }
      dosisActual = dosisActual.add(Duration(hours: intervalo));
    }

    return dosis;
  }

  Map<String, List<DateTime>> _agruparPorFecha(List<DateTime> dosis) {
    Map<String, List<DateTime>> agrupadas = {};
    final formatter = DateFormat('EEEE, d MMMM', 'es_ES');
    
    for (var hora in dosis) {
      final fechaKey = formatter.format(hora);
      agrupadas.putIfAbsent(fechaKey, () => []).add(hora);
    }
    
    return agrupadas;
  }

  // --- PASO 2: CORREGIR LA LÓGICA ASÍNCRONA EN EL DIÁLOGO ---

  void _showDeleteOptionsDialog(BuildContext dialogContext, Map<String, dynamic> medicamento) {
    showDialog(
      context: dialogContext,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
          title: const Text('Eliminar Dosis'),
          content: const Text('¿Qué te gustaría hacer con esta toma?'),
          actionsAlignment: MainAxisAlignment.center,
          actions: <Widget>[
            TextButton(
              child: const Text('Omitir solo esta toma', style: TextStyle(color: Colors.blue)),
              onPressed: () async {
                // Guardamos una referencia al Navigator y al ScaffoldMessenger ANTES del 'await'.
                // Usamos el 'context' del diálogo para cerrarlo.
                final navigator = Navigator.of(context);
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                
                navigator.pop();
                
                // Lógica de cancelar y reprogramar
                final String docId = medicamento['docId'];
                final int alarmId = medicamento['prescriptionAlarmId'];
                final DateTime horaDosisOmitida = medicamento['horaDosis'];
                final int intervalo = int.parse(medicamento['intervaloDosis']);
                final DateTime fechaFinTratamiento = (medicamento['fechaFinTratamiento'] as Timestamp).toDate();

                await AndroidAlarmManager.cancel(alarmId);

                final DateTime proximaDosis = horaDosisOmitida.add(Duration(hours: intervalo));

                if (proximaDosis.isBefore(fechaFinTratamiento)) {
                  final params = {
                    'currentNotificationId': medicamento['currentNotificationId'] ?? 0,
                    'nombreMedicamento': medicamento['nombreMedicamento'],
                    'presentacion': medicamento['presentacion'],
                    'intervaloHoras': intervalo,
                    'fechaFinTratamientoString': fechaFinTratamiento.toIso8601String(),
                    'prescriptionAlarmId': alarmId,
                  };
                  await AndroidAlarmManager.oneShotAt(proximaDosis, alarmId, alarmCallbackLogic, exact: true, wakeup: true, alarmClock: true, rescheduleOnReboot: true, params: params);
                }

                final docRef = FirebaseFirestore.instance.collection('medicamentos').doc(FirebaseAuth.instance.currentUser?.uid).collection('userMedicamentos').doc(docId);
                await docRef.update({'skippedDoses': FieldValue.arrayUnion([Timestamp.fromDate(horaDosisOmitida)])});
                
                // --- La comprobación de seguridad 'mounted' ---
                // Ahora podemos usar 'mounted' porque estamos en un StatefulWidget.
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(content: Text('Dosis omitida y reprogramada.'), duration: Duration(seconds: 2)),
                  );
                }
              },
            ),
            TextButton(
              child: const Text('Eliminar tratamiento', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                final navigator = Navigator.of(context);
                final scaffoldMessenger = ScaffoldMessenger.of(context);

                navigator.pop();

                final alarmId = medicamento['prescriptionAlarmId'];
                if (alarmId != null) {
                  await AndroidAlarmManager.cancel(alarmId);
                }
                
                await FirebaseFirestore.instance.collection('medicamentos').doc(FirebaseAuth.instance.currentUser?.uid).collection('userMedicamentos').doc(medicamento['docId']).delete();
                
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(content: Text('Tratamiento eliminado.'), duration: Duration(seconds: 2)),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildDosisCard(Map<String, dynamic> medicamento, BuildContext context) {
    final horaFormateada = DateFormat('hh:mm a').format(medicamento['horaDosis']);
    
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => DetalleRecetaPage(receta: medicamento)),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 241, 241, 241),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: const Color.fromARGB(20, 47, 109, 180),
              blurRadius: 6,
              spreadRadius: 3,
              offset: const Offset(0, 4)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    horaFormateada,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                ],
              ),
              Container(
                height: 60,
                width: 3,
                color: Colors.blue,
                margin: const EdgeInsets.symmetric(horizontal: 20)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medicamento['nombreMedicamento'],
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                    const SizedBox(height: 5),
                    Text('Dosis cada ${medicamento['intervaloDosis']} horas'),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Color.fromARGB(255, 247, 128, 120)),
                onPressed: () {
                  _showDeleteOptionsDialog(context, medicamento);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('medicamentos')
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .collection('userMedicamentos')
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.hasError) {
            print('Error en StreamBuilder: ${snapshot.error}');
            return const Center(child: Text('Ocurrió un error al cargar las recetas.'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('Aún no has agregado ninguna receta', style: TextStyle(fontSize: 20)),
            );
          }

          List<Map<String, dynamic>> todasDosis = [];
          for (var recetaDoc in snapshot.data!.docs) {
            final datos = recetaDoc.data() as Map<String, dynamic>;
            final List<dynamic> skippedDosesRaw = datos['skippedDoses'] ?? [];
            final List<DateTime> skippedDoses = skippedDosesRaw.map((ts) => (ts as Timestamp).toDate()).toList();
            final dosisGeneradas = _generarDosisDiarias(datos);
            for (var horaDosis in dosisGeneradas) {
              bool esOmitida = skippedDoses.any((skippedTime) => skippedTime.isAtSameMomentAs(horaDosis));
              if (!esOmitida) {
                todasDosis.add({'docId': recetaDoc.id, ...datos, 'horaDosis': horaDosis});
              }
            }
          }

          todasDosis.sort((a, b) => a['horaDosis'].compareTo(b['horaDosis']));

          final dosisAgrupadas = _agruparPorFecha(todasDosis.map((d) => d['horaDosis'] as DateTime).toList());

          return ListView(
            children: [
              for (var entrada in dosisAgrupadas.entries)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        entrada.key,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                      ),
                    ),
                    ...entrada.value.map((hora) {
                      final medicamento = todasDosis.firstWhere((d) => d['horaDosis'] == hora);
                      return _buildDosisCard(medicamento, context);
                    }),
                  ],
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const AgregarRecetaPage()));
        },
        tooltip: 'Agregar Medicamento',
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        backgroundColor: Colors.transparent,
        heroTag: 'uniqueTag1',
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color.fromARGB(255, 73, 194, 255), Color.fromARGB(255, 47, 109, 180)],
            ),
          ),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }
}