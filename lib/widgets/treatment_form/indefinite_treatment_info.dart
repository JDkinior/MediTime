// lib/widgets/treatment_form/indefinite_treatment_info.dart
import 'package:flutter/material.dart';
import 'package:meditime/theme/app_theme.dart';

/// Widget informativo para tratamientos indefinidos
class IndefiniteTreatmentInfo extends StatelessWidget {
  const IndefiniteTreatmentInfo({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline,
                color: AppTheme.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tratamiento Indefinido',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Este tratamiento se ejecutará de forma continua hasta que lo marques como completado o lo elimines.',
                      style: TextStyle(
                        color: AppTheme.primaryTextColor,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Las dosis se generan automáticamente según sea necesario\n'
                      '• Puedes pausar o detener el tratamiento en cualquier momento\n'
                      '• El calendario mostrará las dosis mes a mes para mejor rendimiento',
                      style: TextStyle(
                        color: AppTheme.secondaryTextColor,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}