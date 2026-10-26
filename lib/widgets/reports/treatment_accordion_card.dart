// lib/widgets/reports/treatment_accordion_card.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/screens/medication/detalle_receta_page.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:meditime/widgets/container_transform_card.dart';
import 'package:provider/provider.dart';

/// Tarjeta desplegable (acordeón) refinada con la filosofía de diseño Emil Kowalski
/// para visualizar el rendimiento y detalles de un tratamiento médico.
class TreatmentAccordionCard extends StatefulWidget {
  final Tratamiento tratamiento;
  final Map<String, int> stats;
  final bool isExpanded;
  final VoidCallback onToggle;

  const TreatmentAccordionCard({
    super.key,
    required this.tratamiento,
    required this.stats,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  State<TreatmentAccordionCard> createState() => _TreatmentAccordionCardState();
}

class _TreatmentAccordionCardState extends State<TreatmentAccordionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
      reverseDuration: const Duration(milliseconds: 160),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.985).animate(
      CurvedAnimation(
        parent: _pressController,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    _pressController.forward();
  }

  void _onTapUp(TapUpDetails _) {
    _pressController.reverse();
  }

  void _onTapCancel() {
    _pressController.reverse();
  }

  Color _getAdherenceTierColor(double adherence) {
    final int pct = adherence.toInt();
    if (pct >= 80) {
      return AppTheme.successColor;
    } else if (pct >= 50) {
      return const Color(0xFFD97706); // Amber cálido y legible
    } else {
      return AppTheme.errorColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final int programadas = widget.stats['programadasPasadas'] ?? 0;
    final int tomadas = widget.stats['tomadas'] ?? 0;
    final int omitidas = widget.stats['omitidas'] ?? 0;
    final int notificadasCount = widget.stats['notificadas'] ?? 0;
    final int aplazadasCount = widget.stats['aplazadas'] ?? 0;
    final double adherence =
        programadas > 0 ? (tomadas / programadas) * 100 : 0.0;

    final pref = context.watch<PreferenceNotifier>();
    final showBorder = pref.showCardBorder || pref.highContrast;

    final tierColor = _getAdherenceTierColor(adherence);

    // Subtítulo con presentación y posología si están disponibles
    final subtitleParts = <String>[];
    if (widget.tratamiento.presentacion.trim().isNotEmpty) {
      subtitleParts.add(widget.tratamiento.presentacion.trim());
    }
    if (widget.tratamiento.intervaloDosis.inHours > 0) {
      subtitleParts.add("Cada ${widget.tratamiento.intervaloDosis.inHours}h");
    }
    final subtitleText = subtitleParts.join(" · ");

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnimation.value,
        child: child,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: isDark ? 0.22 : (widget.isExpanded ? 0.06 : 0.035),
              ),
              blurRadius: widget.isExpanded ? 14 : 9,
              offset: Offset(0, widget.isExpanded ? 4 : 2),
            ),
          ],
          border: Border.all(
            color: widget.isExpanded
                ? AppTheme.primaryColor.withValues(alpha: isDark ? 0.35 : 0.22)
                : (showBorder
                    ? AppTheme.borderColor
                    : AppTheme.borderColor.withValues(alpha: isDark ? 0.3 : 0.5)),
            width: widget.isExpanded ? 1.2 : 1.0,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: _onTapDown,
                onTapUp: _onTapUp,
                onTapCancel: _onTapCancel,
                onTap: () {
                  HapticFeedback.lightImpact();
                  widget.onToggle();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.tratamiento.nombreMedicamento,
                                    style: TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryTextColor,
                                      letterSpacing: -0.3,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildSegmentedProgressBar(
                              tomadas: tomadas,
                              omitidas: omitidas,
                              notificadas: notificadasCount,
                              aplazadas: aplazadasCount,
                              programadas: programadas,
                              isDark: isDark,
                            ),
                            if (subtitleText.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                subtitleText,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppTheme.secondaryTextColor,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildAdherenceBadge(
                        adherence,
                        tierColor,
                        showBorder: showBorder,
                      ),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: widget.isExpanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppTheme.secondaryTextColor.withValues(alpha: 0.7),
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: widget.isExpanded
                    ? Padding(
                        padding: const EdgeInsets.only(
                          left: 16,
                          right: 16,
                          bottom: 16,
                          top: 0,
                        ),
                        child: Column(
                          children: [
                            Divider(
                              color: AppTheme.borderColor.withValues(alpha: 0.7),
                              height: 1,
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildDetailItem(
                                  Icons.calendar_today_outlined,
                                  "Inicio",
                                  DateFormat('dd MMM yyyy', 'es')
                                      .format(widget.tratamiento.fechaInicioTratamiento),
                                ),
                                _buildDetailItem(
                                  Icons.event_available_outlined,
                                  "Fin",
                                  DateFormat('dd MMM yyyy', 'es')
                                      .format(widget.tratamiento.fechaFinTratamiento),
                                ),
                                _buildDetailItem(
                                  Icons.schedule_rounded,
                                  "Dosis",
                                  "Cada ${widget.tratamiento.intervaloDosis.inHours} h",
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildMiniStatChip(
                                    "Tomadas",
                                    tomadas,
                                    AppTheme.successColor,
                                    showBorder: showBorder,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: _buildMiniStatChip(
                                    "Omitidas",
                                    omitidas,
                                    AppTheme.errorColor,
                                    showBorder: showBorder,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: _buildMiniStatChip(
                                    "Notificadas",
                                    notificadasCount,
                                    Colors.amber,
                                    showBorder: showBorder,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: _buildMiniStatChip(
                                    "Aplazadas",
                                    aplazadasCount,
                                    Colors.orange,
                                    showBorder: showBorder,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            ContainerTransformCard<void>(
                              borderRadius: BorderRadius.circular(12),
                              closedColor: Colors.transparent,
                              closedShadows: const [],
                              showBorder: false,
                              openBuilder: (context, _) => DetalleRecetaPage(
                                tratamiento: widget.tratamiento,
                                canEdit: false,
                              ),
                              closedBuilder: (context, openContainer) {
                                return InkWell(
                                  onTap: openContainer,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                      horizontal: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withValues(
                                        alpha: 0.08,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: showBorder
                                          ? Border.all(
                                              color: AppTheme.primaryColor.withValues(
                                                alpha: 0.25,
                                              ),
                                            )
                                          : null,
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.visibility_outlined,
                                          size: 15,
                                          color: AppTheme.primaryColor,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          "Ver detalle completo del medicamento",
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primaryColor,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          size: 11,
                                          color: AppTheme.primaryColor.withValues(alpha: 0.7),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentedProgressBar({
    required int tomadas,
    required int omitidas,
    required int notificadas,
    required int aplazadas,
    required int programadas,
    required bool isDark,
  }) {
    final trackColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFEFF2F6);

    final totalDoses = programadas > 0
        ? programadas
        : (tomadas + omitidas + notificadas + aplazadas);

    if (totalDoses <= 0) {
      return Container(
        height: 6.5,
        decoration: BoxDecoration(
          color: trackColor,
          borderRadius: BorderRadius.circular(100),
        ),
      );
    }

    final activeSegments = <Map<String, dynamic>>[];
    if (tomadas > 0) {
      activeSegments.add({'flex': tomadas, 'color': AppTheme.successColor});
    }
    if (omitidas > 0) {
      activeSegments.add({'flex': omitidas, 'color': AppTheme.errorColor});
    }
    if (notificadas > 0) {
      activeSegments.add({'flex': notificadas, 'color': Colors.amber});
    }
    if (aplazadas > 0) {
      activeSegments.add({'flex': aplazadas, 'color': Colors.orange});
    }

    final activeDoses = tomadas + omitidas + notificadas + aplazadas;
    final remaining = totalDoses - activeDoses;

    return Container(
      height: 6.5,
      decoration: BoxDecoration(
        color: trackColor,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        children: [
          for (int i = 0; i < activeSegments.length; i++) ...[
            if (i > 0) const SizedBox(width: 2.5),
            Expanded(
              flex: activeSegments[i]['flex'] as int,
              child: Container(
                height: 6.5,
                decoration: BoxDecoration(
                  color: activeSegments[i]['color'] as Color,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
          ],
          if (remaining > 0)
            Expanded(
              flex: remaining,
              child: const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }

  Widget _buildAdherenceBadge(
    double adherence,
    Color tierColor, {
    bool showBorder = false,
  }) {
    final int pct = adherence.toInt();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tierColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: showBorder
            ? Border.all(
                color: tierColor.withValues(alpha: 0.35),
                width: 0.8,
              )
            : null,
      ),
      child: Text(
        "$pct%",
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: tierColor,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: AppTheme.secondaryTextColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.secondaryTextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryTextColor,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStatChip(
    String label,
    int value,
    Color color, {
    bool showBorder = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: showBorder
            ? Border.all(color: color.withValues(alpha: 0.3))
            : null,
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              const SizedBox(width: 4),
              Text(
                "$label: $value",
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
