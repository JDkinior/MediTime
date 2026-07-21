import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meditime/services/auth_service.dart';
import 'package:meditime/services/firestore_service.dart';
import 'package:meditime/services/notification_service.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:meditime/theme/app_theme.dart';

class DatosPrivacidadPage extends StatefulWidget {
  const DatosPrivacidadPage({super.key});

  @override
  State<DatosPrivacidadPage> createState() => _DatosPrivacidadPageState();
}

class _DatosPrivacidadPageState extends State<DatosPrivacidadPage> {
  bool _isLoading = false;

  Future<void> _clearMedicationHistory() async {
    final authService = context.read<AuthService>();
    final firestoreService = context.read<FirestoreService>();
    final user = authService.currentUser;

    if (user == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final eliminados = await firestoreService.clearAllMedicamentos(user.uid);

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
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Datos y Privacidad'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.primaryTextColor,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
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
}
