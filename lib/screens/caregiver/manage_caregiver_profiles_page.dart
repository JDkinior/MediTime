import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meditime/notifiers/caregiver_notifier.dart';
import 'package:meditime/services/auth_service.dart';
import 'package:meditime/services/firestore_service.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:meditime/widgets/caregiver/add_caregiver_profile_dialog.dart';

class ManageCaregiverProfilesPage extends StatefulWidget {
  const ManageCaregiverProfilesPage({super.key});

  @override
  State<ManageCaregiverProfilesPage> createState() => _ManageCaregiverProfilesPageState();
}

class _ManageCaregiverProfilesPageState extends State<ManageCaregiverProfilesPage> {
  bool _isLoading = false;

  Future<void> _deleteProfile(String profileId, String profileName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Paciente'),
        content: Text('¿Estás seguro de que deseas eliminar a "$profileName"? Esta acción borrará permanentemente sus medicamentos y rutinas de tu cuenta.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final userId = context.read<AuthService>().currentUser?.uid;
      if (userId == null) throw Exception('No se encontró el ID del usuario.');
      
      final caregiverNotifier = context.read<CaregiverNotifier>();
      final firestoreService = context.read<FirestoreService>();
      
      // Clear associated meds
      final profile = caregiverNotifier.managedProfiles.firstWhere((p) => p.id == profileId);
      await firestoreService.clearAllMedicamentos(userId, profile);

      // Delete profile
      await firestoreService.deleteCaregiverProfile(userId, profileId);
      
      // Reload profiles
      await caregiverNotifier.loadProfiles(userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Paciente eliminado exitosamente.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _editProfile(dynamic profile) async {
    final result = await showDialog(
      context: context,
      builder: (context) => AddCaregiverProfileDialog(initialProfile: profile),
    );
    if (result == true) {
      if (mounted) {
        setState(() {}); // refresh the list
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Gestionar Pacientes', style: TextStyle(color: AppTheme.whiteTextColor)),
        backgroundColor: AppTheme.primaryColor,
        iconTheme: const IconThemeData(color: AppTheme.whiteTextColor),
      ),
      body: Stack(
        children: [
          Consumer<CaregiverNotifier>(
            builder: (context, caregiverNotifier, child) {
              final profiles = caregiverNotifier.managedProfiles;
              
              if (profiles.isEmpty) {
                return const Center(
                  child: Text('No tienes pacientes registrados.'),
                );
              }
              
              return ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: profiles.length,
                itemBuilder: (context, index) {
                  final profile = profiles[index];
                  final hexColor = profile.colorHex.toUpperCase().replaceAll('#', '');
                  final color = Color(int.parse(hexColor.length == 6 ? 'FF$hexColor' : hexColor, radix: 16));
                  
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 12.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: color,
                        child: const Icon(Icons.person, color: Colors.white),
                      ),
                      title: Text(profile.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        profile.category != null && profile.category!.isNotEmpty 
                            ? '${profile.relationship} • ${profile.category}' 
                            : profile.relationship
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: AppTheme.primaryColor),
                            onPressed: () => _editProfile(profile),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: AppTheme.errorColor),
                            onPressed: () => _deleteProfile(profile.id, profile.name),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
