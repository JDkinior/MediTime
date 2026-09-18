// lib/widgets/primary_button.dart
import 'package:flutter/material.dart';
import 'package:meditime/theme/app_theme.dart';

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed; // Puede ser nulo para deshabilitar el botón
  final bool isLoading;
  final Gradient? gradient;
  final Color? color;

  const PrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.gradient,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          elevation: 0,
          // Deshabilita el botón si está cargando o si onPressed es nulo
          disabledBackgroundColor: Colors.grey.shade400,
        ),
        onPressed: isLoading ? null : onPressed,
        child: Ink(
          decoration: BoxDecoration(
            gradient: (onPressed != null && !isLoading && color == null)
                ? (gradient ?? AppTheme.buttonGradient)
                : null, // Sin gradiente si está deshabilitado o si se especificó color sólido
            borderRadius: BorderRadius.circular(22),
            color: (onPressed == null || isLoading)
                ? Colors.grey.shade400
                : color,
          ),
          child: Container(
            alignment: Alignment.center,
            child: isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(
                    text,
                    style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ),
    );
  }
}