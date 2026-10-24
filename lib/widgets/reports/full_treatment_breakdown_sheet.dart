// lib/widgets/reports/full_treatment_breakdown_sheet.dart
import 'package:flutter/material.dart';
import 'package:meditime/l10n/generated/app_localizations.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/services/tratamiento_service.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:meditime/widgets/reports/treatment_accordion_card.dart';
import 'package:provider/provider.dart';

/// Hoja modal (Bottom Sheet) que presenta el desglose completo e interactivo
/// de todos los tratamientos de un período, con filtros de adherencia y búsqueda.
class FullTreatmentBreakdownSheet extends StatefulWidget {
  final List<Tratamiento> tratamientos;
  final Map<String, DateTime> dateRange;
  final Map<String, int> Function(Tratamiento, Map<String, DateTime>)? statsCalculator;

  const FullTreatmentBreakdownSheet({
    super.key,
    required this.tratamientos,
    required this.dateRange,
    this.statsCalculator,
  });

  static Future<void> show(
    BuildContext context, {
    required List<Tratamiento> tratamientos,
    required Map<String, DateTime> dateRange,
    Map<String, int> Function(Tratamiento, Map<String, DateTime>)? statsCalculator,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FullTreatmentBreakdownSheet(
        tratamientos: tratamientos,
        dateRange: dateRange,
        statsCalculator: statsCalculator,
      ),
    );
  }

  @override
  State<FullTreatmentBreakdownSheet> createState() =>
      _FullTreatmentBreakdownSheetState();
}

class _FullTreatmentBreakdownSheetState
    extends State<FullTreatmentBreakdownSheet> {
  final Set<String> _expandedTreatments = <String>{};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedAdherenceTier; // null (todos), 'high', 'medium', 'low'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Map<String, int> _getStats(Tratamiento t) {
    if (widget.statsCalculator != null) {
      return widget.statsCalculator!(t, widget.dateRange);
    }
    // Cálculo de respaldo estándar si no se pasa función
    final start = widget.dateRange['start']!;
    final end = widget.dateRange['end']!;
    int tomadas = 0;
    int omitidas = 0;
    int notificadas = 0;
    int aplazadas = 0;
    final now = DateTime.now();

    final List<DateTime> recordedTimes = [];
    t.doseStatus.forEach((key, status) {
      final parsed = DateTime.tryParse(key);
      if (parsed != null &&
          !parsed.isBefore(start) &&
          !parsed.isAfter(end) &&
          parsed.isBefore(now)) {
        recordedTimes.add(parsed);
        switch (status) {
          case DoseStatus.tomada:
            tomadas++;
            break;
          case DoseStatus.omitida:
            omitidas++;
            break;
          case DoseStatus.notificada:
            notificadas++;
            break;
          case DoseStatus.aplazada:
            aplazadas++;
            break;
          case DoseStatus.pendiente:
            omitidas++;
            break;
        }
      }
    });

    final todasLasDosis = TratamientoService.generarDosisEnRango(t, start, end);
    for (final doseTime in todasLasDosis) {
      if (!doseTime.isBefore(start) &&
          !doseTime.isAfter(end) &&
          doseTime.isBefore(now)) {
        final alreadyLogged = recordedTimes.any(
          (rt) => rt.difference(doseTime).inMinutes.abs() <= 60,
        );
        if (!alreadyLogged) {
          omitidas++;
        }
      }
    }

    final int programadasPasadas = tomadas + omitidas + notificadas + aplazadas;
    return {
      'tomadas': tomadas,
      'omitidas': omitidas,
      'notificadas': notificadas,
      'aplazadas': aplazadas,
      'programadasPasadas': programadasPasadas,
    };
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Color color,
    required int count,
    bool showBorder = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: showBorder
              ? Border.all(
                  color: isSelected ? color : color.withValues(alpha: 0.25),
                  width: isSelected ? 1.5 : 1,
                )
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : color,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? Colors.white.withValues(alpha: 0.25)
                        : color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color:
                      isSelected ? Colors.white : color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pref = context.watch<PreferenceNotifier>();
    final showBorder = pref.showCardBorder || pref.highContrast;

    // Precalcular estadísticas y porcentajes para todos los tratamientos
    final Map<String, Map<String, int>> statsMap = {};
    final Map<String, double> adherenceMap = {};

    int countHigh = 0;
    int countMedium = 0;
    int countLow = 0;

    for (final t in widget.tratamientos) {
      final s = _getStats(t);
      statsMap[t.id] = s;
      final prog = s['programadasPasadas'] ?? 0;
      final tom = s['tomadas'] ?? 0;
      final adh = prog > 0 ? (tom / prog) * 100 : 0.0;
      adherenceMap[t.id] = adh;

      if (adh >= 80) {
        countHigh++;
      } else if (adh >= 50) {
        countMedium++;
      } else {
        countLow++;
      }
    }

    final filtered =
        widget.tratamientos.where((t) {
          final adh = adherenceMap[t.id] ?? 0.0;
          if (_selectedAdherenceTier == 'high' && adh < 80) return false;
          if (_selectedAdherenceTier == 'medium' && (adh < 50 || adh >= 80)) {
            return false;
          }
          if (_selectedAdherenceTier == 'low' && adh >= 50) return false;

          if (_searchQuery.isNotEmpty) {
            final name = t.nombreMedicamento.toLowerCase();
            if (!name.contains(_searchQuery)) return false;
          }

          return true;
        }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder:
          (ctx, scrollController) => Container(
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              border: showBorder ? Border.all(color: AppTheme.borderColor) : null,
            ),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n?.reportsBreakdownTitle ??
                                'Desglose por tratamiento',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryTextColor,
                            ),
                          ),
                          Text(
                            '${widget.tratamientos.length} tratamientos en este período',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                // Chips de filtro por adherencia
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      _buildFilterChip(
                        label: 'Todos',
                        isSelected: _selectedAdherenceTier == null,
                        onTap: () => setState(() => _selectedAdherenceTier = null),
                        color: AppTheme.primaryColor,
                        count: widget.tratamientos.length,
                        showBorder: showBorder,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Alta (≥80%)',
                        isSelected: _selectedAdherenceTier == 'high',
                        onTap:
                            () => setState(
                              () =>
                                  _selectedAdherenceTier =
                                      _selectedAdherenceTier == 'high'
                                          ? null
                                          : 'high',
                            ),
                        color: AppTheme.successColor,
                        count: countHigh,
                        showBorder: showBorder,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Media (50-79%)',
                        isSelected: _selectedAdherenceTier == 'medium',
                        onTap:
                            () => setState(
                              () =>
                                  _selectedAdherenceTier =
                                      _selectedAdherenceTier == 'medium'
                                          ? null
                                          : 'medium',
                            ),
                        color: const Color(0xFFF59E0B),
                        count: countMedium,
                        showBorder: showBorder,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Baja (<50%)',
                        isSelected: _selectedAdherenceTier == 'low',
                        onTap:
                            () => setState(
                              () =>
                                  _selectedAdherenceTier =
                                      _selectedAdherenceTier == 'low'
                                          ? null
                                          : 'low',
                            ),
                        color: AppTheme.errorColor,
                        count: countLow,
                        showBorder: showBorder,
                      ),
                    ],
                  ),
                ),
                // Barra de búsqueda rápida de tratamientos si hay más de 4
                if (widget.tratamientos.length > 4)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 6,
                    ),
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: AppTheme.lightShadow,
                        border: showBorder ? Border.all(color: AppTheme.borderColor) : null,
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged:
                            (val) => setState(
                              () => _searchQuery = val.trim().toLowerCase(),
                            ),
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.primaryTextColor,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Buscar medicamento...',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: AppTheme.secondaryTextColor,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            size: 18,
                            color: AppTheme.secondaryTextColor,
                          ),
                          suffixIcon:
                              _searchController.text.isNotEmpty
                                  ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                  : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                const Divider(height: 1),
                Expanded(
                  child:
                      filtered.isEmpty
                          ? Center(
                            child: Text(
                              'No hay tratamientos registrados con este filtro.',
                              style: TextStyle(
                                color: AppTheme.secondaryTextColor,
                                fontSize: 13,
                              ),
                            ),
                          )
                          : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (ctx, index) {
                              final t = filtered[index];
                              final stats =
                                  statsMap[t.id] ??
                                  {
                                    'programadasPasadas': 0,
                                    'tomadas': 0,
                                    'omitidas': 0,
                                    'notificadas': 0,
                                    'aplazadas': 0,
                                  };
                              final isExpanded = _expandedTreatments.contains(
                                t.id,
                              );

                              return TreatmentAccordionCard(
                                tratamiento: t,
                                stats: stats,
                                isExpanded: isExpanded,
                                onToggle: () {
                                  setState(() {
                                    if (isExpanded) {
                                      _expandedTreatments.remove(t.id);
                                    } else {
                                      _expandedTreatments.add(t.id);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                ),
              ],
            ),
          ),
    );
  }
}
