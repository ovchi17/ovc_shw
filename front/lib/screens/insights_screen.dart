import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/colors.dart';
import '../core/param_info.dart';
import '../models/models.dart';
import '../services/api.dart';
import '../widgets/glass_card.dart';
import '../widgets/score_circle.dart';
import '../widgets/charts/score_line_chart.dart';
import '../utils/formatters.dart';
import 'tips_screen.dart';

class InsightsScreen extends StatefulWidget {
  final SpeechParameter param;

  const InsightsScreen({super.key, required this.param});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  int _period = 7;
  bool _loadingTrend = true;
  List<double> _trendScores = [];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
    _loadTrend();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadTrend() async {
    setState(() => _loadingTrend = true);
    try {
      final period = _period == 7 ? '7d' : _period == 0 ? 'all' : '30d';
      final data = await Api.getParameterDynamics(period: period);
      final rawList =
          data[widget.param.name] as List<dynamic>? ?? [];
      final scores =
          rawList.map((v) => (v as num).toDouble()).toList();
      if (mounted) {
        setState(() {
          _trendScores = scores;
          _loadingTrend = false;
        });
      }
    } catch (e, st) {
      debugPrint('InsightsScreen: trend load failed: $e\n$st');
      if (mounted) {
        setState(() {
          _trendScores = [];
          _loadingTrend = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.param;
    final info = paramInfoMap[p.name];
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 280,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.5),
                radius: 0.85,
                colors: [
                  p.color.withValues(alpha: 0.14),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: cs.background.withValues(alpha: 0.92),
              elevation: 0,
              leading: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.surface.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.arrow_back_ios_new_rounded,
                      color: cs.onSurfaceVariant, size: 18),
                ),
              ),
              title: Text(
                p.nameRu,
                style: GoogleFonts.inter(
                  color: cs.onSurface,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 60),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  FadeTransition(
                    opacity: _anim,
                    child: SlideTransition(
                      position: Tween(
                              begin: const Offset(0, 0.15),
                              end: Offset.zero)
                          .animate(_anim),
                      child: Center(
                        child: Column(children: [
                          const SizedBox(height: 8),
                          ScoreCircle(score: p.score, size: 140),
                          const SizedBox(height: 12),
                          ScoreLabelPill(score: p.score, color: p.color),
                        ]),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          _SectionTitle('Динамика балла'),
                          const Spacer(),
                          _PeriodToggle(
                            selected: _period,
                            onChanged: (v) {
                              setState(() => _period = v);
                              _loadTrend();
                            },
                          ),
                        ]),
                        const SizedBox(height: 14),
                        if (_loadingTrend)
                          const SizedBox(
                            height: 110,
                            child: Center(
                                child: CircularProgressIndicator()),
                          )
                        else
                          SizedBox(
                            height: 160,
                            child: ScoreLineChart(
                              scores: _trendScores,
                              color: p.color,
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  if (p.extraMetrics.isNotEmpty) ...[
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionTitle('Ключевые метрики'),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: p.extraMetrics.entries
                                .map((e) => _MetricChip(
                                      label: e.key,
                                      value: e.value,
                                      color: p.color,
                                    ))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (p.subScores.isNotEmpty) ...[
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionTitle('Подробные оценки'),
                          const SizedBox(height: 12),
                          ...p.subScores.entries.map((e) {
                            final label = subScoreLabels[e.key] ?? e.key;
                            final v = e.value.clamp(0.0, 100.0);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(children: [
                                Expanded(flex: 3,
                                    child: Text(label,
                                        style: GoogleFonts.inter(
                                            color: cs.onSurfaceVariant,
                                            fontSize: 12))),
                                const SizedBox(width: 8),
                                Expanded(flex: 4,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(3),
                                      child: LinearProgressIndicator(
                                        value: v / 100,
                                        backgroundColor: cs.onSurfaceVariant.withValues(alpha: 0.12),
                                        valueColor: AlwaysStoppedAnimation(AppColors.scoreColor(v)),
                                        minHeight: 5,
                                      ),
                                    )),
                                const SizedBox(width: 8),
                                SizedBox(width: 28,
                                    child: Text('${v.toInt()}',
                                        textAlign: TextAlign.right,
                                        style: GoogleFonts.inter(
                                            color: AppColors.scoreColor(v),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700))),
                              ]),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  if (p.rawData.isNotEmpty) ...[
                    _RawDataSection(param: p),
                    const SizedBox(height: 14),
                  ],

                  if (info != null) ...[
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionTitle('Что это измеряет'),
                          const SizedBox(height: 10),
                          Text(
                            info.whatItMeasures,
                            style: GoogleFonts.inter(
                              color: cs.onSurfaceVariant,
                              fontSize: 14,
                              height: 1.55,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    GlassCard(
                      borderColor: p.color.withValues(alpha: 0.2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionTitle('Упражнение'),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: p.color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.fitness_center_rounded,
                                    color: p.color, size: 16),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  info.adviceForScore(p.score),
                                  style: GoogleFonts.inter(
                                    color: cs.onSurface,
                                    fontSize: 14,
                                    height: 1.55,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Divider(color: cs.onSurface.withValues(alpha: 0.1), height: 1),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const TipsScreen()),
                            ),
                            child: Row(children: [
                              const Icon(Icons.school_rounded,
                                  color: AppColors.accentSuccess, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'Все советы и упражнения',
                                style: GoogleFonts.inter(
                                    color: AppColors.accentSuccess,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600),
                              ),
                              const Spacer(),
                              const Icon(Icons.arrow_forward_ios_rounded,
                                  color: AppColors.accentSuccess, size: 13),
                            ]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ]),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: GoogleFonts.inter(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      );
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MetricChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(
          value,
          style: GoogleFonts.inter(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(
            color: cs.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ]),
    );
  }
}

class _PeriodToggle extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;

  const _PeriodToggle(
      {required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const options = [(7, '7д'), (30, '30д'), (0, 'Всё')];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: cs.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: options.map((entry) {
          final v = entry.$1;
          final label = entry.$2;
          final isSelected = v == selected;
          return GestureDetector(
            onTap: () => onChanged(v),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.accentSuccess
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                label,
                style: GoogleFonts.inter(
                  color: isSelected ? cs.background : cs.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _RawDataSection extends StatelessWidget {
  final SpeechParameter param;
  const _RawDataSection({required this.param});

  @override
  Widget build(BuildContext context) {
    final raw = param.rawData;
    final p = param;
    final List<Widget> rows = [];

    switch (p.name) {
      case 'parasites':
        final allFillers = (raw['top_fillers_overall'] as List<dynamic>? ??
                raw['top_fillers'] as List<dynamic>? ??
                [])
            .whereType<Map>()
            .toList();
        if (allFillers.isNotEmpty) {
          rows.add(_subTitle(context, 'Все слова-паразиты'));
          for (final f in allFillers) {
            final word = (f['word'] ?? '').toString();
            final count = (f['count'] as num? ?? 0).toInt();
            final pct = (f['pct'] ?? f['percent'] as num? ?? 0).toDouble();
            rows.add(_FillerRow(word: word, count: count, pct: pct, color: p.color));
          }
        }
        final timecodes = (raw['filler_timecodes'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .toList();
        if (timecodes.isNotEmpty) {
          rows.add(const SizedBox(height: 12));
          rows.add(_subTitle(context, 'Вхождения (${timecodes.length})'));
          for (final tc in timecodes) {
            final word = (tc['word'] ?? '').toString();
            final start = (tc['start'] as num? ?? 0).toDouble();
            rows.add(_TimecodeRow(label: '«$word»', startSec: start, color: p.color));
          }
        }
        break;

      case 'pauses':
        final pauseTcs = (raw['long_pause_timecodes'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .toList();
        if (pauseTcs.isNotEmpty) {
          rows.add(_subTitle(context, 'Длинные паузы (${pauseTcs.length})'));
          for (final tc in pauseTcs) {
            final start = (tc['start'] as num? ?? 0).toDouble();
            final durMs = (tc['duration_ms'] as num? ?? 0).toInt();
            final durStr = durMs >= 1000
                ? '${(durMs / 1000).toStringAsFixed(1)} с'
                : '${durMs} мс';
            rows.add(_TimecodeRow(
                label: 'Пауза $durStr', startSec: start, color: p.color));
          }
        }
        break;

      case 'lexical':
        final repeated = (raw['top_repeated_words'] as List<dynamic>? ?? [])
            .map((w) => w.toString())
            .toList();
        if (repeated.isNotEmpty) {
          rows.add(_subTitle(context, 'Часто повторяемые слова'));
          rows.add(Wrap(
            spacing: 8,
            runSpacing: 6,
            children: repeated
                .map((w) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: p.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: p.color.withValues(alpha: 0.25)),
                      ),
                      child: Text(w,
                          style: GoogleFonts.inter(
                              color: p.color,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ))
                .toList(),
          ));
        }
        break;

      case 'tempo':
        final windows = (raw['window_scores'] as List<dynamic>? ?? [])
            .whereType<num>()
            .toList();
        if (windows.isNotEmpty) {
          rows.add(_subTitle(context, 'Темп по фрагментам (сл/мин)'));
          rows.add(_WindowBars(values: windows.map((v) => v.toDouble()).toList(),
              color: p.color));
        }
        break;

      case 'syntax':
        final utterances = (raw['utterance_lengths'] as List<dynamic>? ?? [])
            .whereType<num>()
            .toList();
        if (utterances.isNotEmpty) {
          rows.add(_subTitle(context, 'Длина фраз (слова)'));
          rows.add(_WindowBars(
              values: utterances.map((v) => v.toDouble()).toList(),
              color: p.color));
        }
        break;
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle('Подробные данные'),
          const SizedBox(height: 12),
          ...rows,
        ],
      ),
    );
  }

  Widget _subTitle(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      );
}

class _FillerRow extends StatelessWidget {
  final String word;
  final int count;
  final double pct;
  final Color color;
  const _FillerRow(
      {required this.word,
      required this.count,
      required this.pct,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Expanded(
          flex: 3,
          child: Text(
            '«$word»',
            style: GoogleFonts.inter(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          flex: 5,
          child: Stack(children: [
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            FractionallySizedBox(
              widthFactor: (pct / 100).clamp(0.0, 1.0),
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        Text(
          '$count раз',
          style: GoogleFonts.inter(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ]),
    );
  }
}

class _TimecodeRow extends StatelessWidget {
  final String label;
  final double startSec;
  final Color color;
  const _TimecodeRow(
      {required this.label, required this.startSec, required this.color});

  String _fmt(double sec) =>
      Duration(milliseconds: (sec * 1000).round()).mmss;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            _fmt(startSec),
            style: GoogleFonts.inter(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ),
      ]),
    );
  }
}

class _WindowBars extends StatelessWidget {
  final List<double> values;
  final Color color;
  const _WindowBars({required this.values, required this.color});

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) return const SizedBox.shrink();
    return SizedBox(
      height: 60,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: values.take(30).map((v) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: FractionallySizedBox(
                heightFactor: (v / maxVal).clamp(0.05, 1.0),
                alignment: Alignment.bottomCenter,
                child: Container(
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
