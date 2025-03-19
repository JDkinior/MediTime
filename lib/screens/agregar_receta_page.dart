import 'package:flutter/material.dart';
import 'package:flutter_time_picker_spinner/flutter_time_picker_spinner.dart';
import '../data/medicamentos_data.dart';

class AgregarRecetaPage extends StatefulWidget {
  const AgregarRecetaPage({super.key});

  @override
  _AgregarRecetaPageState createState() => _AgregarRecetaPageState();
}

class _AgregarRecetaPageState extends State<AgregarRecetaPage> {
  int _currentStep = 0;
  final PageController _pageController = PageController();
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

  final TextEditingController _nombreMedicamentoController = TextEditingController();
  final TextEditingController _dosisController = TextEditingController();
  final TextEditingController _vecesPorDiaController = TextEditingController();
  // Añadir controlador para duración:
final TextEditingController _duracionController = TextEditingController();

  @override
  void dispose() {
    _nombreMedicamentoController.dispose();
    _dosisController.dispose();
    _vecesPorDiaController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agregar Receta'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: _buildStep(),
        ),
      ),
    );
  }

  Widget _buildStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildFadeTransition(0),
              _buildFadeTransition(1),
              _buildFadeTransition(2),
              _buildFadeTransition(3),
              _buildFadeTransition(4),
              _buildFadeTransition(5),
            ],
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
                  onPressed: () {
                    setState(() {
                      _currentStep--;
                    });
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                    );
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
                  onPressed: _isStepValid()
                      ? () {
                          setState(() {
                            _currentStep++;
                          });
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeInOut,
                          );
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
      onPressed: () {
        _saveData();
        Navigator.of(context).pop();
      },
      backgroundColor: const Color.fromARGB(255, 92, 214, 96), // Cambiar el color a verde
      foregroundColor: Colors.white, // Color del ícono
      shape: const CircleBorder(),
      heroTag: 'botonFinalizar', // Asegúrate de dar un heroTag único
      child: const Icon(Icons.check), // El ícono de chulito
    ),
  ),

          ],
        ),
      ],
    );
  }

  Widget _buildFadeTransition(int step) {
    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, child) {
        double opacity = 1.0;
        if (_pageController.position.haveDimensions) {
          double offset = _pageController.page! - step;
          opacity = (1 - offset.abs()).clamp(0.0, 1.0);
        }
        return Opacity(
          opacity: opacity,
          child: child,
        );
      },
      child: _buildStepContent(step),
    );
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildQuestionText('Resumen de la receta:'),
            const SizedBox(height: 16),
            Text('Medicamento: $_nombreMedicamento'),
            Text('Presentación: $_presentacion'),
            Text('Hora primera dosis: ${_horaPrimeraDosis.format(context)}'),
            Text('Intervalo entre dosis: $_dosis horas'),
            Text('Duración del tratamiento: $_duracion días'),
            Text('Veces por día: ${_dosis.isNotEmpty ? 24 ~/ int.parse(_dosis) : "No definido"}'),
          ],
        );
      default:
        return Container();
    }
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

bool _isStepValid() {
  switch (_currentStep) {
    case 0: return _nombreMedicamento.isNotEmpty;
    case 1: return _presentacion.isNotEmpty; // Hora siempre válida
    case 2: return true; // Hora siempre válida
    case 3: return _dosis.isNotEmpty && int.parse(_dosis) > 0;
    case 4: return _duracion.isNotEmpty && int.parse(_duracion) > 0;
    default: return false;
  }
}

  void _saveData() {
    MedicamentosData.saveMedicamentoData(
      nombreMedicamento: _nombreMedicamento,
      presentacion: _presentacion,
      duracion: _duracion, // Añadir este campo
      horaPrimeraDosis: _horaPrimeraDosis,
      intervaloDosis: _dosis,
    );
  }
}