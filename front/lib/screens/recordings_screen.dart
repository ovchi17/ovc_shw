import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/colors.dart';
import '../services/api.dart';
import '../widgets/glass_card.dart';
import '../utils/formatters.dart';
import 'results_screen.dart';

class RecordingsScreen extends StatefulWidget {
  const RecordingsScreen({super.key});

  @override
  State<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends State<RecordingsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _recordings = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await Api.getRecordings(limit: 50);
      setState(() {
        _recordings = list.whereType<Map<String, dynamic>>().toList();
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            elevation: 0,
            leading: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.arrow_back_ios_new_rounded,
                    color: cs.onSurfaceVariant, size: 18),
              ),
            ),
            title: Text(
              'История записей',
              style: GoogleFonts.inter(
                color: cs.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
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
            )
          else if (_recordings.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.mic_none_rounded,
                        color: cs.onSurfaceVariant, size: 56),
                    const SizedBox(height: 16),
                    Text(
                      'Записей пока нет',
                      style: GoogleFonts.inter(
                        color: cs.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Сделай первую запись,\nчтобы она появилась здесь',
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
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _RecordingCard(
                    data: _recordings[i],
                    onTap: () => _openRecording(_recordings[i]),
                  ),
                  childCount: _recordings.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openRecording(Map<String, dynamic> data) async {
    final cs = Theme.of(context).colorScheme;
    final analysisId = data['analysis_id'] as int?;
    if (analysisId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Анализ ещё не готов',
              style: GoogleFonts.inter(color: cs.onSurface)),
          backgroundColor: cs.surface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    try {
      final result = await Api.getAnalysis(analysisId);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ResultsScreen(result: result)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: $e',
              style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: AppColors.accentDanger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }
}

class _RecordingCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _RecordingCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final score = (data['score'] as num?)?.toInt();
    final scoreChange = (data['score_change'] as num?)?.toInt();
    final status = (data['status'] as String?) ?? '';
    final isDone = status == 'done';
    final color = score != null ? AppColors.scoreColor(score.toDouble()) : cs.onSurfaceVariant;

    return GestureDetector(
      onTap: isDone ? onTap : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Row(
            children: [
              Container(width: 4, height: 72, color: isDone ? color : cs.onSurfaceVariant),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (data['title'] as String?) ?? 'Запись',
                              style: GoogleFonts.inter(
                                color: cs.onSurface,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  DateFormat.fullFromIso(data['created_at'] as String?),
                                  style: GoogleFonts.inter(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                                if (formatDurationSec(data['duration_sec'] as num?).isNotEmpty) ...[
                                  Text(
                                    '  ·  ${formatDurationSec(data['duration_sec'] as num?)}',
                                    style: GoogleFonts.inter(
                                      color: cs.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (!isDone) ...[
                              const SizedBox(height: 4),
                              Text(
                                status == 'processing' || status == 'transcribing' || status == 'analyzing'
                                    ? 'Обрабатывается...'
                                    : status == 'error'
                                        ? 'Ошибка анализа'
                                        : status,
                                style: GoogleFonts.inter(
                                  color: status == 'error'
                                      ? AppColors.accentDanger
                                      : AppColors.accentWarning,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (isDone && score != null) ...[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: color.withValues(alpha: 0.1),
                                border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
                              ),
                              child: Center(
                                child: Text(
                                  '$score',
                                  style: GoogleFonts.inter(
                                    color: color,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ),
                            if (scoreChange != null && scoreChange != 0) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (scoreChange > 0 ? AppColors.accentSuccess : AppColors.accentDanger).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      scoreChange > 0
                                          ? Icons.arrow_upward_rounded
                                          : Icons.arrow_downward_rounded,
                                      size: 9,
                                      color: scoreChange > 0
                                          ? AppColors.accentSuccess
                                          : AppColors.accentDanger,
                                    ),
                                    Text(
                                      '${scoreChange > 0 ? '+' : ''}$scoreChange',
                                      style: GoogleFonts.inter(
                                        color: scoreChange > 0
                                            ? AppColors.accentSuccess
                                            : AppColors.accentDanger,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.chevron_right_rounded,
                            color: cs.onSurfaceVariant, size: 18),
                        const SizedBox(width: 8),
                      ] else if (!isDone && status != 'error') ...[
                        SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(AppColors.accentWarning),
                          ),
                        ),
                        const SizedBox(width: 16),
                      ] else
                        const SizedBox(width: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
