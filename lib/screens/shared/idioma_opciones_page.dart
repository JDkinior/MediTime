import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:meditime/widgets/modern_app_bar.dart';
import 'package:meditime/widgets/modern_content_fade.dart';
import 'package:meditime/widgets/settings/settings_widgets.dart';
import 'package:meditime/l10n/generated/app_localizations.dart';

class IdiomaOpcionesPage extends StatelessWidget {
  const IdiomaOpcionesPage({super.key});

  Widget _buildLanguageBadge(String code, bool isSelected) {
    return Text(
      code.toUpperCase(),
      style: TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
        color: isSelected ? AppTheme.primaryColor : AppTheme.secondaryTextColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final preferenceNotifier = context.watch<PreferenceNotifier>();
    final currentCode = preferenceNotifier.languageCode;

    final title = l10n?.languageTitle ?? 'Idioma';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: ModernAppBar(
        child: AppBar(
          title: Text(title),
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
                    title: 'Idioma de la interfaz',
                    topPadding: 0,
                  ),
                  SettingsRadioOptionCard(
                    title: l10n?.languageSystem ?? 'Automático (Sistema)',
                    subtitle: l10n?.languageSystemDesc ??
                        'Seguir automáticamente el idioma configurado en tu teléfono.',
                    icon: Icons.brightness_auto_rounded,
                    color: Colors.indigo,
                    isSelected: currentCode == 'system',
                    onTap: () => _changeLanguage(context, 'system'),
                  ),
                  SettingsRadioOptionCard(
                    title: l10n?.languageSpanish ?? 'Español',
                    subtitle: l10n?.languageSpanishDesc ?? 'Español (predeterminado)',
                    leadingWidget: _buildLanguageBadge('es', currentCode == 'es'),
                    color: AppTheme.primaryColor,
                    isSelected: currentCode == 'es',
                    onTap: () => _changeLanguage(context, 'es'),
                  ),
                  SettingsRadioOptionCard(
                    title: l10n?.languageEnglish ?? 'English',
                    subtitle: l10n?.languageEnglishDesc ?? 'Inglés (Estados Unidos / Internacional)',
                    leadingWidget: _buildLanguageBadge('en', currentCode == 'en'),
                    color: AppTheme.primaryColor,
                    isSelected: currentCode == 'en',
                    onTap: () => _changeLanguage(context, 'en'),
                  ),
                  SettingsRadioOptionCard(
                    title: l10n?.languagePortuguese ?? 'Português',
                    subtitle: l10n?.languagePortugueseDesc ?? 'Portugués (Brasil / Portugal)',
                    leadingWidget: _buildLanguageBadge('pt', currentCode == 'pt'),
                    color: AppTheme.primaryColor,
                    isSelected: currentCode == 'pt',
                    onTap: () => _changeLanguage(context, 'pt'),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _changeLanguage(BuildContext context, String code) async {
    final notifier = context.read<PreferenceNotifier>();
    if (notifier.languageCode == code) return;
    await notifier.setLanguageCode(code);

    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context);
    final msg = l10n?.languageChangedSnackbar ?? 'Idioma actualizado correctamente.';

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppTheme.successColor,
          duration: const Duration(seconds: 2),
        ),
      );
  }
}
