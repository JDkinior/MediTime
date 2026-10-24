import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:meditime/widgets/modern_app_bar.dart';
import 'package:meditime/widgets/modern_content_fade.dart';
import 'package:meditime/widgets/settings/settings_widgets.dart';

class DisenoAparienciaPage extends StatefulWidget {
  const DisenoAparienciaPage({super.key});

  @override
  State<DisenoAparienciaPage> createState() => _DisenoAparienciaPageState();
}

class _DisenoAparienciaPageState extends State<DisenoAparienciaPage> {
  void _showFeedback(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.successColor,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _onThemeModeChanged(String newValue) async {
    final preferenceNotifier = context.read<PreferenceNotifier>();
    if (preferenceNotifier.themeMode == newValue) return;
    await preferenceNotifier.setThemeMode(newValue);
    _showFeedback('Modo de pantalla actualizado.');
  }

  Future<void> _onCalendarFormatChanged(String? newValue) async {
    if (newValue == null) return;
    final preferenceNotifier = context.read<PreferenceNotifier>();
    if (preferenceNotifier.calendarFormat == newValue) return;
    await preferenceNotifier.setCalendarFormat(newValue);
    _showFeedback('Diseño de calendario guardado.');
  }

  Future<void> _onInterfaceStyleChanged(String? newValue) async {
    if (newValue == null) return;
    final preferenceNotifier = context.read<PreferenceNotifier>();
    if (preferenceNotifier.interfaceStyle == newValue) return;
    await preferenceNotifier.setInterfaceStyle(newValue);
    _showFeedback('Estilo de navegación guardado.');
  }

  @override
  Widget build(BuildContext context) {
    final preferenceNotifier = context.watch<PreferenceNotifier>();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: ModernAppBar(
        child: AppBar(
          title: const Text('Diseño y Apariencia'),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: AppTheme.primaryTextColor,
        ),
      ),
      body: preferenceNotifier.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ModernContentFade(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  const SettingsSectionHeader(
                    title: 'Tema y Navegación',
                    topPadding: 0,
                  ),

                  SettingsCardWrapper(
                    title: 'Modo de pantalla',
                    subtitle: 'Adapta el brillo de la aplicación al día, la noche o tu teléfono.',
                    child: Row(
                      children: [
                        SettingsVisualOptionCard(
                          title: 'Claro',
                          subtitle: 'Modo diurno',
                          preview: const Icon(
                            Icons.light_mode_rounded,
                            color: Colors.orange,
                            size: 28,
                          ),
                          isSelected: preferenceNotifier.themeMode == 'light',
                          onTap: () => _onThemeModeChanged('light'),
                        ),
                        const SizedBox(width: 10),
                        SettingsVisualOptionCard(
                          title: 'Oscuro',
                          subtitle: 'Modo nocturno',
                          preview: const Icon(
                            Icons.dark_mode_rounded,
                            color: Colors.amber,
                            size: 28,
                          ),
                          isSelected: preferenceNotifier.themeMode == 'dark',
                          onTap: () => _onThemeModeChanged('dark'),
                        ),
                        const SizedBox(width: 10),
                        SettingsVisualOptionCard(
                          title: 'Sistema',
                          subtitle: 'Automático',
                          preview: const Icon(
                            Icons.settings_brightness_rounded,
                            color: Colors.blue,
                            size: 28,
                          ),
                          isSelected: preferenceNotifier.themeMode == 'system',
                          onTap: () => _onThemeModeChanged('system'),
                        ),
                      ],
                    ),
                  ),

                  SettingsCardWrapper(
                    title: 'Estilo de navegación',
                    subtitle: 'Selecciona el diseño de la barra inferior y cabeceras.',
                    child: Row(
                      children: [
                        SettingsVisualOptionCard(
                          title: 'Clásica',
                          subtitle: 'Barra tradicional',
                          preview: _buildClassicPreview(
                            isSelected: preferenceNotifier.interfaceStyle == 'classic',
                          ),
                          isSelected: preferenceNotifier.interfaceStyle == 'classic',
                          onTap: () => _onInterfaceStyleChanged('classic'),
                        ),
                        const SizedBox(width: 12),
                        SettingsVisualOptionCard(
                          title: 'Moderna',
                          subtitle: 'Cápsula flotante',
                          preview: _buildModernPreview(
                            isSelected: preferenceNotifier.interfaceStyle == 'modern',
                          ),
                          isSelected: preferenceNotifier.interfaceStyle == 'modern',
                          onTap: () => _onInterfaceStyleChanged('modern'),
                        ),
                      ],
                    ),
                  ),

                  const SettingsSectionHeader(
                    title: 'Distribución y Efectos',
                    topPadding: 8,
                  ),

                  SettingsCardWrapper(
                    title: 'Vista de calendario',
                    subtitle: 'Elige cuántos días visualizar simultáneamente en Inicio.',
                    child: Row(
                      children: [
                        _buildCalendarOptionCard(
                          preferenceNotifier: preferenceNotifier,
                          id: 'weekly',
                          title: 'Semanal',
                          subtitle: '1 fila',
                          previewRows: 1,
                        ),
                        const SizedBox(width: 10),
                        _buildCalendarOptionCard(
                          preferenceNotifier: preferenceNotifier,
                          id: 'biweekly',
                          title: 'Quincenal',
                          subtitle: '2 filas',
                          previewRows: 2,
                        ),
                        const SizedBox(width: 10),
                        _buildCalendarOptionCard(
                          preferenceNotifier: preferenceNotifier,
                          id: 'monthly',
                          title: 'Mensual',
                          subtitle: 'Completo',
                          previewRows: 4,
                        ),
                      ],
                    ),
                  ),

                  SettingsSwitchTileCard(
                    title: 'Difuminado suave al hacer scroll',
                    description: preferenceNotifier.interfaceStyle == 'modern'
                        ? 'Atenúa suavemente los extremos superior e inferior de las listas para evitar cortes abruptos.'
                        : 'Atenúa los extremos al desplazarse (este efecto es visible cuando usas el estilo de navegación Moderna).',
                    value: preferenceNotifier.enableScrollFade,
                    icon: Icons.gradient_rounded,
                    activeColor: AppTheme.primaryColor,
                    onChanged: (val) async {
                      await preferenceNotifier.setEnableScrollFade(val);
                      _showFeedback(
                        val
                            ? 'Difuminado de scroll activado.'
                            : 'Difuminado de scroll desactivado.',
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCalendarOptionCard({
    required PreferenceNotifier preferenceNotifier,
    required String id,
    required String title,
    required String subtitle,
    required int previewRows,
  }) {
    final isSelected = preferenceNotifier.calendarFormat == id;

    final preview = Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(previewRows, (r) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(7, (c) {
            final isToday = r == 0 && c == 3;
            return Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isToday
                    ? AppTheme.primaryColor
                    : (isSelected
                        ? AppTheme.primaryColor.withValues(alpha: 0.3)
                        : Colors.grey.shade500),
              ),
            );
          }),
        );
      }),
    );

    return SettingsVisualOptionCard(
      preview: preview,
      title: title,
      subtitle: subtitle,
      isSelected: isSelected,
      onTap: () => _onCalendarFormatChanged(id),
    );
  }

  Widget _buildClassicPreview({required bool isSelected}) {
    return Container(
      width: 80,
      height: 16,
      decoration: BoxDecoration(
        color: isSelected
            ? AppTheme.primaryColor.withValues(alpha: 0.1)
            : Colors.grey.shade700.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
          3,
          (index) => Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? AppTheme.primaryColor : Colors.grey.shade500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernPreview({required bool isSelected}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 55,
          height: 16,
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor.withValues(alpha: 0.1)
                : Colors.grey.shade700.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              3,
              (index) => Container(
                width: 3,
                height: 3,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? AppTheme.primaryColor : Colors.grey.shade500,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Center(
            child: Icon(Icons.add, size: 10, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
