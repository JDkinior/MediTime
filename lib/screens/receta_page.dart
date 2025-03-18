import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'agregar_receta_page.dart';
import 'detalle_receta_page.dart'; // Import the new file

class RecetaPage extends StatelessWidget {
  const RecetaPage({super.key});

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
                'Aun no has agregado ninguna receta',
                style: TextStyle(fontSize: 20),
              ),
            );
          }

          // Obtener las recetas y ordenarlas por la hora de la primera dosis
          final recetas = snapshot.data!.docs;
          recetas.sort((a, b) {
            final horaA = a['horaPrimeraDosis'].split(':');
            final horaB = b['horaPrimeraDosis'].split(':');
            
            final int horaAHour = int.parse(horaA[0]);
            final int horaAMinute = int.parse(horaA[1]);
            
            final int horaBHour = int.parse(horaB[0]);
            final int horaBMinute = int.parse(horaB[1]);

            // Comparar primero las horas y luego los minutos
            if (horaAHour != horaBHour) {
              return horaAHour.compareTo(horaBHour);
            }
            return horaAMinute.compareTo(horaBMinute);
          });

          return ListView.builder(
            itemCount: recetas.length,
            itemBuilder: (context, index) {
              final receta = recetas[index];
              final horaPrimeraDosis = receta['horaPrimeraDosis'];
              final parts = horaPrimeraDosis.split(':');
              final hour = int.parse(parts[0]);
              final minute = int.parse(parts[1]);
              final period = hour >= 12 ? 'p.m' : 'a.m';
              final formattedMinute = minute.toString().padLeft(2, '0');
              final formattedHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);

return GestureDetector(
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetalleRecetaPage(receta: receta),
      ),
    );
  },
  child: Container(
    margin: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color.fromARGB(255, 241, 241, 241), // Color de fondo
      borderRadius: BorderRadius.circular(15),
      boxShadow: [
        BoxShadow(
          color: const Color.fromARGB(20, 47, 109, 180), // Color de la sombra
          blurRadius: 6,       // Difuminado
          spreadRadius: 3,    // Extensión
          offset: const Offset(0, 4) // Posición (horizontal, vertical)
        ),
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
                              '$formattedHour:$formattedMinute $period',
                              style: const TextStyle(
                                fontSize: 24,
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
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                receta['nombreMedicamento'],
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text('Dosis: ${receta['intervaloDosis']}'),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Color.fromARGB(255, 247, 128, 120)),
                          onPressed: () async {
                            await FirebaseFirestore.instance
                                .collection('medicamentos')
                                .doc(FirebaseAuth.instance.currentUser?.uid)
                                .collection('userMedicamentos')
                                .doc(receta.id)
                                .delete();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
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
  backgroundColor: Colors.transparent, // Fondo transparente para que se vea el degradado
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
        transform: GradientRotation(0 * 3.1416 / 180), // Convertir 45 grados a radianes
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
}
