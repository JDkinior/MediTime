import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DetalleRecetaPage extends StatelessWidget {
  final QueryDocumentSnapshot receta;

  const DetalleRecetaPage({super.key, required this.receta});

  // Function to calculate the next time the medication will sound
  String getNextDoseTime() {
    // Assuming 'horaPrimeraDosis' is stored in 24-hour format like "14:00"
    DateTime now = DateTime.now();
    DateTime firstDoseTime = DateFormat('HH:mm').parse(receta['horaPrimeraDosis']);
    DateTime nextDose = DateTime(now.year, now.month, now.day, firstDoseTime.hour, firstDoseTime.minute);

    if (nextDose.isBefore(now)) {
      nextDose = nextDose.add(Duration(hours: int.parse(receta['intervaloDosis'])));
    }

    return DateFormat('hh:mm a').format(nextDose);
  }

  // Function to calculate the remaining time until the next dose
  String getRemainingTime() {
    DateTime now = DateTime.now();
    DateTime firstDoseTime = DateFormat('HH:mm').parse(receta['horaPrimeraDosis']);
    DateTime nextDose = DateTime(now.year, now.month, now.day, firstDoseTime.hour, firstDoseTime.minute);

    if (nextDose.isBefore(now)) {
      nextDose = nextDose.add(Duration(hours: int.parse(receta['intervaloDosis'])));
    }

    Duration difference = nextDose.difference(now);
    return '${difference.inHours} hours ${difference.inMinutes % 60} minutes';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(receta['nombreMedicamento']),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Big, prominent time display in blue
            Center(
              child: Text(
                getNextDoseTime(),
                style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.blue),
              ),
            ),
            const SizedBox(height: 8),
            // Smaller, detailed time until the next dose
            Center(
              child: Text(
                'En ${getRemainingTime()}',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 20),
            // Rest of the details with points
RichText(
  text: TextSpan(
    style: const TextStyle(fontSize: 18), // Estilo general de texto
    children: [
      const TextSpan(
        text: '● Medicamento: ',
        style: TextStyle(
          color: Colors.blue, 
          fontWeight: FontWeight.bold, // Negrita para el texto azul
        ),
      ),
      TextSpan(
        text: receta['nombreMedicamento'], // Texto dinámico
        style: const TextStyle(color: Colors.black), // Mantiene el color por defecto
      ),
    ],
  ),
),
const SizedBox(height: 10),
RichText(
  text: TextSpan(
    style: const TextStyle(fontSize: 18),
    children: [
      const TextSpan(
        text: '● Debe tomarse en: ',
        style: TextStyle(
          color: Colors.blue, 
          fontWeight: FontWeight.bold, // Negrita para el texto azul
        ),
      ),
      TextSpan(
        text: receta['presentacion'],
        style: const TextStyle(color: Colors.black),
      ),
    ],
  ),
),
const SizedBox(height: 10),
RichText(
  text: TextSpan(
    style: const TextStyle(fontSize: 18),
    children: [
      const TextSpan(
        text: '● Frecuencia: ',
        style: TextStyle(
          color: Colors.blue, 
          fontWeight: FontWeight.bold, // Negrita para el texto azul
        ),
      ),
      TextSpan(
        text: receta['frecuencia'],
        style: const TextStyle(color: Colors.black),
      ),
    ],
  ),
),
const SizedBox(height: 10),
RichText(
  text: TextSpan(
    style: const TextStyle(fontSize: 18),
    children: [
      const TextSpan(
        text: '● Cada: ',
        style: TextStyle(
          color: Colors.blue, 
          fontWeight: FontWeight.bold, // Negrita para el texto azul
        ),
      ),
      TextSpan(
        text: '${receta['intervaloDosis']} horas',
        style: const TextStyle(color: Colors.black),
      ),
    ],
  ),
),
const SizedBox(height: 10),
if (receta['vecesPorDia'] != null)
  RichText(
    text: TextSpan(
      style: const TextStyle(fontSize: 18),
      children: [
        const TextSpan(
          text: '● Veces por día: ',
          style: TextStyle(
            color: Colors.blue, 
            fontWeight: FontWeight.bold, // Negrita para el texto azul
          ),
        ),
        TextSpan(
          text: receta['vecesPorDia'],
          style: const TextStyle(color: Colors.black),
        ),
      ],
    ),
  ),


          ],
        ),
      ),
    );
  }
}
