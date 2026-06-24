// lib/screens/shared/opciones_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meditime/services/preference_service.dart';
import 'package:meditime/services/auth_service.dart';
import 'package:meditime/services/notification_service.dart';
import 'package:meditime/services/firestore_service.dart';
import 'package:meditime/models/tratamiento.dart';

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
  
  // Estado para el diseño de calendario
  String _calendarFormatStr = 'weekly';
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
    
    // Cargamos preferencias en paralelo
    final results = await Future.wait([
      preferenceService.getNotificationMode(),
      preferenceService.getSnoozeDuration(),
      preferenceService.getCalendarFormat(),
    ]);

    if (mounted) {
      setState(() {
        // CORRECCIÓN: Hacemos un 'cast' explícito al tipo de dato correcto
        _notificacionesActivas = results[0] as bool;
        _snoozeDuration = results[1] as int;
        _calendarFormatStr = results[2] as String;
        _isLoading = false;
      });
    }
  }

  Future<void> _onCalendarFormatChanged(String? newValue) async {
    if (newValue == null) return;
    
    setState(() {
      _calendarFormatStr = newValue;
    });
    
    final preferenceService = context.read<PreferenceService>();
    await preferenceService.saveCalendarFormat(newValue);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Diseño de calendario guardado.'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
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

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tiempo de aplazamiento guardado.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.notifications_active_outlined, color: Colors.grey),
                          const SizedBox(width: 16),
                          Text(
                            'Modo de Notificación',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildNotificationOptionCard(
                            activeMode: true,
                            title: 'Modo Activo',
                            subtitle: 'Recibe alertas y toma acciones',
                            preview: Builder(
                              builder: (context) {
                                final primaryColor = const Color(0xFF2296F3);
                                final isSelected = _notificacionesActivas == true;
                                return Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.notifications_active, size: 14, color: isSelected ? primaryColor : Colors.grey),
                                        const SizedBox(width: 4),
                                        Container(width: 35, height: 4, color: Colors.grey.shade300),
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
                                            color: isSelected ? primaryColor.withOpacity(0.15) : Colors.grey.shade200,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Center(child: Container(width: 16, height: 2, color: isSelected ? primaryColor : Colors.grey)),
                                        ),
                                        Container(
                                          width: 32,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: isSelected ? primaryColor.withOpacity(0.15) : Colors.grey.shade200,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Center(child: Container(width: 16, height: 2, color: isSelected ? primaryColor : Colors.grey)),
                                        ),
                                      ],
                                    )
                                  ],
                                );
                              }
                            ),
                          ),
                          const SizedBox(width: 12),
                          _buildNotificationOptionCard(
                            activeMode: false,
                            title: 'Modo Automático',
                            subtitle: 'Se marcan como tomadas',
                            preview: Builder(
                              builder: (context) {
                                final primaryColor = const Color(0xFF2296F3);
                                final isSelected = _notificacionesActivas == false;
                                return Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.check_circle, size: 16, color: isSelected ? primaryColor : Colors.grey),
                                        const SizedBox(width: 6),
                                        Container(width: 35, height: 4, color: Colors.grey.shade300),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Container(width: 50, height: 3, color: Colors.grey.shade200),
                                  ],
                                );
                              }
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
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
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calendar_month_outlined, color: Colors.grey),
                          const SizedBox(width: 16),
                          Text(
                            'Diseño de Calendario',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
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
                    ],
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.delete_forever_outlined, color: Colors.redAccent),
                  title: const Text(
                    'Eliminar historial de medicamentos',
                    style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Borra todos los tratamientos y sus alarmas'),
                  onTap: () => _confirmClearHistory(context),
                ),
                // --- FIN DE LA MODIFICACIÓN ---
              ],
            ),
    );
  }

  Widget _buildCalendarOptionCard({
    required String id,
    required String title,
    required String subtitle,
    required int previewRows,
  }) {
    final isSelected = _calendarFormatStr == id;
    final primaryColor = const Color(0xFF2296F3);

    return Expanded(
      child: GestureDetector(
        onTap: () => _onCalendarFormatChanged(id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? primaryColor : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mini Preview representation
              Container(
                height: 48,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(previewRows, (r) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(7, (c) {
                        final isToday = r == 0 && c == 3; // Highlight one dot as today
                        return Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isToday
                                ? primaryColor
                                : (isSelected ? primaryColor.withOpacity(0.3) : Colors.grey.shade300),
                          ),
                        );
                      }),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isSelected ? primaryColor : Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationOptionCard({
    required bool activeMode,
    required String title,
    required String subtitle,
    required Widget preview,
  }) {
    final isSelected = _notificacionesActivas == activeMode;
    final primaryColor = const Color(0xFF2296F3);

    return Expanded(
      child: GestureDetector(
        onTap: _isRescheduling ? null : () => _onNotificationModeChanged(activeMode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? primaryColor : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Preview representation
              Container(
                height: 54,
                width: double.infinity,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: preview,
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isSelected ? primaryColor : Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}