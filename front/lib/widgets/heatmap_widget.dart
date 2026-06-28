import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/colors.dart';

class HeatmapCalendar extends StatelessWidget {
  final List<double?> scores;
  final int days;

  const HeatmapCalendar({
    super.key,
    required this.scores,
    this.days = 30,
  });

  Color _cellColor(double? score) {
    if (score == null) return AppColors.neutral.withValues(alpha: 0.12);
    if (score >= 80) return AppColors.accentSuccess.withValues(alpha: 0.85);
    if (score >= 60) return AppColors.accentWarning.withValues(alpha: 0.8);
    return AppColors.accentDanger.withValues(alpha: 0.8);
  }

  @override
  Widget build(BuildContext context) {
    final cells = List.generate(days, (i) {
      final score = i < scores.length ? scores[i] : null;
      return score;
    });

    const cols = 7;
    final rows = (days / cols).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс']
              .map(
                (d) => Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 6),
        ...List.generate(rows, (row) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              children: List.generate(cols, (col) {
                final idx = row * cols + col;
                if (idx >= days) return const Expanded(child: SizedBox());
                final score = idx < cells.length ? cells[idx] : null;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.5),
                    child: Tooltip(
                      message: score != null
                          ? '${score.toInt()} баллов'
                          : 'Нет записи',
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Container(
                          decoration: BoxDecoration(
                            color: _cellColor(score),
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: score != null
                                ? [
                                    BoxShadow(
                                      color: _cellColor(score)
                                          .withValues(alpha: 0.4),
                                      blurRadius: 4,
                                    )
                                  ]
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          );
        }),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(
              'Баллы:',
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
            const SizedBox(width: 8),
            _LegendItem(color: AppColors.accentDanger, label: '<60'),
            const SizedBox(width: 8),
            _LegendItem(color: AppColors.accentWarning, label: '60–79'),
            const SizedBox(width: 8),
            _LegendItem(color: AppColors.accentSuccess, label: '≥80'),
          ],
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
