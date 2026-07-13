// lib/widgets/treatment_form/form_field_wrapper.dart
import 'package:flutter/material.dart';
import 'package:meditime/theme/app_theme.dart';

/// Widget wrapper para campos de formulario con estilo consistente
class FormFieldWrapper extends StatelessWidget {
  final String label;
  final Widget child;
  final String? helperText;

  const FormFieldWrapper({
    super.key,
    required this.label,
    required this.child,
    this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.primaryTextColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        child,
        if (helperText != null) ...[
          const SizedBox(height: 8),
          Text(
            helperText!,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.secondaryTextColor,
            ),
          ),
        ],
      ],
    );
  }
}

/// Input decoration consistente para todos los campos
class AppInputDecoration {
  static InputDecoration get standard => InputDecoration(
    fillColor: AppTheme.cardColor,
    filled: true,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: const BorderSide(
        color: Colors.transparent,
        width: 2,
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: const BorderSide(
        color: Colors.transparent,
        width: 2,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: const BorderSide(
        color: Color(0xFF41B8DB),
        width: 2,
      ),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide(
        color: AppTheme.borderColor,
        width: 1,
      ),
    ),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: 20,
      vertical: 18,
    ),
  );

  static InputDecoration withHint(String hint) => standard.copyWith(
    hintText: hint,
    hintStyle: TextStyle(color: AppTheme.secondaryTextColor.withValues(alpha: 0.6)),
  );
}