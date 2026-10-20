// lib/widgets/chat/animated_typing_dots.dart
import 'dart:async';
import 'package:flutter/material.dart';

/// Indicador visual animado de tres puntos pulsantes mientras el asistente
/// genera una respuesta.
class AnimatedTypingDots extends StatefulWidget {
  const AnimatedTypingDots({super.key});

  @override
  State<AnimatedTypingDots> createState() => _AnimatedTypingDotsState();
}

class _AnimatedTypingDotsState extends State<AnimatedTypingDots> {
  int _activeDot = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 260), (_) {
      if (!mounted) return;
      setState(() => _activeDot = (_activeDot + 1) % 3);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        final targetOpacity = _activeDot == index ? 1.0 : 0.25;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: AnimatedOpacity(
            opacity: targetOpacity,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF6A7485),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      }),
    );
  }
}
