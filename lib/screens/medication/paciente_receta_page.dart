import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:meditime/services/firestore_service.dart';
import 'package:meditime/widgets/estado_vista.dart';
import 'package:meditime/enums/view_state.dart';
import 'package:meditime/screens/medication/detalle_receta_page.dart';
import 'package:provider/provider.dart';

class PacienteRecetaPage extends StatelessWidget {
  final String patientUid;
  final String patientEmail;

  const PacienteRecetaPage({
    super.key,
    required this.patientUid,
    required this.patientEmail,
  });

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.watch<FirestoreService>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Recetas de $patientEmail'),
      ),
      body: StreamBuilder<List<Tratamiento>>(
        stream: firestoreService.getMedicamentosStream(patientUid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const EstadoVista(state: ViewState.loading, child: SizedBox.shrink());
          }
          if (snapshot.hasError) {
            return const EstadoVista(
              state: ViewState.error,
              errorMessage: 'Ocurrió un error al cargar las recetas del paciente.',
              child: SizedBox.shrink(),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const EstadoVista(
              state: ViewState.empty,
              emptyMessage: 'El paciente aún no tiene medicamentos registrados.',
              child: SizedBox.shrink(),
            );
          }

          final todosLosTratamientos = snapshot.data!;
          final List<Map<String, dynamic>> dosisPendientes = [];

          for (var tratamiento in todosLosTratamientos) {
            tratamiento.doseStatus.forEach((dateString, status) {
              final doseTime = DateTime.parse(dateString);
              if (status == DoseStatus.pendiente && doseTime.isAfter(DateTime.now())) {
                dosisPendientes.add({
                  'tratamiento': tratamiento,
                  'doseTime': doseTime,
                });
              }
            });
          }

          dosisPendientes.sort((a, b) => (a['doseTime'] as DateTime).compareTo(b['doseTime'] as DateTime));

          if (dosisPendientes.isEmpty) {
            return const EstadoVista(
              state: ViewState.empty,
              emptyMessage: 'El paciente no tiene dosis futuras programadas.',
              child: SizedBox.shrink(),
            );
          }

          return ListView.builder(
            itemCount: dosisPendientes.length,
            itemBuilder: (context, index) {
              final doseData = dosisPendientes[index];
              final Tratamiento tratamiento = doseData['tratamiento'];
              final DateTime horaDosis = doseData['doseTime'];
              final horaFormateada = DateFormat('hh:mm a, d MMM', 'es_ES').format(horaDosis);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.medical_services, color: Colors.blue),
                  title: Text(tratamiento.nombreMedicamento),
                  subtitle: Text('Dosis: ${tratamiento.dosisPorToma} ${tratamiento.presentacion}\nPróxima toma: $horaFormateada'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DetalleRecetaPage(
                          tratamiento: tratamiento,
                          horaDosis: horaDosis,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
