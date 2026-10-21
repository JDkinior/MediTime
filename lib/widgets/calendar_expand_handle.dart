import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/theme/app_theme.dart';

/// Barra indicadora táctil y visual colocada en la base del contenedor blanco
/// del calendario para mostrar y permitir expandir (semanal -> quincenal -> mensual)
/// o contraer (mensual -> quincenal -> semanal) de forma gradual y suave.
class CalendarExpandHandle extends StatefulWidget {
  final CalendarFormat calendarFormat;
  final ValueChanged<CalendarFormat> onFormatChanged;

  const CalendarExpandHandle({
    super.key,
    required this.calendarFormat,
    required this.onFormatChanged,
  });

  @override
  State<CalendarExpandHandle> createState() => _CalendarExpandHandleState();
}

class _CalendarExpandHandleState extends State<CalendarExpandHandle> {
  static const List<CalendarFormat> _formatOrder = [
    CalendarFormat.week,
    CalendarFormat.twoWeeks,
    CalendarFormat.month,
  ];

  static const double _dragStepThreshold = 22.0;

  double _dragAccumulator = 0.0;
  bool _stepTriggeredDuringDrag = false;
  bool _isDragging = false;

  void _stepExpand() {
    final currentIndex = _formatOrder.indexOf(widget.calendarFormat).clamp(0, _formatOrder.length - 1);
    if (currentIndex < _formatOrder.length - 1) {
      widget.onFormatChanged(_formatOrder[currentIndex + 1]);
    }
  }

  void _stepCollapse() {
    final currentIndex = _formatOrder.indexOf(widget.calendarFormat).clamp(0, _formatOrder.length - 1);
    if (currentIndex > 0) {
      widget.onFormatChanged(_formatOrder[currentIndex - 1]);
    }
  }

  void _resetDrag() {
    if (mounted) {
      setState(() {
        _isDragging = false;
        _dragAccumulator = 0.0;
        _stepTriggeredDuringDrag = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark || AppTheme.currentIsDark;
    final preferenceNotifier = Provider.of<PreferenceNotifier?>(context);
    final isHighContrast = preferenceNotifier?.highContrast ?? false;

    final Color handleColor;
    if (isHighContrast) {
      handleColor = isDark ? const Color(0xFFB0B0B0) : const Color(0xFF666666);
    } else {
      handleColor = isDark
          ? (_isDragging ? const Color(0xFF727885) : const Color(0xFF555A64))
          : (_isDragging ? const Color(0xFF9CA3AF) : const Color(0xFFD1D5DB));
    }

    final isExpanded = widget.calendarFormat == CalendarFormat.month;
    final langCode = Localizations.maybeLocaleOf(context)?.languageCode ?? 'es';
    final isEnglish = langCode == 'en';
    final label = isExpanded
        ? (isEnglish ? 'Collapse calendar' : 'Contraer calendario')
        : (isEnglish ? 'Expand calendar' : 'Expandir calendario');

    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (widget.calendarFormat == CalendarFormat.month) {
              widget.onFormatChanged(CalendarFormat.week);
            } else {
              widget.onFormatChanged(CalendarFormat.month);
            }
          },
          onVerticalDragDown: (_) {
            setState(() {
              _isDragging = true;
              _dragAccumulator = 0.0;
              _stepTriggeredDuringDrag = false;
            });
          },
          onVerticalDragStart: (_) {
            setState(() {
              _isDragging = true;
            });
          },
          onVerticalDragUpdate: (details) {
            _dragAccumulator += details.delta.dy;
            final currentIndex = _formatOrder.indexOf(widget.calendarFormat).clamp(0, _formatOrder.length - 1);

            if (_dragAccumulator >= _dragStepThreshold) {
              if (currentIndex < _formatOrder.length - 1) {
                _stepTriggeredDuringDrag = true;
                _stepExpand();
                _dragAccumulator = 0.0;
              } else {
                _dragAccumulator = _dragStepThreshold;
              }
            } else if (_dragAccumulator <= -_dragStepThreshold) {
              if (currentIndex > 0) {
                _stepTriggeredDuringDrag = true;
                _stepCollapse();
                _dragAccumulator = 0.0;
              } else {
                _dragAccumulator = -_dragStepThreshold;
              }
            }
          },
          onVerticalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0.0;
            if (!_stepTriggeredDuringDrag) {
              if (velocity > 150 || _dragAccumulator >= 10.0) {
                _stepExpand();
              } else if (velocity < -150 || _dragAccumulator <= -10.0) {
                _stepCollapse();
              }
            }
            _resetDrag();
          },
          onVerticalDragCancel: _resetDrag,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 4.0, bottom: 9.0),
            alignment: Alignment.center,
            child: AnimatedContainer(
              key: const Key('calendar_expand_handle_bar'),
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              width: _isDragging ? 48 : 40,
              height: 4,
              decoration: BoxDecoration(
                color: handleColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
