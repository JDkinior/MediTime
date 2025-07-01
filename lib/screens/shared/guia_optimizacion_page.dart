// lib/screens/shared/guia_optimizacion_page.dart
import 'package:flutter/material.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:meditime/widgets/primary_button.dart';

class GuiaOptimizacionPage extends StatelessWidget {
  const GuiaOptimizacionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: const Text('Guía de Optimización'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: kSecondaryColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            const Text(
              '¿Por qué es importante?',
              style: kSectionTitleStyle,
            ),
            const SizedBox(height: 8),
            const Text(
              'Los fabricantes de teléfonos (especialmente Xiaomi, Huawei, y OnePlus) implementan medidas muy agresivas de ahorro de batería. Estas pueden "congelar" o cerrar aplicaciones en segundo plano, causando que los recordatorios de MediTime no lleguen a la hora exacta.',
              style: kBodyTextStyle,
            ),
            const SizedBox(height: 24),
            const Text(
              'Pasos recomendados',
              style: kSectionTitleStyle,
            ),
            const SizedBox(height: 16),
            _buildStepCard(
              icon: Icons.battery_charging_full_rounded,
              title: 'Desactivar Optimización de Batería',
              description:
                  'Es el paso más importante. Busca "MediTime" en la configuración de batería de tu teléfono y selecciona "Sin restricciones" o "No optimizar".',
              step: 'Paso 1',
            ),
            const SizedBox(height: 16),
            _buildStepCard(
              icon: Icons.settings_backup_restore_rounded,
              title: 'Permitir Inicio Automático',
              description:
                  'Busca una opción llamada "Inicio automático" o "Autostart". Asegúrate de que MediTime esté activado para que pueda funcionar después de reiniciar el teléfono.',
              step: 'Paso 2',
            ),
            const SizedBox(height: 16),
            _buildStepCard(
              icon: Icons.lock_outline_rounded,
              title: 'Bloquear la App en "Recientes"',
              description:
                  'Abre la lista de aplicaciones recientes, mantén presionada la ventana de MediTime y busca un ícono de candado. Esto evita que el sistema la cierre.',
              step: 'Paso 3',
            ),
            const SizedBox(height: 32),
            PrimaryButton(
              text: 'Entendido',
              onPressed: () {
                Navigator.of(context).pop();
                
              },
            )
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kPrimaryColor, kSecondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: kCustomBoxShadow,
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: Colors.white, size: 40),
          SizedBox(height: 16),
          Text(
            'Asegura tus recordatorios',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Sigue esta guía para garantizar que las notificaciones de tus medicamentos lleguen siempre a tiempo.',
            style: TextStyle(
              fontSize: 15,
              color: Colors.white70,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard(
      {required IconData icon,
      required String title,
      required String description,
      required String step}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: kCustomBoxShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(icon, color: kSecondaryColor, size: 32),
              const SizedBox(height: 8),
              Text(
                step,
                style: const TextStyle(
                    color: kSecondaryColor, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black54,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}