import 'package:flutter/material.dart';
import 'package:flutter_time_picker_spinner/flutter_time_picker_spinner.dart';
import 'medicamentos_data.dart';

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
  String _frecuencia = '';
  String _dosis = '';
  String _vecesPorDia = '';
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
            _buildQuestionText('¿Cuántas veces debe suministrarlo?'),
            const SizedBox(height: 16),
            DropdownButton<String>(
              value: _frecuencia.isEmpty ? null : _frecuencia,
              hint: const Text('Selecciona una opción'),
              items: const [
                DropdownMenuItem(
                  value: 'una vez por dia',
                  child: Text('Una vez por día'),
                ),
                DropdownMenuItem(
                  value: 'dos veces por dia',
                  child: Text('Dos veces por día'),
                ),
                DropdownMenuItem(
                  value: 'tres veces por dia',
                  child: Text('Tres veces por día'),
                ),
                DropdownMenuItem(
                  value: 'personalizado',
                  child: Text('Personalizado'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _frecuencia = value!;
                });
              },
            ),
            if (_frecuencia == 'personalizado')
              TextField(
                controller: _vecesPorDiaController,
                decoration: const InputDecoration(
                  labelText: 'Número de veces por día',
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  setState(() {
                    _vecesPorDia = value;
                  });
                },
              ),
          ],
        );
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildQuestionText('¿Cuándo debe tomar la primera dosis?'),
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
      case 4:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildQuestionText('¿Cada cuánto debe tomar las dosis?'),
            const SizedBox(height: 16),
            TextField(
              controller: _dosisController,
              decoration: const InputDecoration(
                labelText: 'Intervalo de horas entre dosis',
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
      case 5:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildQuestionText('Resumen de la receta:'),
            const SizedBox(height: 16),
            Text('Medicamento: $_nombreMedicamento'),
            Text('Presentación: $_presentacion'),
            Text('Frecuencia: $_frecuencia'),
            if (_frecuencia == 'personalizado') Text('Veces por día: $_vecesPorDia'),
            Text(
                'Hora primera dosis: ${_horaPrimeraDosis.format(context)}'),
            Text('Intervalo entre dosis: $_dosis horas'),
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
      case 0:
        return _nombreMedicamento.isNotEmpty;
      case 1:
        return _presentacion.isNotEmpty;
      case 2:
        return _frecuencia.isNotEmpty &&
            (_frecuencia != 'personalizado' || _vecesPorDia.isNotEmpty);
      case 3:
        return true;
      case 4:
        return _dosis.isNotEmpty && double.tryParse(_dosis) != null && double.parse(_dosis) > 0;
      default:
        return false;
    }
  }

  void _saveData() {
    MedicamentosData.saveMedicamentoData(
      nombreMedicamento: _nombreMedicamento,
      presentacion: _presentacion,
      frecuencia: _frecuencia,
      vecesPorDia: _frecuencia == 'personalizado' ? _vecesPorDia : null,
      horaPrimeraDosis: _horaPrimeraDosis,
      intervaloDosis: _dosis,
    );
  }
}
