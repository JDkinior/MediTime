// lib/widgets/medication/receta_summary_card.dart
import 'dart:async';
import 'package:flutter/material.dart';

import 'package:meditime/theme/app_theme.dart';
import 'package:meditime/l10n/generated/app_localizations.dart';
import 'package:meditime/widgets/medication/wave_painter.dart';
import 'package:meditime/screens/subscription/subscription_page.dart';

class RecetaSummaryCard extends StatefulWidget {
  final DateTime selectedDate;
  final int pendientesHoy;
  final int tomadasHoy;
  final double adherenciaHoy;
  final bool isPremium;
  final List<Map<String, String>> effectiveTips;
  final AppLocalizations? l10n;

  const RecetaSummaryCard({
    super.key,
    required this.selectedDate,
    required this.pendientesHoy,
    required this.tomadasHoy,
    required this.adherenciaHoy,
    required this.isPremium,
    required this.effectiveTips,
    required this.l10n,
  });

  @override
  State<RecetaSummaryCard> createState() => RecetaSummaryCardState();
}

class RecetaSummaryCardState extends State<RecetaSummaryCard>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final AnimationController _waveController;
  late final PageController _summaryPageController;
  int _currentSummaryIndex = 0;
  Timer? _autoSlideTimer;
  Timer? _dotsFadeTimer;
  bool _showDotsIndicator = true;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _summaryPageController = PageController();

    _dotsFadeTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) {
        setState(() {
          _showDotsIndicator = false;
        });
      }
    });

    if (widget.isPremium) {
      _startAutoSlideTimer();
    }
  }

  @override
  void didUpdateWidget(covariant RecetaSummaryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPremium != widget.isPremium) {
      if (widget.isPremium) {
        _startAutoSlideTimer();
      } else {
        _autoSlideTimer?.cancel();
        _autoSlideTimer = null;
      }
    }

    final total = _getTotalSlides();
    if (_currentSummaryIndex >= total) {
      _currentSummaryIndex = 0;
      if (_summaryPageController.hasClients) {
        _summaryPageController.jumpToPage(0);
      }
    }
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _dotsFadeTimer?.cancel();
    _waveController.dispose();
    _summaryPageController.dispose();
    super.dispose();
  }

  int _getTotalSlides() {
    if (!widget.isPremium) return 2;
    if (widget.effectiveTips.isEmpty) return 1;
    return 1000;
  }

  int _getCycleLength() {
    if (!widget.isPremium) return 2;
    if (widget.effectiveTips.isEmpty) return 1;
    return widget.effectiveTips.length * 2;
  }

  void _startAutoSlideTimer() {
    _autoSlideTimer?.cancel();
    if (!widget.isPremium) return;

    _autoSlideTimer = Timer(const Duration(milliseconds: 6000), () {
      if (!mounted || !_summaryPageController.hasClients) return;

      final total = _getTotalSlides();
      if (_currentSummaryIndex >= total - 1) {
        _summaryPageController.animateToPage(
          0,
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeInOutCubic,
        );
      } else {
        _summaryPageController.nextPage(
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  void _onSummaryPageChanged(int idx) {
    _dotsFadeTimer?.cancel();
    setState(() {
      _currentSummaryIndex = idx;
      _showDotsIndicator = true;
    });

    _dotsFadeTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() {
          _showDotsIndicator = false;
        });
      }
    });

    _startAutoSlideTimer();
  }

  bool _esHoy(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  Widget _buildSummaryItem(String number, String label) {
    return Column(
      children: [
        Text(
          number,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.8),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryMetricsSlide() {
    final l10n = widget.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _esHoy(widget.selectedDate)
                ? (l10n?.summaryToday ?? 'Resumen de hoy')
                : (l10n?.summaryDay ?? 'Resumen del día'),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem(
                widget.pendientesHoy.toString(),
                l10n?.pendingUppercase ?? 'PENDIENTES',
              ),
              _buildSummaryItem(
                widget.tomadasHoy.toString(),
                l10n?.takenUppercase ?? 'TOMADAS',
              ),
              _buildSummaryItem(
                '${widget.adherenciaHoy.toStringAsFixed(0)}%',
                l10n?.adherenceUppercase ?? 'ADHERENCIA',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAiTipSlide({
    required Map<String, String> tip,
    required int tipNumber,
    required int totalTips,
  }) {
    final content = tip['content']?.trim() ?? '';
    final isAi = tip['isAi'] == 'true';

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 16),
      child: Stack(
        children: [
          if (isAi)
            Positioned(
              top: 0,
              right: 0,
              child: IgnorePointer(
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white.withValues(alpha: 0.25),
                  size: 20,
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              content,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17.0,
                fontWeight: FontWeight.w600,
                height: 1.35,
                letterSpacing: -0.2,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProTeaserSlide(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.amberAccent,
                      size: 13,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      widget.l10n?.cardAiHealthTips ??
                          'Consejos de Salud con IA',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'PRO',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.l10n?.cardAiTipsDescription ??
                      'Recibe recomendaciones y precauciones personalizadas para tus medicamentos.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => const SubscriptionPage(
                            sourceFeature:
                                'los consejos de tratamiento con Inteligencia Artificial',
                          ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.primaryColor,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  widget.l10n?.cardViewPro ?? 'Ver PRO',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final cycleLength = _getCycleLength();
    final totalSlides = _getTotalSlides();
    final dotsCount = cycleLength;
    final activeDot = _currentSummaryIndex % dotsCount;

    return Container(
      height: 154,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.18),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _waveController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: WavePainter(animationValue: _waveController.value),
                  );
                },
              ),
            ),
          ),
          PageView.builder(
            controller: _summaryPageController,
            itemCount: totalSlides,
            onPageChanged: _onSummaryPageChanged,
            itemBuilder: (context, index) {
              Widget slideContent;
              if (!widget.isPremium) {
                if (index == 0) {
                  slideContent = _buildSummaryMetricsSlide();
                } else {
                  slideContent = _buildProTeaserSlide(context);
                }
              } else {
                if (widget.effectiveTips.isEmpty || index % 2 == 0) {
                  slideContent = _buildSummaryMetricsSlide();
                } else {
                  final tips = widget.effectiveTips;
                  final tipIdx = (index % cycleLength) ~/ 2;
                  final tip = tips[tipIdx % tips.length];
                  slideContent = _buildAiTipSlide(
                    tip: tip,
                    tipNumber: (tipIdx % tips.length) + 1,
                    totalTips: tips.length,
                  );
                }
              }

              // Robust slide transition that NEVER hides the active slide:
              return AnimatedBuilder(
                animation: _summaryPageController,
                builder: (context, child) {
                  // If controller is not ready or has no dimensions, ALWAYS show child at 100% opacity!
                  if (!_summaryPageController.hasClients ||
                      !_summaryPageController.position.haveDimensions) {
                    return child!;
                  }

                  final double? page = _summaryPageController.page;
                  if (page == null || page.isNaN) {
                    return child!;
                  }

                  final double diff = (index - page).clamp(-1.0, 1.0);
                  // Gentle opacity: never 0 for the active or settling page
                  final double opacity = (1.0 - (diff.abs() * 0.6)).clamp(
                    0.0,
                    1.0,
                  );
                  final double extraSlide = diff * 24.0;

                  return Opacity(
                    opacity: opacity,
                    child: Transform.translate(
                      offset: Offset(extraSlide, 0),
                      child: child,
                    ),
                  );
                },
                child: slideContent,
              );
            },
          ),
          if (dotsCount > 1)
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                opacity: _showDotsIndicator ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 350),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(dotsCount, (dotIdx) {
                    final isSelected = dotIdx == activeDot;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: isSelected ? 16 : 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
