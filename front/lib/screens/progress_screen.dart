import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/colors.dart';
import '../widgets/glass_card.dart';
import '../widgets/stat_card.dart';
import '../widgets/heatmap_widget.dart';
import '../widgets/charts/parameter_trend_grid.dart';
import '../widgets/charts/score_line_chart.dart';
import '../services/api.dart';
import 'compare_screen.dart';
import 'recordings_screen.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with SingleTickerProviderStateMixin {
  int _range = 30;
  bool _loading = true;
  bool _reloading = false;
  String? _error;

  late final TabController _tabCtrl;

  Map<String, dynamic>? _overview;
  Map<String, dynamic>? _dynamics;
  Map<String, dynamic>? _activity;
  Map<String, List<double>> _paramTrends = {};
  Map<String, Map<String, double>> _latestSubScores = {};
  List<String> _pointDates = [];
  List<String> _paramDates = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load(initial: true);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool initial = false}) async {
    setState(() {
      if (initial) _loading = true;
      else _reloading = true;
      _error = null;
    });
    try {
      final period = _range == 7 ? '7d' : _range == 0 ? 'all' : '30d';
      final results = await Future.wait([
        Api.getProgressOverview(period: period),
        Api.getDynamics(period: period),
        Api.getActivity(),
        Api.getParameterDynamics(period: period).catchError((_) => <String, dynamic>{}),
      ]);
      setState(() {
        _overview = results[0];
        _dynamics = results[1];
        _activity = results[2];
        final paramData = results[3];

        final dynPoints = (_dynamics!['points'] as List<dynamic>? ?? []).whereType<Map>().toList();
        _pointDates = dynPoints.map((p) => p['date'] as String? ?? '').toList();

        _paramDates = (paramData['dates'] as List<dynamic>? ?? [])
            .map((d) => d.toString())
            .toList();

        _paramTrends = {};
        for (final key in ['parasites', 'pauses', 'tempo', 'lexical', 'syntax']) {
          final raw = paramData[key] as List<dynamic>? ?? [];
          _paramTrends[key] = raw.map((v) => (v as num).toDouble()).toList();
        }
        final latestSubRaw = paramData['latest_sub_scores'] as Map? ?? {};
        _latestSubScores = {};
        for (final key in ['parasites', 'pauses', 'tempo', 'lexical', 'syntax']) {
          final sub = latestSubRaw[key] as Map? ?? {};
          _latestSubScores[key] = sub.map((k, v) =>
              MapEntry(k.toString(), (v as num).toDouble()));
        }
        _loading = false;
        _reloading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
        _reloading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: AppColors.accentDanger, size: 48),
                const SizedBox(height: 16),
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                        color: cs.onSurfaceVariant, fontSize: 14)),
                const SizedBox(height: 24),
                GlassButton(
                  onTap: _load,
                  child: Center(
                    child: Text('Повторить',
                        style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final ov = _overview ?? {};
    final dyn = _dynamics ?? {};
    final act = _activity ?? {};

    final currentScore = (ov['current_score'] as int?) ?? 0;
    final scoreChange = (ov['score_change'] as int?) ?? 0;
    final streak = (ov['streak'] as int?) ?? 0;
    final totalRecs = (ov['total_recordings'] as int?) ?? 0;

    final points = (dyn['points'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((p) => (p['score'] as int? ?? 0).toDouble())
        .toList();
    final pointDates = _pointDates;

    final allActivityDays = (act['days'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((d) => (d['score'] as num?)?.toDouble())
        .toList();
    final heatmapDays = (_range == 0 || _range >= allActivityDays.length)
        ? allActivityDays.length
        : _range;
    final activityDays = allActivityDays.length > heatmapDays
        ? allActivityDays.sublist(allActivityDays.length - heatmapDays)
        : allActivityDays;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            pinned: true,
            elevation: 0,
            titleSpacing: 20,
            title: Text(
              'Прогресс',
              style: GoogleFonts.inter(
                color: cs.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(44),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: _SegmentedTabs(controller: _tabCtrl),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            _OverviewTab(
              range: _range,
              reloading: _reloading,
              onRangeChanged: (v) {
                setState(() => _range = v);
                _load();
              },
              currentScore: currentScore,
              scoreChange: scoreChange,
              streak: streak,
              totalRecs: totalRecs,
              points: points,
              pointDates: pointDates,
              activityDays: activityDays,
              heatmapDays: heatmapDays,
            ),
            _ParametersTab(
              paramTrends: _paramTrends,
              paramDates: _paramDates,
              latestSubScores: _latestSubScores,
              range: _range,
              reloading: _reloading,
              onRangeChanged: (v) {
                setState(() => _range = v);
                _load();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  final TabController controller;
  const _SegmentedTabs({required this.controller});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          color: AppColors.accentSuccess,
          borderRadius: BorderRadius.circular(9),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: cs.onSurfaceVariant,
        labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
        tabs: const [
          Tab(text: 'Общий прогресс'),
          Tab(text: 'По параметрам'),
        ],
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final int range;
  final bool reloading;
  final ValueChanged<int> onRangeChanged;
  final int currentScore;
  final int scoreChange;
  final int streak;
  final int totalRecs;
  final List<double> points;
  final List<String> pointDates;
  final List<double?> activityDays;
  final int heatmapDays;

  const _OverviewTab({
    required this.range,
    required this.reloading,
    required this.onRangeChanged,
    required this.currentScore,
    required this.scoreChange,
    required this.streak,
    required this.totalRecs,
    required this.points,
    required this.pointDates,
    required this.activityDays,
    required this.heatmapDays,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Row(
                children: [
                  Expanded(child: StatCard(
                    compact: true,
                    label: 'Средний балл',
                    value: '$currentScore',
                    icon: Icons.analytics_rounded,
                    color: AppColors.accentWarning,
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: StatCard(
                    compact: true,
                    label: range == 0 ? 'Рост за всё время' : 'Рост за ${range}д',
                    value: '${scoreChange >= 0 ? '+' : ''}$scoreChange',
                    icon: Icons.trending_up_rounded,
                    color: AppColors.accentSuccess,
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: StatCard(
                    compact: true,
                    label: 'Серия',
                    value: '$streak дней',
                    icon: Icons.local_fire_department_rounded,
                    color: AppColors.accentBlue,
                  )),
                ],
              ),

              const SizedBox(height: 16),

              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Динамика баллов',
                          style: GoogleFonts.inter(
                            color: cs.onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        _RangeToggle(selected: range, onChanged: onRangeChanged),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 180,
                      child: reloading
                          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                          : points.length < 3
                              ? Center(
                                  child: Text(
                                    'Недостаточно записей за период',
                                    style: GoogleFonts.inter(
                                      color: cs.onSurfaceVariant,
                                      fontSize: 13,
                                    ),
                                  ),
                                )
                              : ScoreLineChart(scores: points, dates: pointDates),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      range == 0
                          ? 'Активность за последние 30 дней'
                          : 'Активность за $range дней',
                      style: GoogleFonts.inter(
                        color: cs.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    HeatmapCalendar(scores: activityDays, days: heatmapDays),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              GlassCard(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CompareScreen()),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.accentBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.compare_arrows_rounded,
                          color: AppColors.accentBlue, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Сравнить записи',
                              style: GoogleFonts.inter(
                                color: cs.onSurface,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              )),
                          Text('Посмотри динамику по двум записям',
                              style: GoogleFonts.inter(
                                color: cs.onSurfaceVariant,
                                fontSize: 12,
                              )),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: cs.onSurfaceVariant, size: 20),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              GlassCard(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RecordingsScreen()),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.accentWarning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.history_rounded,
                          color: AppColors.accentWarning, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('История записей',
                              style: GoogleFonts.inter(
                                color: cs.onSurface,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              )),
                          Text(
                            totalRecs == 0
                                ? 'Нет записей'
                                : '$totalRecs ${_recWord(totalRecs)}',
                            style: GoogleFonts.inter(
                              color: cs.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: cs.onSurfaceVariant, size: 20),
                  ],
                ),
              ),

              if (totalRecs == 0) ...[
                const SizedBox(height: 32),
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.mic_none_rounded,
                          color: cs.onSurfaceVariant, size: 56),
                      const SizedBox(height: 16),
                      Text(
                        'Начни записывать',
                        style: GoogleFonts.inter(
                          color: cs.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'После первой записи здесь\nпоявится твой прогресс',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: cs.onSurfaceVariant,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ]),
          ),
        ),
      ],
    );
  }
}

class _ParametersTab extends StatelessWidget {
  final Map<String, List<double>> paramTrends;
  final List<String> paramDates;
  final Map<String, Map<String, double>> latestSubScores;
  final int range;
  final bool reloading;
  final ValueChanged<int> onRangeChanged;

  const _ParametersTab({
    required this.paramTrends,
    required this.paramDates,
    required this.latestSubScores,
    required this.range,
    required this.reloading,
    required this.onRangeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Тренд за период',
                    style: GoogleFonts.inter(
                      color: cs.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  _RangeToggle(selected: range, onChanged: onRangeChanged),
                ],
              ),
              const SizedBox(height: 5),
              if (reloading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else
                ParameterTrendGrid(paramTrends: paramTrends, dates: paramDates),
            ]),
          ),
        ),
      ],
    );
  }
}

String _recWord(int n) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod100 >= 11 && mod100 <= 14) return 'записей';
  if (mod10 == 1) return 'запись';
  if (mod10 >= 2 && mod10 <= 4) return 'записи';
  return 'записей';
}


class _RangeToggle extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;

  const _RangeToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: const [(7, '7д'), (30, '30д'), (0, 'Всё')].map((entry) {
          final v = entry.$1;
          final label = entry.$2;
          final isSelected = v == selected;
          return GestureDetector(
            onTap: () => onChanged(v),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.accentSuccess : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                label,
                style: GoogleFonts.inter(
                  color: isSelected ? Colors.white : cs.onSurfaceVariant,
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
