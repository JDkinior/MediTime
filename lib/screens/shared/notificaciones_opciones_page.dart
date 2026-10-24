import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meditime/services/auth_service.dart';
import 'package:meditime/services/notification_service.dart';
import 'package:meditime/services/preference_service.dart';
import 'package:meditime/services/system_settings_service.dart';
import 'package:meditime/services/alarm_sound_service.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:meditime/screens/alarm/alarm_ringing_page.dart';
import 'package:meditime/screens/shared/guia_optimizacion_page.dart';
import 'package:meditime/widgets/modern_app_bar.dart';
import 'package:meditime/widgets/modern_content_fade.dart';
import 'package:meditime/widgets/settings/settings_widgets.dart';

class NotificacionesOpcionesPage extends StatefulWidget {
  const NotificacionesOpcionesPage({super.key});

  @override
  State<NotificacionesOpcionesPage> createState() => _NotificacionesOpcionesPageState();
}

class _NotificacionesOpcionesPageState extends State<NotificacionesOpcionesPage>
    with WidgetsBindingObserver {
  bool _isRescheduling = false;
  final List<int> _snoozeOptions = [1, 5, 10, 15, 20, 30];
  bool _isIgnoringBattery = true;
  bool _canScheduleExact = true;
  bool _notificationsEnabled = true;
  bool _canUseFullScreen = true;
  String? _activePreviewId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkSystemSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AlarmSoundService.stopPreview();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkSystemSettings();
    }
  }

  Future<void> _checkSystemSettings() async {
    try {
      final ignoring = await SystemSettingsService.isIgnoringBatteryOptimizations();
      final exact = await SystemSettingsService.canScheduleExactAlarms();
      final notifs = await SystemSettingsService.areNotificationsEnabled();
      final fullScreen = await SystemSettingsService.canUseFullScreenIntent();
      if (mounted) {
        setState(() {
          _isIgnoringBattery = ignoring;
          _canScheduleExact = exact;
          _notificationsEnabled = notifs;
          _canUseFullScreen = fullScreen;
        });
      }
    } catch (_) {}
  }

  bool get _allSystemPermissionsOk =>
      _isIgnoringBattery && _canScheduleExact && _notificationsEnabled && _canUseFullScreen;

  Future<void> _togglePreview(
    String id, {
    String? uri,
    String? resourceName,
    String? soundType,
  }) async {
    if (_activePreviewId == id) {
      await AlarmSoundService.stopPreview();
      if (mounted) setState(() => _activePreviewId = null);
    } else {
      if (mounted) setState(() => _activePreviewId = id);
      await AlarmSoundService.playPreview(
        uri: uri,
        resourceName: resourceName,
        soundType: soundType,
      );
    }
  }

  void _openAlarmSoundModal(BuildContext context) {
    AlarmSoundService.stopPreview();
    setState(() => _activePreviewId = null);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _AlarmToneSelectorSheet(),
    );
  }

  Future<void> _onReminderModeChanged(DoseReminderMode mode) async {
    final preferenceNotifier = context.read<PreferenceNotifier>();
    if (preferenceNotifier.reminderMode == mode) return;

    setState(() {
      _isRescheduling = true;
    });

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
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('Modo de recordatorio actualizado.'),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 2),
          ),
        );
    }
  }

  Future<void> _onSnoozeDurationChanged(int? newDuration) async {
    if (newDuration == null) return;

    final preferenceNotifier = context.read<PreferenceNotifier>();
    await preferenceNotifier.setSnoozeDuration(newDuration);

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Tiempo de aplazamiento guardado ($newDuration min).'),
          backgroundColor: AppTheme.successColor,
          duration: const Duration(seconds: 2),
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
            style: TextStyle(
              color: AppTheme.primaryTextColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ingresa el tiempo de aplazamiento en minutos (1 a 120):',
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
                  hintStyle: TextStyle(
                    color: AppTheme.secondaryTextColor.withValues(alpha: 0.5),
                  ),
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
                if (val != null && val > 0 && val <= 120) {
                  Navigator.pop(dialogContext);
                  _onSnoozeDurationChanged(val);
                } else {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(
                        content: Text('Ingresa un número válido entre 1 y 120 minutos.'),
                        backgroundColor: AppTheme.errorColor,
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

  Future<void> _openAlarmTest(BuildContext context) async {
    await AlarmSoundService.stopPreview();
    if (mounted) {
      setState(() => _activePreviewId = null);
    }
    if (!context.mounted) return;
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

  String _getModeDetailedDescription(DoseReminderMode mode) {
    switch (mode) {
      case DoseReminderMode.alarm:
        return 'Modo Alarma (Recomendado): Suena en bucle continuo y enciende la pantalla completa como un despertador hasta que confirmes o aplaces la toma.';
      case DoseReminderMode.active:
        return 'Modo Activo: Muestra una notificación interactiva con sonido y botones rápidos para marcar la toma como Tomada, Omitida o Aplazada.';
      case DoseReminderMode.automatic:
        return 'Modo Informativo: Envía un aviso discreto a la hora programada y registra la toma automáticamente en tu agenda.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferenceNotifier = context.watch<PreferenceNotifier>();
    final currentMode = preferenceNotifier.reminderMode;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: ModernAppBar(
        child: AppBar(
          title: const Text('Notificaciones y Alarmas'),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: AppTheme.primaryTextColor,
        ),
      ),
      body: _isRescheduling
          ? const Center(child: CircularProgressIndicator())
          : ModernContentFade(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  const SettingsSectionHeader(
                    title: 'Modo de Recordatorio',
                    topPadding: 0,
                  ),

                  SettingsCardWrapper(
                    title: 'Gestión de tomas',
                    subtitle: 'Selecciona entre aviso discreto, notificación interactiva o despertador.',
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SettingsVisualOptionCard(
                              title: 'Informativo',
                              subtitle: 'Toma automática',
                              preview: _buildAutoModePreview(
                                isSelected: currentMode == DoseReminderMode.automatic,
                              ),
                              isSelected: currentMode == DoseReminderMode.automatic,
                              selectedColor: AppTheme.successColor,
                              onTap: _isRescheduling
                                  ? () {}
                                  : () => _onReminderModeChanged(DoseReminderMode.automatic),
                            ),
                            const SizedBox(width: 8),
                            SettingsVisualOptionCard(
                              title: 'Modo Activo',
                              subtitle: 'Con botones',
                              preview: _buildActiveModePreview(
                                isSelected: currentMode == DoseReminderMode.active,
                              ),
                              isSelected: currentMode == DoseReminderMode.active,
                              selectedColor: AppTheme.primaryColor,
                              onTap: _isRescheduling
                                  ? () {}
                                  : () => _onReminderModeChanged(DoseReminderMode.active),
                            ),
                            const SizedBox(width: 8),
                            SettingsVisualOptionCard(
                              title: 'Modo Alarma',
                              subtitle: 'Pantalla completa',
                              preview: _buildAlarmModePreview(
                                isSelected: currentMode == DoseReminderMode.alarm,
                              ),
                              isSelected: currentMode == DoseReminderMode.alarm,
                              selectedColor: AppTheme.errorColor,
                              onTap: _isRescheduling
                                  ? () {}
                                  : () => _onReminderModeChanged(DoseReminderMode.alarm),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.borderColor.withValues(alpha: 0.7),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                currentMode == DoseReminderMode.alarm
                                    ? Icons.alarm_on_rounded
                                    : (currentMode == DoseReminderMode.active
                                        ? Icons.notifications_active_outlined
                                        : Icons.info_outline_rounded),
                                size: 18,
                                color: currentMode == DoseReminderMode.alarm
                                    ? AppTheme.errorColor
                                    : AppTheme.primaryColor,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _getModeDetailedDescription(currentMode),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.secondaryTextColor,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SettingsSectionHeader(
                    title: 'Sonido, Aplazamiento y Prueba',
                    topPadding: 8,
                  ),

                  _buildAlarmSoundCard(context, preferenceNotifier),

                  _buildSnoozeCard(context, preferenceNotifier),

                  SettingsCardWrapper(
                    title: 'Simulación en Vivo',
                    subtitle:
                        'Comprueba cómo se verá y sonará la pantalla completa del Modo Alarma en tu teléfono.',
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _openAlarmTest(context),
                        icon: const Icon(Icons.alarm_on_rounded, size: 20),
                        label: const Text(
                          'Probar Modo Alarma Ahora',
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

                  const SettingsSectionHeader(
                    title: 'Fiabilidad del Sistema y Privacidad',
                    topPadding: 8,
                  ),

                  SettingsCardWrapper(
                    title: 'Fiabilidad de Alarmas y Batería',
                    subtitle:
                        'Verifica que Android autorice a MediTime a sonar puntualmente en segundo plano.',
                    trailingHeader: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _allSystemPermissionsOk
                            ? AppTheme.successColor.withValues(alpha: 0.12)
                            : Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _allSystemPermissionsOk ? 'Óptimo' : 'Revisar',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _allSystemPermissionsOk
                              ? AppTheme.successColor
                              : Colors.amber.shade800,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _allSystemPermissionsOk
                                ? const Color(0xFF10B981).withValues(alpha: 0.1)
                                : const Color(0xFFF59E0B).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _allSystemPermissionsOk
                                  ? const Color(0xFF10B981).withValues(alpha: 0.3)
                                  : const Color(0xFFF59E0B).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _allSystemPermissionsOk
                                    ? Icons.check_circle_rounded
                                    : Icons.warning_amber_rounded,
                                color: _allSystemPermissionsOk
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFF59E0B),
                                size: 24,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _allSystemPermissionsOk
                                      ? 'Batería, notificaciones y alarmas exactas están correctamente autorizadas.'
                                      : 'Faltan permisos clave o el ahorro de batería está activo, lo que podría retrasar o silenciar alarmas.',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: _allSystemPermissionsOk
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFF59E0B),
                                    height: 1.3,
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

                  SettingsSwitchTileCard(
                    title: 'Ocultar fármaco en pantalla bloqueada',
                    description:
                        'Oculta el nombre específico del medicamento en las notificaciones mientras el teléfono está bloqueado.',
                    value: preferenceNotifier.hideMedicineNameOnLockScreen,
                    icon: Icons.visibility_off_outlined,
                    activeColor: Colors.deepPurple,
                    onChanged: (bool value) async {
                      await preferenceNotifier.setHideMedicineNameOnLockScreen(value);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
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
                ],
              ),
            ),
    );
  }

  Widget _buildSnoozeCard(BuildContext context, PreferenceNotifier preferenceNotifier) {
    final currentSnooze = preferenceNotifier.snoozeDuration;
    final List<int> displayOptions = List<int>.from(_snoozeOptions);
    if (!displayOptions.contains(currentSnooze)) {
      displayOptions.add(currentSnooze);
      displayOptions.sort();
    }

    final List<DropdownMenuItem<int>> dropdownItems = [
      for (final val in displayOptions)
        DropdownMenuItem<int>(
          value: val,
          child: Text('$val min'),
        ),
      const DropdownMenuItem<int>(
        value: -1,
        child: Text('Personalizado...'),
      ),
    ];

    return SettingsActionTileCard(
      title: 'Tiempo de aplazamiento',
      subtitle: 'Minutos que esperará la alarma al pulsar "Posponer".',
      icon: Icons.snooze_rounded,
      iconColor: AppTheme.primaryColor,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: currentSnooze,
            dropdownColor: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            style: TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 13.5,
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
          ),
        ),
      ),
    );
  }

  Widget _buildActiveModePreview({required bool isSelected}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_active,
              size: 15,
              color: isSelected ? AppTheme.primaryColor : Colors.grey.shade500,
            ),
            const SizedBox(width: 3),
            Container(
              width: 26,
              height: 4,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor.withValues(alpha: 0.4)
                    : Colors.grey.shade700.withValues(alpha: 0.3),
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
                color: isSelected
                    ? AppTheme.primaryColor.withValues(alpha: 0.2)
                    : Colors.grey.shade700.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Center(
                child: Container(
                  width: 10,
                  height: 2,
                  color: isSelected ? AppTheme.primaryColor : Colors.grey.shade500,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 22,
              height: 8,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor.withValues(alpha: 0.2)
                    : Colors.grey.shade700.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Center(
                child: Container(
                  width: 10,
                  height: 2,
                  color: isSelected ? AppTheme.primaryColor : Colors.grey.shade500,
                ),
              ),
            ),
          ],
        ),
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
            Icon(
              Icons.check_circle,
              size: 15,
              color: isSelected ? AppTheme.successColor : Colors.grey.shade500,
            ),
            const SizedBox(width: 4),
            Container(
              width: 26,
              height: 4,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.successColor.withValues(alpha: 0.4)
                    : Colors.grey.shade700.withValues(alpha: 0.3),
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
            color: isSelected
                ? AppTheme.successColor.withValues(alpha: 0.3)
                : Colors.grey.shade700.withValues(alpha: 0.2),
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
              color: isSelected ? AppTheme.errorColor : Colors.grey.shade500,
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
                ? AppTheme.errorColor.withValues(alpha: 0.4)
                : Colors.grey.shade700.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }

  Widget _buildAlarmSoundCard(
    BuildContext context,
    PreferenceNotifier preferenceNotifier,
  ) {
    final soundTitle = preferenceNotifier.alarmSoundTitle;
    final soundType = preferenceNotifier.alarmSoundType;
    final soundUri = preferenceNotifier.alarmSoundUri;
    final soundResource = preferenceNotifier.alarmSoundResource;

    final isCustom = soundType == 'custom';
    final isPreviewPlaying = _activePreviewId == 'current_selected_tone';

    return SettingsCardWrapper(
      title: 'Tono y Sonido de Alarma',
      subtitle:
          'Configura el sonido del Modo Alarma con tonos de tu teléfono o personalizados de MediTime.',
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openAlarmSoundModal(context),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.borderColor.withValues(alpha: 0.7),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isCustom ? Icons.music_note_rounded : Icons.ring_volume_rounded,
                        color: AppTheme.primaryColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            soundTitle,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryTextColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isCustom
                                      ? Colors.indigo.withValues(alpha: 0.12)
                                      : Colors.teal.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isCustom ? 'Personalizado MediTime' : 'Tono del Teléfono',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isCustom ? Colors.indigo : Colors.teal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: isPreviewPlaying ? 'Detener vista previa' : 'Escuchar tono',
                      icon: Icon(
                        isPreviewPlaying
                            ? Icons.stop_circle_rounded
                            : Icons.play_circle_fill_rounded,
                        color: AppTheme.primaryColor,
                        size: 34,
                      ),
                      onPressed: () {
                        _togglePreview(
                          'current_selected_tone',
                          uri: soundUri,
                          resourceName: soundResource,
                          soundType: soundType,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openAlarmSoundModal(context),
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: const Text(
                'Cambiar Tono de Alarma',
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
    );
  }
}

/// Hoja modal inferior para seleccionar y escuchar tonos de alarma.
class _AlarmToneSelectorSheet extends StatefulWidget {
  const _AlarmToneSelectorSheet();

  @override
  State<_AlarmToneSelectorSheet> createState() => _AlarmToneSelectorSheetState();
}

class _AlarmToneSelectorSheetState extends State<_AlarmToneSelectorSheet> {
  int _tabIndex = 0; // 0: Personalizados MediTime, 1: Tonos del teléfono
  String? _previewId;
  List<Map<String, String>> _phoneRingtones = [];
  bool _loadingPhoneRingtones = true;

  @override
  void initState() {
    super.initState();
    _loadPhoneRingtones();
  }

  @override
  void dispose() {
    AlarmSoundService.stopPreview();
    super.dispose();
  }

  Future<void> _loadPhoneRingtones() async {
    try {
      final list = await AlarmSoundService.getRingtones();
      if (mounted) {
        setState(() {
          _phoneRingtones = list;
          _loadingPhoneRingtones = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingPhoneRingtones = false;
        });
      }
    }
  }

  Future<void> _togglePreview(
    String id, {
    String? uri,
    String? resourceName,
    String? soundType,
  }) async {
    if (_previewId == id) {
      await AlarmSoundService.stopPreview();
      if (mounted) setState(() => _previewId = null);
    } else {
      if (mounted) setState(() => _previewId = id);
      await AlarmSoundService.playPreview(
        uri: uri,
        resourceName: resourceName,
        soundType: soundType,
      );
    }
  }

  Future<void> _selectTone({
    required String type,
    required String title,
    String? uri,
    String? resourceName,
  }) async {
    final notifier = context.read<PreferenceNotifier>();
    await notifier.setAlarmSound(
      type: type,
      title: title,
      uri: uri,
      resourceName: resourceName,
    );

    _togglePreview(
      type == 'custom' ? (resourceName ?? type) : (uri ?? type),
      uri: uri,
      resourceName: resourceName,
      soundType: type,
    );
  }

  Future<void> _openSystemPicker() async {
    final notifier = context.read<PreferenceNotifier>();
    final result = await AlarmSoundService.openRingtonePicker(
      currentUri: notifier.alarmSoundUri,
    );
    if (result != null && mounted) {
      final title = result['title'] ?? 'Tono del teléfono';
      final uri = result['uri'] ?? '';
      await notifier.setAlarmSound(
        type: 'phone_tone',
        title: title,
        uri: uri,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Tono de alarma seleccionado: $title'),
              backgroundColor: AppTheme.primaryColor,
              duration: const Duration(seconds: 2),
            ),
          );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferenceNotifier = context.watch<PreferenceNotifier>();
    final currentSoundType = preferenceNotifier.alarmSoundType;
    final currentResource = preferenceNotifier.alarmSoundResource;
    final currentUri = preferenceNotifier.alarmSoundUri;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = Theme.of(context).cardColor;

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: preferenceNotifier.showCardBorder || preferenceNotifier.highContrast
            ? Border.all(color: AppTheme.borderColor)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.82,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tono de Alarma',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Elige cómo sonará tu teléfono en el Modo Alarma',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        AlarmSoundService.stopPreview();
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppTheme.borderColor.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            AlarmSoundService.stopPreview();
                            setState(() {
                              _tabIndex = 0;
                              _previewId = null;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _tabIndex == 0
                                  ? AppTheme.primaryColor
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 16,
                                  color: _tabIndex == 0
                                      ? Colors.white
                                      : AppTheme.secondaryTextColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Personalizados (4)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _tabIndex == 0
                                        ? Colors.white
                                        : AppTheme.secondaryTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            AlarmSoundService.stopPreview();
                            setState(() {
                              _tabIndex = 1;
                              _previewId = null;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _tabIndex == 1
                                  ? AppTheme.primaryColor
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.phone_android_rounded,
                                  size: 16,
                                  color: _tabIndex == 1
                                      ? Colors.white
                                      : AppTheme.secondaryTextColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Del Teléfono',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _tabIndex == 1
                                        ? Colors.white
                                        : AppTheme.secondaryTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Flexible(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  children: _tabIndex == 0
                      ? _buildCustomTonesList(
                          currentSoundType: currentSoundType,
                          currentResource: currentResource,
                        )
                      : _buildPhoneTonesList(
                          currentSoundType: currentSoundType,
                          currentUri: currentUri,
                        ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      AlarmSoundService.stopPreview();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Listo',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCustomTonesList({
    required String currentSoundType,
    required String? currentResource,
  }) {
    return AlarmSoundOption.customTones.map((tone) {
      final isSelected =
          currentSoundType == 'custom' && currentResource == tone.resourceName;
      final isPlaying = _previewId == tone.resourceName;

      return _buildToneItemTile(
        title: tone.title,
        subtitle: tone.subtitle,
        badgeText: 'MediTime',
        badgeColor: Colors.indigo,
        icon: Icons.music_note_rounded,
        isSelected: isSelected,
        isPlaying: isPlaying,
        onTap: () {
          _selectTone(
            type: 'custom',
            title: tone.title,
            resourceName: tone.resourceName,
          );
        },
        onPlayToggle: () {
          _togglePreview(
            tone.resourceName!,
            resourceName: tone.resourceName,
            soundType: 'custom',
          );
        },
      );
    }).toList();
  }

  List<Widget> _buildPhoneTonesList({
    required String currentSoundType,
    required String? currentUri,
  }) {
    final List<Widget> items = [];

    final isAlarmDefaultSelected = currentSoundType == 'system_alarm';
    final isAlarmDefaultPlaying = _previewId == 'system_alarm';
    items.add(
      _buildToneItemTile(
        title: 'Alarma del teléfono (Predeterminada)',
        subtitle: 'Tono oficial de la alarma de tu reloj del sistema',
        badgeText: 'Sistema',
        badgeColor: Colors.teal,
        icon: Icons.alarm_rounded,
        isSelected: isAlarmDefaultSelected,
        isPlaying: isAlarmDefaultPlaying,
        onTap: () {
          _selectTone(
            type: 'system_alarm',
            title: 'Alarma del teléfono (Predeterminada)',
            uri: 'content://settings/system/alarm_alert',
          );
        },
        onPlayToggle: () {
          _togglePreview(
            'system_alarm',
            uri: 'content://settings/system/alarm_alert',
            soundType: 'system_alarm',
          );
        },
      ),
    );

    final isRingtoneDefaultSelected = currentSoundType == 'system_ringtone';
    final isRingtoneDefaultPlaying = _previewId == 'system_ringtone';
    items.add(
      _buildToneItemTile(
        title: 'Tono de llamada del teléfono',
        subtitle: 'Tono asignado a las llamadas entrantes',
        badgeText: 'Sistema',
        badgeColor: Colors.teal,
        icon: Icons.ring_volume_rounded,
        isSelected: isRingtoneDefaultSelected,
        isPlaying: isRingtoneDefaultPlaying,
        onTap: () {
          _selectTone(
            type: 'system_ringtone',
            title: 'Tono de llamada del teléfono',
            uri: 'content://settings/system/ringtone',
          );
        },
        onPlayToggle: () {
          _togglePreview(
            'system_ringtone',
            uri: 'content://settings/system/ringtone',
            soundType: 'system_ringtone',
          );
        },
      ),
    );

    items.add(
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: InkWell(
          onTap: _openSystemPicker,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.folder_open_rounded,
                  color: AppTheme.primaryColor,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Elegir en selector del teléfono...',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Explora todos los tonos y sonidos almacenados en tu dispositivo',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppTheme.primaryColor,
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (_loadingPhoneRingtones) {
      items.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ),
        ),
      );
    } else if (_phoneRingtones.isNotEmpty) {
      items.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 6),
          child: Text(
            'TONOS DETECTADOS EN TU DISPOSITIVO',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: AppTheme.secondaryTextColor,
            ),
          ),
        ),
      );

      for (var r in _phoneRingtones) {
        final title = r['title'] ?? 'Tono del sistema';
        final uri = r['uri'] ?? '';
        final isSelected = currentSoundType == 'phone_tone' && currentUri == uri;
        final isPlaying = _previewId == uri;

        items.add(
          _buildToneItemTile(
            title: title,
            subtitle: 'Tono instalado en el teléfono',
            badgeText: 'Dispositivo',
            badgeColor: Colors.blueGrey,
            icon: Icons.audiotrack_rounded,
            isSelected: isSelected,
            isPlaying: isPlaying,
            onTap: () {
              _selectTone(
                type: 'phone_tone',
                title: title,
                uri: uri,
              );
            },
            onPlayToggle: () {
              _togglePreview(
                uri,
                uri: uri,
                soundType: 'phone_tone',
              );
            },
          ),
        );
      }
    }

    return items;
  }

  Widget _buildToneItemTile({
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
    required IconData icon,
    required bool isSelected,
    required bool isPlaying,
    required VoidCallback onTap,
    required VoidCallback onPlayToggle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? AppTheme.primaryColor.withValues(alpha: 0.06)
            : AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? AppTheme.primaryColor
              : AppTheme.borderColor.withValues(alpha: 0.6),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor.withValues(alpha: 0.15)
                : AppTheme.borderColor.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: isSelected ? AppTheme.primaryColor : AppTheme.secondaryTextColor,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? AppTheme.primaryColor : AppTheme.primaryTextColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: badgeColor,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.secondaryTextColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                isPlaying
                    ? Icons.stop_circle_rounded
                    : Icons.play_circle_outline_rounded,
                color: isPlaying ? AppTheme.primaryColor : AppTheme.secondaryTextColor,
                size: 26,
              ),
              tooltip: isPlaying ? 'Detener' : 'Probar',
              onPressed: onPlayToggle,
            ),
            Container(
              width: 20,
              height: 20,
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
                      size: 13,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
