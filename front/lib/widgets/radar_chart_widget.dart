import 'dart:math';
import 'package:flutter/material.dart';
import '../core/colors.dart';
import '../models/models.dart';

class SpeechRadarWithNumbers extends StatelessWidget {
  final List<SpeechParameter> parameters;
  final List<SpeechParameter>? secondParameters;
  final double size;
  final bool showNumbers;

  const SpeechRadarWithNumbers({
    super.key,
    required this.parameters,
    this.size = 260,
    this.secondParameters,
    this.showNumbers = true,
    int maxValue = 100,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RadarPainter(
          parameters: parameters,
          secondParameters: secondParameters,
          showNumbers: showNumbers,
        ),
      ),
    );
  }
}

String _shortName(SpeechParameter p) {
  const map = {
    'parasites': 'Паразиты',
    'pauses': 'Паузы',
    'tempo': 'Темп',
    'lexical': 'Лексика',
    'syntax': 'Синтаксис',
  };
  return map[p.name] ?? p.nameRu;
}
class _RadarPainter extends CustomPainter {
  final List<SpeechParameter> parameters;
  final List<SpeechParameter>? secondParameters;
  final bool showNumbers;

  const _RadarPainter({
    required this.parameters,
    this.secondParameters,
    this.showNumbers = true,
  });

  static const _rings = [25.0, 50.0, 75.0, 100.0];
  static const _labelPadding = 56.0;

  @override
  void paint(Canvas canvas, Size size) {
    final n = parameters.length;
    if (n < 3) return;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = min(cx, cy) - _labelPadding;
    double angle(int i) => -pi / 2 + 2 * pi * i / n;
    Offset vertex(int i, double fraction) => Offset(
          cx + radius * fraction * cos(angle(i)),
          cy + radius * fraction * sin(angle(i)),
        );
    final ringPaint = Paint()..style = PaintingStyle.stroke;
    for (final ring in _rings) {
      final frac = ring / 100.0;
      final isOuter = ring == 100.0;
      ringPaint
        ..color = AppColors.neutral.withValues(alpha: isOuter ? 0.30 : 0.14)
        ..strokeWidth = isOuter ? 1.0 : 0.7;

      final path = Path();
      for (int i = 0; i < n; i++) {
        final p = vertex(i, frac);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas.drawPath(path, ringPaint);
    }
    final spokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = AppColors.neutral.withValues(alpha: 0.20);

    for (int i = 0; i < n; i++) {
      canvas.drawLine(Offset(cx, cy), vertex(i, 1.0), spokePaint);
    }
    Path buildPolygon(List<SpeechParameter> params) {
      final path = Path();
      for (int i = 0; i < n; i++) {
        final frac = (params[i].score.clamp(0.0, 100.0)) / 100.0;
        final p = vertex(i, frac);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      return path..close();
    }

    if (secondParameters != null && secondParameters!.length == n) {
      final p2 = buildPolygon(secondParameters!);
      canvas.drawPath(p2,
          Paint()..style = PaintingStyle.fill..color = AppColors.accentBlue.withValues(alpha: 0.13));
      canvas.drawPath(
        p2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..color = AppColors.accentBlue.withValues(alpha: 0.75)
          ..strokeJoin = StrokeJoin.round,
      );
    }

    final avgScore =
        parameters.map((p) => p.score).reduce((a, b) => a + b) / n;
    final fillColor = AppColors.scoreColor(avgScore);

    final p1 = buildPolygon(parameters);
    canvas.drawPath(
        p1, Paint()..style = PaintingStyle.fill..color = fillColor.withValues(alpha: 0.16));
    canvas.drawPath(
      p1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = fillColor.withValues(alpha: 0.90)
        ..strokeJoin = StrokeJoin.round,
    );

    for (int i = 0; i < n; i++) {
      final score = parameters[i].score;
      final frac = score.clamp(0.0, 100.0) / 100.0;
      final dotPos = vertex(i, frac);
      final dotColor = AppColors.scoreColor(score);
      canvas.drawCircle(dotPos, 7,
          Paint()..color = dotColor.withValues(alpha: 0.18));
      canvas.drawCircle(dotPos, 4,
          Paint()..color = dotColor);
      canvas.drawCircle(
        dotPos,
        4,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = Colors.white.withValues(alpha: 0.35)
          ..strokeWidth = 1.2,
      );
      _drawVertexLabel(
          canvas, _shortName(parameters[i]), showNumbers ? score.toInt() : null,
          dotColor, vertex(i, 1.0), angle(i));
    }
  }
  void _drawVertexLabel(Canvas canvas, String name, int? score,
      Color scoreColor, Offset anchor, double axisAngle) {
    final nameTp = TextPainter(
      text: TextSpan(
        text: name,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 10.0,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 58);

    TextPainter? scoreTp;
    if (score != null) {
      scoreTp = TextPainter(
        text: TextSpan(
          text: score.toString(),
          style: TextStyle(
            color: scoreColor,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 36);
    }

    const lineGap = 1.0;
    const anchorGap = 6.0;

    final blockW = scoreTp != null ? max(nameTp.width, scoreTp.width) : nameTp.width;
    final blockH = scoreTp != null
        ? scoreTp.height + lineGap + nameTp.height
        : nameTp.height;

    final cosA = cos(axisAngle);
    final sinA = sin(axisAngle);
    double blockLeft, blockTop;
    if (sinA < -0.5) {
      blockLeft = anchor.dx - blockW / 2;
      blockTop = anchor.dy - blockH - anchorGap;
    } else if (sinA > 0.5) {
      blockLeft = anchor.dx - blockW / 2;
      blockTop = anchor.dy + anchorGap;
    } else if (cosA > 0) {
      blockLeft = anchor.dx + anchorGap;
      blockTop = anchor.dy - blockH / 2;
    } else {
      blockLeft = anchor.dx - blockW - anchorGap;
      blockTop = anchor.dy - blockH / 2;
    }

    if (scoreTp != null) {
      scoreTp.paint(canvas,
          Offset(blockLeft + (blockW - scoreTp.width) / 2, blockTop));
      nameTp.paint(canvas,
          Offset(blockLeft + (blockW - nameTp.width) / 2,
              blockTop + scoreTp.height + lineGap));
    } else {
      nameTp.paint(canvas,
          Offset(blockLeft + (blockW - nameTp.width) / 2, blockTop));
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      parameters != old.parameters ||
      secondParameters != old.secondParameters ||
      showNumbers != old.showNumbers;
}
