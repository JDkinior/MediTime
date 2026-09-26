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
  /// (por ejemplo, en vistas con pestañas donde algunas tienen cabeceras estáticas).
  final ValueListenable<bool>? fadeEnabledNotifier;

  const ModernAppBar({
    super.key,
    required this.child,
    this.showFade = true,
    this.fadeEnabledNotifier,
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
    if (!_isFadeActive && _scrollProgress != 0.0) {
      setState(() {
        _scrollProgress = 0.0;
      });
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
    if (!_isFadeActive && _scrollProgress != 0.0) {
      setState(() {
        _scrollProgress = 0.0;
      });
    }
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
      final double progress = (extent / 20.0).clamp(0.0, 1.0);
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
      centerTitle: bar.centerTitle,
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

    // Si el degradado no está activo (ej. páginas con cabeceras estáticas como Calendario o Progreso),
    // mantenemos un fondo completamente plano y sólido.
    if (!_isFadeActive) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: totalAppBarHeight,
            child: Container(color: bgColor),
          ),
          Theme(
            data: Theme.of(context).copyWith(
              appBarTheme: Theme.of(context).appBarTheme.copyWith(
                    scrolledUnderElevation: 0.0,
                    surfaceTintColor: Colors.transparent,
                  ),
            ),
            child: widget.child,
          ),
        ],
      );
    }

    // En modo moderno con difuminado activo:
    // 1. Barra de estado sólida para proteger los iconos del sistema.
    // 2. La barra superior NO es sólida en su parte inferior: se disuelve en degradado continuo hacia transparente,
    //    permitiendo que el contenido scrolleado fluya detrás y se desvanezca suavemente (análogo a la barra inferior).
    const double fadeExtension = 40.0;
    final double gradientHeight = widget.preferredSize.height + fadeExtension;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 1. Fondo sólido solo para la barra de estado (y notch)
        if (topPadding > 0)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: topPadding,
            child: Container(color: bgColor),
          ),
        // 2. Degradado continuo que protege el título y se difumina suavemente hacia abajo
        Positioned(
          left: 0,
          right: 0,
          top: topPadding,
          height: gradientHeight,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    bgColor,
                    bgColor,
                    bgColor.withValues(alpha: 0.88),
                    bgColor.withValues(alpha: 0.52),
                    bgColor.withValues(alpha: 0.20),
                    bgColor.withValues(alpha: 0.0),
                  ],
                  stops: const [
                    0.0,
                    0.44,
                    0.54,
                    0.66,
                    0.80,
                    1.0,
                  ],
                ),
              ),
            ),
          ),
        ),
        // 3. AppBar transparente con sus iconos y títulos
        Theme(
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
      ],
    );
  }
}
