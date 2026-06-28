import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/colors.dart';
import '../models/models.dart';
import '../utils/formatters.dart';
import '../widgets/glass_card.dart';
import '../widgets/score_circle.dart';
import '../widgets/radar_chart_widget.dart';
import '../services/api.dart';

class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key});

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  bool _loadingList = true;
  bool _loadingCompare = false;
  String? _listError;
  String? _compareError;

  List<Map<String, dynamic>> _recordings = [];
  int? _idA;
  int? _idB;
  Map<String, dynamic>? _compareData;

  @override
  void initState() {
    super.initState();
    _loadList();
  }

  Future<void> _loadList() async {
    setState(() { _loadingList = true; _listError = null; });
    try {
      final list = await Api.getRecordings(limit: 50);
      final done = list.whereType<Map<String, dynamic>>()
          .where((r) => r['status'] == 'done')
          .toList();
      setState(() {
        _recordings = done;
        _loadingList = false;
        if (done.length >= 2) {
          _idA = (done[0]['id'] as num).toInt();
          _idB = (done[1]['id'] as num).toInt();
          _loadCompare();
        }
      });
    } catch (e) {
      setState(() { _listError = e.toString(); _loadingList = false; });
    }
  }

  Future<void> _loadCompare() async {
    if (_idA == null || _idB == null || _idA == _idB) return;
    setState(() { _loadingCompare = true; _compareError = null; _compareData = null; });
    try {
      final data = await Api.compareRecordings(_idA!, _idB!);
      setState(() { _compareData = data; _loadingCompare = false; });
    } catch (e) {
      setState(() { _compareError = e.toString(); _loadingCompare = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: cs.background,
            floating: true,
            elevation: 0,
            leading: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: cs.onSurfaceVariant.withValues(alpha: 0.08)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(Icons.arrow_back_ios_new_rounded,
                    color: cs.onSurfaceVariant, size: 18),
              ),
            ),
            title: Text(
              'Сравнение записей',
              style: GoogleFonts.inter(
                color: cs.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          if (_loadingList)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_listError != null)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: AppColors.accentDanger, size: 48),
                      const SizedBox(height: 16),
                      Text(_listError!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                              color: cs.onSurfaceVariant, fontSize: 14)),
                      const SizedBox(height: 24),
                      GlassButton(
                        onTap: _loadList,
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
            )
          else if (_recordings.length < 2)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.compare_arrows_rounded,
                          color: cs.onSurfaceVariant, size: 56),
                      const SizedBox(height: 16),
                      Text(
                        'Нужно минимум 2 записи',
                        style: GoogleFonts.inter(
                          color: cs.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Сделай ещё несколько записей,\nчтобы сравнивать их между собой',
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
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Row(
                    children: [
                      Expanded(child: _Selector(
                        label: 'Запись A',
                        selectedId: _idA,
                        recordings: _recordings,
                        onChanged: (id) {
                          setState(() => _idA = id);
                          _loadCompare();
                        },
                        accentColor: AppColors.accentSuccess,
                        fmtDate: DateFormat.shortFromIso,
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _Selector(
                        label: 'Запись B',
                        selectedId: _idB,
                        recordings: _recordings,
                        onChanged: (id) {
                          setState(() => _idB = id);
                          _loadCompare();
                        },
                        accentColor: AppColors.accentBlue,
                        fmtDate: DateFormat.shortFromIso,
                      )),
                    ],
                  ),

                  const SizedBox(height: 20),

                  if (_loadingCompare)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_compareError != null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(_compareError!,
                            style: GoogleFonts.inter(
                                color: AppColors.accentDanger, fontSize: 13)),
                      ),
                    )
                  else if (_compareData != null) ...[
                    _buildCompareBody(context, _compareData!),
                  ] else if (_idA == _idB)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text('Выбери разные записи',
                            style: GoogleFonts.inter(
                                color: cs.onSurfaceVariant, fontSize: 13)),
                      ),
                    ),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCompareBody(BuildContext context, Map<String, dynamic> data) {
    final cs = Theme.of(context).colorScheme;
    final ra = data['recording_a'] as Map<String, dynamic>? ?? {};
    final rb = data['recording_b'] as Map<String, dynamic>? ?? {};
    final scoreA = (ra['score'] as num?)?.toDouble() ?? 0;
    final scoreB = (rb['score'] as num?)?.toDouble() ?? 0;
    final params = (data['parameters'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final radarKeys = ['parasites', 'pauses', 'tempo', 'lexical', 'syntax'];
    final radarNamesRu = {
      'parasites': 'Паразиты',
      'pauses': 'Паузы',
      'tempo': 'Темп',
      'lexical': 'Лексика',
      'syntax': 'Синтаксис',
    };

    List<SpeechParameter> buildRadarParams(double Function(String key) getScore) {
      return radarKeys.map((key) => SpeechParameter(
        name: key,
        nameRu: radarNamesRu[key] ?? key,
        score: getScore(key),
        icon: Icons.analytics_rounded,
      )).toList();
    }

    final paramsMap = <String, Map<String, dynamic>>{};
    for (final p in params) {
      final key = (p['key'] as String?) ?? '';
      if (key.isNotEmpty) paramsMap[key] = p;
    }
    final hasKeys = paramsMap.isNotEmpty;
    final radarA = buildRadarParams((key) {
      if (hasKeys) {
        return (paramsMap[key]?['score_a'] as num?)?.toDouble() ?? 0;
      }
      final idx = radarKeys.indexOf(key);
      if (idx < 0 || idx >= params.length) return 0;
      return (params[idx]['score_a'] as num?)?.toDouble() ?? 0;
    });
    final radarB = buildRadarParams((key) {
      if (hasKeys) {
        return (paramsMap[key]?['score_b'] as num?)?.toDouble() ?? 0;
      }
      final idx = radarKeys.indexOf(key);
      if (idx < 0 || idx >= params.length) return 0;
      return (params[idx]['score_b'] as num?)?.toDouble() ?? 0;
    });

    final diff = scoreB - scoreA;
    final diffPositive = diff >= 0;
    final diffColor = diff > 0
        ? AppColors.accentSuccess
        : diff < 0
            ? AppColors.accentDanger
            : AppColors.textSecondary;
    final diffStr = diff == 0 ? '=' : '${diff > 0 ? '+' : ''}${diff.toStringAsFixed(0)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassCard(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.accentSuccess.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Запись A',
                          style: GoogleFonts.inter(
                            color: AppColors.accentSuccess,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                  Expanded(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.accentBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Запись B',
                          style: GoogleFonts.inter(
                            color: AppColors.accentBlue,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ScoreCol(score: scoreA, color: AppColors.accentSuccess),
                  Container(
                    width: 60,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: diffColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: diffColor.withValues(alpha: 0.3)),
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                        diff > 0
                            ? Icons.trending_up_rounded
                            : diff < 0
                                ? Icons.trending_down_rounded
                                : Icons.remove_rounded,
                        color: diffColor,
                        size: 18,
                      ),
                      Text(
                        diffStr,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: diffColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                    ]),
                  ),
                  _ScoreCol(score: scoreB, color: AppColors.accentBlue),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                diffPositive && diff != 0
                    ? 'Запись B лучше на ${diff.abs().toStringAsFixed(0)} очков'
                    : diff != 0
                        ? 'Запись A лучше на ${diff.abs().toStringAsFixed(0)} очков'
                        : 'Результаты одинаковые',
                style: GoogleFonts.inter(
                  color: cs.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),
        if (radarA.any((p) => p.score > 0) || radarB.any((p) => p.score > 0)) ...[
          GlassCard(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Профиль речи',
                      style: GoogleFonts.inter(
                        color: cs.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Row(children: [
                      _RadarLegendDot(color: AppColors.accentSuccess, label: 'A'),
                      const SizedBox(width: 12),
                      _RadarLegendDot(color: AppColors.accentBlue, label: 'B'),
                    ]),
                  ],
                ),
                const SizedBox(height: 8),
                Center(
                  child: SpeechRadarWithNumbers(
                    parameters: radarA,
                    secondParameters: radarB,
                    size: 260,
                    showNumbers: false,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        Text(
          'По параметрам',
          style: GoogleFonts.inter(
            color: cs.onSurface,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),

        ...params.map((p) => _CompareParamCard(param: p)),
      ],
    );
  }
}

class _RadarLegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _RadarLegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 10, height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: GoogleFonts.inter(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    ]);
  }
}

class _Selector extends StatelessWidget {
  final String label;
  final int? selectedId;
  final List<Map<String, dynamic>> recordings;
  final ValueChanged<int> onChanged;
  final Color accentColor;
  final String Function(String?) fmtDate;

  const _Selector({
    required this.label,
    required this.selectedId,
    required this.recordings,
    required this.onChanged,
    required this.accentColor,
    required this.fmtDate,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderColor: accentColor.withValues(alpha: 0.3),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: accentColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButton<int>(
            value: selectedId,
            isExpanded: true,
            dropdownColor: Theme.of(context).colorScheme.surface,
            underline: const SizedBox(),
            style: GoogleFonts.inter(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 13,
            ),
            icon: Icon(Icons.keyboard_arrow_down_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant, size: 18),
            items: recordings.map((r) {
              final id = (r['id'] as num).toInt();
              final score = (r['score'] as num?)?.toInt() ?? 0;
              final date = fmtDate(r['created_at'] as String?);
              return DropdownMenuItem(
                value: id,
                child: Text('$date — $score б'),
              );
            }).toList(),
            onChanged: (v) { if (v != null) onChanged(v); },
          ),
        ],
      ),
    );
  }
}

class _ScoreCol extends StatelessWidget {
  final double score;
  final Color color;

  const _ScoreCol({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ScoreCircle(score: score, size: 90, animate: false),
        const SizedBox(height: 8),
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ],
    );
  }
}

class _CompareParamCard extends StatefulWidget {
  final Map<String, dynamic> param;
  const _CompareParamCard({required this.param});

  @override
  State<_CompareParamCard> createState() => _CompareParamCardState();
}

class _CompareParamCardState extends State<_CompareParamCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.param;
    final cs = Theme.of(context).colorScheme;
    final title = (p['title'] as String?) ?? '';
    final sa = (p['score_a'] as num?)?.toDouble() ?? 0;
    final sb = (p['score_b'] as num?)?.toDouble() ?? 0;
    final d = sb - sa;
    final dColor = d > 0
        ? AppColors.accentSuccess
        : d < 0
            ? AppColors.accentDanger
            : cs.onSurfaceVariant;
    final dStr = d == 0 ? '=' : '${d > 0 ? '+' : ''}${d.toStringAsFixed(0)}';

    final subA = (p['sub_scores_a'] as Map?)?.cast<String, dynamic>() ?? {};
    final subB = (p['sub_scores_b'] as Map?)?.cast<String, dynamic>() ?? {};
    final hasSubScores = subA.isNotEmpty || subB.isNotEmpty;
    final allKeys = {...subA.keys, ...subB.keys}.toList();
    final extraA = (p['extra_metrics_a'] as Map?)?.cast<String, dynamic>() ?? {};
    final extraB = (p['extra_metrics_b'] as Map?)?.cast<String, dynamic>() ?? {};
    final hasExtra = extraA.isNotEmpty || extraB.isNotEmpty;
    final allExtraKeys = {...extraA.keys, ...extraB.keys}.toList();
    final canExpand = hasSubScores || hasExtra;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.onSurfaceVariant.withValues(alpha: 0.12)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          onTap: canExpand ? () => setState(() => _expanded = !_expanded) : null,
          behavior: HitTestBehavior.opaque,
          child: Row(children: [
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  color: cs.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: dColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: dColor.withValues(alpha: 0.25)),
              ),
              child: Text(
                dStr,
                style: GoogleFonts.inter(
                  color: dColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (canExpand) ...[
              const SizedBox(width: 8),
              Icon(
                _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                color: cs.onSurfaceVariant,
                size: 20,
              ),
            ],
          ]),
        ),
        const SizedBox(height: 12),
        _CompareBar(label: 'A', score: sa, color: AppColors.accentSuccess),
        const SizedBox(height: 6),
        _CompareBar(label: 'B', score: sb, color: AppColors.accentBlue),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: _expanded && canExpand
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Divider(color: cs.onSurfaceVariant.withValues(alpha: 0.12), height: 1),
                      const SizedBox(height: 8),
                      if (hasSubScores) ...[
                        Row(children: [
                          Icon(Icons.tune_rounded,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.6), size: 13),
                          const SizedBox(width: 5),
                          Text('Из чего складывается оценка',
                              style: GoogleFonts.inter(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ]),
                        const SizedBox(height: 8),
                        ...allKeys.map((subKey) {
                          final label = subScoreLabels[subKey] ?? subKey;
                          final valA = (subA[subKey] as num?)?.toDouble() ?? 0;
                          final valB = (subB[subKey] as num?)?.toDouble() ?? 0;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(label,
                                    style: GoogleFonts.inter(
                                        color: cs.onSurfaceVariant, fontSize: 10)),
                                const SizedBox(height: 3),
                                Row(children: [
                                  SizedBox(width: 14,
                                      child: Text('A',
                                          style: GoogleFonts.inter(
                                              color: AppColors.accentSuccess,
                                              fontSize: 9, fontWeight: FontWeight.w700))),
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(3),
                                      child: LinearProgressIndicator(
                                        value: (valA / 100).clamp(0, 1),
                                        backgroundColor: cs.onSurfaceVariant.withValues(alpha: 0.10),
                                        valueColor: const AlwaysStoppedAnimation(AppColors.accentSuccess),
                                        minHeight: 5,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 26,
                                      child: Text('${valA.toInt()}',
                                          textAlign: TextAlign.right,
                                          style: GoogleFonts.inter(
                                              color: AppColors.scoreColor(valA),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700))),
                                ]),
                                const SizedBox(height: 3),
                                Row(children: [
                                  SizedBox(width: 14,
                                      child: Text('B',
                                          style: GoogleFonts.inter(
                                              color: AppColors.accentBlue,
                                              fontSize: 9, fontWeight: FontWeight.w700))),
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(3),
                                      child: LinearProgressIndicator(
                                        value: (valB / 100).clamp(0, 1),
                                        backgroundColor: cs.onSurfaceVariant.withValues(alpha: 0.10),
                                        valueColor: const AlwaysStoppedAnimation(AppColors.accentBlue),
                                        minHeight: 5,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 26,
                                      child: Text('${valB.toInt()}',
                                          textAlign: TextAlign.right,
                                          style: GoogleFonts.inter(
                                              color: AppColors.scoreColor(valB),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700))),
                                ]),
                              ],
                            ),
                          );
                        }),
                      ],
                      if (hasExtra) ...[
                        if (hasSubScores) const SizedBox(height: 4),
                        Row(children: [
                          Icon(Icons.bar_chart_rounded,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.6), size: 13),
                          const SizedBox(width: 5),
                          Text('Значения показателей',
                              style: GoogleFonts.inter(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ]),
                        const SizedBox(height: 8),
                        ...allExtraKeys.map((mKey) {
                          final vA = extraA[mKey]?.toString() ?? '—';
                          final vB = extraB[mKey]?.toString() ?? '—';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(children: [
                              Expanded(
                                flex: 3,
                                child: Text(mKey,
                                    style: GoogleFonts.inter(
                                        color: cs.onSurfaceVariant, fontSize: 10)),
                              ),
                              SizedBox(
                                width: 64,
                                child: Text(vA,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                        color: AppColors.accentSuccess,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600)),
                              ),
                              SizedBox(
                                width: 64,
                                child: Text(vB,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                        color: AppColors.accentBlue,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ]),
                          );
                        }),
                      ],
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ]),
    );
  }
}

class _CompareBar extends StatelessWidget {
  final String label;
  final double score;
  final Color color;

  const _CompareBar({
    required this.label,
    required this.score,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      SizedBox(
        width: 16,
        child: Text(label,
            style: GoogleFonts.inter(
                color: color, fontSize: 10, fontWeight: FontWeight.w700)),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: Stack(children: [
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          FractionallySizedBox(
            widthFactor: (score / 100).clamp(0.0, 1.0),
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ]),
      ),
      const SizedBox(width: 8),
      SizedBox(
        width: 28,
        child: Text(
          score.toInt().toString(),
          textAlign: TextAlign.right,
          style: GoogleFonts.inter(
            color: AppColors.scoreColor(score),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ]);
  }
}

