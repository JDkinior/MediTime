import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:showcaseview/showcaseview.dart';

// Widgets, servicios y el notifier
import 'package:meditime/services/auth_service.dart';
import 'package:meditime/services/firestore_service.dart';
import 'package:meditime/services/storage_service.dart';
import 'package:meditime/notifiers/profile_notifier.dart'; // Se importa el notifier
import 'package:meditime/theme/app_theme.dart'; // Se importa el tema para estilos consistentes
import 'package:meditime/screens/shared/localizador_farmacias_page.dart';
import 'package:meditime/widgets/treatment_form/form_field_wrapper.dart';
import 'package:meditime/screens/medication/paciente_receta_page.dart';

class PerfilPage extends StatefulWidget {
  final GlobalKey? profileKey;

  const PerfilPage({
    super.key,
    this.profileKey,
  });

  @override
  State<PerfilPage> createState() => _PerfilPageState();
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
  final TextEditingController _medicalHistoryController =
      TextEditingController();

  // FocusNodes for inline editing
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _dobFocusNode = FocusNode();
  final FocusNode _bloodTypeFocusNode = FocusNode();
  final FocusNode _allergiesFocusNode = FocusNode();
  final FocusNode _medicationsFocusNode = FocusNode();
  final FocusNode _medicalHistoryFocusNode = FocusNode();

  String?
  _profileImageUrl; // Puede ser una URL de red o una ruta de archivo local
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

  String? _patientEmail;
  String? _patientUid;
  String? _caregiverUid;
  final TextEditingController _caregiverPatientEmailController = TextEditingController();

  bool _isDeprecatedFirebaseStorageUrl(String? url) {
    return url != null && url.contains('firebasestorage.googleapis.com');
  }

  @override
  void initState() {
    super.initState();
    _setupFocusListeners();
    // Carga los datos del perfil después de que el widget se construya
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfileData();
    });
    _addListeners();
  }

  void _setupFocusListeners() {
    _nameFocusNode.addListener(_onFocusChange);
    _phoneFocusNode.addListener(_onFocusChange);
    _dobFocusNode.addListener(_onFocusChange);
    _bloodTypeFocusNode.addListener(_onFocusChange);
    _allergiesFocusNode.addListener(_onFocusChange);
    _medicationsFocusNode.addListener(_onFocusChange);
    _medicalHistoryFocusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    // Rebuild to update focused borders around outer card containers
    setState(() {});

    final hasFocus = _nameFocusNode.hasFocus ||
        _phoneFocusNode.hasFocus ||
        _dobFocusNode.hasFocus ||
        _bloodTypeFocusNode.hasFocus ||
        _allergiesFocusNode.hasFocus ||
        _medicationsFocusNode.hasFocus ||
        _medicalHistoryFocusNode.hasFocus;

    // Save immediately if we lose focus entirely and there are changes
    if (!hasFocus && _isSaveButtonEnabled) {
      _saveProfileDataSilently();
    }
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
    _caregiverPatientEmailController.dispose();

    _nameFocusNode.dispose();
    _phoneFocusNode.dispose();
    _dobFocusNode.dispose();
    _bloodTypeFocusNode.dispose();
    _allergiesFocusNode.dispose();
    _medicationsFocusNode.dispose();
    _medicalHistoryFocusNode.dispose();

    super.dispose();
  }

  Future<void> _loadProfileData() async {
    if (!mounted) return;
    final authService = context.read<AuthService>();
    final firestoreService = context.read<FirestoreService>();
    final user = authService.currentUser;
    if (user == null) return;

    final profileNotifier = context.read<ProfileNotifier>();
    final doc = await firestoreService.getUserProfile(user.uid);
    if (!mounted) return;

    final profileData = doc.data() as Map<String, dynamic>?;
    final firestoreProfileImage = profileData?['profileImage'] as String?;
    final sanitizedProfileImage =
        _isDeprecatedFirebaseStorageUrl(firestoreProfileImage)
            ? null
            : firestoreProfileImage;

    if (mounted) {
      setState(() {
        _originalName = profileNotifier.userName ?? profileData?['name'] ?? '';
        final notifierImage =
            _isDeprecatedFirebaseStorageUrl(profileNotifier.profileImageUrl)
                ? null
                : profileNotifier.profileImageUrl;
        _originalProfileImageUrl = notifierImage ?? sanitizedProfileImage ?? '';

        _originalPhone = profileData?['phone'] ?? '';
        _originalEmail = user.email ?? '';
        _originalDob = profileData?['dob'] ?? '';
        _originalBloodType = profileData?['bloodType'] ?? '';
        _originalAllergies = profileData?['allergies'] ?? '';
        _originalMedications = profileData?['medications'] ?? '';
        _originalMedicalHistory = profileData?['medicalHistory'] ?? '';
        
        _patientEmail = profileData?['patientEmail'];
        _patientUid = profileData?['patientUid'];
        _caregiverUid = profileData?['caregiverUid'];

        _resetToOriginalData();
      });
    }
  }

  void _resetToOriginalData() {
    if (!mounted) return;

    _nameController.text = _originalName ?? '';
    _phoneController.text = _originalPhone ?? '';
    _emailController.text = _originalEmail ?? '';
    _dobController.text = _originalDob ?? '';
    _bloodTypeController.text = _originalBloodType ?? '';
    _allergiesController.text = _originalAllergies ?? '';
    _medicationsController.text = _originalMedications ?? '';
    _medicalHistoryController.text = _originalMedicalHistory ?? '';

    _nameFocusNode.unfocus();
    _phoneFocusNode.unfocus();
    _dobFocusNode.unfocus();
    _bloodTypeFocusNode.unfocus();
    _allergiesFocusNode.unfocus();
    _medicationsFocusNode.unfocus();
    _medicalHistoryFocusNode.unfocus();

    setState(() {
      _profileImageUrl = _originalProfileImageUrl;
      _isSaveButtonEnabled = false;
    });
  }

  void _updateSaveButtonState() {
    if (!mounted) return;
    final hasChanged =
        _nameController.text != _originalName ||
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
        setState(() {
          _profileImageUrl = pickedFile.path;
        });
        _updateSaveButtonState();
        // Save image pick
        _saveProfileDataSilently();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar la imagen: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  Future<void> _saveProfileDataSilently() async {
    if (!mounted || _isSaving) return;
    
    final authService = context.read<AuthService>();
    final firestoreService = context.read<FirestoreService>();
    final storageService = context.read<StorageService>();
    final user = authService.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      String? finalImageUrl = _originalProfileImageUrl;

      if (_profileImageUrl != null &&
          _profileImageUrl!.isNotEmpty &&
          !_profileImageUrl!.startsWith('http')) {
        File imageFile = File(_profileImageUrl!);
        finalImageUrl = await storageService.uploadProfileImage(
          user.uid,
          imageFile,
        );
      }

      final dataToSave = {
        'name': _nameController.text,
        'phone': _phoneController.text,
        'dob': _dobController.text,
        'bloodType': _bloodTypeController.text,
        'allergies': _allergiesController.text,
        'medications': _medicationsController.text,
        'medicalHistory': _medicalHistoryController.text,
        'profileImage': finalImageUrl ?? '',
      };

      await firestoreService.saveUserProfile(user.uid, dataToSave);

      // Sincronizar también con el photoURL de Firebase Auth
      if (finalImageUrl != null && finalImageUrl.isNotEmpty) {
        try {
          await user.updatePhotoURL(finalImageUrl);
        } catch (e) {
          debugPrint('PerfilPage: Error al actualizar photoURL en FirebaseAuth: $e');
        }
      }

      if (mounted) {
        // Limpiar la caché de imágenes en memoria para asegurar refresco inmediato
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();

        context.read<ProfileNotifier>().updateProfile(
          newName: _nameController.text,
          newImageUrl: finalImageUrl,
        );

        setState(() {
          _originalName = _nameController.text;
          _originalPhone = _phoneController.text;
          _originalDob = _dobController.text;
          _originalBloodType = _bloodTypeController.text;
          _originalAllergies = _allergiesController.text;
          _originalMedications = _medicationsController.text;
          _originalMedicalHistory = _medicalHistoryController.text;
          _originalProfileImageUrl = finalImageUrl;
          _profileImageUrl = finalImageUrl;
          _isSaveButtonEnabled = false;
        });
      }
    } catch (e) {
      debugPrint('PerfilPage: Error al guardar datos del perfil: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar la foto/perfil: $e')),
        );
        setState(() {
          _profileImageUrl = _originalProfileImageUrl;
          _isSaveButtonEnabled = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    FocusScope.of(context).unfocus();
    
    DateTime initialDate = DateTime(2000);
    if (_dobController.text.isNotEmpty) {
      final parts = _dobController.text.split('/');
      if (parts.length == 3) {
        final day = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final year = int.tryParse(parts[2]);
        if (day != null && month != null && year != null) {
          try {
            initialDate = DateTime(year, month, day);
          } catch (_) {}
        }
      }
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (BuildContext context, Widget? child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? ColorScheme.dark(
                    primary: AppTheme.primaryColor,
                    onPrimary: Colors.white,
                    surface: Theme.of(context).cardColor,
                    onSurface: AppTheme.primaryTextColor,
                  )
                : ColorScheme.light(
                    primary: AppTheme.primaryColor,
                    onPrimary: Colors.white,
                    surface: Theme.of(context).cardColor,
                    onSurface: AppTheme.primaryTextColor,
                  ),
            dialogBackgroundColor: Theme.of(context).cardColor,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final day = picked.day.toString().padLeft(2, '0');
      final month = picked.month.toString().padLeft(2, '0');
      final year = picked.year.toString();
      
      setState(() {
        _dobController.text = '$day/$month/$year';
      });
      
      _updateSaveButtonState();
      _saveProfileDataSilently();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileNotifier>();

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('Perfil'),
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: AppTheme.primaryTextColor,
          actions: [
            if (_isSaveButtonEnabled)
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Center(
                  child: GestureDetector(
                    onTap: _resetToOriginalData,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(
                          color: AppTheme.errorColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Card (Header)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Row with Avatar + Name/Email
                    Row(
                      children: [
                        // Avatar stack
                        Stack(
                          children: [
                            _buildAvatarWithShowcase(profile),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _pickImage,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: AppTheme.primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        // Name and Email
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _nameController.text.isNotEmpty ? _nameController.text : (profile.userName ?? 'Nombre de Usuario'),
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryTextColor),
                              ),
                              const SizedBox(height: 8),
                              // Email container
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.email_outlined, color: AppTheme.primaryColor, size: 14),
                                    const SizedBox(width: 6),
                                    Text(
                                      _emailController.text,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Divider
                    Divider(color: AppTheme.borderColor),
                    const SizedBox(height: 12),
                    // Stat row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildHeaderStatItem(
                          icon: Icons.calendar_month_rounded,
                          label: 'Fecha de nacimiento',
                          value: _dobController.text.isNotEmpty ? _dobController.text : 'No especificado',
                        ),
                        _buildStatDivider(),
                        _buildHeaderStatItem(
                          icon: Icons.water_drop_rounded,
                          label: 'Tipo de sangre',
                          value: _bloodTypeController.text.isNotEmpty ? _bloodTypeController.text : 'No especificado',
                        ),
                        _buildStatDivider(),
                        _buildHeaderStatItem(
                          icon: Icons.shield_rounded,
                          label: 'Alergias',
                          value: _allergiesController.text.isNotEmpty ? _allergiesController.text : 'No especificado',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              _buildSectionTitle('Datos Personales', Icons.person_outline_rounded),
              const SizedBox(height: 8),
              _buildEditableOrDisplayField(
                controller: _nameController,
                labelText: 'Nombre',
                hintText: 'Tu nombre completo',
                icon: Icons.person_outline_rounded,
                focusNode: _nameFocusNode,
              ),
              _buildEditableOrDisplayField(
                controller: _phoneController,
                labelText: 'Número de Teléfono',
                hintText: 'Tu número de teléfono',
                keyboardType: TextInputType.phone,
                icon: Icons.phone_outlined,
                focusNode: _phoneFocusNode,
              ),
              _buildEditableOrDisplayField(
                controller: _emailController,
                labelText: 'Correo',
                hintText: 'Tu correo electrónico',
                enabled: false,
                icon: Icons.email_outlined,
                focusNode: FocusNode(), // Always disabled, mock node
              ),
              _buildEditableOrDisplayField(
                controller: _dobController,
                labelText: 'Fecha de Nacimiento',
                hintText: 'Ej: 01/01/1990',
                icon: Icons.calendar_month_outlined,
                focusNode: _dobFocusNode,
                readOnly: true,
                onTap: () => _selectDate(context),
              ),

              const SizedBox(height: 24),
              _buildSectionTitle('Datos Médicos', Icons.favorite_border_rounded),
              const SizedBox(height: 8),
              _buildEditableOrDisplayField(
                controller: _bloodTypeController,
                labelText: 'Tipo de Sangre',
                hintText: 'Ej: O+',
                icon: Icons.water_drop_outlined,
                focusNode: _bloodTypeFocusNode,
              ),
              _buildEditableOrDisplayField(
                controller: _allergiesController,
                labelText: 'Alergias',
                hintText: 'Ej: Penicilina',
                icon: Icons.shield_outlined,
                focusNode: _allergiesFocusNode,
              ),
              _buildEditableOrDisplayField(
                controller: _medicationsController,
                labelText: 'Medicamentos Importantes',
                hintText: 'Los que tomas regularmente',
                icon: Icons.link_rounded,
                focusNode: _medicationsFocusNode,
              ),
              _buildEditableOrDisplayField(
                controller: _medicalHistoryController,
                labelText: 'Historial Médico',
                hintText: 'Condiciones médicas relevantes',
                icon: Icons.description_outlined,
                focusNode: _medicalHistoryFocusNode,
              ),

              const SizedBox(height: 24),
              _buildCaregiverSection(),

              const SizedBox(height: 24),
              _buildNearbyPharmaciesOption(),

              const SizedBox(height: 24),
              _buildInfoBanner(),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 18),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: AppTheme.secondaryTextColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 40,
      color: AppTheme.borderColor,
    );
  }

  Widget _buildAvatarWithShowcase(ProfileNotifier profile) {
    ImageProvider<Object>? backgroundImage;
    final canLoadNetworkImage =
        _profileImageUrl != null &&
        _profileImageUrl!.startsWith('http') &&
        !_isDeprecatedFirebaseStorageUrl(_profileImageUrl);

    if (canLoadNetworkImage) {
      backgroundImage = NetworkImage(_profileImageUrl!);
    } else if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      backgroundImage = FileImage(File(_profileImageUrl!));
    }

    Widget? avatarChild;
    if (backgroundImage == null) {
      avatarChild = Icon(Icons.person, size: 40, color: Colors.grey.shade500);
    }

    final avatar = CircleAvatar(
      radius: 42,
      backgroundColor: AppTheme.borderColor,
      child: CircleAvatar(
        radius: 40,
        backgroundColor: Colors.grey.shade200,
        backgroundImage: backgroundImage,
        child: avatarChild,
      ),
    );

    if (widget.profileKey != null) {
      return Showcase(
        key: widget.profileKey!,
        title: 'Tu perfil de salud',
        description:
            'Mantén tu información médica actualizada: foto, nombre, tipo de sangre, alergias y más.',
        tooltipBackgroundColor: const Color(0xFF2F6DB4),
        textColor: Colors.white,
        descTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          height: 1.5,
        ),
        targetShapeBorder: const CircleBorder(),
        child: avatar,
      );
    }
    return avatar;
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryTextColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Divider(
              color: AppTheme.borderColor,
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNearbyPharmaciesOption() {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const LocalizadorFarmaciasPage(),
          ),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2F6DB4), Color(0xFF49C2FF)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          children: [
            Icon(Icons.local_pharmacy_outlined, color: Colors.white, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Farmacias Cercanas',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Busca farmacias abiertas cerca de tu ubicación.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableOrDisplayField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required IconData icon,
    required FocusNode focusNode,
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    final isFocused = focusNode.hasFocus;
    return GestureDetector(
      onTap: () {
        if (enabled) {
          if (onTap != null) {
            onTap();
          } else {
            focusNode.requestFocus();
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: (enabled && isFocused) ? AppTheme.primaryColor : AppTheme.borderColor,
            width: (enabled && isFocused) ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppTheme.primaryColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    labelText,
                    style: TextStyle(
                      color: AppTheme.secondaryTextColor,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    keyboardType: keyboardType,
                    enabled: enabled,
                    readOnly: readOnly,
                    onTap: onTap,
                    style: TextStyle(
                      color: enabled ? AppTheme.primaryTextColor : AppTheme.secondaryTextColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      filled: false,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintText: hintText,
                      hintStyle: TextStyle(
                        color: AppTheme.secondaryTextColor.withOpacity(0.5),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                    ),
                  ),
                ],
              ),
            ),
            if (enabled)
              Icon(Icons.chevron_right, color: AppTheme.secondaryTextColor, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: AppTheme.primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Información importante',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Mantén tus datos actualizados para ayudarte mejor.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaregiverSection() {
    final firestoreService = context.read<FirestoreService>();
    final authService = context.read<AuthService>();
    final user = authService.currentUser;

    if (user == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Modo Cuidador', Icons.supervised_user_circle_outlined),
        const SizedBox(height: 12),
        if (_caregiverUid != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.security, color: Colors.blue),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tu cuenta está siendo supervisada por tu cuidador asignado.',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (_patientEmail != null) ...[
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            color: Colors.green.withOpacity(0.1),
            child: ListTile(
              leading: const Icon(Icons.favorite, color: Colors.green),
              title: Text('Paciente: $_patientEmail'),
              subtitle: const Text('Puedes supervisar sus tratamientos activos.'),
              trailing: PopupMenuButton<int>(
                onSelected: (val) async {
                  if (val == 0) {
                    if (_patientUid != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PacienteRecetaPage(
                            patientUid: _patientUid!,
                            patientEmail: _patientEmail!,
                          ),
                        ),
                      );
                    }
                  } else if (val == 1) {
                    try {
                      setState(() => _isSaving = true);
                      await firestoreService.unlinkPatient(user.uid);
                      await _loadProfileData();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Paciente desvinculado con éxito.')),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                      );
                    } finally {
                      setState(() => _isSaving = false);
                    }
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 0, child: Text('Ver Recetas')),
                  const PopupMenuItem(value: 1, child: Text('Desvincular', style: TextStyle(color: Colors.red))),
                ],
              ),
            ),
          ),
        ] else ...[
          const Text(
            'Si eres cuidador de un familiar, ingresa su correo electrónico para supervisar su cumplimiento de dosis en tiempo real.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _caregiverPatientEmailController,
                  decoration: AppInputDecoration.withHint('Correo del paciente'),
                  keyboardType: TextInputType.emailAddress,
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isSaving ? null : () async {
                  final email = _caregiverPatientEmailController.text.trim();
                  if (email.isEmpty) return;
                  try {
                    setState(() => _isSaving = true);
                    await firestoreService.linkPatient(user.uid, email);
                    _caregiverPatientEmailController.clear();
                    await _loadProfileData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Paciente vinculado con éxito.')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  } finally {
                    setState(() => _isSaving = false);
                  }
                },
                child: const Text('Vincular'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
