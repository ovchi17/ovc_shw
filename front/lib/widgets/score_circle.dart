import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/colors.dart';

class ScoreCircle extends StatefulWidget {
  final double score;
  final double size;
  final bool animate;
  final Widget? centerChild;

  const ScoreCircle({
    super.key,
    required this.score,
    this.size = 160,
    this.animate = true,
    this.centerChild,
  });

  @override
  State<ScoreCircle> createState() => _ScoreCircleState();
}

class _ScoreCircleState extends State<ScoreCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scoreAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scoreAnim = Tween<double>(begin: 0, end: widget.score).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    if (widget.animate) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scoreAnim,
      builder: (context, _) {
        final score = _scoreAnim.value;
        final color = AppColors.scoreColor(score);
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _ScoreCirclePainter(score: score, color: color),
            child: Center(
              child: widget.centerChild ??
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        score.toInt().toString(),
                        style: GoogleFonts.inter(
                          color: color,
                          fontSize: widget.size * 0.28,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                      Text(
                        'из 100',
                        style: GoogleFonts.inter(
                          color: AppColors.textSecondary,
                          fontSize: widget.size * 0.09,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
            ),
          ),
        );
      },
    );
  }
}

class _ScoreCirclePainter extends CustomPainter {
  final double score;
  final Color color;

  _ScoreCirclePainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    const strokeWidth = 8.0;
    const startAngle = -pi / 2;
    final clamped = score.clamp(0.0, 100.0);
    final sweepAngle = 2 * pi * (clamped / 100).clamp(0.001, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      2 * pi,
      false,
      Paint()
        ..color = AppColors.neutral.withValues(alpha: 0.2)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color = color.withValues(alpha: 0.3)
        ..strokeWidth = strokeWidth + 8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    final rect = Rect.fromCircle(center: center, radius: radius);
    final gradient = SweepGradient(
      startAngle: startAngle,
      endAngle: startAngle + sweepAngle,
      colors: [color.withValues(alpha: 0.7), color],
    );

    canvas.drawArc(
      rect,
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..shader = gradient.createShader(rect)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ScoreCirclePainter old) =>
      old.score != score || old.color != color;
}
class ScoreLabelPill extends StatelessWidget {
  final double score;
  final Color? color;
  const ScoreLabelPill({super.key, required this.score, this.color});

  static String labelFor(double score) {
    if (score >= 80) return 'Отличная речь!';
    if (score >= 60) return 'Хороший результат';
    if (score >= 40) return 'Есть над чем работать';
    return 'Нужна тренировка';
  }

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.scoreColor(score);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Text(
        labelFor(score),
        style: GoogleFonts.inter(
          color: c, fontSize: 14, fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class ScoreBar extends StatelessWidget {
  final double score;
  final double height;

  const ScoreBar({super.key, required this.score, this.height = 6});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.scoreColor(score);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Stack(
        children: [
          Container(
            height: height,
            color: AppColors.neutral.withValues(alpha: 0.2),
          ),
          FractionallySizedBox(
            widthFactor: (score / 100).clamp(0.0, 1.0),
            child: Container(
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(height),
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: 0.8), color],
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
