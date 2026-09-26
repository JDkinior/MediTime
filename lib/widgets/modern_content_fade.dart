import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/theme/app_theme.dart';

/// Envoltorio para listas o vistas desplazables que, en modo moderno,
/// añade un difuminado suave en la parte superior al hacer scroll.
///
/// Esto evita que el contenido se corte de manera abrupta debajo de cabeceras
/// fijas (como selectores de intervalo, calendarios o títulos de sección).
/// En modo clásico, no aplica ningún degradado y retorna el hijo original.
class ModernContentFade extends StatefulWidget {
  final Widget child;
  final double height;
  final double topOffset;
  final Color? color;

  const ModernContentFade({
    super.key,
    required this.child,
    this.height = 28.0,
    this.topOffset = 0.0,
    this.color,
  });

  @override
  State<ModernContentFade> createState() => _ModernContentFadeState();
}

class _ModernContentFadeState extends State<ModernContentFade> {
  double _opacity = 0.0;

  void _handleScroll(ScrollNotification notification) {
    if (notification.metrics.axis == Axis.vertical) {
      final extent = notification.metrics.extentBefore;
      final newOpacity = (extent / 16.0).clamp(0.0, 1.0);
      if ((newOpacity - _opacity).abs() > 0.01) {
        setState(() {
          _opacity = newOpacity;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferenceNotifier = context.watch<PreferenceNotifier>();
    final isModern = preferenceNotifier.interfaceStyle == 'modern';

    if (!isModern) {
      return widget.child;
    }

    final bgColor = widget.color ?? AppTheme.backgroundColor;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        _handleScroll(notification);
        return false;
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          widget.child,
          if (_opacity > 0)
            Positioned(
              left: 0,
              right: 0,
              top: widget.topOffset,
              height: widget.height,
              child: IgnorePointer(
                child: Opacity(
                  opacity: _opacity,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          bgColor,
                          bgColor.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
