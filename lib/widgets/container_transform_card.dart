import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meditime/notifiers/preference_notifier.dart';
import 'package:meditime/theme/app_theme.dart';

/// Callback para abrir el contenedor.
typedef OpenContainerAction = void Function();

/// Callback para cerrar el contenedor desde dentro.
typedef CloseContainerAction<T> = void Function([T? returnValue]);

/// Contenedor animado con la transición Container Transform (Material Motion).
///
/// Transforma de manera fluida y armónica una tarjeta de medicamento cerrada
/// ([closedBuilder]) en su pantalla de detalle ([openBuilder]) y revierte la
/// animación al retroceder.
///
/// Características clave de diseño:
/// 1. Mantiene de forma continua las esquinas redondeadas ([borderRadius]) durante
///    toda la trayectoria, evitando que se transforme en un rectángulo brusco o rígido.
/// 2. Fondo sin oscurecimiento (`barrierColor: Colors.transparent`): el fondo de la
///    pantalla anterior permanece luminoso y visible durante la animación.
/// 3. Alineación sin distorsiones: la tarjeta y la pantalla de detalle se despliegan
///    en su proporción natural sin efectos de estiramiento artificial.
class ContainerTransformCard<T extends Object?> extends StatefulWidget {
  /// Constructor del widget en estado cerrado (tarjeta).
  final Widget Function(BuildContext context, VoidCallback openContainer) closedBuilder;

  /// Constructor del widget en estado abierto (pantalla de detalle).
  final Widget Function(BuildContext context, VoidCallback closeContainer) openBuilder;

  /// Duración de la animación de apertura. Por defecto 320ms para máxima fluidez.
  final Duration transitionDuration;

  /// Duración de la animación de cierre/retorno. Por defecto 280ms.
  final Duration reverseTransitionDuration;

  /// Curva de animación para la transformación. Por defecto [Curves.fastOutSlowIn].
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
    this.transitionDuration = const Duration(milliseconds: 320),
    this.reverseTransitionDuration = const Duration(milliseconds: 280),
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

    // Aislamos la tarjeta cerrada en un RepaintBoundary para rasterizarla una sola vez
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

/// Ruta de transición especializada en Container Transform de alto rendimiento.
///
/// Optimizaciones clave para 60/120 FPS en dispositivos móviles:
/// 1. Fondo completamente transparente sin oscurecimiento (`barrierColor: Colors.transparent`, `opaque: false`).
/// 2. Geometría de esquinas redondeadas preservada casi todo el vuelo ([Curves.easeInCubic]).
/// 3. Aislamiento de capas con [RepaintBoundary] para pantalla completa y tarjeta cerrada:
///    elimina repintados innecesarios por frame (GPU texture caching).
/// 4. Cero recorridos de árbol por frame (`findRenderObject` y `localToGlobal` eliminados en `buildTransitions`).
/// 5. Elevación y sombras aceleradas por hardware vía [Material] en vez de rasterizado Gaussian de CPU.
/// 6. Pre-calentamiento de vista con [Offstage] para evitar tirones (jank) al inflar la pantalla a mitad del trayecto.
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

  static final Animatable<double> _closedOpacityTween = TweenSequence<double>([
    TweenSequenceItem<double>(
      tween: Tween<double>(begin: 1.0, end: 0.0),
      weight: 25,
    ),
    TweenSequenceItem<double>(
      tween: ConstantTween<double>(0.0),
      weight: 75,
    ),
  ]);

  static final Animatable<double> _openOpacityTween = TweenSequence<double>([
    TweenSequenceItem<double>(
      tween: ConstantTween<double>(0.0),
      weight: 15,
    ),
    TweenSequenceItem<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      weight: 25,
    ),
    TweenSequenceItem<double>(
      tween: ConstantTween<double>(1.0),
      weight: 60,
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

    final Size screenSize = MediaQuery.sizeOf(context);
    final double curvedValue = curve.transform(animation.value);

    // Dimensiones y posición interpoladas O(1) matemáticamente sin recorrer el árbol
    final Rect fullScreenRect = Offset.zero & screenSize;
    final Rect currentRect = Rect.lerp(originRect, fullScreenRect, curvedValue)!;

    // Preservar la curvatura redondeada durante casi toda la expansión:
    // Curves.easeInCubic asegura que la tarjeta se mantenga redondeada durante más del 80%
    // del recorrido, suavizándose a 0 únicamente en los extremos exactos de la pantalla.
    final double radiusProgress = Curves.easeInCubic.transform(curvedValue);
    final BorderRadius currentRadius = BorderRadius.lerp(borderRadius, BorderRadius.zero, radiusProgress)!;

    // Color interpolado suavemente
    final Color currentColor = Color.lerp(closedColor, openColor, curvedValue)!;

    // Elevación física acelerada por hardware (shaders nativos de GPU)
    final double currentElevation = curvedValue > 0.98
        ? 0.0
        : (5.0 * math.sin(curvedValue * math.pi)).clamp(0.0, 5.0);

    // Borde de contraste si aplica
    final BorderSide currentBorderSide = hasBorder && curvedValue < 0.75
        ? BorderSide(
            color: borderColor.withValues(alpha: (1.0 - (curvedValue / 0.75)).clamp(0.0, 1.0)),
            width: borderWidth,
          )
        : BorderSide.none;

    // Opacidades cruzadas desde secuencia estática
    final double closedOpacity = _closedOpacityTween.transform(curvedValue);
    final double openOpacity = _openOpacityTween.transform(curvedValue);

    return Align(
      alignment: Alignment.topLeft,
      child: Transform.translate(
        offset: Offset(currentRect.left, currentRect.top),
        child: SizedBox(
          width: currentRect.width,
          height: currentRect.height,
          child: Material(
            color: currentColor,
            elevation: currentElevation,
            shape: RoundedRectangleBorder(
              borderRadius: currentRadius,
              side: currentBorderSide,
            ),
            child: ClipRRect(
              borderRadius: currentRadius,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Pantalla abierta: pre-renderizada desde el frame 0 en RepaintBoundary
                  // Evita frame-drops al no tener que inflar widgets pesados a mitad del vuelo
                  Offstage(
                    offstage: openOpacity <= 0.0,
                    child: FadeTransition(
                      opacity: AlwaysStoppedAnimation<double>(openOpacity),
                      child: OverflowBox(
                        alignment: Alignment.topLeft,
                        minWidth: screenSize.width,
                        maxWidth: screenSize.width,
                        minHeight: screenSize.height,
                        maxHeight: screenSize.height,
                        child: RepaintBoundary(
                          child: child,
                        ),
                      ),
                    ),
                  ),

                  // Tarjeta cerrada: desvaneciéndose en su posición nativa sin repintar
                  Offstage(
                    offstage: closedOpacity <= 0.0,
                    child: FadeTransition(
                      opacity: AlwaysStoppedAnimation<double>(closedOpacity),
                      child: OverflowBox(
                        alignment: Alignment.topLeft,
                        minWidth: originRect.width,
                        maxWidth: originRect.width,
                        minHeight: originRect.height,
                        maxHeight: originRect.height,
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
