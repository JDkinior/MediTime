import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/notifiers/caregiver_notifier.dart';
import 'package:meditime/services/auth_service.dart';
import 'package:meditime/services/firestore_service.dart';
import 'package:meditime/services/notification_service.dart';
import 'package:meditime/notifiers/profile_notifier.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:meditime/core/legal_content.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:meditime/widgets/modern_app_bar.dart';
import 'package:meditime/widgets/modern_content_fade.dart';
import 'package:meditime/widgets/settings/settings_widgets.dart';
import 'legal_document_page.dart';

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
    final caregiverNotifier = context.read<CaregiverNotifier>();
    final user = authService.currentUser;

    if (user == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Eliminar medicamentos del perfil principal
      final eliminados = await firestoreService.clearAllMedicamentos(user.uid);
      for (Tratamiento t in eliminados) {
        await NotificationService.cancelTreatmentAlarms(t.prescriptionAlarmId);
      }

      // 2. Eliminar medicamentos de perfiles locales gestionados (si existen)
      for (final profile in caregiverNotifier.managedProfiles) {
        if (!profile.isExternalUser) {
          final localEliminados = await firestoreService.clearAllMedicamentos(
            user.uid,
            profile,
          );
          for (Tratamiento t in localEliminados) {
            await NotificationService.cancelTreatmentAlarms(t.prescriptionAlarmId);
          }
        }
      }

      // 3. Cancelar cualquier notificación activa remanente en la bandeja del sistema
      await NotificationService.cancelAllAlarmNotifications();

      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: const Text('Historial de medicamentos eliminado con éxito.'),
              backgroundColor: AppTheme.successColor,
              duration: const Duration(seconds: 3),
            ),
          );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Error al eliminar historial: $e'),
              backgroundColor: AppTheme.errorColor,
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
          backgroundColor: Theme.of(context).cardColor,
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppTheme.errorColor),
              SizedBox(width: 8),
              Expanded(child: Text('¿Eliminar historial médico?')),
            ],
          ),
          content: const Text(
            'Esta acción eliminará de forma permanente todos tus medicamentos registrados y sus recordatorios programados. Esta acción no se puede deshacer.\n\n¿Deseas continuar?',
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
              style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
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
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: const Text('Historial de chats con Midi eliminado con éxito.'),
              backgroundColor: AppTheme.successColor,
              duration: const Duration(seconds: 3),
            ),
          );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Error al eliminar chats: $e'),
              backgroundColor: AppTheme.errorColor,
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
              Icon(Icons.warning_amber_rounded, color: AppTheme.errorColor),
              SizedBox(width: 8),
              Expanded(child: Text('¿Eliminar chats con Midi?')),
            ],
          ),
          content: const Text(
            'Esta acción eliminará de forma permanente todo tu historial de conversaciones con el asistente Midi. Esta acción no se puede deshacer.\n\n¿Deseas continuar?',
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
              style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
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
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('Tu cuenta y todos tus datos fueron eliminados correctamente.'),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 4),
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
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Error al eliminar la cuenta.'),
            backgroundColor: AppTheme.errorColor,
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
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(reauthResult.error ?? 'Error al reautenticar con Google.'),
            backgroundColor: AppTheme.errorColor,
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
              Icon(Icons.warning_amber_rounded, color: AppTheme.errorColor, size: 28),
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
                foregroundColor: AppTheme.errorColor,
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
    final pref = context.watch<PreferenceNotifier>();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: ModernAppBar(
        child: AppBar(
          title: const Text('Datos y Privacidad'),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: AppTheme.primaryTextColor,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ModernContentFade(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  const SettingsSectionHeader(
                    title: 'Privacidad en Pantalla',
                    topPadding: 0,
                  ),
                  SettingsSwitchTileCard(
                    title: 'Protección contra capturas',
                    description:
                        'Bloquea capturas de pantalla y oculta la vista previa de MediTime al cambiar entre aplicaciones.',
                    value: pref.secureScreen,
                    icon: Icons.security_rounded,
                    activeColor: AppTheme.primaryColor,
                    onChanged: (bool value) async {
                      await context.read<PreferenceNotifier>().setSecureScreen(value);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(
                            content: Text(
                              value
                                  ? 'Protección de pantalla activada (Anti-captura).'
                                  : 'Protección de pantalla desactivada.',
                            ),
                            backgroundColor: AppTheme.primaryColor,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                    },
                  ),
                  SettingsSwitchTileCard(
                    title: 'Ocultar fármaco en pantalla bloqueada',
                    description:
                        'Oculta el nombre específico del medicamento en las notificaciones mientras el teléfono está bloqueado.',
                    value: pref.hideMedicineNameOnLockScreen,
                    icon: Icons.visibility_off_outlined,
                    activeColor: Colors.deepPurple,
                    onChanged: (bool value) async {
                      await context
                          .read<PreferenceNotifier>()
                          .setHideMedicineNameOnLockScreen(value);
                      if (!context.mounted) return;
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
                    },
                  ),

                  const SettingsSectionHeader(
                    title: 'Documentación Legal y Transparencia',
                    topPadding: 12,
                  ),
                  SettingsActionTileCard(
                    title: 'Términos y Política de Privacidad',
                    subtitle:
                        'Documentos vigentes (v${LegalContent.version}). Conforme a Google Play Health Apps y RGPD.',
                    icon: Icons.verified_user_outlined,
                    iconColor: AppTheme.primaryColor,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LegalDocumentPage(initialTabIndex: 1),
                        ),
                      );
                    },
                  ),

                  const SettingsSectionHeader(
                    title: 'Gestión y Eliminación de Datos',
                    isDestructive: true,
                    topPadding: 12,
                  ),
                  SettingsActionTileCard(
                    title: 'Eliminar historial médico',
                    subtitle:
                        'Borra permanentemente todos tus tratamientos registrados y cancela sus alarmas.',
                    icon: Icons.delete_forever_outlined,
                    iconColor: AppTheme.errorColor,
                    isDestructive: true,
                    onTap: () => _confirmClearHistory(context),
                  ),
                  SettingsActionTileCard(
                    title: 'Eliminar historial de chats con IA',
                    subtitle: 'Borra todas las conversaciones guardadas con el asistente Midi.',
                    icon: Icons.forum_outlined,
                    iconColor: AppTheme.errorColor,
                    isDestructive: true,
                    onTap: () => _confirmClearChatHistory(context),
                  ),
                  SettingsActionTileCard(
                    title: 'Eliminar mi cuenta y datos personales',
                    subtitle:
                        'Elimina de forma irreversible tu cuenta, perfiles gestionados y toda tu información.',
                    icon: Icons.no_accounts_rounded,
                    iconColor: AppTheme.errorColor,
                    isDestructive: true,
                    onTap: () => _confirmDeleteAccount(context),
                  ),
                ],
              ),
            ),
    );
  }
}
