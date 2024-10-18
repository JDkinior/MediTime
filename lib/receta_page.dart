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
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  margin: const EdgeInsets.all(10),
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
        backgroundColor: Colors.blue,
        heroTag: 'uniqueTag1',  // Asignar un tag único
        child: const Icon(
          Icons.add,
          color: Colors.white,
        ),
      ),
    );
  }
}
