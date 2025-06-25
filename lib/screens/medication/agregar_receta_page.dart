// lib/screens/agregar_receta_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_time_picker_spinner/flutter_time_picker_spinner.dart';
import 'dart:math';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:provider/provider.dart'; // CAMBIO: Importar Provider

// CAMBIO: Importar los servicios
import 'package:meditime/services/auth_service.dart';
import 'package:meditime/services/firestore_service.dart';
import 'package:meditime/alarm_callback_handler.dart';

class AgregarRecetaPage extends StatefulWidget {
  const AgregarRecetaPage({super.key});

  @override
  _AgregarRecetaPageState createState() => _AgregarRecetaPageState();
}

class _AgregarRecetaPageState extends State<AgregarRecetaPage> {
  int _currentStep = 0;
  final PageController _pageController = PageController();
  bool _isAnimating = false;

  // Controladores y variables para el formulario (sin cambios)
  String _nombreMedicamento = '';
  String _presentacion = '';
  String _duracion = '';
  String _dosis = '';
  TimeOfDay _horaPrimeraDosis = TimeOfDay.now();
  final TextEditingController _notasController = TextEditingController();
  String _notas = '';
  final List<String> _presentaciones = [
    'Comprimidos', 'Grageas', 'Cápsulas', 'Sobres',
    'Jarabes', 'Gotas', 'Suspensiones', 'Emulsiones'
  ];
  final TextEditingController _nombreMedicamentoController = TextEditingController();
  final TextEditingController _dosisController = TextEditingController();
  final TextEditingController _vecesPorDiaController = TextEditingController();
  final TextEditingController _duracionController = TextEditingController();


  @override
  void dispose() {
    _nombreMedicamentoController.dispose();
    _dosisController.dispose();
    _vecesPorDiaController.dispose();
    _duracionController.dispose();
    _pageController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  // CAMBIO: La función de guardar ahora usa los servicios
  Future<void> _saveData() async {
    if (!mounted) return;

    // Obtener los servicios de Provider
    final authService = context.read<AuthService>();
    final firestoreService = context.read<FirestoreService>();
    final user = authService.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Usuario no encontrado.'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      if (_duracion.isEmpty || _dosis.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, completa la duración y el intervalo de dosis.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final int prescriptionAlarmManagerId = Random().nextInt(2147483647);
      final int intervaloEnHoras = int.parse(_dosis);
      final int duracionEnDias = int.parse(_duracion);
      final int firstLocalNotificationId = Random().nextInt(100000);

      final now = DateTime.now();
      DateTime primeraDosisDateTime = DateTime(
        now.year, now.month, now.day,
        _horaPrimeraDosis.hour, _horaPrimeraDosis.minute,
      );

      if (primeraDosisDateTime.isBefore(now)) {
        primeraDosisDateTime = primeraDosisDateTime.add(const Duration(days: 1));
      }

      final DateTime fechaInicioTratamiento = primeraDosisDateTime;
      final DateTime fechaFinTratamiento = fechaInicioTratamiento.add(Duration(days: duracionEnDias));
      
      // CAMBIO: Llamar al método del servicio para guardar en Firestore
      await firestoreService.saveMedicamento(
        userId: user.uid,
        nombreMedicamento: _nombreMedicamento,
        presentacion: _presentacion,
        duracion: _duracion,
        horaPrimeraDosis: _horaPrimeraDosis,
        intervaloDosis: _dosis,
        prescriptionAlarmId: prescriptionAlarmManagerId,
        fechaInicioTratamiento: fechaInicioTratamiento,
        fechaFinTratamiento: fechaFinTratamiento,
        notas: _notas,
      );

      // La lógica de la alarma no cambia, ya que está bien encapsulada.
      if (primeraDosisDateTime.isBefore(fechaFinTratamiento)) {
        debugPrint(
            "Programando PRIMERA alarma para $_nombreMedicamento a las $primeraDosisDateTime con ID de Alarma (AlarmManager): $prescriptionAlarmManagerId");
        
        await AndroidAlarmManager.oneShotAt(
          primeraDosisDateTime,
          prescriptionAlarmManagerId,
          alarmCallbackLogic,
          exact: true,
          wakeup: true,
          alarmClock: true,
          rescheduleOnReboot: true,
          params: {
            'currentNotificationId': firstLocalNotificationId,
            'nombreMedicamento': _nombreMedicamento,
            'presentacion': _presentacion,
            'intervaloHoras': intervaloEnHoras,
            'fechaFinTratamientoString': fechaFinTratamiento.toIso8601String(),
            'prescriptionAlarmId': prescriptionAlarmManagerId,
          },
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Recordatorios configurados para $_nombreMedicamento'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error al guardar datos o programar alarma: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al configurar recordatorios: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agregar Receta'),
      ),
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
                  // --- INICIO DE LA OPTIMIZACIÓN ---
                  return AnimatedBuilder(
                    animation: _pageController,
                    // 1. El contenido del paso se construye una sola vez y se pasa como 'child'.
                    child: _buildStepContent(index),
                    // 2. El 'builder' recibe el 'child' ya construido.
                    builder: (context, child) {
                      double opacity = 1.0;
                      if (_pageController.position.haveDimensions) {
                        opacity = (1 - (_pageController.page! - index).abs()).clamp(0.0, 1.0);
                      }
                      // 3. Solo reconstruimos el Opacity, que es muy eficiente.
                      return Opacity(
                        opacity: opacity,
                        child: child, // Usamos el 'child'.
                      );
                    },
                  );
                  // --- FIN DE LA OPTIMIZACIÓN ---
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (_currentStep > 0)
                  SizedBox(
                    width: 70,
                    height: 70,
                    child: FloatingActionButton(
                      onPressed: _isAnimating
                          ? null // Si está animando, el botón está desactivado
                          : () async {
                              setState(() {
                                _isAnimating = true;
                              });
                              // YA NO CAMBIAMOS _currentStep AQUÍ
                              await _pageController.previousPage(
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeInOut,
                              );
                              // Esperamos a que la animación termine y luego reactivamos el botón
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
                      onPressed: _isStepValid() && !_isAnimating
                          ? () async {
                              setState(() {
                                _isAnimating = true;
                              });
                              // YA NO CAMBIAMOS _currentStep AQUÍ
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
                      backgroundColor: _isStepValid() ? Colors.blue : Colors.grey,
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
                    // LÓGICA MODIFICADA AQUÍ
                    onPressed: _isAnimating // <-- 1. Comprueba si ya hay una acción en curso
                        ? null // <-- 2. Si es así, desactiva el botón
                        : () async {
                            setState(() {
                              _isAnimating = true; // <-- 3. Desactiva inmediatamente el botón
                            });

                            await _saveData(); // Espera a que los datos se guarden

                            if (mounted) {
                              Navigator.of(context).pop(); // Cierra la pantalla de forma segura
                            }
                            // No es necesario volver a poner _isAnimating en false,
                            // porque esta página será destruida.
                          },
                    child: const Icon(Icons.check),
                  ),
                ),
              ],
            ),
             const SizedBox(height: 16), // Espacio adicional en la parte inferior
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionText(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 30, // Ajustado para mejor visualización
        color: Colors.blue,
        fontWeight: FontWeight.bold,
      ),
      textAlign: TextAlign.center,
    );
  }

  bool _isStepValid() {
    switch (_currentStep) {
      case 0:
        return _nombreMedicamentoController.text.isNotEmpty;
      case 1:
        return _presentacion.isNotEmpty;
      case 2:
        return true; // La hora siempre es válida ya que tiene un valor por defecto
      case 3:
        return _dosisController.text.isNotEmpty &&
            (int.tryParse(_dosisController.text) ?? 0) > 0;
      case 4:
        return _duracionController.text.isNotEmpty &&
            (int.tryParse(_duracionController.text) ?? 0) > 0;
      case 5: // El nuevo paso para las notas
        return true; // Las notas son opcionales
      case 6: // El resumen ahora es el paso 6
        return true;
      default:
        return false;
    }
  }
  Widget _buildStepContent(int step) {
    switch (step) {
        case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildQuestionText('¿Qué medicamento vas a agregar?'),
            const SizedBox(height: 16),
            TextField(
              controller: _nombreMedicamentoController,
              decoration: const InputDecoration(
                labelText: 'Nombre del medicamento',
              ),
              onChanged: (value) {
                setState(() {
                  _nombreMedicamento = value;
                });
              },
            ),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildQuestionText('¿Cuál es la presentación del medicamento?'),
            const SizedBox(height: 16),
            DropdownButton<String>(
              value: _presentacion.isEmpty ? null : _presentacion,
              hint: const Text('Selecciona una opción'),
              items: _presentaciones.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _presentacion = value!;
                });
              },
            ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildQuestionText('¿Cuándo será la primera dosis?'),
            const SizedBox(height: 16),
            Text(
              'Hora seleccionada: ${_horaPrimeraDosis.format(context)}',
              style: const TextStyle(fontSize: 16),
            ),
            SizedBox(
              height: 150,
              child: TimePickerSpinner(
                time: DateTime(2020, 1, 1, _horaPrimeraDosis.hour,
                    _horaPrimeraDosis.minute),
                is24HourMode: false,
                onTimeChange: (time) {
                  setState(() {
                    _horaPrimeraDosis =
                        TimeOfDay(hour: time.hour, minute: time.minute);
                  });
                },
              ),
            ),
          ],
        );
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildQuestionText('¿Cada cuántas horas debe tomarlo?'),
            const SizedBox(height: 16),
            TextField(
              controller: _dosisController,
              decoration: const InputDecoration(
                labelText: 'Ej: 8 (cada 8 horas)',
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {
                  _dosis = value;
                });
              },
            ),
          ],
        );
      case 4:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildQuestionText('¿Por cuántos días?'),
            const SizedBox(height: 16),
            TextField(
              controller: _duracionController, // Usar controlador
              decoration: const InputDecoration(
                labelText: 'Duración del tratamiento',
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {
                  _duracion = value;
                });
              },
            ),
          ],
        );
            case 5: // <-- NUEVO PASO
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildQuestionText('¿Alguna nota o indicación especial?'),
          const SizedBox(height: 4),
          const Text('(Ej: "Tomar con comida", "No conducir")', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          TextField(
            controller: _notasController,
            decoration: const InputDecoration(
              labelText: 'Notas (Opcional)',
            ),
            onChanged: (value) {
              setState(() {
                _notas = value;
              });
            },
          ),
        ],
      );
      case 6:
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildQuestionText('Resumen de la receta:'),
              const SizedBox(height: 24),
              Text('Medicamento: ${_nombreMedicamentoController.text}', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              Text('Presentación: $_presentacion', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              Text('Hora primera dosis: ${_horaPrimeraDosis.format(context)}', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              Text('Intervalo entre dosis: ${_dosisController.text} horas', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              Text('Duración del tratamiento: ${_duracionController.text} días', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              Text(
                  'Veces por día: ${(_dosisController.text.isNotEmpty && (int.tryParse(_dosisController.text) ?? 0) > 0) ? (24 / int.parse(_dosisController.text)).round() : "No definido"}',
                  style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      );
      default:
      return Container();
    }
  }
}
