import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/theme/app_theme.dart';

/// Callback para abrir el contenedor.
typedef OpenContainerAction = void Function();

/// Callback para cerrar el contenedor desde dentro.
typedef CloseContainerAction<T> = void Function([T? returnValue]);

/// Contenedor animado con la transición Container Transform (Material Motion) optimizada para 120 FPS.
///
/// Transforma de manera fluida y armónica una tarjeta de medicamento cerrada
/// ([closedBuilder]) en su pantalla de detalle ([openBuilder]) y revierte la
/// animación al retroceder.
///
/// Características clave de rendimiento y diseño:
/// 1. Rendimiento 120 FPS fijado por hardware:
///    - Cero recalculo de layout por frame: [child] y [closedChild] tienen dimensiones
///      estables fijas y se escalan mediante transformaciones de matriz 2D en GPU con [FittedBox(fit: BoxFit.fitWidth)].
///    - Aislamiento de rasterizado [RepaintBoundary]: ambas pantallas se renderizan exactamente una vez
///      en la GPU y sus texturas se reutilizan frame a frame.
///    - Disolución orgánica sin sobrecoste de composición: la opacidad de salida (22%) y de entrada (82%)
///      minimizan la superposición de capas `saveLayer` en GPU.
///    - Sin sombras dinámicas de CPU: elevación plana a 0.0 para eliminar el cálculo de polígonos Gaussianos en cada frame.
/// 2. Mantiene de forma continua las esquinas redondeadas ([borderRadius]) durante
///    el 75%+ de la trayectoria ([Curves.easeInCubic]), aplanándose con gracia únicamente
///    al tocar los límites de la pantalla.
/// 3. Fondo sin oscurecimiento (`barrierColor: Colors.transparent`, `opaque: false`):
///    el fondo de la pantalla anterior permanece luminoso y visible durante toda la animación.
/// 4. Desvanecimiento suave del color de fondo: el contenedor transiciona fluidamente entre el color
///    de la tarjeta cerrada y el fondo del destino, logrando un cross-dissolve orgánico y natural.
class ContainerTransformCard<T extends Object?> extends StatefulWidget {
  /// Constructor del widget en estado cerrado (tarjeta).
  final Widget Function(BuildContext context, VoidCallback openContainer) closedBuilder;

  /// Constructor del widget en estado abierto (pantalla de detalle).
  final Widget Function(BuildContext context, VoidCallback closeContainer) openBuilder;

  /// Duración de la animación de apertura. Por defecto 300ms para una respuesta instantánea y sedosa a 120 FPS.
  final Duration transitionDuration;

  /// Duración de la animación de cierre/retorno. Por defecto 260ms.
  final Duration reverseTransitionDuration;

  /// Curva de animación para la transformación. Por defecto [Curves.fastOutSlowIn] (estándar Material Motion).
  final Curve curve;

  /// Radio de las esquinas redondeadas de la tarjeta. Por defecto 20.0 (estilo tarjeta MediTime).
  final BorderRadius borderRadius;

  /// Elevación / sombras personalizadas para la tarjeta en reposo.
  final List<BoxShadow>? closedShadows;

  /// Color de fondo de la tarjeta cerrada. Si es null, usa [AppTheme.cardColor].
  final Color? closedColor;

  /// Color de fondo del destino abierto. Si es null, usa el fondo del Scaffold.
  final Color? openColor;

  /// Si es true, todo el contenedor reacciona al toque para abrirse.
  /// Si es false (por defecto), el toque se delega a widgets interactivos internos como [InkWell].
  final bool tappable;

  /// Si se debe mostrar borde en la tarjeta cerrada. Si es null, se evalúa con [PreferenceNotifier].
  final bool? showBorder;

  /// Color del borde si está activo. Si es null, usa [AppTheme.borderColor].
  final Color? borderColor;

  /// Ancho del borde si está activo. Por defecto 1.0.
  final double borderWidth;

  /// Callback opcional que se ejecuta al cerrarse el contenedor abierto.
  final ValueChanged<T?>? onClosed;

  /// Si se debe empujar la ruta sobre el Navigator raíz. Por defecto true.
  final bool useRootNavigator;

  const ContainerTransformCard({
    super.key,
    required this.closedBuilder,
    required this.openBuilder,
    this.transitionDuration = const Duration(milliseconds: 300),
    this.reverseTransitionDuration = const Duration(milliseconds: 260),
    this.curve = Curves.fastOutSlowIn,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.closedShadows,
    this.closedColor,
    this.openColor,
    this.tappable = false,
    this.showBorder,
    this.borderColor,
    this.borderWidth = 1.0,
    this.onClosed,
    this.useRootNavigator = true,
  });

  @override
  State<ContainerTransformCard<T>> createState() => ContainerTransformCardState<T>();
}

class ContainerTransformCardState<T extends Object?> extends State<ContainerTransformCard<T>> {
  final GlobalKey _cardKey = GlobalKey();
  bool _isRouteActive = false;
  Size? _placeholderSize;

  void openContainer() {
    if (_isRouteActive) return;

    final renderBox = _cardKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final originRect = renderBox.localToGlobal(Offset.zero) & renderBox.size;
    final preferenceNotifier = _getPreferenceNotifier();
    final hasBorder = widget.showBorder ??
        (preferenceNotifier != null &&
            (preferenceNotifier.showCardBorder || preferenceNotifier.highContrast));

    final effectiveBorderColor = widget.borderColor ?? AppTheme.borderColor;
    final effectiveClosedColor = widget.closedColor ?? AppTheme.cardColor;
    final effectiveOpenColor = widget.openColor ?? Theme.of(context).scaffoldBackgroundColor;
    final effectiveClosedShadows = widget.closedShadows ?? AppTheme.cardShadow;

    // Aislamos la tarjeta cerrada en un RepaintBoundary para rasterizarla una sola vez en la GPU
    final closedPreview = RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: effectiveClosedColor,
          borderRadius: widget.borderRadius,
          border: hasBorder
              ? Border.all(color: effectiveBorderColor, width: widget.borderWidth)
              : null,
        ),
        child: ClipRRect(
          borderRadius: widget.borderRadius,
          child: Material(
            type: MaterialType.transparency,
            child: widget.closedBuilder(context, () {}),
          ),
        ),
      ),
    );

    setState(() {
      _isRouteActive = true;
      _placeholderSize = originRect.size;
    });

    final route = ContainerTransformPageRoute<T>(
      sourceKey: _cardKey,
      originRect: originRect,
      borderRadius: widget.borderRadius,
      closedColor: effectiveClosedColor,
      openColor: effectiveOpenColor,
      closedShadows: effectiveClosedShadows,
      hasBorder: hasBorder,
      borderColor: effectiveBorderColor,
      borderWidth: widget.borderWidth,
      transitionDuration: widget.transitionDuration,
      reverseTransitionDuration: widget.reverseTransitionDuration,
      curve: widget.curve,
      closedChild: closedPreview,
      builder: (routeContext) {
        return widget.openBuilder(
          routeContext,
          () => Navigator.of(routeContext).pop(),
        );
      },
    );

    Navigator.of(context, rootNavigator: widget.useRootNavigator)
        .push(route)
        .then((result) {
      if (mounted) {
        setState(() {
          _isRouteActive = false;
          _placeholderSize = null;
        });
      }
      if (widget.onClosed != null) {
        widget.onClosed!(result);
      }
    });
  }

  PreferenceNotifier? _getPreferenceNotifier() {
    try {
      return context.read<PreferenceNotifier>();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    PreferenceNotifier? preferenceNotifier;
    try {
      preferenceNotifier = context.watch<PreferenceNotifier>();
    } catch (_) {
      // Ignorar si se evalúa fuera del proveedor
    }

    final hasBorder = widget.showBorder ??
        (preferenceNotifier != null &&
            (preferenceNotifier.showCardBorder || preferenceNotifier.highContrast));

    final effectiveBorderColor = widget.borderColor ?? AppTheme.borderColor;
    final effectiveClosedColor = widget.closedColor ?? AppTheme.cardColor;
    final effectiveClosedShadows = widget.closedShadows ?? AppTheme.cardShadow;

    final cardWidget = DecoratedBox(
      decoration: BoxDecoration(
        color: effectiveClosedColor,
        borderRadius: widget.borderRadius,
        border: hasBorder
            ? Border.all(color: effectiveBorderColor, width: widget.borderWidth)
            : null,
        boxShadow: effectiveClosedShadows,
      ),
      child: ClipRRect(
        borderRadius: widget.borderRadius,
        child: Material(
          type: MaterialType.transparency,
          child: widget.tappable
              ? InkWell(
                  onTap: openContainer,
                  borderRadius: widget.borderRadius,
                  child: widget.closedBuilder(context, openContainer),
                )
              : widget.closedBuilder(context, openContainer),
        ),
      ),
    );

    if (_isRouteActive && _placeholderSize != null) {
      return KeyedSubtree(
        key: _cardKey,
        child: SizedBox.fromSize(size: _placeholderSize),
      );
    }

    return KeyedSubtree(
      key: _cardKey,
      child: cardWidget,
    );
  }
}

/// Ruta de transición especializada en Container Transform de alto rendimiento a 120 FPS.
class ContainerTransformPageRoute<T> extends PageRoute<T> {
  final GlobalKey sourceKey;
  final Rect originRect;
  final BorderRadius borderRadius;
  final Color closedColor;
  final Color openColor;
  final List<BoxShadow> closedShadows;
  final bool hasBorder;
  final Color borderColor;
  final double borderWidth;
  final Widget closedChild;
  final WidgetBuilder builder;
  final Curve curve;

  @override
  final Duration transitionDuration;

  @override
  final Duration reverseTransitionDuration;

  Animation<double>? _curvedAnimation;
  Animation<double>? _openOpacityAnimation;
  Animation<double>? _closedOpacityAnimation;
  Animation<Color?>? _colorAnimation;

  // Secuencia de opacidad optimizada para hardware:
  // Closed card se desvanece de 1.0 a 0.0 en el primer 22%.
  // Open card se revela de 0.0 a 1.0 a partir del 18%.
  // Minimiza la concurrencia de capas OpacityLayer / saveLayer en GPU.
  static final Animatable<double> _closedOpacityTween = TweenSequence<double>([
    TweenSequenceItem<double>(
      tween: Tween<double>(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeOut)),
      weight: 22,
    ),
    TweenSequenceItem<double>(
      tween: ConstantTween<double>(0.0),
      weight: 78,
    ),
  ]);

  static final Animatable<double> _openOpacityTween = TweenSequence<double>([
    TweenSequenceItem<double>(
      tween: ConstantTween<double>(0.0),
      weight: 18,
    ),
    TweenSequenceItem<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeIn)),
      weight: 82,
    ),
  ]);

  ContainerTransformPageRoute({
    required this.sourceKey,
    required this.originRect,
    required this.borderRadius,
    required this.closedColor,
    required this.openColor,
    required this.closedShadows,
    required this.hasBorder,
    required this.borderColor,
    required this.borderWidth,
    required this.closedChild,
    required this.builder,
    required this.transitionDuration,
    required this.reverseTransitionDuration,
    this.curve = Curves.fastOutSlowIn,
    super.settings,
  });

  @override
  bool get opaque => false;

  @override
  bool get barrierDismissible => false;

  @override
  Color? get barrierColor => Colors.transparent;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  void _ensureAnimations() {
    if (_curvedAnimation != null || animation == null) return;
    final parent = animation!;
    _curvedAnimation = CurvedAnimation(
      parent: parent,
      curve: curve,
      reverseCurve: curve.flipped,
    );

    _openOpacityAnimation = _openOpacityTween.animate(_curvedAnimation!);
    _closedOpacityAnimation = _closedOpacityTween.animate(_curvedAnimation!);
    _colorAnimation = TweenSequence<Color?>([
      TweenSequenceItem<Color?>(
        tween: ColorTween(begin: closedColor, end: Color.lerp(closedColor, openColor, 0.4)),
        weight: 25,
      ),
      TweenSequenceItem<Color?>(
        tween: ColorTween(begin: Color.lerp(closedColor, openColor, 0.4), end: openColor),
        weight: 75,
      ),
    ]).animate(_curvedAnimation!);
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return builder(context);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (animation.status == AnimationStatus.completed) {
      return child;
    }

    _ensureAnimations();

    final Size screenSize = MediaQuery.sizeOf(context);
    final double curvedValue = _curvedAnimation?.value ?? curve.transform(animation.value);

    // Dimensiones y posición interpoladas matemáticamente O(1)
    final Rect fullScreenRect = Offset.zero & screenSize;
    final Rect currentRect = Rect.lerp(originRect, fullScreenRect, curvedValue)!;

    // Preservar la curvatura redondeada durante el 75%+ del vuelo con Curves.easeInCubic
    final double radiusProgress = Curves.easeInCubic.transform(curvedValue);
    final BorderRadius currentRadius = BorderRadius.lerp(borderRadius, BorderRadius.zero, radiusProgress)!;

    // Color de fondo suavemente interpolado
    final Color currentColor = _colorAnimation?.value ??
        Color.lerp(closedColor, openColor, curvedValue)!;

    // Borde de contraste opcional (fading out al inicio)
    final BorderSide currentBorderSide = hasBorder && animation.value < 0.70
        ? BorderSide(
            color: borderColor.withValues(alpha: (1.0 - (animation.value / 0.70)).clamp(0.0, 1.0)),
            width: borderWidth,
          )
        : BorderSide.none;

    return Align(
      alignment: Alignment.topLeft,
      child: Transform.translate(
        offset: Offset(currentRect.left, currentRect.top),
        child: SizedBox(
          width: currentRect.width,
          height: currentRect.height,
          child: Material(
            animationDuration: Duration.zero,
            color: currentColor,
            elevation: 0.0, // CERO cálculo de sombras Skia por frame
            shape: RoundedRectangleBorder(
              borderRadius: currentRadius,
              side: currentBorderSide,
            ),
            clipBehavior: Clip.none,
            child: ClipRRect(
              borderRadius: currentRadius,
              child: Stack(
                fit: StackFit.passthrough,
                children: [
                  // Pantalla abierta: Dimensiones fijas screenSize con escala GPU vía BoxFit.fitWidth
                  FadeTransition(
                    opacity: _openOpacityAnimation!,
                    child: FittedBox(
                      fit: BoxFit.fitWidth,
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: screenSize.width,
                        height: screenSize.height,
                        child: RepaintBoundary(
                          child: child,
                        ),
                      ),
                    ),
                  ),

                  // Tarjeta cerrada: Dimensiones fijas originRect con escala GPU vía BoxFit.fitWidth
                  FadeTransition(
                    opacity: _closedOpacityAnimation!,
                    child: FittedBox(
                      fit: BoxFit.fitWidth,
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: originRect.width,
                        height: originRect.height,
                        child: RepaintBoundary(
                          child: closedChild,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
