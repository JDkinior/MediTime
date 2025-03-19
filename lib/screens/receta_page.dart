import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'agregar_receta_page.dart';
import 'detalle_receta_page.dart';

class RecetaPage extends StatelessWidget {
  const RecetaPage({super.key});

List<DateTime> _generarDosisDiarias(Map<String, dynamic> receta) {
  final horaInicial = DateFormat('HH:mm').parse(receta['horaPrimeraDosis']);
  final intervalo = int.parse(receta['intervaloDosis']);
  final duracionDias = int.parse(receta['duracion']);
  List<DateTime> dosis = [];
  
  DateTime dosisActual = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
    horaInicial.hour,
    horaInicial.minute,
  );

  final fechaFin = dosisActual.add(Duration(days: duracionDias));
  
  // Generar dosis hasta cubrir el periodo completo del tratamiento
  while (dosisActual.isBefore(fechaFin)) {
    // Solo agregar dosis futuras o de hoy
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
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'Aún no has agregado ninguna receta',
                style: TextStyle(fontSize: 20),
              ),
            );
          }

          List<Map<String, dynamic>> todasDosis = [];
          for (var receta in snapshot.data!.docs) {
            final datos = receta.data() as Map<String, dynamic>;
            final dosis = _generarDosisDiarias(datos);
            todasDosis.addAll(dosis.map((hora) => {
              ...datos,
              'horaDosis': hora,
              'docId': receta.id
            }));
          }

          todasDosis.sort((a, b) => a['horaDosis'].compareTo(b['horaDosis']));

          final dosisAgrupadas = _agruparPorFecha(
              todasDosis.map((d) => d['horaDosis'] as DateTime).toList());

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
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    ...entrada.value.map((hora) {
                      final medicamento = todasDosis.firstWhere(
                          (d) => d['horaDosis'] == hora);
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
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AgregarRecetaPage()),
          );
        },
        tooltip: 'Agregar Medicamento',
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
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
              colors: [
                Color.fromARGB(255, 73, 194, 255),
                Color.fromARGB(255, 47, 109, 180),
              ],
            ),
          ),
          child: const Icon(
            Icons.add,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildDosisCard(Map<String, dynamic> medicamento, BuildContext context) {
    final horaFormateada = DateFormat('hh:mm a').format(medicamento['horaDosis']);
    
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DetalleRecetaPage(receta: medicamento),
        ),
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
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
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
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text('Dosis cada ${medicamento['intervaloDosis']} horas'),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete, 
                    color: Color.fromARGB(255, 247, 128, 120)),
                onPressed: () async {
                  await FirebaseFirestore.instance
                      .collection('medicamentos')
                      .doc(FirebaseAuth.instance.currentUser?.uid)
                      .collection('userMedicamentos')
                      .doc(medicamento['docId']) // Usar medicamento aquí
                      .delete();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}