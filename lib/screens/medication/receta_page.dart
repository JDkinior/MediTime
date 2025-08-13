// lib/screens/medication/receta_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meditime/models/tratamiento.dart'; // Importamos el modelo Tratamiento
import 'package:meditime/theme/app_theme.dart';
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

  // --- INICIO DE LA MODIFICACIÓN ---
  // Esta función ahora agrupa los datos de las dosis, no solo las fechas.
  Map<String, List<Map<String, dynamic>>> _agruparDosisPorFecha(List<Map<String, dynamic>> dosis) {
    Map<String, List<Map<String, dynamic>>> agrupadas = {};
    final formatter = DateFormat('EEEE, d MMMM', 'es_ES');
    for (var dosisData in dosis) {
      final fechaKey = formatter.format(dosisData['doseTime']);
      agrupadas.putIfAbsent(fechaKey, () => []).add(dosisData);
    }
    return agrupadas;
  }

  // --- INICIO DE LA MODIFICACIÓN: Nueva función para manejar la acción del menú ---

  // El diálogo ahora recibe el objeto Tratamiento directamente.
   void _showDoseOptionsDialog(BuildContext context, Tratamiento tratamiento, DateTime doseTime) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final user = authService.currentUser;
    if (user == null) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text('Opciones de la Dosis', style: TextStyle(fontSize: 22, color: kSecondaryColor, fontWeight: FontWeight.w500)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.alarm_off, color: Colors.orange),
                title: const Text('Omitir esta dosis'),
                onTap: () async {
                  Navigator.of(context).pop(); // Cerrar el diálogo
                  await firestoreService.updateDoseStatus(user.uid, tratamiento.id, doseTime, DoseStatus.omitida);
                  final doc = await firestoreService.getMedicamentoDocRef(user.uid, tratamiento.id).get();
                  if (doc.exists) {
                    final updatedTratamiento = Tratamiento.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
                    await NotificationService.rescheduleNextPendingDose(updatedTratamiento, user.uid);
                  }
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(content: Text('Dosis omitida y alarma reprogramada.')),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('Eliminar tratamiento', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.of(context).pop(); // Cerrar el diálogo
                  // Mostrar un diálogo de confirmación adicional si es necesario
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        title: const Text('Confirmar eliminación', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        content: const Text('¿Estás seguro de que deseas eliminar este tratamiento?'),
                        actions: <Widget>[
                          TextButton(
                            child: const Text('Cancelar'),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                          TextButton(
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                            child: const Text('Eliminar'),
                            onPressed: () async {
                              Navigator.of(context).pop(); // Cerrar el diálogo de confirmación
                              // Revocar localmente para impedir callbacks offline
                              await NotificationService.revokeTreatmentLocally(user.uid, tratamiento.id);
                              // Cancelar serie de alarmas de Android para este tratamiento
                              await NotificationService.cancelTreatmentAlarms(tratamiento.prescriptionAlarmId);
                              // Cancelar notificaciones activas visibles
                              await NotificationService.cancelAllActiveAndroidNotifications();
                              // Cancelar también todas las notificaciones programadas (incluye snoozes)
                              await NotificationService.cancelAllFlutterLocalNotifications();
                              // Eliminar en Firestore
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
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // La tarjeta de la dosis ahora recibe el mapa de datos de la dosis
  Widget _buildDosisCard(Map<String, dynamic> doseData, BuildContext context) {
    final Tratamiento tratamiento = doseData['tratamiento'];
    final DateTime horaDosis = doseData['doseTime'];
    final horaFormateada = DateFormat('hh:mm a', 'es_ES').format(horaDosis);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => DetalleRecetaPage(
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
                  Text('Dosis cada ${tratamiento.intervaloDosis.inHours} horas'),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _showDoseOptionsDialog(context, tratamiento, horaDosis),
              // Hacemos que toda el área del contenedor sea sensible al tacto, incluso las partes transparentes.
              behavior: HitTestBehavior.opaque,
              child: Container(
                // Un color transparente es necesario para que `behavior` funcione correctamente.
                color: Colors.transparent,
                // Añadimos padding para aumentar el área de toque y mover el ícono.
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
                child: const Icon(Icons.more_vert, color: Colors.grey),
              ),
            )
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
          : StreamBuilder<List<Tratamiento>>(
              stream: firestoreService.getMedicamentosStream(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const EstadoVista(state: ViewState.loading, child: SizedBox.shrink());
                }
                if (snapshot.hasError) {
                  // Este es el error que estás viendo.
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
                    // --- INICIO DE LA MODIFICACIÓN: Lógica central actualizada ---
                    final todosLosTratamientos = snapshot.data!;
                    final List<Map<String, dynamic>> dosisPendientes = [];

                    // 1. Recorremos los tratamientos y sus mapas de estado
                    for (var tratamiento in todosLosTratamientos) {
                      tratamiento.doseStatus.forEach((dateString, status) {
                        final doseTime = DateTime.parse(dateString);
                        // 2. Solo nos interesan las dosis futuras que están 'pendientes'
                        if (status == DoseStatus.pendiente && doseTime.isAfter(DateTime.now())) {
                          dosisPendientes.add({
                            'tratamiento': tratamiento,
                            'doseTime': doseTime,
                          });
                        }
                      });
                    }

                    // 3. Ordenamos todas las dosis cronológicamente
                    dosisPendientes.sort((a, b) => (a['doseTime'] as DateTime).compareTo(b['doseTime'] as DateTime));

                    if (dosisPendientes.isEmpty) {
                      return const EstadoVista(
                        state: ViewState.empty,
                        emptyMessage: 'No tienes dosis futuras programadas. ¡Añade una nueva receta!',
                        child: SizedBox.shrink(),
                      );
                    }

                    // 4. Agrupamos las dosis por día para mostrarlas en la UI
                    final dosisAgrupadasPorFecha = _agruparDosisPorFecha(dosisPendientes);

                    return ListView(
                      children: dosisAgrupadasPorFecha.entries.map((entry) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Text(entry.key, style: TextStyle(fontSize: 18, fontWeight: FontWeight.normal, color: Colors.grey[700])),
                            ),
                            // Usamos la nueva función _buildDosisCard
                            ...entry.value.map((doseData) => _buildDosisCard(doseData, context)),
                          ],
                        );
                      }).toList(),
                    );
                    // --- FIN DE LA MODIFICACIÓN ---
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