// lib/widgets/estado_vista.dart

import 'package:flutter/material.dart';
import 'package:meditime/enums/view_state.dart';
import 'package:meditime/widgets/primary_button.dart';
import 'package:meditime/theme/app_theme.dart';

class EstadoVista extends StatelessWidget {
  /// El estado actual de la vista (cargando, éxito, error, vacío).
  final ViewState state;

  /// El widget que se mostrará cuando el estado sea `success`.
  final Widget child;

  /// Mensaje a mostrar en el estado de error.
  final String errorMessage;

  /// Mensaje a mostrar en el estado vacío.
  final String emptyMessage;

  /// Callback que se ejecuta cuando el usuario presiona el botón de reintentar.
  final VoidCallback? onRetry;

  const EstadoVista({
    super.key,
    required this.state,
    required this.child,
    this.errorMessage = 'Ocurrió un error inesperado. Por favor, intenta de nuevo.',
    this.emptyMessage = 'No se encontraron datos.',
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case ViewState.loading:
        return const Center(
          child: CircularProgressIndicator(),
        );
      case ViewState.error:
        return _buildMessageUI(
          context,
          icon: Icons.error_outline,
          iconColor: kErrorColor,
          message: errorMessage,
          showRetryButton: true,
        );
      case ViewState.empty:
        return _buildMessageUI(
          context,
          icon: Icons.inbox_outlined,
          iconColor: Colors.grey,
          message: emptyMessage,
        );
      case ViewState.success:
        return child;
      }
  }

  /// Construye la interfaz para los estados de error y vacío.
  Widget _buildMessageUI(BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String message,
    bool showRetryButton = false,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: iconColor),
            const SizedBox(height: 24),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, color: Colors.black54),
            ),
            if (showRetryButton && onRetry != null) ...[
              const SizedBox(height: 32),
              PrimaryButton(
                text: 'Reintentar',
                onPressed: onRetry!,
              ),
            ]
          ],
        ),
      ),
    );
  }
}