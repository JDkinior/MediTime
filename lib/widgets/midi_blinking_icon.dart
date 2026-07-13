import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class MidiBlinkingIcon extends StatefulWidget {
  final double size;

  const MidiBlinkingIcon({
    super.key,
    this.size = 28,
  });

  @override
  State<MidiBlinkingIcon> createState() => _MidiBlinkingIconState();
}

class _MidiBlinkingIconState extends State<MidiBlinkingIcon> {
  bool _isBlinking = false;
  Timer? _blinkTimer;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _scheduleBlink();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/chatbot/midi_blink.png'), context);
    precacheImage(const AssetImage('assets/chatbot/midi_open.png'), context);
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    super.dispose();
  }

  void _scheduleBlink() {
    final waitMs = 2200 + _random.nextInt(3800);
    _blinkTimer = Timer(Duration(milliseconds: waitMs), () {
      if (!mounted) return;
      setState(() => _isBlinking = true);
      _blinkTimer = Timer(const Duration(milliseconds: 150), () {
        if (!mounted) return;
        setState(() => _isBlinking = false);
        _scheduleBlink();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _isBlinking ? 'assets/chatbot/midi_blink.png' : 'assets/chatbot/midi_open.png',
      width: widget.size,
      height: widget.size,
      fit: BoxFit.contain,
    );
  }
}
