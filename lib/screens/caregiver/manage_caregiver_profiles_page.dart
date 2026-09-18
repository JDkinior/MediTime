import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meditime/notifiers/caregiver_notifier.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/models/caregiver_profile.dart';
import 'package:meditime/services/auth_service.dart';
import 'package:meditime/services/firestore_service.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:meditime/screens/caregiver/add_edit_caregiver_profile_page.dart';
import 'package:meditime/core/subscription_guard.dart';

class ManageCaregiverProfilesPage extends StatefulWidget {
  final bool isAnimalMode;

  const ManageCaregiverProfilesPage({super.key, this.isAnimalMode = false});

  @override
  State<ManageCaregiverProfilesPage> createState() => _ManageCaregiverProfilesPageState();
}

class _ManageCaregiverProfilesPageState extends State<ManageCaregiverProfilesPage> {
  bool _isLoading = false;

  bool _getEffectiveAnimalMode() {
    return widget.isAnimalMode ||
        context.read<PreferenceNotifier>().isAnimalMode ||
        context.read<CaregiverNotifier>().modeType == CaregiverModeType.veterinario;
  }

  Future<void> _deleteProfile(String profileId, String profileName) async {
    final isAnimal = _getEffectiveAnimalMode();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppTheme.errorColor),
            const SizedBox(width: 8),
            Text(isAnimal ? 'Eliminar Mascota' : 'Eliminar Paciente'),
          ],
        ),
        content: Text(
          isAnimal
              ? '¿Estás seguro de que deseas eliminar a "$profileName"?\n\nEsta acción borrará permanentemente sus medicamentos y tratamientos asociados.'
              : '¿Estás seguro de que deseas eliminar a "$profileName"?\n\nEsta acción borrará permanentemente sus medicamentos e historial asociados.',
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
          SnackBar(
            content: Text(
              isAnimal
                  ? 'Mascota eliminada exitosamente.'
                  : 'Paciente eliminado exitosamente.',
            ),
          ),
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
    final isAnimal = _getEffectiveAnimalMode();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditCaregiverProfilePage(
          initialProfile: profile,
          isAnimalMode: isAnimal,
        ),
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
    final isAnimal = _getEffectiveAnimalMode();
    final canProceed = await SubscriptionGuard.canAddProfile(context, isAnimal: isAnimal);
    if (!canProceed || !mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditCaregiverProfilePage(
          isAnimalMode: isAnimal,
        ),
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
    final prefNotifier = context.watch<PreferenceNotifier>();
    final caregiverNotifier = context.watch<CaregiverNotifier>();
    final isAnimal = widget.isAnimalMode ||
        prefNotifier.isAnimalMode ||
        caregiverNotifier.modeType == CaregiverModeType.veterinario;
    final isClinico = caregiverNotifier.modeType == CaregiverModeType.clinico || caregiverNotifier.modeType == CaregiverModeType.veterinario;

    // Si estamos en modo animales, mostramos perfiles de animales si existen; de lo contrario todos
    final allProfiles = caregiverNotifier.managedProfiles;
    final profiles = isAnimal
        ? allProfiles.where((p) => p.isAnimal).toList()
        : allProfiles.where((p) => !p.isAnimal).toList();

    final countTotal = profiles.length;
    final countWithRoom = profiles.where((p) => p.roomNumber != null && p.roomNumber!.isNotEmpty).length;
    final countWithMicrochip = profiles.where((p) => p.microchip != null && p.microchip!.isNotEmpty).length;
    final countLinked = profiles.where((p) => p.isExternalUser).length;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(isAnimal ? 'Gestión de Mascotas / Pacientes' : 'Gestión de Pacientes'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.primaryTextColor,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addProfile,
        backgroundColor: AppTheme.primaryColor,
        icon: Icon(isAnimal ? Icons.pets_rounded : Icons.person_add_rounded, color: Colors.white),
        label: Text(
          isAnimal ? 'Agregar Mascota' : 'Agregar Paciente',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
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
                            Icon(isAnimal ? Icons.pets_rounded : Icons.analytics_rounded, color: AppTheme.primaryColor, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              isAnimal ? 'Resumen de Mascotas' : 'Resumen de Pacientes',
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
                            isAnimal ? 'Modo Animales' : (isClinico ? 'Modo Clínico' : 'Modo Familiar'),
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
                        _buildStatItem('Total', countTotal.toString(), isAnimal ? Icons.pets_rounded : Icons.people_alt_rounded, Colors.blue),
                        if (isAnimal)
                          _buildStatItem('Con Microchip', countWithMicrochip.toString(), Icons.qr_code_rounded, Colors.teal)
                        else if (isClinico)
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
                isAnimal ? 'Listado de Mascotas' : 'Listado de Pacientes',
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
                    border: (context.watch<PreferenceNotifier>().showCardBorder || context.watch<PreferenceNotifier>().highContrast)
                        ? Border.all(color: AppTheme.borderColor)
                        : null,
                  ),
                  child: Column(
                    children: [
                      Icon(
                        isAnimal ? Icons.pets_rounded : Icons.person_search_rounded,
                        size: 56,
                        color: AppTheme.secondaryTextColor.withOpacity(0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isAnimal ? 'No tienes mascotas registradas' : 'No tienes pacientes registrados',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isAnimal
                            ? 'Agrega a tus mascotas o pacientes veterinarios para gestionar sus medicamentos y dosis.'
                            : 'Agrega pacientes familiares o de hospital para gestionar sus medicamentos.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: AppTheme.secondaryTextColor),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _addProfile,
                        icon: const Icon(Icons.add_rounded),
                        label: Text(isAnimal ? 'Agregar Primera Mascota' : 'Agregar Primer Paciente'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          side: BorderSide(color: AppTheme.primaryColor),
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
                        border: (context.watch<PreferenceNotifier>().showCardBorder || context.watch<PreferenceNotifier>().highContrast)
                            ? Border.all(color: AppTheme.borderColor)
                            : null,
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
                                child: profile.isAnimal
                                    ? Icon(Icons.pets_rounded, color: color, size: 22)
                                    : Text(
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
                                      profile.isAnimal
                                          ? [profile.species, profile.breed, profile.relationship]
                                              .where((s) => s != null && s.isNotEmpty)
                                              .join(' • ')
                                          : profile.relationship,
                                      style: TextStyle(fontSize: 13, color: AppTheme.secondaryTextColor),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.edit_outlined, color: AppTheme.primaryColor),
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
                              if (profile.species != null && profile.species!.isNotEmpty)
                                _buildBadge(Icons.pets_rounded, profile.species!, AppTheme.primaryColor),
                              if (profile.breed != null && profile.breed!.isNotEmpty)
                                _buildBadge(Icons.info_outline_rounded, profile.breed!, Colors.teal),
                              if (profile.weight != null)
                                _buildBadge(Icons.scale_rounded, '${profile.weight} kg', Colors.purple),
                              if (profile.microchip != null && profile.microchip!.isNotEmpty)
                                _buildBadge(Icons.qr_code_rounded, 'Chip: ${profile.microchip}', Colors.indigo),
                              if (profile.category != null && profile.category!.isNotEmpty)
                                _buildBadge(Icons.category_outlined, profile.category!, AppTheme.primaryColor),
                              if (profile.roomNumber != null && profile.roomNumber!.isNotEmpty)
                                _buildBadge(Icons.meeting_room_outlined, profile.isAnimal ? 'Box: ${profile.roomNumber}' : 'Hab: ${profile.roomNumber}', Colors.amber.shade800),
                              if (profile.bloodType != null && profile.bloodType!.isNotEmpty)
                                _buildBadge(Icons.bloodtype_outlined, profile.bloodType!, Colors.redAccent),
                              if (profile.isExternalUser)
                                _buildBadge(Icons.link_rounded, 'Vinculado', Colors.teal),
                              if (profile.allergies != null && profile.allergies!.isNotEmpty)
                                _buildBadge(Icons.warning_amber_rounded, 'Alergias: ${profile.allergies}', Colors.orange.shade800),
                              if (profile.notes != null && profile.notes!.isNotEmpty)
                                _buildBadge(Icons.note_alt_outlined, 'Con notas', Colors.blueGrey),
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
