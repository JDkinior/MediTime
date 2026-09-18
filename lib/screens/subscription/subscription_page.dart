// lib/screens/subscription/subscription_page.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meditime/notifiers/subscription_notifier.dart';
import 'package:meditime/services/subscription_service.dart';
import 'package:meditime/services/auth_service.dart';
import 'package:meditime/theme/app_theme.dart';

class SubscriptionPage extends StatefulWidget {
  final String? sourceFeature;

  const SubscriptionPage({super.key, this.sourceFeature});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  // 'annual' or 'monthly'
  String _selectedTier = 'annual';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subNotifier = context.watch<SubscriptionNotifier>();
    final isPremium = subNotifier.isPremium;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Background ambient soft glow circles
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    (isDark ? const Color(0xFF7C3AED) : const Color(0xFFDDD6FE)).withValues(alpha: isDark ? 0.2 : 0.45),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 120,
            left: -80,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    (isDark ? const Color(0xFF2563EB) : const Color(0xFFBAE6FD)).withValues(alpha: isDark ? 0.15 : 0.4),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Main Content
          SafeArea(
            child: subNotifier.isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      // Top Bar with Close Button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.close_rounded,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                                size: 28,
                              ),
                              onPressed: () => Navigator.pop(context),
                              tooltip: 'Cerrar',
                            ),
                          ],
                        ),
                      ),

                      // Proportional layout calibrated to fill viewport gracefully
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final totalHeight = constraints.maxHeight;
                            final isSmallScreen = totalHeight < 720;

                            // Dynamic height budget so cards expand to fill vertical space without voids
                            final headerEstimate = isSmallScreen ? 124.0 : 142.0;
                            final bottomEstimate = isPremium ? 76.0 : 144.0;
                            final gap = isSmallScreen ? 8.0 : (isPremium ? 12.0 : 9.0);
                            final availableForCards = totalHeight - headerEstimate - bottomEstimate - (gap * 3);

                            // Proportional heights: 2 grid rows + 1 wide card
                            // Wide card is ~52% of a grid card
                            final rawCardHeight = (availableForCards / 2.52);
                            final cardHeight = isPremium
                                ? rawCardHeight.clamp(160.0, 205.0)
                                : rawCardHeight.clamp(136.0, 172.0);
                            final wideCardHeight = (cardHeight * 0.52).clamp(
                              isPremium ? 88.0 : 74.0,
                              isPremium ? 106.0 : 88.0,
                            );

                            return SingleChildScrollView(
                              physics: const ClampingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: totalHeight - 4,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Column(
                                      children: [
                                        // Hero Badge with Sparkling Rays
                                        _buildSparklingBadge(),
                                        SizedBox(height: isSmallScreen ? 8 : 12),

                                        // Title
                                        Text(
                                          isPremium
                                              ? '¡Ya eres Miembro Pro!'
                                              : 'Cuida tu salud y la de los tuyos sin límites',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: isSmallScreen ? 20 : 23,
                                            fontWeight: FontWeight.w900,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                            letterSpacing: -0.4,
                                            height: 1.18,
                                          ),
                                        ),
                                        const SizedBox(height: 5),

                                        // Subtitle
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 10),
                                          child: Text(
                                            isPremium
                                                ? 'Tu suscripción está activa (${subNotifier.subscriptionTier == 'annual' ? 'Plan Anual' : 'Plan Mensual'}).\nDisfrutas de todos los beneficios Pro.'
                                                : (widget.sourceFeature != null
                                                    ? 'Para usar ${widget.sourceFeature}, pásate a MediTime Pro por un costo muy económico.'
                                                    : 'Desbloquea herramientas avanzadas diseñadas para tu tranquilidad y la de tu familia.'),
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: isSmallScreen ? 12 : 13,
                                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                              height: 1.3,
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: gap + 2),

                                        // 2x2 Grid of Benefit Cards
                                        Row(
                                          children: [
                                            // Card 1: Medicamentos y Tratamientos ilimitados
                                            Expanded(
                                              child: _buildBenefitCard(
                                                context: context,
                                                isDark: isDark,
                                                height: cardHeight,
                                                isSmallScreen: isSmallScreen,
                                                backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                                                borderColor: isDark ? const Color(0xFF334155) : const Color(0xFFDBEAFE),
                                                accentColor: const Color(0xFF2563EB),
                                                titleLine1: 'Medicamentos y',
                                                titleLine2: 'Tratamientos ilimitados',
                                                subtitle: 'Supera el límite de 3 tratamientos del plan gratis.',
                                                illustration: const _MedicalKitIllustration(),
                                                onTap: () => _showBenefitDialog(
                                                  context,
                                                  title: 'Medicamentos y Tratamientos Ilimitados',
                                                  description: 'En el plan gratuito puedes gestionar hasta 3 tratamientos simultáneos. Con MediTime Pro puedes agregar todos los tratamientos, recetas y recordatorios que necesites sin ningún límite.',
                                                  iconColor: const Color(0xFF2563EB),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            // Card 2: Modo Cuidador & Mascotas ilimitado
                                            Expanded(
                                              child: _buildBenefitCard(
                                                context: context,
                                                isDark: isDark,
                                                height: cardHeight,
                                                isSmallScreen: isSmallScreen,
                                                backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF5F0FF),
                                                borderColor: isDark ? const Color(0xFF334155) : const Color(0xFFEDE9FE),
                                                accentColor: const Color(0xFF7C3AED),
                                                titleLine1: 'Modo Cuidador &',
                                                titleLine2: 'Mascotas ilimitado',
                                                subtitle: 'Registra pacientes, familiares o animales sin restricción.',
                                                illustration: const _CaregiverIllustration(),
                                                onTap: () => _showBenefitDialog(
                                                  context,
                                                  title: 'Modo Cuidador & Mascotas Ilimitado',
                                                  description: 'Crea y administra múltiples perfiles independientes para tus familiares, pacientes bajo tu cuidado o mascotas veterinarias, con dosis y calendarios totalmente separados.',
                                                  iconColor: const Color(0xFF7C3AED),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: gap),

                                        Row(
                                          children: [
                                            // Card 3: Reportes Médicos en PDF
                                            Expanded(
                                              child: _buildBenefitCard(
                                                context: context,
                                                isDark: isDark,
                                                height: cardHeight,
                                                isSmallScreen: isSmallScreen,
                                                backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFF0F2),
                                                borderColor: isDark ? const Color(0xFF334155) : const Color(0xFFFFE4E6),
                                                accentColor: const Color(0xFFE11D48),
                                                titleLine1: 'Reportes Médicos en PDF',
                                                titleLine2: null,
                                                subtitle: 'Exporta tu adherencia y dosis para entregar a tu médico.',
                                                illustration: const _PdfReportIllustration(),
                                                onTap: () => _showBenefitDialog(
                                                  context,
                                                  title: 'Reportes Médicos en PDF',
                                                  description: 'Genera documentos clínicos completos con tu porcentaje de adherencia, tomas cumplidas y notas de salud en formato PDF para compartir directamente con tu especialista.',
                                                  iconColor: const Color(0xFFE11D48),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            // Card 4: Asistente Midi con Voz (IA Pro)
                                            Expanded(
                                              child: _buildBenefitCard(
                                                context: context,
                                                isDark: isDark,
                                                height: cardHeight,
                                                isSmallScreen: isSmallScreen,
                                                backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFECFDF5),
                                                borderColor: isDark ? const Color(0xFF334155) : const Color(0xFFD1FAE5),
                                                accentColor: const Color(0xFF059669),
                                                titleLine1: 'Asistente Midi con Voz',
                                                titleLine2: '(IA Pro)',
                                                subtitle: 'Habla por notas de voz y escucha las respuestas de Midi.',
                                                illustration: const _VoiceAssistantIllustration(),
                                                onTap: () => _showBenefitDialog(
                                                  context,
                                                  title: 'Asistente Midi con Voz (IA Pro)',
                                                  description: 'Consulta dudas sobre tus medicamentos mediante notas de voz y escucha las respuestas audibles de Midi, tu asistente médico potenciado por Inteligencia Artificial.',
                                                  iconColor: const Color(0xFF059669),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: gap),

                                        // Card 5: Widgets de Pantalla de Inicio (Wide Card)
                                        _buildWideBenefitCard(
                                          context: context,
                                          isDark: isDark,
                                          height: wideCardHeight,
                                          isSmallScreen: isSmallScreen,
                                          backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFBEB),
                                          borderColor: isDark ? const Color(0xFF334155) : const Color(0xFFFEF08A),
                                          accentColor: const Color(0xFFD97706),
                                          title: 'Widgets de Pantalla de Inicio',
                                          subtitle: 'Marca tus dosis directamente desde el home de tu celular.',
                                          illustration: const _HomeWidgetIllustration(),
                                          onTap: () => _showBenefitDialog(
                                            context,
                                            title: 'Widgets de Pantalla de Inicio',
                                            description: 'Monitorea tus próximas tomas del día y registra medicamentos tomados directamente desde los widgets interactivos de la pantalla de inicio de tu teléfono.',
                                            iconColor: const Color(0xFFD97706),
                                          ),
                                        ),
                                      ],
                                    ),

                                    // Bottom Action Area
                                    Padding(
                                      padding: EdgeInsets.only(top: gap, bottom: 8),
                                      child: isPremium
                                          ? _buildActiveSubscriptionBanner(context, subNotifier, isDark)
                                          : _buildPurchaseSection(context, isDark, isSmallScreen),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Hero Badge with Sparkling Decorative Rays (Matching Image 1)
  // ---------------------------------------------------------------------------
  Widget _buildSparklingBadge() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left radiating rays
          const CustomPaint(
            size: Size(20, 24),
            painter: _SparkleRaysPainter(isLeft: true, color: Color(0xFF2563EB)),
          ),
          const SizedBox(width: 5),

          // Badge container
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6.5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.38),
                  blurRadius: 12,
                  offset: const Offset(0, 3.5),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CustomPaint(
                  size: Size(16, 13),
                  painter: _CrownPainter(color: Colors.white),
                ),
                SizedBox(width: 7),
                Text(
                  'MEDITIME PRO',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.15,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),

          // Right radiating rays
          const CustomPaint(
            size: Size(20, 24),
            painter: _SparkleRaysPainter(isLeft: false, color: Color(0xFF7C3AED)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2x2 Grid Benefit Card (Matching Image 1 Proportions)
  // ---------------------------------------------------------------------------
  Widget _buildBenefitCard({
    required BuildContext context,
    required bool isDark,
    required double height,
    required bool isSmallScreen,
    required Color backgroundColor,
    required Color borderColor,
    required Color accentColor,
    required String titleLine1,
    required String? titleLine2,
    required String subtitle,
    required Widget illustration,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: height,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: 1.1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.025),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Centered Illustration at top
            Center(
              child: SizedBox(
                height: isSmallScreen ? 44 : 52,
                child: illustration,
              ),
            ),
            const Spacer(),

            // Title
            Text(
              titleLine2 != null ? '$titleLine1\n$titleLine2' : titleLine1,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: isSmallScreen ? 12 : 13.2,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                height: 1.18,
              ),
            ),
            const SizedBox(height: 3),

            // Subtitle
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: isSmallScreen ? 10 : 11,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                height: 1.18,
              ),
            ),
            const Spacer(),

            // Bottom Arrow Icon in circle (Bottom-Left)
            _buildArrowCircle(accentColor, isSmallScreen),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Wide Benefit Card (Matching Card 5 in Image 1)
  // ---------------------------------------------------------------------------
  Widget _buildWideBenefitCard({
    required BuildContext context,
    required bool isDark,
    required double height,
    required bool isSmallScreen,
    required Color backgroundColor,
    required Color borderColor,
    required Color accentColor,
    required String title,
    required String subtitle,
    required Widget illustration,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: 1.1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.025),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left column: Smartphone illustration + bottom-left arrow
            SizedBox(
              width: isSmallScreen ? 56 : 64,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: SizedBox(
                      height: isSmallScreen ? 42 : 48,
                      child: illustration,
                    ),
                  ),
                  _buildArrowCircle(accentColor, isSmallScreen),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Texts in the middle/right
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 12.5 : 13.8,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 10.5 : 11.2,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArrowCircle(Color accentColor, bool isSmallScreen) {
    final size = isSmallScreen ? 22.0 : 26.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.arrow_forward_rounded,
        size: isSmallScreen ? 12.0 : 14.0,
        color: accentColor,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Active Subscription Banner (Matching Bottom of Image 1)
  // ---------------------------------------------------------------------------
  Widget _buildActiveSubscriptionBanner(
    BuildContext context,
    SubscriptionNotifier subNotifier,
    bool isDark,
  ) {
    final expires = subNotifier.subscriptionExpiresAt;
    final expiresText = expires != null
        ? 'Válida hasta: ${expires.day}/${expires.month}/${expires.year}'
        : 'Suscripción Activa y Permanente';

    return InkWell(
      onTap: () => _handleCancel(context),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF34D399), Color(0xFF10B981), Color(0xFF059669)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF059669).withValues(alpha: 0.38),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Sparkling Checkmark Circle
            const CustomPaint(
              size: Size(38, 38),
              painter: _ActiveCheckPainter(),
            ),
            const SizedBox(width: 16),

            // Title & Valid Date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Suscripción Activa',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    expiresText,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Purchase Section: Side-by-Side Plans + CTA Button (NO SCROLL NEEDED)
  // ---------------------------------------------------------------------------
  Widget _buildPurchaseSection(BuildContext context, bool isDark, bool isSmallScreen) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Side-by-Side Compact Plans Selector
        Row(
          children: [
            // Annual Plan (Featured)
            Expanded(
              child: _buildCompactPlanTile(
                tier: 'annual',
                title: 'Plan Anual',
                badge: 'AHORRA 44%',
                price: '\$39.900',
                period: '/ año',
                subtext: 'Equivale a \$3.325/mes',
                isDark: isDark,
                isSmallScreen: isSmallScreen,
              ),
            ),
            const SizedBox(width: 10),
            // Monthly Plan
            Expanded(
              child: _buildCompactPlanTile(
                tier: 'monthly',
                title: 'Plan Mensual',
                badge: null,
                price: '\$5.900',
                period: '/ mes',
                subtext: 'Cancela cuando quieras',
                isDark: isDark,
                isSmallScreen: isSmallScreen,
              ),
            ),
          ],
        ),
        SizedBox(height: isSmallScreen ? 8 : 10),

        // Subscribe Primary Button
        SizedBox(
          width: double.infinity,
          height: isSmallScreen ? 45 : 49,
          child: ElevatedButton(
            onPressed: () => _handleSubscribe(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              shadowColor: const Color(0xFF2563EB).withValues(alpha: 0.4),
            ),
            child: Ink(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CustomPaint(
                      size: Size(14, 12),
                      painter: _CrownPainter(color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _selectedTier == 'annual'
                          ? 'Suscribirme por \$39.900 COP / año'
                          : 'Suscribirme por \$5.900 COP / mes',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 13.5 : 14.8,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Disclaimer
        SizedBox(height: isSmallScreen ? 4 : 6),
        Text(
          'Precios en COP. Cancela en cualquier momento sin penalidad.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isSmallScreen ? 9.5 : 10.5,
            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Compact Plan Selector Tile
  // ---------------------------------------------------------------------------
  Widget _buildCompactPlanTile({
    required String tier,
    required String title,
    required String? badge,
    required String price,
    required String period,
    required String subtext,
    required bool isDark,
    required bool isSmallScreen,
  }) {
    final isSelected = _selectedTier == tier;

    return InkWell(
      onTap: () => setState(() => _selectedTier = tier),
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.symmetric(
              horizontal: 10,
              vertical: isSmallScreen ? 8 : 10,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark ? const Color(0xFF1E1B4B) : const Color(0xFFEEF2FF))
                  : (isDark ? const Color(0xFF1E293B) : Colors.white),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF4F46E5)
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.18),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 11 : 12,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                      size: isSmallScreen ? 14 : 16,
                      color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF94A3B8),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      price,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 13 : 14.5,
                        fontWeight: FontWeight.w900,
                        color: isSelected
                            ? const Color(0xFF4F46E5)
                            : (isDark ? Colors.white : const Color(0xFF0F172A)),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      period,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 9.5 : 10.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  subtext,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 8.5 : 9.5,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),

          // Floating badge on top
          if (badge != null)
            Positioned(
              top: -7,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                  ),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD97706).withValues(alpha: 0.35),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Benefit Info Dialog
  // ---------------------------------------------------------------------------
  void _showBenefitDialog(
    BuildContext context, {
    required String title,
    required String description,
    required Color iconColor,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.star_rounded, color: iconColor, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          description,
          style: const TextStyle(fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSubscribe(BuildContext context) async {
    final user = context.read<AuthService>().currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, inicia sesión para suscribirte.')),
      );
      return;
    }

    final subNotifier = context.read<SubscriptionNotifier>();
    final subService = context.read<SubscriptionService>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await subNotifier.activateSubscription(
        userId: user.uid,
        tier: _selectedTier,
        service: subService,
      );

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('🎉 ¡Bienvenido a MediTime Pro! Todas las funciones están desbloqueadas.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
        navigator.pop(true);
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error al procesar suscripción: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _handleCancel(BuildContext context) async {
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;

    final subNotifier = context.read<SubscriptionNotifier>();
    final subService = context.read<SubscriptionService>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Volver al Plan Gratuito'),
        content: const Text(
          '¿Estás seguro de que deseas volver al plan gratuito? Las funciones ilimitadas, reportes PDF y voz de IA se desactivarán.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Mantener Pro'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await subNotifier.cancelSubscription(
        userId: user.uid,
        service: subService,
      );

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Has vuelto al Plan Gratuito.')),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Error al cancelar: $e')),
        );
      }
    }
  }
}

// =============================================================================
// VECTOR ILLUSTRATIONS & PAINTERS (Matching Image 1 Aesthetic)
// =============================================================================

/// Sparkling decorative rays radiating from the badge
class _SparkleRaysPainter extends CustomPainter {
  final bool isLeft;
  final Color color;

  const _SparkleRaysPainter({required this.isLeft, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    if (isLeft) {
      // Upper slanted ray (pointing up-left)
      canvas.drawLine(
        Offset(size.width * 0.95, size.height * 0.4),
        Offset(size.width * 0.05, size.height * 0.08),
        paint,
      );
      // Lower slanted ray (pointing slightly down-left)
      canvas.drawLine(
        Offset(size.width * 0.9, size.height * 0.7),
        Offset(size.width * 0.1, size.height * 0.88),
        paint,
      );
    } else {
      // Upper slanted ray (pointing up-right)
      canvas.drawLine(
        Offset(size.width * 0.05, size.height * 0.4),
        Offset(size.width * 0.95, size.height * 0.08),
        paint,
      );
      // Lower slanted ray (pointing slightly down-right)
      canvas.drawLine(
        Offset(size.width * 0.1, size.height * 0.7),
        Offset(size.width * 0.9, size.height * 0.88),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SparkleRaysPainter oldDelegate) =>
      oldDelegate.isLeft != isLeft || oldDelegate.color != color;
}

/// 3-Point Crown Painter
class _CrownPainter extends CustomPainter {
  final Color color;

  const _CrownPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, size.height * 0.22)
      ..lineTo(size.width * 0.26, size.height * 0.56)
      ..lineTo(size.width * 0.5, 0)
      ..lineTo(size.width * 0.74, size.height * 0.56)
      ..lineTo(size.width, size.height * 0.22)
      ..lineTo(size.width * 0.88, size.height)
      ..lineTo(size.width * 0.12, size.height)
      ..close();

    canvas.drawPath(path, paint);

    // Crown peak jewels
    canvas.drawCircle(Offset(0, size.height * 0.18), 1.5, paint);
    canvas.drawCircle(Offset(size.width * 0.5, 0), 1.8, paint);
    canvas.drawCircle(Offset(size.width, size.height * 0.18), 1.5, paint);
  }

  @override
  bool shouldRepaint(covariant _CrownPainter oldDelegate) => oldDelegate.color != color;
}

/// Card 1 Illustration: First Aid Kit + Blister Pack (Sky Blue)
class _MedicalKitIllustration extends StatelessWidget {
  const _MedicalKitIllustration();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(78, 52),
      painter: _MedicalKitPainter(),
    );
  }
}

class _MedicalKitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Ambient soft blue cloud behind
    final cloudPaint = Paint()
      ..color = const Color(0xFFBAE6FD).withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - 4, cy), width: 56, height: 40),
      cloudPaint,
    );

    // First Aid Kit Bag
    final kitRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx - 10, cy + 2), width: 34, height: 26),
      const Radius.circular(7),
    );
    final kitPaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(kitRect, kitPaint);

    // Kit handle
    final handlePaint = Paint()
      ..color = const Color(0xFF1D4ED8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx - 10, cy - 11), width: 13, height: 8),
      math.pi,
      math.pi,
      false,
      handlePaint,
    );

    // White Cross on Kit
    final crossPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx - 10, cy - 3), Offset(cx - 10, cy + 7), crossPaint);
    canvas.drawLine(Offset(cx - 15, cy + 2), Offset(cx - 5, cy + 2), crossPaint);

    // Subtle gloss line on kit
    final glossPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx - 22, cy - 7), Offset(cx - 16, cy - 7), glossPaint);

    // Blister Pack leaning on the right (tilted ~20 deg)
    canvas.save();
    canvas.translate(cx + 12, cy + 1);
    canvas.rotate(0.36);

    final blisterRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: 20, height: 32),
      const Radius.circular(5),
    );
    final blisterPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final blisterBorder = Paint()
      ..color = const Color(0xFF93C5FD)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(blisterRect, blisterPaint);
    canvas.drawRRect(blisterRect, blisterBorder);

    // 4 blister pockets with pill capsules
    final pillRed = Paint()..color = const Color(0xFFEF4444);
    final pillBlue = Paint()..color = const Color(0xFF2563EB);
    final pillWhite = Paint()..color = const Color(0xFFE2E8F0);

    // Row 1 Capsule (Red / White)
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(-6.5, -12, 5.5, 10), const Radius.circular(2.5)),
      pillRed,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(1.0, -12, 5.5, 10), const Radius.circular(2.5)),
      pillWhite,
    );

    // Row 2 Capsule (White / Blue)
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(-6.5, 2, 5.5, 10), const Radius.circular(2.5)),
      pillWhite,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(1.0, 2, 5.5, 10), const Radius.circular(2.5)),
      pillBlue,
    );

    canvas.restore();

    // Decorative blue sparkle rays
    final rayPaint = Paint()
      ..color = const Color(0xFF3B82F6)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx + 24, cy - 13), Offset(cx + 29, cy - 17), rayPaint);
    canvas.drawLine(Offset(cx + 31, cy - 6), Offset(cx + 36, cy - 7), rayPaint);
    canvas.drawLine(Offset(cx - 26, cy - 10), Offset(cx - 31, cy - 13), rayPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Card 2 Illustration: Caregiver + Family + Shield + Heart (Lavender)
class _CaregiverIllustration extends StatelessWidget {
  const _CaregiverIllustration();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(78, 52),
      painter: _CaregiverPainter(),
    );
  }
}

class _CaregiverPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Ambient soft lavender cloud behind
    final cloudPaint = Paint()
      ..color = const Color(0xFFE9D5FF).withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: 58, height: 42),
      cloudPaint,
    );

    // Family silhouettes (Center adult, Left child, Right adult)
    final adult1Paint = Paint()
      ..color = const Color(0xFFA855F7)
      ..style = PaintingStyle.fill;
    final adult2Paint = Paint()
      ..color = const Color(0xFFC084FC)
      ..style = PaintingStyle.fill;
    final childPaint = Paint()
      ..color = const Color(0xFF818CF8)
      ..style = PaintingStyle.fill;

    // Adult 1 (Center)
    canvas.drawCircle(Offset(cx - 2, cy - 9), 6.5, adult1Paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx - 10, cy - 2, 16, 17), const Radius.circular(6)),
      adult1Paint,
    );

    // Child (Left)
    canvas.drawCircle(Offset(cx - 15, cy - 4), 5.0, childPaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx - 21, cy + 2, 13, 14), const Radius.circular(5)),
      childPaint,
    );

    // Adult 2 (Right)
    canvas.drawCircle(Offset(cx + 11, cy - 6), 5.5, adult2Paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx + 5, cy + 1, 13, 15), const Radius.circular(5)),
      adult2Paint,
    );

    // Blue Shield in front
    final shieldPath = Path()
      ..moveTo(cx - 1, cy - 2)
      ..lineTo(cx + 12, cy + 2)
      ..lineTo(cx + 12, cy + 11)
      ..quadraticBezierTo(cx + 12, cy + 18, cx - 1, cy + 22)
      ..quadraticBezierTo(cx - 14, cy + 18, cx - 14, cy + 11)
      ..lineTo(cx - 14, cy + 2)
      ..close();

    final shieldPaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..style = PaintingStyle.fill;
    canvas.drawPath(shieldPath, shieldPaint);

    // White Cross on Shield
    final crossPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx - 1, cy + 4), Offset(cx - 1, cy + 15), crossPaint);
    canvas.drawLine(Offset(cx - 6.5, cy + 9.5), Offset(cx + 4.5, cy + 9.5), crossPaint);

    // Floating pink heart (Top-Left)
    final heartPath = Path()
      ..moveTo(cx - 20, cy - 13)
      ..cubicTo(cx - 23, cy - 17, cx - 27, cy - 14, cx - 25, cy - 10)
      ..cubicTo(cx - 23, cy - 7, cx - 20, cy - 5, cx - 20, cy - 5)
      ..cubicTo(cx - 20, cy - 5, cx - 17, cy - 7, cx - 15, cy - 10)
      ..cubicTo(cx - 13, cy - 14, cx - 17, cy - 17, cx - 20, cy - 13)
      ..close();

    final heartPaint = Paint()
      ..color = const Color(0xFFF43F5E)
      ..style = PaintingStyle.fill;
    canvas.drawPath(heartPath, heartPaint);

    // Sparkle rays on right
    final rayPaint = Paint()
      ..color = const Color(0xFF8B5CF6)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx + 20, cy - 10), Offset(cx + 25, cy - 14), rayPaint);
    canvas.drawLine(Offset(cx + 23, cy - 2), Offset(cx + 28, cy - 4), rayPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Card 3 Illustration: Medical Report in PDF (Rose Pink)
class _PdfReportIllustration extends StatelessWidget {
  const _PdfReportIllustration();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(78, 52),
      painter: _PdfReportPainter(),
    );
  }
}

class _PdfReportPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Ambient soft pink cloud behind
    final cloudPaint = Paint()
      ..color = const Color(0xFFFECDD3).withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: 56, height: 42),
      cloudPaint,
    );

    // Document Paper
    final paperPath = Path()
      ..moveTo(cx - 15, cy - 18)
      ..lineTo(cx + 7, cy - 18)
      ..lineTo(cx + 17, cy - 8)
      ..lineTo(cx + 17, cy + 18)
      ..lineTo(cx - 15, cy + 18)
      ..close();

    final paperPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final paperBorder = Paint()
      ..color = const Color(0xFFFDA4AF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawPath(paperPath, paperPaint);
    canvas.drawPath(paperPath, paperBorder);

    // Folded Dog-Ear Corner
    final foldPath = Path()
      ..moveTo(cx + 7, cy - 18)
      ..lineTo(cx + 7, cy - 8)
      ..lineTo(cx + 17, cy - 8)
      ..close();
    final foldPaint = Paint()
      ..color = const Color(0xFFFECDD3)
      ..style = PaintingStyle.fill;
    canvas.drawPath(foldPath, foldPaint);

    // Red PDF Badge in Center
    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx + 1, cy + 1), width: 26, height: 13),
      const Radius.circular(3.5),
    );
    final badgePaint = Paint()
      ..color = const Color(0xFFEF4444)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(badgeRect, badgePaint);

    // "PDF" text on badge
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'PDF',
        style: TextStyle(
          color: Colors.white,
          fontSize: 8.2,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(cx + 1 - textPainter.width / 2, cy + 1 - textPainter.height / 2),
    );

    // Document report lines below
    final linePaint = Paint()
      ..color = const Color(0xFFFDA4AF)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx - 9, cy + 11), Offset(cx + 11, cy + 11), linePaint);
    canvas.drawLine(Offset(cx - 9, cy + 14.5), Offset(cx + 5, cy + 14.5), linePaint);

    // Radiating pink sparkle rays
    final rayPaint = Paint()
      ..color = const Color(0xFFF43F5E)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx - 22, cy - 7), Offset(cx - 28, cy - 11), rayPaint);
    canvas.drawLine(Offset(cx - 21, cy + 5), Offset(cx - 26, cy + 8), rayPaint);
    canvas.drawLine(Offset(cx + 22, cy - 2), Offset(cx + 27, cy - 4), rayPaint);
    canvas.drawLine(Offset(cx + 22, cy + 8), Offset(cx + 27, cy + 11), rayPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Card 4 Illustration: Voice AI Assistant (Mint Green)
class _VoiceAssistantIllustration extends StatelessWidget {
  const _VoiceAssistantIllustration();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(78, 52),
      painter: _VoiceAssistantPainter(),
    );
  }
}

class _VoiceAssistantPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Ambient soft mint cloud behind
    final cloudPaint = Paint()
      ..color = const Color(0xFFA7F3D0).withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - 2, cy), width: 56, height: 42),
      cloudPaint,
    );

    // Microphone Base & Stand
    final micPaint = Paint()
      ..color = const Color(0xFF059669)
      ..style = PaintingStyle.fill;
    final micStroke = Paint()
      ..color = const Color(0xFF059669)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;

    // Mic Capsule
    final capsuleRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx - 4, cy - 3), width: 11, height: 18),
      const Radius.circular(5.5),
    );
    canvas.drawRRect(capsuleRect, micPaint);

    // Cradle arc around capsule
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx - 4, cy - 2), width: 20, height: 18),
      0,
      math.pi,
      false,
      micStroke,
    );

    // Stem and Base
    canvas.drawLine(Offset(cx - 4, cy + 7), Offset(cx - 4, cy + 14), micStroke);
    canvas.drawLine(Offset(cx - 10, cy + 14), Offset(cx + 2, cy + 14), micStroke);

    // Sound waves around mic: left and right
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx - 4, cy - 3), width: 28, height: 22),
      -math.pi * 0.72,
      math.pi * 0.44,
      false,
      micStroke..strokeWidth = 2.0,
    );
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx - 4, cy - 3), width: 36, height: 28),
      -math.pi * 0.68,
      math.pi * 0.36,
      false,
      micStroke..strokeWidth = 1.6,
    );

    // Floating Speech Bubble with 3 dots (Top-Right)
    final bubbleRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx + 10, cy - 16, 18, 14),
      const Radius.circular(4.5),
    );
    final bubblePaint = Paint()
      ..color = const Color(0xFF10B981)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(bubbleRect, bubblePaint);

    // Bubble tail
    final tailPath = Path()
      ..moveTo(cx + 12, cy - 2)
      ..lineTo(cx + 9, cy + 1.5)
      ..lineTo(cx + 16, cy - 2)
      ..close();
    canvas.drawPath(tailPath, bubblePaint);

    // 3 white dots inside bubble
    final dotPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(cx + 14.5, cy - 9), 1.2, dotPaint);
    canvas.drawCircle(Offset(cx + 19, cy - 9), 1.2, dotPaint);
    canvas.drawCircle(Offset(cx + 23.5, cy - 9), 1.2, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Card 5 Illustration: Home Screen Widgets (Amber / Yellow)
class _HomeWidgetIllustration extends StatelessWidget {
  const _HomeWidgetIllustration();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(60, 50),
      painter: _HomeWidgetPainter(),
    );
  }
}

class _HomeWidgetPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Golden ambient sunburst cloud behind
    final cloudPaint = Paint()
      ..color = const Color(0xFFFDE68A).withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), 20, cloudPaint);

    // Smartphone Outline
    final phoneRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: 28, height: 40),
      const Radius.circular(6.5),
    );
    final phonePaint = Paint()
      ..color = const Color(0xFF0284C7)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(phoneRect, phonePaint);

    // Phone Screen
    final screenRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: 23, height: 35),
      const Radius.circular(4.5),
    );
    final screenPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawRRect(screenRect, screenPaint);

    // Top home widget card on phone screen
    final widgetRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy - 4.5), width: 18, height: 16),
      const Radius.circular(3),
    );
    final widgetPaint = Paint()
      ..color = const Color(0xFFFEF3C7)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(widgetRect, widgetPaint);

    // House icon in widget
    final iconPaint = Paint()
      ..color = const Color(0xFFD97706)
      ..style = PaintingStyle.fill;
    final roofPath = Path()
      ..moveTo(cx, cy - 10)
      ..lineTo(cx - 4, cy - 6)
      ..lineTo(cx + 4, cy - 6)
      ..close();
    canvas.drawPath(roofPath, iconPaint);

    // 4 app tiles grid below
    final tilePaint = Paint()..color = const Color(0xFF10B981);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx - 7, cy + 5, 5, 5), const Radius.circular(1.5)),
      tilePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx + 2, cy + 5, 5, 5), const Radius.circular(1.5)),
      tilePaint,
    );

    // Golden sunburst rays around phone
    final rayPaint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx - 18, cy - 10), Offset(cx - 23, cy - 13), rayPaint);
    canvas.drawLine(Offset(cx - 19, cy + 9), Offset(cx - 24, cy + 12), rayPaint);
    canvas.drawLine(Offset(cx + 18, cy - 9), Offset(cx + 23, cy - 11), rayPaint);
    canvas.drawLine(Offset(cx + 18, cy + 8), Offset(cx + 23, cy + 10), rayPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Active Subscription Checkmark Circle with Sparkling Rays (Image 1 Bottom)
class _ActiveCheckPainter extends CustomPainter {
  const _ActiveCheckPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Green Checkmark circle with subtle white glow
    final circlePaint = Paint()
      ..color = const Color(0xFF059669)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), 14, circlePaint);

    // Clean white border around circle
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(Offset(cx, cy), 14, borderPaint);

    // White Checkmark icon
    final checkPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final checkPath = Path()
      ..moveTo(cx - 5.5, cy)
      ..lineTo(cx - 1.5, cy + 4)
      ..lineTo(cx + 5.5, cy - 4);
    canvas.drawPath(checkPath, checkPaint);

    // 6 Radiating white sparkle dashes (3 on left, 3 on right)
    final rayPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    // Left rays
    canvas.drawLine(Offset(cx - 16, cy - 6), Offset(cx - 20, cy - 8), rayPaint);
    canvas.drawLine(Offset(cx - 17, cy), Offset(cx - 21, cy), rayPaint);
    canvas.drawLine(Offset(cx - 16, cy + 6), Offset(cx - 20, cy + 8), rayPaint);

    // Right rays
    canvas.drawLine(Offset(cx + 16, cy - 6), Offset(cx + 20, cy - 8), rayPaint);
    canvas.drawLine(Offset(cx + 17, cy), Offset(cx + 21, cy), rayPaint);
    canvas.drawLine(Offset(cx + 16, cy + 6), Offset(cx + 20, cy + 8), rayPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
