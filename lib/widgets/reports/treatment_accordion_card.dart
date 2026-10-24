// lib/widgets/reports/treatment_accordion_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/screens/medication/detalle_receta_page.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:meditime/widgets/container_transform_card.dart';
import 'package:provider/provider.dart';

/// Tarjeta desplegable (acordeón) para visualizar el rendimiento y detalles
/// de un tratamiento específico dentro de un período de reportes.
class TreatmentAccordionCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final int programadas = stats['programadasPasadas'] ?? 0;
    final int tomadas = stats['tomadas'] ?? 0;
    final int omitidas = stats['omitidas'] ?? 0;
    final int notificadasCount = stats['notificadas'] ?? 0;
    final int aplazadasCount = stats['aplazadas'] ?? 0;
    final double adherence =
        programadas > 0 ? (tomadas / programadas) * 100 : 0.0;



    final pref = context.watch<PreferenceNotifier>();
    final showBorder = pref.showCardBorder || pref.highContrast;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
        border: showBorder ? Border.all(color: AppTheme.borderColor) : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tratamiento.nombreMedicamento,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: SizedBox(
                              height: 6,
                              child:
                                  programadas > 0
                                      ? Row(
                                        children: [
                                          if (tomadas > 0)
                                            Expanded(
                                              flex: tomadas,
                                              child: Container(
                                                color: AppTheme.successColor,
                                              ),
                                            ),
                                          if (omitidas > 0)
                                            Expanded(
                                              flex: omitidas,
                                              child: Container(
                                                color: AppTheme.errorColor,
                                              ),
                                            ),
                                          if (notificadasCount > 0)
                                            Expanded(
                                              flex: notificadasCount,
                                              child: Container(
                                                color: Colors.amber,
                                              ),
                                            ),
                                          if (aplazadasCount > 0)
                                            Expanded(
                                              flex: aplazadasCount,
                                              child: Container(
                                                color: Colors.orange,
                                              ),
                                            ),
                                          if (programadas -
                                                  tomadas -
                                                  omitidas -
                                                  notificadasCount -
                                                  aplazadasCount >
                                              0)
                                            Expanded(
                                              flex:
                                                  programadas -
                                                  tomadas -
                                                  omitidas -
                                                  notificadasCount -
                                                  aplazadasCount,
                                              child: Container(
                                                color: AppTheme.borderColor,
                                              ),
                                            ),
                                        ],
                                      )
                                      : Container(color: AppTheme.borderColor),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Tomadas $tomadas · Omitidas $omitidas · Notif. $notificadasCount · Aplaz. $aplazadasCount",
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "${adherence.toInt()}%",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryTextColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: Colors.grey[400],
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(
                  left: 20,
                  right: 20,
                  bottom: 16,
                  top: 0,
                ),
                child: Column(
                  children: [
                    Divider(color: AppTheme.borderColor, height: 1),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildDetailItem(
                          Icons.date_range,
                          "Inicio",
                          DateFormat(
                            'dd MMM yyyy',
                            'es',
                          ).format(tratamiento.fechaInicioTratamiento),
                        ),
                        _buildDetailItem(
                          Icons.date_range_sharp,
                          "Fin",
                          DateFormat(
                            'dd MMM yyyy',
                            'es',
                          ).format(tratamiento.fechaFinTratamiento),
                        ),
                        _buildDetailItem(
                          Icons.medical_services_outlined,
                          "Dosis",
                          "Cada ${tratamiento.intervaloDosis.inHours} h",
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
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
                      openBuilder:
                          (context, _) => DetalleRecetaPage(
                            tratamiento: tratamiento,
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
                                        alpha: 0.3,
                                      ),
                                    )
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.visibility_outlined,
                                  size: 16,
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
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              crossFadeState:
                  isExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
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
            Icon(icon, size: 14, color: Colors.grey[400]),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[400],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
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
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
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
