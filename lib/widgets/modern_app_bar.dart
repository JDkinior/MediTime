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

  const ModernAppBar({
    super.key,
    required this.child,
    this.showFade = true,
    this.fadeEnabledNotifier,
    this.fadeExtension = 0.0,
  });

  @override
  Size get preferredSize => child.preferredSize;

  @override
  State<ModernAppBar> createState() => _ModernAppBarState();
}

class _ModernAppBarState extends State<ModernAppBar> {
  ScrollNotificationObserverState? _scrollNotificationObserver;
  double _scrollProgress = 0.0;

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
      if (!_isFadeActive && _scrollProgress != 0.0) {
        _scrollProgress = 0.0;
      }
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.fadeEnabledNotifier?.removeListener(_onFadeNotifierChanged);
    _scrollNotificationObserver?.removeListener(_handleScrollNotification);
    _scrollNotificationObserver = null;
    super.dispose();
  }

  void _onFadeNotifierChanged() {
    setState(() {
      if (!_isFadeActive) {
        _scrollProgress = 0.0;
      }
    });
  }

  void _handleScrollNotification(ScrollNotification notification) {
    if (!_isFadeActive) {
      if (_scrollProgress != 0.0) {
        setState(() {
          _scrollProgress = 0.0;
        });
      }
      return;
    }

    final metrics = notification.metrics;
    if (metrics.axis == Axis.vertical) {
      final double extent = metrics.extentBefore;
      final double progress = (extent / 24.0).clamp(0.0, 1.0);
      if ((progress - _scrollProgress).abs() > 0.01) {
        setState(() {
          _scrollProgress = progress;
        });
      }
    }
  }

  PreferredSizeWidget _makeTransparentAppBar(PreferredSizeWidget child) {
    if (child is! AppBar) return child;
    final bar = child;
    return AppBar(
      key: bar.key,
      leading: bar.leading,
      automaticallyImplyLeading: bar.automaticallyImplyLeading,
      title: bar.title,
      actions: bar.actions,
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
      leadingWidth: bar.leadingWidth,
      toolbarTextStyle: bar.toolbarTextStyle,
      titleTextStyle: bar.titleTextStyle,
      systemOverlayStyle: bar.systemOverlayStyle,
      forceMaterialTransparency: true,
      clipBehavior: bar.clipBehavior,
    );
  }

  @override
  Widget build(BuildContext context) {
    final preferenceNotifier = context.watch<PreferenceNotifier>();
    final isModern = preferenceNotifier.interfaceStyle == 'modern';

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

    final isScrollFadeEnabled = preferenceNotifier.enableScrollFade;
    final currentExtension = (isScrollFadeEnabled && _isFadeActive && _scrollProgress > 0.0)
        ? (widget.fadeExtension * _scrollProgress)
        : 0.0;
    final showGradient = isScrollFadeEnabled && _isFadeActive && currentExtension > 0.0;

    return Stack(
      clipBehavior: showGradient ? Clip.none : Clip.hardEdge,
      children: [
        // 1. Fondo sólido completo para barra de estado y toolbar
        Positioned(
          key: const ValueKey('modern_app_bar_bg'),
          left: 0,
          right: 0,
          top: 0,
          height: totalAppBarHeight,
          child: Container(color: bgColor),
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
          child: _makeTransparentAppBar(widget.child),
        ),
        // 3. Degradado continuo suave proyectado exclusivamente por DEBAJO de la toolbar
        if (showGradient)
          Positioned(
            key: const ValueKey('modern_app_bar_gradient'),
            left: 0,
            right: 0,
            top: totalAppBarHeight,
            height: currentExtension,
            child: IgnorePointer(
              child: Opacity(
                opacity: _scrollProgress,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        bgColor,
                        bgColor.withValues(alpha: 0.70),
                        bgColor.withValues(alpha: 0.35),
                        bgColor.withValues(alpha: 0.10),
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
            ),
          ),
      ],
    );
  }
}
