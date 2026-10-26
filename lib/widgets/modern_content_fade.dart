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
  double _topOpacity = 0.0;
  double _bottomOpacity = 0.0;

  void _handleMetrics(ScrollMetrics metrics) {
    if (metrics.axis != Axis.vertical) return;

    double newTopOpacity = _topOpacity;
    double newBottomOpacity = _bottomOpacity;

    if (widget.enableTopFade) {
      final extentBefore = metrics.extentBefore;
      newTopOpacity = (extentBefore / 16.0).clamp(0.0, 1.0);
    } else {
      newTopOpacity = 0.0;
    }

    if (widget.enableBottomFade) {
      final extentAfter = metrics.extentAfter;
      newBottomOpacity = (extentAfter / 16.0).clamp(0.0, 1.0);
    } else {
      newBottomOpacity = 0.0;
    }

    if ((newTopOpacity - _topOpacity).abs() > 0.01 ||
        (newBottomOpacity - _bottomOpacity).abs() > 0.01) {
      setState(() {
        _topOpacity = newTopOpacity;
        _bottomOpacity = newBottomOpacity;
      });
    }
  }

  @override
  void didUpdateWidget(ModernContentFade oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enableTopFade && _topOpacity != 0.0) {
      _topOpacity = 0.0;
    }
    if (!widget.enableBottomFade && _bottomOpacity != 0.0) {
      _bottomOpacity = 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferenceNotifier = context.watch<PreferenceNotifier>();
    final isModern = preferenceNotifier.interfaceStyle == 'modern';
    final isScrollFadeEnabled = preferenceNotifier.enableScrollFade;

    if (!isModern || !isScrollFadeEnabled) {
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
          if (widget.enableTopFade && _topOpacity > 0)
            Positioned(
              left: 0,
              right: 0,
              top: widget.topOffset.clamp(0.0, double.infinity),
              height: widget.height,
              child: IgnorePointer(
                child: Opacity(
                  opacity: _topOpacity,
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
          if (widget.enableBottomFade && _bottomOpacity > 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: widget.bottomOffset.clamp(0.0, double.infinity),
              height: effectiveBottomHeight,
              child: IgnorePointer(
                child: Opacity(
                  opacity: _bottomOpacity,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
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
