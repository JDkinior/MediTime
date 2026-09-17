import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/notifiers/caregiver_notifier.dart';
import 'package:meditime/notifiers/profile_notifier.dart';
import 'package:meditime/services/preference_service.dart';
import 'package:meditime/services/firestore_service.dart';
import 'package:meditime/services/storage_service.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:meditime/widgets/primary_button.dart';
import 'package:meditime/widgets/styled_text_field.dart';

/// Widget de animación de desvanecimiento y deslizamiento hacia arriba
/// con retraso escalonado (staggered animation) para cada tarjeta.
class FadeSlideCard extends StatefulWidget {
  final Widget child;
  final int delayMs;
  final Duration duration;

  const FadeSlideCard({
    super.key,
    required this.child,
    this.delayMs = 0,
    this.duration = const Duration(milliseconds: 400),
  });

  @override
  State<FadeSlideCard> createState() => _FadeSlideCardState();
}

class _FadeSlideCardState extends State<FadeSlideCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    if (widget.delayMs > 0) {
      Future.delayed(Duration(milliseconds: widget.delayMs), () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

class OnboardingPage extends StatefulWidget {
  final User user;
  final VoidCallback onCompleted;

  const OnboardingPage({
    super.key,
    required this.user,
    required this.onCompleted,
  });

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int _currentPage = 0;
  static const int _totalPages = 6;

  // Step 0: Términos
  bool _acceptedTerms = false;

  // Step 1: Perfil
  late final TextEditingController _nameController;
  File? _profileImage;
  String? _photoUrl;
  final ImagePicker _picker = ImagePicker();

  // Step 2: Propósito de uso
  String _selectedPurpose = 'personal'; // 'personal', 'cuidador', 'animales'

  // Step 3: Estilo de interfaz
  String _selectedInterfaceStyle = 'modern'; // 'modern', 'classic', 'simplified'

  // Step 4: Modo de recordatorio
  DoseReminderMode _selectedReminderMode = DoseReminderMode.alarm;

  // Step 5: Guardado
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.displayName ?? '');
    _photoUrl = widget.user.photoURL;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      setState(() {
        _currentPage++;
      });
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      setState(() {
        _currentPage--;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, maxWidth: 600, maxHeight: 600, imageQuality: 80);
      if (picked != null) {
        setState(() {
          _profileImage = File(picked.path);
        });
      }
    } catch (e) {
      debugPrint("Error seleccionando imagen: $e");
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt_rounded, color: AppTheme.primaryColor),
              title: const Text('Tomar foto con la cámara'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library_rounded, color: AppTheme.primaryColor),
              title: const Text('Elegir de la galería'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _completeOnboarding() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final userId = widget.user.uid;
      final enteredName = _nameController.text.trim();
      final effectiveName = enteredName.isNotEmpty
          ? enteredName
          : (widget.user.displayName?.isNotEmpty == true ? widget.user.displayName! : 'Usuario');

      // 1. Subir imagen si se tomó una foto local
      String? finalImageUrl = _photoUrl;
      if (_profileImage != null) {
        try {
          final storageService = context.read<StorageService>();
          finalImageUrl = await storageService.uploadProfileImage(userId, _profileImage!);
        } catch (e) {
          debugPrint("Advertencia: No se pudo subir imagen a Cloudinary en onboarding: $e");
        }
      }

      // 2. Guardar perfil en Firestore
      final firestoreService = context.read<FirestoreService>();
      await firestoreService.saveUserProfile(userId, {
        'name': effectiveName,
        if (finalImageUrl != null && finalImageUrl.isNotEmpty) 'profileImage': finalImageUrl,
        'onboardingCompleted': true,
        'appPurpose': _selectedPurpose,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // 3. Actualizar ProfileNotifier
      if (mounted) {
        context.read<ProfileNotifier>().updateProfile(
          newName: effectiveName,
          newImageUrl: finalImageUrl,
        );
      }

      // 4. Configurar Modo Cuidador o Modo Animales según el propósito seleccionado
      final isCaregiver = _selectedPurpose == 'cuidador';
      final isAnimal = _selectedPurpose == 'animales';

      if (mounted) {
        final caregiverNotifier = context.read<CaregiverNotifier>();
        final preferenceNotifier = context.read<PreferenceNotifier>();

        if (isCaregiver) {
          await preferenceNotifier.setAnimalMode(false);
          await caregiverNotifier.setCaregiverModeActive(true);
          caregiverNotifier.ensureActiveProfileForMode(isAnimalMode: false);
        } else if (isAnimal) {
          await caregiverNotifier.setCaregiverModeActive(false);
          await preferenceNotifier.setAnimalMode(true);
          await caregiverNotifier.setModeType(CaregiverModeType.veterinario);
          caregiverNotifier.ensureActiveProfileForMode(isAnimalMode: true);
        } else {
          // Personal
          await caregiverNotifier.setCaregiverModeActive(false);
          await preferenceNotifier.setAnimalMode(false);
          caregiverNotifier.clearActiveProfile();
        }
      }

      // 5. Configurar Preferencias de Interfaz y Recordatorios
      final isSimplified = _selectedInterfaceStyle == 'simplified';
      final styleToSave = isSimplified ? 'classic' : _selectedInterfaceStyle;

      if (mounted) {
        await context.read<PreferenceNotifier>().applyOnboardingSettings(
          reminderMode: _selectedReminderMode,
          interfaceStyle: styleToSave,
          simplifiedInterface: isSimplified,
          largeText: isSimplified,
          highContrast: isSimplified,
        );
      }

      // 6. Marcar onboarding como completado en almacenamiento local
      await PreferenceService().saveOnboardingCompleted(userId, true);

      // 7. Notificar finalización para navegación a HomePage
      widget.onCompleted();
    } catch (e) {
      debugPrint("Error completando onboarding: $e");
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar configuración: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              // Barra superior de navegación y progreso
              _buildTopBar(isDark),

              // Contenido con transición de desvanecimiento y deslizamiento entre pasos
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.04, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey<int>(_currentPage),
                    child: _buildCurrentStep(isDark),
                  ),
                ),
              ),

              // Barra inferior con botón siguiente / finalizar
              _buildBottomControls(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep(bool isDark) {
    switch (_currentPage) {
      case 0:
        return _buildWelcomeStep(isDark);
      case 1:
        return _buildProfileStep(isDark);
      case 2:
        return _buildPurposeStep(isDark);
      case 3:
        return _buildInterfaceStep(isDark);
      case 4:
        return _buildReminderStep(isDark);
      case 5:
        return _buildSummaryStep(isDark);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTopBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Botón atrás (visible desde el paso 1)
          if (_currentPage > 0)
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              color: AppTheme.primaryTextColor,
              onPressed: _isSaving ? null : _previousPage,
            )
          else
            const SizedBox(width: 40),

          // Indicador de pasos (puntos animados)
          Row(
            children: List.generate(_totalPages, (index) {
              final isCurrent = index == _currentPage;
              final isDone = index < _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isCurrent ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isCurrent
                      ? AppTheme.primaryColor
                      : (isDone
                          ? AppTheme.primaryColor.withValues(alpha: 0.4)
                          : AppTheme.borderColor),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),

          // Etiqueta de paso (ej. 1/6)
          Text(
            '${_currentPage + 1}/$_totalPages',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppTheme.secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  // --- PASO 0: BIENVENIDA Y TÉRMINOS ---
  Widget _buildWelcomeStep(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 10),
          FadeSlideCard(
            delayMs: 0,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: Image.asset(
                  'assets/chatbot/midi_open.png',
                  width: 75,
                  height: 75,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.favorite_rounded,
                    size: 55,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          FadeSlideCard(
            delayMs: 60,
            child: Text(
              '¡Te damos la bienvenida a MediTime!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryTextColor,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 10),
          FadeSlideCard(
            delayMs: 120,
            child: Text(
              'Tu asistente inteligente para no olvidar ninguna toma de medicamentos y cuidar de los tuyos.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.secondaryTextColor,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Tarjetas con desvanecimiento escalonado
          FadeSlideCard(
            delayMs: 180,
            child: _buildPillarTile(
              icon: Icons.alarm_on_rounded,
              color: Colors.indigo,
              title: 'Puntualidad Segura',
              subtitle: 'Alarmas exactas que suenan incluso sin internet ni señal.',
            ),
          ),
          const SizedBox(height: 12),
          FadeSlideCard(
            delayMs: 240,
            child: _buildPillarTile(
              icon: Icons.shield_rounded,
              color: AppTheme.successColor,
              title: 'Privacidad Médica Blindada',
              subtitle: 'Tus tratamientos y recetas están protegidos y aislados.',
            ),
          ),
          const SizedBox(height: 12),
          FadeSlideCard(
            delayMs: 300,
            child: _buildPillarTile(
              icon: Icons.supervised_user_circle_rounded,
              color: Colors.teal,
              title: 'Modo Cuidador y Pacientes',
              subtitle: 'Organiza tomas para tus padres, hijos o pacientes en una sola app.',
            ),
          ),

          const SizedBox(height: 24),

          FadeSlideCard(
            delayMs: 360,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _acceptedTerms
                      ? AppTheme.primaryColor
                      : AppTheme.borderColor,
                  width: _acceptedTerms ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: _acceptedTerms,
                    activeColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (val) => setState(() => _acceptedTerms = val ?? false),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _acceptedTerms = !_acceptedTerms),
                      child: Text(
                        'He leído y acepto los Términos de Servicio y la Política de Privacidad de Datos Médicos.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.primaryTextColor,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillarTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryTextColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.secondaryTextColor,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- PASO 1: IDENTIDAD (NOMBRE Y FOTO) ---
  Widget _buildProfileStep(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          FadeSlideCard(
            delayMs: 0,
            child: Text(
              '¿Cómo te gustaría que te llamemos?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryTextColor,
              ),
            ),
          ),
          const SizedBox(height: 8),
          FadeSlideCard(
            delayMs: 60,
            child: Text(
              'Personalizaremos tus recordatorios, reportes y la voz de tu asistente.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.secondaryTextColor,
              ),
            ),
          ),
          const SizedBox(height: 32),

          FadeSlideCard(
            delayMs: 120,
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        border: Border.all(color: AppTheme.primaryColor, width: 2.5),
                        image: _profileImage != null
                            ? DecorationImage(image: FileImage(_profileImage!), fit: BoxFit.cover)
                            : (_photoUrl != null && _photoUrl!.isNotEmpty
                                ? DecorationImage(image: NetworkImage(_photoUrl!), fit: BoxFit.cover)
                                : null),
                      ),
                      child: (_profileImage == null && (_photoUrl == null || _photoUrl!.isEmpty))
                          ? Icon(Icons.person_rounded, size: 65, color: AppTheme.primaryColor)
                          : null,
                    ),
                    GestureDetector(
                      onTap: _showImageSourceDialog,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: _showImageSourceDialog,
                  icon: const Icon(Icons.photo_camera_outlined, size: 16),
                  label: Text(_profileImage != null || _photoUrl != null ? 'Cambiar foto' : 'Subir foto'),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.primaryColor),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          FadeSlideCard(
            delayMs: 180,
            child: StyledTextField(
              controller: _nameController,
              labelText: 'Nombre o apodo',
              hintText: 'Ej. Juan Pérez',
            ),
          ),
          const SizedBox(height: 12),
          FadeSlideCard(
            delayMs: 240,
            child: Text(
              'Si iniciaste con Google, tu nombre se ha precargado automáticamente.',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.secondaryTextColor,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- PASO 2: PROPÓSITO DE USO (MODO DE LA APP) ---
  Widget _buildPurposeStep(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          FadeSlideCard(
            delayMs: 0,
            child: Text(
              '¿Para qué usarás MediTime?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryTextColor,
              ),
            ),
          ),
          const SizedBox(height: 8),
          FadeSlideCard(
            delayMs: 60,
            child: Text(
              'Adaptaremos la pantalla principal y las opciones a tu necesidad.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.secondaryTextColor,
              ),
            ),
          ),
          const SizedBox(height: 24),

          FadeSlideCard(
            delayMs: 120,
            child: _buildSelectionCard(
              isSelected: _selectedPurpose == 'personal',
              onTap: () => setState(() => _selectedPurpose = 'personal'),
              icon: Icons.person_rounded,
              color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF004AC6),
              title: 'Para mí (Uso Personal)',
              subtitle: 'Registrar mis propios medicamentos, recetas y seguir mi adherencia diaria.',
            ),
          ),
          const SizedBox(height: 14),
          FadeSlideCard(
            delayMs: 200,
            child: _buildSelectionCard(
              isSelected: _selectedPurpose == 'cuidador',
              onTap: () => setState(() => _selectedPurpose = 'cuidador'),
              icon: Icons.health_and_safety_rounded,
              color: isDark ? const Color(0xFFBCA2F3) : const Color(0xFF8B62D4),
              title: 'Soy Cuidador / Familiar',
              subtitle: 'Gestionar las tomas de mis padres, hijos, pacientes u otros familiares a mi cargo.',
            ),
          ),
          const SizedBox(height: 14),
          FadeSlideCard(
            delayMs: 280,
            child: _buildSelectionCard(
              isSelected: _selectedPurpose == 'animales',
              onTap: () => setState(() => _selectedPurpose = 'animales'),
              icon: Icons.pets_rounded,
              color: isDark ? const Color(0xFF65C895) : const Color(0xFF389E6A),
              title: 'Mascotas y Animales (Veterinaria)',
              subtitle: 'Gestionar tratamientos, dosis y recordatorios para mascotas o en clínica veterinaria.',
            ),
          ),
        ],
      ),
    );
  }

  // --- PASO 3: ESTILO DE INTERFAZ ---
  Widget _buildInterfaceStep(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          FadeSlideCard(
            delayMs: 0,
            child: Text(
              '¿Qué estilo visual prefieres?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryTextColor,
              ),
            ),
          ),
          const SizedBox(height: 8),
          FadeSlideCard(
            delayMs: 60,
            child: Text(
              'Puedes cambiar esto en cualquier momento desde Opciones.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.secondaryTextColor,
              ),
            ),
          ),
          const SizedBox(height: 24),

          FadeSlideCard(
            delayMs: 120,
            child: _buildSelectionCard(
              isSelected: _selectedInterfaceStyle == 'modern',
              onTap: () => setState(() => _selectedInterfaceStyle = 'modern'),
              icon: Icons.auto_awesome_rounded,
              color: Colors.amber.shade800,
              title: 'Moderna (Recomendada)',
              subtitle: 'Diseño visual con tarjetas flotantes, degradados suaves y barra de cápsula.',
            ),
          ),
          const SizedBox(height: 14),
          FadeSlideCard(
            delayMs: 200,
            child: _buildSelectionCard(
              isSelected: _selectedInterfaceStyle == 'classic',
              onTap: () => setState(() => _selectedInterfaceStyle = 'classic'),
              icon: Icons.dashboard_outlined,
              color: AppTheme.primaryColor,
              title: 'Clásica',
              subtitle: 'Diseño limpio, directo y tradicional enfocado en la máxima simplicidad.',
            ),
          ),
          const SizedBox(height: 14),
          FadeSlideCard(
            delayMs: 280,
            child: _buildSelectionCard(
              isSelected: _selectedInterfaceStyle == 'simplified',
              onTap: () => setState(() => _selectedInterfaceStyle = 'simplified'),
              icon: Icons.accessibility_new_rounded,
              color: Colors.green.shade700,
              title: 'Accesible / Simplificada',
              subtitle: 'Botones grandes, tipografía de alta visibilidad y alto contraste (ideal para adultos mayores).',
            ),
          ),
        ],
      ),
    );
  }

  // --- PASO 4: TIPO DE RECORDATORIO ---
  Widget _buildReminderStep(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          FadeSlideCard(
            delayMs: 0,
            child: Text(
              '¿Cómo prefieres que te avisemos?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryTextColor,
              ),
            ),
          ),
          const SizedBox(height: 8),
          FadeSlideCard(
            delayMs: 60,
            child: Text(
              'Elige la intensidad de aviso para tus tomas de medicamento.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.secondaryTextColor,
              ),
            ),
          ),
          const SizedBox(height: 24),

          FadeSlideCard(
            delayMs: 120,
            child: _buildSelectionCard(
              isSelected: _selectedReminderMode == DoseReminderMode.alarm,
              onTap: () => setState(() => _selectedReminderMode = DoseReminderMode.alarm),
              icon: Icons.alarm_on_rounded,
              color: AppTheme.errorColor,
              title: '🚨 Modo Alarma (Recomendado)',
              subtitle: 'Suena de forma continua en bucle como un despertador y enciende la pantalla hasta que interactúes.',
            ),
          ),
          const SizedBox(height: 14),
          FadeSlideCard(
            delayMs: 200,
            child: _buildSelectionCard(
              isSelected: _selectedReminderMode == DoseReminderMode.active,
              onTap: () => setState(() => _selectedReminderMode = DoseReminderMode.active),
              icon: Icons.notifications_active_outlined,
              color: Colors.blue,
              title: '🔔 Modo Activo',
              subtitle: 'Notificación interactiva con botones rápidos para Tomar, Omitir o Aplazar.',
            ),
          ),
          const SizedBox(height: 14),
          FadeSlideCard(
            delayMs: 280,
            child: _buildSelectionCard(
              isSelected: _selectedReminderMode == DoseReminderMode.automatic,
              onTap: () => setState(() => _selectedReminderMode = DoseReminderMode.automatic),
              icon: Icons.info_outline_rounded,
              color: Colors.teal,
              title: 'ℹ️ Modo Informativo',
              subtitle: 'Aviso discreto. Ideal si ya tienes una rutina fija y solo quieres una referencia.',
            ),
          ),
        ],
      ),
    );
  }

  // --- PASO 5: RESUMEN Y FINALIZACIÓN ---
  Widget _buildSummaryStep(bool isDark) {
    final name = _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : 'Amigo';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          const SizedBox(height: 10),
          FadeSlideCard(
            delayMs: 0,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppTheme.successColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                size: 55,
                color: AppTheme.successColor,
              ),
            ),
          ),
          const SizedBox(height: 20),
          FadeSlideCard(
            delayMs: 80,
            child: Text(
              '¡Todo listo, $name!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryTextColor,
              ),
            ),
          ),
          const SizedBox(height: 8),
          FadeSlideCard(
            delayMs: 140,
            child: Text(
              'Hemos configurado MediTime a tu medida. Aquí tienes un resumen de tu perfil:',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.secondaryTextColor,
              ),
            ),
          ),
          const SizedBox(height: 24),

          FadeSlideCard(
            delayMs: 200,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(
                children: [
                  _buildSummaryRow(
                    icon: Icons.person_outline_rounded,
                    label: 'Usuario',
                    value: name,
                  ),
                  const Divider(height: 24),
                  _buildSummaryRow(
                    icon: _selectedPurpose == 'animales'
                        ? Icons.pets_rounded
                        : (_selectedPurpose == 'cuidador' ? Icons.health_and_safety_outlined : Icons.person_outline_rounded),
                    label: 'Propósito',
                    value: _selectedPurpose == 'personal'
                        ? 'Uso Personal'
                        : (_selectedPurpose == 'cuidador' ? 'Modo Cuidador' : 'Modo Animales'),
                  ),
                  const Divider(height: 24),
                  _buildSummaryRow(
                    icon: Icons.palette_outlined,
                    label: 'Estilo Visual',
                    value: _selectedInterfaceStyle == 'modern'
                        ? 'Moderna'
                        : (_selectedInterfaceStyle == 'classic' ? 'Clásica' : 'Accesible / Simplificada'),
                  ),
                  const Divider(height: 24),
                  _buildSummaryRow(
                    icon: Icons.alarm_outlined,
                    label: 'Recordatorios',
                    value: _selectedReminderMode == DoseReminderMode.alarm
                        ? 'Alarma Despertador'
                        : (_selectedReminderMode == DoseReminderMode.active ? 'Modo Activo' : 'Informativo'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryColor),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.secondaryTextColor,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryTextColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionCard({
    required bool isSelected,
    required VoidCallback onTap,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.08)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? color : AppTheme.borderColor,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: color.withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: isSelected ? 0.22 : 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.secondaryTextColor,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedScale(
              scale: isSelected ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: isSelected ? color : AppTheme.secondaryTextColor.withValues(alpha: 0.4),
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls(bool isDark) {
    final isLastStep = _currentPage == _totalPages - 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: isLastStep
          ? PrimaryButton(
              text: 'Comenzar a usar MediTime',
              isLoading: _isSaving,
              onPressed: _completeOnboarding,
            )
          : PrimaryButton(
              text: 'Continuar',
              onPressed: (_currentPage == 0 && !_acceptedTerms)
                  ? null
                  : _nextPage,
            ),
    );
  }
}
