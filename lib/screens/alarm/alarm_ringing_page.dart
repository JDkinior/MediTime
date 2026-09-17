import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:meditime/services/firestore_service.dart';
import 'package:meditime/services/notification_service.dart';
import 'package:meditime/services/preference_service.dart';
import 'package:meditime/services/system_settings_service.dart';
import 'package:meditime/services/alarm_sound_service.dart';
import 'package:meditime/theme/app_theme.dart';

class AlarmRingingPage extends StatefulWidget {
  final String userId;
  final String docId;
  final DateTime doseTime;
  final String nombreMedicamento;
  final int dosisPorToma;
  final String presentacion;
  final String? pacienteNombre;
  final String? habitacion;
  final String? categoria;
  final int? notificationId;
  final bool isTest;

  const AlarmRingingPage({
    super.key,
    required this.userId,
    required this.docId,
    required this.doseTime,
    required this.nombreMedicamento,
    this.dosisPorToma = 1,
    this.presentacion = 'dosis',
    this.pacienteNombre,
    this.habitacion,
    this.categoria,
    this.notificationId,
    this.isTest = false,
  });

  @override
  State<AlarmRingingPage> createState() => _AlarmRingingPageState();
}

class _AlarmRingingPageState extends State<AlarmRingingPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _glowAnimation;

  Timer? _clockTimer;
  DateTime _now = DateTime.now();
  int _snoozeMinutes = 10;
  bool _isProcessing = false;
  bool _actionCompleted = false;

  @override
  void initState() {
    super.initState();
    
    // Activar visibilidad sobre la pantalla de bloqueo y encender pantalla
    SystemSettingsService.setLockScreenVisibility(true);

    // Asegurar que el tono de alarma y vibración continua estén activos (dual-redundancy)
    AlarmSoundService.startAlarm();
    
    // Cargar duración de aplazamiento configurada
    _loadSnoozeDuration();

    // Actualizar reloj cada segundo
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });

    // Control de animación de pulso y aura luminosa
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _glowAnimation = Tween<double>(begin: 0.25, end: 0.65).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _loadSnoozeDuration() async {
    try {
      final mins = await PreferenceService().getSnoozeDuration();
      if (mounted) {
        setState(() {
          _snoozeMinutes = mins;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    AlarmSoundService.stopAlarm();
    SystemSettingsService.setLockScreenVisibility(false);
    _clockTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _stopAlarmAndExit(Future<void> Function() onDone) async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
    });

    // Detener sonido de alarma inmediatamente en todos los componentes
    await AlarmSoundService.stopAlarm();

    if (widget.notificationId != null) {
      await NotificationService.cancelFlutterLocalNotificationById(
        widget.notificationId!,
      );
    }

    await onDone();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleTomar() async {
    setState(() {
      _actionCompleted = true;
    });

    await _stopAlarmAndExit(() async {
      if (!widget.isTest && widget.userId.isNotEmpty && widget.docId.isNotEmpty) {
        try {
          final firestoreService = FirestoreService();
          await firestoreService.updateDoseStatus(
            widget.userId,
            widget.docId,
            widget.doseTime,
            DoseStatus.tomada,
          );

          // Reprogramar siguiente dosis
          final docRef = firestoreService.getMedicamentoDocRef(
            widget.userId,
            widget.docId,
          );
          final docSnap = await docRef.get();
          if (docSnap.exists) {
            final tratamiento = Tratamiento.fromFirestore(
              docSnap as dynamic,
            );
            await NotificationService.rescheduleNextPendingDose(
              tratamiento,
              widget.userId,
            );
          }
        } catch (e) {
          debugPrint('Error al registrar dosis tomada: $e');
        }
      }
    });
  }

  Future<void> _handleAplazar() async {
    await _stopAlarmAndExit(() async {
      if (!widget.isTest && widget.userId.isNotEmpty && widget.docId.isNotEmpty) {
        try {
          final firestoreService = FirestoreService();
          await firestoreService.updateDoseStatus(
            widget.userId,
            widget.docId,
            widget.doseTime,
            DoseStatus.aplazada,
          );

          final payload =
              'active_notification|${widget.userId}|${widget.docId}|${widget.doseTime.toIso8601String()}';

          await NotificationService.snoozeNotification(
            widget.notificationId ?? 99999,
            payload,
            widget.doseTime,
            _snoozeMinutes,
          );
        } catch (e) {
          debugPrint('Error al aplazar alarma: $e');
        }
      }
    });
  }

  Future<void> _handleOmitir() async {
    await _stopAlarmAndExit(() async {
      if (!widget.isTest && widget.userId.isNotEmpty && widget.docId.isNotEmpty) {
        try {
          final firestoreService = FirestoreService();
          await firestoreService.updateDoseStatus(
            widget.userId,
            widget.docId,
            widget.doseTime,
            DoseStatus.omitida,
          );

          final docRef = firestoreService.getMedicamentoDocRef(
            widget.userId,
            widget.docId,
          );
          final docSnap = await docRef.get();
          if (docSnap.exists) {
            final tratamiento = Tratamiento.fromFirestore(
              docSnap as dynamic,
            );
            await NotificationService.rescheduleNextPendingDose(
              tratamiento,
              widget.userId,
            );
          }
        } catch (e) {
          debugPrint('Error al omitir dosis: $e');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final formattedTime = DateFormat('hh:mm').format(_now);
    final formattedPeriod = DateFormat('a').format(_now).toUpperCase();
    final formattedDate =
        DateFormat("EEEE, d 'de' MMMM", 'es_ES').format(_now);

    final bool hasPatient =
        widget.pacienteNombre != null && widget.pacienteNombre!.isNotEmpty;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF090D16),
        body: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.3),
              radius: 1.2,
              colors: [
                Color(0xFF132042),
                Color(0xFF090D16),
                Color(0xFF05070B),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  // Encabezado superior
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppTheme.primaryColor.withOpacity(0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.alarm_on_rounded,
                              color: Color(0xFF60A5FA),
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.isTest
                                  ? 'PRUEBA DE MODO ALARMA'
                                  : 'MEDITIME • HORA DE MEDICAMENTO',
                              style: const TextStyle(
                                color: Color(0xFF93C5FD),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const Spacer(flex: 1),

                  // Reloj digital grande
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            formattedTime,
                            style: const TextStyle(
                              fontSize: 68,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -2,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formattedPeriod,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF93C5FD),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        formattedDate[0].toUpperCase() +
                            formattedDate.substring(1),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.65),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  const Spacer(flex: 2),

                  // Avatar pulsante con ondas de sonido
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // Onda exterior
                          Container(
                            width: 170 * _pulseAnimation.value,
                            height: 170 * _pulseAnimation.value,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.primaryColor.withOpacity(
                                (1.0 - _glowAnimation.value) * 0.15,
                              ),
                            ),
                          ),
                          // Onda interior
                          Container(
                            width: 140 * _pulseAnimation.value,
                            height: 140 * _pulseAnimation.value,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.primaryColor.withOpacity(
                                (1.0 - _glowAnimation.value) * 0.28,
                              ),
                            ),
                          ),
                          // Círculo central con icono
                          Container(
                            width: 104,
                            height: 104,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF2563EB),
                                  Color(0xFF004AC6),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF2563EB).withOpacity(
                                    _glowAnimation.value,
                                  ),
                                  blurRadius: 30,
                                  spreadRadius: 6,
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.medication_rounded,
                                size: 52,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const Spacer(flex: 2),

                  // Tarjeta informativa del medicamento
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.12),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          widget.nombreMedicamento,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Dosis: ${widget.dosisPorToma} ${widget.presentacion}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF93C5FD),
                            ),
                          ),
                        ),
                        if (hasPatient) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.person_outline,
                                  size: 14,
                                  color: Color(0xFFCBD5E1),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${widget.pacienteNombre}${widget.habitacion != null && widget.habitacion!.isNotEmpty ? ' • Hab. ${widget.habitacion}' : ''}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFCBD5E1),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const Spacer(flex: 2),

                  // Botones de acción táctil
                  if (_actionCompleted)
                    const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF10B981),
                            size: 48,
                          ),
                          SizedBox(height: 8),
                          Text(
                            '¡Dosis registrada!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    // Botón principal: TOMAR
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _handleTomar,
                        icon: const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 24,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Tomar Dosis',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.4,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          elevation: 6,
                          shadowColor: const Color(0xFF10B981).withOpacity(0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Fila de botones secundarios: APLAZAR y OMITIR
                    Row(
                      children: [
                        // Botón Aplazar
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: _isProcessing ? null : _handleAplazar,
                              icon: const Icon(
                                Icons.snooze_rounded,
                                size: 18,
                                color: Color(0xFFFBBF24),
                              ),
                              label: Text(
                                'Aplazar ($_snoozeMinutes min)',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFFBBF24),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color:
                                      const Color(0xFFFBBF24).withOpacity(0.4),
                                  width: 1.2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                backgroundColor:
                                    const Color(0xFFFBBF24).withOpacity(0.08),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Botón Omitir
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: _isProcessing ? null : _handleOmitir,
                              icon: const Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: Color(0xFFF87171),
                              ),
                              label: const Text(
                                'Omitir',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFF87171),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color:
                                      const Color(0xFFF87171).withOpacity(0.4),
                                  width: 1.2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                backgroundColor:
                                    const Color(0xFFF87171).withOpacity(0.08),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const Spacer(flex: 1),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
