import 'package:flutter/material.dart';

class OpcionesPage extends StatelessWidget {
  const OpcionesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Opciones'),
      ),
      body: const Center(
        child: Text(
          'Aún en desarrollo',
          style: TextStyle(
            fontSize: 24,
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}