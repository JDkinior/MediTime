// lib/screens/receta_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:meditime/services/notification_service.dart';
import 'package:meditime/services/auth_service.dart';
import 'package:meditime/services/firestore_service.dart';
import 'agregar_receta_page.dart';
import 'detalle_receta_page.dart';
import 'package:meditime/widgets/estado_vista.dart';
import 'package:meditime/enums/view_state.dart';

class RecetaPage extends StatefulWidget {
  const RecetaPage({super.key});

  @override
  State<RecetaPage> createState() => _RecetaPageState();
}

class _RecetaPageState extends State<RecetaPage> {

  // Lógica para generar y agrupar dosis.
  List<DateTime> _generarDosisDiarias(Map<String, dynamic> receta) {
    final DateTime fechaInicio = (receta['fechaInicioTratamiento'] as Timestamp).toDate();
    final DateTime fechaFin = (receta['fechaFinTratamiento'] as Timestamp).toDate();
    final int intervalo = int.parse(receta['intervaloDosis']);
    List<DateTime> dosis = [];
    DateTime dosisActual = fechaInicio;

    while (dosisActual.isBefore(fechaFin)) {
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
  
  // Lógica del diálogo ahora usa los servicios.
  void _showDeleteOptionsDialog(BuildContext dialogContext, Map<String, dynamic> medicamento) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final user = authService.currentUser;

    if (user == null) return;

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
              child: const Text('Omitir solo esta toma',
                  style: TextStyle(color: Colors.blue)),
              onPressed: () async {
                final navigator = Navigator.of(context);
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                final DocumentReference docRef = firestoreService.getMedicamentoDocRef(user.uid, medicamento['docId']);

                navigator.pop(); // Cierra el diálogo

                // *** REFACTORIZACIÓN CLAVE ***
                // Toda la lógica compleja se reemplaza por una sola llamada al servicio.
                final bool success =
                    await NotificationService.skipNextDoseAndReschedule(
                  tratamiento: medicamento,
                  docRef: docRef,
                );
                // *** FIN DE LA REFACTORIZACIÓN ***

                if (scaffoldMessenger.mounted) {
                  if (success) {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                          content: Text('Próxima dosis omitida y reprogramada.')),
                    );
                  } else {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                          content: Text('No hay próximas dosis para omitir.')),
                    );
                  }
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
                  await NotificationService.cancelTreatmentAlarms(alarmId);
                }

                await firestoreService.deleteTratamiento(user.uid, medicamento['docId']);

                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text('Tratamiento eliminado.')),
                );
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
    // CAMBIO: Obtener los servicios
    final authService = context.watch<AuthService>();
    final firestoreService = context.watch<FirestoreService>();
    final user = authService.currentUser;

    return Scaffold(
      // CAMBIO: El StreamBuilder ahora usa el stream del servicio
      body: user == null
          ? const Center(child: Text('Inicia sesión para ver tus recetas.'))
          : StreamBuilder<QuerySnapshot>(
              stream: firestoreService.getMedicamentosStream(user.uid),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const EstadoVista(state: ViewState.loading, child: SizedBox.shrink());
              }
              if (snapshot.hasError) {
                return EstadoVista(
                  state: ViewState.error,
                  errorMessage: 'Ocurrió un error al cargar las recetas.',
                  onRetry: () {
                    // Lógica para reintentar la carga si es necesario
                    setState(() {});
                  },
                  child: const SizedBox.shrink(),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const EstadoVista(
                  state: ViewState.empty,
                  emptyMessage: 'Aún no has agregado ninguna receta. ¡Añade una para empezar!',
                  child: SizedBox.shrink(),
                );
              }

              return EstadoVista(
                state: ViewState.success,
                child: Builder( // Usamos un Builder para que el contexto sea correcto
                  builder: (context) {
                    // La lógica para procesar los datos no cambia.
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

                    if (todasDosis.isEmpty) {
                      return const EstadoVista(
                        state: ViewState.empty,
                        emptyMessage: 'No tienes dosis futuras programadas. ¡Añade una nueva receta o revisa tus tratamientos pasados en el calendario!',
                        child: SizedBox.shrink(),
                      );
                    }

                todasDosis.sort((a, b) => a['horaDosis'].compareTo(b['horaDosis']));

                final dosisAgrupadas = _agruparPorFecha(todasDosis.map((d) => d['horaDosis'] as DateTime).toList());

                // Crear un mapa de búsqueda para acceso O(1)
                final Map<DateTime, Map<String, dynamic>> dosisLookup = {
                  for (var d in todasDosis) d['horaDosis'] as DateTime: d
                };

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
                            final medicamento = dosisLookup[hora];
                            return _buildDosisCard(medicamento!, context);
                          }),
                        ],
                      ),
                  ],
                    );
                  }
                ),
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