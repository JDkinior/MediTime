import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meditime/notifiers/preference_notifier.dart';

/// Wrapper para [PreferredSizeWidget] (como [AppBar]) que, en modo moderno:
/// 1. Evita que la barra superior cambie de color al deslizar/scrollear.
/// 2. Agrega un difuminado continuo en degradado hacia transparente
///    que aparece suavemente al deslizar.
/// En modo clásico, preserva el comportamiento estándar original de Material 3.
class ModernAppBar extends StatefulWidget implements PreferredSizeWidget {
  final PreferredSizeWidget child;

  /// Controla si se debe mostrar el degradado al hacer scroll.
  /// Si es false, la barra mantendrá su color plano sin degradado.
  final bool showFade;

  /// Notificador opcional para habilitar/deshabilitar el degradado reactivamente
  /// (por ejemplo, en vistas con pestañas donde algunas tienen cabeceras estáticas o banners).
  final ValueListenable<bool>? fadeEnabledNotifier;

  /// Extensión opcional por debajo de la AppBar (por defecto 0.0 para no sobreponerse a elementos inferiores).
  final double fadeExtension;

  /// Controla si la barra debe renderizarse con efecto de cristal esmerilado translúcido.
  final bool useGlass;

  /// Si es true, al hacer scroll el título desaparece suavemente (opacity -> 0)
  /// y los botones (leading y actions) se encapsulan en cápsulas flotantes
  /// con sombra y fondo de cristal / superficie, siguiendo la estética Samsung One UI.
  final bool encapsulateOnScroll;

  /// Conserva el espacio de las cápsulas aunque el efecto esté desactivado.
  final bool reserveControlSpace;

  /// Permite sincronizar la barra con un scroll controlado por la página.
  final ValueListenable<double>? scrollProgress;

  /// Desvanece el título sin desplazarlo al hacer scroll.
  final bool fadeTitleInPlace;

  const ModernAppBar({
    super.key,
    required this.child,
    this.showFade = true,
    this.fadeEnabledNotifier,
    this.fadeExtension = 0.0,
    this.useGlass = false,
    this.encapsulateOnScroll = false,
    this.reserveControlSpace = false,
    this.scrollProgress,
    this.fadeTitleInPlace = false,
  });

  static Color controlSurface({required bool isDark, double progress = 1}) {
    return isDark
        ? const Color(0xFF22242A).withValues(alpha: 0.92 * progress)
        : Colors.white.withValues(alpha: 0.94 * progress);
  }

  static BoxShadow controlShadow({required bool isDark, required double progress}) {
    return BoxShadow(
      color: Colors.black.withValues(alpha: (isDark ? 0.65 : 0.12) * progress),
      blurRadius: isDark ? 16 : 14,
      spreadRadius: 1,
      offset: const Offset(0, 4),
    );
  }

  @override
  Size get preferredSize => child.preferredSize;

  @override
  State<ModernAppBar> createState() => _ModernAppBarState();
}

class _ModernAppBarState extends State<ModernAppBar> {
  ScrollNotificationObserverState? _scrollNotificationObserver;
  final ValueNotifier<double> _scrollProgress = ValueNotifier<double>(0.0);

  ValueListenable<double> get _effectiveScrollProgress =>
      widget.scrollProgress ?? _scrollProgress;

  bool get _isFadeActive =>
      widget.showFade &&
      (widget.fadeEnabledNotifier == null || widget.fadeEnabledNotifier!.value);

  @override
  void initState() {
    super.initState();
    widget.fadeEnabledNotifier?.addListener(_onFadeNotifierChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scrollNotificationObserver?.removeListener(_handleScrollNotification);
    _scrollNotificationObserver = ScrollNotificationObserver.maybeOf(context);
    _scrollNotificationObserver?.addListener(_handleScrollNotification);
  }

  @override
  void didUpdateWidget(ModernAppBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fadeEnabledNotifier != widget.fadeEnabledNotifier) {
      oldWidget.fadeEnabledNotifier?.removeListener(_onFadeNotifierChanged);
      widget.fadeEnabledNotifier?.addListener(_onFadeNotifierChanged);
    }
    if (oldWidget.showFade != widget.showFade ||
        oldWidget.fadeEnabledNotifier != widget.fadeEnabledNotifier) {
      if (!_isFadeActive && _scrollProgress.value != 0.0) {
        _scrollProgress.value = 0.0;
      }
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.fadeEnabledNotifier?.removeListener(_onFadeNotifierChanged);
    _scrollNotificationObserver?.removeListener(_handleScrollNotification);
    _scrollNotificationObserver = null;
    _scrollProgress.dispose();
    super.dispose();
  }

  void _onFadeNotifierChanged() {
    if (!_isFadeActive && _scrollProgress.value != 0.0) {
      _scrollProgress.value = 0.0;
    }
    setState(() {});
  }

  void _handleScrollNotification(ScrollNotification notification) {
    if (widget.scrollProgress != null) return;
    if (!_isFadeActive) {
      if (_scrollProgress.value != 0.0) {
        _scrollProgress.value = 0.0;
      }
      return;
    }

    final metrics = notification.metrics;
    if (metrics.axis == Axis.vertical) {
      final double extent = metrics.extentBefore;
      final double progress = (extent / 36.0).clamp(0.0, 1.0);
      if ((progress - _scrollProgress.value).abs() > 0.01) {
        _scrollProgress.value = progress;
      }
    }
  }

  PreferredSizeWidget _makeTransparentAppBar(BuildContext context, PreferredSizeWidget child) {
    if (child is! AppBar) return child;
    final bar = child;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget? leading = bar.leading;
    List<Widget>? actions = bar.actions;
    Widget? title = bar.title;

    if (widget.encapsulateOnScroll) {
      if (title != null) {
        title = ValueListenableBuilder<double>(
          valueListenable: _effectiveScrollProgress,
          child: title,
          builder: (_, progress, child) {
            final titleOpacity = (1.0 - progress).clamp(0.0, 1.0);
            return IgnorePointer(
              ignoring: progress > 0.7,
              child: Opacity(
                opacity: titleOpacity,
                child: widget.fadeTitleInPlace
                    ? child
                    : Transform.translate(
                        offset: Offset(0, -6.0 * progress),
                        child: child,
                      ),
              ),
            );
          },
        );
      }
    }

    if (widget.encapsulateOnScroll || widget.reserveControlSpace) {
      final controlProgress = widget.encapsulateOnScroll
          ? _effectiveScrollProgress
          : const AlwaysStoppedAnimation<double>(0);

      // 2. Botón leading encapsulado en cápsula circular One UI (menú hamburguesa o retroceso)
      if (leading != null) {
        leading = Center(
          child: Padding(
            padding: const EdgeInsets.only(left: 6.0),
            child: ValueListenableBuilder<double>(
              valueListenable: controlProgress,
              child: Center(child: leading),
              builder: (_, progress, child) {
                return Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: progress > 0.05
                        ? ModernAppBar.controlSurface(isDark: isDark, progress: progress)
                        : Colors.transparent,
                    border: progress > 0.05
                        ? Border.all(
                            color: (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: (isDark ? 0.12 : 0.08) * progress),
                            width: 1.0,
                          )
                        : Border.all(color: Colors.transparent),
                    boxShadow: progress > 0.05
                        ? [ModernAppBar.controlShadow(isDark: isDark, progress: progress)]
                        : null,
                  ),
                  child: child,
                );
              },
            ),
          ),
        );
      }

      // 3. Botones de acciones encapsulados en cápsula circular One UI (como Midi)
      if (actions != null && actions.isNotEmpty) {
        actions = actions.map((action) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ValueListenableBuilder<double>(
                valueListenable: controlProgress,
                child: Center(child: action),
                builder: (_, progress, child) {
                  return Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: progress > 0.05
                          ? ModernAppBar.controlSurface(isDark: isDark, progress: progress)
                          : Colors.transparent,
                      border: progress > 0.05
                          ? Border.all(
                              color: (isDark ? Colors.white : Colors.black)
                                  .withValues(alpha: (isDark ? 0.12 : 0.08) * progress),
                              width: 1.0,
                            )
                          : Border.all(color: Colors.transparent),
                      boxShadow: progress > 0.05
                        ? [ModernAppBar.controlShadow(isDark: isDark, progress: progress)]
                        : null,
                    ),
                    child: child,
                  );
                },
              ),
            ),
          );
        }).toList();
      }
    }

    return AppBar(
      key: bar.key,
      leading: leading,
      automaticallyImplyLeading: bar.automaticallyImplyLeading,
      title: title,
      actions: actions,
      flexibleSpace: bar.flexibleSpace,
      bottom: bar.bottom,
      elevation: 0.0,
      scrolledUnderElevation: 0.0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: bar.shape,
      backgroundColor: Colors.transparent,
      foregroundColor: bar.foregroundColor,
      iconTheme: bar.iconTheme,
      actionsIconTheme: bar.actionsIconTheme,
      primary: bar.primary,
      centerTitle: bar.centerTitle ?? true,
      excludeHeaderSemantics: bar.excludeHeaderSemantics,
      titleSpacing: bar.titleSpacing,
      toolbarOpacity: bar.toolbarOpacity,
      bottomOpacity: bar.bottomOpacity,
      toolbarHeight: bar.toolbarHeight,
      leadingWidth: widget.encapsulateOnScroll || widget.reserveControlSpace
          ? 62.0
          : bar.leadingWidth,
      toolbarTextStyle: bar.toolbarTextStyle,
      titleTextStyle: bar.titleTextStyle,
      systemOverlayStyle: bar.systemOverlayStyle,
      forceMaterialTransparency: true,
      clipBehavior: Clip.none,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pref = context.select<
        PreferenceNotifier,
        ({bool isModern, bool enableScrollFade, bool highContrast})>(
      (p) => (
        isModern: p.interfaceStyle == 'modern',
        enableScrollFade: p.enableScrollFade,
        highContrast: p.highContrast,
      ),
    );
    final isModern = pref.isModern;

    if (!isModern) {
      return widget.child;
    }

    final isPrimary = widget.child is AppBar ? (widget.child as AppBar).primary : true;
    final topPadding = isPrimary ? MediaQuery.paddingOf(context).top : 0.0;
    final totalAppBarHeight = widget.preferredSize.height + topPadding;

    final Color bgColor = (widget.child is AppBar &&
            (widget.child as AppBar).backgroundColor != null &&
            (widget.child as AppBar).backgroundColor != Colors.transparent)
        ? (widget.child as AppBar).backgroundColor!
        : Theme.of(context).scaffoldBackgroundColor;

    final isScrollFadeEnabled = pref.enableScrollFade;
    final highContrast = pref.highContrast;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canShowGradient = !widget.encapsulateOnScroll &&
        isScrollFadeEnabled &&
        _isFadeActive &&
        widget.fadeExtension > 0.0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 1. Fondo para barra de estado y toolbar (cristal esmerilado si useGlass está activo, o sólido)
        Positioned(
          key: const ValueKey('modern_app_bar_bg'),
          left: 0,
          right: 0,
          top: 0,
          height: totalAppBarHeight,
          child: ValueListenableBuilder<double>(
            valueListenable: _effectiveScrollProgress,
            builder: (context, progress, _) {
              if (widget.useGlass && !highContrast) {
                if (widget.encapsulateOnScroll && progress >= 0.99) {
                  return const SizedBox.shrink();
                }
                final alphaScale = widget.encapsulateOnScroll
                    ? (1.0 - progress).clamp(0.0, 1.0)
                    : 1.0;
                return RepaintBoundary(
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.78 * alphaScale)
                              : Colors.white.withValues(alpha: 0.82 * alphaScale),
                          border: Border(
                            bottom: BorderSide(
                              color: (isDark ? Colors.white : Colors.black).withValues(
                                alpha: (isDark ? 0.08 : 0.06) * alphaScale,
                              ),
                              width: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }
              return Container(
                color: widget.encapsulateOnScroll
                    ? bgColor.withValues(alpha: (1.0 - progress).clamp(0.0, 1.0))
                    : bgColor,
              );
            },
          ),
        ),
        // 2. AppBar transparente con sus iconos y títulos (Key y orden estables para preservar el render tree de Showcase)
        Theme(
          key: const ValueKey('modern_app_bar_theme'),
          data: Theme.of(context).copyWith(
            appBarTheme: Theme.of(context).appBarTheme.copyWith(
                  backgroundColor: Colors.transparent,
                  scrolledUnderElevation: 0.0,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0.0,
                ),
          ),
          child: _makeTransparentAppBar(context, widget.child),
        ),
        // 3. Degradado continuo suave proyectado exclusivamente por DEBAJO de la toolbar
        if (canShowGradient)
          ValueListenableBuilder<double>(
            valueListenable: _effectiveScrollProgress,
            builder: (context, progress, _) {
              if (progress <= 0.0) return const SizedBox.shrink();
              final currentExtension = widget.fadeExtension * progress;
              return Positioned(
                key: const ValueKey('modern_app_bar_gradient'),
                left: 0,
                right: 0,
                top: totalAppBarHeight,
                height: currentExtension,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          bgColor.withValues(alpha: progress),
                          bgColor.withValues(alpha: 0.70 * progress),
                          bgColor.withValues(alpha: 0.35 * progress),
                          bgColor.withValues(alpha: 0.10 * progress),
                          bgColor.withValues(alpha: 0.0),
                        ],
                        stops: const [
                          0.0,
                          0.25,
                          0.55,
                          0.80,
                          1.0,
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
