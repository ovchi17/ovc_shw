import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/colors.dart';

class PauseHistogram extends StatefulWidget {
  final int brief;
  final int medium;
  final int long;

  const PauseHistogram({
    super.key,
    required this.brief,
    required this.medium,
    required this.long,
  });

  @override
  State<PauseHistogram> createState() => _PauseHistogramState();
}

class _PauseHistogramState extends State<PauseHistogram>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  int? _touched;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.brief + widget.medium + widget.long;

    if (total == 0) {
      return _ChartPlaceholder(label: 'Нет данных о паузах');
    }

    final vals = [
      widget.brief.toDouble(),
      widget.medium.toDouble(),
      widget.long.toDouble(),
    ];
    final maxVal = vals.reduce((a, b) => a > b ? a : b);
    final barColors = [
      AppColors.accentSuccess,
      AppColors.accentWarning,
      AppColors.accentDanger,
    ];
    final labels = ['Короткие\n<0.2 с', 'Средние\n0.2–1 с', 'Длинные\n>1 с'];
    final pcts = vals.map((v) => (v / total * 100).round()).toList();

    return FadeTransition(
      opacity: _anim,
      child: Column(children: [
        SizedBox(
          height: 120,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxVal * 1.25,
              barTouchData: BarTouchData(
                touchCallback: (event, response) {
                  if (!mounted) return;
                  setState(() {
                    _touched = (event is FlTapUpEvent)
                        ? response?.spot?.touchedBarGroupIndex
                        : null;
                  });
                },
                touchTooltipData: BarTouchTooltipData(
                  tooltipBgColor: AppColors.surface,
                  getTooltipItem: (group, _, rod, __) {
                    final names = ['Короткие', 'Средние', 'Длинные'];
                    return BarTooltipItem(
                      '${names[group.x]}: ${rod.toY.toInt()} пауз',
                      GoogleFonts.inter(
                          color: AppColors.textPrimary, fontSize: 12),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                bottomTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: false),
              barGroups: List.generate(3, (i) {
                final isTouched = _touched == i;
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: vals[i],
                      width: 52,
                      color: barColors[i]
                          .withValues(alpha: isTouched ? 1.0 : 0.78),
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8)),
                      backDrawRodData: BackgroundBarChartRodData(show: false),
                    ),
                  ],
                );
              }),
            ),
            swapAnimationDuration: const Duration(milliseconds: 600),
            swapAnimationCurve: Curves.easeInOutCubic,
          ),
        ),

        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(3, (i) {
            return _BarLabel(
              label: labels[i],
              count: vals[i].toInt(),
              pct: pcts[i],
              color: barColors[i],
            );
          }),
        ),
      ]),
    );
  }
}

class _BarLabel extends StatelessWidget {
  final String label;
  final int count;
  final int pct;
  final Color color;

  const _BarLabel({
    required this.label,
    required this.count,
    required this.pct,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(
        '$pct%',
        style: GoogleFonts.inter(
          color: color,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          height: 1.1,
        ),
      ),
      Text(
        '$count пауз',
        style: GoogleFonts.inter(
          color: AppColors.textSecondary,
          fontSize: 11,
          height: 1.3,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        label,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          color: AppColors.neutral,
          fontSize: 10,
          height: 1.3,
        ),
      ),
    ]);
  }
}

class _ChartPlaceholder extends StatelessWidget {
  final String label;
  const _ChartPlaceholder({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.bar_chart_rounded,
            color: AppColors.neutral.withValues(alpha: 0.4), size: 36),
        const SizedBox(height: 10),
        Text(label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 13,
            )),
      ]),
    );
  }
}
