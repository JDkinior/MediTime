import 'package:meditime/widgets/frosted_glass_bottom_sheet.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:meditime/models/caregiver_profile.dart';
import 'package:provider/provider.dart';
import 'package:meditime/notifiers/caregiver_notifier.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/services/preference_service.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:meditime/services/auth_service.dart';
import 'package:meditime/services/firestore_service.dart';
import 'package:meditime/screens/shared/localizador_farmacias_page.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:meditime/widgets/estado_vista.dart';
import 'package:meditime/enums/view_state.dart';
import 'package:meditime/services/notification_service.dart';
import 'package:meditime/services/tratamiento_service.dart';
import 'package:meditime/widgets/tutorial_tooltip.dart';
import 'package:meditime/screens/medication/detalle_receta_page.dart';
import 'package:meditime/widgets/container_transform_card.dart';
import 'package:meditime/screens/medication/editar_tratamiento_page.dart';
import 'package:meditime/core/utils.dart';
import 'package:meditime/l10n/generated/app_localizations.dart';
import 'package:meditime/widgets/modern_content_fade.dart';
import 'package:meditime/widgets/calendar_expand_handle.dart';
import 'package:meditime/widgets/pill_icon.dart';

class CalendarioPage extends StatefulWidget {
  final GlobalKey? calendarKey;
  final GlobalKey? calendarViewKey;

  final bool isActive;

  const CalendarioPage({
    super.key,
    this.calendarKey,
    this.calendarViewKey,
    this.isActive = true,
  });

  @override
  State<CalendarioPage> createState() => _CalendarioPageState();
}

class _CalendarioPageState extends State<CalendarioPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  Stream<List<Map<String, dynamic>>>? _combinedStream;
  List<CaregiverProfile>? _lastProfiles;
  bool _lastIsGeneral = false;
  String? _lastActiveProfileId;
  String? _lastUserId;

  void _updateStreamIfNeeded(
    String userId,
    bool isGeneral,
    List<CaregiverProfile> profiles,
    CaregiverProfile? activeProfile,
    FirestoreService firestoreService,
  ) {
    final activeProfileId = activeProfile?.id;
    if (_combinedStream != null &&
        _lastUserId == userId &&
        _lastIsGeneral == isGeneral &&
        _lastActiveProfileId == activeProfileId &&
        _lastProfiles != null &&
        _lastProfiles!.length == profiles.length) {
      bool same = true;
      for (int i = 0; i < profiles.length; i++) {
        if (_lastProfiles![i].id != profiles[i].id) {
          same = false;
          break;
        }
      }
      if (same) return;
    }

    _lastUserId = userId;
    _lastIsGeneral = isGeneral;
    _lastActiveProfileId = activeProfileId;
    _lastProfiles = List.from(profiles);

    if (!isGeneral) {
      _combinedStream = firestoreService
          .getMedicamentosStream(userId, activeProfile)
          .map((tratamientos) {
            return tratamientos
                .map((t) => {'tratamiento': t, 'profile': activeProfile})
                .toList();
          });
      return;
    }

    if (profiles.isEmpty) {
      _combinedStream = Stream.value([]);
      return;
    }

    List<Stream<List<Map<String, dynamic>>>> streams =
        profiles.map((profile) {
          return firestoreService.getMedicamentosStream(userId, profile).map((
            tratamientos,
          ) {
            return tratamientos
                .map((t) => {'tratamiento': t, 'profile': profile})
                .toList();
          });
        }).toList();

    _combinedStream = _combineLatest(streams).map((listOfLists) {
      return listOfLists.expand((list) => list).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final authService = context.watch<AuthService>();
    final firestoreService = context.watch<FirestoreService>();
    final caregiverNotifier = context.watch<CaregiverNotifier>();
    final preferenceNotifier = context.watch<PreferenceNotifier>();
    final user = authService.currentUser;
    final isAnimal = preferenceNotifier.isAnimalMode;
    final isManagedMode = caregiverNotifier.isCaregiverModeActive || isAnimal;
    final isGeneralMode = isManagedMode && caregiverNotifier.isGeneralMode;
    final activeProfile =
        isManagedMode
            ? caregiverNotifier.getEffectiveActiveProfile(
              isAnimalMode: isAnimal,
            )
            : null;
    final profiles =
        isAnimal
            ? caregiverNotifier.managedProfiles
                .where((p) => p.isAnimal)
                .toList()
            : caregiverNotifier.managedProfiles
                .where((p) => !p.isAnimal)
                .toList();

    if (user == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(child: Text('Inicia sesión para ver el calendario.')),
      );
    }

    _updateStreamIfNeeded(
      user.uid,
      isGeneralMode,
      profiles,
      activeProfile,
      firestoreService,
    );

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        key: ValueKey('${isGeneralMode}_${activeProfile?.id}_$isManagedMode'),
        initialData:
            !isGeneralMode
                ? firestoreService
                    .getCachedMedicamentos(user.uid, activeProfile)
                    ?.map((t) => {'tratamiento': t, 'profile': activeProfile})
                    .toList()
                : null,
        stream: _combinedStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const EstadoVista(
              state: ViewState.loading,
              child: SizedBox.shrink(),
            );
          }
          if (snapshot.hasError) {
            return const EstadoVista(
              state: ViewState.error,
              errorMessage: 'No se pudieron cargar los datos.',
              child: SizedBox.shrink(),
            );
          }

          final items = snapshot.data ?? [];
          return _CalendarioContenido(
            tratamientosItems: items,
            userId: user.uid,
            calendarKey: widget.calendarKey,
            calendarViewKey: widget.calendarViewKey,
            isActive: widget.isActive,
          );
        },
      ),
    );
  }
}

class _CalendarioContenido extends StatefulWidget {
  final List<Map<String, dynamic>> tratamientosItems;
  final String userId;
  final GlobalKey? calendarKey;
  final GlobalKey? calendarViewKey;
  final bool isActive;

  const _CalendarioContenido({
    required this.tratamientosItems,
    required this.userId,
    required this.isActive,
    this.calendarKey,
    this.calendarViewKey,
  });

  @override
  State<_CalendarioContenido> createState() => _CalendarioContenidoState();
}

class _CalendarioContenidoState extends State<_CalendarioContenido> with SingleTickerProviderStateMixin {
  static const double _dayShadowPadding = 8.0;
  static const double _calendarHeaderHeight = 80.0;
  static const double _calendarRowHeight = 52.0;
  static const _calendarStyle = CalendarStyle(
    outsideDaysVisible: false,
    tablePadding: EdgeInsets.only(bottom: _dayShadowPadding),
  );
  static const double _kHeightWeek = _calendarHeaderHeight + _calendarRowHeight + _dayShadowPadding;
  static const double _kHeightTwoWeeks = _calendarHeaderHeight + 2 * _calendarRowHeight + _dayShadowPadding;

  CalendarFormat _calendarFormat = CalendarFormat.week;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Animation<double>? _secondaryAnimation;

  late AnimationController _snapController;
  Animation<double>? _snapAnimation;
  double? _interactiveHeight;
  double _dragStartHeight = _kHeightWeek;
  double _calendarDragDy = 0;
  bool _isDraggingCalendar = false;
  CalendarFormat? _targetFormat;
  final _calendarPageStorage = PageStorageBucket();
  int _selectionRevision = 0;

  final Map<DateTime, Map<String, List<Map<String, dynamic>>>> _dayCache = {};
  final Set<DateTime> _populatedMonths = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _populateCacheForMonth(_focusedDay);
    _loadCalendarFormatSetting();

    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _snapController.addListener(() {
      setState(() {
        _interactiveHeight = _snapAnimation?.value;
      });
    });
    _snapController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isDraggingCalendar = false;
          _interactiveHeight = null;
          if (_targetFormat != null) {
            _calendarFormat = _targetFormat!;
            _targetFormat = null;
          }
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newAnim = ModalRoute.of(context)?.secondaryAnimation;
    if (newAnim != _secondaryAnimation) {
      _secondaryAnimation?.removeStatusListener(_onAnimationStatusChanged);
      _secondaryAnimation = newAnim;
      _secondaryAnimation?.addStatusListener(_onAnimationStatusChanged);
    }
  }

  void _onAnimationStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) {
      _loadCalendarFormatSetting();
    }
  }

  @override
  void dispose() {
    _snapController.dispose();
    _secondaryAnimation?.removeStatusListener(_onAnimationStatusChanged);
    super.dispose();
  }

  int _getMonthRowCount(DateTime focusedDay) {
    final first = DateTime(focusedDay.year, focusedDay.month, 1);
    final daysBefore = first.weekday % 7; // Sunday = 7 -> 0, Monday = 1 -> 1
    final firstToDisplay = first.subtract(Duration(days: daysBefore));

    final last = DateTime(focusedDay.year, focusedDay.month + 1, 0);
    final daysAfter = (7 - ((last.weekday % 7) + 1)) % 7;
    final lastToDisplay = last.add(Duration(days: daysAfter));

    return (lastToDisplay.difference(firstToDisplay).inDays + 1) ~/ 7;
  }

  double _getMonthHeight(DateTime focusedDay) {
    final rowCount = _getMonthRowCount(focusedDay);
    return _calendarHeaderHeight + rowCount * _calendarRowHeight + _dayShadowPadding;
  }

  double _getHeightForFormat(CalendarFormat format) {
    switch (format) {
      case CalendarFormat.week:
        return _kHeightWeek;
      case CalendarFormat.twoWeeks:
        return _kHeightTwoWeeks;
      case CalendarFormat.month:
        return _getMonthHeight(_focusedDay);
    }
  }

  void _syncFocusedDayForFormat(CalendarFormat target) {
    if (target != CalendarFormat.month && _selectedDay != null) {
      if (_selectedDay!.year == _focusedDay.year && _selectedDay!.month == _focusedDay.month) {
        _focusedDay = _selectedDay!;
      }
    }
  }

  DateTime _firstDayOfWeek(DateTime day) {
    final daysBefore = day.weekday % 7; // Sunday = 7 -> 0, Monday = 1 -> 1
    return DateTime.utc(day.year, day.month, day.day).subtract(Duration(days: daysBefore));
  }

  DateTime _firstDayOfTwoWeeks(DateTime day) {
    final weekStart = _firstDayOfWeek(day);
    final firstWeek = _firstDayOfWeek(DateTime.utc(2022, 1, 1));
    final weekIndex = weekStart.difference(firstWeek).inDays ~/ 7;
    return weekStart.subtract(Duration(days: (weekIndex % 2) * 7));
  }

  bool _isDayOnCurrentPage(DateTime day, CalendarFormat format) {
    return switch (format) {
      CalendarFormat.month =>
        day.year == _focusedDay.year && day.month == _focusedDay.month,
      CalendarFormat.twoWeeks =>
        _firstDayOfTwoWeeks(day) == _firstDayOfTwoWeeks(_focusedDay),
      CalendarFormat.week => _firstDayOfWeek(day) == _firstDayOfWeek(_focusedDay),
    };
  }

  void _anchorResizeToSelectedDay() {
    final selectedDay = _selectedDay;
    if (selectedDay != null && _isDayOnCurrentPage(selectedDay, _calendarFormat)) {
      _focusedDay = selectedDay;
    }
  }

  void _updateCalendarFormat(CalendarFormat format) {
    if (_calendarFormat != format) {
      _snapController.stop();
      final currentH = _interactiveHeight ?? _getHeightForFormat(_calendarFormat);
      final targetH = _getHeightForFormat(format);
      _animateToHeightAndFormat(currentH, targetH, format);
    }
  }

  void _handleDragStart() {
    _snapController.stop();
    _calendarDragDy = 0;
    setState(() {
      _anchorResizeToSelectedDay();
      _isDraggingCalendar = true;
      _dragStartHeight = _interactiveHeight ?? _getHeightForFormat(_calendarFormat);
      _interactiveHeight = _dragStartHeight;
    });
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    _calendarDragDy += details.delta.dy;
    final minH = _kHeightWeek;
    final maxH = _getMonthHeight(_focusedDay);
    setState(() {
      _interactiveHeight = (_dragStartHeight + _calendarDragDy).clamp(minH, maxH);
    });
  }

  void _handleDragEnd(double velocity) {
    final minH = _kHeightWeek;
    final midH = _kHeightTwoWeeks;
    final maxH = _getMonthHeight(_focusedDay);
    final currentH = _interactiveHeight ?? _getHeightForFormat(_calendarFormat);

    final threshold1 = (minH + midH) / 2; // 158.0
    final threshold2 = (midH + maxH) / 2; // e.g. 262.0

    CalendarFormat target;
    double targetH;

    if (velocity > 320.0) {
      if (currentH < midH) {
        target = CalendarFormat.twoWeeks;
        targetH = midH;
      } else {
        target = CalendarFormat.month;
        targetH = maxH;
      }
    } else if (velocity < -320.0) {
      if (currentH > midH) {
        target = CalendarFormat.twoWeeks;
        targetH = midH;
      } else {
        target = CalendarFormat.week;
        targetH = minH;
      }
    } else {
      if (currentH < threshold1) {
        target = CalendarFormat.week;
        targetH = minH;
      } else if (currentH < threshold2) {
        target = CalendarFormat.twoWeeks;
        targetH = midH;
      } else {
        target = CalendarFormat.month;
        targetH = maxH;
      }
    }

    _animateToHeightAndFormat(currentH, targetH, target);
  }

  void _handleDragCancel() {
    final currentH = _interactiveHeight ?? _getHeightForFormat(_calendarFormat);
    final targetH = _getHeightForFormat(_calendarFormat);
    _animateToHeightAndFormat(currentH, targetH, _calendarFormat);
  }

  void _handleTap() {
    _snapController.stop();
    final currentH = _interactiveHeight ?? _getHeightForFormat(_calendarFormat);
    final CalendarFormat target;
    final double targetH;

    if (_calendarFormat == CalendarFormat.month) {
      target = CalendarFormat.week;
      targetH = _kHeightWeek;
    } else {
      target = CalendarFormat.month;
      targetH = _getMonthHeight(_focusedDay);
    }

    _animateToHeightAndFormat(currentH, targetH, target);
  }

  void _animateToHeightAndFormat(double startH, double endH, CalendarFormat target) {
    _anchorResizeToSelectedDay();
    _targetFormat = target;
    _snapAnimation = Tween<double>(begin: startH, end: endH).animate(
      CurvedAnimation(parent: _snapController, curve: Curves.easeOutCubic),
    );
    _snapController.reset();
    _snapController.forward();

    final formatStr = target == CalendarFormat.week
        ? 'weekly'
        : (target == CalendarFormat.twoWeeks ? 'biweekly' : 'monthly');
    Provider.of<PreferenceNotifier?>(context, listen: false)?.setCalendarFormat(formatStr);
  }

  Future<void> _loadCalendarFormatSetting() async {
    final preferenceService = context.read<PreferenceService>();
    final formatStr = await preferenceService.getCalendarFormat();
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            if (formatStr == 'weekly') {
              _calendarFormat = CalendarFormat.week;
            } else if (formatStr == 'biweekly') {
              _calendarFormat = CalendarFormat.twoWeeks;
            } else if (formatStr == 'monthly') {
              _calendarFormat = CalendarFormat.month;
            }
            _syncFocusedDayForFormat(_calendarFormat);
          });
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant _CalendarioContenido oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      _snapController.stop();
      _calendarFormat = _targetFormat ?? _calendarFormat;
      _targetFormat = null;
      _interactiveHeight = null;
      _isDraggingCalendar = false;
      final selectedDay = _selectedDay ?? DateTime.now();
      _focusedDay = selectedDay;
      _selectedDay = selectedDay;
      _selectionRevision++;
      _populateCacheForMonth(selectedDay);
    }
    if (oldWidget.tratamientosItems != widget.tratamientosItems) {
      _dayCache.clear();
      _populatedMonths.clear();
      _populateCacheForMonth(_focusedDay);
    }
  }

  void _populateCacheForMonth(DateTime month) {
    final monthKey = DateTime(month.year, month.month, 1);
    if (_populatedMonths.contains(monthKey)) {
      return;
    }
    _populatedMonths.add(monthKey);

    final firstDayOfMonth = DateTime(month.year, month.month, 1, 0, 0, 0);
    final lastDayOfMonth = DateTime(
      month.year,
      month.month + 1,
      0,
      23,
      59,
      59,
      999,
    );

    for (var item in widget.tratamientosItems) {
      final Tratamiento tratamiento = item['tratamiento'];
      final CaregiverProfile? profile = item['profile'];
      final cacheKey = "${tratamiento.id}_${profile?.id ?? 'self'}";

      // 1. Recopilar todas las dosis explícitamente registradas en doseStatus para este mes
      final List<DateTime> recordedTimes = [];
      tratamiento.doseStatus.forEach((dateString, status) {
        final parsedTime = DateTime.tryParse(dateString);
        if (parsedTime != null &&
            !parsedTime.isBefore(firstDayOfMonth) &&
            !parsedTime.isAfter(lastDayOfMonth)) {
          recordedTimes.add(parsedTime);
          final dayKey = DateTime(
            parsedTime.year,
            parsedTime.month,
            parsedTime.day,
          );

          _dayCache.putIfAbsent(dayKey, () => {});
          final treatmentMap = _dayCache[dayKey]!;

          treatmentMap.putIfAbsent(cacheKey, () => []);
          treatmentMap[cacheKey]!.add({
            'tratamiento': tratamiento,
            'profile': profile,
            'doseTime': parsedTime,
            'status': status,
          });
        }
      });

      recordedTimes.sort();

      // 2. Generar dosis programadas del mes y agregar aquellas que no tienen registro asociado
      final dosisCalculadas = TratamientoService.generarDosisEnRango(
        tratamiento,
        firstDayOfMonth,
        lastDayOfMonth,
      );
      final intervaloMinutos =
          tratamiento.intervaloDosis.inMinutes > 0
              ? tratamiento.intervaloDosis.inMinutes
              : 240;
      final maxToleranceMinutes = (intervaloMinutos / 2).clamp(30.0, 180.0);

      int recIdx = 0;
      final int recLen = recordedTimes.length;

      for (var doseTime in dosisCalculadas) {
        while (recIdx < recLen &&
            doseTime.difference(recordedTimes[recIdx]).inMinutes >
                maxToleranceMinutes) {
          recIdx++;
        }

        bool isRecorded = false;
        int checkIdx = recIdx;
        while (checkIdx < recLen) {
          final diffMinutes =
              recordedTimes[checkIdx].difference(doseTime).inMinutes;
          if (diffMinutes.abs() <= maxToleranceMinutes) {
            isRecorded = true;
            break;
          }
          if (diffMinutes > maxToleranceMinutes) {
            break;
          }
          checkIdx++;
        }

        if (!isRecorded) {
          final key = doseTime.toIso8601String();
          final status = tratamiento.doseStatus[key] ?? DoseStatus.pendiente;
          final dayKey = DateTime(doseTime.year, doseTime.month, doseTime.day);

          _dayCache.putIfAbsent(dayKey, () => {});
          final treatmentMap = _dayCache[dayKey]!;

          treatmentMap.putIfAbsent(cacheKey, () => []);
          treatmentMap[cacheKey]!.add({
            'tratamiento': tratamiento,
            'profile': profile,
            'doseTime': doseTime,
            'status': status,
          });
        }
      }
    }

    _dayCache.forEach((day, treatmentMap) {
      if (day.year == month.year && day.month == month.month) {
        for (var doseList in treatmentMap.values) {
          doseList.sort(
            (a, b) => (a['doseTime'] as DateTime).compareTo(
              b['doseTime'] as DateTime,
            ),
          );
        }
      }
    });
  }

  Map<String, List<Map<String, dynamic>>> _getGroupedDosesForDay(DateTime day) {
    final monthKey = DateTime(day.year, day.month, 1);
    if (!_populatedMonths.contains(monthKey)) {
      _populateCacheForMonth(day);
    }
    final dayKey = DateTime(day.year, day.month, day.day);
    return _dayCache[dayKey] ?? {};
  }

  List<Map<String, dynamic>> _obtenerDosisDelDia(DateTime day) {
    final groupedDoses = _getGroupedDosesForDay(day);
    final List<Map<String, dynamic>> flatDoses = [];

    groupedDoses.forEach((key, list) {
      for (var dose in list) {
        flatDoses.add(dose);
      }
    });

    flatDoses.sort(
      (a, b) =>
          (a['doseTime'] as DateTime).compareTo(b['doseTime'] as DateTime),
    );
    return flatDoses;
  }

  Color _determineDayColor(
    Map<String, List<Map<String, dynamic>>> dosesForDay,
  ) {
    if (dosesForDay.isEmpty) return Colors.transparent;

    final now = DateTime.now();
    final allDoses = dosesForDay.values.expand((d) => d).toList();

    bool hasNotificada = allDoses.any((d) {
      final DoseStatus s = d['status'];
      final DateTime dt = d['doseTime'];
      return s == DoseStatus.notificada ||
          (s == DoseStatus.pendiente && dt.isBefore(now));
    });

    if (hasNotificada) {
      return Colors.amber.shade600;
    } else if (allDoses.any((d) => d['status'] == DoseStatus.omitida)) {
      return AppTheme.errorColor;
    } else if (allDoses.every((d) => d['status'] == DoseStatus.tomada)) {
      return AppTheme.successColor;
    } else {
      return AppTheme.primaryColor;
    }
  }

  void _showDoseOptionsDialog(
    BuildContext context,
    Tratamiento tratamiento,
    CaregiverProfile? profile,
    DateTime doseTime,
    DoseStatus status,
  ) {
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    Widget buildDeferOption(BuildContext ctx, int minutes, String label) {
      return InkWell(
        onTap: () => Navigator.pop(ctx, minutes),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.05),
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.15),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (BuildContext sheetCtx) {
        final isDark = Theme.of(sheetCtx).brightness == Brightness.dark;
        return FrostedGlassBottomSheet(
          padding: EdgeInsets.only(
            top: 8,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(sheetCtx).padding.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                  margin: const EdgeInsets.only(bottom: 20),
                ),
              ),
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.medical_services_outlined,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Opciones de la Dosis',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${tratamiento.nombreMedicamento} • ${AppUtils.formatDoseTime(doseTime)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.secondaryTextColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Section 1: Main Completion Action
              if (status != DoseStatus.tomada) ...[
                InkWell(
                  onTap: () async {
                    Navigator.of(sheetCtx).pop();
                    await NotificationService.cancelSnoozeForTreatment(
                      docId: tratamiento.id,
                      doseTime: doseTime,
                    );
                    final inventoryResult = await firestoreService
                        .updateDoseStatus(
                          widget.userId,
                          tratamiento.id,
                          doseTime,
                          DoseStatus.tomada,
                          profile,
                        );
                    await NotificationService.rescheduleNextPendingDose(
                      tratamiento,
                      widget.userId,
                      profile,
                    );
                    if (inventoryResult?.stockBajo == true) {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            'Stock bajo: te quedan ${inventoryResult!.dosisRestantes} dosis',
                          ),
                        ),
                      );
                    } else {
                      scaffoldMessenger.showSnackBar(
                        const SnackBar(
                          content: Text('Dosis marcada como tomada.'),
                        ),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.successColor.withValues(alpha: 0.2),
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.successColor.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: AppTheme.successColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Marcar como tomada',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.successColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Descuenta del inventario automáticamente',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.secondaryTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Section 2: Quick Adjustments Group
              Material(
                color: isDark ? AppTheme.surfaceColor : const Color(0xFFF4F6F9),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? AppTheme.borderColor : const Color(0xFFE5E9F0),
                    ),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: isDark
                              ? AppTheme.errorColor.withValues(alpha: 0.1)
                              : const Color(0xFFE8ECF2),
                          child: const Icon(
                            Icons.close,
                            color: AppTheme.errorColor,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          'Marcar como omitida',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryTextColor,
                          ),
                        ),
                        subtitle: Text(
                          'No descontará inventario pero registrará la omisión',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.secondaryTextColor,
                          ),
                        ),
                        onTap: () async {
                          Navigator.of(sheetCtx).pop();
                          await NotificationService.cancelSnoozeForTreatment(
                            docId: tratamiento.id,
                            doseTime: doseTime,
                          );
                          await firestoreService.updateDoseStatus(
                            widget.userId,
                            tratamiento.id,
                            doseTime,
                            DoseStatus.omitida,
                            profile,
                          );
                          await NotificationService.rescheduleNextPendingDose(
                            tratamiento,
                            widget.userId,
                            profile,
                          );
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              content: Text('Dosis marcada como omitida.'),
                            ),
                          );
                        },
                      ),
                      Divider(
                        height: 1,
                        color: isDark ? AppTheme.borderColor : const Color(0xFFEAECEF),
                      ),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: isDark
                              ? Colors.orange.withValues(alpha: 0.1)
                              : const Color(0xFFE8ECF2),
                          child: const Icon(
                            Icons.snooze,
                            color: Colors.orange,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          'Aplazar dosis',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryTextColor,
                          ),
                        ),
                        subtitle: Text(
                          'Pospone la toma 10, 15, 30 o 60 minutos',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.secondaryTextColor,
                          ),
                        ),
                        onTap: () async {
                          Navigator.of(sheetCtx).pop();
                          final minutes = await showModalBottomSheet<int>(
                            context: context,
                            backgroundColor: Colors.transparent,
                            barrierColor: Colors.black.withValues(alpha: 0.35),
                            builder:
                                (ctx) => FrostedGlassBottomSheet(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Center(
                                        child: Container(
                                          width: 40,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: Colors.grey[300],
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                          margin: const EdgeInsets.only(
                                            bottom: 20,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        'Aplazar dosis',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryTextColor,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Selecciona cuánto tiempo deseas posponer la toma:',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppTheme.secondaryTextColor,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 20),
                                      GridView.count(
                                        crossAxisCount: 2,
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        mainAxisSpacing: 12,
                                        crossAxisSpacing: 12,
                                        childAspectRatio: 2.2,
                                        children: [
                                          buildDeferOption(ctx, 10, '+10 min'),
                                          buildDeferOption(ctx, 15, '+15 min'),
                                          buildDeferOption(ctx, 30, '+30 min'),
                                          buildDeferOption(ctx, 60, '+1 hora'),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                    ],
                                  ),
                                ),
                          );

                          if (minutes != null) {
                            final newDoseTime = doseTime.add(
                              Duration(minutes: minutes),
                            );
                            await NotificationService.cancelSnoozeForTreatment(
                              docId: tratamiento.id,
                              doseTime: doseTime,
                            );
                            final updatedTratamiento = await firestoreService
                                .deferOrMoveSingleDose(
                                  userId: widget.userId,
                                  docId: tratamiento.id,
                                  oldDoseTime: doseTime,
                                  newDoseTime: newDoseTime,
                                  newStatus: DoseStatus.aplazada,
                                  profile: profile,
                                );
                            await NotificationService.rescheduleNextPendingDose(
                              updatedTratamiento ?? tratamiento,
                              widget.userId,
                              profile,
                            );
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Dosis aplazada por $minutes minutos.',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      Divider(
                        height: 1,
                        color: isDark ? AppTheme.borderColor : const Color(0xFFEAECEF),
                      ),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: isDark
                              ? AppTheme.primaryColor.withValues(alpha: 0.1)
                              : const Color(0xFFE8ECF2),
                          child: Icon(
                            Icons.edit_outlined,
                            color: AppTheme.primaryColor,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          'Editar tratamiento',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryTextColor,
                          ),
                        ),
                        subtitle: Text(
                          'Modificar solo esta dosis o el tratamiento completo',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.secondaryTextColor,
                          ),
                        ),
                        onTap: () {
                          Navigator.of(sheetCtx).pop();
                          _showEditOptionsDialog(
                            context: context,
                            tratamiento: tratamiento,
                            doseTime: doseTime,
                            profile: profile,
                            scaffoldMessenger: scaffoldMessenger,
                            firestoreService: firestoreService,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Section 3: Destructive Action
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                tileColor: AppTheme.errorColor.withValues(alpha: 0.08),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_forever,
                    color: AppTheme.errorColor,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Eliminar tratamiento',
                  style: TextStyle(
                    color: AppTheme.errorColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: const Text(
                  'Remueve este tratamiento y todas sus alarmas',
                  style: TextStyle(fontSize: 11, color: AppTheme.errorColor),
                ),
                onTap: () async {
                  Navigator.of(sheetCtx).pop();
                  showDialog(
                    context: context,
                    builder: (BuildContext dialogCtx) {
                      return AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: const Text(
                          'Confirmar eliminación',
                          style: TextStyle(
                            color: AppTheme.errorColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        content: const Text(
                          '¿Estás seguro de que deseas eliminar este tratamiento?',
                        ),
                        actions: <Widget>[
                          TextButton(
                            child: const Text('Cancelar'),
                            onPressed: () {
                              Navigator.of(dialogCtx).pop();
                            },
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.errorColor,
                            ),
                            child: const Text('Eliminar'),
                            onPressed: () async {
                              Navigator.of(dialogCtx).pop();
                              await NotificationService.revokeTreatmentLocally(
                                widget.userId,
                                tratamiento.id,
                              );
                              await NotificationService.cancelTreatmentAlarms(
                                tratamiento.prescriptionAlarmId,
                              );
                              await NotificationService.cancelAllActiveAndroidNotifications();
                              await NotificationService.cancelAllFlutterLocalNotifications();
                              await firestoreService.deleteTratamiento(
                                widget.userId,
                                tratamiento.id,
                                profile,
                              );
                              scaffoldMessenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Tratamiento eliminado.'),
                                ),
                              );
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditOptionsDialog({
    required BuildContext context,
    required Tratamiento tratamiento,
    required DateTime doseTime,
    CaregiverProfile? profile,
    required ScaffoldMessengerState scaffoldMessenger,
    required FirestoreService firestoreService,
  }) async {
    final option = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder:
          (BuildContext sheetCtx) => FrostedGlassBottomSheet(
            padding: EdgeInsets.only(
              top: 12,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(sheetCtx).padding.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                  margin: const EdgeInsets.only(bottom: 18),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.edit_note_rounded,
                        color: AppTheme.primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '¿Qué deseas editar?',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${tratamiento.nombreMedicamento} • ${AppUtils.formatDoseTime(doseTime)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Material(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                          ),
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.primaryColor.withValues(
                              alpha: 0.1,
                            ),
                            child: Icon(
                              Icons.edit_calendar_outlined,
                              color: AppTheme.primaryColor,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            'Editar solo esta dosis',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryTextColor,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            'Cambiar la hora programada para esta toma (${AppUtils.formatDoseTime(doseTime)})',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.secondaryTextColor,
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right, size: 20),
                          onTap:
                              () => Navigator.of(sheetCtx).pop('single_dose'),
                        ),
                        Divider(height: 1, color: AppTheme.borderColor),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(16),
                            ),
                          ),
                          leading: CircleAvatar(
                            backgroundColor: Colors.purple.withValues(
                              alpha: 0.1,
                            ),
                            child: const Icon(
                              Icons.medication_outlined,
                              color: Colors.purple,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            'Editar tratamiento completo',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryTextColor,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            'Modificar medicamento, horarios, duración e inventario',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.secondaryTextColor,
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right, size: 20),
                          onTap:
                              () =>
                                  Navigator.of(sheetCtx).pop('full_treatment'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
    );

    if (option == 'single_dose') {
      if (!context.mounted) return;
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(doseTime),
      );
      if (pickedTime != null) {
        final newDoseTime = DateTime(
          doseTime.year,
          doseTime.month,
          doseTime.day,
          pickedTime.hour,
          pickedTime.minute,
        );
        await NotificationService.cancelSnoozeForTreatment(
          docId: tratamiento.id,
          doseTime: doseTime,
        );
        final updatedTratamiento = await firestoreService.deferOrMoveSingleDose(
          userId: widget.userId,
          docId: tratamiento.id,
          oldDoseTime: doseTime,
          newDoseTime: newDoseTime,
          profile: profile,
        );
        await NotificationService.rescheduleNextPendingDose(
          updatedTratamiento ?? tratamiento,
          widget.userId,
          profile,
        );
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Hora de la dosis modificada.')),
        );
      }
    } else if (option == 'full_treatment') {
      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (_) => EditarTratamientoPage(
                tratamiento: tratamiento,
                profile: profile,
              ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final firestoreService = context.read<FirestoreService>();
    final flatDoses = _obtenerDosisDelDia(_selectedDay!);

    // Calcular progreso diario
    final totalDoses = flatDoses.length;
    final takenDoses =
        flatDoses.where((d) => d['status'] == DoseStatus.tomada).length;
    final progressVal = totalDoses > 0 ? takenDoses / totalDoses : 0.0;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) => true,
      child: Column(
        children: [
          // TableCalendar Container Card (wrapped in RepaintBoundary for smooth transitions)
          RepaintBoundary(
            child: Container(
              margin: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppTheme.cardShadow,
                border:
                    (context.watch<PreferenceNotifier>().showCardBorder ||
                            context.watch<PreferenceNotifier>().highContrast)
                        ? Border.all(color: AppTheme.borderColor)
                        : null,
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragStart: (_) => _handleDragStart(),
                onVerticalDragUpdate: _handleDragUpdate,
                onVerticalDragEnd: (details) =>
                    _handleDragEnd(details.primaryVelocity ?? 0),
                onVerticalDragCancel: () {
                  if (_isDraggingCalendar && !_snapController.isAnimating) {
                    _handleDragCancel();
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildCalendar(),
                    CalendarExpandHandle(
                      calendarFormat: _calendarFormat,
                      onFormatChanged: _updateCalendarFormat,
                      isDragging: _isDraggingCalendar,
                      enableVerticalDrag: false,
                      onTap: _handleTap,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Resumen del día
          if (totalDoses > 0)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border:
                      (context.watch<PreferenceNotifier>().showCardBorder ||
                              context.watch<PreferenceNotifier>().highContrast)
                          ? Border.all(color: AppTheme.borderColor)
                          : null,
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n?.daySummary ?? 'Resumen del día',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryTextColor,
                          ),
                        ),
                        Text(
                          l10n?.dosesCompletedSummary(takenDoses, totalDoses) ??
                              '$takenDoses de $totalDoses dosis completadas',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progressVal,
                        minHeight: 8,
                        backgroundColor: AppTheme.surfaceColor,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 8.0,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n?.medicationsOfTheDay ?? "Medicamentos del día",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryTextColor,
                ),
              ),
            ),
          ),

          Expanded(
            child: ModernContentFade(
              topOffset: 0.0,
              height: 28,
              child: Builder(
                builder: (context) {
                  if (flatDoses.isEmpty) {
                    return Center(
                      child: SingleChildScrollView(
                        primary: false,
                        child: EstadoVista(
                          state: ViewState.empty,
                          emptyMessage:
                              l10n?.calendarNoEvents ??
                              'No hay dosis programadas para este día.',
                          child: const SizedBox.shrink(),
                        ),
                      ),
                    );
                  }

                  final isModern =
                      context.watch<PreferenceNotifier>().interfaceStyle ==
                      'modern';
                  return ListView.builder(
                    key: const PageStorageKey('calendar-day-doses'),
                    padding: EdgeInsets.only(
                      left: 20.0,
                      right: 20.0,
                      bottom: isModern ? 100.0 : 20.0,
                    ),
                    itemCount: flatDoses.length,
                    itemBuilder: (context, index) {
                      final dose = flatDoses[index];
                      final isFirst = index == 0;
                      final isLast = index == flatDoses.length - 1;
                      return _buildTimelineRow(
                        dose,
                        isFirst,
                        isLast,
                        firestoreService,
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    final langCode = Localizations.localeOf(context).languageCode;
    final builders = CalendarBuilders<Map<String, dynamic>>(
      markerBuilder: (context, day, events) => const SizedBox.shrink(),
      defaultBuilder: (context, day, focusedDay) {
        final dosesForDay = _getGroupedDosesForDay(day);
        if (dosesForDay.isEmpty) return null;
        final dayColor = _determineDayColor(dosesForDay);
        final isHighContrast = context.watch<PreferenceNotifier>().highContrast;
        return AspectRatio(
          aspectRatio: 1.0,
          child: Container(
            margin: const EdgeInsets.all(5.0),
            decoration: BoxDecoration(
              color: dayColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12.0),
              border: isHighContrast
                  ? Border.all(color: dayColor, width: 1.5)
                  : null,
            ),
            child: Center(
              child: Text(
                '${day.day}',
                style: TextStyle(
                  color: dayColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        );
      },
      selectedBuilder: (context, day, focusedDay) {
        return AspectRatio(
          aspectRatio: 1.0,
          child: Container(
            margin: const EdgeInsets.all(5.0),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(12.0),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(
                '${day.day}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        );
      },
      todayBuilder: (context, day, focusedDay) {
        final dosesForDay = _getGroupedDosesForDay(day);
        final dayColor = dosesForDay.isNotEmpty
            ? _determineDayColor(dosesForDay)
            : AppTheme.primaryColor;
        return AspectRatio(
          aspectRatio: 1.0,
          child: Container(
            margin: const EdgeInsets.all(5.0),
            decoration: BoxDecoration(
              color: dosesForDay.isNotEmpty
                  ? dayColor.withValues(alpha: 0.15)
                  : null,
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(
                color: dosesForDay.isNotEmpty
                    ? dayColor.withValues(alpha: 0.5)
                    : AppTheme.primaryColor,
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                '${day.day}',
                style: TextStyle(
                  color: dayColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        );
      },
    );
    final interactiveHeight = _interactiveHeight;
    final isPreview = interactiveHeight != null;
    final format = _calendarFormat;
    final selectionRevision = _selectionRevision;
    final calendar = TableCalendar<Map<String, dynamic>>(
      key: ValueKey((isPreview, format, selectionRevision)),
      locale: langCode == 'en' ? 'en_US' : (langCode == 'pt' ? 'pt_BR' : 'es_ES'),
      firstDay: DateTime.utc(2022, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: _focusedDay,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      calendarFormat: format,
      rowHeight: _calendarRowHeight,
      availableCalendarFormats: const {
        CalendarFormat.month: 'Month',
        CalendarFormat.twoWeeks: '2 weeks',
        CalendarFormat.week: 'Week',
      },
      availableGestures:
          isPreview ? AvailableGestures.none : AvailableGestures.horizontalSwipe,
      pageAnimationEnabled: false,
      formatAnimationDuration: Duration.zero,
      formatAnimationCurve: Curves.easeInOutCubic,
      eventLoader:
          (day) => _getGroupedDosesForDay(day).values.expand((d) => d).toList(),
      onDaySelected: (selectedDay, _) {
        final changesMonth = !_isDayOnCurrentPage(selectedDay, CalendarFormat.month);
        if (!changesMonth && isSameDay(_selectedDay, selectedDay)) return;

        final movesFocus = changesMonth ||
            !_isDayOnCurrentPage(selectedDay, _calendarFormat);
        setState(() {
          _selectedDay = selectedDay;
          if (movesFocus) _focusedDay = selectedDay;
        });
        _populateCacheForMonth(selectedDay);
      },
      onFormatChanged: (format) {
        _updateCalendarFormat(format);
      },
      onPageChanged: (focusedDay) {
        if (isPreview ||
            _interactiveHeight != null ||
            format != _calendarFormat ||
            selectionRevision != _selectionRevision) {
          return;
        }
        setState(() {
          if (_calendarFormat == CalendarFormat.month &&
              _selectedDay != null &&
              _selectedDay!.year == focusedDay.year &&
              _selectedDay!.month == focusedDay.month) {
            _focusedDay = _selectedDay!;
          } else {
            _focusedDay = focusedDay;
          }
        });
        _populateCacheForMonth(focusedDay);
      },
      calendarBuilders: builders,
      calendarStyle: _calendarStyle,
      headerStyle: HeaderStyle(
        titleCentered: true,
        formatButtonVisible: false,
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryTextColor,
        ),
      ),
    );

    // On a format change, TableCalendar must start from focusedDay, not
    // restore a page index from a different format or the dose list.
    final calendarWithLocalStorage = PageStorage(
      bucket: _calendarPageStorage,
      child: calendar,
    );
    final content = interactiveHeight == null
        ? calendarWithLocalStorage
        : _buildCalendarPreview(calendarWithLocalStorage, builders, interactiveHeight);

    final keyToUse = widget.calendarViewKey ?? widget.calendarKey;
    if (keyToUse != null) {
      final l10n = AppLocalizations.of(context);
      return Showcase.withWidget(
        key: keyToUse,
        height: 200,
        width: 320,
        disableDefaultTargetGestures: true,
        container: TutorialTooltip(
          icon: Icons.today_rounded,
          title: l10n?.tutorialStep7Title ?? 'Historial y Detalle del Día',
          description:
              l10n?.tutorialStep7Desc ??
              'Revisa cada día según tus dosis:\n🟢 Tomadas  🔴 Omitidas  🟡 Pendientes\n\nToca cualquier día para ver la lista de dosis programadas.',
          stepNumber: 7,
          totalSteps: 11,
        ),
        targetShapeBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        targetPadding: const EdgeInsets.all(4),
        child: content,
      );
    }
    return content;
  }

  Widget _buildCalendarPreview(
    Widget calendar,
    CalendarBuilders<Map<String, dynamic>> builders,
    double height,
  ) {
    final monthStart = _firstDayOfWeek(DateTime.utc(_focusedDay.year, _focusedDay.month));
    final weekStart = _firstDayOfWeek(_focusedDay);
    final twoWeekStart = _firstDayOfTwoWeeks(_focusedDay);
    final firstRow = monthStart.isBefore(twoWeekStart) ? monthStart : twoWeekStart;
    final monthRows = _getMonthRowCount(_focusedDay);
    final monthHeight = _getMonthHeight(_focusedDay);

    double rowOf(DateTime day) => day.difference(firstRow).inDays / 7;
    final firstVisibleRow = height <= _kHeightTwoWeeks
        ? rowOf(weekStart) + (rowOf(twoWeekStart) - rowOf(weekStart)) *
            ((height - _kHeightWeek) / _calendarRowHeight).clamp(0.0, 1.0)
        : rowOf(twoWeekStart) + (rowOf(monthStart) - rowOf(twoWeekStart)) *
            ((height - _kHeightTwoWeeks) / (monthHeight - _kHeightTwoWeeks)).clamp(0.0, 1.0);

    final lastMonthRow = rowOf(monthStart).toInt() + monthRows;
    final lastBiweeklyRow = rowOf(twoWeekStart).toInt() + 2;
    final rowCount = lastMonthRow > lastBiweeklyRow ? lastMonthRow : lastBiweeklyRow;
    final datesHeight = height - _calendarHeaderHeight;
    final rowViewportHeight = datesHeight - _dayShadowPadding;
    final rowOffset = firstVisibleRow * _calendarRowHeight;
    final today = DateTime.now();
    final outsideDayOpacity =
        (1 - (height - _kHeightTwoWeeks) / (monthHeight - _kHeightTwoWeeks))
            .clamp(0.0, 1.0);

    return IgnorePointer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRect(
            child: SizedBox(
              height: _calendarHeaderHeight,
              child: OverflowBox(
                alignment: Alignment.topCenter,
                minHeight: 0,
                maxHeight: monthHeight,
                child: calendar,
              ),
            ),
          ),
          ClipRect(
            child: SizedBox(
              height: datesHeight,
              child: OverflowBox(
                alignment: Alignment.topCenter,
                minHeight: 0,
                maxHeight: rowCount * _calendarRowHeight + _dayShadowPadding,
                child: Transform.translate(
                  offset: Offset(0, -rowOffset),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(rowCount, (row) {
                      final rowTop = row * _calendarRowHeight - rowOffset;
                      final visibleHeight = (rowTop + _calendarRowHeight)
                              .clamp(0.0, rowViewportHeight) -
                          rowTop.clamp(0.0, rowViewportHeight);
                      final opacity =
                          ((visibleHeight / _calendarRowHeight - 0.6) / 0.4)
                              .clamp(0.0, 1.0);
                      return Opacity(
                        opacity: opacity,
                        child: SizedBox(
                          height: _calendarRowHeight,
                          child: Row(
                            children: List.generate(7, (column) {
                              final day = firstRow.add(Duration(days: row * 7 + column));
                              final isOutside = day.month != _focusedDay.month;
                              final isWeekend = day.weekday >= DateTime.saturday;
                              final dayBuilder = isSameDay(_selectedDay, day)
                                  ? builders.selectedBuilder
                                  : isSameDay(today, day)
                                      ? builders.todayBuilder
                                      : isOutside
                                          ? builders.outsideBuilder
                                          : builders.defaultBuilder;
                              final textStyle = isOutside
                                  ? _calendarStyle.outsideTextStyle
                                  : isWeekend
                                      ? _calendarStyle.weekendTextStyle
                                      : _calendarStyle.defaultTextStyle;
                              final cell = Center(
                                child: dayBuilder?.call(context, day, _focusedDay) ??
                                    Text('${day.day}', style: textStyle),
                              );
                              return Expanded(
                                child: isOutside
                                    ? Opacity(opacity: outsideDayOpacity, child: cell)
                                    : cell,
                              );
                            }),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineRow(
    Map<String, dynamic> dose,
    bool isFirst,
    bool isLast,
    FirestoreService firestoreService,
  ) {
    final Tratamiento tratamiento = dose['tratamiento'];
    final CaregiverProfile? profile = dose['profile'];
    final DateTime doseTime = dose['doseTime'];
    final DoseStatus status = dose['status'];
    final l10n = AppLocalizations.of(context);
    final timeStr = AppUtils.formatDoseTime(doseTime);

    // Determinar estilo visual según el estado
    Color nodeColor = Colors.grey.shade300;
    Widget nodeWidget = Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(shape: BoxShape.circle, color: nodeColor),
    );
    final isPast = doseTime.isBefore(DateTime.now());

    if (status == DoseStatus.tomada) {
      nodeColor = AppTheme.successColor;
      nodeWidget = Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(shape: BoxShape.circle, color: nodeColor),
        child: const Icon(Icons.check, color: Colors.white, size: 14),
      );
    } else if (status == DoseStatus.omitida) {
      nodeColor = AppTheme.errorColor;
      nodeWidget = Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(shape: BoxShape.circle, color: nodeColor),
        child: const Icon(Icons.close, color: Colors.white, size: 14),
      );
    } else if (status == DoseStatus.aplazada) {
      nodeColor = Colors.orange;
      nodeWidget = Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.orange,
        ),
        child: const Icon(
          Icons.watch_later_outlined,
          color: Colors.white,
          size: 14,
        ),
      );
    } else if (status == DoseStatus.notificada ||
        (status == DoseStatus.pendiente && isPast)) {
      nodeColor = Colors.amber;
      nodeWidget = Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(shape: BoxShape.circle, color: nodeColor),
        child: const Icon(Icons.notifications, color: Colors.white, size: 14),
      );
    } else {
      nodeColor = const Color(0xFFC3C6D7);
      nodeWidget = Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: nodeColor, width: 2),
        ),
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator (Left)
          SizedBox(
            width: 24,
            child: Column(
              children: [
                if (isFirst)
                  const SizedBox(height: 22)
                else
                  Container(
                    width: 2,
                    height: 22,
                    color: const Color(0xFFC3C6D7).withValues(alpha: 0.4),
                  ),
                nodeWidget,
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: const Color(0xFFC3C6D7).withValues(alpha: 0.4),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Dose Card (Right)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ContainerTransformCard<void>(
                    openBuilder:
                        (context, _) => DetalleRecetaPage(
                          tratamiento: tratamiento,
                          horaDosis: doseTime,
                          profile: profile,
                        ),
                    closedBuilder: (context, openContainer) {
                      final localizedPres = AppUtils.localizePresentation(
                        context,
                        tratamiento.presentacion,
                      );
                      final dosePresentationText =
                          tratamiento.dosisPorToma > 0
                              ? '${tratamiento.dosisPorToma} $localizedPres'
                              : localizedPres;
                      final localizedFreq =
                          tratamiento.intervaloDosis.inHours == 1
                              ? (l10n?.everyHourSingle ?? 'Cada hora')
                              : (l10n?.everyHours(
                                    tratamiento.intervaloDosis.inHours,
                                  ) ??
                                  'Cada ${tratamiento.intervaloDosis.inHours} horas');

                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Main Card Content (Opens Detail Screen)
                            Expanded(
                              child: InkWell(
                                onTap: openContainer,
                                borderRadius: const BorderRadius.horizontal(
                                  left: Radius.circular(20),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    left: 16,
                                    right: 4,
                                    top: 22,
                                    bottom: 22,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          // Left Column: Time & Frequency
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                timeStr,
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      AppUtils.getDoseStatusColor(
                                                        status,
                                                        isPast: isPast,
                                                      ),
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.access_time_rounded,
                                                    size: 13,
                                                    color:
                                                        AppTheme
                                                            .secondaryTextColor,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    localizedFreq,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          AppTheme
                                                              .secondaryTextColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),

                                          // Subtle Vertical Divider
                                          Container(
                                            height: 42,
                                            width: 1,
                                            margin: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                            ),
                                            color: AppTheme.secondaryTextColor
                                                .withValues(alpha: 0.18),
                                          ),

                                          // Right Column: Medication Name & Presentation
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  tratamiento.nombreMedicamento,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 17,
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        AppTheme
                                                            .primaryTextColor,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    MedicationPresentationIcon(
                                                      presentation:
                                                          tratamiento
                                                              .presentacion,
                                                      size: 13,
                                                      color:
                                                          AppTheme
                                                              .secondaryTextColor,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        dosePresentationText,
                                                        maxLines: 1,
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color:
                                                              AppTheme
                                                                  .secondaryTextColor,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),

                                      // Caregiver Profile Tag
                                      if (profile != null) ...[
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Color(
                                              int.parse(
                                                profile.colorHex.replaceFirst(
                                                  '#',
                                                  'FF',
                                                ),
                                                radix: 16,
                                              ),
                                            ).withValues(alpha: 0.05),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            border: Border.all(
                                              color: Color(
                                                int.parse(
                                                  profile.colorHex.replaceFirst(
                                                    '#',
                                                    'FF',
                                                  ),
                                                  radix: 16,
                                                ),
                                              ).withValues(alpha: 0.2),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.person,
                                                size: 12,
                                                color: Color(
                                                  int.parse(
                                                    profile.colorHex
                                                        .replaceFirst(
                                                          '#',
                                                          'FF',
                                                        ),
                                                    radix: 16,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                profile.name,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(
                                                    int.parse(
                                                      profile.colorHex
                                                          .replaceFirst(
                                                            '#',
                                                            'FF',
                                                          ),
                                                      radix: 16,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Entire Right Strip (Opens Dose Options Dialog)
                            InkWell(
                              onTap:
                                  () => _showDoseOptionsDialog(
                                    context,
                                    tratamiento,
                                    profile,
                                    doseTime,
                                    status,
                                  ),
                              borderRadius: const BorderRadius.horizontal(
                                right: Radius.circular(20),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  left: 6.0,
                                  right: 14.0,
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.more_vert,
                                    color: AppTheme.secondaryTextColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // Quick Action Buttons below if it's notified or pending past (pending response)
                  if (status == DoseStatus.notificada ||
                      (status == DoseStatus.pendiente && isPast))
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                      child: Row(
                        children: [
                          FilledButton.icon(
                            icon: const Icon(Icons.check, size: 14),
                            label: Text(
                              l10n?.doseStatusTaken ?? 'Tomada',
                              style: const TextStyle(fontSize: 11),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.successColor.withValues(
                                alpha: 0.12,
                              ),
                              foregroundColor: AppTheme.successColor,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              elevation: 0,
                            ),
                            onPressed: () async {
                              final result = await firestoreService
                                  .updateDoseStatus(
                                    widget.userId,
                                    tratamiento.id,
                                    doseTime,
                                    DoseStatus.tomada,
                                    profile,
                                  );
                              if (!mounted) return;
                              if (result?.stockBajo == true) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Stock bajo: te quedan ${result!.dosisRestantes} dosis',
                                    ),
                                    action: SnackBarAction(
                                      label: 'Farmacias',
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder:
                                                (context) =>
                                                    const LocalizadorFarmaciasPage(),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            icon: const Icon(Icons.close, size: 14),
                            label: Text(
                              l10n?.doseStatusSkipped ?? 'Omitida',
                              style: const TextStyle(fontSize: 11),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.errorColor.withValues(
                                alpha: 0.12,
                              ),
                              foregroundColor: AppTheme.errorColor,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              elevation: 0,
                            ),
                            onPressed: () {
                              firestoreService.updateDoseStatus(
                                widget.userId,
                                tratamiento.id,
                                doseTime,
                                DoseStatus.omitida,
                                profile,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// A simple manual stream combiner since we don't have rxdart
Stream<List<T>> _combineLatest<T>(List<Stream<T>> streams) {
  if (streams.isEmpty) {
    return Stream.value([]);
  }

  late StreamController<List<T>> controller;
  List<T?> currentValues = List.filled(streams.length, null);
  List<bool> hasValue = List.filled(streams.length, false);

  controller = StreamController<List<T>>.broadcast(
    onListen: () {
      int completed = 0;
      List<dynamic> subscriptions = [];

      for (int i = 0; i < streams.length; i++) {
        subscriptions.add(
          streams[i].listen(
            (value) {
              currentValues[i] = value;
              hasValue[i] = true;
              if (!hasValue.contains(false)) {
                controller.add(List<T>.from(currentValues));
              }
            },
            onError: controller.addError,
            onDone: () {
              completed++;
              if (completed == streams.length) {
                controller.close();
              }
            },
          ),
        );
      }

      controller.onCancel = () {
        for (var sub in subscriptions) {
          sub.cancel();
        }
      };
    },
  );

  return controller.stream;
}
