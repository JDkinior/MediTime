import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/theme/app_theme.dart';

/// Contenedor estilizado con efecto frosted glass (cristal esmerilado translúcido con blur)
/// para hojas modales inferiores (Bottom Sheets).
class FrostedGlassBottomSheet extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;

  const FrostedGlassBottomSheet({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 28.0,
  });

  @override
  Widget build(BuildContext context) {
    PreferenceNotifier? pref;
    try {
      pref = context.watch<PreferenceNotifier>();
    } catch (_) {}
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isModern = pref?.interfaceStyle == 'modern' || pref == null;
    final highContrast = pref?.highContrast ?? false;
    final useGlass = isModern && !highContrast;

    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(borderRadius)),
      child: BackdropFilter(
        filter: useGlass
            ? ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0)
            : ImageFilter.blur(sigmaX: 0.0, sigmaY: 0.0),
        child: Container(
          decoration: BoxDecoration(
            color: useGlass
                ? (isDark
                    ? Theme.of(context).cardColor.withValues(alpha: 0.78)
                    : Colors.white.withValues(alpha: 0.85))
                : Theme.of(context).cardColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(borderRadius)),
            border: Border.all(
              color: useGlass
                  ? (isDark ? Colors.white : Colors.black).withValues(alpha: isDark ? 0.12 : 0.08)
                  : ((pref?.showCardBorder ?? false) || highContrast ? AppTheme.borderColor : Colors.transparent),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.10),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
