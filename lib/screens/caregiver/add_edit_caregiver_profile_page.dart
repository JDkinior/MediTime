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

  const AddEditCaregiverProfilePage({super.key, this.initialProfile});

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

  final List<String> _presetColors = [
    '#4F46E5', // Indigo Suave
    '#F43F5E', // Rosa Coral
    '#10B981', // Verde Esmeralda
    '#F59E0B', // Ámbar Miel
    '#8B5CF6', // Violeta Lavanda
    '#0EA5E9', // Azul Celeste
    '#14B8A6', // Menta Turquesa
    '#F97316', // Terracota
  ];
  String _selectedColorHex = '#4F46E5';

  String? _selectedRelationship;
  String? _selectedBloodType;
  String? _selectedCategory;

  final List<String> _bloodTypes = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-', 'No lo sé', 'Personalizado'];
  final List<String> _familyRelationships = ['Hijo/a', 'Padre/Madre', 'Abuelo/a', 'Pareja', 'Hermano/a', 'Personalizado'];
  final List<String> _clinicRelationships = ['Paciente', 'Residente', 'Personalizado'];
  final List<String> _clinicCategories = ['Piso 1', 'Piso 2', 'Piso 3', 'Piso 4', 'Pabellón A', 'Pabellón B', 'Personalizado'];

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

      if (_familyRelationships.contains(p.relationship) || _clinicRelationships.contains(p.relationship)) {
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
        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
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
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre del paciente es obligatorio.')),
      );
      return;
    }

    String relationship = _selectedRelationship ?? 'Paciente';
    if (relationship == 'Personalizado') {
      relationship = _relationshipController.text.trim();
      if (relationship.isEmpty) relationship = 'Paciente';
    }

    String? category = _selectedCategory;
    if (category == 'Personalizado') {
      category = _categoryController.text.trim();
    }

    String? bloodType = _selectedBloodType;
    if (bloodType == 'Personalizado') {
      bloodType = _bloodTypeController.text.trim();
    }

    setState(() => _isLoading = true);
    try {
      final authService = context.read<AuthService>();
      final firestoreService = context.read<FirestoreService>();
      final caregiverNotifier = context.read<CaregiverNotifier>();
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
      );

      await firestoreService.saveCaregiverProfile(currentUser.uid, profile);
      await caregiverNotifier.loadProfiles(currentUser.uid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.initialProfile != null ? '¡Paciente actualizado con éxito!' : '¡Paciente agregado con éxito!',
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
    context.watch<PreferenceNotifier>();
    final caregiverNotifier = context.watch<CaregiverNotifier>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isClinico = caregiverNotifier.modeType == CaregiverModeType.clinico;
    final relationshipOptions = isClinico ? _clinicRelationships : _familyRelationships;

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
          widget.initialProfile != null ? 'Editar Paciente' : 'Agregar Paciente',
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
                  tabs: const [
                    Tab(text: 'Perfil Gestionado'),
                    Tab(text: 'Vincular por Correo'),
                  ],
                ),
              ),

            Expanded(
              child: widget.initialProfile != null
                  ? _buildLocalForm(isDark, isClinico, relationshipOptions)
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildLocalForm(isDark, isClinico, relationshipOptions),
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
            border: Border.all(color: AppTheme.borderColor),
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
                    child: const Icon(Icons.link_rounded, color: AppTheme.primaryColor, size: 22),
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

  Widget _buildLocalForm(bool isDark, bool isClinico, List<String> relationshipOptions) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Section 1: General Info Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.borderColor),
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
                    child: Icon(isClinico ? Icons.hotel_rounded : Icons.person_rounded, color: AppTheme.primaryColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Información Principal',
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
                labelText: 'Nombre / Alias del Paciente',
                hintText: 'Ej: Juan David',
              ),
              const SizedBox(height: 20),

              DropdownButtonFormField<String>(
                dropdownColor: Theme.of(context).cardColor,
                style: TextStyle(color: AppTheme.primaryTextColor, fontSize: 15),
                decoration: _buildDropdownDecoration(isClinico ? 'Relación / Rol' : 'Relación Familiar', isDark),
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
                  labelText: 'Especificar Relación',
                  hintText: 'Ej: Tío, Cuidador',
                ),
              ],

              if (isClinico) ...[
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  dropdownColor: Theme.of(context).cardColor,
                  style: TextStyle(color: AppTheme.primaryTextColor, fontSize: 15),
                  decoration: _buildDropdownDecoration('Categoría / Piso', isDark),
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
                    labelText: 'Especificar Categoría/Piso',
                    hintText: 'Ej: Pabellón Sur, Terapia Intensiva',
                  ),
                ],
                const SizedBox(height: 20),
                StyledTextField(
                  controller: _roomNumberController,
                  labelText: 'Habitación / Cama',
                  hintText: 'Ej: 204B',
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
            border: Border.all(color: AppTheme.borderColor),
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
                    child: const Icon(Icons.medical_services_rounded, color: AppTheme.primaryColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Información Médica (Opcional)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryTextColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

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
              StyledTextField(
                controller: _allergiesController,
                labelText: 'Alergias o Observaciones',
                hintText: 'Ej: Penicilina, Intolerancia a la lactosa',
              ),
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
            border: Border.all(color: AppTheme.borderColor),
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
                    child: const Icon(Icons.palette_rounded, color: AppTheme.primaryColor, size: 22),
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
                    widget.initialProfile != null ? 'Guardar Cambios' : 'Guardar Paciente',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
