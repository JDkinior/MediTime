import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meditime/models/caregiver_profile.dart';
import 'package:meditime/notifiers/caregiver_notifier.dart';
import 'package:meditime/services/auth_service.dart';
import 'package:meditime/services/firestore_service.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:meditime/widgets/styled_text_field.dart';

class AddCaregiverProfileDialog extends StatefulWidget {
  final CaregiverProfile? initialProfile;
  
  const AddCaregiverProfileDialog({super.key, this.initialProfile});

  @override
  State<AddCaregiverProfileDialog> createState() => _AddCaregiverProfileDialogState();
}

class _AddCaregiverProfileDialogState extends State<AddCaregiverProfileDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

  // Tab 1: Vincular por Correo
  final _emailController = TextEditingController();

  // Tab 2: Crear Paciente Local
  final _nameController = TextEditingController();
  final _relationshipController = TextEditingController();
  final _roomNumberController = TextEditingController();
  final _categoryController = TextEditingController();
  final _bloodTypeController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _notesController = TextEditingController();

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
    
    if (widget.initialProfile != null) {
      final p = widget.initialProfile!;
      _nameController.text = p.name;
      _selectedColorHex = p.colorHex;
      _roomNumberController.text = p.roomNumber ?? '';
      _allergiesController.text = p.allergies ?? '';
      _notesController.text = p.notes ?? '';
      
      // Relationship
      if (_familyRelationships.contains(p.relationship) || _clinicRelationships.contains(p.relationship)) {
        _selectedRelationship = p.relationship;
      } else if (p.relationship.isNotEmpty) {
        _selectedRelationship = 'Personalizado';
        _relationshipController.text = p.relationship;
      }
      
      // Blood Type
      if (p.bloodType != null) {
        if (_bloodTypes.contains(p.bloodType)) {
          _selectedBloodType = p.bloodType;
        } else if (p.bloodType!.isNotEmpty) {
          _selectedBloodType = 'Personalizado';
          _bloodTypeController.text = p.bloodType!;
        }
      }
      
      // Category
      if (p.category != null) {
        if (_clinicCategories.contains(p.category)) {
          _selectedCategory = p.category;
        } else if (p.category!.isNotEmpty) {
          _selectedCategory = 'Personalizado';
          _categoryController.text = p.category!;
        }
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
    _notesController.dispose();
    super.dispose();
  }

  Color _colorFromHex(String hexColor) {
    hexColor = hexColor.toUpperCase().replaceAll("#", "");
    if (hexColor.length == 6) {
      hexColor = "FF$hexColor";
    }
    return Color(int.parse(hexColor, radix: 16));
  }

  Future<void> _linkByEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() => _isLoading = true);
    final firestoreService = context.read<FirestoreService>();
    final authService = context.read<AuthService>();
    final caregiverNotifier = context.read<CaregiverNotifier>();
    final userId = authService.currentUser?.uid;

    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Find user by email
      final query = await FirebaseFirestore.instance.collection('users').where('email', isEqualTo: email).get();
      if (query.docs.isEmpty) {
        throw Exception('Usuario no encontrado.');
      }
      final linkedUser = query.docs.first;
      
      final newProfile = CaregiverProfile(
        id: linkedUser.id, // Use their UID as profile ID
        name: linkedUser.data()['name'] ?? 'Usuario Vinculado',
        relationship: 'Familiar Vinculado',
        colorHex: _presetColors[0],
        isExternalUser: true,
        email: email,
        linkedUid: linkedUser.id,
      );

      await firestoreService.saveCaregiverProfile(userId, newProfile);
      await caregiverNotifier.loadProfiles(userId);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil vinculado exitosamente')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitLocalProfile() async {
    final name = _nameController.text.trim();
    final relationship = (_selectedRelationship == 'Personalizado' || _selectedRelationship == null) 
        ? _relationshipController.text.trim() 
        : _selectedRelationship!;
        
    final category = (_selectedCategory == 'Personalizado' || _selectedCategory == null)
        ? _categoryController.text.trim()
        : _selectedCategory!;
        
    final bloodType = (_selectedBloodType == 'Personalizado' || _selectedBloodType == 'No lo sé' || _selectedBloodType == null)
        ? _bloodTypeController.text.trim()
        : _selectedBloodType!;
    
    if (name.isEmpty || relationship.isEmpty) return;

    setState(() => _isLoading = true);
    final firestoreService = context.read<FirestoreService>();
    final authService = context.read<AuthService>();
    final caregiverNotifier = context.read<CaregiverNotifier>();
    final userId = authService.currentUser?.uid;

    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final CaregiverProfile newProfile;
      if (widget.initialProfile != null) {
        newProfile = CaregiverProfile(
          id: widget.initialProfile!.id,
          name: _nameController.text.trim(),
          relationship: relationship,
          colorHex: _selectedColorHex,
          isExternalUser: widget.initialProfile!.isExternalUser,
          email: widget.initialProfile!.email,
          linkedUid: widget.initialProfile!.linkedUid,
          roomNumber: _roomNumberController.text.trim().isEmpty ? null : _roomNumberController.text.trim(),
          category: category.isEmpty ? null : category,
          bloodType: bloodType.isEmpty ? null : bloodType,
          allergies: _allergiesController.text.trim().isEmpty ? null : _allergiesController.text.trim(),
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );
      } else {
        newProfile = CaregiverProfile(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: _nameController.text.trim(),
          relationship: relationship,
          colorHex: _selectedColorHex,
          isExternalUser: false,
          roomNumber: _roomNumberController.text.trim().isEmpty ? null : _roomNumberController.text.trim(),
          category: category.isEmpty ? null : category,
          bloodType: bloodType.isEmpty ? null : bloodType,
          allergies: _allergiesController.text.trim().isEmpty ? null : _allergiesController.text.trim(),
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );
      }

      await firestoreService.saveCaregiverProfile(userId, newProfile);
      await caregiverNotifier.loadProfiles(userId);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.initialProfile != null ? 'Perfil actualizado exitosamente' : 'Perfil creado exitosamente')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildVinculacionEmail() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Vincular con un usuario existente de MediTime.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 16),
        StyledTextField(
          controller: _emailController,
          labelText: 'Correo electrónico',
          hintText: 'ejemplo@correo.com',
          keyboardType: TextInputType.emailAddress,
        ),
      ],
    );
  }

  InputDecoration _buildDropdownDecoration(String labelText, bool isDark) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: TextStyle(color: AppTheme.secondaryTextColor),
      fillColor: isDark ? AppTheme.surfaceColor : Colors.white,
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: AppTheme.borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: AppTheme.borderColor),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
        borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    );
  }

  Widget _buildLocalProfileForm(bool isClinico) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Crear un perfil gestionado enteramente por ti.',
          style: TextStyle(color: AppTheme.secondaryTextColor, fontSize: 13),
        ),
        const SizedBox(height: 16),
        StyledTextField(
          controller: _nameController,
          labelText: 'Nombre / Alias',
          hintText: 'Ej: Mamá, Juan',
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          dropdownColor: Theme.of(context).cardColor,
          style: TextStyle(color: AppTheme.primaryTextColor, fontSize: 15),
          decoration: _buildDropdownDecoration(
            isClinico ? 'Relación / Identificador' : 'Parentesco',
            isDark,
          ),
          value: _selectedRelationship,
          items: (isClinico ? _clinicRelationships : _familyRelationships).map((String value) {
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
          const SizedBox(height: 12),
          StyledTextField(
            controller: _relationshipController,
            labelText: 'Especificar Relación',
            hintText: 'Ej: Tío, Cuidador',
          ),
        ],
        if (isClinico) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            dropdownColor: Theme.of(context).cardColor,
            style: TextStyle(color: AppTheme.primaryTextColor, fontSize: 15),
            decoration: _buildDropdownDecoration('Categoría / Piso', isDark),
            value: _selectedCategory,
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
            const SizedBox(height: 12),
            StyledTextField(
              controller: _categoryController,
              labelText: 'Especificar Categoría/Piso',
              hintText: 'Ej: Pabellón Sur, Terapia Intensiva',
            ),
          ],
          const SizedBox(height: 12),
          StyledTextField(
            controller: _roomNumberController,
            labelText: 'Habitación / Cama',
            hintText: 'Ej: 204B',
          ),
        ],
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          dropdownColor: Theme.of(context).cardColor,
          style: TextStyle(color: AppTheme.primaryTextColor, fontSize: 15),
          decoration: _buildDropdownDecoration('Tipo de Sangre (Opcional)', isDark),
          value: _selectedBloodType,
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
          const SizedBox(height: 12),
          StyledTextField(
            controller: _bloodTypeController,
            labelText: 'Especificar Tipo de Sangre',
            hintText: 'Ej: O+',
          ),
        ],
        const SizedBox(height: 12),
        StyledTextField(
          controller: _allergiesController,
          labelText: 'Alergias (Opcional)',
          hintText: 'Ej: Penicilina',
        ),
        const SizedBox(height: 16),
        Text('Color identificador', style: TextStyle(color: AppTheme.primaryTextColor, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          children: _presetColors.map((hex) {
            return GestureDetector(
              onTap: () => setState(() => _selectedColorHex = hex),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _colorFromHex(hex),
                  shape: BoxShape.circle,
                  border: _selectedColorHex == hex
                      ? Border.all(color: AppTheme.primaryTextColor, width: 3)
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final caregiverNotifier = context.watch<CaregiverNotifier>();
    final isClinico = caregiverNotifier.modeType == CaregiverModeType.clinico;

    return Dialog(
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
        ),
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        child: Column(
          children: [
            Text(
              widget.initialProfile != null ? 'Editar Persona' : 'Agregar Persona',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryTextColor,
              ),
            ),
            if (widget.initialProfile == null) ...[
              const SizedBox(height: 16),
              TabBar(
                controller: _tabController,
                labelColor: AppTheme.primaryColor,
                unselectedLabelColor: AppTheme.secondaryTextColor,
                indicatorColor: AppTheme.primaryColor,
                tabs: const [
                  Tab(text: 'Vincular (Correo)'),
                  Tab(text: 'Crear Local'),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: widget.initialProfile != null
                  ? SingleChildScrollView(child: _buildLocalProfileForm(isClinico))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildVinculacionEmail(),
                        SingleChildScrollView(child: _buildLocalProfileForm(isClinico)),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : (widget.initialProfile != null || _tabController.index == 1 ? _submitLocalProfile : _linkByEmail),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        widget.initialProfile != null ? 'Guardar Cambios' : 'Guardar Perfil',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
