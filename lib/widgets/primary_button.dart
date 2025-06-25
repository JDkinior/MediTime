// lib/widgets/primary_button.dart
import 'package:flutter/material.dart';

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed; // Puede ser nulo para deshabilitar el botón
  final bool isLoading;

  const PrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
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
            gradient: onPressed != null && !isLoading
                ? const LinearGradient(
                    colors: [
                      Color.fromARGB(255, 73, 194, 255),
                      Color.fromARGB(255, 47, 109, 180),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null, // Sin gradiente si está deshabilitado
            borderRadius: BorderRadius.circular(22),
            color: onPressed == null || isLoading ? Colors.grey.shade400 : null,
          ),
          child: Container(
            alignment: Alignment.center,
            child: isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(
                    text,
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
          ),
        ),
      ),
    );
  }
}