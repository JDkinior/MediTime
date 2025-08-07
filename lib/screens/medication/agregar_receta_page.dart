// lib/screens/medication/agregar_receta_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_time_picker_spinner/flutter_time_picker_spinner.dart';
import 'package:provider/provider.dart';
import 'package:meditime/screens/shared/guia_optimizacion_page.dart';
import 'package:meditime/notifiers/treatment_form_notifier.dart';
import 'package:meditime/widgets/treatment_form/form_field_wrapper.dart';
import 'package:meditime/widgets/treatment_form/duration_selector.dart';
import 'package:meditime/widgets/treatment_form/treatment_summary_card.dart';

class AgregarRecetaPage extends StatefulWidget {
  const AgregarRecetaPage({super.key});

  @override
  _AgregarRecetaPageState createState() => _AgregarRecetaPageState();
}

class _AgregarRecetaPageState extends State<AgregarRecetaPage> {
  int _currentStep = 0;
  final PageController _pageController = PageController();
  bool _isAnimating = false;

  // Controladores de texto
  final TextEditingController _nombreMedicamentoController = TextEditingController();
  final TextEditingController _dosisController = TextEditingController();
  final TextEditingController _duracionController = TextEditingController();
  final TextEditingController _notasController = TextEditingController();

  @override
  void dispose() {
    _nombreMedicamentoController.dispose();
    _dosisController.dispose();
    _duracionController.dispose();
    _notasController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  /// Guarda el tratamiento usando el notifier
  Future<void> _saveData() async {
    if (!mounted) return;

    final notifier = context.read<TreatmentFormNotifier>();
    final success = await notifier.saveTreatment();

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Recordatorios configurados para ${notifier.formData.nombreMedicamento}',
          ),
          backgroundColor: Colors.green,
        ),
      );
      
      // Mostrar consejos para optimizar las notificaciones
      await _showBatteryOptimizationTip();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(notifier.errorMessage ?? 'Error al guardar el tratamiento'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showBatteryOptimizationTip() async {
    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Optimización de Recordatorios'),
          content: const Text(
            'Para asegurar que recibas tus recordatorios a tiempo, es recomendable realizar unos ajustes en tu teléfono.\n\n¿Quieres ver cómo?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Ahora no'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Cierra el diálogo primero

                // SOLUCIÓN: Usar el contexto del widget principal y un delay
                Future.delayed(const Duration(milliseconds: 100), () {
                  if (mounted) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const GuiaOptimizacionPage(),
                      ),
                    );
                  }
                });
              },
              child: const Text('Ver guía'),
            ),
          ],
        );
      },
    );
  }



  @override
  Widget build(BuildContext context) {
    return Consumer<TreatmentFormNotifier>(
      builder: (context, notifier, child) {
        return Scaffold(
          appBar: AppBar(title: const Text('Agregar Receta')),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 7,
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
                            opacity = (1 - (_pageController.page! - index).abs())
                                .clamp(0.0, 1.0);
                          }
                          return Opacity(
                            opacity: opacity,
                            child: child,
                          );
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
            width: 70,
            height: 70,
            child: FloatingActionButton(
              onPressed: _isAnimating ? null : () async {
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
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              heroTag: 'botonAnterior',
              child: const Icon(Icons.arrow_back),
            ),
          ),
        if (_currentStep < 6)
          SizedBox(
            width: 70,
            height: 70,
            child: FloatingActionButton(
              onPressed: notifier.isStepValid(_currentStep) && !_isAnimating
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
              backgroundColor: notifier.isStepValid(_currentStep) ? Colors.blue : Colors.grey,
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              heroTag: 'botonSiguiente',
              child: const Icon(Icons.arrow_forward),
            ),
          ),
        if (_currentStep == 6)
          SizedBox(
            width: 70,
            height: 70,
            child: FloatingActionButton(
              backgroundColor: const Color.fromARGB(255, 92, 214, 96),
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              heroTag: 'botonFinalizar',
              onPressed: (_isAnimating || notifier.isLoading) ? null : () async {
                setState(() {
                  _isAnimating = true;
                });

                await _saveData();

                if (mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: notifier.isLoading 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.check),
            ),
          ),
      ],
    );
  }

  Widget _buildQuestionText(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 30,
        color: Colors.blue,
        fontWeight: FontWeight.bold,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildStepContent(int step, TreatmentFormNotifier notifier) {
    switch (step) {
      case 0: // Nombre del medicamento
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildQuestionText('¿Qué medicamento vas a agregar?'),
            const SizedBox(height: 24),
            FormFieldWrapper(
              label: 'Nombre del medicamento',
              child: TextFormField(
                controller: _nombreMedicamentoController,
                onChanged: notifier.updateNombreMedicamento,
                decoration: AppInputDecoration.withHint(
                  'Escribe el nombre del medicamento'
                ),
              ),
            ),
          ],
        );

      case 1: // Presentación
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildQuestionText('¿Cuál es la presentación del medicamento?'),
            const SizedBox(height: 16),
            DropdownButton<String>(
              value: notifier.formData.presentacion.isEmpty 
                  ? null 
                  : notifier.formData.presentacion,
              hint: const Text('Selecciona una opción'),
              items: notifier.presentaciones.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (value) => notifier.updatePresentacion(value!),
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
                  2020, 1, 1,
                  notifier.formData.horaPrimeraDosis.hour,
                  notifier.formData.horaPrimeraDosis.minute,
                ),
                is24HourMode: false,
                onTimeChange: (time) {
                  notifier.updateHoraPrimeraDosis(
                    TimeOfDay(hour: time.hour, minute: time.minute)
                  );
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

      case 5: // Notas
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
                  'Escribe cualquier indicación especial'
                ),
              ),
            ),
          ],
        );

      case 6: // Resumen
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Resumen de la receta',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Revisa los datos antes de confirmar',
                  style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                ),
                const SizedBox(height: 20),
                
                TreatmentSummaryCard(
                  formData: notifier.formData,
                  summaryInfo: notifier.getSummaryInfo(),
                ),

                const SizedBox(height: 10),

                // Mensaje de confirmación
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue[700],
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Al confirmar, se programarán las alarmas automáticamente para recordarte cada dosis',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontSize: 14,
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
