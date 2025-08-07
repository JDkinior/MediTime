// lib/widgets/treatment_form/treatment_summary_card.dart
import 'package:flutter/material.dart';
import 'package:meditime/theme/app_theme.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
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
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sección Medicamento con botón PDF
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildSection(
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
              ),
              // Botón PDF
              Container(
                margin: const EdgeInsets.only(top: 30),
                child: IconButton(
                  onPressed: () => _generatePDF(context),
                  icon: const Icon(
                    Icons.picture_as_pdf,
                    color: kInfoColor,
                    size: 32,
                  ),
                  tooltip: 'Descargar PDF',
                ),
              ),
            ],
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
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ),
              Expanded(
                child: Text(
                  '• Hasta ${summaryInfo['endDate']}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
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
                style: const TextStyle(fontSize: 16, color: Colors.black),
              ),
            ),
          ] else ...[
            _buildDivider(),
            _buildSection(
              title: 'Notas',
              child: Text(
                '• Ninguna',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
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

    return schedule
        .map(
          (time) => Padding(
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
        )
        .toList();
  }

  String _formatTimeForPDF(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _generatePDF(BuildContext context) async {
    try {
      final pdf = pw.Document();
      final schedule = formData.generateDailySchedule();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return pw.Container(
              padding: const pw.EdgeInsets.all(24),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: pw.BorderRadius.circular(16),
                border: pw.Border.all(color: PdfColors.grey300, width: 1),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Sección Medicamento (igual que en la tarjeta)
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Medicamento',
                        style: pw.TextStyle(
                          fontSize: 16,
                          color: PdfColors.grey700,
                          fontWeight: pw.FontWeight.normal,
                        ),
                      ),
                      pw.SizedBox(height: 12),
                      pw.Text(
                        formData.nombreMedicamento,
                        style: pw.TextStyle(
                          fontSize: 32,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Presentación: ${formData.presentacion}',
                        style: pw.TextStyle(
                          fontSize: 16,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),

                  // Divider
                  pw.SizedBox(height: 24),
                  pw.Container(height: 1, color: PdfColors.grey300),
                  pw.SizedBox(height: 24),

                  // Sección Horarios y Duración (lado a lado)
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Horarios
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Horarios',
                              style: pw.TextStyle(
                                fontSize: 16,
                                color: PdfColors.grey700,
                                fontWeight: pw.FontWeight.normal,
                              ),
                            ),
                            pw.SizedBox(height: 12),
                            ...schedule.map(
                              (time) => pw.Padding(
                                padding: const pw.EdgeInsets.only(bottom: 4),
                                child: pw.Text(
                                  '- ${_formatTimeForPDF(time)}',
                                  style: pw.TextStyle(
                                    fontSize: 18,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.black,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Duración
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Duración',
                              style: pw.TextStyle(
                                fontSize: 16,
                                color: PdfColors.grey700,
                                fontWeight: pw.FontWeight.normal,
                              ),
                            ),
                            pw.SizedBox(height: 12),
                            pw.Text(
                              summaryInfo['durationText'] ?? '',
                              style: pw.TextStyle(
                                fontSize: 20,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.black,
                              ),
                            ),
                            if (!formData.esIndefinido) ...[
                              pw.SizedBox(height: 4),
                              pw.Text(
                                '(${formData.duracionEnDias} días)',
                                style: pw.TextStyle(
                                  fontSize: 14,
                                  color: PdfColors.grey700,
                                ),
                              ),
                            ],
                            pw.SizedBox(height: 16),
                            pw.Text(
                              'Frecuencia',
                              style: pw.TextStyle(
                                fontSize: 16,
                                color: PdfColors.grey700,
                                fontWeight: pw.FontWeight.normal,
                              ),
                            ),
                            pw.SizedBox(height: 8),
                            pw.Text(
                              'Cada ${formData.intervaloDosis} horas',
                              style: pw.TextStyle(
                                fontSize: 18,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 20),

                  // Información adicional
                  pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          formData.esIndefinido
                              ? '- Dosis generadas automáticamente'
                              : '- Total ${summaryInfo['totalDoses']} dosis',
                          style: pw.TextStyle(
                            fontSize: 14,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Text(
                          '- Hasta ${summaryInfo['endDate']}',
                          style: pw.TextStyle(
                            fontSize: 14,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Divider antes de notas
                  pw.SizedBox(height: 24),
                  pw.Container(height: 1, color: PdfColors.grey300),
                  pw.SizedBox(height: 24),

                  // Notas
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Notas',
                        style: pw.TextStyle(
                          fontSize: 16,
                          color: PdfColors.grey700,
                          fontWeight: pw.FontWeight.normal,
                        ),
                      ),
                      pw.SizedBox(height: 12),
                      pw.Text(
                        formData.notas.isNotEmpty
                            ? '- ${formData.notas}'
                            : '- Ninguna',
                        style: pw.TextStyle(
                          fontSize: 16,
                          color:
                              formData.notas.isNotEmpty
                                  ? PdfColors.black
                                  : PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );

      // Mostrar el PDF para descarga o impresión
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name:
            'tratamiento_${formData.nombreMedicamento.replaceAll(' ', '_')}.pdf',
      );
    } catch (e) {
      // Mostrar error si algo sale mal
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
