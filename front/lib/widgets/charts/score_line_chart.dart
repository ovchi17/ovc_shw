import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/colors.dart';
import '../../utils/formatters.dart';

class ScoreLineChart extends StatelessWidget {
  final List<double> scores;
  final List<String> dates;
  final Color? color;

  const ScoreLineChart({super.key, required this.scores, this.dates = const [], this.color});

  @override
  Widget build(BuildContext context) {
    if (scores.length < 3) {
      return Center(
        child: Text(
          'Недостаточно записей для графика',
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      );
    }

    final lineColor = color ?? AppColors.accentSuccess;

    final spots = scores
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    final minVal = scores.reduce(math.min);
    final maxVal = scores.reduce(math.max);
    final minY = ((minVal - 10).clamp(0, 90) / 10).floor() * 10.0;
    final maxY = ((maxVal + 10).clamp(10, 110) / 10).ceil() * 10.0;
    final interval = ((maxY - minY) / 4).ceilToDouble().clamp(5.0, 25.0);

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (_) => FlLine(
            color: AppColors.neutral.withValues(alpha: 0.15),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            axisNameWidget: Text(
              'балл',
              style: GoogleFonts.inter(color: AppColors.neutral, fontSize: 9),
            ),
            axisNameSize: 14,
            sideTitles: SideTitles(
              showTitles: true,
              interval: interval,
              reservedSize: 30,
              getTitlesWidget: (v, _) => Text(
                '${v.toInt()}',
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: math.max(1, (scores.length / 5).ceil()).toDouble(),
              getTitlesWidget: (v, _) {
                final idx = v.toInt();
                final step = math.max(1, scores.length ~/ 5);
                if (idx % step != 0) return const SizedBox.shrink();
                String label;
                if (dates.length > idx && dates[idx].isNotEmpty) {
                  try {
                    final dt = DateTime.parse(dates[idx]);
                    label = DateFormat.dayMonth(dt);
                  } catch (_) {
                    label = '';
                  }
                } else {
                  final dt = DateTime.now()
                      .subtract(Duration(days: scores.length - 1 - idx));
                  label = DateFormat.dayMonth(dt);
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minY: minY,
        maxY: maxY.clamp(minY + 10, 100),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.35,
            color: lineColor,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: scores.length <= 15,
              getDotPainter: (spot, _, __, idx) => FlDotCirclePainter(
                radius: idx == scores.length - 1 ? 4.5 : 3.0,
                color: lineColor,
                strokeWidth: 2,
                strokeColor: AppColors.background,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  lineColor.withValues(alpha: 0.2),
                  lineColor.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutCubic,
    );
  }
}
