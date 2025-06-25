import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

// Widgets y servicios
import 'package:meditime/widgets/primary_button.dart';
import 'package:meditime/widgets/styled_text_field.dart';
import 'package:meditime/services/auth_service.dart';
import 'package:meditime/services/firestore_service.dart';
import 'package:meditime/services/storage_service.dart';

class PerfilPage extends StatefulWidget {
  final bool isEditing;
  final VoidCallback toggleEditing;
  final Function(String) onImageChanged;
  final Function(String) onNameChanged;

  const PerfilPage({
    super.key,
    required this.isEditing,
    required this.toggleEditing,
    required this.onImageChanged,
    required this.onNameChanged,
  });

  @override
  _PerfilPageState createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  // --- Lógica de estado y controladores (sin cambios) ---
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _bloodTypeController = TextEditingController();
  final TextEditingController _allergiesController = TextEditingController();
  final TextEditingController _medicationsController = TextEditingController();
  final TextEditingController _medicalHistoryController = TextEditingController();
  String? _profileImageUrl;
  final ImagePicker _picker = ImagePicker();
  bool _isSaveButtonEnabled = false;
  bool _isPickingImage = false;
  bool _isSaving = false;
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
    if (oldWidget.isEditing && !widget.isEditing) {
      _loadProfileData();
    }
  }

  // --- Lógica de datos (sin cambios) ---
  Future<void> _loadProfileData() async {
    if (!mounted) return;
    final authService = context.read<AuthService>();
    final firestoreService = context.read<FirestoreService>();
    final user = authService.currentUser;
    if (user == null) return;
    final doc = await firestoreService.getUserProfile(user.uid);
    final profileData = doc.data() as Map<String, dynamic>?;
    setState(() {
      _nameController.text = profileData?['name'] ?? '';
      _phoneController.text = profileData?['phone'] ?? '';
      _emailController.text = user.email ?? '';
      _dobController.text = profileData?['dob'] ?? '';
      _bloodTypeController.text = profileData?['bloodType'] ?? '';
      _allergiesController.text = profileData?['allergies'] ?? '';
      _medicationsController.text = profileData?['medications'] ?? '';
      _medicalHistoryController.text = profileData?['medicalHistory'] ?? '';
      _profileImageUrl = profileData?['profileImage'] ?? '';
      _originalName = _nameController.text;
      _originalPhone = _phoneController.text;
      _originalEmail = _emailController.text;
      _originalDob = _dobController.text;
      _originalBloodType = _bloodTypeController.text;
      _originalAllergies = _allergiesController.text;
      _originalMedications = _medicationsController.text;
      _originalMedicalHistory = _medicalHistoryController.text;
      _originalProfileImageUrl = _profileImageUrl;
      _updateSaveButtonState();
    });
  }

  void _updateSaveButtonState() {
    setState(() {
      _isSaveButtonEnabled = _nameController.text != _originalName ||
          _phoneController.text != _originalPhone ||
          _emailController.text != _originalEmail ||
          _dobController.text != _originalDob ||
          _bloodTypeController.text != _originalBloodType ||
          _allergiesController.text != _originalAllergies ||
          _medicationsController.text != _originalMedications ||
          _medicalHistoryController.text != _originalMedicalHistory ||
          _profileImageUrl != _originalProfileImageUrl;
    });
  }

  Future<void> _saveProfileData() async {
    if (!mounted) return;
    setState(() => _isSaving = true);
    final authService = context.read<AuthService>();
    final firestoreService = context.read<FirestoreService>();
    final user = authService.currentUser;
    if (user == null) {
        setState(() => _isSaving = false);
        return;
    }
    final dataToSave = {
      'name': _nameController.text, 'phone': _phoneController.text,
      'email': _emailController.text, 'dob': _dobController.text,
      'bloodType': _bloodTypeController.text, 'allergies': _allergiesController.text,
      'medications': _medicationsController.text, 'medicalHistory': _medicalHistoryController.text,
      'profileImage': _profileImageUrl ?? '',
    };
    await firestoreService.saveUserProfile(user.uid, dataToSave);
    if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cambios guardados')));
        widget.onNameChanged(_nameController.text);
        widget.toggleEditing();
        setState(() => _isSaving = false);
    }
  }

  Future<void> _pickImage() async {
    if (_isPickingImage) return;
    setState(() => _isPickingImage = true);
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null && mounted) {
        final authService = context.read<AuthService>();
        final storageService = context.read<StorageService>();
        final user = authService.currentUser;
        if (user == null) return;
        File imageFile = File(pickedFile.path);
        String downloadUrl = await storageService.uploadProfileImage(user.uid, imageFile);
        if (mounted) {
          setState(() { _profileImageUrl = downloadUrl; });
          widget.onImageChanged(downloadUrl);
          _updateSaveButtonState();
        }
      }
    } catch (e) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al subir la imagen: $e')));
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  // --- Inicio de la nueva UI ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Usamos el color de fondo consistente con el resto de la app
      backgroundColor: const Color(0xFFF3F3F3),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileHeader(),
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

  Widget _buildProfileHeader() {
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
                backgroundImage: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                    ? NetworkImage(_profileImageUrl!)
                    : const AssetImage('assets/profile_picture.png') as ImageProvider,
                child: widget.isEditing
                    ? Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withOpacity(0.4),
                        ),
                        child: const Center(
                          child: Icon(Icons.camera_alt, color: Colors.white, size: 30),
                        ),
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _nameController.text.isNotEmpty ? _nameController.text : "Nombre de Usuario",
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2F71B6)),
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
        // El StyledTextField ya maneja el estilo, no necesitamos lógica extra aquí
      );
    } else {
      // Este es el modo de visualización, que ahora usa un contenedor con
      // el estilo de sombra y borde de tu app.
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color.fromARGB(15, 47, 109, 180),
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
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
