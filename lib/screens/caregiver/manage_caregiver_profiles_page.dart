import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meditime/notifiers/caregiver_notifier.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/models/caregiver_profile.dart';
import 'package:meditime/services/auth_service.dart';
import 'package:meditime/services/firestore_service.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:meditime/screens/caregiver/add_edit_caregiver_profile_page.dart';

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.errorColor),
            SizedBox(width: 8),
            Text('Eliminar Paciente'),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar a "$profileName"?\n\nEsta acción borrará permanentemente sus medicamentos e historial asociados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
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

      final profile = caregiverNotifier.managedProfiles.firstWhere((p) => p.id == profileId);
      await firestoreService.clearAllMedicamentos(userId, profile);
      await firestoreService.deleteCaregiverProfile(userId, profileId);
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

  Future<void> _editProfile(CaregiverProfile profile) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditCaregiverProfilePage(initialProfile: profile),
      ),
    );
    if (mounted) {
      final userId = context.read<AuthService>().currentUser?.uid;
      if (userId != null) {
        await context.read<CaregiverNotifier>().loadProfiles(userId);
      }
    }
  }

  Future<void> _addProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddEditCaregiverProfilePage(),
      ),
    );
    if (mounted) {
      final userId = context.read<AuthService>().currentUser?.uid;
      if (userId != null) {
        await context.read<CaregiverNotifier>().loadProfiles(userId);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<PreferenceNotifier>();
    final caregiverNotifier = context.watch<CaregiverNotifier>();
    final profiles = caregiverNotifier.managedProfiles;
    final isClinico = caregiverNotifier.modeType == CaregiverModeType.clinico;

    final countTotal = profiles.length;
    final countWithRoom = profiles.where((p) => p.roomNumber != null && p.roomNumber!.isNotEmpty).length;
    final countLinked = profiles.where((p) => p.isExternalUser).length;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Gestión de Pacientes'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.primaryTextColor,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addProfile,
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text('Agregar Paciente', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Dashboard Stats Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryColor.withOpacity(0.12),
                      AppTheme.primaryColor.withOpacity(0.04),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.analytics_rounded, color: AppTheme.primaryColor, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              'Resumen de Pacientes',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryTextColor,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isClinico ? 'Modo Clínico' : 'Modo Familiar',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildStatItem('Total', countTotal.toString(), Icons.people_alt_rounded, Colors.blue),
                        if (isClinico)
                          _buildStatItem('En Habitación', countWithRoom.toString(), Icons.hotel_rounded, Colors.amber.shade700)
                        else
                          _buildStatItem('Vinculados', countLinked.toString(), Icons.link_rounded, Colors.teal),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'Listado de Pacientes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryTextColor,
                ),
              ),
              const SizedBox(height: 12),

              if (profiles.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.person_search_rounded, size: 56, color: AppTheme.secondaryTextColor.withOpacity(0.5)),
                      const SizedBox(height: 12),
                      Text(
                        'No tienes pacientes registrados',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Agrega pacientes familiares o de hospital para gestionar sus medicamentos.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: AppTheme.secondaryTextColor),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _addProfile,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Agregar Primer Paciente'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          side: const BorderSide(color: AppTheme.primaryColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: profiles.length,
                  itemBuilder: (context, index) {
                    final profile = profiles[index];
                    final hexColor = profile.colorHex.toUpperCase().replaceAll('#', '');
                    final color = Color(int.parse(hexColor.length == 6 ? 'FF$hexColor' : hexColor, radix: 16));

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12.0),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.borderColor),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: color.withOpacity(0.2),
                                child: Text(
                                  profile.name.isNotEmpty ? profile.name[0].toUpperCase() : '?',
                                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      profile.name,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryTextColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      profile.relationship,
                                      style: TextStyle(fontSize: 13, color: AppTheme.secondaryTextColor),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryColor),
                                tooltip: 'Editar',
                                onPressed: () => _editProfile(profile),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.errorColor),
                                tooltip: 'Eliminar',
                                onPressed: () => _deleteProfile(profile.id, profile.name),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              if (profile.category != null && profile.category!.isNotEmpty)
                                _buildBadge(Icons.category_outlined, profile.category!, AppTheme.primaryColor),
                              if (profile.roomNumber != null && profile.roomNumber!.isNotEmpty)
                                _buildBadge(Icons.hotel_outlined, 'Hab: ${profile.roomNumber}', Colors.amber.shade800),
                              if (profile.bloodType != null && profile.bloodType!.isNotEmpty)
                                _buildBadge(Icons.bloodtype_outlined, profile.bloodType!, Colors.redAccent),
                              if (profile.isExternalUser)
                                _buildBadge(Icons.link_rounded, 'Vinculado', Colors.teal),
                              if (profile.allergies != null && profile.allergies!.isNotEmpty)
                                _buildBadge(Icons.warning_amber_rounded, 'Alergias: ${profile.allergies}', Colors.orange.shade800),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              const SizedBox(height: 80), // bottom space for FAB
            ],
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

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryTextColor,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.secondaryTextColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
