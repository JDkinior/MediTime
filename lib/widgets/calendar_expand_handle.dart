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
  final bool? isDragging;
  final VoidCallback? onDragStart;
  final ValueChanged<double>? onDragUpdate;
  final ValueChanged<double>? onDragEnd;
  final VoidCallback? onDragCancel;
  final VoidCallback? onTap;

  const CalendarExpandHandle({
    super.key,
    required this.calendarFormat,
    required this.onFormatChanged,
    this.isDragging,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
    this.onDragCancel,
    this.onTap,
  });

  @override
  State<CalendarExpandHandle> createState() => _CalendarExpandHandleState();
}

class _CalendarExpandHandleState extends State<CalendarExpandHandle> {
  late CalendarFormat _dragStartFormat;
  late CalendarFormat _currentFormatDuringDrag;
  double _totalDragY = 0.0;
  bool _isDragging = false;

  bool get _isActiveDragging => widget.isDragging ?? _isDragging;

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

  void _resetDrag() {
    if (mounted) {
      setState(() {
        _isDragging = false;
        _totalDragY = 0.0;
        _dragStartFormat = widget.calendarFormat;
        _currentFormatDuringDrag = widget.calendarFormat;
      });
    }
  }

  void _handleFallbackDragUpdate() {
    if (_dragStartFormat == CalendarFormat.week) {
      if (_currentFormatDuringDrag == CalendarFormat.week && _totalDragY >= 36.0) {
        _currentFormatDuringDrag = CalendarFormat.twoWeeks;
        widget.onFormatChanged(CalendarFormat.twoWeeks);
      }
      if (_currentFormatDuringDrag == CalendarFormat.twoWeeks && _totalDragY >= 80.0) {
        _currentFormatDuringDrag = CalendarFormat.month;
        widget.onFormatChanged(CalendarFormat.month);
      } else if (_currentFormatDuringDrag == CalendarFormat.month && _totalDragY < 68.0) {
        _currentFormatDuringDrag = CalendarFormat.twoWeeks;
        widget.onFormatChanged(CalendarFormat.twoWeeks);
      } else if (_currentFormatDuringDrag == CalendarFormat.twoWeeks && _totalDragY < 18.0) {
        _currentFormatDuringDrag = CalendarFormat.week;
        widget.onFormatChanged(CalendarFormat.week);
      }
    } else if (_dragStartFormat == CalendarFormat.month) {
      if (_currentFormatDuringDrag == CalendarFormat.month && _totalDragY <= -45.0) {
        _currentFormatDuringDrag = CalendarFormat.twoWeeks;
        widget.onFormatChanged(CalendarFormat.twoWeeks);
      }
      if (_currentFormatDuringDrag == CalendarFormat.twoWeeks && _totalDragY <= -75.0) {
        _currentFormatDuringDrag = CalendarFormat.week;
        widget.onFormatChanged(CalendarFormat.week);
      } else if (_currentFormatDuringDrag == CalendarFormat.week && _totalDragY > -60.0) {
        _currentFormatDuringDrag = CalendarFormat.twoWeeks;
        widget.onFormatChanged(CalendarFormat.twoWeeks);
      } else if (_currentFormatDuringDrag == CalendarFormat.twoWeeks && _totalDragY > -25.0) {
        _currentFormatDuringDrag = CalendarFormat.month;
        widget.onFormatChanged(CalendarFormat.month);
      }
    } else if (_dragStartFormat == CalendarFormat.twoWeeks) {
      if (_currentFormatDuringDrag == CalendarFormat.twoWeeks && _totalDragY >= 50.0) {
        _currentFormatDuringDrag = CalendarFormat.month;
        widget.onFormatChanged(CalendarFormat.month);
      } else if (_currentFormatDuringDrag == CalendarFormat.twoWeeks && _totalDragY <= -36.0) {
        _currentFormatDuringDrag = CalendarFormat.week;
        widget.onFormatChanged(CalendarFormat.week);
      } else if (_currentFormatDuringDrag == CalendarFormat.month && _totalDragY < 35.0) {
        _currentFormatDuringDrag = CalendarFormat.twoWeeks;
        widget.onFormatChanged(CalendarFormat.twoWeeks);
      } else if (_currentFormatDuringDrag == CalendarFormat.week && _totalDragY > -18.0) {
        _currentFormatDuringDrag = CalendarFormat.twoWeeks;
        widget.onFormatChanged(CalendarFormat.twoWeeks);
      }
    }
  }

  void _handleFallbackDragEnd(double velocity) {
    if (_dragStartFormat == CalendarFormat.week) {
      if (_totalDragY >= 65.0) {
        if (_currentFormatDuringDrag != CalendarFormat.month) {
          _currentFormatDuringDrag = CalendarFormat.month;
          widget.onFormatChanged(CalendarFormat.month);
        }
      } else if (_totalDragY >= 25.0 || velocity > 150.0) {
        if (_currentFormatDuringDrag != CalendarFormat.twoWeeks) {
          _currentFormatDuringDrag = CalendarFormat.twoWeeks;
          widget.onFormatChanged(CalendarFormat.twoWeeks);
        }
      } else {
        if (_currentFormatDuringDrag != CalendarFormat.week) {
          _currentFormatDuringDrag = CalendarFormat.week;
          widget.onFormatChanged(CalendarFormat.week);
        }
      }
    } else if (_dragStartFormat == CalendarFormat.month) {
      if (_totalDragY <= -65.0) {
        if (_currentFormatDuringDrag != CalendarFormat.week) {
          _currentFormatDuringDrag = CalendarFormat.week;
          widget.onFormatChanged(CalendarFormat.week);
        }
      } else if (_totalDragY <= -25.0 || velocity < -150.0) {
        if (_currentFormatDuringDrag != CalendarFormat.twoWeeks) {
          _currentFormatDuringDrag = CalendarFormat.twoWeeks;
          widget.onFormatChanged(CalendarFormat.twoWeeks);
        }
      } else {
        if (_currentFormatDuringDrag != CalendarFormat.month) {
          _currentFormatDuringDrag = CalendarFormat.month;
          widget.onFormatChanged(CalendarFormat.month);
        }
      }
    } else if (_dragStartFormat == CalendarFormat.twoWeeks) {
      if (_totalDragY >= 40.0 || velocity > 150.0) {
        if (_currentFormatDuringDrag != CalendarFormat.month) {
          _currentFormatDuringDrag = CalendarFormat.month;
          widget.onFormatChanged(CalendarFormat.month);
        }
      } else if (_totalDragY <= -25.0 || velocity < -150.0) {
        if (_currentFormatDuringDrag != CalendarFormat.week) {
          _currentFormatDuringDrag = CalendarFormat.week;
          widget.onFormatChanged(CalendarFormat.week);
        }
      } else {
        if (_currentFormatDuringDrag != CalendarFormat.twoWeeks) {
          _currentFormatDuringDrag = CalendarFormat.twoWeeks;
          widget.onFormatChanged(CalendarFormat.twoWeeks);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark || AppTheme.currentIsDark;
    final preferenceNotifier = Provider.of<PreferenceNotifier?>(context);
    final isHighContrast = preferenceNotifier?.highContrast ?? false;
    final isDraggingNow = _isActiveDragging;

    final Color handleColor;
    if (isHighContrast) {
      handleColor = isDark ? const Color(0xFFB0B0B0) : const Color(0xFF666666);
    } else {
      handleColor = isDark
          ? (isDraggingNow ? const Color(0xFF727885) : const Color(0xFF555A64))
          : (isDraggingNow ? const Color(0xFF9CA3AF) : const Color(0xFFD1D5DB));
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
            if (widget.onTap != null) {
              widget.onTap!();
            } else {
              if (widget.calendarFormat == CalendarFormat.month) {
                widget.onFormatChanged(CalendarFormat.week);
              } else {
                widget.onFormatChanged(CalendarFormat.month);
              }
            }
          },
          onVerticalDragDown: (_) {
            setState(() {
              _isDragging = true;
              _totalDragY = 0.0;
                    _dragStartFormat = widget.calendarFormat;
              _currentFormatDuringDrag = widget.calendarFormat;
            });
          },
          onVerticalDragStart: (_) {
            setState(() {
              _isDragging = true;
            });
            widget.onDragStart?.call();
          },
          onVerticalDragUpdate: (details) {
            _totalDragY += details.delta.dy;
            if (widget.onDragUpdate != null) {
              widget.onDragUpdate!(_totalDragY);
            } else {
              _handleFallbackDragUpdate();
            }
            if (mounted) {
              setState(() {});
            }
          },
          onVerticalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0.0;
            if (widget.onDragEnd != null) {
              widget.onDragEnd!(velocity);
            } else {
              _handleFallbackDragEnd(velocity);
            }
            _resetDrag();
          },
          onVerticalDragCancel: () {
            widget.onDragCancel?.call();
            _resetDrag();
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.only(
              top: 4.0,
              bottom: 9.0,
            ),
            alignment: Alignment.center,
            child: AnimatedContainer(
              key: const Key('calendar_expand_handle_bar'),
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              width: isDraggingNow ? 48 : 40,
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
