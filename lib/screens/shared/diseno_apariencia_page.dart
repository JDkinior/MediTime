import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/theme/app_theme.dart';

class DisenoAparienciaPage extends StatefulWidget {
  const DisenoAparienciaPage({super.key});

  @override
  State<DisenoAparienciaPage> createState() => _DisenoAparienciaPageState();
}

class _DisenoAparienciaPageState extends State<DisenoAparienciaPage> {
  Future<void> _onCalendarFormatChanged(String? newValue) async {
    if (newValue == null) return;
    
    final preferenceNotifier = context.read<PreferenceNotifier>();
    await preferenceNotifier.setCalendarFormat(newValue);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Diseño de calendario guardado.'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _onInterfaceStyleChanged(String? newValue) async {
    if (newValue == null) return;
    
    final preferenceNotifier = context.read<PreferenceNotifier>();
    await preferenceNotifier.setInterfaceStyle(newValue);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Diseño de interfaz guardado.'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preferenceNotifier = context.watch<PreferenceNotifier>();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Diseño y Apariencia'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.primaryTextColor,
      ),
      body: preferenceNotifier.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildOptionCardWrapper(
                  title: 'Modo de pantalla',
                  subtitle: 'Elige cómo se verá la aplicación.',
                  child: Row(
                    children: [
                      _buildThemeOptionCard(
                        id: 'light',
                        title: 'Claro',
                        subtitle: 'Modo diurno',
                        preview: const Icon(Icons.light_mode_rounded, color: Colors.orange, size: 28),
                      ),
                      const SizedBox(width: 10),
                      _buildThemeOptionCard(
                        id: 'dark',
                        title: 'Oscuro',
                        subtitle: 'Modo nocturno',
                        preview: const Icon(Icons.dark_mode_rounded, color: Colors.amber, size: 28),
                      ),
                      const SizedBox(width: 10),
                      _buildThemeOptionCard(
                        id: 'system',
                        title: 'Sistema',
                        subtitle: 'Auto (sistema)',
                        preview: const Icon(Icons.settings_brightness_rounded, color: Colors.blue, size: 28),
                      ),
                    ],
                  ),
                ),

                _buildOptionCardWrapper(
                  title: 'Estilo de navegación',
                  subtitle: 'Selecciona el estilo de tu barra de navegación.',
                  child: Row(
                    children: [
                      _buildInterfaceOptionCard(
                        id: 'classic',
                        title: 'Clásica',
                        subtitle: 'Nav bar tradicional',
                        preview: _buildClassicPreview(isSelected: preferenceNotifier.interfaceStyle == 'classic'),
                      ),
                      const SizedBox(width: 12),
                      _buildInterfaceOptionCard(
                        id: 'modern',
                        title: 'Moderna',
                        subtitle: 'Flotante premium',
                        preview: _buildModernPreview(isSelected: preferenceNotifier.interfaceStyle == 'modern'),
                      ),
                    ],
                  ),
                ),

                _buildOptionCardWrapper(
                  title: 'Vista de calendario',
                  subtitle: 'Elige cómo quieres ver el calendario.',
                  child: Row(
                    children: [
                      _buildCalendarOptionCard(
                        id: 'weekly',
                        title: 'Semanal',
                        subtitle: '1 fila',
                        previewRows: 1,
                      ),
                      const SizedBox(width: 10),
                      _buildCalendarOptionCard(
                        id: 'biweekly',
                        title: 'Quincenal',
                        subtitle: '2 filas',
                        previewRows: 2,
                      ),
                      const SizedBox(width: 10),
                      _buildCalendarOptionCard(
                        id: 'monthly',
                        title: 'Mensual',
                        subtitle: 'Completo',
                        previewRows: 4,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildOptionCardWrapper({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryTextColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.secondaryTextColor,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildOptionCardLayout({
    required Widget preview,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final cardBorderColor = isSelected
        ? AppTheme.primaryColor
        : AppTheme.borderColor;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor.withOpacity(0.04)
                : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: cardBorderColor,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                height: 48,
                child: Center(child: preview),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isSelected ? AppTheme.primaryColor : AppTheme.primaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.secondaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? AppTheme.primaryColor : Colors.grey.shade500,
                    width: isSelected ? 0 : 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 12,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeOptionCard({
    required String id,
    required String title,
    required String subtitle,
    required Widget preview,
  }) {
    final preferenceNotifier = context.watch<PreferenceNotifier>();
    final isSelected = preferenceNotifier.themeMode == id;
    return _buildOptionCardLayout(
      preview: preview,
      title: title,
      subtitle: subtitle,
      isSelected: isSelected,
      onTap: () => preferenceNotifier.setThemeMode(id),
    );
  }

  Widget _buildInterfaceOptionCard({
    required String id,
    required String title,
    required String subtitle,
    required Widget preview,
  }) {
    final preferenceNotifier = context.watch<PreferenceNotifier>();
    final isSelected = preferenceNotifier.interfaceStyle == id;
    return _buildOptionCardLayout(
      preview: preview,
      title: title,
      subtitle: subtitle,
      isSelected: isSelected,
      onTap: () => _onInterfaceStyleChanged(id),
    );
  }

  Widget _buildCalendarOptionCard({
    required String id,
    required String title,
    required String subtitle,
    required int previewRows,
  }) {
    final preferenceNotifier = context.watch<PreferenceNotifier>();
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
                    : (isSelected ? AppTheme.primaryColor.withOpacity(0.3) : Colors.grey.shade500),
              ),
            );
          }),
        );
      }),
    );
    
    return _buildOptionCardLayout(
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
        color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : Colors.grey.shade700.withOpacity(0.2),
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
            color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : Colors.grey.shade700.withOpacity(0.2),
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
