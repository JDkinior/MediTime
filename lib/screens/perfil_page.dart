import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../data/perfil_data.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';
import 'package:image/image.dart' as img;


String? _originalName;
String? _originalPhone;
String? _originalEmail;
String? _originalDob;
String? _originalBloodType;
String? _originalAllergies;
String? _originalMedications;
String? _originalMedicalHistory;
String? _originalProfileImageUrl;

class PerfilPage extends StatefulWidget {
  final bool isEditing;
  final VoidCallback toggleEditing;
  final Function(String) onImageChanged; // Callback para notificar cambios en la imagen
  final Function(String) onNameChanged; // Callback para notificar cambios en el nombre

  const PerfilPage({
    super.key,
    required this.isEditing,
    required this.toggleEditing,
    required this.onImageChanged,
    required this.onNameChanged, // Añadir el callback como parámetro requerido
  });

  static Future<void> saveProfileData(BuildContext context) async {
    final state = context.findAncestorStateOfType<_PerfilPageState>();
    await state?._saveProfileData();
  }

  @override
  _PerfilPageState createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _bloodTypeController = TextEditingController();
  final TextEditingController _allergiesController = TextEditingController();
  final TextEditingController _medicationsController = TextEditingController();
  final TextEditingController _medicalHistoryController = TextEditingController();
  String? _profileImageUrl; // Ahora guardamos la URL en lugar de un archivo local
  final ImagePicker _picker = ImagePicker();
  bool _isSaveButtonEnabled = false;
  bool _isPickingImage = false; // <-- Añade esta línea

@override
void initState() {
    super.initState();
    _loadProfileData();
    _updateSaveButtonState();

    // Agregar listeners para todos los controladores
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
    // Remover los listeners y liberar recursos
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
      _loadProfileData(); // Recargar datos si se sale del modo edición
    }
  }

Future<void> _loadProfileData() async {
    final profileData = await PerfilData.loadProfileDataFromFirestore();
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '';

    setState(() {
      _nameController.text = profileData?[PerfilData.keyName] ?? '';
      _phoneController.text = profileData?[PerfilData.keyPhone] ?? '';
      _emailController.text = email;
      _dobController.text = profileData?[PerfilData.keyDob] ?? '';
      _bloodTypeController.text = profileData?[PerfilData.keyBloodType] ?? '';
      _allergiesController.text = profileData?[PerfilData.keyAllergies] ?? '';
      _medicationsController.text = profileData?[PerfilData.keyMedications] ?? '';
      _medicalHistoryController.text = profileData?[PerfilData.keyMedicalHistory] ?? '';
      _profileImageUrl = profileData?[PerfilData.keyProfileImage] ?? '';

      // Guardar los valores originales
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
    await PerfilData.saveProfileDataToFirestore(
      name: _nameController.text,
      phone: _phoneController.text,
      email: _emailController.text,
      dob: _dobController.text,
      bloodType: _bloodTypeController.text,
      allergies: _allergiesController.text,
      medications: _medicationsController.text,
      medicalHistory: _medicalHistoryController.text,
      profileImagePath: _profileImageUrl ?? '', // Guardar la URL de la imagen
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cambios guardados'),
        duration: Duration(seconds: 2),
      ),
    );

    widget.toggleEditing();
  }

Future<void> _pickImage() async {
  // Evita múltiples aperturas
  if (_isPickingImage) return; 

  setState(() {
    _isPickingImage = true;
  });

  try {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      File imageFile = File(pickedFile.path);
      String? downloadUrl = await _uploadImageToFirebase(imageFile);

      if (downloadUrl != null && mounted) {
        setState(() {
          _profileImageUrl = downloadUrl;
        });
        widget.onImageChanged(downloadUrl);
        _updateSaveButtonState();
      }
    }
  } catch (e) {
    print("Error al seleccionar imagen: $e");
  } finally {
    if (mounted) {
      setState(() {
        _isPickingImage = false;
      });
    }
  }
}


  Future<Uint8List> _compressImage(File imageFile) async {
    final originalImage = img.decodeImage(await imageFile.readAsBytes());
    final resizedImage = img.copyResize(originalImage!, width: 300);
    final compressedImage = img.encodeJpg(resizedImage, quality: 70);
    return Uint8List.fromList(compressedImage);
  }

  Future<String?> _uploadImageToFirebase(File imageFile) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      Uint8List compressedImage = await _compressImage(imageFile);
      String fileName = 'profile_images/${user.uid}.jpg';
      Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
      await storageRef.putData(compressedImage);

      String downloadUrl = await storageRef.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print("Error al subir la imagen: $e");
      return null;
    }
  }


  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: widget.isEditing && !_isPickingImage ? _pickImage : null, 
              child: CircleAvatar(
                radius: 50,
                backgroundImage: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                    ? NetworkImage(_profileImageUrl!) // Cargar desde la URL
                    : const AssetImage('assets/profile_picture.png') as ImageProvider,
              ),
            ),
            const SizedBox(height: 20),
            _buildSectionTitle('Datos Personales'),
            const SizedBox(height: 10),
            _buildEditableTextField(
                controller: _nameController, labelText: 'Nombre'),
            const SizedBox(height: 10),
            _buildEditableTextField(
              controller: _phoneController,
              labelText: 'Número de Teléfono',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 10),
            _buildEditableTextField(
              controller: _emailController,
              labelText: 'Correo',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 10),
            _buildEditableTextField(
              controller: _dobController,
              labelText: 'Fecha de Nacimiento',
              keyboardType: TextInputType.datetime,
            ),
            const SizedBox(height: 20),
            _buildSectionTitle('Datos Médicos'),
            const SizedBox(height: 10),
            _buildEditableTextField(
                controller: _bloodTypeController, labelText: 'Tipo de Sangre'),
            const SizedBox(height: 10),
            _buildEditableTextField(
                controller: _allergiesController, labelText: 'Alergias'),
            const SizedBox(height: 10),
            _buildEditableTextField(
                controller: _medicationsController,
                labelText: 'Medicamentos Actuales'),
            const SizedBox(height: 10),
            _buildEditableTextField(
                controller: _medicalHistoryController,
                labelText: 'Historial Médico'),
            const SizedBox(height: 20),
            Visibility(
              visible: widget.isEditing,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  fixedSize: const Size(400, 60),
                  backgroundColor: _isSaveButtonEnabled
                      ? Colors.blue
                      : Colors.grey, // Color del botón
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50), // Radio del botón
                  ),
                  foregroundColor: Colors.white, // Color del texto
                ),
                onPressed: _isSaveButtonEnabled ? _saveProfileData : null,
                child: const Text(
                  'Guardar',
                  style: TextStyle(
                      fontSize: 17), // Ajusta el tamaño del texto aquí
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildEditableTextField({
    required TextEditingController controller,
    required String labelText,
    TextInputType keyboardType = TextInputType.text,
  }) {
    // No necesitas añadir el listener aquí porque ya lo has añadido en initState
    return widget.isEditing
        ? TextField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(25.0), // Hace los bordes redondeados
              ),
              labelText: labelText,
            ),
          )
        : _buildDisplayField(controller.text, labelText);
  }

  Widget _buildDisplayField(String value, String labelText) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        children: [
          Text(
            '$labelText: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(value.isNotEmpty ? value : 'N/A'),
          ),
        ],
      ),
    );
  }
}
