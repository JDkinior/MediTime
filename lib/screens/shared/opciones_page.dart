import 'package:flutter/material.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:meditime/screens/shared/accesibilidad_page.dart';
import 'package:meditime/screens/shared/diseno_apariencia_page.dart';
import 'package:meditime/screens/shared/notificaciones_opciones_page.dart';
import 'package:meditime/screens/shared/datos_privacidad_page.dart';

class OpcionesPage extends StatelessWidget {
  const OpcionesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Opciones'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.primaryTextColor,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCategoryCard(
            context: context,
            title: 'Accesibilidad',
            subtitle: 'Oculta opciones secundarias y se enfoca solo en lo más importante.',
            icon: Icons.accessibility_new_rounded,
            iconColor: AppTheme.primaryColor,
            page: const AccesibilidadPage(),
          ),
          _buildCategoryCard(
            context: context,
            title: 'Diseño y Apariencia',
            subtitle: 'Personaliza la apariencia de la app a tu gusto.',
            icon: Icons.palette_outlined,
            iconColor: Colors.amber,
            page: const DisenoAparienciaPage(),
          ),
          _buildCategoryCard(
            context: context,
            title: 'Notificaciones y Alarmas',
            subtitle: 'Configura cómo quieres recibir tus recordatorios.',
            icon: Icons.notifications_active_outlined,
            iconColor: Colors.blue,
            page: const NotificacionesOpcionesPage(),
          ),
          _buildCategoryCard(
            context: context,
            title: 'Datos y Privacidad',
            subtitle: 'Gestiona tu historial médico y de chats.',
            icon: Icons.security_rounded,
            iconColor: AppTheme.errorColor,
            page: const DatosPrivacidadPage(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Widget page,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryTextColor,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.secondaryTextColor,
            ),
          ),
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: AppTheme.secondaryTextColor),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => page),
          );
        },
      ),
    );
  }
}
