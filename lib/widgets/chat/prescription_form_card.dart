// lib/widgets/chat/prescription_form_card.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meditime/models/caregiver_profile.dart';
import 'package:meditime/notifiers/caregiver_notifier.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/theme/app_theme.dart';

class PrescriptionFormCard extends StatefulWidget {
  final Map<String, dynamic> prescriptionData;
  final void Function(
    String name,
    String pres,
    int interval,
    int dosis,
    int duration,
    String notas, [
    CaregiverProfile? targetProfile,
  ])
  onSaved;

  const PrescriptionFormCard({
    super.key,
    required this.prescriptionData,
    required this.onSaved,
  });

  @override
  State<PrescriptionFormCard> createState() => PrescriptionFormCardState();
}

class PrescriptionFormCardState extends State<PrescriptionFormCard> {
  late final TextEditingController _nameController;
  late final TextEditingController _dosisController;
  late final TextEditingController _intervaloController;
  late final TextEditingController _duracionController;
  late final TextEditingController _notasController;
  late String _selectedPresentacion;

  CaregiverProfile? _selectedProfile;
  bool _profileInitialized = false;

  final List<String> _presentaciones = [
    'Comprimidos',
    'Grageas',
    'Cápsulas',
    'Sobres',
    'Jarabes',
    'Gotas',
    'Suspensiones',
    'Emulsiones',
  ];

  @override
  void initState() {
    super.initState();
    final data = widget.prescriptionData;
    _nameController = TextEditingController(text: data['nombreMedicamento']);
    _dosisController = TextEditingController(
      text: data['dosisPorToma']?.toString(),
    );
    _intervaloController = TextEditingController(
      text: data['intervaloDosis']?.toString(),
    );
    _duracionController = TextEditingController(
      text: data['duracion']?.toString(),
    );
    _notasController = TextEditingController(text: data['notas']);

    final rawPres = data['presentacion']?.toString() ?? 'Comprimidos';
    _selectedPresentacion = _normalizePresentacion(rawPres);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_profileInitialized) {
      _profileInitialized = true;
      _initSelectedProfile();
    }
  }

  void _initSelectedProfile() {
    final prefNotifier = context.read<PreferenceNotifier>();
    final caregiverNotifier = context.read<CaregiverNotifier>();
    final isAnimal = prefNotifier.isAnimalMode;
    final allProfiles = caregiverNotifier.managedProfiles;
    final data = widget.prescriptionData;

    final targetId = data['targetProfileId']?.toString();
    final targetName = data['targetProfileName']?.toString();

    if (targetId != null && targetId.isNotEmpty && targetId != 'general') {
      try {
        _selectedProfile = allProfiles.firstWhere((p) => p.id == targetId);
        return;
      } catch (_) {}
    }

    if (targetName != null && targetName.trim().isNotEmpty) {
      final clean = targetName.trim().toLowerCase();
      if (clean != 'personal' &&
          clean != 'yo' &&
          clean != 'mí' &&
          clean != 'mi perfil') {
        final modeProfiles =
            allProfiles
                .where((p) => isAnimal ? p.isAnimal : !p.isAnimal)
                .toList();
        final pool = modeProfiles.isNotEmpty ? modeProfiles : allProfiles;
        try {
          _selectedProfile = pool.firstWhere(
            (p) => p.name.trim().toLowerCase() == clean,
          );
          return;
        } catch (_) {
          try {
            _selectedProfile = pool.firstWhere(
              (p) =>
                  p.name.trim().toLowerCase().contains(clean) ||
                  clean.contains(p.name.trim().toLowerCase()),
            );
            return;
          } catch (_) {}
        }
      }
    }

    _selectedProfile = caregiverNotifier.getEffectiveActiveProfile(
      isAnimalMode: isAnimal,
    );
    if (_selectedProfile == null && isAnimal) {
      final animals = allProfiles.where((p) => p.isAnimal).toList();
      if (animals.isNotEmpty) {
        _selectedProfile = animals.first;
      }
    }
  }

  String _normalizePresentacion(String rawValue) {
    final clean = rawValue.trim().toLowerCase();
    if (clean.contains('comprimido') ||
        clean.contains('pastilla') ||
        clean.contains('tableta')) {
      return 'Comprimidos';
    } else if (clean.contains('gragea')) {
      return 'Grageas';
    } else if (clean.contains('cápsula') || clean.contains('capsula')) {
      return 'Cápsulas';
    } else if (clean.contains('sobre')) {
      return 'Sobres';
    } else if (clean.contains('jarabe')) {
      return 'Jarabes';
    } else if (clean.contains('gota')) {
      return 'Gotas';
    } else if (clean.contains('suspension') || clean.contains('suspensión')) {
      return 'Suspensiones';
    } else if (clean.contains('emulsion') || clean.contains('emulsión')) {
      return 'Emulsiones';
    }
    return 'Comprimidos';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosisController.dispose();
    _intervaloController.dispose();
    _duracionController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSaved = widget.prescriptionData['isSaved'] == true;
    final prefNotifier = context.watch<PreferenceNotifier>();
    final caregiverNotifier = context.watch<CaregiverNotifier>();
    final isAnimal = prefNotifier.isAnimalMode;
    final isCaregiver = caregiverNotifier.isCaregiverModeActive;
    final availableProfiles =
        caregiverNotifier.managedProfiles
            .where((p) => isAnimal ? p.isAnimal : !p.isAnimal)
            .toList();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color:
              isSaved
                  ? Colors.green.withValues(alpha: 0.4)
                  : AppTheme.primaryColor.withValues(alpha: 0.2),
          width: isSaved ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isSaved ? Icons.check_circle : Icons.receipt_long_rounded,
                color: isSaved ? Colors.green : AppTheme.primaryColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isSaved ? 'Receta Guardada' : 'Datos Extraídos de la Receta',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isSaved ? Colors.green : AppTheme.primaryTextColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isCaregiver || isAnimal) ...[
            if (isSaved)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: (isAnimal ? Colors.teal : AppTheme.primaryColor)
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (isAnimal ? Colors.teal : AppTheme.primaryColor)
                        .withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isAnimal ? Icons.pets_rounded : Icons.person_rounded,
                      size: 20,
                      color: isAnimal ? Colors.teal : AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isAnimal
                                ? 'Mascota / Paciente'
                                : 'Paciente asignado',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color:
                                  isAnimal
                                      ? Colors.teal
                                      : AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _selectedProfile != null
                                ? '${_selectedProfile!.name} (${isAnimal ? (_selectedProfile!.species ?? "Mascota") : _selectedProfile!.relationship})'
                                : 'Mi Perfil Personal (Yo)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryTextColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: isAnimal ? Colors.teal : AppTheme.primaryColor,
                    ),
                  ],
                ),
              )
            else
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isAnimal
                              ? Icons.pets_rounded
                              : Icons.person_outline_rounded,
                          size: 16,
                          color: isAnimal ? Colors.teal : AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isAnimal
                              ? 'Paciente / Mascota a tratar'
                              : 'Paciente asignado',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color:
                                isAnimal ? Colors.teal : AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<CaregiverProfile?>(
                      initialValue:
                          availableProfiles.contains(_selectedProfile)
                              ? _selectedProfile
                              : null,
                      dropdownColor: Theme.of(context).cardColor,
                      isExpanded: true,
                      style: TextStyle(
                        color: AppTheme.primaryTextColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      items: [
                        if (!isAnimal)
                          const DropdownMenuItem<CaregiverProfile?>(
                            value: null,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.person_pin_rounded,
                                  size: 18,
                                  color: Colors.grey,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Mi Perfil Personal (Yo)',
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ...availableProfiles.map((p) {
                          Color pColor =
                              isAnimal ? Colors.teal : AppTheme.primaryColor;
                          try {
                            pColor = Color(
                              int.parse(p.colorHex.replaceFirst('#', '0xFF')),
                            );
                          } catch (_) {}
                          return DropdownMenuItem<CaregiverProfile?>(
                            value: p,
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: pColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${p.name} (${isAnimal ? (p.species ?? "Mascota") : p.relationship})',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedProfile = val;
                          widget.prescriptionData['targetProfileId'] = val?.id;
                          widget.prescriptionData['targetProfileName'] =
                              val?.name;
                        });
                      },
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppTheme.borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color:
                                isAnimal ? Colors.teal : AppTheme.primaryColor,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppTheme.borderColor),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          _buildField(
            label: 'Nombre del Medicamento',
            controller: _nameController,
            enabled: !isSaved,
          ),
          const SizedBox(height: 12),
          Text(
            'Presentación',
            style: TextStyle(fontSize: 12, color: AppTheme.secondaryTextColor),
          ),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            initialValue: _selectedPresentacion,
            dropdownColor: Theme.of(context).cardColor,
            style: TextStyle(
              color: AppTheme.primaryTextColor,
              fontWeight: FontWeight.w600,
            ),
            items:
                _presentaciones.map((p) {
                  return DropdownMenuItem<String>(value: p, child: Text(p));
                }).toList(),
            onChanged:
                isSaved
                    ? null
                    : (val) {
                      if (val != null) {
                        setState(() => _selectedPresentacion = val);
                      }
                    },
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppTheme.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppTheme.primaryColor),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppTheme.borderColor),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildField(
                  label: 'Dosis por toma',
                  controller: _dosisController,
                  keyboardType: TextInputType.number,
                  enabled: !isSaved,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildField(
                  label: 'Intervalo (horas)',
                  controller: _intervaloController,
                  keyboardType: TextInputType.number,
                  enabled: !isSaved,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildField(
            label: 'Duración (días)',
            controller: _duracionController,
            keyboardType: TextInputType.number,
            enabled: !isSaved,
          ),
          const SizedBox(height: 12),
          _buildField(
            label: 'Notas adicionales',
            controller: _notasController,
            enabled: !isSaved,
          ),
          const SizedBox(height: 16),
          if (!isSaved)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  final name = _nameController.text.trim();
                  final pres = _selectedPresentacion;
                  final interval = int.tryParse(_intervaloController.text) ?? 8;
                  final dosis = int.tryParse(_dosisController.text) ?? 1;
                  final duration = int.tryParse(_duracionController.text) ?? 7;
                  final notas = _notasController.text.trim();

                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'El nombre del medicamento es requerido.',
                        ),
                      ),
                    );
                    return;
                  }

                  widget.onSaved(
                    name,
                    pres,
                    interval,
                    dosis,
                    duration,
                    notas,
                    _selectedProfile,
                  );
                },
                child: const Text('Confirmar y Guardar'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppTheme.secondaryTextColor),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          enabled: enabled,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color:
                enabled
                    ? AppTheme.primaryTextColor
                    : AppTheme.secondaryTextColor,
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppTheme.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppTheme.primaryColor),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppTheme.borderColor),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppTheme.borderColor),
            ),
          ),
        ),
      ],
    );
  }
}
