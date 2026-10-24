import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:meditime/widgets/modern_app_bar.dart';
import 'package:meditime/widgets/modern_content_fade.dart';
import 'package:meditime/widgets/settings/settings_widgets.dart';

class AccesibilidadPage extends StatefulWidget {
  const AccesibilidadPage({super.key});

  @override
  State<AccesibilidadPage> createState() => _AccesibilidadPageState();
}

class _AccesibilidadPageState extends State<AccesibilidadPage> {
  int _getActiveCount(PreferenceNotifier notifier) {
    int activeCount = 0;
    if (notifier.highContrast) activeCount++;
    if (notifier.largeText) activeCount++;
    if (notifier.largeButtons) activeCount++;
    if (notifier.showCardBorder) activeCount++;
    if (notifier.simplifiedInterface) activeCount++;
    return activeCount;
  }

  Future<void> _toggleSeniorPreset(PreferenceNotifier notifier, bool enableAll) async {
    await notifier.setHighContrast(enableAll);
    await notifier.setLargeText(enableAll);
    await notifier.setLargeButtons(enableAll);
    await notifier.setShowCardBorder(enableAll);
    await notifier.setSimplifiedInterface(enableAll);

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            enableAll
                ? 'Modo Adulto Mayor completo activado.'
                : 'Ajustes de accesibilidad restaurados al modo estándar.',
          ),
          backgroundColor: enableAll ? AppTheme.successColor : AppTheme.primaryColor,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final preferenceNotifier = context.watch<PreferenceNotifier>();
    final activeCount = _getActiveCount(preferenceNotifier);
    final allActive = activeCount == 5;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: ModernAppBar(
        child: AppBar(
          title: const Text('Accesibilidad'),
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
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            allActive ? AppTheme.secondaryTextColor : AppTheme.primaryColor,
                        side: BorderSide(
                          color: allActive
                              ? AppTheme.borderColor
                              : AppTheme.primaryColor.withValues(alpha: 0.45),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: Icon(
                        allActive ? Icons.restart_alt_rounded : Icons.auto_fix_high_rounded,
                        size: 18,
                      ),
                      label: Text(
                        allActive
                            ? 'Restaurar vista estándar'
                            : 'Activar todas las ayudas (Modo Adulto Mayor)',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _toggleSeniorPreset(preferenceNotifier, !allActive),
                    ),
                  ),

                  const SettingsSectionHeader(
                    title: 'Legibilidad y Contraste',
                    topPadding: 4,
                  ),
                  SettingsSwitchTileCard(
                    title: 'Texto Grande',
                    description:
                        'Aumenta el tamaño global de las letras para facilitar la lectura sin forzar la vista.',
                    value: preferenceNotifier.largeText,
                    onChanged: (val) => preferenceNotifier.setLargeText(val),
                    icon: Icons.format_size_rounded,
                  ),
                  SettingsSwitchTileCard(
                    title: 'Alto Contraste',
                    description:
                        'Refuerza el contraste de colores, textos y bordes para máxima claridad visual.',
                    value: preferenceNotifier.highContrast,
                    onChanged: (val) => preferenceNotifier.setHighContrast(val),
                    icon: Icons.contrast_rounded,
                  ),
                  SettingsSwitchTileCard(
                    title: 'Borde en tarjetas',
                    description:
                        'Dibuja un contorno definido alrededor de todas las tarjetas y bloques de información.',
                    value: preferenceNotifier.showCardBorder,
                    onChanged: (val) => preferenceNotifier.setShowCardBorder(val),
                    icon: Icons.crop_square_rounded,
                  ),

                  const SettingsSectionHeader(
                    title: 'Interacción y Simplicidad',
                    topPadding: 12,
                  ),
                  SettingsSwitchTileCard(
                    title: 'Botones Grandes',
                    description:
                        'Expande la altura de los botones principales (mín. 56 px) para tocarlos con mayor precisión.',
                    value: preferenceNotifier.largeButtons,
                    onChanged: (val) => preferenceNotifier.setLargeButtons(val),
                    icon: Icons.smart_button_rounded,
                  ),
                  SettingsSwitchTileCard(
                    title: 'Interfaz Simplificada',
                    description:
                        'Oculta detalles secundarios y deja únicamente lo esencial: tus medicamentos y tus tomas.',
                    value: preferenceNotifier.simplifiedInterface,
                    onChanged: (val) => preferenceNotifier.setSimplifiedInterface(val),
                    icon: Icons.clean_hands_rounded,
                  ),
                ],
              ),
            ),
    );
  }
}
