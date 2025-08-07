// lib/widgets/treatment_form/form_field_wrapper.dart
import 'package:flutter/material.dart';

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
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
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
              color: Colors.grey[600],
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
    fillColor: Colors.white,
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
        color: Colors.grey[300]!,
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
    hintStyle: TextStyle(color: Colors.grey[400]),
  );
}