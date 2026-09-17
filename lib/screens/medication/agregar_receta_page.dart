// lib/screens/medication/agregar_receta_page.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_time_picker_spinner/flutter_time_picker_spinner.dart';
import 'package:meditime/models/tratamiento.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:image_picker/image_picker.dart';
import 'package:meditime/services/gemini_service.dart';
import 'package:provider/provider.dart';
import 'package:meditime/notifiers/treatment_form_notifier.dart';
import 'package:meditime/notifiers/caregiver_notifier.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/models/caregiver_profile.dart';
import 'package:meditime/models/treatment_form_data.dart';
import 'package:meditime/widgets/treatment_form/form_field_wrapper.dart';
import 'package:meditime/widgets/treatment_form/duration_selector.dart';
import 'package:meditime/widgets/treatment_form/treatment_summary_card.dart';
import 'package:meditime/widgets/drug_interaction_dialog.dart';
import 'package:meditime/repositories/treatment_repository.dart';
import 'package:meditime/services/auth_service.dart';

class AgregarRecetaPage extends StatefulWidget {
  final Tratamiento? tratamientoToEdit;

  const AgregarRecetaPage({super.key, this.tratamientoToEdit});

  @override
  AgregarRecetaPageState createState() => AgregarRecetaPageState();
}

class AgregarRecetaPageState extends State<AgregarRecetaPage> {
  int _currentStep = 0;
  final PageController _pageController = PageController();
  bool _isAnimating = false;

  // Controladores de texto
  final TextEditingController _nombreMedicamentoController =
      TextEditingController();
  final TextEditingController _cantidadActualController =
      TextEditingController();
  final TextEditingController _cantidadTotalController =
      TextEditingController();
  final TextEditingController _dosisPorTomaController = TextEditingController();
  final TextEditingController _dosisController = TextEditingController();
  final TextEditingController _duracionController = TextEditingController();
  final TextEditingController _notasController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.tratamientoToEdit != null) {
      _userInteractedWithTime = true;
      final t = widget.tratamientoToEdit!;
      _nombreMedicamentoController.text = t.nombreMedicamento;
      _cantidadActualController.text = t.cantidadActual.toString();
      _cantidadTotalController.text = t.cantidadTotalCaja.toString();
      _dosisPorTomaController.text = t.dosisPorToma.toString();
      _dosisController.text = t.intervaloDosis.inHours.toString();
      _duracionController.text = (int.tryParse(t.duracion) ?? 7).toString();
      _notasController.text = t.notas;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final notifier = context.read<TreatmentFormNotifier>();
        notifier.initializeWithTreatment(t);
        _duracionController.text = notifier.formData.duracionNumero.toString();
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final notifier = context.read<TreatmentFormNotifier>();
        notifier.resetForm();
        notifier.updateHoraPrimeraDosis(TimeOfDay.now());
      });
    }
  }

  @override
  void dispose() {
    _nombreMedicamentoController.dispose();
    _cantidadActualController.dispose();
    _cantidadTotalController.dispose();
    _dosisPorTomaController.dispose();
    _dosisController.dispose();
    _duracionController.dispose();
    _notasController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _handleBack(BuildContext context, TreatmentFormNotifier notifier) async {
    if (_isAnimating) return;
    if (_currentStep > 0) {
      setState(() {
        _isAnimating = true;
      });
      await _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      if (mounted) {
        setState(() {
          _isAnimating = false;
        });
      }
    } else {
      final hasData = notifier.formData.nombreMedicamento.trim().isNotEmpty ||
          _nombreMedicamentoController.text.trim().isNotEmpty;
      if (hasData) {
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('¿Descartar receta?'),
            content: const Text(
              'Tienes datos ingresados en el formulario. Si sales ahora, se perderán los cambios.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Continuar editando'),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Salir y descartar'),
              ),
            ],
          ),
        );
        if (shouldExit == true && mounted) {
          Navigator.of(context).pop();
        }
      } else {
        Navigator.of(context).pop();
      }
    }
  }

  /// Verificación de interacciones farmacológicas con la IA
  Future<bool> _checkAndWarnDrugInteractions(String newDrugName) async {
    if (newDrugName.trim().isEmpty) return true;

    try {
      final authService = context.read<AuthService>();
      final userId = authService.currentUser?.uid;
      if (userId == null) return true;

      final treatmentRepo = context.read<TreatmentRepository>();
      final result = await treatmentRepo.getTreatments(userId);
      if (!result.isSuccess || result.data == null || result.data!.isEmpty) return true;

      final activeTreatments = result.data!;
      final geminiService = context.read<GeminiService>();

      final checkResult = await geminiService.checkDrugInteractions(
        newDrugName: newDrugName,
        activeTreatments: activeTreatments,
      );

      if (checkResult['hasInteraction'] == true && mounted) {
        final warningMessage = checkResult['warningMessage'] as String? ??
            'Se ha detectado una posible interacción medicamentosa.';
        final proceed = await DrugInteractionDialog.show(
          context,
          warningMessage: warningMessage,
        );
        return proceed;
      }
    } catch (e) {
      debugPrint('Error en la verificación de interacciones: $e');
    }

    return true;
  }

  /// Guarda o actualiza el tratamiento usando el notifier
  Future<void> _saveData() async {
    if (!mounted) return;

    final notifier = context.read<TreatmentFormNotifier>();
    final caregiverNotifier = context.read<CaregiverNotifier>();
    final activeProfile = caregiverNotifier.isCaregiverModeActive ? caregiverNotifier.activeProfile : null;
    final isEditing = widget.tratamientoToEdit != null;

    final proceed = await _checkAndWarnDrugInteractions(notifier.formData.nombreMedicamento);
    if (!proceed || !mounted) return;

    final bool success;
    if (isEditing) {
      success = await notifier.updateExistingTreatment(
        originalTratamiento: widget.tratamientoToEdit!,
        profile: activeProfile,
      );
    } else {
      success = await notifier.saveTreatment(activeProfile);
    }

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing
                ? 'Tratamiento actualizado para ${notifier.formData.nombreMedicamento}'
                : 'Recordatorios configurados para ${notifier.formData.nombreMedicamento}',
          ),
          backgroundColor: Colors.green,
        ),
      );

      notifier.resetForm();

      // Limpiar los controladores de texto
      _nombreMedicamentoController.clear();
      _cantidadActualController.clear();
      _cantidadTotalController.clear();
      _dosisPorTomaController.clear();
      _dosisController.clear();
      _duracionController.clear();
      _notasController.clear();

      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            notifier.errorMessage ?? 'Error al guardar el tratamiento',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _normalizePresentacion(String rawValue) {
    final clean = rawValue.trim().toLowerCase();
    if (clean.contains('comprimido') || clean.contains('pastilla') || clean.contains('tableta')) {
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

  void _parseAndSetDuracion(String durString, TreatmentFormNotifier notifier) {
    final clean = durString.toLowerCase();
    if (clean.contains('continuo') || clean.contains('indefinido')) {
      notifier.updateEsIndefinido(true);
      return;
    }
    final regExp = RegExp(r'\d+');
    final match = regExp.firstMatch(clean);
    if (match != null) {
      final number = int.tryParse(match.group(0)!);
      if (number != null) {
        notifier.updateDuracionNumero(number);
        _duracionController.text = number.toString();
        if (clean.contains('mes') || clean.contains('month')) {
          notifier.updateDuracionUnidad(DurationUnit.months);
        } else if (clean.contains('año') || clean.contains('year')) {
          notifier.updateDuracionUnidad(DurationUnit.years);
        } else {
          notifier.updateDuracionUnidad(DurationUnit.days);
        }
      }
    }
  }

  Future<void> _scanPrescriptionWithAI(TreatmentFormNotifier notifier) async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Cámara'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final image = await picker.pickImage(source: source);
    if (image == null) return;

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text('Analizando receta con IA de Groq...')),
          ],
        ),
      ),
    );

    try {
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);
      final extension = image.path.split('.').last.toLowerCase();
      final mimeType = extension == 'png' ? 'image/png' : 'image/jpeg';

      final geminiService = context.read<GeminiService>();
      final result = await geminiService.analyzePrescriptionImage(base64Image, mimeType);

      if (result != null && mounted) {
        Navigator.pop(context); // Close loading dialog

        if (result['nombreMedicamento'] != null) {
          notifier.updateNombreMedicamento(result['nombreMedicamento']);
          _nombreMedicamentoController.text = result['nombreMedicamento'];
        }
        if (result['presentacion'] != null) {
          final normalized = _normalizePresentacion(result['presentacion']);
          notifier.updatePresentacion(normalized);
        }
        if (result['notas'] != null) {
          notifier.updateNotas(result['notas']);
          _notasController.text = result['notas'];
        }
        if (result['intervaloDosis'] != null) {
          final intVal = int.tryParse(result['intervaloDosis'].toString());
          if (intVal != null) {
            notifier.updateIntervaloDosis(intVal);
            _dosisController.text = intVal.toString();
          }
        }
        if (result['dosisPorToma'] != null) {
          final intVal = int.tryParse(result['dosisPorToma'].toString());
          if (intVal != null) {
            notifier.updateDosisPorToma(intVal);
            _dosisPorTomaController.text = intVal.toString();
          }
        }
        if (result['duracion'] != null) {
          _parseAndSetDuracion(result['duracion'].toString(), notifier);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receta analizada con éxito. Formulario completado.'),
            backgroundColor: Colors.green,
          ),
        );

        // Verificar interacciones farmacológicas para el medicamento extraído
        final scannedDrugName = result['nombreMedicamento']?.toString();
        if (scannedDrugName != null && scannedDrugName.isNotEmpty) {
          await _checkAndWarnDrugInteractions(scannedDrugName);
        }
      } else {
        if (mounted) Navigator.pop(context);
        throw Exception('No se pudo extraer información de la receta.');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al analizar la receta: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TreatmentFormNotifier>(
      builder: (context, notifier, child) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            _handleBack(context, notifier);
          },
          child: Scaffold(
            backgroundColor: AppTheme.backgroundColor,
            resizeToAvoidBottomInset: true,
            appBar: AppBar(
              elevation: 0,
              backgroundColor: Colors.transparent,
              foregroundColor: AppTheme.primaryTextColor,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => _handleBack(context, notifier),
              ),
              title: Text(
                widget.tratamientoToEdit != null ? 'Editar Tratamiento' : 'Agregar Receta',
                style: TextStyle(
                  color: AppTheme.primaryTextColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.document_scanner,
                        color: AppTheme.primaryColor,
                        size: 22,
                      ),
                    ),
                    tooltip: 'Escanear receta con IA',
                    onPressed: () => _scanPrescriptionWithAI(notifier),
                  ),
                ),
              ],
            ),
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 8,
                      onPageChanged: (page) {
                        setState(() {
                          _currentStep = page;
                        });
                      },
                      itemBuilder: (context, index) {
                        return AnimatedBuilder(
                          animation: _pageController,
                          child: _buildStepContent(index, notifier),
                          builder: (context, child) {
                            double opacity = 1.0;
                            if (_pageController.position.haveDimensions) {
                              opacity = (1 -
                                      (_pageController.page! - index).abs())
                                  .clamp(0.0, 1.0);
                            }
                            return Opacity(opacity: opacity, child: child);
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildNavigationButtons(notifier),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Construye los botones de navegación
  Widget _buildNavigationButtons(TreatmentFormNotifier notifier) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (_currentStep > 0)
          SizedBox(
            width: 64,
            height: 64,
            child: FloatingActionButton(
              onPressed:
                  _isAnimating
                      ? null
                      : () async {
                        setState(() {
                          _isAnimating = true;
                        });
                        await _pageController.previousPage(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut,
                        );
                        if (mounted) {
                          setState(() {
                            _isAnimating = false;
                          });
                        }
                      },
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              elevation: 2,
              shape: const CircleBorder(),
              heroTag: 'botonAnterior',
              child: const Icon(Icons.arrow_back),
            ),
          ),
        if (_currentStep < 7)
          SizedBox(
            width: 64,
            height: 64,
            child: FloatingActionButton(
              onPressed:
                  notifier.isStepValid(_currentStep) && !_isAnimating
                      ? () async {
                        setState(() {
                          _isAnimating = true;
                        });
                        await _pageController.nextPage(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut,
                        );
                        if (mounted) {
                          setState(() {
                            _isAnimating = false;
                          });
                        }
                      }
                      : null,
              backgroundColor:
                  notifier.isStepValid(_currentStep)
                      ? AppTheme.primaryColor
                      : AppTheme.borderColor,
              foregroundColor:
                  notifier.isStepValid(_currentStep)
                      ? Colors.white
                      : AppTheme.secondaryTextColor,
              elevation: notifier.isStepValid(_currentStep) ? 2 : 0,
              shape: const CircleBorder(),
              heroTag: 'botonSiguiente',
              child: const Icon(Icons.arrow_forward),
            ),
          ),
        if (_currentStep == 7)
          SizedBox(
            width: 64,
            height: 64,
            child: FloatingActionButton(
              backgroundColor: AppTheme.secondaryColor,
              foregroundColor: Colors.white,
              elevation: 2,
              shape: const CircleBorder(),
              heroTag: 'botonFinalizar',
              onPressed:
                  (_isAnimating || notifier.isLoading)
                      ? null
                      : () async {
                        setState(() {
                          _isAnimating = true;
                        });

                        await _saveData();

                        if (mounted) {
                          setState(() {
                            _isAnimating = false;
                          });
                        }
                      },
              child:
                  notifier.isLoading
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                      : const Icon(Icons.check, size: 28),
            ),
          ),
      ],
    );
  }

  Widget _buildQuestionText(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 26,
        color: AppTheme.primaryColor,
        fontWeight: FontWeight.bold,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildStepContent(int step, TreatmentFormNotifier notifier) {
    switch (step) {
      case 0: // Nombre del medicamento
        final caregiverNotifier = context.watch<CaregiverNotifier>();
        final prefNotifier = context.watch<PreferenceNotifier>();
        final activeProfile = caregiverNotifier.isCaregiverModeActive ? caregiverNotifier.activeProfile : null;
        final isAnimal = prefNotifier.isAnimalMode || caregiverNotifier.modeType == CaregiverModeType.veterinario || (activeProfile?.isAnimal ?? false);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (activeProfile != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isAnimal ? Icons.pets_rounded : Icons.person_rounded,
                      size: 18,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isAnimal ? 'Mascota: ${activeProfile.name}' : 'Paciente: ${activeProfile.name}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            _buildQuestionText(isAnimal ? '¿Qué medicamento o tratamiento vas a agregar?' : '¿Qué medicamento vas a agregar?'),
            const SizedBox(height: 24),
            FormFieldWrapper(
              label: isAnimal ? 'Nombre del medicamento / tratamiento' : 'Nombre del medicamento',
              child: TextFormField(
                controller: _nombreMedicamentoController,
                onChanged: notifier.updateNombreMedicamento,
                decoration: AppInputDecoration.withHint(
                  isAnimal ? 'Escribe el nombre del fármaco o tratamiento' : 'Escribe el nombre del medicamento',
                ),
              ),
            ),
          ],
        );

      case 1: // Presentación
        final currentPres = notifier.formData.presentacion;
        final isValidPres = notifier.presentaciones.contains(currentPres);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildQuestionText('¿Cuál es la presentación del medicamento?'),
            const SizedBox(height: 16),
            DropdownButton<String>(
              value: isValidPres ? currentPres : null,
              hint: const Text('Selecciona una opción'),
              items:
                  notifier.presentaciones.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
              onChanged: (value) {
                if (value != null) {
                  notifier.updatePresentacion(value);
                }
              },
            ),
          ],
        );

      case 2: // Hora primera dosis
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildQuestionText('¿Cuándo será la primera dosis?'),
            const SizedBox(height: 16),
            Text(
              'Hora seleccionada: ${notifier.formData.horaPrimeraDosis.format(context)}',
              style: const TextStyle(fontSize: 16),
            ),
            SizedBox(
              height: 150,
              child: TimePickerSpinner(
                time: DateTime(
                  2020,
                  1,
                  1,
                  notifier.formData.horaPrimeraDosis.hour,
                  notifier.formData.horaPrimeraDosis.minute,
                ),
                is24HourMode: false,
                normalTextStyle: TextStyle(
                  fontSize: 24,
                  color: AppTheme.secondaryTextColor.withValues(alpha: 0.4),
                ),
                highlightedTextStyle: TextStyle(
                  fontSize: 24,
                  color: AppTheme.primaryTextColor,
                  fontWeight: FontWeight.bold,
                ),
                onTimeChange: (time) {
                  final selectedTime = TimeOfDay(hour: time.hour, minute: time.minute);
                  if (selectedTime.hour != notifier.formData.horaPrimeraDosis.hour ||
                      selectedTime.minute != notifier.formData.horaPrimeraDosis.minute) {
                    setState(() {
                      _userInteractedWithTime = true;
                    });
                    notifier.updateHoraPrimeraDosis(selectedTime);
                  }
                },
              ),
            ),
          ],
        );

      case 3: // Intervalo de dosis
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildQuestionText('¿Cada cuántas horas debe tomarlo?'),
            const SizedBox(height: 24),
            FormFieldWrapper(
              label: 'Intervalo entre dosis',
              child: TextFormField(
                controller: _dosisController,
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final intervalo = int.tryParse(value) ?? 0;
                  notifier.updateIntervaloDosis(intervalo);
                },
                decoration: AppInputDecoration.withHint('Ej: 8 (cada 8 horas)'),
              ),
            ),
          ],
        );

      case 4: // Duración
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildQuestionText('¿Por cuánto tiempo?'),
            const SizedBox(height: 24),
            DurationSelector(
              duracionNumero: notifier.formData.duracionNumero,
              duracionUnidad: notifier.formData.duracionUnidad,
              esIndefinido: notifier.formData.esIndefinido,
              controller: _duracionController,
              onDuracionNumeroChanged: notifier.updateDuracionNumero,
              onDuracionUnidadChanged: notifier.updateDuracionUnidad,
              onEsIndefinidoChanged: notifier.updateEsIndefinido,
            ),
          ],
        );

      case 5: // Inventario
        return Center(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              _buildQuestionText('¿Cómo quieres registrar tu inventario?'),
              const SizedBox(height: 20),
              FormFieldWrapper(
                label: 'Cantidad actual',
                child: TextFormField(
                  controller: _cantidadActualController,
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    notifier.updateCantidadActual(int.tryParse(value) ?? 0);
                  },
                  decoration: AppInputDecoration.withHint('Ej: 30'),
                ),
              ),
              const SizedBox(height: 12),
              FormFieldWrapper(
                label: 'Cantidad total por caja',
                child: TextFormField(
                  controller: _cantidadTotalController,
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    notifier.updateCantidadTotalCaja(int.tryParse(value) ?? 0);
                  },
                  decoration: AppInputDecoration.withHint('Ej: 60'),
                ),
              ),
              const SizedBox(height: 12),
              FormFieldWrapper(
                label: 'Dosis por toma',
                child: TextFormField(
                  controller: _dosisPorTomaController,
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    notifier.updateDosisPorToma(int.tryParse(value) ?? 1);
                  },
                  decoration: AppInputDecoration.withHint('Ej: 1'),
                ),
              ),
            ],
          ),
        ),
      );

      case 6: // Notas
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildQuestionText('¿Alguna nota o indicación especial?'),
            const SizedBox(height: 4),
            const Text(
              '(Ej: "Tomar con comida", "No conducir")',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            FormFieldWrapper(
              label: 'Notas (Opcional)',
              child: TextFormField(
                controller: _notasController,
                maxLines: null,
                minLines: 3,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                onChanged: notifier.updateNotas,
                decoration: AppInputDecoration.withHint(
                  'Escribe cualquier indicación especial',
                ),
              ),
            ),
          ],
        );

      case 7: // Resumen
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 10.0,
              vertical: 10.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Resumen de la receta',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Revisa los datos antes de confirmar',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.secondaryTextColor,
                  ),
                ),
                const SizedBox(height: 20),

                TreatmentSummaryCard(
                  formData: notifier.formData,
                  summaryInfo: notifier.getSummaryInfo(),
                ),

                const SizedBox(height: 12),

                // Mensaje de confirmación
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Al confirmar, se programarán las alarmas automáticamente para recordarte cada dosis',
                          style: TextStyle(
                            color: AppTheme.primaryTextColor,
                            fontSize: 14,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

      default:
        return Container();
    }
  }
}
