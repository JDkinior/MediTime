import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

// Widgets, servicios y el notifier
import 'package:meditime/widgets/primary_button.dart';
import 'package:meditime/widgets/styled_text_field.dart';
import 'package:meditime/services/auth_service.dart';
import 'package:meditime/services/firestore_service.dart';
import 'package:meditime/services/storage_service.dart';
import 'package:meditime/notifiers/profile_notifier.dart'; // Se importa el notifier
import 'package:meditime/theme/app_theme.dart'; // Se importa el tema para estilos consistentes

class PerfilPage extends StatefulWidget {
  final bool isEditing;
  final VoidCallback toggleEditing;
  // Se eliminan los callbacks onImageChanged y onNameChanged

  const PerfilPage({
    super.key,
    required this.isEditing,
    required this.toggleEditing,
  });

  @override
  _PerfilPageState createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  // Controladores y estado local de la página
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _bloodTypeController = TextEditingController();
  final TextEditingController _allergiesController = TextEditingController();
  final TextEditingController _medicationsController = TextEditingController();
  final TextEditingController _medicalHistoryController = TextEditingController();

  String? _profileImageUrl; // Puede ser una URL de red o una ruta de archivo local
  final ImagePicker _picker = ImagePicker();
  bool _isSaveButtonEnabled = false;
  bool _isPickingImage = false;
  bool _isSaving = false;

  // Variables para guardar el estado original y poder cancelar la edición
  String? _originalName;
  String? _originalPhone;
  String? _originalEmail;
  String? _originalDob;
  String? _originalBloodType;
  String? _originalAllergies;
  String? _originalMedications;
  String? _originalMedicalHistory;
  String? _originalProfileImageUrl;

  @override
  void initState() {
    super.initState();
    // Carga los datos del perfil después de que el widget se construya
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfileData();
    });
    _addListeners();
  }

  void _addListeners() {
    _nameController.addListener(_updateSaveButtonState);
    _phoneController.addListener(_updateSaveButtonState);
    _emailController.addListener(_updateSaveButtonState);
    _dobController.addListener(_updateSaveButtonState);
    _bloodTypeController.addListener(_updateSaveButtonState);
    _allergiesController.addListener(_updateSaveButtonState);
    _medicationsController.addListener(_updateSaveButtonState);
    _medicalHistoryController.addListener(_updateSaveButtonState);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    _bloodTypeController.dispose();
    _allergiesController.dispose();
    _medicationsController.dispose();
    _medicalHistoryController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PerfilPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si se cancela la edición, se revierten los cambios
    if (oldWidget.isEditing && !widget.isEditing) {
      _resetToOriginalData();
    }
  }

 Future<void> _loadProfileData() async {
    if (!mounted) return;
    final authService = context.read<AuthService>();
    final firestoreService = context.read<FirestoreService>();
    final user = authService.currentUser;
    if (user == null) return;

    final profileNotifier = context.read<ProfileNotifier>();
    final doc = await firestoreService.getUserProfile(user.uid);
    final profileData = doc.data() as Map<String, dynamic>?;

    setState(() {
      _originalName = profileNotifier.userName ?? profileData?['name'] ?? '';
      _originalProfileImageUrl = profileNotifier.profileImageUrl ?? profileData?['profileImage'] ?? '';
      
      _originalPhone = profileData?['phone'] ?? '';
      _originalEmail = user.email ?? '';
      _originalDob = profileData?['dob'] ?? '';
      _originalBloodType = profileData?['bloodType'] ?? '';
      _originalAllergies = profileData?['allergies'] ?? '';
      _originalMedications = profileData?['medications'] ?? '';
      _originalMedicalHistory = profileData?['medicalHistory'] ?? '';
      
      _resetToOriginalData();
    });
  }

  void _resetToOriginalData() {
    setState(() {
        _nameController.text = _originalName ?? '';
        _phoneController.text = _originalPhone ?? '';
        _emailController.text = _originalEmail ?? '';
        _dobController.text = _originalDob ?? '';
        _bloodTypeController.text = _originalBloodType ?? '';
        _allergiesController.text = _originalAllergies ?? '';
        _medicationsController.text = _originalMedications ?? '';
        _medicalHistoryController.text = _originalMedicalHistory ?? '';
        _profileImageUrl = _originalProfileImageUrl;
        _updateSaveButtonState();
    });
  }

  void _updateSaveButtonState() {
    final hasChanged = _nameController.text != _originalName ||
          _phoneController.text != _originalPhone ||
          _dobController.text != _originalDob ||
          _bloodTypeController.text != _originalBloodType ||
          _allergiesController.text != _originalAllergies ||
          _medicationsController.text != _originalMedications ||
          _medicalHistoryController.text != _originalMedicalHistory ||
          _profileImageUrl != _originalProfileImageUrl;

    setState(() {
      _isSaveButtonEnabled = hasChanged;
    });
  }

  Future<void> _pickImage() async {
    if (_isPickingImage) return;
    setState(() => _isPickingImage = true);

    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null && mounted) {
        // Guardamos la RUTA LOCAL de la imagen temporalmente.
        // La subida a Firebase se hará solo al presionar "Guardar Cambios".
        setState(() {
            _profileImageUrl = pickedFile.path;
        });
        _updateSaveButtonState(); // Habilitamos el botón de guardar
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al seleccionar la imagen: $e')));
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  Future<void> _saveProfileData() async {
    if (!mounted) return;
    setState(() => _isSaving = true);

    final authService = context.read<AuthService>();
    final firestoreService = context.read<FirestoreService>();
    final storageService = context.read<StorageService>();
    final user = authService.currentUser;
    if (user == null) {
      setState(() => _isSaving = false);
      return;
    }

    String? finalImageUrl = _originalProfileImageUrl;

    // CÓDIGO CORREGIDO
    if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty && !_profileImageUrl!.startsWith('http')) {
        File imageFile = File(_profileImageUrl!);
        finalImageUrl = await storageService.uploadProfileImage(user.uid, imageFile);
    }

    final dataToSave = {
      'name': _nameController.text, 'phone': _phoneController.text,
      'dob': _dobController.text, 'bloodType': _bloodTypeController.text,
      'allergies': _allergiesController.text, 'medications': _medicationsController.text,
      'medicalHistory': _medicalHistoryController.text,
      'profileImage': finalImageUrl ?? '',
    };

    await firestoreService.saveUserProfile(user.uid, dataToSave);

    if (mounted) {
      // Notificamos a toda la app sobre los nuevos datos del perfil
      context.read<ProfileNotifier>().updateProfile(
            newName: _nameController.text,
            newImageUrl: finalImageUrl,
          );

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cambios guardados')));
      widget.toggleEditing(); // Salimos del modo edición
    }

    if (mounted) {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // El ProfileNotifier se usa para mostrar los datos en el header
    // sin necesidad de pasarlos por el constructor.
    final profile = context.watch<ProfileNotifier>();
    
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileHeader(profile),
            const SizedBox(height: 24),
            
            _buildSectionTitle('Datos Personales'),
            const SizedBox(height: 12),
            _buildEditableOrDisplayField(controller: _nameController, labelText: 'Nombre', hintText: 'Tu nombre completo'),
            const SizedBox(height: 12),
            _buildEditableOrDisplayField(controller: _phoneController, labelText: 'Número de Teléfono', hintText: 'Tu número de teléfono', keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            _buildEditableOrDisplayField(controller: _emailController, labelText: 'Correo', hintText: 'Tu correo', enabled: false),
            const SizedBox(height: 12),
            _buildEditableOrDisplayField(controller: _dobController, labelText: 'Fecha de Nacimiento', hintText: 'Ej: 01/01/1990', keyboardType: TextInputType.datetime),

            const SizedBox(height: 24),
            _buildSectionTitle('Datos Médicos'),
            const SizedBox(height: 12),
            _buildEditableOrDisplayField(controller: _bloodTypeController, labelText: 'Tipo de Sangre', hintText: 'Ej: O+'),
            const SizedBox(height: 12),
            _buildEditableOrDisplayField(controller: _allergiesController, labelText: 'Alergias', hintText: 'Ej: Penicilina'),
            const SizedBox(height: 12),
            _buildEditableOrDisplayField(controller: _medicationsController, labelText: 'Medicamentos Actuales', hintText: 'Los que tomas regularmente'),
            const SizedBox(height: 12),
            _buildEditableOrDisplayField(controller: _medicalHistoryController, labelText: 'Historial Médico', hintText: 'Condiciones médicas relevantes'),

            const SizedBox(height: 30),
            if (widget.isEditing)
              PrimaryButton(
                text: 'Guardar Cambios',
                isLoading: _isSaving,
                onPressed: _isSaveButtonEnabled ? _saveProfileData : null,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(ProfileNotifier profile) {
    // Determina qué imagen mostrar: la nueva seleccionada o la de la red
    ImageProvider<Object> backgroundImage;
    if (_profileImageUrl != null && _profileImageUrl!.startsWith('http')) {
      backgroundImage = NetworkImage(_profileImageUrl!);
    } else if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      backgroundImage = FileImage(File(_profileImageUrl!));
    } else {
      backgroundImage = const AssetImage('assets/profile_picture.png');
    }

    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: widget.isEditing && !_isPickingImage ? _pickImage : null,
            child: CircleAvatar(
              radius: 55,
              backgroundColor: Colors.white,
              child: CircleAvatar(
                radius: 52,
                backgroundImage: backgroundImage,
                child: widget.isEditing
                    ? Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withOpacity(0.4),
                        ),
                        child: Center(
                          child: _isPickingImage
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Icon(Icons.camera_alt, color: Colors.white, size: 30),
                        ),
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            // Muestra el nombre del controlador si se está editando, o el del notifier si no
            widget.isEditing ? _nameController.text : (profile.userName ?? 'Nombre de Usuario'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF4092E4)),
          ),
          Text(
            _emailController.text,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Text(
        title,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
      ),
    );
  }
  
  Widget _buildEditableOrDisplayField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
  }) {
    if (widget.isEditing) {
      return StyledTextField(
        controller: controller,
        labelText: labelText,
        hintText: hintText,
        keyboardType: keyboardType,
        enabled: enabled,
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Color.fromARGB(255, 241, 241, 241),
          borderRadius: BorderRadius.circular(20),
          boxShadow: kCustomBoxShadow,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    labelText.toUpperCase(),
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 11,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    controller.text.isNotEmpty ? controller.text : 'No especificado',
                    style: TextStyle(
                      fontSize: 16,
                      color: controller.text.isNotEmpty ? Colors.black87 : Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }
}