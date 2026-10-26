import 'dart:ui';
// lib/widgets/reports/streak_celebration_sheet.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:flutter/services.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:meditime/theme/app_theme.dart';

/// Hoja modal estilo Duolingo para celebrar y visualizar la racha activa de tomas médicas.
class StreakCelebrationSheet extends StatefulWidget {
  final int racha;
  final List<Tratamiento> tratamientos;

  const StreakCelebrationSheet({
    super.key,
    required this.racha,
    required this.tratamientos,
  });

  static Future<void> show(
    BuildContext context, {
    required int racha,
    required List<Tratamiento> tratamientos,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (ctx) => StreakCelebrationSheet(
        racha: racha,
        tratamientos: tratamientos,
      ),
    );
  }

  @override
  State<StreakCelebrationSheet> createState() => _StreakCelebrationSheetState();
}

class _StreakCelebrationSheetState extends State<StreakCelebrationSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    // Entrada suave desde 0.90 con curva spring/easeOutCubic (Emil Kowalski craft)
    _scaleAnimation = Tween<double>(begin: 0.90, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutBack,
      ),
    );



    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  /// Calcula el estado de cada día de la semana actual (Lunes a Domingo)
  List<_DayStreakInfo> _calculateWeekDays() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));

    // Mapear dosis de los tratamientos por fecha (YYYY-MM-DD)
    final Map<String, List<DoseStatus>> dayStatuses = {};
    for (var t in widget.tratamientos) {
      t.doseStatus.forEach((key, status) {
        final parsed = DateTime.tryParse(key);
        if (parsed != null) {
          final dateStr =
              "${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}";
          dayStatuses.putIfAbsent(dateStr, () => []).add(status);
        }
      });
    }

    final List<_DayStreakInfo> weekDays = [];
    final dayLetters = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

    for (int i = 0; i < 7; i++) {
      final dayDate = monday.add(Duration(days: i));
      final dateStr =
          "${dayDate.year}-${dayDate.month.toString().padLeft(2, '0')}-${dayDate.day.toString().padLeft(2, '0')}";
      final isFuture = dayDate.isAfter(today);
      final isToday = dayDate.year == today.year &&
          dayDate.month == today.month &&
          dayDate.day == today.day;

      final statuses = dayStatuses[dateStr];
      bool isCompleted = false;
      bool hasPending = false;

      if (statuses != null && statuses.isNotEmpty) {
        if (statuses.every((s) => s == DoseStatus.tomada)) {
          isCompleted = true;
        } else if (statuses.any((s) => s == DoseStatus.omitida)) {
          isCompleted = false;
        } else {
          hasPending = true;
        }
      } else if (!isFuture && !isToday && widget.racha > 0) {
        // Si cae dentro de la racha activa acumulada
        final diffFromToday = today.difference(dayDate).inDays;
        if (diffFromToday < widget.racha) {
          isCompleted = true;
        }
      }

      weekDays.add(_DayStreakInfo(
        letter: dayLetters[i],
        dayNumber: dayDate.day,
        isCompleted: isCompleted,
        isToday: isToday,
        isFuture: isFuture,
        hasPending: hasPending,
      ));
    }

    return weekDays;
  }

  int _calculateNextMilestone(int racha) {
    if (racha < 7) return 7;
    if (racha < 14) return 14;
    if (racha < 30) return 30;
    return ((racha ~/ 30) + 1) * 30;
  }

  String _getMilestoneName(int milestone) {
    switch (milestone) {
      case 7:
        return "Semana Impecable";
      case 14:
        return "Hábito de Hierro";
      case 30:
        return "Mes Perfecto";
      default:
        return "Maestría Clínica";
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    PreferenceNotifier? pref;
    try {
      pref = context.watch<PreferenceNotifier>();
    } catch (_) {}
    final isModern = pref?.interfaceStyle == 'modern' || pref == null;
    final highContrast = pref?.highContrast ?? false;
    final useGlass = isModern && !highContrast;
    final racha = widget.racha;
    final weekDays = _calculateWeekDays();
    final nextMilestone = _calculateNextMilestone(racha);
    final daysRemaining = (nextMilestone - racha).clamp(0, nextMilestone);
    final milestoneProgress = (racha / nextMilestone).clamp(0.0, 1.0);

    const fireOrange = Color(0xFFFF6B00);
    const fireAmber = Color(0xFFFFB703);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: useGlass
            ? ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0)
            : ImageFilter.blur(sigmaX: 0.0, sigmaY: 0.0),
        child: Container(
          decoration: BoxDecoration(
            color: useGlass
                ? (isDark
                    ? Theme.of(context).cardColor.withValues(alpha: 0.78)
                    : Colors.white.withValues(alpha: 0.85))
                : Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(
              color: (useGlass
                  ? (isDark ? Colors.white : Colors.black).withValues(alpha: isDark ? 0.12 : 0.08)
                  : ((pref?.showCardBorder ?? false) || highContrast ? AppTheme.borderColor : Colors.transparent)),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
                blurRadius: 30,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(
            top: 12,
            left: 20,
            right: 20,
            bottom: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
          const SizedBox(height: 16),

          // Header con botón de cerrar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: fireOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: fireOrange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt_rounded, size: 14, color: fireOrange),
                    const SizedBox(width: 4),
                    Text(
                      racha > 0 ? "RACHA ACTIVA" : "SIN RACHA",
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: fireOrange,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded, size: 22),
                color: AppTheme.secondaryTextColor,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Hero Flame Emblem estilo Duolingo
          ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFF9E00),
                    Color(0xFFFF3D00),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF5722).withValues(alpha: 0.45),
                    blurRadius: 26,
                    spreadRadius: 4,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: 14,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.local_fire_department_rounded,
                    size: 58,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Headline Counter
          Text(
            racha > 0 ? "$racha ${racha == 1 ? 'DÍA' : 'DÍAS'}" : "0 DÍAS",
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: AppTheme.primaryTextColor,
              letterSpacing: -1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            racha >= 7
                ? "¡Tu racha está que arde!"
                : (racha > 0
                    ? "¡Constancia encendida!"
                    : "¡Hoy es el día ideal para iniciar tu racha!"),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: fireOrange,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              "Tomar cada medicamento a tiempo fortalece tu salud y crea una disciplina de bienestar duradera.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: AppTheme.secondaryTextColor,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 22),

          // Duolingo-style 7-Day Trail (Semana actual)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.borderColor.withValues(alpha: 0.6),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.calendar_today_rounded, size: 14, color: fireOrange),
                        SizedBox(width: 6),
                        Text(
                          "Cadena de esta semana",
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      "${weekDays.where((d) => d.isCompleted).length}/7 completados",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.secondaryTextColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: weekDays.map((day) => _buildDayNode(day, isDark)).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Próximo Hito / Milestone Progress Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [
                        fireOrange.withValues(alpha: 0.08),
                        fireAmber.withValues(alpha: 0.14),
                      ]
                    : [
                        fireOrange.withValues(alpha: 0.04),
                        fireAmber.withValues(alpha: 0.10),
                      ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: fireOrange.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: fireOrange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.emoji_events_rounded,
                        size: 18,
                        color: fireOrange,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Próxima meta: ${_getMilestoneName(nextMilestone)} ($nextMilestone días)",
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            daysRemaining > 0
                                ? "Faltan $daysRemaining ${daysRemaining == 1 ? 'día' : 'días'} consecutivos para desbloquearlo"
                                : "¡Meta superada con honores!",
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: milestoneProgress,
                    minHeight: 7,
                    backgroundColor: fireOrange.withValues(alpha: 0.15),
                    valueColor: const AlwaysStoppedAnimation<Color>(fireOrange),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Duolingo-style Big Punchy CTA Button
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              Navigator.pop(context);
            },
            child: Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFF7A00),
                    Color(0xFFFF4500),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF4500).withValues(alpha: 0.40),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  "¡CONTINUAR!",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  ),
),
      ),
    );
  }

  Widget _buildDayNode(_DayStreakInfo day, bool isDark) {
    const fireOrange = Color(0xFFFF6B00);

    Widget circleContent;
    BoxDecoration circleDecoration;

    if (day.isCompleted) {
      circleDecoration = BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFF9E00),
            Color(0xFFFF5722),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: fireOrange.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      );
      circleContent = const Icon(
        Icons.local_fire_department_rounded,
        size: 17,
        color: Colors.white,
      );
    } else if (day.isToday) {
      circleDecoration = BoxDecoration(
        shape: BoxShape.circle,
        color: fireOrange.withValues(alpha: 0.12),
        border: Border.all(color: fireOrange, width: 2),
      );
      circleContent = const Icon(
        Icons.whatshot_outlined,
        size: 16,
        color: fireOrange,
      );
    } else if (day.isFuture) {
      circleDecoration = BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200,
      );
      circleContent = Text(
        "${day.dayNumber}",
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppTheme.secondaryTextColor.withValues(alpha: 0.6),
        ),
      );
    } else {
      // Pasado sin completar
      circleDecoration = BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade200,
        border: Border.all(
          color: AppTheme.borderColor.withValues(alpha: 0.5),
        ),
      );
      circleContent = Icon(
        Icons.circle,
        size: 6,
        color: AppTheme.secondaryTextColor.withValues(alpha: 0.4),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          day.letter,
          style: TextStyle(
            fontSize: 11,
            fontWeight: day.isToday ? FontWeight.w800 : FontWeight.w600,
            color: day.isToday ? fireOrange : AppTheme.secondaryTextColor,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 34,
          height: 34,
          decoration: circleDecoration,
          child: Center(child: circleContent),
        ),
        const SizedBox(height: 4),
        Text(
          day.isToday ? "Hoy" : "${day.dayNumber}",
          style: TextStyle(
            fontSize: 10,
            fontWeight: day.isToday ? FontWeight.w800 : FontWeight.normal,
            color: day.isToday ? fireOrange : AppTheme.secondaryTextColor,
          ),
        ),
      ],
    );
  }
}

class _DayStreakInfo {
  final String letter;
  final int dayNumber;
  final bool isCompleted;
  final bool isToday;
  final bool isFuture;
  final bool hasPending;

  _DayStreakInfo({
    required this.letter,
    required this.dayNumber,
    required this.isCompleted,
    required this.isToday,
    required this.isFuture,
    required this.hasPending,
  });
}
