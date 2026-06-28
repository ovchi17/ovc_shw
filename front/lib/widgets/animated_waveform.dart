import 'dart:math';
import 'package:flutter/material.dart';
import '../core/colors.dart';

class AnimatedWaveform extends StatefulWidget {
  final bool isPlaying;
  final double height;
  final int barCount;
  final Color? color1;
  final Color? color2;

  const AnimatedWaveform({
    super.key,
    required this.isPlaying,
    this.height = 80,
    this.barCount = 48,
    this.color1,
    this.color2,
  });

  @override
  State<AnimatedWaveform> createState() => _AnimatedWaveformState();
}

class _AnimatedWaveformState extends State<AnimatedWaveform>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _controllers = List.generate(
      widget.barCount,
          (i) =>
          AnimationController(
            vsync: this,
            duration: Duration(milliseconds: 400 + _random.nextInt(600)),
          ),
    );
    _animations = _controllers.map((c) {
      return Tween<double>(
        begin: 0.05 + _random.nextDouble() * 0.15,
        end: 0.3 + _random.nextDouble() * 0.7,
      ).animate(CurvedAnimation(parent: c, curve: Curves.easeInOut));
    }).toList();
    if (widget.isPlaying) _startAnimations();
  }

  void _startAnimations() {
    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 15), () {
        if (mounted) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }

  void _stopAnimations() {
    for (final c in _controllers) {
      c.animateTo(0.1, duration: const Duration(milliseconds: 300));
    }
  }

  @override
  void didUpdateWidget(AnimatedWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      widget.isPlaying ? _startAnimations() : _stopAnimations();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: Listenable.merge(_controllers),
        builder: (context, _) {
          return CustomPaint(
            size: Size.infinite,
            painter: _WaveformPainter(
              amplitudes: _animations.map((a) => a.value).toList(),
              color1: widget.color1 ?? AppColors.waveStart,
              color2: widget.color2 ?? AppColors.waveEnd,
            ),
          );
        },
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> amplitudes;
  final Color color1;
  final Color color2;

  _WaveformPainter({
    required this.amplitudes,
    required this.color1,
    required this.color2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final barWidth = size.width / (amplitudes.length * 1.6);
    final gap = barWidth * 0.6;
    final totalWidth = amplitudes.length * (barWidth + gap) - gap;
    final startX = (size.width - totalWidth) / 2;

    for (int i = 0; i < amplitudes.length; i++) {
      final t = i / (amplitudes.length - 1);
      final color = Color.lerp(color1, color2, t)!;
      final amp = amplitudes[i];
      final barHeight = size.height * amp;
      final x = startX + i * (barWidth + gap);
      final y = (size.height - barHeight) / 2;

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, barHeight),
          const Radius.circular(3),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.amplitudes != amplitudes;
}
