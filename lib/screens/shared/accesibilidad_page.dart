import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/theme/app_theme.dart';

class AccesibilidadPage extends StatelessWidget {
  const AccesibilidadPage({super.key});

  @override
  Widget build(BuildContext context) {
    final preferenceNotifier = context.watch<PreferenceNotifier>();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Accesibilidad'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.primaryTextColor,
      ),
      body: preferenceNotifier.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildIntroText(),
                const SizedBox(height: 24),
                _buildAccessibilityOption(
                  context: context,
                  title: 'Alto Contraste',
                  description: 'Aumenta el contraste de los colores para mejorar la legibilidad.',
                  value: preferenceNotifier.highContrast,
                  onChanged: (val) => preferenceNotifier.setHighContrast(val),
                  icon: Icons.contrast_rounded,
                  demoWidget: _buildHighContrastDemo(context, preferenceNotifier.highContrast),
                ),
                _buildAccessibilityOption(
                  context: context,
                  title: 'Texto Grande',
                  description: 'Aumenta el tamaño global del texto para facilitar la lectura.',
                  value: preferenceNotifier.largeText,
                  onChanged: (val) => preferenceNotifier.setLargeText(val),
                  icon: Icons.format_size_rounded,
                  demoWidget: _buildLargeTextDemo(context),
                ),
                _buildAccessibilityOption(
                  context: context,
                  title: 'Botones Grandes',
                  description: 'Expande el tamaño de los botones principales (mín. 64px) para tocarlos más fácilmente.',
                  value: preferenceNotifier.largeButtons,
                  onChanged: (val) => preferenceNotifier.setLargeButtons(val),
                  icon: Icons.smart_button_rounded,
                  demoWidget: _buildLargeButtonsDemo(context),
                ),
                _buildAccessibilityOption(
                  context: context,
                  title: 'Interfaz Simplificada',
                  description: 'Oculta opciones secundarias y se enfoca solo en lo más importante (tus alarmas y medicamentos).',
                  value: preferenceNotifier.simplifiedInterface,
                  onChanged: (val) => preferenceNotifier.setSimplifiedInterface(val),
                  icon: Icons.clean_hands_rounded,
                  demoWidget: _buildSimplifiedInterfaceDemo(context),
                ),
              ],
            ),
    );
  }

  Widget _buildIntroText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.elderly_rounded, color: AppTheme.primaryColor, size: 28),
            const SizedBox(width: 8),
            Text(
              'Modo Adulto Mayor',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryTextColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Configura MediTime para que sea más fácil de ver y usar. Activa las opciones que mejor se adapten a ti.',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.secondaryTextColor,
          ),
        ),
      ],
    );
  }

  Widget _buildAccessibilityOption({
    required BuildContext context,
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
    required Widget demoWidget,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor, width: value ? 2 : 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            title: Row(
              children: [
                Icon(icon, color: value ? AppTheme.primaryColor : AppTheme.secondaryTextColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.primaryTextColor,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                description,
                style: TextStyle(color: AppTheme.secondaryTextColor),
              ),
            ),
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.primaryColor,
          ),
          const Divider(height: 1),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vista Previa:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.secondaryTextColor,
                  ),
                ),
                const SizedBox(height: 12),
                Center(child: demoWidget),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighContrastDemo(BuildContext context, bool isHighContrast) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Color Primario',
              style: TextStyle(color: AppTheme.whiteTextColor, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Texto Base',
            style: TextStyle(color: AppTheme.primaryTextColor),
          ),
        ],
      ),
    );
  }

  Widget _buildLargeTextDemo(BuildContext context) {
    return Text(
      'Este es un texto de ejemplo.',
      style: TextStyle(color: AppTheme.primaryTextColor),
    );
  }

  Widget _buildLargeButtonsDemo(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () {},
      icon: const Icon(Icons.check_circle_outline),
      label: const Text('Botón de Ejemplo'),
    );
  }

  Widget _buildSimplifiedInterfaceDemo(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.medication_rounded, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                'Próxima toma: Paracetamol',
                style: TextStyle(color: AppTheme.primaryTextColor, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (!context.watch<PreferenceNotifier>().simplifiedInterface) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, color: AppTheme.secondaryTextColor, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Información adicional (Oculta en modo simple)',
                    style: TextStyle(color: AppTheme.secondaryTextColor, fontSize: 11),
                  ),
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }
}
