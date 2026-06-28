import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/colors.dart';
import 'score_line_chart.dart';

class ParameterTrendGrid extends StatelessWidget {
  final Map<String, List<double>> paramTrends;
  final List<String> dates;

  const ParameterTrendGrid({super.key, required this.paramTrends, this.dates = const []});

  static const _params = [
    _ParamMeta('parasites', 'Паразиты', AppColors.accentDanger),
    _ParamMeta('pauses', 'Паузы', AppColors.accentWarning),
    _ParamMeta('tempo', 'Темп', AppColors.accentBlue),
    _ParamMeta('lexical', 'Лексика', AppColors.accentSuccess),
    _ParamMeta('syntax', 'Синтаксис', Color(0xFFAB5CF2)),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _params.map((meta) {
        final scores = paramTrends[meta.key] ?? [];
        return _ParamCard(meta: meta, scores: scores, dates: dates);
      }).toList(),
    );
  }
}
class _ParamCard extends StatelessWidget {
  final _ParamMeta meta;
  final List<double> scores;
  final List<String> dates;
  const _ParamCard({required this.meta, required this.scores, this.dates = const []});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: meta.color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: meta.color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              meta.label,
              style: GoogleFonts.inter(
                color: cs.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            if (scores.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: meta.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(scores.reduce((a, b) => a + b) / scores.length).round()}',
                  style: GoogleFonts.inter(
                    color: meta.color,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            height: 150,
            child: ScoreLineChart(
              scores: scores,
              dates: dates,
              color: meta.color,
            ),
          ),
        ],
      ),
    );
  }
}
class _ParamMeta {
  final String key;
  final String label;
  final Color color;
  const _ParamMeta(this.key, this.label, this.color);
}
