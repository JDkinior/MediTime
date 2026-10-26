import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import 'package:flutter/rendering.dart';

import 'package:meditime/enums/view_state.dart';

import 'package:meditime/models/tratamiento.dart';

import 'package:meditime/widgets/estado_vista.dart';

import 'package:provider/provider.dart';

import 'package:meditime/notifiers/preference_notifier.dart';

import 'package:meditime/services/auth_service.dart';

import 'package:meditime/services/firestore_service.dart';

import 'package:meditime/services/pdf_report_service.dart';

import 'package:meditime/theme/app_theme.dart';

import 'package:meditime/services/tratamiento_service.dart';



import 'package:intl/intl.dart';

import 'package:fl_chart/fl_chart.dart';



import 'package:meditime/l10n/generated/app_localizations.dart';

import 'package:meditime/core/subscription_guard.dart';

import 'package:meditime/notifiers/caregiver_notifier.dart';


import 'package:meditime/widgets/modern_app_bar.dart';

import 'package:meditime/widgets/modern_content_fade.dart';



// Enum para manejar los intervalos de forma clara

export 'package:meditime/enums/report_interval.dart';

import 'package:meditime/enums/report_interval.dart';

import 'package:meditime/widgets/reports/multi_segment_ring_painter.dart';

import 'package:meditime/widgets/reports/evolution_details_sheet.dart';

import 'package:meditime/widgets/reports/full_history_sheet.dart';
import 'package:meditime/widgets/reports/full_treatment_breakdown_sheet.dart';
import 'package:meditime/widgets/reports/treatment_accordion_card.dart';

import 'package:meditime/widgets/reports/omission_analysis_sheet.dart';



class ReportesPage extends StatefulWidget {

  const ReportesPage({super.key, this.initialInterval});



  final ReportInterval? initialInterval;



  @override

  State<ReportesPage> createState() => _ReportesPageState();

}



class _ReportesPageState extends State<ReportesPage> {

  // Estado para manejar el intervalo seleccionado

  late ReportInterval _selectedInterval;

  final GlobalKey _chartKey = GlobalKey();

  final PdfReportService _pdfService = PdfReportService();

  final ScrollController _scrollController = ScrollController();

  

  // Acordeón expandible

  final Set<String> _expandedTreatments = {};
@override

  void initState() {

    super.initState();

    _selectedInterval = widget.initialInterval ?? ReportInterval.todo;

  }



  @override

  void dispose() {

    _scrollController.dispose();

    super.dispose();

  }







  // Función para capturar el widget como una imagen

  Future<Uint8List?> _capturePng() async {

    try {

      if (_chartKey.currentContext == null) return null;

      RenderRepaintBoundary boundary =

          _chartKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

      ui.Image image = await boundary.toImage(pixelRatio: 3.0);

      ByteData? byteData =

          await image.toByteData(format: ui.ImageByteFormat.png);

      return byteData?.buffer.asUint8List();

    } catch (e) {

      debugPrint("Error capturando imagen: $e");

      return null;

    }

  }



  // Función para obtener el rango de fechas según el intervalo

  Map<String, DateTime> _getDateRange() {

    final now = DateTime.now();

    DateTime startDate;

    switch (_selectedInterval) {

      case ReportInterval.semana:

        startDate = now.subtract(Duration(days: now.weekday - 1));

        break;

      case ReportInterval.mes:

        startDate = DateTime(now.year, now.month, 1);

        break;

      case ReportInterval.anio:

        startDate = DateTime(now.year, 1, 1);

        break;

      case ReportInterval.todo:

        startDate = DateTime(2000);

        break;

    }

    return {

      'start': DateTime(startDate.year, startDate.month, startDate.day),

      'end': now,

    };

  }



  // Caché en memoria para evitar recalcular estadísticas repetidamente en un mismo ciclo

  final Map<String, Map<String, int>> _statsCache = {};



  // Lógica de cálculo de dosis optimizada

  Map<String, int> _calcularEstadisticas(Tratamiento tratamiento, Map<String, DateTime> dateRange) {

    final start = dateRange['start']!;

    final end = dateRange['end']!;

    final cacheKey = "${tratamiento.id}_${start.millisecondsSinceEpoch}_${end.millisecondsSinceEpoch}_${tratamiento.doseStatus.length}";

    if (_statsCache.containsKey(cacheKey)) {

      return _statsCache[cacheKey]!;

    }



    int tomadas = 0;

    int omitidas = 0;

    int notificadas = 0;

    int aplazadas = 0;



    final now = DateTime.now();



    // 1. Recopilar y contabilizar todas las dosis registradas explícitamente en doseStatus dentro del rango

    final List<DateTime> recordedTimes = [];

    tratamiento.doseStatus.forEach((key, status) {

      final parsedTime = DateTime.tryParse(key);

      if (parsedTime != null &&

          !parsedTime.isBefore(start) &&

          !parsedTime.isAfter(end) &&

          parsedTime.isBefore(now)) {

        recordedTimes.add(parsedTime);

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



    // Ordenar para búsqueda lineal optimizada O(N + M)

    recordedTimes.sort();



    // 2. Generar dosis teóricas programadas y detectar las pasadas no registradas (olvidadas)

    final todasLasDosis = TratamientoService.generarDosisEnRango(tratamiento, start, end);

    final intervaloMinutos = tratamiento.intervaloDosis.inMinutes > 0 ? tratamiento.intervaloDosis.inMinutes : 240;

    final maxToleranceMinutes = (intervaloMinutos / 2).clamp(30.0, 180.0);



    int recIdx = 0;

    final int recLen = recordedTimes.length;



    for (final doseTime in todasLasDosis) {

      if (!doseTime.isBefore(start) && !doseTime.isAfter(end) && doseTime.isBefore(now)) {

        // Avanzar el puntero hasta las dosis cercanas a doseTime

        while (recIdx < recLen && doseTime.difference(recordedTimes[recIdx]).inMinutes > maxToleranceMinutes) {

          recIdx++;

        }



        bool isRecorded = false;

        int checkIdx = recIdx;

        while (checkIdx < recLen) {

          final diffMinutes = recordedTimes[checkIdx].difference(doseTime).inMinutes;

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

          // Dosis pasada que nunca fue interactuada ni registrada -> cuenta como omitida

          omitidas++;

        }

      }

    }



    final int programadasPasadas = tomadas + omitidas + notificadas + aplazadas;



    final result = {

      'tomadas': tomadas,

      'omitidas': omitidas,

      'notificadas': notificadas,

      'aplazadas': aplazadas,

      'programadasPasadas': programadasPasadas,

    };

    _statsCache[cacheKey] = result;

    return result;

  }



  // Obtener datos de evolución (spots, etiquetas y detalles) según el intervalo de reporte seleccionado arriba

  Map<String, dynamic> _getEvolutionData(List<Tratamiento> tratamientos) {

    final List<FlSpot> spots = [];

    final List<String> labels = [];

    final List<Map<String, dynamic>> details = [];

    final now = DateTime.now();

    final locale = Localizations.localeOf(context).toString();

    final isEs = locale.startsWith('es');



    switch (_selectedInterval) {

      case ReportInterval.semana:

        // 7 días de la semana actual (Lunes a Domingo)

        final monday = now.subtract(Duration(days: now.weekday - 1));

        for (int i = 0; i < 7; i++) {

          final date = monday.add(Duration(days: i));

          final shortLetter = DateFormat.E(locale).format(date).substring(0, 1).toUpperCase();

          labels.add(shortLetter);

          final range = {

            'start': DateTime(date.year, date.month, date.day, 0, 0, 0),

            'end': DateTime(date.year, date.month, date.day, 23, 59, 59),

          };

          int tomadas = 0;

          int programadas = 0;

          int omitidas = 0;

          int notificadas = 0;

          int aplazadas = 0;

          for (var t in tratamientos) {

            final stats = _calcularEstadisticas(t, range);

            tomadas += stats['tomadas']!;

            programadas += stats['programadasPasadas']!;

            omitidas += stats['omitidas']!;

            notificadas += stats['notificadas']!;

            aplazadas += stats['aplazadas']!;

          }

          final double compliance = programadas > 0 ? (tomadas / programadas) * 100 : 0.0;

          spots.add(FlSpot(i.toDouble(), compliance));

          details.add({

            'label': shortLetter,

            'fullLabel': "${DateFormat.EEEE(locale).format(date)} ${date.day} ${DateFormat('MMM', locale).format(date)}",

            'compliance': compliance,

            'tomadas': tomadas,

            'programadas': programadas,

            'omitidas': omitidas,

            'notificadas': notificadas,

            'aplazadas': aplazadas,

          });

        }

        break;



      case ReportInterval.mes:

        // 6 intervalos de 5 días dentro del mes

        final monthLabels = ['5', '10', '15', '20', '25', '30'];

        labels.addAll(monthLabels);

        for (int i = 0; i < 6; i++) {

          final startDay = 1 + i * 5;

          final endDay = (i + 1) * 5;

          final start = DateTime(now.year, now.month, startDay, 0, 0, 0);

          final end = DateTime(now.year, now.month, endDay > 30 ? 30 : endDay, 23, 59, 59);

          final range = {'start': start, 'end': end};



          int tomadas = 0;

          int programadas = 0;

          int omitidas = 0;

          int notificadas = 0;

          int aplazadas = 0;

          for (var t in tratamientos) {

            final stats = _calcularEstadisticas(t, range);

            tomadas += stats['tomadas']!;

            programadas += stats['programadasPasadas']!;

            omitidas += stats['omitidas']!;

            notificadas += stats['notificadas']!;

            aplazadas += stats['aplazadas']!;

          }

          final double compliance = programadas > 0 ? (tomadas / programadas) * 100 : 0.0;

          spots.add(FlSpot(i.toDouble(), compliance));

          final displayEndDay = endDay > 30 ? 30 : endDay;

          details.add({

            'label': isEs ? 'Días $startDay-$displayEndDay' : 'Days $startDay-$displayEndDay',

            'fullLabel': isEs

                ? "Días $startDay al $displayEndDay de ${DateFormat('MMMM', locale).format(now)}"

                : "Days $startDay to $displayEndDay of ${DateFormat('MMMM', locale).format(now)}",

            'compliance': compliance,

            'tomadas': tomadas,

            'programadas': programadas,

            'omitidas': omitidas,

            'notificadas': notificadas,

            'aplazadas': aplazadas,

          });

        }

        break;



      case ReportInterval.anio:

        // 12 iniciales de los meses según locale

        for (int i = 0; i < 12; i++) {

          final monthDate = DateTime(now.year, i + 1, 1);

          final monthLetter = DateFormat.MMM(locale).format(monthDate).substring(0, 1).toUpperCase();

          labels.add(monthLetter);

          final start = DateTime(now.year, i + 1, 1, 0, 0, 0);

          final end = DateTime(now.year, i + 2, 0, 23, 59, 59);

          final range = {'start': start, 'end': end};



          int tomadas = 0;

          int programadas = 0;

          int omitidas = 0;

          int notificadas = 0;

          int aplazadas = 0;

          for (var t in tratamientos) {

            final stats = _calcularEstadisticas(t, range);

            tomadas += stats['tomadas']!;

            programadas += stats['programadasPasadas']!;

            omitidas += stats['omitidas']!;

            notificadas += stats['notificadas']!;

            aplazadas += stats['aplazadas']!;

          }

          final double compliance = programadas > 0 ? (tomadas / programadas) * 100 : 0.0;

          spots.add(FlSpot(i.toDouble(), compliance));

          details.add({

            'label': DateFormat('MMM', locale).format(monthDate),

            'fullLabel': "${DateFormat('MMMM', locale).format(monthDate)} ${now.year}",

            'compliance': compliance,

            'tomadas': tomadas,

            'programadas': programadas,

            'omitidas': omitidas,

            'notificadas': notificadas,

            'aplazadas': aplazadas,

          });

        }

        break;



      case ReportInterval.todo:

        // 6 meses anteriores

        for (int i = 5; i >= 0; i--) {

          final targetMonth = DateTime(now.year, now.month - i, 1);

          final monthStr = DateFormat('MMM', locale).format(targetMonth);

          labels.add(monthStr);

          final start = DateTime(targetMonth.year, targetMonth.month, 1, 0, 0, 0);

          final end = DateTime(targetMonth.year, targetMonth.month + 1, 0, 23, 59, 59);

          final range = {'start': start, 'end': end};



          int tomadas = 0;

          int programadas = 0;

          int omitidas = 0;

          int notificadas = 0;

          int aplazadas = 0;

          for (var t in tratamientos) {

            final stats = _calcularEstadisticas(t, range);

            tomadas += stats['tomadas']!;

            programadas += stats['programadasPasadas']!;

            omitidas += stats['omitidas']!;

            notificadas += stats['notificadas']!;

            aplazadas += stats['aplazadas']!;

          }

          final double compliance = programadas > 0 ? (tomadas / programadas) * 100 : 0.0;

          spots.add(FlSpot((5 - i).toDouble(), compliance));

          details.add({

            'label': monthStr,

            'fullLabel': DateFormat('MMMM yyyy', locale).format(targetMonth),

            'compliance': compliance,

            'tomadas': tomadas,

            'programadas': programadas,

            'omitidas': omitidas,

            'notificadas': notificadas,

            'aplazadas': aplazadas,

          });

        }

        break;

    }



    return {'spots': spots, 'labels': labels, 'details': details};

  }



  // Obtener historial reciente ordenado por fecha (filtrado por rango)

  List<Map<String, dynamic>> _getRecentHistory(List<Tratamiento> tratamientos, Map<String, DateTime> dateRange) {

    final List<Map<String, dynamic>> history = [];

    final now = DateTime.now();

    final start = dateRange['start']!;

    final end = dateRange['end']!;

    for (var t in tratamientos) {

      t.doseStatus.forEach((dateString, status) {

        // Filtrar por status primero para evitar parsing innecesario

        if (status == DoseStatus.tomada || status == DoseStatus.omitida || status == DoseStatus.notificada || status == DoseStatus.aplazada) {

          final doseTime = DateTime.tryParse(dateString);

          if (doseTime != null &&

              doseTime.isBefore(now) &&

              !doseTime.isBefore(start) &&

              !doseTime.isAfter(end)) {

            history.add({

              'treatment': t,

              'time': doseTime,

              'status': status,

            });

          }

        }

      });

    }

    history.sort((a, b) => (b['time'] as DateTime).compareTo(a['time'] as DateTime));

    return history.take(4).toList();

  }



  // Analizar patrones de omisión dinámicamente

  Map<String, String> _analyzeOmissionsPattern(List<Tratamiento> tratamientos, Map<String, DateTime> dateRange) {

    int morningOmissions = 0;

    int afternoonOmissions = 0;

    int nightOmissions = 0;

    int earlyOmissions = 0;



    final now = DateTime.now();

    final start = dateRange['start']!;

    final end = dateRange['end']!;



    for (var t in tratamientos) {

      t.doseStatus.forEach((dateString, status) {

        if (status == DoseStatus.omitida) {

          final doseTime = DateTime.tryParse(dateString);

          // Solo contar omisiones dentro del rango seleccionado y pasadas

          if (doseTime != null && doseTime.isBefore(now) && !doseTime.isBefore(start) && !doseTime.isAfter(end)) {

            final hour = doseTime.hour;

            if (hour >= 6 && hour < 12) {

              morningOmissions++;

            } else if (hour >= 12 && hour < 18) {

              afternoonOmissions++;

            } else if (hour >= 18 && hour < 24) {

              nightOmissions++;

            } else {

              earlyOmissions++;

            }

          }

        }

      });

    }



    final maxVal = [morningOmissions, afternoonOmissions, nightOmissions, earlyOmissions].reduce((a, b) => a > b ? a : b);



    if (maxVal == 0) {

      return {

        'title': '¡Gran constancia!',

        'subtitle': 'No presentas omisiones de dosis registradas.',

        'recommendation': 'Sigue con esta excelente disciplina de toma.',

      };

    }



    if (maxVal == morningOmissions) {

      return {

        'title': 'Sueles omitir más dosis en la mañana',

        'subtitle': 'Entre 6:00 a. m. y 12:00 p. m.',

        'recommendation': 'Recomendación: Deja tu pastillero cerca del desayuno para no olvidarlo.',

      };

    } else if (maxVal == afternoonOmissions) {

      return {

        'title': 'Sueles omitir más dosis en la tarde',

        'subtitle': 'Entre 12:00 p. m. y 6:00 p. m.',

        'recommendation': 'Recomendación: Activa recordatorios en ese horario para mejorar tu adherencia.',

      };

    } else if (maxVal == nightOmissions) {

      return {

        'title': 'Sueles omitir más dosis en la noche',

        'subtitle': 'Entre 6:00 p. m. y 12:00 a. m.',

        'recommendation': 'Recomendación: Configura una alarma de soporte 15 minutos antes de dormir.',

      };

    } else {

      return {

        'title': 'Sueles omitir más dosis de madrugada',

        'subtitle': 'Entre 12:00 a. m. y 6:00 a. m.',

        'recommendation': 'Recomendación: Ajusta las horas de tus tomas para evitar interrumpir tu sueño.',

      };

    }

  }



  @override

  Widget build(BuildContext context) {

    final authService = context.watch<AuthService>();

    final firestoreService = context.watch<FirestoreService>();

    final preferenceNotifier = context.watch<PreferenceNotifier>();

    final caregiverNotifier = context.watch<CaregiverNotifier>();

    final user = authService.currentUser;

    final dateRange = _getDateRange();

    final isAnimal = preferenceNotifier.isAnimalMode;

    final isManagedMode = caregiverNotifier.isCaregiverModeActive || isAnimal;

    final activeProfile = isManagedMode

        ? caregiverNotifier.getEffectiveActiveProfile(isAnimalMode: isAnimal)

        : null;



    return Scaffold(

      backgroundColor: AppTheme.backgroundColor,

      appBar: ModernAppBar(

        showFade: false,

        child: AppBar(

        title: Text(

          'Reporte de Adherencia',

          style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryTextColor, fontSize: 20),

        ),

        centerTitle: true,

        elevation: 0,

        backgroundColor: AppTheme.backgroundColor,

        foregroundColor: AppTheme.primaryTextColor,

        actions: [

          IconButton(

            icon: Icon(Icons.file_download_outlined, color: AppTheme.primaryColor),

            onPressed: () async {

              final canProceed = await SubscriptionGuard.canExportPdf(context);

              if (!canProceed || !context.mounted) return;



              final imageBytes = await _capturePng();

              if (imageBytes == null) {

                if (context.mounted) {

                  ScaffoldMessenger.of(context).showSnackBar(

                    const SnackBar(content: Text("Error al generar el gráfico del reporte.")),

                  );

                }

                return;

              }



              final List<Tratamiento> tratamientos = await firestoreService.getMedicamentosStream(user!.uid, activeProfile).first;

              final dateRangePdf = _getDateRange();

              

              List<Map<String, dynamic>> tratamientosData = [];

              int totalDosisTomadasGlobal = 0;

              int totalDosisOmitidasGlobal = 0;

              int totalDosisNotificadasGlobal = 0;

              int totalDosisAplazadasGlobal = 0;



              for (var tratamiento in tratamientos) {

                final stats = _calcularEstadisticas(tratamiento, dateRangePdf);

                final int dosisProgramadas = stats['programadasPasadas']!;

                final int dosisOmitidas = stats['omitidas']!;

                final int dosisTomadas = stats['tomadas']!;

                final int dosisNotificadas = stats['notificadas']!;

                final int dosisAplazadas = stats['aplazadas']!;



                if (dosisProgramadas > 0) {

                  totalDosisTomadasGlobal += dosisTomadas;

                  totalDosisOmitidasGlobal += dosisOmitidas;

                  totalDosisNotificadasGlobal += dosisNotificadas;

                  totalDosisAplazadasGlobal += dosisAplazadas;

                  tratamientosData.add({

                    'nombreMedicamento': tratamiento.nombreMedicamento,

                    'adherencia': (dosisTomadas / dosisProgramadas) * 100,

                    'tomadas': dosisTomadas,

                    'programadas': dosisProgramadas,

                  });

                }

              }

              

              await _pdfService.generateAndShowPdf(

                intervalText: _selectedInterval.toString().split('.').last.toUpperCase(),

                tomadas: totalDosisTomadasGlobal,

                omitidas: totalDosisOmitidasGlobal,

                notificadas: totalDosisNotificadasGlobal,

                aplazadas: totalDosisAplazadasGlobal,

                tratamientos: tratamientosData,

                chartImage: imageBytes,

              );

            },

          ),

        ],

        ),

      ),

      body: user == null

          ? Center(child: Text(AppLocalizations.of(context)?.reportsLoginRequired ?? 'Inicia sesión para ver tus reportes.'))

          : Column(

              children: [

                _buildIntervalSelector(),

                Expanded(

                  child: ModernContentFade(

                    topOffset: 0.0,

                    height: 32,

                    child: StreamBuilder<List<Tratamiento>>(

                    initialData: firestoreService.getCachedMedicamentos(user.uid, activeProfile),

                    stream: firestoreService.getMedicamentosStream(user.uid, activeProfile),

                    builder: (context, snapshot) {

                      final l10n = AppLocalizations.of(context);

                      if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {

                        return const EstadoVista(state: ViewState.loading, child: SizedBox.shrink());

                      }

                      if (snapshot.hasError) {

                        return EstadoVista(

                          state: ViewState.error,

                          errorMessage: l10n?.reportsLoadError ?? "Error al cargar los datos para el reporte.",

                          onRetry: () => setState(() {}),

                          child: const SizedBox.shrink(),

                        );

                      }

                      if (!snapshot.hasData || snapshot.data!.isEmpty) {

                        return EstadoVista(

                          state: ViewState.empty,

                          emptyMessage: l10n?.reportsNoTreatments ?? 'No hay tratamientos para generar un reporte.',

                          child: const SizedBox.shrink(),

                        );

                      }



                      final todosLosTratamientos = snapshot.data!;

                      int totalDosisOmitidas = 0;

                      int totalDosisTomadas = 0;

                      int totalDosisNotificadas = 0;

                      int totalDosisAplazadas = 0;

                      int totalDosisProgramadas = 0;



                      for (var tratamiento in todosLosTratamientos) {

                        final stats = _calcularEstadisticas(tratamiento, dateRange);

                        totalDosisOmitidas += stats['omitidas']!;

                        totalDosisTomadas += stats['tomadas']!;

                        totalDosisNotificadas += stats['notificadas']!;

                        totalDosisAplazadas += stats['aplazadas']!;

                        totalDosisProgramadas += stats['programadasPasadas']!;

                      }



                      final double compliancePercentage = totalDosisProgramadas > 0

                          ? (totalDosisTomadas / totalDosisProgramadas) * 100

                          : 0.0;



                      final recentHistory = _getRecentHistory(todosLosTratamientos, dateRange);

                      final omissionsInfo = _analyzeOmissionsPattern(todosLosTratamientos, dateRange);



                      return ListView(

                          controller: _scrollController,

                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),

                          physics: const BouncingScrollPhysics(),

                          children: [

                            // 1. Tarjeta Adherencia General

                            RepaintBoundary(

                              key: _chartKey,

                              child: _buildOverallAdherenceCard(compliancePercentage, totalDosisTomadas, totalDosisOmitidas, totalDosisNotificadas, totalDosisAplazadas),

                            ),

                            const SizedBox(height: 16),



                            // 2. Banner dinámico de sugerencia/atención

                            _buildSuggestionBanner(
                              compliancePercentage,
                              totalProgramadas: totalDosisProgramadas,
                              totalOmitidas: totalDosisOmitidas,
                              totalAplazadas: totalDosisAplazadas,
                            ),

                            const SizedBox(height: 16),



                            // 3. Resumen Rápido (5 columnas)

                            _buildQuickSummaryRow(totalDosisProgramadas, totalDosisTomadas, totalDosisOmitidas, totalDosisNotificadas, totalDosisAplazadas, compliancePercentage),

                            const SizedBox(height: 24),



                            // 4. Gráfico Evolución de Adherencia

                            _buildEvolutionCard(todosLosTratamientos),

                            const SizedBox(height: 24),



                            // 4.5 Banner de mejora

                            _buildImprovementBanner(compliancePercentage, todosLosTratamientos),

                            const SizedBox(height: 24),



                            // 5. Desglose por tratamiento

                            _buildDesgloseSection(todosLosTratamientos, dateRange),

                            const SizedBox(height: 24),



                            // 6. Historial Reciente

                            _buildRecentHistorySection(recentHistory, todosLosTratamientos),

                            const SizedBox(height: 24),



                            // 7. Patrón de Omisiones

                            _buildOmissionsPatternCard(omissionsInfo, todosLosTratamientos),

                            const SizedBox(height: 24),

                          ],

                        );

                    },

                  ),

                ),

              ),

              ],

            ),

      

    );

  }



  Widget _buildIntervalSelector() {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(30),
        border: (context.watch<PreferenceNotifier>().showCardBorder || context.watch<PreferenceNotifier>().highContrast)
            ? Border.all(color: AppTheme.borderColor)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: ReportInterval.values.map((interval) {
          final isSelected = _selectedInterval == interval;
          String text = '';
          switch (interval) {
            case ReportInterval.semana:
              text = l10n?.intervalWeek ?? 'Semana';
              break;
            case ReportInterval.mes:
              text = l10n?.intervalMonth ?? 'Mes';
              break;
            case ReportInterval.anio:
              text = l10n?.intervalYear ?? 'Año';
              break;
            case ReportInterval.todo:
              text = l10n?.intervalAll ?? 'Todo';
              break;
          }

          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedInterval = interval;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.28),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      text,
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppTheme.secondaryTextColor,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        fontSize: 13.5,
                        letterSpacing: isSelected ? -0.2 : 0,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

    Widget _buildOverallAdherenceCard(double adherencia, int tomadas, int omitidas, int notificadas, int aplazadas) {

    final int total = tomadas + omitidas + notificadas + aplazadas;

    final hasData = total > 0;



    return Container(

      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(

        color: Theme.of(context).cardColor,

        borderRadius: BorderRadius.circular(24),

        boxShadow: AppTheme.cardShadow,

        border: (context.watch<PreferenceNotifier>().showCardBorder || context.watch<PreferenceNotifier>().highContrast)

            ? Border.all(color: AppTheme.borderColor)

            : null,

      ),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Text(

            "Tu adherencia general",

            style: TextStyle(

              fontSize: 16,

              color: AppTheme.primaryTextColor,

              fontWeight: FontWeight.bold,

            ),

          ),

          const SizedBox(height: 16),

          Row(

            children: [

              const Spacer(flex: 1),

              Stack(

                alignment: Alignment.center,

                children: [

                  SizedBox(

                    width: 105,

                    height: 105,

                    child: RepaintBoundary(

                      child: CustomPaint(

                        painter: MultiSegmentRingPainter(

                          tomadas: tomadas,

                          omitidas: omitidas,

                          notificadas: notificadas,

                          aplazadas: aplazadas,

                          trackColor: AppTheme.surfaceColor,

                        ),

                      ),

                    ),

                  ),

                  Column(

                    mainAxisSize: MainAxisSize.min,

                    children: [

                      Text(

                        hasData ? "${adherencia.round()}%" : "0%",

                        style: TextStyle(

                          color: AppTheme.primaryTextColor,

                          fontSize: 24,

                          fontWeight: FontWeight.bold,

                        ),

                      ),

                      Text(

                        "Adherencia",

                        style: TextStyle(

                          color: AppTheme.secondaryTextColor,

                          fontSize: 10,

                          fontWeight: FontWeight.bold,

                        ),

                      ),

                    ],

                  ),

                ],

              ),

              const Spacer(flex: 2),

              Column(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  _buildAdherenceLegendItem("Tomadas", tomadas, AppTheme.successColor),

                  const SizedBox(height: 8),

                  _buildAdherenceLegendItem("Omitidas", omitidas, AppTheme.errorColor),

                  const SizedBox(height: 8),

                  _buildAdherenceLegendItem("Notificadas", notificadas, const Color(0xFFFFB703)),

                  const SizedBox(height: 8),

                  _buildAdherenceLegendItem("Aplazadas", aplazadas, Colors.orange),

                ],

              ),

              const Spacer(flex: 2),

            ],

          ),

        ],

      ),

    );

  }



  Widget _buildAdherenceLegendItem(String label, int value, Color color) {

    return Column(

      crossAxisAlignment: CrossAxisAlignment.start,

      children: [

        Text(

          label,

          style: TextStyle(

            color: AppTheme.secondaryTextColor,

            fontSize: 14,

            fontWeight: FontWeight.w500,

          ),

        ),

        const SizedBox(height: 4),

        Row(

          children: [

            Container(

              width: 8,

              height: 8,

              decoration: BoxDecoration(

                shape: BoxShape.circle,

                color: color,

              ),

            ),

            const SizedBox(width: 8),

            Text(

              "$value",

              style: TextStyle(

                color: AppTheme.primaryTextColor,

                fontSize: 20,

                fontWeight: FontWeight.bold,

              ),

            ),

          ],

        ),

      ],

    );

  }



  Widget _buildSuggestionBanner(
    double adherence, {
    int totalProgramadas = 0,
    int totalOmitidas = 0,
    int totalAplazadas = 0,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final String title;
    final String message;
    final IconData icon;
    final Color accentColor;
    final Color bgColor;
    final Color borderColor;

    if (totalProgramadas == 0) {
      accentColor = AppTheme.primaryColor;
      title = "Sin tomas en este período";
      message = "No hay dosis programadas para el rango de fechas seleccionado.";
      icon = Icons.calendar_today_outlined;
      bgColor = isDark ? const Color(0xFF141923) : const Color(0xFFF1F5F9);
      borderColor = isDark ? const Color(0xFF283244) : const Color(0xFFCBD5E1);
    } else if (adherence >= 95) {
      accentColor = AppTheme.successColor;
      title = "Excelente adherencia";
      message = "Mantienes una constancia óptima en tus tomas. ¡Sigue así!";
      icon = Icons.check_circle_outline;
      bgColor = isDark ? const Color(0xFF0F231B) : const Color(0xFFECFDF5);
      borderColor = isDark ? const Color(0xFF1E4B39) : const Color(0xFFA7F3D0);
    } else if (adherence >= 80) {
      accentColor = AppTheme.primaryColor;
      title = "Buen progreso";
      message = "Vas por buen camino. Asocia tus tomas a hábitos diarios para no olvidar ninguna.";
      icon = Icons.trending_up;
      bgColor = isDark ? const Color(0xFF131D31) : const Color(0xFFEFF6FF);
      borderColor = isDark ? const Color(0xFF233B6E) : const Color(0xFFBFDBFE);
    } else if (adherence >= 60) {
      accentColor = const Color(0xFFF59E0B);
      title = "Atención con los horarios";
      message = totalAplazadas >= 3
          ? "Has aplazado varias dosis. Evalúa ajustar los horarios en tu receta."
          : "Activa recordatorios 15 minutos antes de cada toma para tener tu medicamento listo.";
      icon = Icons.lightbulb_outline;
      bgColor = isDark ? const Color(0xFF231B0E) : const Color(0xFFFFFBEB);
      borderColor = isDark ? const Color(0xFF4D3815) : const Color(0xFFFDE68A);
    } else if (adherence >= 40) {
      accentColor = const Color(0xFFF97316);
      title = "Dosis omitidas frecuentes";
      message = "Has omitido varias tomas. Sube el volumen de tus alarmas para no perder efectividad.";
      icon = Icons.warning_amber_rounded;
      bgColor = isDark ? const Color(0xFF26160F) : const Color(0xFFFFF7ED);
      borderColor = isDark ? const Color(0xFF542E1B) : const Color(0xFFFED7AA);
    } else {
      accentColor = AppTheme.errorColor;
      title = "Baja adherencia";
      message = "La mayoría de las dosis no se han registrado. Consulta a tu médico si tienes dificultades con el tratamiento.";
      icon = Icons.error_outline_rounded;
      bgColor = isDark ? const Color(0xFF261012) : const Color(0xFFFEF2F2);
      borderColor = isDark ? const Color(0xFF542025) : const Color(0xFFFECACA);
    }

    final isHighContrast = context.watch<PreferenceNotifier>().highContrast;
    final showBorder = context.watch<PreferenceNotifier>().showCardBorder;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: (showBorder || isHighContrast)
            ? Border.all(color: borderColor, width: isHighContrast ? 1.5 : 1.0)
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : accentColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.secondaryTextColor,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSummaryRow(int totales, int tomadas, int omitidas, int notificadas, int aplazadas, double adherencia) {

    final l10n = AppLocalizations.of(context);

    return Column(

      crossAxisAlignment: CrossAxisAlignment.start,

      children: [

        Text(

          l10n?.reportsQuickSummary ?? "Resumen rápido",

          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primaryTextColor),

        ),

        const SizedBox(height: 12),

        Row(

          children: [

            _buildQuickStatCard(

              icon: Icons.check_circle_outline,

              iconColor: AppTheme.successColor,

              iconBgColor: AppTheme.successColor.withValues(alpha: 0.08),

              value: tomadas.toString(),

              label: l10n?.reportsTakenDoses ?? "Tomadas",

            ),

            _buildQuickStatCard(

              icon: Icons.cancel_outlined,

              iconColor: AppTheme.errorColor,

              iconBgColor: AppTheme.errorColor.withValues(alpha: 0.08),

              value: omitidas.toString(),

              label: l10n?.reportsSkippedDoses ?? "Omitidas",

            ),

            _buildQuickStatCard(

              icon: Icons.notifications_outlined,

              iconColor: const Color(0xFFFFB703),

              iconBgColor: const Color(0xFFFFB703).withValues(alpha: 0.08),

              value: notificadas.toString(),

              label: l10n != null ? (Localizations.localeOf(context).languageCode == 'en' ? 'Notif.' : 'Notif.') : "Notif.",

            ),

            _buildQuickStatCard(

              icon: Icons.watch_later_outlined,

              iconColor: Colors.orange,

              iconBgColor: Colors.orange.withValues(alpha: 0.08),

              value: aplazadas.toString(),

              label: l10n != null ? (Localizations.localeOf(context).languageCode == 'en' ? 'Snoozed' : 'Aplaz.') : "Aplaz.",

            ),

            _buildQuickStatCard(

              icon: Icons.percent,

              iconColor: AppTheme.primaryColor,

              iconBgColor: AppTheme.primaryColor.withValues(alpha: 0.08),

              value: "${adherencia.toInt()}%",

              label: l10n != null ? (Localizations.localeOf(context).languageCode == 'en' ? 'Adher.' : 'Adher.') : "Adher.",

            ),

          ],

        ),

      ],

    );

  }



  Widget _buildQuickStatCard({

    required IconData icon,

    required Color iconColor,

    required Color iconBgColor,

    required String value,

    required String label,

  }) {

    return Expanded(

      child: Container(

        margin: const EdgeInsets.symmetric(horizontal: 3),

        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),

        decoration: BoxDecoration(

          color: Theme.of(context).cardColor,

          borderRadius: BorderRadius.circular(14),

          boxShadow: const [

            BoxShadow(

              color: Color(0x03000000),

              blurRadius: 10,

              offset: Offset(0, 4),

            )

          ],

          border: (context.watch<PreferenceNotifier>().showCardBorder || context.watch<PreferenceNotifier>().highContrast)

              ? Border.all(color: AppTheme.borderColor)

              : null,

        ),

        child: Column(

          children: [

            Container(

              padding: const EdgeInsets.all(6),

              decoration: BoxDecoration(color: iconBgColor, shape: BoxShape.circle),

              child: Icon(icon, color: iconColor, size: 16),

            ),

            const SizedBox(height: 6),

            Text(

              value,

              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryTextColor),

            ),

            const SizedBox(height: 2),

            Text(

              label,

              style: TextStyle(fontSize: 9.5, color: Colors.grey[500], fontWeight: FontWeight.w600),

              textAlign: TextAlign.center,

              maxLines: 1,

              overflow: TextOverflow.ellipsis,

            ),

          ],

        ),

      ),

    );

  }



  Widget _buildEvolutionCard(List<Tratamiento> tratamientos) {

    final l10n = AppLocalizations.of(context);

    final evolutionData = _getEvolutionData(tratamientos);

    final List<FlSpot> spots = evolutionData['spots'];

    final List<String> labels = evolutionData['labels'];



    final lineBar = LineChartBarData(

      spots: spots,

      isCurved: false, // Diseños angulosos en lugar de redondeados

      color: AppTheme.primaryColor,

      barWidth: 3.5,

      isStrokeCapRound: true,

      dotData: FlDotData(

        show: true,

        getDotPainter: (spot, percent, barData, index) {

          final isLast = index == spots.length - 1;

          return FlDotCirclePainter(

            radius: isLast ? 6 : 4.5,

            color: isLast ? Colors.white : AppTheme.primaryColor,

            strokeWidth: isLast ? 3 : 0,

            strokeColor: AppTheme.primaryColor,

          );

        },

      ),

      belowBarData: BarAreaData(

        show: true,

        gradient: LinearGradient(

          colors: [

            AppTheme.primaryColor.withValues(alpha: 0.18),

            AppTheme.primaryColor.withValues(alpha: 0.0),

          ],

          begin: Alignment.topCenter,

          end: Alignment.bottomCenter,

        ),

      ),

    );



    return Container(

      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor,

        borderRadius: BorderRadius.circular(20),

        boxShadow: const [

          BoxShadow(

            color: Color(0x05000000),

            blurRadius: 15,

            offset: Offset(0, 6),

          )

        ],

        border: (context.watch<PreferenceNotifier>().showCardBorder || context.watch<PreferenceNotifier>().highContrast)

            ? Border.all(color: AppTheme.borderColor)

            : null,

      ),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Row(

            mainAxisAlignment: MainAxisAlignment.spaceBetween,

            children: [

              Text(

                l10n?.reportsEvolutionTitle ?? "Evolución de adherencia",

                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primaryTextColor),

              ),

              TextButton(

                onPressed: () => _showEvolutionDetails(tratamientos),

                style: TextButton.styleFrom(minimumSize: Size.zero, padding: EdgeInsets.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),

                child: Text(

                  l10n?.reportsSeeMore ?? "Ver más",

                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryColor),

                ),

              ),

            ],

          ),

          const SizedBox(height: 24),

          SizedBox(

            height: 180,

            child: RepaintBoundary(

              child: LineChart(

                LineChartData(

                  gridData: FlGridData(

                    show: true,

                    drawVerticalLine: false,

                    getDrawingHorizontalLine: (value) {

                      return FlLine(

                        color: AppTheme.borderColor,

                        strokeWidth: 1,

                      );

                    },

                  ),

                  titlesData: FlTitlesData(

                    leftTitles: AxisTitles(

                      sideTitles: SideTitles(

                        showTitles: true,

                        reservedSize: 32,

                        getTitlesWidget: (value, meta) {

                          if (value % 25 != 0) return const SizedBox.shrink();

                          return Text(

                            '${value.toInt()}%',

                            style: TextStyle(color: Colors.grey[400], fontSize: 10, fontWeight: FontWeight.w500),

                          );

                        },

                      ),

                    ),

                    bottomTitles: AxisTitles(

                      sideTitles: SideTitles(

                        showTitles: true,

                        getTitlesWidget: (value, meta) {

                          final int idx = value.toInt();

                          if (idx >= 0 && idx < labels.length) {

                            return Padding(

                              padding: const EdgeInsets.only(top: 8.0),

                              child: Text(

                                labels[idx],

                                style: TextStyle(color: Colors.grey[500], fontSize: 10, fontWeight: FontWeight.bold),

                              ),

                            );

                          }

                          return const SizedBox.shrink();

                        },

                      ),

                    ),

                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),

                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),

                  ),

                  borderData: FlBorderData(show: false),

                  minY: 0,

                  maxY: 100,

                  lineBarsData: [lineBar],

                  showingTooltipIndicators: spots.isEmpty

                      ? []

                      : [

                          ShowingTooltipIndicators([

                            LineBarSpot(

                              lineBar,

                              0,

                              spots.last,

                            ),

                          ]),

                        ],

                  lineTouchData: LineTouchData(

                    enabled: true,

                    handleBuiltInTouches: true,

                    touchTooltipData: LineTouchTooltipData(

                      getTooltipColor: (_) => AppTheme.primaryColor,

                      tooltipRoundedRadius: 8,

                      tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),

                      getTooltipItems: (touchedSpots) {

                        return touchedSpots.map((spot) {

                          return LineTooltipItem(

                            '${spot.y.toInt()}%',

                            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),

                          );

                        }).toList();

                      },

                    ),

                  ),

                ),

              ),

            ),

          ),

        ],

      ),

    );

  }



  Widget _buildDesgloseSection(List<Tratamiento> tratamientos, Map<String, DateTime> dateRange) {

    final start = dateRange['start']!;

    final end = dateRange['end']!;



    // Filtrar tratamientos para mostrar solo los que tuvieron actividad o estuvieron activos en el rango de fechas seleccionado

    final tratamientosDelPeriodo = tratamientos.where((t) {

      final stats = _calcularEstadisticas(t, dateRange);

      if (stats['programadasPasadas']! > 0) return true;

      return !t.fechaFinTratamiento.isBefore(start) && !t.fechaInicioTratamiento.isAfter(end);

    }).toList();



    // Ordenar para mostrar primero los tratamientos con dosis en el período

    tratamientosDelPeriodo.sort((a, b) {

      final sa = _calcularEstadisticas(a, dateRange)['programadasPasadas']!;

      final sb = _calcularEstadisticas(b, dateRange)['programadasPasadas']!;

      return sb.compareTo(sa);

    });



    final l10n = AppLocalizations.of(context);



    if (tratamientosDelPeriodo.isEmpty) {

      return Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Text(

            l10n?.reportsBreakdownTitle ?? "Desglose por tratamiento",

            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primaryTextColor),

          ),

          const SizedBox(height: 12),

          Container(

            width: double.infinity,

            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),

            decoration: BoxDecoration(

              color: Theme.of(context).cardColor,

              borderRadius: BorderRadius.circular(16),

              border: Border.all(color: AppTheme.borderColor),

            ),

            child: Center(

              child: Text(

                l10n?.reportsNoTreatmentsInPeriod ?? "No hay tratamientos registrados en este período.",

                style: TextStyle(color: AppTheme.secondaryTextColor, fontSize: 13),

              ),

            ),

          ),

        ],

      );

    }



    final visibleTreatments = tratamientosDelPeriodo.take(5).toList();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n?.reportsBreakdownTitle ?? "Desglose por tratamiento",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primaryTextColor),
            ),
            if (tratamientosDelPeriodo.length > 5)
              TextButton(
                onPressed: () => _showFullTreatmentBreakdown(tratamientosDelPeriodo, dateRange),
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  "${l10n?.reportsSeeAll ?? "Ver todo"} (${tratamientosDelPeriodo.length})",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryColor),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ...visibleTreatments.map((t) => _buildTratamientoAccordionCard(t, dateRange)),
      ],
    );

  }



  Widget _buildTratamientoAccordionCard(Tratamiento tratamiento, Map<String, DateTime> dateRange) {
    final stats = _calcularEstadisticas(tratamiento, dateRange);
    final isExpanded = _expandedTreatments.contains(tratamiento.id);

    return TreatmentAccordionCard(
      tratamiento: tratamiento,
      stats: stats,
      isExpanded: isExpanded,
      onToggle: () {
        setState(() {
          if (isExpanded) {
            _expandedTreatments.remove(tratamiento.id);
          } else {
            _expandedTreatments.add(tratamiento.id);
          }
        });
      },
    );
  }

  Widget _buildRecentHistorySection(List<Map<String, dynamic>> recentHistory, List<Tratamiento> todosLosTratamientos) {

    final l10n = AppLocalizations.of(context);

    return Column(

      crossAxisAlignment: CrossAxisAlignment.start,

      children: [

        Row(

          mainAxisAlignment: MainAxisAlignment.spaceBetween,

          children: [

            Text(

              l10n?.reportsRecentHistoryTitle ?? "Historial reciente",

              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primaryTextColor),

            ),

            TextButton(

              onPressed: () => _showFullHistory(todosLosTratamientos),

              style: TextButton.styleFrom(minimumSize: Size.zero, padding: EdgeInsets.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),

              child: Text(

                l10n?.reportsSeeAll ?? "Ver todo",

                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryColor),

              ),

            ),

          ],

        ),

        const SizedBox(height: 12),

        if (recentHistory.isEmpty)

          Container(

            padding: const EdgeInsets.all(16),

            alignment: Alignment.center,

            child: Text(l10n?.reportsNoRecentRecords ?? "No hay registros recientes.", style: TextStyle(color: Colors.grey[400], fontSize: 13)),

          )

        else

          Container(

            decoration: BoxDecoration(color: Theme.of(context).cardColor,

              borderRadius: BorderRadius.circular(20),

              boxShadow: AppTheme.cardShadow,

              border: (context.watch<PreferenceNotifier>().showCardBorder || context.watch<PreferenceNotifier>().highContrast)

                  ? Border.all(color: AppTheme.borderColor)

                  : null,

            ),

            child: ListView.separated(

              shrinkWrap: true,

              physics: const NeverScrollableScrollPhysics(),

              itemCount: recentHistory.length,

              separatorBuilder: (context, index) => Divider(height: 1, color: AppTheme.borderColor),

              itemBuilder: (context, index) {

                final item = recentHistory[index];

                final date = item['time'] as DateTime;

                final status = item['status'] as DoseStatus;

                final t = item['treatment'] as Tratamiento;



                Color statusColor;

                IconData statusIcon;

                String statusText;



                switch (status) {

                  case DoseStatus.tomada:

                    statusColor = AppTheme.successColor;

                    statusIcon = Icons.check;

                    statusText = "Tomada";

                    break;

                  case DoseStatus.omitida:

                    statusColor = AppTheme.errorColor;

                    statusIcon = Icons.close;

                    statusText = "Omitida";

                    break;

                  case DoseStatus.notificada:

                    statusColor = Colors.amber;

                    statusIcon = Icons.notifications;

                    statusText = "Notificada";

                    break;

                  case DoseStatus.aplazada:

                    statusColor = Colors.orange;

                    statusIcon = Icons.schedule;

                    statusText = "Aplazada";

                    break;

                  case DoseStatus.pendiente:

                    statusColor = Colors.grey;

                    statusIcon = Icons.hourglass_empty;

                    statusText = "Pendiente";

                    break;

                }



                return ListTile(

                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),

                  leading: Container(

                    padding: const EdgeInsets.all(6),

                    decoration: BoxDecoration(

                      color: statusColor.withValues(alpha: 0.12),

                      shape: BoxShape.circle,

                    ),

                    child: Icon(

                      statusIcon,

                      color: statusColor,

                      size: 16,

                    ),

                  ),

                  title: Text(

                    t.nombreMedicamento,

                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryTextColor),

                  ),

                  subtitle: Text(

                    DateFormat('dd MMM, hh:mm a').format(date),

                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),

                  ),

                  trailing: Container(

                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),

                    decoration: BoxDecoration(

                      color: statusColor.withValues(alpha: 0.1),

                      borderRadius: BorderRadius.circular(20),

                    ),

                    child: Text(

                      statusText,

                      style: TextStyle(

                        fontSize: 11,

                        fontWeight: FontWeight.bold,

                        color: statusColor,

                      ),

                    ),

                  ),

                );

              },

            ),

          ),

      ],

    );

  }



  Widget _buildImprovementBanner(double compliancePercentage, List<Tratamiento> todosLosTratamientos) {

    final isDark = Theme.of(context).brightness == Brightness.dark;

    

    // Calculate previous period

    final range = _getDateRange();

    final start = range['start']!;

    final end = range['end']!;

    final duration = end.difference(start);

    

    DateTime prevStart;

    DateTime prevEnd;

    if (_selectedInterval == ReportInterval.todo) {

      prevStart = start.subtract(const Duration(days: 30));

      prevEnd = start;

    } else {

      prevStart = start.subtract(duration);

      prevEnd = start;

    }

    

    final prevRange = {'start': prevStart, 'end': prevEnd};

    int prevTotalDosisProgramadas = 0;

    int prevTotalDosisTomadas = 0;

    for (var tratamiento in todosLosTratamientos) {

      final stats = _calcularEstadisticas(tratamiento, prevRange);

      prevTotalDosisTomadas += stats['tomadas']!;

      prevTotalDosisProgramadas += stats['programadasPasadas']!;

    }

    

    final double prevCompliance = prevTotalDosisProgramadas > 0

        ? (prevTotalDosisTomadas / prevTotalDosisProgramadas) * 100

        : 0.0;

        

    // Calculate difference

    double diff = compliancePercentage - prevCompliance;

    

    // Only show banner if there is a real positive improvement

    if (diff <= 0 || prevTotalDosisProgramadas == 0) {

      return const SizedBox.shrink();

    }

    final int displayPercentage = diff.toInt();

    

    final bgColor = isDark ? const Color(0xFF16152B) : const Color(0xFFEEF2FF);

    final iconBgColor = const Color(0xFF4F46E5);

    final badgeBgColor = const Color(0xFF4F46E5).withValues(alpha: isDark ? 0.25 : 0.15);

    

    return Container(

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(

        color: bgColor,

        borderRadius: BorderRadius.circular(20),

        border: (context.watch<PreferenceNotifier>().showCardBorder || context.watch<PreferenceNotifier>().highContrast)

            ? Border.all(color: isDark ? const Color(0xFF2E2A5C) : const Color(0xFFE0E7FF), width: 1)

            : null,

      ),

      child: Row(

        children: [

          // Purple Star Icon

          Container(

            padding: const EdgeInsets.all(10),

            decoration: BoxDecoration(

              color: iconBgColor,

              borderRadius: BorderRadius.circular(14),

            ),

            child: const Icon(

              Icons.star_rounded,

              color: Colors.white,

              size: 22,

            ),

          ),

          const SizedBox(width: 14),

          // Texts

          Expanded(

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Text(

                  "¡Sigue mejorando!",

                  style: TextStyle(

                    fontSize: 14,

                    fontWeight: FontWeight.bold,

                    color: isDark ? Colors.white : const Color(0xFF312E81),

                  ),

                ),

                const SizedBox(height: 4),

                Text(

                  "Tu adherencia ha mejorado un $displayPercentage% respecto al período anterior.",

                  style: TextStyle(

                    fontSize: 12,

                    color: isDark ? const Color(0xFFC7D2FE) : const Color(0xFF4338CA),

                    height: 1.4,

                  ),

                ),

              ],

            ),

          ),

          const SizedBox(width: 10),

          // Badge

          Container(

            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),

            decoration: BoxDecoration(

              color: badgeBgColor,

              borderRadius: BorderRadius.circular(10),

            ),

            child: Row(

              mainAxisSize: MainAxisSize.min,

              children: [

                Icon(

                  Icons.trending_up_rounded,

                  color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),

                  size: 14,

                ),

                const SizedBox(width: 4),

                Text(

                  "$displayPercentage%",

                  style: TextStyle(

                    fontSize: 12,

                    fontWeight: FontWeight.bold,

                    color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),

                  ),

                ),

              ],

            ),

          ),

        ],

      ),

    );

  }



  Widget _buildOmissionsPatternCard(Map<String, String> info, List<Tratamiento> todosLosTratamientos) {

    final l10n = AppLocalizations.of(context);

    return Column(

      crossAxisAlignment: CrossAxisAlignment.start,

      children: [

        Row(

          mainAxisAlignment: MainAxisAlignment.spaceBetween,

          children: [

            Text(

              l10n?.reportsOmissionsPatternTitle ?? "Patrón de omisiones",

              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primaryTextColor),

            ),

            TextButton(

              onPressed: () => _showOmissionAnalysis(todosLosTratamientos),

              style: TextButton.styleFrom(minimumSize: Size.zero, padding: EdgeInsets.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),

              child: Text(

                l10n?.reportsSeeAnalysis ?? "Ver análisis",

                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryColor),

              ),

            ),

          ],

        ),

        const SizedBox(height: 12),

        Container(

          padding: const EdgeInsets.all(16),

          decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor,

            borderRadius: BorderRadius.circular(16),

            boxShadow: const [

              BoxShadow(

                color: Color(0x03000000),

                blurRadius: 10,

                offset: Offset(0, 4),

              )

            ],

            border: (context.watch<PreferenceNotifier>().showCardBorder || context.watch<PreferenceNotifier>().highContrast)

                ? Border.all(color: AppTheme.borderColor)

                : null,

          ),

          child: Row(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              Container(

                padding: const EdgeInsets.all(12),

                decoration: BoxDecoration(

                  color: AppTheme.errorColor.withValues(alpha: 0.08),

                  borderRadius: BorderRadius.circular(12),

                ),

                child: const Icon(

                  Icons.bar_chart,

                  color: AppTheme.errorColor,

                  size: 24,

                ),

              ),

              const SizedBox(width: 16),

              Expanded(

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    Text(

                      info['title']!,

                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryTextColor),

                    ),

                    const SizedBox(height: 4),

                    Text(

                      info['subtitle']!,

                      style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500),

                    ),

                    const SizedBox(height: 12),

                    Text(

                      info['recommendation']!,

                      style: TextStyle(fontSize: 12, color: AppTheme.secondaryTextColor, height: 1.4),

                    ),

                  ],

                ),

              ),

            ],

          ),

        ),

      ],

    );

  }



  

  // ─── Detalle de Evolución de Adherencia (Ver más) ─────────────────

  void _showEvolutionDetails(List<Tratamiento> tratamientos) {

    final evolutionData = _getEvolutionData(tratamientos);

    String intervalName = '';

    switch (_selectedInterval) {

      case ReportInterval.semana:

        intervalName = 'Esta Semana';

        break;

      case ReportInterval.mes:

        intervalName = 'Este Mes';

        break;

      case ReportInterval.anio:

        intervalName = 'Este Año';

        break;

      case ReportInterval.todo:

        intervalName = 'Histórico';

        break;

    }

    EvolutionDetailsSheet.show(

      context: context,

      tratamientos: tratamientos,

      evolutionData: evolutionData,

      intervalName: intervalName,

    );

  }



  // ─── Desglose completo de tratamientos (Ver todo) ─────────────────

  void _showFullTreatmentBreakdown(List<Tratamiento> tratamientos, Map<String, DateTime> dateRange) {

    FullTreatmentBreakdownSheet.show(

      context,

      tratamientos: tratamientos,

      dateRange: dateRange,

      statsCalculator: _calcularEstadisticas,

    );

  }



  // ─── Historial completo (Ver todo) ────────────────────────────────

  void _showFullHistory(List<Tratamiento> tratamientos) {

    FullHistorySheet.show(context, tratamientos);

  }



  // ─── Análisis de Patrón de Omisiones (Bottom Sheet) ───────────────

  void _showOmissionAnalysis(List<Tratamiento> tratamientos) {

    OmissionAnalysisSheet.show(context, tratamientos);

  }

}

