import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:meditime/l10n/generated/app_localizations.dart';

class IdiomaOpcionesPage extends StatelessWidget {
  const IdiomaOpcionesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final preferenceNotifier = context.watch<PreferenceNotifier>();
    final currentCode = preferenceNotifier.languageCode;

    final title = l10n?.languageTitle ?? 'Idioma';
    final subtitle = l10n?.languageSubtitle ?? 'Selecciona tu idioma preferido para la interfaz.';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(title),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.primaryTextColor,
      ),
      body: preferenceNotifier.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 16),
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.secondaryTextColor,
                    ),
                  ),
                ),
                _buildLanguageCard(
                  context: context,
                  id: 'system',
                  title: l10n?.languageSystem ?? 'Automático (Sistema)',
                  description: l10n?.languageSystemDesc ?? 'Seguir la configuración del dispositivo',
                  leadingWidget: const Icon(Icons.brightness_auto_rounded, color: Colors.blueAccent, size: 26),
                  isSelected: currentCode == 'system',
                  onTap: () => _changeLanguage(context, 'system'),
                ),
                const SizedBox(height: 12),
                _buildLanguageCard(
                  context: context,
                  id: 'es',
                  title: l10n?.languageSpanish ?? 'Español',
                  description: l10n?.languageSpanishDesc ?? 'Español (predeterminado)',
                  leadingWidget: const Text('🇪🇸', style: TextStyle(fontSize: 24)),
                  isSelected: currentCode == 'es',
                  onTap: () => _changeLanguage(context, 'es'),
                ),
                const SizedBox(height: 12),
                _buildLanguageCard(
                  context: context,
                  id: 'en',
                  title: l10n?.languageEnglish ?? 'English',
                  description: l10n?.languageEnglishDesc ?? 'Inglés',
                  leadingWidget: const Text('🇺🇸', style: TextStyle(fontSize: 24)),
                  isSelected: currentCode == 'en',
                  onTap: () => _changeLanguage(context, 'en'),
                ),
              ],
            ),
    );
  }

  Future<void> _changeLanguage(BuildContext context, String code) async {
    final notifier = context.read<PreferenceNotifier>();
    await notifier.setLanguageCode(code);

    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context);
    final msg = l10n?.languageChangedSnackbar ?? 'Idioma actualizado correctamente.';

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildLanguageCard({
    required BuildContext context,
    required String id,
    required String title,
    required String description,
    required Widget leadingWidget,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final preferenceNotifier = context.watch<PreferenceNotifier>();
    final showBorder = preferenceNotifier.showCardBorder || preferenceNotifier.highContrast;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primaryColor
                  : (showBorder ? AppTheme.borderColor : Colors.transparent),
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
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryColor.withOpacity(0.12)
                      : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4),
                  shape: BoxShape.circle,
                ),
                child: leadingWidget,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? AppTheme.primaryColor : AppTheme.primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? AppTheme.primaryColor : Colors.grey.shade400,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 16,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
