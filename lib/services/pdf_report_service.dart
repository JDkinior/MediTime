import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfReportService {
  // Genera y muestra la vista previa del PDF
  Future<void> generateAndShowPdf({
    required String intervalText,
    required int tomadas,
    required int omitidas,
    required List<Map<String, dynamic>> tratamientos,
    required Uint8List chartImage,
  }) async {
    final doc = pw.Document();
    
    // Cargar la fuente para que el PDF la use
    final font = await PdfGoogleFonts.poppinsRegular();
    final boldFont = await PdfGoogleFonts.poppinsBold();

    // Imagen del logo (opcional, pero le da un toque profesional)
    final logoImage = pw.MemoryImage(
      (await rootBundle.load('assets/google_logo.png')).buffer.asUint8List(),
    );

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(logoImage, font),
              pw.SizedBox(height: 20),
              _buildTitle(intervalText, boldFont),
              pw.SizedBox(height: 20),
              _buildSummaryCard(tomadas, omitidas, chartImage, font, boldFont),
              pw.SizedBox(height: 20),
              pw.Text("Desglose por Tratamiento", style: pw.TextStyle(font: boldFont, fontSize: 18)),
              pw.Divider(height: 20),
              _buildTreatmentsTable(tratamientos, font, boldFont),
            ],
          );
        },
      ),
    );

    // Muestra la pantalla de impresión/guardado
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save());
  }

  // --- Widgets Auxiliares para el PDF ---

  pw.Widget _buildHeader(pw.MemoryImage logo, pw.Font font) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Row(
          children: [
            pw.Image(logo, width: 40),
            pw.SizedBox(width: 10),
            pw.Text("MediTime", style: pw.TextStyle(font: font, fontSize: 24, color: PdfColors.blueGrey800)),
          ]
        ),
        pw.Text("Reporte de Adherencia", style: pw.TextStyle(font: font, fontSize: 16)),
      ],
    );
  }

  pw.Widget _buildTitle(String intervalText, pw.Font boldFont) {
    return pw.Text("Periodo del Reporte: $intervalText", style: pw.TextStyle(font: boldFont, fontSize: 20));
  }
  
  pw.Widget _buildSummaryCard(int tomadas, int omitidas, Uint8List chartImage, pw.Font font, pw.Font boldFont) {
    final total = tomadas + omitidas;
    final adherencia = total > 0 ? (tomadas / total) * 100 : 0.0;
    
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Row(
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("Tasa de Adherencia", style: pw.TextStyle(font: boldFont, fontSize: 16)),
              pw.Text("${adherencia.toStringAsFixed(1)}%", style: pw.TextStyle(font: boldFont, fontSize: 40, color: PdfColors.blue800)),
              pw.SizedBox(height: 10),
              pw.Text("Dosis Tomadas: $tomadas", style: pw.TextStyle(font: font)),
              pw.Text("Dosis Omitidas: $omitidas", style: pw.TextStyle(font: font)),
            ]
          ),
          pw.Spacer(),
          pw.Image(pw.MemoryImage(chartImage), width: 150, height: 150),
        ]
      )
    );
  }
  
  pw.Widget _buildTreatmentsTable(List<Map<String, dynamic>> tratamientos, pw.Font font, pw.Font boldFont) {
    final headers = ['Medicamento', 'Cumplimiento', 'Tomadas', 'Programadas'];

    final data = tratamientos.map((t) {
      return [
        t['nombreMedicamento'],
        "${t['adherencia'].toStringAsFixed(1)}%",
        t['tomadas'].toString(),
        t['programadas'].toString(),
      ];
    }).toList();
    
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      headerStyle: pw.TextStyle(font: boldFont, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey),
      cellStyle: pw.TextStyle(font: font),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.center,
        3: pw.Alignment.center,
      },
    );
  }
}