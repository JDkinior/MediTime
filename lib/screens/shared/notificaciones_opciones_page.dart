import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meditime/services/auth_service.dart';
import 'package:meditime/services/notification_service.dart';
import 'package:meditime/services/preference_service.dart';
import 'package:meditime/services/system_settings_service.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:meditime/screens/alarm/alarm_ringing_page.dart';
import 'package:meditime/screens/shared/guia_optimizacion_page.dart';

class NotificacionesOpcionesPage extends StatefulWidget {
  const NotificacionesOpcionesPage({super.key});

  @override
  State<NotificacionesOpcionesPage> createState() => _NotificacionesOpcionesPageState();
}

class _NotificacionesOpcionesPageState extends State<NotificacionesOpcionesPage> {
  bool _isRescheduling = false;
  final List<int> _snoozeOptions = [1, 5, 10, 15, 20, 30]; // Options in minutes
  bool _isIgnoringBattery = true;
  bool _canScheduleExact = true;

  @override
  void initState() {
    super.initState();
    _checkSystemSettings();
  }

  Future<void> _checkSystemSettings() async {
    try {
      final ignoring = await SystemSettingsService.isIgnoringBatteryOptimizations();
      final exact = await SystemSettingsService.canScheduleExactAlarms();
      if (mounted) {
        setState(() {
          _isIgnoringBattery = ignoring;
          _canScheduleExact = exact;
        });
      }
    } catch (_) {}
  }

  Future<void> _onReminderModeChanged(DoseReminderMode mode) async {
    setState(() {
      _isRescheduling = true;
    });

    final preferenceNotifier = context.read<PreferenceNotifier>();
    final authService = context.read<AuthService>();
    final user = authService.currentUser;

    await preferenceNotifier.setReminderMode(mode);

    if (user != null) {
      debugPrint("Preferencia de recordatorio cambiada a ${mode.name}. Reactivando alarmas...");
      await NotificationService.reactivateAlarmsForUser(user.uid);
      debugPrint("Alarmas reactivadas.");
    }

    if (mounted) {
      setState(() {
        _isRescheduling = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Modo de recordatorio actualizado.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _onSnoozeDurationChanged(int? newDuration) async {
    if (newDuration == null) return;
    
    final preferenceNotifier = context.read<PreferenceNotifier>();
    await preferenceNotifier.setSnoozeDuration(newDuration);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tiempo de aplazamiento guardado.'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showCustomSnoozeDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: Text(
            'Tiempo personalizado',
            style: TextStyle(color: AppTheme.primaryTextColor, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ingresa el tiempo de aplazamiento en minutos:',
                style: TextStyle(color: AppTheme.secondaryTextColor, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: TextStyle(color: AppTheme.primaryTextColor),
                decoration: InputDecoration(
                  hintText: 'Ej. 8',
                  hintStyle: TextStyle(color: AppTheme.secondaryTextColor.withOpacity(0.5)),
                  suffixText: 'min',
                  suffixStyle: TextStyle(color: AppTheme.secondaryTextColor),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.borderColor),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.primaryColor),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                final text = controller.text.trim();
                final val = int.tryParse(text);
                if (val != null && val > 0) {
                  Navigator.pop(dialogContext);
                  _onSnoozeDurationChanged(val);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Por favor ingresa un número de minutos válido (mayor a 0).'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  void _openAlarmTest(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AlarmRingingPage(
          userId: '',
          docId: '',
          doseTime: DateTime.now(),
          nombreMedicamento: 'Paracetamol 500mg',
          dosisPorToma: 1,
          presentacion: 'tableta',
          isTest: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preferenceNotifier = context.watch<PreferenceNotifier>();
    final currentMode = preferenceNotifier.reminderMode;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Notificaciones y Alarmas'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.primaryTextColor,
      ),
      body: _isRescheduling
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildOptionCardWrapper(
                  title: 'Gestión de tomas',
                  subtitle: 'Elige cómo quieres que suenen y actúen tus recordatorios de dosis.',
                  child: Column(
                    children: [
                      // 3 Tarjetas de modo de recordatorio
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildNotificationOptionCard(
                            mode: DoseReminderMode.automatic,
                            title: 'Automático',
                            subtitle: 'Toma marcada al sonar',
                            preview: _buildAutoModePreview(isSelected: currentMode == DoseReminderMode.automatic),
                          ),
                          const SizedBox(width: 8),
                          _buildNotificationOptionCard(
                            mode: DoseReminderMode.active,
                            title: 'Modo Activo',
                            subtitle: 'Notificación con botones',
                            preview: _buildActiveModePreview(isSelected: currentMode == DoseReminderMode.active),
                          ),
                          const SizedBox(width: 8),
                          _buildNotificationOptionCard(
                            mode: DoseReminderMode.alarm,
                            title: 'Modo Alarma',
                            subtitle: 'Alarma y pantalla completa',
                            preview: _buildAlarmModePreview(isSelected: currentMode == DoseReminderMode.alarm),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Tarjeta interactiva de prueba del Modo Alarma
                _buildOptionCardWrapper(
                  title: 'Simulación y Prueba',
                  subtitle: 'Comprueba el tono, vibración y la pantalla completa del Modo Alarma.',
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _openAlarmTest(context),
                      icon: const Icon(Icons.alarm_on_rounded, size: 20),
                      label: const Text(
                        'Probar Modo Alarma',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ),

                _buildListTileCard(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.snooze_outlined, color: AppTheme.primaryColor, size: 20),
                    ),
                    title: Text(
                      'Aplazamiento',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryTextColor,
                      ),
                    ),
                    subtitle: const Text('Duración de la alarma pospuesta'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.borderColor,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: Builder(
                          builder: (context) {
                            final currentSnooze = preferenceNotifier.snoozeDuration;
                            final List<int> displayOptions = List<int>.from(_snoozeOptions);
                            if (!displayOptions.contains(currentSnooze)) {
                              displayOptions.add(currentSnooze);
                              displayOptions.sort();
                            }
                            
                            final List<DropdownMenuItem<int>> dropdownItems = [];
                            for (var val in displayOptions) {
                              dropdownItems.add(
                                DropdownMenuItem<int>(
                                  value: val,
                                  child: Text('$val min'),
                                ),
                              );
                            }
                            dropdownItems.add(
                              const DropdownMenuItem<int>(
                                value: -1,
                                child: Text('Personalizado...'),
                              ),
                            );

                            return DropdownButton<int>(
                              value: currentSnooze,
                              dropdownColor: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(16),
                              style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.primaryColor),
                                items: dropdownItems,
                                onChanged: (int? newValue) {
                                  if (newValue == -1) {
                                    _showCustomSnoozeDialog(context);
                                  } else {
                                    _onSnoozeDurationChanged(newValue);
                                  }
                                },
                              );
                            }
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Tarjeta de Fiabilidad y Optimización de Batería
                  _buildOptionCardWrapper(
                    title: 'Fiabilidad de Alarmas y Batería',
                    subtitle: 'Asegura que tu teléfono no bloquee o silencie las alarmas en segundo plano.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: (_isIgnoringBattery && _canScheduleExact)
                                ? const Color(0xFF10B981).withOpacity(0.1)
                                : const Color(0xFFF59E0B).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: (_isIgnoringBattery && _canScheduleExact)
                                  ? const Color(0xFF10B981).withOpacity(0.3)
                                  : const Color(0xFFF59E0B).withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                (_isIgnoringBattery && _canScheduleExact)
                                    ? Icons.check_circle_rounded
                                    : Icons.warning_amber_rounded,
                                color: (_isIgnoringBattery && _canScheduleExact)
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFF59E0B),
                                size: 24,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  (_isIgnoringBattery && _canScheduleExact)
                                      ? 'Tu dispositivo está optimizado para hacer sonar alarmas a tiempo.'
                                      : 'Tu dispositivo podría retrasar o silenciar alarmas para ahorrar batería.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: (_isIgnoringBattery && _canScheduleExact)
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFF59E0B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const GuiaOptimizacionPage(),
                                ),
                              );
                              _checkSystemSettings();
                            },
                            icon: const Icon(Icons.settings_suggest_rounded, size: 18),
                            label: const Text(
                              'Abrir Guía de Optimización del Dispositivo',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryColor,
                              side: BorderSide(color: AppTheme.primaryColor),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Tarjeta de Privacidad en Pantalla de Bloqueo
                _buildListTileCard(
                  child: SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.shield_outlined, color: Colors.deepPurple, size: 20),
                    ),
                    title: Text(
                      'Privacidad en pantalla bloqueada',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryTextColor,
                      ),
                    ),
                    subtitle: Text(
                      'Oculta el nombre del fármaco en la pantalla de bloqueo para proteger tus datos médicos.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.secondaryTextColor,
                      ),
                    ),
                    value: preferenceNotifier.hideMedicineNameOnLockScreen,
                    activeColor: AppTheme.primaryColor,
                    onChanged: (bool value) async {
                      await preferenceNotifier.setHideMedicineNameOnLockScreen(value);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              value
                                  ? 'Nombre de medicamentos oculto en pantalla de bloqueo.'
                                  : 'Nombre de medicamentos visible en pantalla de bloqueo.',
                            ),
                            backgroundColor: AppTheme.primaryColor,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                ),
                ],
              ),
      );
    }

  Widget _buildOptionCardWrapper({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: (context.watch<PreferenceNotifier>().showCardBorder || context.watch<PreferenceNotifier>().highContrast)
            ? Border.all(color: AppTheme.borderColor)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryTextColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.secondaryTextColor,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildListTileCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: (context.watch<PreferenceNotifier>().showCardBorder || context.watch<PreferenceNotifier>().highContrast)
            ? Border.all(color: AppTheme.borderColor)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildOptionCardLayout({
    required Widget preview,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final cardBorderColor = isSelected
        ? AppTheme.primaryColor
        : AppTheme.borderColor;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor.withOpacity(0.05)
                : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: cardBorderColor,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                height: 44,
                child: Center(child: preview),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isSelected ? AppTheme.primaryColor : AppTheme.primaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.secondaryTextColor,
                  height: 1.15,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? AppTheme.primaryColor : Colors.grey.shade400,
                    width: isSelected ? 0 : 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 12,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationOptionCard({
    required DoseReminderMode mode,
    required String title,
    required String subtitle,
    required Widget preview,
  }) {
    final preferenceNotifier = context.watch<PreferenceNotifier>();
    final isSelected = preferenceNotifier.reminderMode == mode;
    return _buildOptionCardLayout(
      preview: preview,
      title: title,
      subtitle: subtitle,
      isSelected: isSelected,
      onTap: _isRescheduling ? () {} : () => _onReminderModeChanged(mode),
    );
  }

  Widget _buildActiveModePreview({required bool isSelected}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_active, size: 15, color: isSelected ? AppTheme.primaryColor : Colors.grey.shade500),
            const SizedBox(width: 3),
            Container(
              width: 26, 
              height: 4, 
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryColor.withOpacity(0.4) : Colors.grey.shade700.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 22,
              height: 8,
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryColor.withOpacity(0.2) : Colors.grey.shade700.withOpacity(0.2),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Center(child: Container(width: 10, height: 2, color: isSelected ? AppTheme.primaryColor : Colors.grey.shade500)),
            ),
            const SizedBox(width: 4),
            Container(
              width: 22,
              height: 8,
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryColor.withOpacity(0.2) : Colors.grey.shade700.withOpacity(0.2),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Center(child: Container(width: 10, height: 2, color: isSelected ? AppTheme.primaryColor : Colors.grey.shade500)),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildAutoModePreview({required bool isSelected}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 15, color: isSelected ? AppTheme.successColor : Colors.grey.shade500),
            const SizedBox(width: 4),
            Container(
              width: 26, 
              height: 4, 
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.successColor.withOpacity(0.4) : Colors.grey.shade700.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: 38, 
          height: 3, 
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.successColor.withOpacity(0.3) : Colors.grey.shade700.withOpacity(0.2),
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
      ],
    );
  }

  Widget _buildAlarmModePreview({required bool isSelected}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.alarm_on_rounded,
              size: 16,
              color: isSelected ? const Color(0xFFEF4444) : Colors.grey.shade500,
            ),
            const SizedBox(width: 3),
            Icon(
              Icons.graphic_eq_rounded,
              size: 14,
              color: isSelected ? AppTheme.primaryColor : Colors.grey.shade500,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: 38,
          height: 4,
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFEF4444).withOpacity(0.4)
                : Colors.grey.shade700.withOpacity(0.25),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}
