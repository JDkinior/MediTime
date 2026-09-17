import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meditime/notifiers/caregiver_notifier.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/models/caregiver_profile.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:meditime/screens/caregiver/manage_caregiver_profiles_page.dart';

class PatientSelectorDialog extends StatefulWidget {
  const PatientSelectorDialog({super.key});

  @override
  State<PatientSelectorDialog> createState() => _PatientSelectorDialogState();
}

class _PatientSelectorDialogState extends State<PatientSelectorDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSortAscending = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _shortenName(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return '${parts[0]} ${parts[1]}';
    }
    return parts.isNotEmpty ? parts[0] : '';
  }

  @override
  Widget build(BuildContext context) {
    final caregiverNotifier = context.watch<CaregiverNotifier>();
    final preferenceNotifier = context.watch<PreferenceNotifier>();
    final isAnimalMode = preferenceNotifier.isAnimalMode || caregiverNotifier.modeType == CaregiverModeType.veterinario;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isClinico = caregiverNotifier.modeType == CaregiverModeType.clinico;
    final profiles = caregiverNotifier.managedProfiles;

    final filteredProfiles = profiles.where((p) {
      if (_searchQuery.isEmpty) return true;
      final nameMatches = p.name.toLowerCase().contains(_searchQuery);
      final roomMatches = p.roomNumber?.toLowerCase().contains(_searchQuery) ?? false;
      final speciesMatches = p.species?.toLowerCase().contains(_searchQuery) ?? false;
      final breedMatches = p.breed?.toLowerCase().contains(_searchQuery) ?? false;
      return nameMatches || roomMatches || speciesMatches || breedMatches;
    }).toList();

    filteredProfiles.sort((a, b) {
      final nameA = a.name.toLowerCase();
      final nameB = b.name.toLowerCase();
      return _isSortAscending ? nameA.compareTo(nameB) : nameB.compareTo(nameA);
    });

    final cardBg = isDark ? AppTheme.surfaceColor : Colors.white;
    final searchBg = isDark ? AppTheme.backgroundColor : const Color(0xFFF3F6FB);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 620),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.4 : 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Search Header Section
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(color: AppTheme.primaryTextColor, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: isAnimalMode ? 'Buscar mascota, especie o box...' : 'Buscar paciente o habitación...',
                          hintStyle: TextStyle(color: AppTheme.secondaryTextColor.withOpacity(0.6), fontSize: 13),
                          prefixIcon: Icon(isAnimalMode ? Icons.pets_rounded : Icons.search_rounded, size: 20, color: AppTheme.primaryColor),
                          filled: true,
                          fillColor: searchBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: isDark ? BorderSide(color: Colors.white.withOpacity(0.08)) : BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: isDark ? BorderSide(color: Colors.white.withOpacity(0.08)) : BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: AppTheme.primaryColor.withOpacity(0.5), width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: searchBg,
                        borderRadius: BorderRadius.circular(16),
                        border: isDark ? Border.all(color: Colors.white.withOpacity(0.08)) : null,
                      ),
                      child: IconButton(
                        icon: Icon(
                          _isSortAscending ? Icons.sort_by_alpha_rounded : Icons.swap_vert_rounded,
                          color: AppTheme.primaryColor,
                          size: 20,
                        ),
                        tooltip: _isSortAscending ? 'Orden: A-Z (Toca para Z-A)' : 'Orden: Z-A (Toca para A-Z)',
                        onPressed: () {
                          setState(() {
                            _isSortAscending = !_isSortAscending;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    // Mi Perfil (Mis Medicamentos) Option
                    InkWell(
                      onTap: () {
                        caregiverNotifier.setActiveProfileId(null);
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: caregiverNotifier.activeProfileId == null
                              ? (isDark ? AppTheme.primaryColor.withOpacity(0.18) : const Color(0xFFEBF3FE))
                              : (isDark ? AppTheme.backgroundColor : const Color(0xFFFAFCFF)),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: caregiverNotifier.activeProfileId == null
                                ? AppTheme.primaryColor.withOpacity(isDark ? 0.3 : 0.2)
                                : AppTheme.borderColor,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(isDark ? 0.3 : 0.15),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(Icons.person_pin_rounded, color: AppTheme.primaryColor, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Mi Perfil (Mis Medicamentos)',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: caregiverNotifier.activeProfileId == null
                                          ? (isDark ? Colors.white : AppTheme.primaryColor)
                                          : AppTheme.primaryTextColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Mis medicamentos y recordatorios personales',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.secondaryTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (caregiverNotifier.activeProfileId == null)
                              Icon(Icons.check_circle_rounded, color: AppTheme.primaryColor, size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Vista General (Todos) Option
                    InkWell(
                      onTap: () {
                        caregiverNotifier.setActiveProfileId('general');
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: caregiverNotifier.isGeneralMode
                              ? (isDark ? AppTheme.primaryColor.withOpacity(0.18) : const Color(0xFFEBF3FE))
                              : (isDark ? AppTheme.backgroundColor : const Color(0xFFFAFCFF)),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: caregiverNotifier.isGeneralMode
                                ? AppTheme.primaryColor.withOpacity(isDark ? 0.3 : 0.2)
                                : AppTheme.borderColor,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(isDark ? 0.3 : 0.15),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                isAnimalMode ? Icons.pets_rounded : Icons.grid_view_rounded,
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
                                    isAnimalMode ? 'Todas las mascotas' : 'Vista General (Todos)',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: caregiverNotifier.isGeneralMode
                                          ? (isDark ? Colors.white : AppTheme.primaryColor)
                                          : AppTheme.primaryTextColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isAnimalMode
                                        ? 'Ver el plan de todas tus mascotas'
                                        : 'Ver el plan de todos tus pacientes',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.secondaryTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${profiles.length}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section Title: PACIENTES
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8, right: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isAnimalMode ? 'MASCOTAS Y ANIMALES' : 'PACIENTES',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.secondaryTextColor.withOpacity(0.7),
                              letterSpacing: 0.8,
                            ),
                          ),
                          Text(
                            _isSortAscending ? 'Nombre (A-Z)' : 'Nombre (Z-A)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Patient List Items Card Container
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.backgroundColor : const Color(0xFFFAFCFF),
                        borderRadius: BorderRadius.circular(20),
                        border: (context.watch<PreferenceNotifier>().showCardBorder || context.watch<PreferenceNotifier>().highContrast)
                            ? Border.all(color: AppTheme.borderColor)
                            : null,
                      ),
                      child: Column(
                        children: [
                          if (filteredProfiles.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Text(
                                isAnimalMode ? 'No se encontraron mascotas' : 'No se encontraron pacientes',
                                style: TextStyle(color: AppTheme.secondaryTextColor, fontSize: 13),
                              ),
                            )
                          else
                            ...filteredProfiles.asMap().entries.map((entry) {
                              final index = entry.key;
                              final profile = entry.value;
                              final hexColor = profile.colorHex.toUpperCase().replaceAll('#', '');
                              final color = Color(int.parse(hexColor.length == 6 ? 'FF$hexColor' : hexColor, radix: 16));

                              return Column(
                                children: [
                                  InkWell(
                                    onTap: () {
                                      caregiverNotifier.setActiveProfileId(profile.id);
                                      Navigator.pop(context);
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: color.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(14),
                                            ),
                                            child: Icon(
                                              (profile.isAnimal || isAnimalMode)
                                                  ? Icons.pets_rounded
                                                  : (isClinico ? Icons.hotel_rounded : Icons.person_rounded),
                                              color: color,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _shortenName(profile.name),
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppTheme.primaryTextColor,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  (profile.isAnimal || isAnimalMode)
                                                      ? [
                                                          if (profile.species != null && profile.species!.isNotEmpty) profile.species!,
                                                          if (profile.breed != null && profile.breed!.isNotEmpty) profile.breed!,
                                                          if (profile.roomNumber != null && profile.roomNumber!.isNotEmpty) 'Box ${profile.roomNumber}',
                                                          if ((profile.species == null || profile.species!.isEmpty) && profile.relationship.isNotEmpty) profile.relationship,
                                                        ].join(' • ')
                                                      : (profile.roomNumber != null && profile.roomNumber!.isNotEmpty
                                                          ? 'Hab. ${profile.roomNumber}'
                                                          : profile.relationship),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: AppTheme.secondaryTextColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: color.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              'Dosis hoy',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: color,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Icon(
                                            Icons.chevron_right_rounded,
                                            size: 18,
                                            color: AppTheme.secondaryTextColor.withOpacity(0.5),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (index < filteredProfiles.length - 1)
                                    Divider(height: 1, indent: 56, color: AppTheme.borderColor),
                                ],
                              );
                            }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Gestionar Pacientes Card
                    InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ManageCaregiverProfilesPage(isAnimalMode: isAnimalMode),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.backgroundColor : const Color(0xFFFAFCFF),
                          borderRadius: BorderRadius.circular(18),
                          border: (context.watch<PreferenceNotifier>().showCardBorder || context.watch<PreferenceNotifier>().highContrast)
                              ? Border.all(color: AppTheme.borderColor)
                              : null,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                isAnimalMode ? Icons.pets_rounded : Icons.people_alt_rounded,
                                color: AppTheme.primaryColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isAnimalMode ? 'Gestionar mascotas y animales' : 'Gestionar pacientes',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryTextColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isAnimalMode
                                        ? 'Agregar, editar o dar de alta mascotas'
                                        : 'Agregar, editar o eliminar pacientes',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.secondaryTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: AppTheme.secondaryTextColor.withOpacity(0.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
