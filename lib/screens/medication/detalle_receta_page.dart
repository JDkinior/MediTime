// lib/screens/medication/detalle_receta_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meditime/core/utils.dart';
import 'package:meditime/l10n/generated/app_localizations.dart';
import 'package:meditime/models/caregiver_profile.dart';
import 'package:meditime/models/tratamiento.dart'; // <-- CAMBIO: Importar modelo
import 'package:meditime/models/treatment_form_data.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:meditime/widgets/treatment_form/treatment_summary_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:meditime/services/firestore_service.dart';
import 'package:meditime/services/notification_service.dart';
import 'package:meditime/services/preference_service.dart';
import 'package:meditime/widgets/modern_app_bar.dart';
import 'package:meditime/widgets/modern_content_fade.dart';

// CAMBIO: Convertimos a StatefulWidget para manejar el temporizador de la cuenta regresiva
class DetalleRecetaPage extends StatefulWidget {
  // CAMBIO: Recibimos el objeto Tratamiento y la hora específica de la dosis
  final Tratamiento tratamiento;
  final DateTime horaDosis;
  final CaregiverProfile? profile;

  const DetalleRecetaPage({
    super.key,
    required this.tratamiento,
    required this.horaDosis,
    this.profile,
  });

  @override
  State<DetalleRecetaPage> createState() => _DetalleRecetaPageState();
}

class _DetalleRecetaPageState extends State<DetalleRecetaPage> {
  Timer? _timer;
  late DateTime? _nextUpcomingDose;
  bool _isProcessing = false;
  DoseStatus? _currentStatus;

  @override
  void initState() {
    super.initState();
    _currentStatus = _getDoseStatus(widget.horaDosis);
    _nextUpcomingDose = _findNextUpcomingDose();

    if (_nextUpcomingDose != null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (DateTime.now().isAfter(_nextUpcomingDose!)) {
          setState(() {
            _nextUpcomingDose = _findNextUpcomingDose();
          });
        } else {
          setState(() {});
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _handleDoseAction(DoseStatus newStatus) async {
    if (_isProcessing) return;
    final userId =
        FirebaseAuth.instance.currentUser?.uid ??
        await PreferenceService().getCurrentUserId();
    if (userId == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final docId = widget.tratamiento.id;
      final doseTime = widget.horaDosis;
      final firestoreService = FirestoreService();

      final resolved = await firestoreService.resolveMedicamentoWithProfile(
        userId,
        docId,
        profile: widget.profile,
        profileId: widget.tratamiento.profileId,
      );
      final effectiveProfile = resolved?.profile ?? widget.profile;

      await firestoreService.updateDoseStatus(
        userId,
        docId,
        doseTime,
        newStatus,
        effectiveProfile,
      );

      if (mounted) {
        setState(() {
          _currentStatus = newStatus;
        });
      }

      if (newStatus == DoseStatus.aplazada) {
        final snoozeMinutes = await PreferenceService().getSnoozeDuration();
        final payload =
            'active_notification|$userId|$docId|${doseTime.toIso8601String()}|${effectiveProfile?.id ?? ""}';
        // Enviar id ficticio para aplazar
        await NotificationService.snoozeNotification(
          doseTime.hashCode.abs(), // Generar un ID único basado en la hora
          payload,
          doseTime,
          snoozeMinutes,
        );

        if (mounted) {
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                l10n?.doseSnoozedSuccess(snoozeMinutes) ??
                    'Dosis aplazada por $snoozeMinutes minutos',
              ),
            ),
          );
        }
      } else {
        // Reprogramar próxima dosis
        final docRef =
            resolved?.docRef ??
            firestoreService.getMedicamentoDocRef(
              userId,
              docId,
              effectiveProfile,
            );
        final docSnap = await docRef.get();
        if (docSnap.exists) {
          final freshTratamiento = Tratamiento.fromFirestore(
            docSnap as dynamic,
          );
          await NotificationService.rescheduleNextPendingDose(
            freshTratamiento,
            userId,
            effectiveProfile,
          );
        }
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Error actualizando dosis: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n?.doseDetailUpdateError ?? 'Error al actualizar la dosis',
            ),
          ),
        );
      }
    }
  }

  DateTime? _findNextUpcomingDose() {
    // CAMBIO: Lógica adaptada para usar el objeto Tratamiento
    final horaInicial = widget.tratamiento.horaPrimeraDosis;
    final intervalo = widget.tratamiento.intervaloDosis.inHours;
    final fechaFinTratamiento = widget.tratamiento.fechaFinTratamiento;
    final List<DateTime> dosisOmitidas = widget.tratamiento.skippedDoses;

    List<DateTime> dosisPotenciales = [];
    DateTime dosisActual = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      horaInicial.hour,
      horaInicial.minute,
    );

    while (dosisActual.isBefore(fechaFinTratamiento)) {
      if (dosisActual.isAfter(
        DateTime.now().subtract(const Duration(minutes: 1)),
      )) {
        dosisPotenciales.add(dosisActual);
      }
      dosisActual = dosisActual.add(Duration(hours: intervalo));
    }

    for (final dosis in dosisPotenciales) {
      bool esOmitida = dosisOmitidas.any(
        (skipped) => skipped.isAtSameMomentAs(dosis),
      );
      if (!esOmitida) {
        return dosis;
      }
    }
    return null;
  }

  // --- PASO 4: ACTUALIZAR LA LÓGICA DEL TIEMPO RESTANTE ---
  String _getTiempoRestante(DateTime proximaDosis, AppLocalizations? l10n) {
    final ahora = DateTime.now();
    final diferencia = proximaDosis.difference(ahora);

    if (diferencia.isNegative) {
      return l10n?.doseDetailTimeNow ?? 'Es momento de tomar la dosis';
    }

    // Si falta menos de un minuto, muestra los segundos
    if (diferencia.inMinutes < 1) {
      return l10n?.doseDetailInSeconds(diferencia.inSeconds) ??
          'En ${diferencia.inSeconds} segundos';
    }

    final dias = diferencia.inDays;
    final horas = diferencia.inHours % 24;
    final minutos = diferencia.inMinutes % 60;

    if (dias > 0) {
      return l10n?.doseDetailInDaysHours(dias, horas) ??
          'En $dias días y $horas horas';
    }
    if (horas > 0) {
      return l10n?.doseDetailInHoursMinutes(horas, minutos) ??
          'En $horas horas y $minutos minutos';
    }
    return l10n?.doseDetailInMinutes(minutos) ?? 'En $minutos minutos';
  }

  @override
  Widget build(BuildContext context) {
    final DateTime selectedDoseTime = widget.horaDosis;
    final formData = _convertToFormData();
    final l10n = AppLocalizations.of(context);
    final status = _getDoseStatus(selectedDoseTime);
    final isNotificada = status == DoseStatus.notificada;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      extendBody: isNotificada,
      appBar: ModernAppBar(
        child: AppBar(
          centerTitle: true,
          title: Text(
            AppUtils.capitalize(widget.tratamiento.nombreMedicamento),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          leading: Center(
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.chevron_left_rounded,
                  size: 26,
                  color: AppTheme.primaryTextColor,
                ),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          ModernContentFade(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 24.0,
                right: 24.0,
                top: 24.0,
                bottom: isNotificada ? 116.0 : 24.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSelectedDoseDisplay(selectedDoseTime, l10n),
                  const SizedBox(height: 24),
                  _buildNextDoseInfo(_nextUpcomingDose, selectedDoseTime, l10n),
                  const SizedBox(height: 22),
                  Divider(
                    height: 1,
                    color: AppTheme.borderColor.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 22),
                  TreatmentSummaryCard(
                    formData: formData,
                    summaryInfo: _getSummaryInfo(formData, context),
                  ),
                ],
              ),
            ),
          ),
          if (isNotificada)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 160,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        bgColor.withValues(alpha: 0.0),
                        bgColor.withValues(alpha: 0.35),
                        bgColor.withValues(alpha: 0.8),
                        bgColor.withValues(alpha: 0.98),
                      ],
                      stops: const [0.0, 0.35, 0.7, 1.0],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: isNotificada ? _buildFloatingActionBar(l10n) : null,
    );
  }

  // --- El resto de los widgets de construcción ---

  DoseStatus _getDoseStatus(DateTime doseTime) {
    if (_currentStatus != null &&
        doseTime.difference(widget.horaDosis).inMinutes.abs() <= 5) {
      return _currentStatus!;
    }

    // 1. Coincidencia directa por clave ISO
    final directStatus =
        widget.tratamiento.doseStatus[doseTime.toIso8601String()];
    if (directStatus != null) return directStatus;

    // 2. Coincidencia aproximada dentro de una tolerancia (30 min)
    for (final entry in widget.tratamiento.doseStatus.entries) {
      final dt = DateTime.tryParse(entry.key);
      if (dt != null && dt.difference(doseTime).inMinutes.abs() <= 30) {
        return entry.value;
      }
    }

    // 3. Revisar si está en dosis omitidas
    if (widget.tratamiento.skippedDoses.any(
      (d) => d.difference(doseTime).inMinutes.abs() <= 30,
    )) {
      return DoseStatus.omitida;
    }

    // 4. Si la hora ya pasó y no tiene interacción previa
    if (doseTime.isBefore(DateTime.now())) {
      return DoseStatus.notificada;
    }

    return DoseStatus.pendiente;
  }

  Color _getDoseColor(DoseStatus status, bool isPast) {
    switch (status) {
      case DoseStatus.tomada:
        return AppTheme.successColor;
      case DoseStatus.omitida:
        return AppTheme.errorColor;
      case DoseStatus.notificada:
        return const Color(0xFFF59E0B);
      case DoseStatus.aplazada:
        return Colors.orange;
      case DoseStatus.pendiente:
        return isPast ? const Color(0xFFF59E0B) : AppTheme.primaryColor;
    }
  }

  String _getDoseStatusText(
    DoseStatus status,
    bool isPast,
    AppLocalizations? l10n,
  ) {
    switch (status) {
      case DoseStatus.tomada:
        return l10n?.doseStatusTaken ?? 'Tomada';
      case DoseStatus.omitida:
        return l10n?.doseStatusSkipped ?? 'Omitida';
      case DoseStatus.notificada:
        return l10n?.doseStatusNotified ?? 'Notificada';
      case DoseStatus.aplazada:
        return l10n?.doseStatusSnoozed ?? 'Aplazada';
      case DoseStatus.pendiente:
        return isPast
            ? (l10n?.doseStatusNotified ?? 'Notificada')
            : (l10n?.doseStatusScheduled ?? 'Programada');
    }
  }

  IconData _getDoseStatusIcon(DoseStatus status, bool isPast) {
    switch (status) {
      case DoseStatus.tomada:
        return Icons.check_circle_outline;
      case DoseStatus.omitida:
        return Icons.cancel_outlined;
      case DoseStatus.notificada:
        return Icons.notifications;
      case DoseStatus.aplazada:
        return Icons.schedule;
      case DoseStatus.pendiente:
        return isPast ? Icons.notifications : Icons.alarm;
    }
  }

  Widget _buildSelectedDoseDisplay(DateTime doseTime, AppLocalizations? l10n) {
    final isPast = doseTime.isBefore(DateTime.now());
    final status = _getDoseStatus(doseTime);
    final statusColor = _getDoseColor(status, isPast);
    final statusText = _getDoseStatusText(status, isPast, l10n);
    final statusIcon = _getDoseStatusIcon(status, isPast);
    final localeStr = Localizations.localeOf(context).toString();

    final timeFormatted = AppUtils.formatDoseTime(doseTime);
    final timeParts = timeFormatted.split(' ');
    final timeDigits = timeParts[0];
    final timePeriod = timeParts.length > 1 ? timeParts[1] : '';

    final doseLabel = l10n?.doseDetailDoseTime ?? 'Dose time';

    return Column(
      children: [
        Text(
          doseLabel.toUpperCase(),
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.secondaryTextColor.withValues(alpha: 0.8),
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              timeDigits,
              style: TextStyle(
                fontSize: 54,
                fontWeight: FontWeight.bold,
                color: statusColor,
                letterSpacing: -0.5,
              ),
            ),
            if (timePeriod.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                timePeriod,
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          DateFormat('EEEE, d MMMM', localeStr).format(doseTime),
          style: TextStyle(
            fontSize: 16,
            color: AppTheme.secondaryTextColor,
            fontWeight: FontWeight.w300,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(statusIcon, color: statusColor, size: 16),
              const SizedBox(width: 6),
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingActionBar(AppLocalizations? l10n) {
    return SafeArea(
      bottom: true,
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 4),
        child: Row(
          children: [
            // Left: Snooze / Aplazar
            Expanded(
              flex: 3,
              child: _buildPillActionButton(
                icon: Icons.access_alarm_rounded,
                label: l10n?.actionSnooze ?? 'Aplazar',
                color: const Color(0xFFF59E0B),
                onTap:
                    _isProcessing
                        ? null
                        : () => _handleDoseAction(DoseStatus.aplazada),
              ),
            ),
            const SizedBox(width: 10),
            // Center: Take / Tomar (Hero action)
            Expanded(
              flex: 4,
              child: _buildPillActionButton(
                icon: Icons.check_rounded,
                label: l10n?.actionTake ?? 'Tomar',
                color: const Color(0xFF10B981),
                isHero: true,
                onTap:
                    _isProcessing
                        ? null
                        : () => _handleDoseAction(DoseStatus.tomada),
              ),
            ),
            const SizedBox(width: 10),
            // Right: Skip / Omitir
            Expanded(
              flex: 3,
              child: _buildPillActionButton(
                icon: Icons.close_rounded,
                label: l10n?.actionSkip ?? 'Omitir',
                color: const Color(0xFFEF4444),
                onTap:
                    _isProcessing
                        ? null
                        : () => _handleDoseAction(DoseStatus.omitida),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPillActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
    bool isHero = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: isHero ? 56 : 50,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(30),
            boxShadow:
                isHero
                    ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.38),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ]
                    : [
                      BoxShadow(
                        color: color.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
          ),
          child: Center(
            child:
                _isProcessing
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: Colors.white, size: isHero ? 20 : 18),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isHero ? 15 : 13.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
          ),
        ),
      ),
    );
  }

  Widget _buildNextDoseInfo(
    DateTime? nextDose,
    DateTime selectedDose,
    AppLocalizations? l10n,
  ) {
    if (nextDose == null) {
      return _buildStatusBannerCard(
        icon: Icons.check_circle_rounded,
        color: AppTheme.successColor,
        title:
            (l10n?.doseDetailTreatmentFinished ?? 'Tratamiento Finalizado')
                .toUpperCase(),
        subtitle:
            l10n?.doseDetailNoMoreDoses ?? 'No hay más dosis programadas.',
      );
    }

    if (nextDose.isAtSameMomentAs(selectedDose)) {
      return _buildStatusBannerCard(
        icon: Icons.notifications_active_rounded,
        color: AppTheme.primaryColor,
        title:
            (l10n?.doseDetailNextDosePrompt ?? 'Esta es la próxima dosis')
                .toUpperCase(),
        subtitle: _getTiempoRestante(nextDose, l10n),
      );
    }

    return _buildNextAlarmCard(nextDose: nextDose, l10n: l10n);
  }

  Widget _buildNextAlarmCard({
    required DateTime nextDose,
    required AppLocalizations? l10n,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final localeStr = Localizations.localeOf(context).toString();
    final title =
        (l10n?.doseDetailNextAlarm ?? 'Próxima Alarma')
            .replaceAll(':', '')
            .trim()
            .toUpperCase();
    final timeStr = DateFormat('hh:mm a, d MMM', localeStr).format(nextDose);
    final remainingStr = _getTiempoRestante(nextDose, l10n);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder:
                  (_) => DetalleRecetaPage(
                    tratamiento: widget.tratamiento,
                    horaDosis: nextDose,
                    profile: widget.profile,
                  ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF261D16) : const Color(0xFFFCF4ED),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              // Clock Icon without circle
              const Icon(
                Icons.access_time_rounded,
                color: Color(0xFFFE8A23),
                size: 32,
              ),
              const SizedBox(width: 14),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFE8A23),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 17.5,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      remainingStr,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF6D7A90),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBannerCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryTextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TreatmentFormData _convertToFormData() {
    // Calcular la duración real basada en las fechas de inicio y fin
    final fechaInicio = widget.tratamiento.fechaInicioTratamiento;
    final fechaFin = widget.tratamiento.fechaFinTratamiento;
    final duracionEnDias = fechaFin.difference(fechaInicio).inDays;

    // Determinar la mejor unidad y número para mostrar
    int duracionNumero;
    DurationUnit duracionUnidad;

    if (duracionEnDias >= 365) {
      // Si es más de un año, mostrar en años
      duracionNumero = (duracionEnDias / 365).round();
      duracionUnidad = DurationUnit.years;
    } else if (duracionEnDias >= 30) {
      // Si es más de un mes, mostrar en meses
      duracionNumero = (duracionEnDias / 30).round();
      duracionUnidad = DurationUnit.months;
    } else {
      // Mostrar en días
      duracionNumero = duracionEnDias;
      duracionUnidad = DurationUnit.days;
    }

    return TreatmentFormData(
      nombreMedicamento: widget.tratamiento.nombreMedicamento,
      presentacion: widget.tratamiento.presentacion,
      cantidadActual: widget.tratamiento.cantidadActual,
      cantidadTotalCaja: widget.tratamiento.cantidadTotalCaja,
      dosisPorToma: widget.tratamiento.dosisPorToma,
      horaPrimeraDosis: widget.tratamiento.horaPrimeraDosis,
      intervaloDosis: widget.tratamiento.intervaloDosis.inHours,
      duracionNumero: duracionNumero,
      duracionUnidad: duracionUnidad,
      esIndefinido: false, // Los tratamientos guardados no son indefinidos
      notas: widget.tratamiento.notas,
    );
  }

  Map<String, String> _getSummaryInfo(
    TreatmentFormData formData,
    BuildContext context,
  ) {
    final localeStr = Localizations.localeOf(context).toString();
    final DateFormat formatter = DateFormat.yMMMd(localeStr);
    final fechaFin = widget.tratamiento.fechaFinTratamiento;

    return {
      'durationText': formData.duracionText,
      'totalDoses': formData.totalDoses.toString(),
      'endDate': formatter.format(fechaFin),
      'Frecuencia': 'Cada ${widget.tratamiento.intervaloDosis.inHours} horas',
      'Duración': '${widget.tratamiento.duracion} días',
      'Finaliza el': formatter.format(fechaFin),
    };
  }
}
