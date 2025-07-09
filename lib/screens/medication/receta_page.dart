// lib/screens/medication/receta_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meditime/models/tratamiento.dart'; // Importamos el modelo Tratamiento
import 'package:provider/provider.dart';
import 'package:meditime/services/notification_service.dart';
import 'package:meditime/services/auth_service.dart';
import 'package:meditime/services/firestore_service.dart';
import 'agregar_receta_page.dart';
import 'detalle_receta_page.dart';
import 'package:meditime/widgets/estado_vista.dart';
import 'package:meditime/enums/view_state.dart';
import 'package:meditime/services/tratamiento_service.dart';

class RecetaPage extends StatefulWidget {
  const RecetaPage({super.key});

  @override
  State<RecetaPage> createState() => _RecetaPageState();
}

class _RecetaPageState extends State<RecetaPage> {

  // Agrupa una lista de fechas por día para mostrarlas en la UI.
  Map<String, List<DateTime>> _agruparPorFecha(List<DateTime> dosis) {
    Map<String, List<DateTime>> agrupadas = {};
    final formatter = DateFormat('EEEE, d MMMM', 'es_ES');
    for (var hora in dosis) {
      final fechaKey = formatter.format(hora);
      agrupadas.putIfAbsent(fechaKey, () => []).add(hora);
    }
    return agrupadas;
  }

  // El diálogo ahora recibe el objeto Tratamiento directamente.
  void _showDeleteOptionsDialog(BuildContext dialogContext, Tratamiento tratamiento) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final user = authService.currentUser;

    if (user == null) return;

    showDialog(
      context: dialogContext,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
          title: const Text('Eliminar'),
          content: const Text('¿Qué te gustaría hacer con este tratamiento?'),
          actionsAlignment: MainAxisAlignment.center,
           actions: <Widget>[
            TextButton(
              child: const Text('Omitir próxima toma', style: TextStyle(color: Colors.blue)),
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  final docRef = firestoreService.getMedicamentoDocRef(user.uid, tratamiento.id);

                  // 1. Obtenemos los datos más recientes de Firestore.
                  final freshSnapshot = await docRef.get();
                  
                  // 2. Usamos nuestro factory constructor para convertir el snapshot en un objeto Tratamiento.
                  final freshTratamiento = Tratamiento.fromFirestore(freshSnapshot as DocumentSnapshot<Map<String, dynamic>>);

                  navigator.pop(); // Cierra el diálogo

                  // 3. Pasamos el objeto 'freshTratamiento' directamente al servicio.
                  final bool success =
                      await NotificationService.skipNextDoseAndReschedule(
                    tratamiento: freshTratamiento,
                    docRef: docRef,
                  );

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

                await NotificationService.cancelTreatmentAlarms(tratamiento.prescriptionAlarmId);
                await firestoreService.deleteTratamiento(user.uid, tratamiento.id);

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

  // La tarjeta de la dosis ahora recibe el Tratamiento y la hora específica.
  Widget _buildDosisCard(Tratamiento tratamiento, DateTime horaDosis, BuildContext context) {
    final horaFormateada = DateFormat('hh:mm a', 'es_ES').format(horaDosis);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => DetalleRecetaPage(
          // Pasamos el objeto directamente a la página de detalle.
          tratamiento: tratamiento,
          horaDosis: horaDosis,
        )),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 241, 241, 241),
          borderRadius: BorderRadius.circular(15),
          boxShadow: const [
             BoxShadow(
              color: Color.fromARGB(20, 47, 109, 180),
              blurRadius: 6,
              spreadRadius: 3,
              offset: Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Text(horaFormateada, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue)),
            Container(
              height: 60,
              width: 3,
              color: Colors.blue,
              margin: const EdgeInsets.symmetric(horizontal: 20)
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tratamiento.nombreMedicamento, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
                  const SizedBox(height: 5),
                  Text('Dosis cada ${tratamiento.intervaloDosis} horas'),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Color.fromARGB(255, 247, 128, 120)),
              onPressed: () => _showDeleteOptionsDialog(context, tratamiento),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final firestoreService = context.watch<FirestoreService>();
    final user = authService.currentUser;

    return Scaffold(
      body: user == null
          ? const Center(child: Text('Inicia sesión para ver tus recetas.'))
          // El StreamBuilder ahora espera una `List<Tratamiento>`.
          : StreamBuilder<List<Tratamiento>>(
              stream: firestoreService.getMedicamentosStream(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const EstadoVista(state: ViewState.loading, child: SizedBox.shrink());
                }
                if (snapshot.hasError) {
                  return EstadoVista(
                    state: ViewState.error,
                    errorMessage: 'Ocurrió un error al cargar las recetas.',
                    onRetry: () => setState(() {}),
                    child: const SizedBox.shrink(),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const EstadoVista(
                    state: ViewState.empty,
                    emptyMessage: 'Aún no has agregado ninguna receta. ¡Añade una para empezar!',
                    child: SizedBox.shrink(),
                  );
                }

                  return EstadoVista(
                    state: ViewState.success,
                    child: Builder(builder: (context) {
                      final todosLosTratamientos = snapshot.data!;
                      // Creamos una instancia del servicio aquí
                      final tratamientoService = TratamientoService();
                      final Map<DateTime, Tratamiento> mapaDeDosis = {};

                      for (var tratamiento in todosLosTratamientos) {
                        // Usamos el servicio para generar las dosis
                        final dosisGeneradas = tratamientoService.generarDosisPendientes(tratamiento);
                        for (var horaDosis in dosisGeneradas) {
                          mapaDeDosis[horaDosis] = tratamiento;
                        }
                      }

                    if (mapaDeDosis.isEmpty) {
                      return const EstadoVista(
                        state: ViewState.empty,
                        emptyMessage: 'No tienes dosis futuras programadas. ¡Añade una nueva receta!',
                        child: SizedBox.shrink(),
                      );
                    }

                    final todasLasHoras = mapaDeDosis.keys.toList()..sort();
                    final dosisAgrupadasPorFecha = _agruparPorFecha(todasLasHoras);

                    return ListView(
                      children: dosisAgrupadasPorFecha.entries.map((entry) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Text(entry.key, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                            ),
                            ...entry.value.map((hora) {
                              final tratamiento = mapaDeDosis[hora]!;
                              return _buildDosisCard(tratamiento, hora, context);
                            }),
                          ],
                        );
                      }).toList(),
                    );
                  }),
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