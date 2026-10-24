// lib/widgets/reports/full_history_sheet.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:provider/provider.dart';

/// Hoja modal con el historial completo interactivo de dosis pasadas y filtros.
class FullHistorySheet extends StatefulWidget {
  final List<Tratamiento> tratamientos;

  const FullHistorySheet({super.key, required this.tratamientos});

  static Future<void> show(
    BuildContext context,
    List<Tratamiento> tratamientos,
  ) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FullHistorySheet(tratamientos: tratamientos),
    );
  }

  @override
  State<FullHistorySheet> createState() => _FullHistorySheetState();
}

class _FullHistorySheetState extends State<FullHistorySheet> {
  DoseStatus? _selectedStatus;
  String _selectedMed = 'Todos';

  Widget _buildHistoryFilterChip({
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
    final pref = context.watch<PreferenceNotifier>();
    final showBorder = pref.showCardBorder || pref.highContrast;
    final List<Map<String, dynamic>> allHistory = [];
    final now = DateTime.now();
    for (var t in widget.tratamientos) {
      t.doseStatus.forEach((dateString, status) {
        final doseTime = DateTime.tryParse(dateString);
        if (doseTime != null && doseTime.isBefore(now)) {
          allHistory.add({'treatment': t, 'time': doseTime, 'status': status});
        }
      });
    }
    allHistory.sort(
      (a, b) => (b['time'] as DateTime).compareTo(a['time'] as DateTime),
    );

    final uniqueMeds = <String>{};
    for (var t in widget.tratamientos) {
      uniqueMeds.add(t.nombreMedicamento);
    }
    final List<String> medList = ['Todos', ...uniqueMeds];

    final filtered =
        allHistory.where((entry) {
          if (_selectedStatus != null && entry['status'] != _selectedStatus) {
            return false;
          }
          if (_selectedMed != 'Todos' &&
              (entry['treatment'] as Tratamiento).nombreMedicamento !=
                  _selectedMed) {
            return false;
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
              color: Theme.of(context).cardColor,
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
                            'Historial de tomas',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryTextColor,
                            ),
                          ),
                          Text(
                            '${allHistory.length} dosis registradas',
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
                // Filter row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      _buildHistoryFilterChip(
                        label: 'Todas',
                        isSelected: _selectedStatus == null,
                        onTap: () => setState(() => _selectedStatus = null),
                        color: AppTheme.primaryColor,
                        count: allHistory.length,
                        showBorder: showBorder,
                      ),
                      const SizedBox(width: 8),
                      _buildHistoryFilterChip(
                        label: 'Tomadas',
                        isSelected: _selectedStatus == DoseStatus.tomada,
                        onTap:
                            () => setState(
                              () => _selectedStatus = DoseStatus.tomada,
                            ),
                        color: AppTheme.successColor,
                        count:
                            allHistory
                                .where((e) => e['status'] == DoseStatus.tomada)
                                .length,
                        showBorder: showBorder,
                      ),
                      const SizedBox(width: 8),
                      _buildHistoryFilterChip(
                        label: 'Omitidas',
                        isSelected: _selectedStatus == DoseStatus.omitida,
                        onTap:
                            () => setState(
                              () => _selectedStatus = DoseStatus.omitida,
                            ),
                        color: AppTheme.errorColor,
                        count:
                            allHistory
                                .where((e) => e['status'] == DoseStatus.omitida)
                                .length,
                        showBorder: showBorder,
                      ),
                      const SizedBox(width: 8),
                      _buildHistoryFilterChip(
                        label: 'Aplazadas',
                        isSelected: _selectedStatus == DoseStatus.aplazada,
                        onTap:
                            () => setState(
                              () => _selectedStatus = DoseStatus.aplazada,
                            ),
                        color: Colors.orange,
                        count:
                            allHistory
                                .where(
                                  (e) => e['status'] == DoseStatus.aplazada,
                                )
                                .length,
                        showBorder: showBorder,
                      ),
                    ],
                  ),
                ),
                if (medList.length > 2) ...[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
                    child: Row(
                      children:
                          medList.map((med) {
                            final isSel = _selectedMed == med;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: FilterChip(
                                label: Text(
                                  med,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight:
                                        isSel
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                  ),
                                ),
                                selected: isSel,
                                onSelected:
                                    (sel) => setState(() => _selectedMed = med),
                                backgroundColor: AppTheme.surfaceColor,
                                selectedColor: AppTheme.primaryColor.withValues(
                                  alpha: 0.15,
                                ),
                                labelStyle: TextStyle(
                                  color:
                                      isSel
                                          ? AppTheme.primaryColor
                                          : AppTheme.secondaryTextColor,
                                ),
                                checkmarkColor: AppTheme.primaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                  ),
                ],
                const Divider(height: 1),
                Expanded(
                  child:
                      filtered.isEmpty
                          ? Center(
                            child: Text(
                              'No hay tomas registradas con este filtro.',
                              style: TextStyle(
                                color: AppTheme.secondaryTextColor,
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
                              final entry = filtered[index];
                              final t = entry['treatment'] as Tratamiento;
                              final doseTime = entry['time'] as DateTime;
                              final status = entry['status'] as DoseStatus;

                              Color statusColor;
                              IconData statusIcon;
                              String statusLabel;
                              switch (status) {
                                case DoseStatus.tomada:
                                  statusColor = AppTheme.successColor;
                                  statusIcon = Icons.check;
                                  statusLabel = 'Tomada';
                                  break;
                                case DoseStatus.omitida:
                                  statusColor = AppTheme.errorColor;
                                  statusIcon = Icons.close;
                                  statusLabel = 'Omitida';
                                  break;
                                case DoseStatus.aplazada:
                                  statusColor = Colors.orange;
                                  statusIcon = Icons.schedule;
                                  statusLabel = 'Aplazada';
                                  break;
                                case DoseStatus.notificada:
                                  statusColor = Colors.amber;
                                  statusIcon = Icons.notifications;
                                  statusLabel = 'Notificada';
                                  break;
                                case DoseStatus.pendiente:
                                  statusColor = Colors.grey;
                                  statusIcon = Icons.hourglass_empty;
                                  statusLabel = 'Pendiente';
                                  break;
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: AppTheme.cardShadow,
                                  border: showBorder
                                      ? Border.all(
                                          color: AppTheme.borderColor,
                                        )
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        statusIcon,
                                        color: statusColor,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            t.nombreMedicamento,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.primaryTextColor,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '${t.presentacion} · ${t.dosisPorToma} dosis · ${DateFormat('dd MMM, hh:mm a', 'es').format(doseTime)}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color:
                                                  AppTheme.secondaryTextColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(alpha: 0.10),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        statusLabel,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: statusColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
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
