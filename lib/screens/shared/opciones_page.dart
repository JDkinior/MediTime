// lib/screens/shared/opciones_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meditime/services/preference_service.dart';
import 'package:meditime/services/auth_service.dart';
import 'package:meditime/services/notification_service.dart';

class OpcionesPage extends StatefulWidget {
  const OpcionesPage({super.key});

  @override
  State<OpcionesPage> createState() => _OpcionesPageState();
}

class _OpcionesPageState extends State<OpcionesPage> {
  bool _notificacionesActivas = false;
  bool _isLoading = true;
  bool _isRescheduling = false;

  // --- INICIO DE LA MODIFICACIÓN ---
  // Estado para la duración del aplazamiento
  int _snoozeDuration = 10;
  final List<int> _snoozeOptions = [1, 5, 10, 15, 20, 30]; // Opciones en minutos
  // --- FIN DE LA MODIFICACIÓN ---

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  // --- INICIO DE LA MODIFICACIÓN ---
  // Ahora carga ambas preferencias
  Future<void> _loadPreferences() async {
    if (!mounted) return;
    final preferenceService = context.read<PreferenceService>();
    
    // Cargamos ambas preferencias en paralelo
    final results = await Future.wait([
      preferenceService.getNotificationMode(),
      preferenceService.getSnoozeDuration(),
    ]);

    if (mounted) {
      setState(() {
        // CORRECCIÓN: Hacemos un 'cast' explícito al tipo de dato correcto
        _notificacionesActivas = results[0] as bool;
        _snoozeDuration = results[1] as int;
        _isLoading = false;
      });
    }
  }
  // --- FIN DE LA MODIFICACIÓN ---

  Future<void> _onNotificationModeChanged(bool value) async {
    setState(() {
      _notificacionesActivas = value;
      _isRescheduling = true;
    });

    final preferenceService = context.read<PreferenceService>();
    final authService = context.read<AuthService>();
    final user = authService.currentUser;

    await preferenceService.saveNotificationMode(value);

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

  // --- INICIO DE LA MODIFICACIÓN ---
  // Nueva función para guardar la duración del aplazamiento
  Future<void> _onSnoozeDurationChanged(int? newDuration) async {
    if (newDuration == null) return;
    
    setState(() {
      _snoozeDuration = newDuration;
    });
    
    final preferenceService = context.read<PreferenceService>();
    await preferenceService.saveSnoozeDuration(newDuration);

    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tiempo de aplazamiento guardado.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
  }
  // --- FIN DE LA MODIFICACIÓN ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Opciones'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                SwitchListTile(
                  title: const Text('Notificaciones Activas'),
                  subtitle: Text(
                    _notificacionesActivas
                        ? 'Recibirás notificaciones con acciones.'
                        : 'Las dosis se marcarán como tomadas automáticamente.',
                  ),
                  value: _notificacionesActivas,
                  onChanged: _isRescheduling ? null : _onNotificationModeChanged,
                  secondary: const Icon(Icons.notifications_active_outlined),
                ),
                const Divider(),
                // --- INICIO DE LA MODIFICACIÓN ---
                // Nuevo widget para seleccionar el tiempo de aplazamiento
                ListTile(
                  leading: const Icon(Icons.snooze_outlined),
                  title: const Text('Tiempo para aplazar la alarma'),
                  trailing: DropdownButton<int>(
                    value: _snoozeDuration,
                    items: _snoozeOptions.map<DropdownMenuItem<int>>((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text('$value min'),
                      );
                    }).toList(),
                    onChanged: _onSnoozeDurationChanged,
                  ),
                ),
                // --- FIN DE LA MODIFICACIÓN ---
              ],
            ),
    );
  }
}