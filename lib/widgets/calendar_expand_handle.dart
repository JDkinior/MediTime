import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/theme/app_theme.dart';

/// Barra indicadora táctil y visual colocada en la base del contenedor blanco
/// del calendario para mostrar y permitir expandir (semanal -> quincenal -> mensual)
/// o contraer (mensual -> quincenal -> semanal) de forma continua y suave
/// acompañando el recorrido físico del dedo en un solo arrastre.
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

  late CalendarFormat _dragStartFormat;
  late CalendarFormat _currentFormatDuringDrag;
  double _totalDragY = 0.0;
  double _visualOffset = 0.0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _currentFormatDuringDrag = widget.calendarFormat;
    _dragStartFormat = widget.calendarFormat;
  }

  @override
  void didUpdateWidget(covariant CalendarExpandHandle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDragging) {
      _currentFormatDuringDrag = widget.calendarFormat;
      _dragStartFormat = widget.calendarFormat;
    }
  }

  /// Determina el formato objetivo paso a paso en base al desplazamiento total [dy]
  /// desde el inicio del arrastre y el formato actualmente alcanzado.
  /// Garantiza que nunca se salten formatos intermedios (progreso continuo adyacente).
  CalendarFormat _computeTargetFormat({
    required CalendarFormat startFormat,
    required CalendarFormat currentFormat,
    required double dy,
  }) {
    switch (startFormat) {
      case CalendarFormat.week:
        if (currentFormat == CalendarFormat.month) {
          if (dy < 56.0) return CalendarFormat.twoWeeks;
          return CalendarFormat.month;
        } else if (currentFormat == CalendarFormat.twoWeeks) {
          if (dy >= 72.0) return CalendarFormat.month;
          if (dy < 20.0) return CalendarFormat.week;
          return CalendarFormat.twoWeeks;
        } else {
          // currentFormat == CalendarFormat.week
          if (dy >= 36.0) return CalendarFormat.twoWeeks;
          return CalendarFormat.week;
        }

      case CalendarFormat.twoWeeks:
        if (currentFormat == CalendarFormat.month) {
          if (dy < 20.0) return CalendarFormat.twoWeeks;
          return CalendarFormat.month;
        } else if (currentFormat == CalendarFormat.week) {
          if (dy > -20.0) return CalendarFormat.twoWeeks;
          return CalendarFormat.week;
        } else {
          // currentFormat == CalendarFormat.twoWeeks
          if (dy >= 36.0) return CalendarFormat.month;
          if (dy <= -36.0) return CalendarFormat.week;
          return CalendarFormat.twoWeeks;
        }

      case CalendarFormat.month:
        if (currentFormat == CalendarFormat.week) {
          if (dy > -56.0) return CalendarFormat.twoWeeks;
          return CalendarFormat.week;
        } else if (currentFormat == CalendarFormat.twoWeeks) {
          if (dy <= -72.0) return CalendarFormat.week;
          if (dy > -20.0) return CalendarFormat.month;
          return CalendarFormat.twoWeeks;
        } else {
          // currentFormat == CalendarFormat.month
          if (dy <= -36.0) return CalendarFormat.twoWeeks;
          return CalendarFormat.month;
        }
    }
  }

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
        _totalDragY = 0.0;
        _visualOffset = 0.0;
        _dragStartFormat = widget.calendarFormat;
        _currentFormatDuringDrag = widget.calendarFormat;
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
              _totalDragY = 0.0;
              _visualOffset = 0.0;
              _dragStartFormat = widget.calendarFormat;
              _currentFormatDuringDrag = widget.calendarFormat;
            });
          },
          onVerticalDragStart: (_) {
            setState(() {
              _isDragging = true;
            });
          },
          onVerticalDragUpdate: (details) {
            _totalDragY += details.delta.dy;
            _visualOffset = (_totalDragY * 0.2).clamp(-8.0, 8.0);

            // Resuelve transiciones secuenciales hacia el formato objetivo según dy
            while (true) {
              final nextFormat = _computeTargetFormat(
                startFormat: _dragStartFormat,
                currentFormat: _currentFormatDuringDrag,
                dy: _totalDragY,
              );
              if (nextFormat == _currentFormatDuringDrag) break;
              _currentFormatDuringDrag = nextFormat;
              widget.onFormatChanged(nextFormat);
            }

            if (mounted) {
              setState(() {});
            }
          },
          onVerticalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0.0;
            // Si el arrastre no cambió de formato por distancia, pero hubo un flick veloz
            if (_currentFormatDuringDrag == _dragStartFormat) {
              if (velocity > 150 || _totalDragY >= 20.0) {
                _stepExpand();
              } else if (velocity < -150 || _totalDragY <= -20.0) {
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
            child: Transform.translate(
              offset: Offset(0, _visualOffset),
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
      ),
    );
  }
}
