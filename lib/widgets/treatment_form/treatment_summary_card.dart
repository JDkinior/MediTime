// lib/widgets/treatment_form/treatment_summary_card.dart
import 'package:flutter/material.dart';
import 'package:meditime/models/treatment_form_data.dart';

/// Widget para mostrar el resumen del tratamiento
class TreatmentSummaryCard extends StatelessWidget {
  final TreatmentFormData formData;
  final Map<String, String> summaryInfo;

  const TreatmentSummaryCard({
    super.key,
    required this.formData,
    required this.summaryInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sección Medicamento
          _buildSection(
            title: 'Medicamento',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formData.nombreMedicamento,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Presentación: ${formData.presentacion}',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          _buildDivider(),

          // Sección Horarios y Duración
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Horarios
              Expanded(
                child: _buildSection(
                  title: 'Horarios',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _generateScheduleTimes(context),
                  ),
                ),
              ),

              // Duración
              Expanded(
                child: _buildSection(
                  title: 'Duración',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summaryInfo['durationText'] ?? '',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      if (!formData.esIndefinido) ...[
                        const SizedBox(height: 4),
                        Text(
                          '(${formData.duracionEnDias} días)',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        'Frecuencia',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Cada ${formData.intervaloDosis} horas',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Información adicional
          Row(
            children: [
              Expanded(
                child: Text(
                  formData.esIndefinido 
                      ? '• Dosis generadas automáticamente'
                      : '• Total ${summaryInfo['totalDoses']} dosis',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  '• Hasta ${summaryInfo['endDate']}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),

          // Notas (solo si hay)
          if (formData.notas.isNotEmpty) ...[
            _buildDivider(),
            _buildSection(
              title: 'Notas',
              child: Text(
                '• ${formData.notas}',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                ),
              ),
            ),
          ] else ...[
            _buildDivider(),
            _buildSection(
              title: 'Notas',
              child: Text(
                '• Ninguna',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildDivider() {
    return Column(
      children: [
        const SizedBox(height: 24),
        Divider(color: Colors.grey[300]),
        const SizedBox(height: 24),
      ],
    );
  }

  List<Widget> _generateScheduleTimes(BuildContext context) {
    final schedule = formData.generateDailySchedule();
    
    if (schedule.isEmpty) {
      return [
        Text(
          '• No definido',
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),
      ];
    }

    return schedule.map((time) => 
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          '• ${time.format(context)}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
      ),
    ).toList();
  }
}