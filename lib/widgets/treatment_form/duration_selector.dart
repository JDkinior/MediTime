// lib/widgets/treatment_form/duration_selector.dart
import 'package:flutter/material.dart';
import 'package:meditime/models/treatment_form_data.dart';
import 'package:meditime/widgets/treatment_form/form_field_wrapper.dart';

/// Widget para seleccionar la duración del tratamiento
class DurationSelector extends StatelessWidget {
  final int duracionNumero;
  final DurationUnit duracionUnidad;
  final bool esIndefinido;
  final TextEditingController controller;
  final Function(int) onDuracionNumeroChanged;
  final Function(DurationUnit) onDuracionUnidadChanged;
  final Function(bool) onEsIndefinidoChanged;

  const DurationSelector({
    super.key,
    required this.duracionNumero,
    required this.duracionUnidad,
    required this.esIndefinido,
    required this.controller,
    required this.onDuracionNumeroChanged,
    required this.onDuracionUnidadChanged,
    required this.onEsIndefinidoChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FormFieldWrapper(
      label: 'Duración del tratamiento',
      child: Column(
        children: [
          Row(
            children: [
              // Campo numérico
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  enabled: !esIndefinido,
                  onChanged: (value) {
                    final numero = int.tryParse(value) ?? 1;
                    onDuracionNumeroChanged(numero);
                  },
                  decoration: AppInputDecoration.withHint(
                    esIndefinido ? '' : '29'
                  ).copyWith(
                    fillColor: esIndefinido ? Colors.grey[100] : Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Dropdown de unidades
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  value: esIndefinido ? 'Indefinido' : duracionUnidad.displayName,
                  decoration: AppInputDecoration.standard,
                  items: [
                    ...DurationUnit.values.map((unit) => 
                      DropdownMenuItem<String>(
                        value: unit.displayName,
                        child: Text(unit.displayName),
                      )
                    ),
                    const DropdownMenuItem<String>(
                      value: 'Indefinido',
                      child: Text('Indefinido'),
                    ),
                  ],
                  onChanged: (String? newValue) {
                    if (newValue == 'Indefinido') {
                      onEsIndefinidoChanged(true);
                      controller.clear();
                    } else {
                      onEsIndefinidoChanged(false);
                      final unit = DurationUnit.values.firstWhere(
                        (u) => u.displayName == newValue,
                        orElse: () => DurationUnit.days,
                      );
                      onDuracionUnidadChanged(unit);
                      if (controller.text.isEmpty) {
                        controller.text = '1';
                        onDuracionNumeroChanged(1);
                      }
                    }
                  },
                  icon: const Icon(Icons.keyboard_arrow_down),
                ),
              ),
            ],
          ),
          
          // Mensaje informativo para indefinido
          if (esIndefinido) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue[700],
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tratamiento Indefinido - Optimizado',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 32),
                    child: Text(
                      '• Las dosis se generan automáticamente según sea necesario\n'
                      '• Mejor rendimiento en el calendario y la aplicación\n'
                      '• Puedes pausar o detener el tratamiento en cualquier momento',
                      style: TextStyle(
                        color: Colors.blue[600],
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}