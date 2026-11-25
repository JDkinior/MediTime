import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meditime/notifiers/preference_notifier.dart';

/// Envoltorio para listas o vistas desplazables que, en modo moderno,
/// añade un difuminado suave en los extremos (superior, inferior o ambos) al hacer scroll.
///
/// Esto evita que el contenido se corte de manera abrupta debajo de cabeceras fijas
/// o barras inferiores / compositores de mensajes.
/// Si la opción de difuminado está desactivada o el modo es clásico, retorna el hijo directamente.
class ModernContentFade extends StatefulWidget {
  final Widget child;
  final double height;
  final double? bottomHeight;
  final double topOffset;
  final double bottomOffset;
  final Color? color;
  final bool enableTopFade;
  final bool enableBottomFade;

  const ModernContentFade({
    super.key,
    required this.child,
    this.height = 28.0,
    this.bottomHeight,
    this.topOffset = 0.0,
    this.bottomOffset = 0.0,
    this.color,
    this.enableTopFade = true,
    this.enableBottomFade = false,
  });

  @override
  State<ModernContentFade> createState() => _ModernContentFadeState();
}

class _ModernContentFadeState extends State<ModernContentFade> {
  final ValueNotifier<double> _topOpacity = ValueNotifier<double>(0.0);
  final ValueNotifier<double> _bottomOpacity = ValueNotifier<double>(0.0);

  @override
  void dispose() {
    _topOpacity.dispose();
    _bottomOpacity.dispose();
    super.dispose();
  }

  void _handleMetrics(ScrollMetrics metrics) {
    if (metrics.axis != Axis.vertical) return;

    final double newTopOpacity = widget.enableTopFade
        ? (metrics.extentBefore / 16.0).clamp(0.0, 1.0)
        : 0.0;
    final double newBottomOpacity = widget.enableBottomFade
        ? (metrics.extentAfter / 16.0).clamp(0.0, 1.0)
        : 0.0;

    if ((newTopOpacity - _topOpacity.value).abs() > 0.01 ||
        (newTopOpacity == 0.0 && _topOpacity.value != 0.0) ||
        (newTopOpacity == 1.0 && _topOpacity.value != 1.0)) {
      _topOpacity.value = newTopOpacity;
    }

    if ((newBottomOpacity - _bottomOpacity.value).abs() > 0.01 ||
        (newBottomOpacity == 0.0 && _bottomOpacity.value != 0.0) ||
        (newBottomOpacity == 1.0 && _bottomOpacity.value != 1.0)) {
      _bottomOpacity.value = newBottomOpacity;
    }
  }

  @override
  void didUpdateWidget(ModernContentFade oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enableTopFade && _topOpacity.value != 0.0) {
      _topOpacity.value = 0.0;
    }
    if (!widget.enableBottomFade && _bottomOpacity.value != 0.0) {
      _bottomOpacity.value = 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pref = context.select<PreferenceNotifier, ({bool isModern, bool enableScrollFade})>(
      (p) => (
        isModern: p.interfaceStyle == 'modern',
        enableScrollFade: p.enableScrollFade,
      ),
    );

    if (!pref.isModern || !pref.enableScrollFade) {
      return widget.child;
    }

    final bgColor = widget.color ?? Theme.of(context).scaffoldBackgroundColor;
    final effectiveBottomHeight = widget.bottomHeight ?? widget.height;

    return NotificationListener<Notification>(
      onNotification: (notification) {
        if (notification is ScrollNotification) {
          _handleMetrics(notification.metrics);
        } else if (notification is ScrollMetricsNotification) {
          _handleMetrics(notification.metrics);
        }
        return false;
      },
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          widget.child,
          if (widget.enableTopFade)
            ValueListenableBuilder<double>(
              valueListenable: _topOpacity,
              builder: (_, opacity, __) {
                if (opacity <= 0.0) return const SizedBox.shrink();
                return Positioned(
                  left: 0,
                  right: 0,
                  top: widget.topOffset.clamp(0.0, double.infinity),
                  height: widget.height,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            bgColor.withValues(alpha: opacity),
                            bgColor.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          if (widget.enableBottomFade)
            ValueListenableBuilder<double>(
              valueListenable: _bottomOpacity,
              builder: (_, opacity, __) {
                if (opacity <= 0.0) return const SizedBox.shrink();
                return Positioned(
                  left: 0,
                  right: 0,
                  bottom: widget.bottomOffset.clamp(0.0, double.infinity),
                  height: effectiveBottomHeight,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            bgColor.withValues(alpha: opacity),
                            bgColor.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
