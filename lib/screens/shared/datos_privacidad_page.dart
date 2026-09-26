import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/services/auth_service.dart';
import 'package:meditime/services/firestore_service.dart';
import 'package:meditime/services/notification_service.dart';
import 'package:meditime/notifiers/profile_notifier.dart';
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

  Future<void> _handleDeleteAccount({String? password}) async {
    final authService = context.read<AuthService>();
    final profileNotifier = context.read<ProfileNotifier>();

    setState(() => _isLoading = true);

    final result = await authService.deleteAccount(
      profileNotifier: profileNotifier,
      currentPassword: password,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      setState(() => _isLoading = false);
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tu cuenta y todos tus datos fueron eliminados correctamente.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _isLoading = false);

    if (result.error == 'REQUIRES_RECENT_LOGIN') {
      if (authService.isGoogleUser) {
        _promptGoogleReauth();
      } else {
        _promptPasswordReauth();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Error al eliminar la cuenta.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _promptGoogleReauth() async {
    final authService = context.read<AuthService>();
    final reauthResult = await authService.reauthenticateWithGoogle();
    if (!mounted) return;
    if (reauthResult.isSuccess) {
      _handleDeleteAccount();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(reauthResult.error ?? 'Error al reautenticar con Google.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _promptPasswordReauth() {
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Confirma tu contraseña'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Por motivos de seguridad, introduce tu contraseña actual para confirmar la eliminación definitiva de tu cuenta:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Contraseña',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () {
              final pwd = passwordController.text.trim();
              Navigator.pop(dialogCtx);
              if (pwd.isNotEmpty) {
                _handleDeleteAccount(password: pwd);
              }
            },
            child: const Text('Confirmar Eliminación', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '¿Eliminar cuenta permanentemente?',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: const Text(
            'Esta acción es definitiva e IRREVERSIBLE.\n\nSe eliminarán permanentemente de la base de datos de MediTime:\n• Tu cuenta y credenciales de acceso\n• Todos tus tratamientos y recordatorios\n• Tus perfiles de cuidadores o mascotas gestionados\n• Tu historial médico y de consultas con Midi\n\n¿Estás seguro de que deseas continuar?',
            style: TextStyle(fontSize: 13.5, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _handleDeleteAccount();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.redAccent,
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
              child: const Text('Eliminar Mi Cuenta'),
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
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    'PRIVACIDAD Y SEGURIDAD',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: AppTheme.secondaryTextColor,
                    ),
                  ),
                ),
                _buildListTileCard(
                  child: SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.security_rounded, color: AppTheme.primaryColor, size: 22),
                    ),
                    title: Text(
                      'Protección contra capturas',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryTextColor,
                      ),
                    ),
                    subtitle: const Text(
                      'Bloquea capturas de pantalla y oculta la vista previa de la app al cambiar entre aplicaciones para proteger tus datos médicos.',
                      style: TextStyle(fontSize: 12.5),
                    ),
                    value: context.watch<PreferenceNotifier>().secureScreen,
                    activeThumbImage: null,
                    activeColor: AppTheme.primaryColor,
                    onChanged: (bool value) {
                      context.read<PreferenceNotifier>().setSecureScreen(value);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            value
                                ? 'Protección de pantalla activada (Anti-captura).'
                                : 'Protección de pantalla desactivada.',
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _buildListTileCard(
                  child: SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.visibility_off_outlined, color: AppTheme.primaryColor, size: 22),
                    ),
                    title: Text(
                      'Ocultar en pantalla de bloqueo',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryTextColor,
                      ),
                    ),
                    subtitle: const Text(
                      'Oculta el nombre específico del fármaco en los avisos mientras el dispositivo se encuentre bloqueado.',
                      style: TextStyle(fontSize: 12.5),
                    ),
                    value: context.watch<PreferenceNotifier>().hideMedicineNameOnLockScreen,
                    activeColor: AppTheme.primaryColor,
                    onChanged: (bool value) {
                      context.read<PreferenceNotifier>().setHideMedicineNameOnLockScreen(value);
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    'GESTIÓN Y ELIMINACIÓN DE DATOS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: AppTheme.errorColor.withValues(alpha: 0.8),
                    ),
                  ),
                ),
                _buildListTileCard(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withValues(alpha: 0.1),
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
                        color: AppTheme.errorColor.withValues(alpha: 0.1),
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
                const SizedBox(height: 12),
                _buildListTileCard(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.no_accounts_rounded, color: Colors.red, size: 22),
                    ),
                    title: const Text(
                      'Eliminar mi cuenta y datos personales',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    subtitle: const Text('Elimina permanentemente tu cuenta y toda tu información'),
                    onTap: () => _confirmDeleteAccount(context),
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
        border: (context.watch<PreferenceNotifier>().showCardBorder || context.watch<PreferenceNotifier>().highContrast)
            ? Border.all(color: AppTheme.borderColor)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
