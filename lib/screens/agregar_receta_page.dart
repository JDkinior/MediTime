import 'package:flutter/material.dart';
import 'package:flutter_time_picker_spinner/flutter_time_picker_spinner.dart';
import '../data/medicamentos_data.dart';
import 'dart:math'; // Para Random
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:meditime/alarm_callback_handler.dart'; // Importa tu callback

class AgregarRecetaPage extends StatefulWidget {
  const AgregarRecetaPage({super.key});

  @override
  _AgregarRecetaPageState createState() => _AgregarRecetaPageState();
}

class _AgregarRecetaPageState extends State<AgregarRecetaPage> {
  int _currentStep = 0;
  final PageController _pageController = PageController();
  bool _isAnimating = false;  
  String _nombreMedicamento = '';
  String _presentacion = '';
  String _duracion = ''; // En días
  String _dosis = '';
  TimeOfDay _horaPrimeraDosis = TimeOfDay.now();

  final List<String> _presentaciones = [
    'Comprimidos',
    'Grageas',
    'Cápsulas',
    'Sobres',
    'Jarabes',
    'Gotas',
    'Suspensiones',
    'Emulsiones'
  ];

  final TextEditingController _nombreMedicamentoController =
      TextEditingController();
  final TextEditingController _dosisController = TextEditingController();
  final TextEditingController _vecesPorDiaController =
      TextEditingController(); // Aunque no se usa directamente para guardar, mantenlo si planeas usarlo
  final TextEditingController _duracionController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _nombreMedicamentoController.dispose();
    _dosisController.dispose();
    _vecesPorDiaController.dispose();
    _duracionController.dispose(); // Asegúrate de liberar este también
    _pageController.dispose();
    super.dispose();
  }

  // Función _saveData corregida y explícitamente Future<void>
  Future<void> _saveData() async { // Asegúrate de que 'async' está aquí y el tipo de retorno es Future<void>
    try {
      final int prescriptionAlarmManagerId = Random().nextInt(2147483647);

      await MedicamentosData.saveMedicamentoData(
        nombreMedicamento: _nombreMedicamento,
        presentacion: _presentacion,
        duracion: _duracion,
        horaPrimeraDosis: _horaPrimeraDosis,
        intervaloDosis: _dosis,
      );

      final now = DateTime.now();
      DateTime primeraDosisDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        _horaPrimeraDosis.hour,
        _horaPrimeraDosis.minute,
      );

      if (primeraDosisDateTime.isBefore(now)) {
        primeraDosisDateTime = primeraDosisDateTime.add(const Duration(days: 1));
      }

      // Validar que _duracion y _dosis no estén vacíos antes de parsear
      if (_duracion.isEmpty || _dosis.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Por favor, completa la duración y el intervalo de dosis.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return; // Salir si los campos numéricos están vacíos
      }

      final int duracionEnDias = int.parse(_duracion);
      final DateTime fechaFinTratamiento =
          primeraDosisDateTime.add(Duration(days: duracionEnDias));
      final int intervaloEnHoras = int.parse(_dosis);
      final int firstLocalNotificationId = Random().nextInt(100000);

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
              content:
                  Text('Recordatorios configurados para $_nombreMedicamento'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'La fecha de primera dosis es posterior a la fecha de fin de tratamiento.'),
              backgroundColor: Colors.orange,
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
    // No llamar a Navigator.pop() aquí
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
                itemCount: 6,
                onPageChanged: (page) {
                  setState(() {
                    _currentStep = page;
                  });
                },
                itemBuilder: (context, index) {
                  // SOLUCIÓN: Pasa el contenido del paso a la propiedad 'child'.
                  // Se construirá solo una vez.
                  return AnimatedBuilder(
                    animation: _pageController,
                    child: _buildStepContent(index), // <-- 1. Mueve la construcción aquí

                    // El builder ahora recibe el widget pre-construido.
                    builder: (context, child) {
                      double opacity = 1.0;
                      if (_pageController.position.haveDimensions) {
                        opacity = (1 - (_pageController.page! - index).abs()).clamp(0.0, 1.0);
                      }

                      // La lógica de reconstrucción ahora es súper ligera.
                      // Solo reconstruye el Opacity, no el contenido completo.
                      return Opacity(
                        opacity: opacity,
                        child: child, // <-- 2. Usa el 'child' pre-construido aquí
                      );
                    },
                  );
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
                if (_currentStep < 5)
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
              if (_currentStep == 5)
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
      case 5:
        return true; // El resumen siempre es válido para mostrar
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
      case 5:
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
