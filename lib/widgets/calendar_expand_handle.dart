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
            _visualOffset = (_totalDragY * 0.35).clamp(-24.0, 24.0);

            // Gestionar niveles intermedios de forma gradual:
            // Nivel 1: Semana | Nivel 2: Quincenal | Nivel 3: Transición gradual | Nivel 4: Mes
            if (_dragStartFormat == CalendarFormat.week) {
              if (_currentFormatDuringDrag == CalendarFormat.week && _totalDragY >= 36.0) {
                // Baja el primer nivel a quincenal (nivel 2)
                _currentFormatDuringDrag = CalendarFormat.twoWeeks;
                widget.onFormatChanged(CalendarFormat.twoWeeks);
              }
              if (_currentFormatDuringDrag == CalendarFormat.twoWeeks && _totalDragY >= 80.0) {
                // Al continuar hasta el 4to nivel durante el arrastre, alcanza mes
                _currentFormatDuringDrag = CalendarFormat.month;
                widget.onFormatChanged(CalendarFormat.month);
              } else if (_currentFormatDuringDrag == CalendarFormat.month && _totalDragY < 68.0) {
                // Al regresar hacia arriba
                _currentFormatDuringDrag = CalendarFormat.twoWeeks;
                widget.onFormatChanged(CalendarFormat.twoWeeks);
              } else if (_currentFormatDuringDrag == CalendarFormat.twoWeeks && _totalDragY < 18.0) {
                _currentFormatDuringDrag = CalendarFormat.week;
                widget.onFormatChanged(CalendarFormat.week);
              }
            } else if (_dragStartFormat == CalendarFormat.month) {
              if (_currentFormatDuringDrag == CalendarFormat.month && _totalDragY <= -45.0) {
                // Sube hacia quincenal (nivel 2) tras recorrer el 3er nivel
                _currentFormatDuringDrag = CalendarFormat.twoWeeks;
                widget.onFormatChanged(CalendarFormat.twoWeeks);
              }
              if (_currentFormatDuringDrag == CalendarFormat.twoWeeks && _totalDragY <= -75.0) {
                // Sube hasta nivel 1 semanal
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

            if (mounted) {
              setState(() {});
            }
          },
          onVerticalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0.0;

            if (_dragStartFormat == CalendarFormat.week) {
              // Si se soltó en el 3er nivel (o 4to) o hubo flick rápido hacia abajo:
              // termina de adaptarse al 4to nivel (mes completo)
              if (_totalDragY >= 65.0) {
                if (_currentFormatDuringDrag != CalendarFormat.month) {
                  _currentFormatDuringDrag = CalendarFormat.month;
                  widget.onFormatChanged(CalendarFormat.month);
                }
              } else if (_totalDragY >= 25.0 || velocity > 150.0) {
                // Se soltó en nivel quincenal o flick rápido
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
              // Al contraer: si se empujó hacia arriba hasta el 1er nivel semanal
              if (_totalDragY <= -65.0) {
                if (_currentFormatDuringDrag != CalendarFormat.week) {
                  _currentFormatDuringDrag = CalendarFormat.week;
                  widget.onFormatChanged(CalendarFormat.week);
                }
              } else if (_totalDragY <= -25.0 || velocity < -150.0) {
                // Se soltó en nivel quincenal o flick rápido hacia arriba
                if (_currentFormatDuringDrag != CalendarFormat.twoWeeks) {
                  _currentFormatDuringDrag = CalendarFormat.twoWeeks;
                  widget.onFormatChanged(CalendarFormat.twoWeeks);
                }
              } else {
                // Se soltó cerca de mes: se adapta de nuevo a mensual
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

            _resetDrag();
          },
          onVerticalDragCancel: _resetDrag,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: 4.0 + (_visualOffset > 0 ? _visualOffset * 0.3 : 0.0),
              bottom: 9.0 + (_visualOffset < 0 ? -_visualOffset * 0.3 : 0.0),
            ),
            alignment: Alignment.center,
            child: Transform.translate(
              offset: Offset(0, _visualOffset * 0.7),
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
