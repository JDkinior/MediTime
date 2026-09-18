// lib/screens/medication/detalle_receta_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
    final userId = FirebaseAuth.instance.currentUser?.uid ??
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
            SnackBar(content: Text(l10n?.doseSnoozedSuccess(snoozeMinutes) ?? 'Dosis aplazada por $snoozeMinutes minutos')),
          );
        }
      } else {
        // Reprogramar próxima dosis
        final docRef = resolved?.docRef ??
            firestoreService.getMedicamentoDocRef(userId, docId, effectiveProfile);
        final docSnap = await docRef.get();
        if (docSnap.exists) {
          final freshTratamiento = Tratamiento.fromFirestore(docSnap as dynamic);
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
          SnackBar(content: Text(l10n?.doseDetailUpdateError ?? 'Error al actualizar la dosis')),
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

    if (diferencia.isNegative) return l10n?.doseDetailTimeNow ?? 'Es momento de tomar la dosis';

    // Si falta menos de un minuto, muestra los segundos
    if (diferencia.inMinutes < 1) {
      return l10n?.doseDetailInSeconds(diferencia.inSeconds) ?? 'En ${diferencia.inSeconds} segundos';
    }

    final dias = diferencia.inDays;
    final horas = diferencia.inHours % 24;
    final minutos = diferencia.inMinutes % 60;

    if (dias > 0) return l10n?.doseDetailInDaysHours(dias, horas) ?? 'En $dias días y $horas horas';
    if (horas > 0) return l10n?.doseDetailInHoursMinutes(horas, minutos) ?? 'En $horas horas y $minutos minutos';
    return l10n?.doseDetailInMinutes(minutos) ?? 'En $minutos minutos';
  }

  @override
  Widget build(BuildContext context) {
    final DateTime selectedDoseTime = widget.horaDosis;
    final formData = _convertToFormData();
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(widget.tratamiento.nombreMedicamento)),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSelectedDoseDisplay(selectedDoseTime, l10n),
              const SizedBox(height: 32),
              _buildNextDoseInfo(_nextUpcomingDose, selectedDoseTime, l10n),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 32),
              TreatmentSummaryCard(
                formData: formData,
                summaryInfo: _getSummaryInfo(formData, context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- El resto de los widgets de construcción ---

  DoseStatus _getDoseStatus(DateTime doseTime) {
    if (_currentStatus != null && doseTime.difference(widget.horaDosis).inMinutes.abs() <= 5) {
      return _currentStatus!;
    }

    // 1. Coincidencia directa por clave ISO
    final directStatus = widget.tratamiento.doseStatus[doseTime.toIso8601String()];
    if (directStatus != null) return directStatus;

    // 2. Coincidencia aproximada dentro de una tolerancia (30 min)
    for (final entry in widget.tratamiento.doseStatus.entries) {
      final dt = DateTime.tryParse(entry.key);
      if (dt != null && dt.difference(doseTime).inMinutes.abs() <= 30) {
        return entry.value;
      }
    }

    // 3. Revisar si está en dosis omitidas
    if (widget.tratamiento.skippedDoses.any((d) => d.difference(doseTime).inMinutes.abs() <= 30)) {
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
        return const Color(0xFFFFB703);
      case DoseStatus.aplazada:
        return Colors.orange;
      case DoseStatus.pendiente:
        return isPast ? const Color(0xFFFFB703) : AppTheme.primaryColor;
    }
  }

  String _getDoseStatusText(DoseStatus status, bool isPast, AppLocalizations? l10n) {
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
        return Icons.notifications_none;
      case DoseStatus.aplazada:
        return Icons.schedule;
      case DoseStatus.pendiente:
        return isPast ? Icons.notifications_none : Icons.alarm;
    }
  }

  Widget _buildSelectedDoseDisplay(DateTime doseTime, AppLocalizations? l10n) {
    final isPast = doseTime.isBefore(DateTime.now());
    final status = _getDoseStatus(doseTime);
    final statusColor = _getDoseColor(status, isPast);
    final statusText = _getDoseStatusText(status, isPast, l10n);
    final statusIcon = _getDoseStatusIcon(status, isPast);
    final localeStr = Localizations.localeOf(context).toString();

    return Column(
      children: [
        Text(
          l10n?.doseDetailDoseTime ?? 'Hora de esta toma',
          style: TextStyle(
            fontSize: 18,
            color: AppTheme.secondaryTextColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          DateFormat('hh:mm a', localeStr).format(doseTime),
          style: TextStyle(
            fontSize: 52,
            fontWeight: FontWeight.bold,
            color: statusColor,
          ),
        ),
        Text(
          DateFormat('EEEE, d MMMM', localeStr).format(doseTime),
          style: TextStyle(fontSize: 18, color: AppTheme.secondaryTextColor),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusColor.withValues(alpha: 0.3)),
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
        if (status == DoseStatus.notificada) ...[
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : () => _handleDoseAction(DoseStatus.tomada),
                  icon: const Icon(Icons.check, size: 18),
                  label: Text(l10n?.actionTake ?? 'Tomar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isProcessing ? null : () => _handleDoseAction(DoseStatus.aplazada),
                  icon: const Icon(Icons.snooze, size: 18),
                  label: Text(l10n?.actionSnooze ?? 'Aplazar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange.shade700,
                    side: BorderSide(color: Colors.orange.shade700),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextButton.icon(
                  onPressed: _isProcessing ? null : () => _handleDoseAction(DoseStatus.omitida),
                  icon: const Icon(Icons.close, size: 18),
                  label: Text(l10n?.actionSkip ?? 'Omitir'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.errorColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildNextDoseInfo(DateTime? nextDose, DateTime selectedDose, AppLocalizations? l10n) {
    if (nextDose == null) {
      return _buildInfoCard(
        icon: Icons.check_circle,
        color: AppTheme.successColor,
        title: l10n?.doseDetailTreatmentFinished ?? 'Tratamiento Finalizado',
        subtitle: l10n?.doseDetailNoMoreDoses ?? 'No hay más dosis programadas.',
      );
    }

    if (nextDose.isAtSameMomentAs(selectedDose)) {
      return _buildInfoCard(
        icon: Icons.notifications_active,
        color: AppTheme.primaryColor,
        title: l10n?.doseDetailNextDosePrompt ?? 'Esta es la próxima dosis',
        subtitle: _getTiempoRestante(nextDose, l10n),
      );
    }

    final localeStr = Localizations.localeOf(context).toString();
    return _buildInfoCard(
      icon: Icons.update,
      color: Colors.orange.shade700,
      title: l10n?.doseDetailNextAlarm ?? 'Próxima Alarma:',
      subtitle:
          '${DateFormat('hh:mm a, d MMM', localeStr).format(nextDose)}\n${_getTiempoRestante(nextDose, l10n)}',
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.primaryTextColor,
                    height: 1.4,
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

  Map<String, String> _getSummaryInfo(TreatmentFormData formData, BuildContext context) {
    final localeStr = Localizations.localeOf(context).toString();
    final DateFormat formatter = DateFormat.yMMMMd(localeStr);
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
