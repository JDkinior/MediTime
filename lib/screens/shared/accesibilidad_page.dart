import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:meditime/widgets/modern_app_bar.dart';
import 'package:meditime/widgets/modern_content_fade.dart';

class AccesibilidadPage extends StatefulWidget {
  const AccesibilidadPage({super.key});

  @override
  State<AccesibilidadPage> createState() => _AccesibilidadPageState();
}

class _AccesibilidadPageState extends State<AccesibilidadPage> {
  bool _mockDoseTaken = false;

  @override
  Widget build(BuildContext context) {
    final preferenceNotifier = context.watch<PreferenceNotifier>();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: ModernAppBar(
        child: AppBar(
          title: const Text('Accesibilidad'),
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: AppTheme.primaryTextColor,
        ),
      ),
      body: preferenceNotifier.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ModernContentFade(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildIntroText(),
                  _buildHeroLivePreview(context, preferenceNotifier),
                  _buildSectionHeader(
                    title: 'Ajustes de visualización y botones',
                    subtitle: 'Personaliza tamaños, contrastes y simplicidad según tus necesidades.',
                  ),
                  _buildStandardSwitchCard(
                    context: context,
                    title: 'Alto Contraste',
                    description: 'Aumenta el contraste de los colores para mejorar la legibilidad.',
                    value: preferenceNotifier.highContrast,
                    onChanged: (val) => preferenceNotifier.setHighContrast(val),
                    icon: Icons.contrast_rounded,
                  ),
                  _buildStandardSwitchCard(
                    context: context,
                    title: 'Texto Grande',
                    description: 'Aumenta el tamaño global del texto para facilitar la lectura.',
                    value: preferenceNotifier.largeText,
                    onChanged: (val) => preferenceNotifier.setLargeText(val),
                    icon: Icons.format_size_rounded,
                  ),
                  _buildStandardSwitchCard(
                    context: context,
                    title: 'Botones Grandes',
                    description: 'Expande el tamaño de los botones principales (mín. 56px) para tocarlos más fácilmente.',
                    value: preferenceNotifier.largeButtons,
                    onChanged: (val) => preferenceNotifier.setLargeButtons(val),
                    icon: Icons.smart_button_rounded,
                  ),
                  _buildStandardSwitchCard(
                    context: context,
                    title: 'Borde en tarjetas',
                    description: 'Muestra un borde visible alrededor de todas las tarjetas para definir sus contornos.',
                    value: preferenceNotifier.showCardBorder,
                    onChanged: (val) => preferenceNotifier.setShowCardBorder(val),
                    icon: Icons.crop_square_rounded,
                  ),
                  _buildStandardSwitchCard(
                    context: context,
                    title: 'Interfaz Simplificada',
                    description: 'Oculta opciones secundarias y se enfoca solo en lo más importante (tus alarmas y medicamentos).',
                    value: preferenceNotifier.simplifiedInterface,
                    onChanged: (val) => preferenceNotifier.setSimplifiedInterface(val),
                    icon: Icons.clean_hands_rounded,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildIntroText() {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.elderly_rounded, color: AppTheme.primaryColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Modo Adulto Mayor',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryTextColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Configura MediTime para que sea más fácil de ver y usar. Activa las opciones que mejor se adapten a ti.',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.secondaryTextColor,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroLivePreview(BuildContext context, PreferenceNotifier notifier) {
    final isHighContrast = notifier.highContrast;
    final isLargeText = notifier.largeText;
    final isLargeButtons = notifier.largeButtons;
    final hasBorder = notifier.showCardBorder || isHighContrast;
    final isSimplified = notifier.simplifiedInterface;

    int activeCount = 0;
    if (isHighContrast) activeCount++;
    if (isLargeText) activeCount++;
    if (isLargeButtons) activeCount++;
    if (notifier.showCardBorder) activeCount++;
    if (isSimplified) activeCount++;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasBorder ? AppTheme.primaryColor.withValues(alpha: 0.3) : AppTheme.borderColor,
          width: hasBorder ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: AppTheme.primaryColor,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'VISTA PREVIA EN VIVO',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: activeCount > 0
                      ? AppTheme.primaryColor.withValues(alpha: 0.1)
                      : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  activeCount > 0 ? '$activeCount activas' : 'Estándar',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: activeCount > 0 ? AppTheme.primaryColor : AppTheme.secondaryTextColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Tarjeta simulada de medicamento
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: EdgeInsets.all(isLargeText ? 16 : 14),
            decoration: BoxDecoration(
              color: isHighContrast
                  ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white)
                  : AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasBorder ? (isHighContrast ? AppTheme.primaryColor : AppTheme.borderColor) : Colors.transparent,
                width: isHighContrast ? 2.5 : (hasBorder ? 1.5 : 0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: isLargeText ? 46 : 40,
                      height: isLargeText ? 46 : 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: isHighContrast ? 0.2 : 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.medication_rounded,
                        color: AppTheme.primaryColor,
                        size: isLargeText ? 26 : 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Paracetamol 500 mg',
                            style: TextStyle(
                              fontSize: isLargeText ? 17.5 : 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '08:00 AM • 1 tableta',
                            style: TextStyle(
                              fontSize: isLargeText ? 14 : 12.5,
                              color: isHighContrast ? AppTheme.primaryTextColor : AppTheme.secondaryTextColor,
                              fontWeight: isHighContrast ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 200),
                  crossFadeState: isSimplified ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                  firstChild: const SizedBox.shrink(),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.info_outline_rounded, size: 14, color: AppTheme.secondaryTextColor),
                          const SizedBox(width: 6),
                          Text(
                            'Tomar con comida • 24 restantes',
                            style: TextStyle(
                              fontSize: isLargeText ? 12.5 : 11.5,
                              color: AppTheme.secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: isLargeButtons ? 56 : 42,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _mockDoseTaken = !_mockDoseTaken;
                      });
                    },
                    icon: Icon(
                      _mockDoseTaken ? Icons.check_circle_rounded : Icons.check_rounded,
                      size: isLargeButtons ? 22 : 18,
                    ),
                    label: Text(
                      _mockDoseTaken ? '¡Dosis tomada!' : 'Tomar dosis',
                      style: TextStyle(
                        fontSize: isLargeButtons ? 16 : (isLargeText ? 14.5 : 13.5),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _mockDoseTaken ? AppTheme.successColor : AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: isHighContrast ? 0 : 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(isLargeButtons ? 16 : 12),
                        side: isHighContrast
                            ? const BorderSide(color: Colors.white, width: 1.5)
                            : BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              'Toca los interruptores de abajo para ver la transformación aquí.',
              style: TextStyle(
                fontSize: 11.5,
                color: AppTheme.secondaryTextColor.withValues(alpha: 0.8),
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 4, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
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
        ],
      ),
    );
  }

  Widget _buildStandardSwitchCard({
    required BuildContext context,
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    final showBorder = context.watch<PreferenceNotifier>().showCardBorder ||
        context.watch<PreferenceNotifier>().highContrast;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: value
              ? AppTheme.primaryColor.withValues(alpha: 0.35)
              : (showBorder ? AppTheme.borderColor : Colors.transparent),
          width: value ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          secondary: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: value
                  ? AppTheme.primaryColor.withValues(alpha: 0.12)
                  : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: value ? AppTheme.primaryColor : AppTheme.secondaryTextColor,
              size: 22,
            ),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryTextColor,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.secondaryTextColor,
                height: 1.3,
              ),
            ),
          ),
          value: value,
          activeThumbColor: AppTheme.primaryColor,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
