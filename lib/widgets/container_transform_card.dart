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
///    - Cero parpadeo al pulsar: la tarjeta original se reemplaza por un [_placeholderSize] exacto
///      únicamente una vez iniciado el primer frame de la transición, evitando re-layouts de listas y manteniendo el espacio exacto.
///    - Cero efecto entrecortado al entrar: [FadeTransition] opera con dimensiones fijas [SizedBox]
///      debajo de [FittedBox], eliminando la reasignación continua de texturas GPU en cada frame.
///    - Desvanecimiento lineal y homogéneo: la opacidad de entrada y salida se evalúa sobre la progresión
///      temporal lineal (como en el estándar de Google), eliminando el triple suavizado curvo que provocaba saltos visuales.
///    - Cero tirones al terminar de escalar: la pantalla abierta conserva su posición y clave [KeyedSubtree],
///      garantizando que no se destruya ni reinicie su State al alcanzar el 100%.
///    - Aislamiento de rasterizado [RepaintBoundary]: ambas pantallas se renderizan exactamente una vez
///      en la GPU y sus texturas se reutilizan frame a frame.
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

    final navigator = Navigator.of(context, rootNavigator: widget.useRootNavigator);
    final navRenderBox = navigator.context.findRenderObject() as RenderBox?;
    final originRect = navRenderBox != null
        ? MatrixUtils.transformRect(
            renderBox.getTransformTo(navRenderBox),
            Offset.zero & renderBox.size,
          )
        : renderBox.localToGlobal(Offset.zero) & renderBox.size;

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
      onTransitionStart: () {
        if (mounted && !_isRouteActive) {
          setState(() {
            _isRouteActive = true;
            _placeholderSize = originRect.size;
          });
        }
      },
      builder: (routeContext) {
        return widget.openBuilder(
          routeContext,
          () => Navigator.of(routeContext).pop(),
        );
      },
    );

    navigator.push(route).then((result) {
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
  final VoidCallback? onTransitionStart;

  @override
  final Duration transitionDuration;

  @override
  final Duration reverseTransitionDuration;

  final GlobalKey _openPageKey = GlobalKey();
  Animation<double>? _curvedAnimation;
  Animation<double>? _openOpacityAnimation;
  Animation<double>? _closedOpacityAnimation;
  Animation<Color?>? _colorAnimation;
  bool _hasReportedStart = false;

  // Secuencia de opacidad limpia sin curvas anidadas:
  // Closed card se desvanece de 1.0 a 0.0 de forma uniforme en el primer 20%.
  // Open card se revela de 0.0 a 1.0 en el 80% restante.
  // Al evaluarse sobre el progreso temporal lineal (parent), la entrada de la segunda página
  // se siente continua, sedosa y sin saltos visuales entrecortados.
  static final Animatable<double> _closedOpacityTween = TweenSequence<double>([
    TweenSequenceItem<double>(
      tween: Tween<double>(begin: 1.0, end: 0.0),
      weight: 20,
    ),
    TweenSequenceItem<double>(
      tween: ConstantTween<double>(0.0),
      weight: 80,
    ),
  ]);

  static final Animatable<double> _openOpacityTween = TweenSequence<double>([
    TweenSequenceItem<double>(
      tween: ConstantTween<double>(0.0),
      weight: 20,
    ),
    TweenSequenceItem<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      weight: 80,
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
    this.onTransitionStart,
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

    // CRÍTICO: Las animaciones de opacidad y color se evalúan sobre la progresión LINEAL (parent),
    // tal como en el OpenContainer oficial de Google/Flutter.
    // Esto evita el triple suavizado curvo (fastOutSlowIn + easeIn) que causaba que la segunda pantalla
    // entrara de forma entrecortada y a tirones.
    _openOpacityAnimation = _openOpacityTween.animate(parent);
    _closedOpacityAnimation = _closedOpacityTween.animate(parent);

    final middleColor = Color.lerp(closedColor, openColor, 0.5) ?? closedColor;
    _colorAnimation = TweenSequence<Color?>([
      TweenSequenceItem<Color?>(
        tween: ColorTween(begin: closedColor, end: middleColor),
        weight: 20,
      ),
      TweenSequenceItem<Color?>(
        tween: ColorTween(begin: middleColor, end: openColor),
        weight: 80,
      ),
    ]).animate(parent);
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return KeyedSubtree(
      key: _openPageKey,
      child: builder(context),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (!_hasReportedStart) {
      _hasReportedStart = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onTransitionStart?.call();
      });
    }

    _ensureAnimations();

    final Size screenSize = MediaQuery.sizeOf(context);
    final double curvedValue = _curvedAnimation?.value ?? curve.transform(animation.value);

    // Dimensiones y posición interpoladas matemáticamente O(1) con la curva de aceleración física
    final Rect fullScreenRect = Offset.zero & screenSize;
    final Rect currentRect = Rect.lerp(originRect, fullScreenRect, curvedValue)!;

    // Preservar la curvatura redondeada durante el 75%+ del vuelo con Curves.easeInCubic
    final double radiusProgress = Curves.easeInCubic.transform(curvedValue);
    final BorderRadius currentRadius = BorderRadius.lerp(borderRadius, BorderRadius.zero, radiusProgress)!;

    // Color de fondo suavemente interpolado
    final Color currentColor = _colorAnimation?.value ??
        Color.lerp(closedColor, openColor, animation.value)!;

    // Borde de contraste opcional (fading out al inicio)
    final BorderSide currentBorderSide = hasBorder && animation.value < 0.70
        ? BorderSide(
            color: borderColor.withValues(alpha: (1.0 - (animation.value / 0.70)).clamp(0.0, 1.0)),
            width: borderWidth,
          )
        : BorderSide.none;

    final bool isCompleted = animation.status == AnimationStatus.completed;

    return Align(
      alignment: Alignment.topLeft,
      child: Transform.translate(
        offset: isCompleted ? Offset.zero : Offset(currentRect.left, currentRect.top),
        child: SizedBox(
          width: isCompleted ? screenSize.width : currentRect.width,
          height: isCompleted ? screenSize.height : currentRect.height,
          child: Material(
            animationDuration: Duration.zero,
            color: currentColor,
            elevation: 0.0, // CERO cálculo de sombras Skia por frame
            shape: RoundedRectangleBorder(
              borderRadius: isCompleted ? BorderRadius.zero : currentRadius,
              side: isCompleted ? BorderSide.none : currentBorderSide,
            ),
            clipBehavior: Clip.none,
            child: ClipRRect(
              borderRadius: isCompleted ? BorderRadius.zero : currentRadius,
              child: Stack(
                fit: StackFit.passthrough,
                children: [
                  // Pantalla abierta:
                  // 1. FittedBox está AFUERA de SizedBox para aplicar escalado GPU sin alterar
                  //    las dimensiones de la capa de opacidad.
                  // 2. SizedBox tiene dimensiones constantes (screenSize) para que la textura
                  //    en GPU NUNCA se redimensione ni se reasigne frame a frame.
                  // 3. FadeTransition está DENTRO de SizedBox con tamaño fijo para evitar reasignar
                  //    el render target en cada cuadro, eliminando de raíz el efecto entrecortado.
                  FittedBox(
                    fit: BoxFit.fitWidth,
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: screenSize.width,
                      height: screenSize.height,
                      child: FadeTransition(
                        opacity: isCompleted ? const AlwaysStoppedAnimation(1.0) : _openOpacityAnimation!,
                        child: RepaintBoundary(
                          child: child,
                        ),
                      ),
                    ),
                  ),

                  // Tarjeta cerrada: solo visible durante el vuelo (primer 20%), se omite al completar
                  if (!isCompleted)
                    FittedBox(
                      fit: BoxFit.fitWidth,
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: originRect.width,
                        height: originRect.height,
                        child: FadeTransition(
                          opacity: _closedOpacityAnimation!,
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
