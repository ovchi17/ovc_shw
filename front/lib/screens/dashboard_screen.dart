import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/colors.dart';
import '../models/models.dart';
import '../widgets/glass_card.dart';
import '../widgets/score_circle.dart';
import '../widgets/radar_chart_widget.dart';
import '../services/api.dart';
import '../core/icon_mapper.dart';
import '../utils/formatters.dart';
import 'results_screen.dart';
import 'recordings_screen.dart';
import 'insights_screen.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onGoToProfile;
  final VoidCallback? onGoToRecording;
  const DashboardScreen({super.key, this.onGoToProfile, this.onGoToRecording});

  @override
  State<DashboardScreen> createState() => _DashboardState();
}

class _DashboardState extends State<DashboardScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;
  List<Map<String, dynamic>> _recentRecs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _openRecording(Map<String, dynamic> data) async {
    final analysisId = data['analysis_id'] as int?;
    if (analysisId == null) return;
    try {
      final result = await Api.getAnalysis(analysisId);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ResultsScreen(result: result)),
      );
    } catch (e) {
      debugPrint('DashboardScreen: open analysis failed: $e');
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        Api.getDashboard(),
        Api.getRecordings(limit: 3),
      ]);
      setState(() {
        _data = results[0] as Map<String, dynamic>;
        _recentRecs = (results[1] as List)
            .whereType<Map<String, dynamic>>()
            .where((r) => r['status'] == 'done')
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
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
                Text(_error!, textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: cs.onSurfaceVariant, fontSize: 14)),
                const SizedBox(height: 24),
                GlassButton(
                  onTap: _load,
                  child: Center(
                    child: Text('Повторить',
                        style: GoogleFonts.inter(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final d = _data!;
    final user = d['user'] as Map<String, dynamic>? ?? {};
    final rawName = (user['name'] as String?) ?? '';
    final isPhone = RegExp(r'^[+\d\s\-()]{7,}$').hasMatch(rawName);
    final userName = isPhone ? '' : rawName;
    final streak = (user['streak'] as int?) ?? 0;
    final score = (d['score'] as int?) ?? 0;
    final scoreChange = (d['score_change'] as num?)?.toInt() ?? 0;
    final radarMap = d['radar'] as Map<String, dynamic>? ?? {};
    final paramsList = d['parameters'] as List<dynamic>? ?? [];

    final parameters = paramsList
        .whereType<Map>()
        .map((p) => SpeechParameter(
              name: (p['key'] ?? '').toString(),
              nameRu: (p['title'] ?? '').toString(),
              score: ((p['score'] ?? 0) as num).toDouble(),
              icon: iconFromParamKey((p['icon'] ?? '').toString()),
              topIssue: (p['description'] ?? '').toString(),
            ))
        .toList();

    final radarParams = [
      SpeechParameter(name: 'parasites', nameRu: 'Паразиты',
          score: ((radarMap['parasites'] ?? 0) as num).toDouble(),
          icon: Icons.block_rounded),
      SpeechParameter(name: 'pauses', nameRu: 'Паузы',
          score: ((radarMap['pauses'] ?? 0) as num).toDouble(),
          icon: Icons.pause_circle_outline_rounded),
      SpeechParameter(name: 'tempo', nameRu: 'Темп',
          score: ((radarMap['tempo'] ?? 0) as num).toDouble(),
          icon: Icons.speed_rounded),
      SpeechParameter(name: 'lexical', nameRu: 'Лексика',
          score: ((radarMap['lexical'] ?? 0) as num).toDouble(),
          icon: Icons.menu_book_rounded),
      SpeechParameter(name: 'syntax', nameRu: 'Синтаксис',
          score: ((radarMap['syntax'] ?? 0) as num).toDouble(),
          icon: Icons.account_tree_rounded),
    ];

    final hasData = score > 0 || parameters.isNotEmpty;

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            floating: true,
            pinned: false,
            elevation: 0,
            titleSpacing: 20,
            toolbarHeight: 64,
            surfaceTintColor: Colors.transparent,
            title: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (streak > 0) ...[
                        const SizedBox(height: 2),
                        Row(children: [
                          const Text('🔥', style: TextStyle(fontSize: 12)),
                          const SizedBox(width: 4),
                          Text('$streak ${pluralizeDays(streak)} подряд',
                              style: GoogleFonts.inter(
                                color: cs.onSurface, fontSize: 20,
                                fontWeight: FontWeight.w800, height: 1.1)),
                        ]),
                      ] else ...[
                        const SizedBox(height: 2),
                        Text('Средний балл',
                            style: GoogleFonts.inter(
                              color: cs.onSurface, fontSize: 20,
                              fontWeight: FontWeight.w800, height: 1.1)),
                      ],
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: widget.onGoToProfile,
                  child: Container(
                    width: 42, height: 42,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [AppColors.accentSuccess, AppColors.accentBlue],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: userName.isNotEmpty
                          ? Text(userName[0].toUpperCase(),
                              style: GoogleFonts.inter(color: Colors.white,
                                  fontSize: 17, fontWeight: FontWeight.w800))
                          : const Icon(Icons.person_rounded,
                              color: Colors.white, size: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
              ],
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (!hasData) ...[
                  const SizedBox(height: 12),
                  _EmptyStateCard(onTap: widget.onGoToRecording),
                ] else ...[
                  _ScoreHeroCard(score: score, scoreChange: scoreChange),
                  const SizedBox(height: 12),

                  if (radarParams.any((p) => p.score > 0)) ...[
                    GlassCard(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Text('Профиль речи',
                                style: GoogleFonts.inter(
                                  color: cs.onSurface, fontSize: 15,
                                  fontWeight: FontWeight.w700)),
                          ),
                          Center(child: SpeechRadarWithNumbers(
                              parameters: radarParams, size: 260)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  const SizedBox(height: 20),

                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 10),
                    child: Text('Параметры речи',
                        style: GoogleFonts.inter(
                          color: cs.onSurface, fontSize: 17,
                          fontWeight: FontWeight.w700)),
                  ),
                  ...parameters.map((p) => GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => InsightsScreen(param: p))),
                        child: _ParameterCard(param: p),
                      )),
                ],

                if (_recentRecs.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Последние записи',
                            style: GoogleFonts.inter(
                              color: cs.onSurface, fontSize: 17,
                              fontWeight: FontWeight.w700)),
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const RecordingsScreen())),
                          child: Text('Все',
                              style: GoogleFonts.inter(
                                color: AppColors.accentSuccess,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                  ..._recentRecs.map((r) => _RecentRecCard(
                        data: r, onTap: () => _openRecording(r))),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParameterCard extends StatelessWidget {
  final SpeechParameter param;
  const _ParameterCard({required this.param});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Row(children: [
          Container(width: 4, height: 58, color: param.color),
          const SizedBox(width: 14),
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: param.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(param.icon, color: param.color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(param.nameRu,
                        style: GoogleFonts.inter(
                          color: cs.onSurface, fontSize: 14,
                          fontWeight: FontWeight.w600)),
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Text('${param.score.toInt()}',
                          style: GoogleFonts.inter(
                            color: param.color, fontSize: 18,
                            fontWeight: FontWeight.w800, height: 1)),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: ScoreBar(score: param.score),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  final VoidCallback? onTap;
  const _EmptyStateCard({this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppColors.accentSuccess.withValues(alpha: 0.2),
                  AppColors.accentBlue.withValues(alpha: 0.2),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(Icons.mic_rounded,
                color: AppColors.accentSuccess, size: 36),
          ),
          const SizedBox(height: 20),
          Text('Ещё нет записей',
              style: GoogleFonts.inter(
                color: cs.onSurface, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'Запишите или загрузите речь —\nприложение покажет детальный анализ',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                color: cs.onSurfaceVariant, fontSize: 13, height: 1.5)),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppColors.accentSuccess, AppColors.accentBlue]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.mic_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text('Перейти к записи',
                      style: GoogleFonts.inter(
                          color: Colors.white, fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreHeroCard extends StatelessWidget {
  final int score;
  final int scoreChange;
  const _ScoreHeroCard({required this.score, required this.scoreChange});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = AppColors.scoreColor(score.toDouble());
    final label = score >= 80 ? 'Отличная речь!'
        : score >= 60 ? 'Хороший результат'
        : score >= 40 ? 'Есть над чем работать'
        : 'Нужна тренировка';

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Stack(children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.3),
                  radius: 0.9,
                  colors: [color.withValues(alpha: 0.12), Colors.transparent],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
          child: Column(children: [
            ScoreCircle(
                score: score.toDouble(),
                size: 150),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Text(label,
                  style: GoogleFonts.inter(
                      color: color, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (scoreChange != 0) ...[
                _TrendBadge(scoreChange: scoreChange),
                const SizedBox(width: 8),
              ],
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _TrendBadge extends StatelessWidget {
  final int scoreChange;
  const _TrendBadge({required this.scoreChange});

  @override
  Widget build(BuildContext context) {
    final isUp = scoreChange >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (isUp ? AppColors.accentSuccess : AppColors.accentDanger).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            color: isUp ? AppColors.accentSuccess : AppColors.accentDanger,
            size: 12,
          ),
          const SizedBox(width: 3),
          Text('${isUp ? '+' : ''}$scoreChange vs прошлая',
              style: GoogleFonts.inter(
                color: isUp ? AppColors.accentSuccess : AppColors.accentDanger,
                fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _RecentRecCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  const _RecentRecCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final score = (data['score'] as num?)?.toDouble() ?? 0;
    final scoreChange = (data['score_change'] as num?)?.toInt();
    final color = AppColors.scoreColor(score);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.1),
              border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
            ),
            child: Center(
              child: Text('${score.toInt()}',
                  style: GoogleFonts.inter(
                      color: color, fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text((data['title'] as String?) ?? 'Запись',
                  style: GoogleFonts.inter(
                    color: cs.onSurface, fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Row(children: [
                Text(DateFormat.shortFromIso(data['created_at'] as String?),
                    style: GoogleFonts.inter(
                        color: cs.onSurfaceVariant, fontSize: 12)),
                if (formatDurationSec(data['duration_sec'] as num?).isNotEmpty) ...[
                  Text('  ·  ${formatDurationSec(data['duration_sec'] as num?)}',
                      style: GoogleFonts.inter(
                          color: cs.onSurfaceVariant, fontSize: 12)),
                ],
              ]),
            ]),
          ),
          if (scoreChange != null && scoreChange != 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (scoreChange > 0
                        ? AppColors.accentSuccess
                        : AppColors.accentDanger)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  scoreChange > 0
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 10,
                  color: scoreChange > 0
                      ? AppColors.accentSuccess
                      : AppColors.accentDanger,
                ),
                Text('${scoreChange > 0 ? '+' : ''}$scoreChange',
                    style: GoogleFonts.inter(
                      color: scoreChange > 0
                          ? AppColors.accentSuccess
                          : AppColors.accentDanger,
                      fontSize: 11, fontWeight: FontWeight.w700)),
              ]),
            ),
            const SizedBox(width: 8),
          ],
          Icon(Icons.chevron_right_rounded,
              color: cs.onSurfaceVariant, size: 18),
        ]),
      ),
    );
  }
}
