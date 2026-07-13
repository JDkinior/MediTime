// lib/screens/shared/opciones_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meditime/services/auth_service.dart';
import 'package:meditime/services/notification_service.dart';
import 'package:meditime/services/firestore_service.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/theme/app_theme.dart';

class OpcionesPage extends StatefulWidget {
  const OpcionesPage({super.key});

  @override
  State<OpcionesPage> createState() => _OpcionesPageState();
}

class _OpcionesPageState extends State<OpcionesPage> {
  bool _isLoading = false; // Local loading indicator for operations like clearing history
  bool _isRescheduling = false;

  final List<int> _snoozeOptions = [1, 5, 10, 15, 20, 30]; // Options in minutes

  Future<void> _onCalendarFormatChanged(String? newValue) async {
    if (newValue == null) return;
    
    final preferenceNotifier = context.read<PreferenceNotifier>();
    await preferenceNotifier.setCalendarFormat(newValue);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Diseño de calendario guardado.'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _onInterfaceStyleChanged(String? newValue) async {
    if (newValue == null) return;
    
    final preferenceNotifier = context.read<PreferenceNotifier>();
    await preferenceNotifier.setInterfaceStyle(newValue);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Diseño de interfaz guardado.'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _onNotificationModeChanged(bool value) async {
    setState(() {
      _isRescheduling = true;
    });

    final preferenceNotifier = context.read<PreferenceNotifier>();
    final authService = context.read<AuthService>();
    final user = authService.currentUser;

    await preferenceNotifier.setNotificationModeActive(value);

    if (user != null) {
      debugPrint("Preferencia cambiada. Reactivando alarmas...");
      await NotificationService.reactivateAlarmsForUser(user.uid);
      debugPrint("Alarmas reactivadas.");
    }

    if (mounted) {
      setState(() {
        _isRescheduling = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuración actualizada.'),
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
                  focusedBorder: const UnderlineInputBorder(
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

  Future<void> _clearMedicationHistory() async {
    final authService = context.read<AuthService>();
    final firestoreService = context.read<FirestoreService>();
    final user = authService.currentUser;

    if (user == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Eliminar medicamentos de Firestore y recuperar la lista
      final eliminados = await firestoreService.clearAllMedicamentos(user.uid);

      // 2. Cancelar alarmas asociadas
      for (Tratamiento t in eliminados) {
        await NotificationService.cancelTreatmentAlarms(t.prescriptionAlarmId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Historial de medicamentos eliminado con éxito.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar historial: $e'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _confirmClearHistory(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
              SizedBox(width: 8),
              Text('¿Eliminar historial?'),
            ],
          ),
          content: const Text(
            'Esta acción eliminará de forma permanente todos tus medicamentos registrados y sus recordatorios. Esta acción no se puede deshacer.\n\n¿Deseas continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _clearMedicationHistory();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              child: const Text('Eliminar Todo'),
            ),
          ],
        );
      },
    );
  }

    Future<void> _clearChatHistory() async {
    final authService = context.read<AuthService>();
    final firestoreService = context.read<FirestoreService>();
    final user = authService.currentUser;

    if (user == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await firestoreService.clearAllChatSessions(user.uid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Historial de chats con Midi eliminado con éxito.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar chats: $e'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _confirmClearChatHistory(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
              SizedBox(width: 8),
              Text('¿Eliminar chats con Midi?'),
            ],
          ),
          content: const Text(
            'Esta acción eliminará de forma permanente todo tu historial de conversaciones con el chat bot Midi. Esta acción no se puede deshacer.\n\n¿Deseas continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _clearChatHistory();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              child: const Text('Eliminar Todo'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final preferenceNotifier = context.watch<PreferenceNotifier>();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Opciones'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.primaryTextColor,
      ),
      body: (preferenceNotifier.isLoading || _isLoading)
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 1. Section: Diseño y Apariencia
                _buildSectionHeader(
                  'Diseño y Apariencia',
                  Icons.palette_outlined,
                  subtitle: 'Personaliza la apariencia de la app a tu gusto.',
                ),
                const SizedBox(height: 12),
                
                _buildOptionCardWrapper(
                  title: 'Modo de pantalla',
                  subtitle: 'Elige cómo se verá la aplicación.',
                  child: Row(
                    children: [
                      _buildThemeOptionCard(
                        id: 'light',
                        title: 'Claro',
                        subtitle: 'Modo diurno',
                        preview: const Icon(Icons.light_mode_rounded, color: Colors.orange, size: 28),
                      ),
                      const SizedBox(width: 10),
                      _buildThemeOptionCard(
                        id: 'dark',
                        title: 'Oscuro',
                        subtitle: 'Modo nocturno',
                        preview: const Icon(Icons.dark_mode_rounded, color: Colors.amber, size: 28),
                      ),
                      const SizedBox(width: 10),
                      _buildThemeOptionCard(
                        id: 'system',
                        title: 'Sistema',
                        subtitle: 'Auto (sistema)',
                        preview: const Icon(Icons.settings_brightness_rounded, color: Colors.blue, size: 28),
                      ),
                    ],
                  ),
                ),

                _buildOptionCardWrapper(
                  title: 'Estilo de navegación',
                  subtitle: 'Selecciona el estilo de tu barra de navegación.',
                  child: Row(
                    children: [
                      _buildInterfaceOptionCard(
                        id: 'classic',
                        title: 'Clásica',
                        subtitle: 'Nav bar tradicional',
                        preview: _buildClassicPreview(isSelected: preferenceNotifier.interfaceStyle == 'classic'),
                      ),
                      const SizedBox(width: 12),
                      _buildInterfaceOptionCard(
                        id: 'modern',
                        title: 'Moderna',
                        subtitle: 'Flotante premium',
                        preview: _buildModernPreview(isSelected: preferenceNotifier.interfaceStyle == 'modern'),
                      ),
                    ],
                  ),
                ),

                _buildOptionCardWrapper(
                  title: 'Vista de calendario',
                  subtitle: 'Elige cómo quieres ver el calendario.',
                  child: Row(
                    children: [
                      _buildCalendarOptionCard(
                        id: 'weekly',
                        title: 'Semanal',
                        subtitle: '1 fila',
                        previewRows: 1,
                      ),
                      const SizedBox(width: 10),
                      _buildCalendarOptionCard(
                        id: 'biweekly',
                        title: 'Quincenal',
                        subtitle: '2 filas',
                        previewRows: 2,
                      ),
                      const SizedBox(width: 10),
                      _buildCalendarOptionCard(
                        id: 'monthly',
                        title: 'Mensual',
                        subtitle: 'Completo',
                        previewRows: 4,
                      ),
                    ],
                  ),
                ),

                // 2. Section: Notificaciones y Alarmas
                _buildSectionHeader(
                  'Notificaciones y Alarmas',
                  Icons.notifications_active_outlined,
                  subtitle: 'Configura cómo quieres recibir tus recordatorios.',
                ),
                const SizedBox(height: 12),

                _buildOptionCardWrapper(
                  title: 'Gestión de tomas',
                  subtitle: 'Configura el comportamiento al sonar las alarmas.',
                  child: Row(
                    children: [
                      _buildNotificationOptionCard(
                        activeMode: true,
                        title: 'Modo Activo',
                        subtitle: 'Alertas y acciones manuales',
                        preview: _buildActiveModePreview(isSelected: preferenceNotifier.notificationModeActive == true),
                      ),
                      const SizedBox(width: 12),
                      _buildNotificationOptionCard(
                        activeMode: false,
                        title: 'Automático',
                        subtitle: 'Tomas marcadas al sonar',
                        preview: _buildAutoModePreview(isSelected: preferenceNotifier.notificationModeActive == false),
                      ),
                    ],
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
                      child: const Icon(Icons.snooze_outlined, color: AppTheme.primaryColor, size: 20),
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
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.primaryColor),
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

                // 3. Section: Datos y Privacidad
                _buildSectionHeader('Datos y Privacidad', Icons.security_rounded),
                const SizedBox(height: 12),

                _buildListTileCard(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.delete_forever_outlined, color: AppTheme.errorColor, size: 20),
                    ),
                    title: const Text(
                      'Eliminar historial médico',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.errorColor,
                      ),
                    ),
                    subtitle: const Text('Borra permanentemente todos los tratamientos'),
                    onTap: () => _confirmClearHistory(context),
                  ),
                ),
                const SizedBox(height: 12),
                _buildListTileCard(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.forum_outlined, color: AppTheme.errorColor, size: 20),
                    ),
                    title: const Text(
                      'Eliminar historial de chats con IA',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.errorColor,
                      ),
                    ),
                    subtitle: const Text('Borra todas las conversaciones con Midi'),
                    onTap: () => _confirmClearChatHistory(context),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10, top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryTextColor,
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.secondaryTextColor,
                ),
              ),
            ),
          ],
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
        border: Border.all(color: AppTheme.borderColor),
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
        border: Border.all(color: AppTheme.borderColor),
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
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor.withOpacity(0.04)
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
              // 1. Preview
              SizedBox(
                height: 48,
                child: Center(child: preview),
              ),
              const SizedBox(height: 12),
              // 2. Title
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isSelected ? AppTheme.primaryColor : AppTheme.primaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              // 3. Subtitle
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.secondaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              // 4. Radio Indicator
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? AppTheme.primaryColor : Colors.grey.shade500,
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

  Widget _buildThemeOptionCard({
    required String id,
    required String title,
    required String subtitle,
    required Widget preview,
  }) {
    final preferenceNotifier = context.watch<PreferenceNotifier>();
    final isSelected = preferenceNotifier.themeMode == id;
    return _buildOptionCardLayout(
      preview: preview,
      title: title,
      subtitle: subtitle,
      isSelected: isSelected,
      onTap: () => preferenceNotifier.setThemeMode(id),
    );
  }

  Widget _buildInterfaceOptionCard({
    required String id,
    required String title,
    required String subtitle,
    required Widget preview,
  }) {
    final preferenceNotifier = context.watch<PreferenceNotifier>();
    final isSelected = preferenceNotifier.interfaceStyle == id;
    return _buildOptionCardLayout(
      preview: preview,
      title: title,
      subtitle: subtitle,
      isSelected: isSelected,
      onTap: () => _onInterfaceStyleChanged(id),
    );
  }

  Widget _buildCalendarOptionCard({
    required String id,
    required String title,
    required String subtitle,
    required int previewRows,
  }) {
    final preferenceNotifier = context.watch<PreferenceNotifier>();
    final isSelected = preferenceNotifier.calendarFormat == id;
    
    final preview = Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(previewRows, (r) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(7, (c) {
            final isToday = r == 0 && c == 3;
            return Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isToday
                    ? AppTheme.primaryColor
                    : (isSelected ? AppTheme.primaryColor.withOpacity(0.3) : Colors.grey.shade500),
              ),
            );
          }),
        );
      }),
    );
    
    return _buildOptionCardLayout(
      preview: preview,
      title: title,
      subtitle: subtitle,
      isSelected: isSelected,
      onTap: () => _onCalendarFormatChanged(id),
    );
  }

  Widget _buildNotificationOptionCard({
    required bool activeMode,
    required String title,
    required String subtitle,
    required Widget preview,
  }) {
    final preferenceNotifier = context.watch<PreferenceNotifier>();
    final isSelected = preferenceNotifier.notificationModeActive == activeMode;
    return _buildOptionCardLayout(
      preview: preview,
      title: title,
      subtitle: subtitle,
      isSelected: isSelected,
      onTap: _isRescheduling ? () {} : () => _onNotificationModeChanged(activeMode),
    );
  }

  Widget _buildClassicPreview({required bool isSelected}) {
    return Container(
      width: 80,
      height: 16,
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : Colors.grey.shade700.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
          3,
          (index) => Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? AppTheme.primaryColor : Colors.grey.shade500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernPreview({required bool isSelected}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 55,
          height: 16,
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : Colors.grey.shade700.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              3,
              (index) => Container(
                width: 3,
                height: 3,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? AppTheme.primaryColor : Colors.grey.shade500,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Center(
            child: Icon(Icons.add, size: 10, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveModePreview({required bool isSelected}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_active, size: 16, color: isSelected ? AppTheme.primaryColor : Colors.grey.shade500),
            const SizedBox(width: 4),
            Container(
              width: 35, 
              height: 4, 
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryColor.withOpacity(0.3) : Colors.grey.shade700.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Container(
              width: 32,
              height: 10,
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryColor.withOpacity(0.15) : Colors.grey.shade700.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(child: Container(width: 16, height: 2, color: isSelected ? AppTheme.primaryColor : Colors.grey.shade500)),
            ),
            Container(
              width: 32,
              height: 10,
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryColor.withOpacity(0.15) : Colors.grey.shade700.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(child: Container(width: 16, height: 2, color: isSelected ? AppTheme.primaryColor : Colors.grey.shade500)),
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
            Icon(Icons.check_circle, size: 16, color: isSelected ? AppTheme.primaryColor : Colors.grey.shade500),
            const SizedBox(width: 6),
            Container(
              width: 35, 
              height: 4, 
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryColor.withOpacity(0.3) : Colors.grey.shade700.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: 50, 
          height: 3, 
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor.withOpacity(0.3) : Colors.grey.shade700.withOpacity(0.2),
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
      ],
    );
  }
}
