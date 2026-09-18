import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meditime/models/caregiver_profile.dart';
import 'package:meditime/notifiers/caregiver_notifier.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/services/auth_service.dart';
import 'package:meditime/services/firestore_service.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:meditime/widgets/styled_text_field.dart';

class AddEditCaregiverProfilePage extends StatefulWidget {
  final CaregiverProfile? initialProfile;
  final bool isAnimalMode;

  const AddEditCaregiverProfilePage({
    super.key,
    this.initialProfile,
    this.isAnimalMode = false,
  });

  @override
  State<AddEditCaregiverProfilePage> createState() => _AddEditCaregiverProfilePageState();
}

class _AddEditCaregiverProfilePageState extends State<AddEditCaregiverProfilePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

  // Tab 1: Vincular por Correo
  final _emailController = TextEditingController();

  // Tab 2: Perfil Local
  final _nameController = TextEditingController();
  final _relationshipController = TextEditingController();
  final _roomNumberController = TextEditingController();
  final _categoryController = TextEditingController();
  final _bloodTypeController = TextEditingController();
  final _allergiesController = TextEditingController();

  // Campos específicos de Animales / Veterinaria
  final _speciesController = TextEditingController();
  final _breedController = TextEditingController();
  final _weightController = TextEditingController();
  final _microchipController = TextEditingController();
  final _notesController = TextEditingController();

  final List<String> _presetColors = [
    '#15803D', // Verde Veterinario
    '#047857', // Esmeralda Oscuro
    '#4F46E5', // Indigo Suave
    '#F43F5E', // Rosa Coral
    '#10B981', // Verde Esmeralda
    '#F59E0B', // Ámbar Miel
    '#8B5CF6', // Violeta Lavanda
    '#0EA5E9', // Azul Celeste
    '#14B8A6', // Menta Turquesa
    '#F97316', // Terracota
  ];
  String _selectedColorHex = '#15803D';

  String? _selectedRelationship;
  String? _selectedBloodType;
  String? _selectedCategory;
  String? _selectedSpecies;

  final List<String> _bloodTypes = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-', 'No lo sé', 'Personalizado'];
  final List<String> _familyRelationships = ['Hijo/a', 'Padre/Madre', 'Abuelo/a', 'Pareja', 'Hermano/a', 'Personalizado'];
  final List<String> _clinicRelationships = ['Paciente', 'Residente', 'Personalizado'];
  final List<String> _animalRoleOptions = ['Mascota propia', 'Paciente en clínica', 'En observación', 'En adopción', 'Personalizado'];
  final List<String> _clinicCategories = ['Piso 1', 'Piso 2', 'Piso 3', 'Piso 4', 'Pabellón A', 'Pabellón B', 'Personalizado'];
  final List<String> _speciesOptions = [
    'Canino (Perro)',
    'Felino (Gato)',
    'Equino (Caballo)',
    'Bovino',
    'Ave',
    'Roedor / Conejo',
    'Porcino',
    'Exótico',
    'Personalizado',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    final p = widget.initialProfile;
    if (p != null) {
      _nameController.text = p.name;
      _roomNumberController.text = p.roomNumber ?? '';
      _allergiesController.text = p.allergies ?? '';
      _selectedColorHex = p.colorHex;

      if (_bloodTypes.contains(p.bloodType)) {
        _selectedBloodType = p.bloodType;
      } else if (p.bloodType != null && p.bloodType!.isNotEmpty) {
        _selectedBloodType = 'Personalizado';
        _bloodTypeController.text = p.bloodType!;
      }

      if (_familyRelationships.contains(p.relationship) || _clinicRelationships.contains(p.relationship) || _animalRoleOptions.contains(p.relationship)) {
        _selectedRelationship = p.relationship;
      } else if (p.relationship.isNotEmpty) {
        _selectedRelationship = 'Personalizado';
        _relationshipController.text = p.relationship;
      }

      if (_clinicCategories.contains(p.category)) {
        _selectedCategory = p.category;
      } else if (p.category != null && p.category!.isNotEmpty) {
        _selectedCategory = 'Personalizado';
        _categoryController.text = p.category!;
      }

      if (_speciesOptions.contains(p.species)) {
        _selectedSpecies = p.species;
      } else if (p.species != null && p.species!.isNotEmpty) {
        _selectedSpecies = 'Personalizado';
        _speciesController.text = p.species!;
      }

      _breedController.text = p.breed ?? '';
      _weightController.text = p.weight != null ? p.weight.toString() : '';
      _microchipController.text = p.microchip ?? '';
      _notesController.text = p.notes ?? '';
    } else {
      if (!widget.isAnimalMode) {
        _selectedColorHex = '#4F46E5';
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _nameController.dispose();
    _relationshipController.dispose();
    _roomNumberController.dispose();
    _categoryController.dispose();
    _bloodTypeController.dispose();
    _allergiesController.dispose();
    _speciesController.dispose();
    _breedController.dispose();
    _weightController.dispose();
    _microchipController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Color _colorFromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  InputDecoration _buildDropdownDecoration(String labelText, bool isDark) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: TextStyle(color: AppTheme.secondaryTextColor, fontSize: 14),
      filled: true,
      fillColor: isDark ? AppTheme.backgroundColor : const Color(0xFFF4F7FC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppTheme.borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
      ),
    );
  }

  Future<void> _submitLinkUser() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingresa un correo electrónico.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final authService = context.read<AuthService>();
      final firestoreService = context.read<FirestoreService>();
      final caregiverNotifier = context.read<CaregiverNotifier>();
      final currentUser = authService.currentUser;

      if (currentUser == null) return;

      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se encontró ningún usuario con ese correo.')),
          );
        }
        return;
      }

      final targetUserDoc = querySnapshot.docs.first;
      final targetUserData = targetUserDoc.data();
      final targetUid = targetUserDoc.id;
      final targetName = targetUserData['name'] ?? targetUserData['firstName'] ?? 'Usuario Vinculado';

      if (targetUid == currentUser.uid) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No puedes vincularte a ti mismo.')),
          );
        }
        return;
      }

      final profile = CaregiverProfile(
        id: targetUid,
        name: targetName,
        relationship: 'Familiar Vinculado',
        colorHex: _presetColors[0],
        isExternalUser: true,
        email: email,
        linkedUid: targetUid,
      );

      await firestoreService.saveCaregiverProfile(currentUser.uid, profile);
      await firestoreService.ensureCaregiverLink(currentUser.uid, targetUid);
      await caregiverNotifier.loadProfiles(currentUser.uid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('¡Usuario $targetName vinculado con éxito!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al vincular: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitLocalUser() async {
    final name = _nameController.text.trim();
    final prefNotifier = context.read<PreferenceNotifier>();
    final caregiverNotifier = context.read<CaregiverNotifier>();
    final isAnimal = widget.isAnimalMode ||
        (widget.initialProfile?.isAnimal ?? false) ||
        prefNotifier.isAnimalMode ||
        caregiverNotifier.modeType == CaregiverModeType.veterinario;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAnimal ? 'El nombre de la mascota es obligatorio.' : 'El nombre del paciente es obligatorio.',
          ),
        ),
      );
      return;
    }

    final defaultRel = isAnimal ? 'Mascota' : 'Paciente';
    String relationship = _selectedRelationship ?? defaultRel;
    if (relationship == 'Personalizado') {
      relationship = _relationshipController.text.trim();
      if (relationship.isEmpty) relationship = defaultRel;
    }

    String? category = _selectedCategory;
    if (category == 'Personalizado') {
      category = _categoryController.text.trim();
    }

    String? bloodType = _selectedBloodType;
    if (bloodType == 'Personalizado') {
      bloodType = _bloodTypeController.text.trim();
    }

    String? species = _selectedSpecies;
    if (species == 'Personalizado') {
      species = _speciesController.text.trim();
    }

    setState(() => _isLoading = true);
    try {
      final authService = context.read<AuthService>();
      final firestoreService = context.read<FirestoreService>();
      final currentUser = authService.currentUser;

      if (currentUser == null) return;

      final id = widget.initialProfile?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
      final profile = CaregiverProfile(
        id: id,
        name: name,
        relationship: relationship,
        colorHex: _selectedColorHex,
        isExternalUser: widget.initialProfile?.isExternalUser ?? false,
        email: widget.initialProfile?.email,
        linkedUid: widget.initialProfile?.linkedUid,
        roomNumber: _roomNumberController.text.trim().isEmpty ? null : _roomNumberController.text.trim(),
        category: category?.isEmpty ?? true ? null : category,
        bloodType: bloodType?.isEmpty ?? true ? null : bloodType,
        allergies: _allergiesController.text.trim().isEmpty ? null : _allergiesController.text.trim(),
        isAnimal: isAnimal,
        species: species?.isEmpty ?? true ? null : species,
        breed: _breedController.text.trim().isEmpty ? null : _breedController.text.trim(),
        weight: _weightController.text.trim().isEmpty ? null : _weightController.text.trim(),
        microchip: _microchipController.text.trim().isEmpty ? null : _microchipController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      await firestoreService.saveCaregiverProfile(currentUser.uid, profile);
      await caregiverNotifier.loadProfiles(currentUser.uid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.initialProfile != null
                  ? (isAnimal ? '¡Mascota/Animal actualizada con éxito!' : '¡Paciente actualizado con éxito!')
                  : (isAnimal ? '¡Mascota/Animal agregada con éxito!' : '¡Paciente agregado con éxito!'),
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefNotifier = context.watch<PreferenceNotifier>();
    final caregiverNotifier = context.watch<CaregiverNotifier>();
    final isAnimal = widget.isAnimalMode ||
        (widget.initialProfile?.isAnimal ?? false) ||
        prefNotifier.isAnimalMode ||
        caregiverNotifier.modeType == CaregiverModeType.veterinario;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isClinico = caregiverNotifier.modeType == CaregiverModeType.clinico || caregiverNotifier.modeType == CaregiverModeType.veterinario;
    final relationshipOptions = isAnimal
        ? _animalRoleOptions
        : (isClinico ? _clinicRelationships : _familyRelationships);

    final cardBg = Theme.of(context).cardColor;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        backgroundColor: cardBg,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppTheme.primaryTextColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.initialProfile != null
              ? (isAnimal ? 'Editar Mascota / Animal' : 'Editar Paciente')
              : (isAnimal ? 'Agregar Mascota / Animal' : 'Agregar Paciente'),
          style: TextStyle(
            color: AppTheme.primaryTextColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (widget.initialProfile == null)
              Container(
                color: cardBg,
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppTheme.primaryColor,
                  unselectedLabelColor: AppTheme.secondaryTextColor,
                  indicatorColor: AppTheme.primaryColor,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  tabs: [
                    Tab(text: isAnimal ? 'Perfil de Mascota' : 'Perfil Gestionado'),
                    Tab(text: isAnimal ? 'Vincular Tutor' : 'Vincular por Correo'),
                  ],
                ),
              ),

            Expanded(
              child: widget.initialProfile != null
                  ? _buildLocalForm(isDark, isClinico, isAnimal, relationshipOptions)
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildLocalForm(isDark, isClinico, isAnimal, relationshipOptions),
                        _buildLinkUserForm(isDark),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkUserForm(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            border: (context.watch<PreferenceNotifier>().showCardBorder || context.watch<PreferenceNotifier>().highContrast)
                ? Border.all(color: AppTheme.borderColor)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.link_rounded, color: AppTheme.primaryColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vincular Cuenta Existente',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'El usuario debe tener una cuenta registrada en MediTime',
                          style: TextStyle(fontSize: 12, color: AppTheme.secondaryTextColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              StyledTextField(
                controller: _emailController,
                labelText: 'Correo electrónico del usuario',
                hintText: 'ejemplo@correo.com',
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submitLinkUser,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Vincular Usuario', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _buildLocalForm(bool isDark, bool isClinico, bool isAnimal, List<String> relationshipOptions) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Section 1: General Info Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            border: (context.watch<PreferenceNotifier>().showCardBorder || context.watch<PreferenceNotifier>().highContrast)
                ? Border.all(color: AppTheme.borderColor)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      isAnimal
                          ? Icons.pets_rounded
                          : (isClinico ? Icons.hotel_rounded : Icons.person_rounded),
                      color: AppTheme.primaryColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isAnimal ? 'Información de la Mascota' : 'Información Principal',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryTextColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              StyledTextField(
                controller: _nameController,
                labelText: isAnimal ? 'Nombre de la Mascota / Animal' : 'Nombre / Alias del Paciente',
                hintText: isAnimal ? 'Ej: Max, Luna, Toby' : 'Ej: Juan David',
              ),
              const SizedBox(height: 20),

              if (isAnimal) ...[
                DropdownButtonFormField<String>(
                  dropdownColor: Theme.of(context).cardColor,
                  style: TextStyle(color: AppTheme.primaryTextColor, fontSize: 15),
                  decoration: _buildDropdownDecoration('Especie', isDark),
                  initialValue: _selectedSpecies,
                  items: _speciesOptions.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      _selectedSpecies = newValue;
                    });
                  },
                ),
                if (_selectedSpecies == 'Personalizado') ...[
                  const SizedBox(height: 16),
                  StyledTextField(
                    controller: _speciesController,
                    labelText: 'Especificar Especie',
                    hintText: 'Ej: Hurón, Loro, Erizo',
                  ),
                ],
                const SizedBox(height: 20),

                StyledTextField(
                  controller: _breedController,
                  labelText: 'Raza / Cruce (Opcional)',
                  hintText: 'Ej: Golden Retriever, Siamés, Mestizo',
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: StyledTextField(
                        controller: _weightController,
                        labelText: 'Peso en kg (Opcional)',
                        hintText: 'Ej: 14.5',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StyledTextField(
                        controller: _microchipController,
                        labelText: 'Microchip / ID (Opcional)',
                        hintText: 'Ej: 981098...',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],

              DropdownButtonFormField<String>(
                dropdownColor: Theme.of(context).cardColor,
                style: TextStyle(color: AppTheme.primaryTextColor, fontSize: 15),
                decoration: _buildDropdownDecoration(
                  isAnimal ? 'Rol / Estado' : (isClinico ? 'Relación / Rol' : 'Relación Familiar'),
                  isDark,
                ),
                initialValue: _selectedRelationship,
                items: relationshipOptions.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedRelationship = newValue;
                  });
                },
              ),
              if (_selectedRelationship == 'Personalizado') ...[
                const SizedBox(height: 16),
                StyledTextField(
                  controller: _relationshipController,
                  labelText: 'Especificar Relación / Rol',
                  hintText: isAnimal ? 'Ej: En acogida temporal' : 'Ej: Tío, Cuidador',
                ),
              ],

              if (isClinico) ...[
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  dropdownColor: Theme.of(context).cardColor,
                  style: TextStyle(color: AppTheme.primaryTextColor, fontSize: 15),
                  decoration: _buildDropdownDecoration(
                    isAnimal ? 'Área / Sala Veterinaria' : 'Categoría / Piso',
                    isDark,
                  ),
                  initialValue: _selectedCategory,
                  items: _clinicCategories.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      _selectedCategory = newValue;
                    });
                  },
                ),
                if (_selectedCategory == 'Personalizado') ...[
                  const SizedBox(height: 16),
                  StyledTextField(
                    controller: _categoryController,
                    labelText: isAnimal ? 'Especificar Área/Sala' : 'Especificar Categoría/Piso',
                    hintText: isAnimal ? 'Ej: Quirófano, Hospitalización' : 'Ej: Pabellón Sur, Terapia Intensiva',
                  ),
                ],
                const SizedBox(height: 20),
                StyledTextField(
                  controller: _roomNumberController,
                  labelText: isAnimal ? 'Jaula / Box / Canil (Opcional)' : 'Habitación / Cama',
                  hintText: isAnimal ? 'Ej: Box 3, Jaula B' : 'Ej: 204B',
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Section 2: Medical Info Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            border: (context.watch<PreferenceNotifier>().showCardBorder || context.watch<PreferenceNotifier>().highContrast)
                ? Border.all(color: AppTheme.borderColor)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      isAnimal ? Icons.healing_rounded : Icons.medical_services_rounded,
                      color: AppTheme.primaryColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isAnimal ? 'Información Veterinaria (Opcional)' : 'Información Médica (Opcional)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryTextColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (!isAnimal) ...[
                DropdownButtonFormField<String>(
                  dropdownColor: Theme.of(context).cardColor,
                  style: TextStyle(color: AppTheme.primaryTextColor, fontSize: 15),
                  decoration: _buildDropdownDecoration('Tipo de Sangre', isDark),
                  initialValue: _selectedBloodType,
                  items: _bloodTypes.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      _selectedBloodType = newValue;
                    });
                  },
                ),
                if (_selectedBloodType == 'Personalizado') ...[
                  const SizedBox(height: 16),
                  StyledTextField(
                    controller: _bloodTypeController,
                    labelText: 'Especificar Tipo de Sangre',
                    hintText: 'Ej: O+',
                  ),
                ],
                const SizedBox(height: 20),
              ],

              StyledTextField(
                controller: _allergiesController,
                labelText: isAnimal ? 'Alergias o Contraindicaciones' : 'Alergias o Observaciones',
                hintText: isAnimal ? 'Ej: Ivermectina, Alergia al pollo' : 'Ej: Penicilina, Intolerancia a la lactosa',
              ),

              if (isAnimal) ...[
                const SizedBox(height: 20),
                StyledTextField(
                  controller: _notesController,
                  labelText: 'Notas Clínicas / Indicaciones del Veterinario',
                  hintText: 'Ej: No bañar por 10 días, suministrar pastillas con paté...',
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Section 3: Color Identifier Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            border: (context.watch<PreferenceNotifier>().showCardBorder || context.watch<PreferenceNotifier>().highContrast)
                ? Border.all(color: AppTheme.borderColor)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.palette_rounded, color: AppTheme.primaryColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Color Identificador',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryTextColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: _presetColors.map((hex) {
                  final isSelected = _selectedColorHex == hex;
                  final color = _colorFromHex(hex);

                  return GestureDetector(
                    onTap: () => setState(() => _selectedColorHex = hex),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                              color: color.withOpacity(0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                        ],
                        border: isSelected
                            ? Border.all(color: isDark ? Colors.white : AppTheme.primaryTextColor, width: 3)
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // Save Button
        SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submitLocalUser,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(
                    widget.initialProfile != null
                        ? 'Guardar Cambios'
                        : (isAnimal ? 'Guardar Mascota' : 'Guardar Paciente'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
