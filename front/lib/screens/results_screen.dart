import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import '../core/colors.dart';
import '../models/models.dart';
import '../services/api.dart';
import '../widgets/glass_card.dart';
import '../widgets/score_circle.dart';
import '../widgets/radar_chart_widget.dart';
import '../widgets/charts/pause_histogram.dart';
import '../core/constants.dart';
import '../core/param_info.dart';
import '../utils/formatters.dart';
import 'tips_screen.dart';

class ResultsScreen extends StatefulWidget {
  final AnalysisResult result;

  const ResultsScreen({super.key, required this.result});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceCtrl;
  late final Animation<double> _entranceAnim;

  final AudioPlayer _player = AudioPlayer();
  final List<StreamSubscription> _playerSubs = [];
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _hasAudio = false;
  String? _localAudioPath;
  String? _selectedFiller;


  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
        vsync: this, duration: kAnimDurationLong);
    _entranceAnim =
        CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic);
    _entranceCtrl.forward();
    _initPlayer();
  }
  Future<void> _initPlayer() async {
    final raw = widget.result.audioPath;
    if (raw.isEmpty) return;

    final String localPath;
    if (raw.startsWith('http')) {
      final downloaded = await Api.downloadAudioToTemp(raw);
      if (downloaded == null || !mounted) return;
      localPath = downloaded;
    } else {
      if (!File(raw).existsSync()) return;
      localPath = raw;
    }
    _localAudioPath = localPath;
    await _player.setAudioContext(AudioContext(
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: const {},
      ),
    ));
    await _player.setVolume(1.0);
    _player.setReleaseMode(ReleaseMode.stop);
    _playerSubs.addAll([
      _player.onDurationChanged.listen((d) {
        if (mounted) setState(() => _duration = d);
      }),
      _player.onPositionChanged.listen((p) {
        if (mounted) setState(() => _position = p);
      }),
      _player.onPlayerStateChanged.listen((s) {
        if (mounted) setState(() => _isPlaying = s == PlayerState.playing);
      }),
      _player.onPlayerComplete.listen((_) {
        if (mounted) setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }),
    ]);

    await _player.setSource(DeviceFileSource(localPath));
    if (mounted) setState(() => _hasAudio = true);
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      final path = _localAudioPath;
      if (path == null) return;
      await _player.play(DeviceFileSource(path));
    }
  }

  Future<void> _seekTo(Duration pos) async {
    final path = _localAudioPath;
    if (path == null) return;
    if (!_isPlaying) {
      await _player.play(DeviceFileSource(path));
    }
    await _player.seek(pos);
  }

  Future<void> _stopPlay() async {
    await _player.pause();
  }

  @override
  void dispose() {
    for (final s in _playerSubs) {
      s.cancel();
    }
    _player.dispose();
    _entranceCtrl.dispose();
    super.dispose();
  }

  late final Map<String, List<TimecodeProblem>> _fillerGroups = (() {
    final Map<String, List<TimecodeProblem>> groups = {};
    for (final tc
    in widget.result.timecodes.where((t) => t.type == kTimecodeTypeParasite)) {
      final matches = RegExp(r'«([^»]+)»').allMatches(tc.description);
      if (matches.isEmpty) {
        groups.putIfAbsent(tc.description, () => []).add(tc);
      } else {
        for (final m in matches) {
          final word = m.group(1) ?? '';
          if (word.isNotEmpty) {
            groups.putIfAbsent(word, () => []).add(tc);
          }
        }
      }
    }
    return groups;
  })();

  int get _briefPauseCount => widget.result.briefPauseCount;
  int get _mediumPauseCount => widget.result.mediumPauseCount;
  int get _longPauseCount => widget.result.longPauseCount;

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final hasParasiteTimecodes =
        result.timecodes.any((t) => t.type == kTimecodeTypeParasite);
    final pauseCount =
        _briefPauseCount + _mediumPauseCount + _longPauseCount;

    return Scaffold(
      body: Stack(children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 300,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.5),
                radius: 0.85,
                colors: [
                  result.scoreColor.withValues(alpha: 0.14),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _AppBar(
              result: result,
              onBack: () => Navigator.of(context).pop(),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 48),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  FadeTransition(
                    opacity: _entranceAnim,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0, 0.18),
                        end: Offset.zero,
                      ).animate(_entranceAnim),
                      child: _HeroSection(result: result),
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (_hasAudio) ...[
                    _PlayerCard(
                      isPlaying: _isPlaying,
                      position: _position,
                      duration: _duration,
                      timecodes: result.timecodes,
                      selectedFiller: _selectedFiller,
                      onToggle: _togglePlay,
                      onSeek: _seekTo,
                    ),
                    const SizedBox(height: 14),
                  ],

                  if (pauseCount > 0) ...[
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Label('Распределение пауз'),
                          const SizedBox(height: 16),
                          PauseHistogram(
                            brief: _briefPauseCount,
                            medium: _mediumPauseCount,
                            long: _longPauseCount,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  if (result.fillerDetails.isNotEmpty ||
                      hasParasiteTimecodes) ...[
                    _FillerCard(
                      fillerDetails: result.fillerDetails,
                      timecodes: result.timecodes
                          .where((t) => t.type == kTimecodeTypeParasite)
                          .toList(),
                      totalFillers: result.totalFillers,
                      fillerPct: result.fillerPct,
                      selected: _selectedFiller,
                      position: _position,
                      hasAudio: _hasAudio,
                      onSelect: (word) => setState(() {
                        _selectedFiller =
                            _selectedFiller == word ? null : word;
                      }),
                      onSeek: _hasAudio ? _seekTo : null,
                    ),
                    const SizedBox(height: 14),
                  ],

                  GlassCard(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Label('Профиль речи'),
                        const SizedBox(height: 16),
                        Center(
                          child: SpeechRadarWithNumbers(
                            parameters: result.parameters,
                            size: 260,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (result.transcript.isNotEmpty) ...[
                    _TranscriptButton(
                      transcript: result.transcript,
                      fillerGroups: _fillerGroups,
                      onSeek: _hasAudio ? _seekTo : null,
                    ),
                    const SizedBox(height: 14),
                  ],

                  _TopRepeatedWordsCard(parameters: result.parameters),

                  const _Label('Детальный разбор'),
                  const SizedBox(height: 10),
                  ...result.parameters.map((param) {
                    final timecodeType = param.name == 'parasites'
                        ? kTimecodeTypeParasite
                        : param.name == 'pauses'
                            ? kTimecodeTypePause
                            : '';
                    final paramTimecodes = timecodeType.isEmpty
                        ? const <TimecodeProblem>[]
                        : result.timecodes
                            .where((t) => t.type == timecodeType)
                            .toList();
                    return _ParamCard(
                      param: param,
                      timecodes: paramTimecodes,
                      isPlaying: _isPlaying,
                      onSeek: _hasAudio ? _seekTo : null,
                      onStop: _hasAudio ? _stopPlay : null,
                    );
                  }),

                  const SizedBox(height: 14),
                  if (result.parameters.isNotEmpty)
                    _AdviceCard(parameters: result.parameters),
                ]),
              ),
            ),
          ],
        ),
      ]),
    );
  }
}

/// Карточка «Топ-10 самых частых слов» из параметра lexical.
/// Раньше была инлайн-Builder'ом в build(), вынесено в отдельный виджет
/// для читаемости.
class _TopRepeatedWordsCard extends StatelessWidget {
  final List<SpeechParameter> parameters;
  const _TopRepeatedWordsCard({required this.parameters});

  @override
  Widget build(BuildContext context) {
    final lexical = parameters.firstWhere(
      (p) => p.name == 'lexical',
      orElse: () => const SpeechParameter(
        name: '',
        nameRu: '',
        score: 0,
        icon: Icons.text_fields_rounded,
      ),
    );
    if (lexical.name.isEmpty) return const SizedBox.shrink();

    final words = (lexical.rawData['top_repeated_words'] as List?)
            ?.map((w) => w.toString())
            .where((w) => w.isNotEmpty)
            .take(10)
            .toList() ??
        const <String>[];
    if (words.isEmpty) return const SizedBox.shrink();

    final color = lexical.color;
    final colors = Theme.of(context).colorScheme;

    return Column(children: [
      GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.text_fields_rounded, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                'Топ-10 самых частых слов',
                style: GoogleFonts.inter(
                  color: colors.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: words.asMap().entries.map((entry) {
                final rank = entry.key + 1;
                final word = entry.value;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withValues(alpha: 0.2)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                      '$rank.',
                      style: GoogleFonts.inter(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      word,
                      style: GoogleFonts.inter(
                        color: colors.onSurface,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ]),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
    ]);
  }
}

class _AppBar extends StatelessWidget {
  final AnalysisResult result;
  final VoidCallback onBack;

  const _AppBar({required this.result, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SliverAppBar(
      pinned: true,
      backgroundColor: cs.background.withValues(alpha: 0.92),
      elevation: 0,
      leading: GestureDetector(
        onTap: onBack,
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.arrow_back_ios_new_rounded,
              color: cs.onSurfaceVariant, size: 18),
        ),
      ),
      title: Text('Результаты',
          style: GoogleFonts.inter(
              color: cs.onSurface,
              fontSize: 17,
              fontWeight: FontWeight.w600)),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
          child: Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(8)),
            child: Text(
              DateFormat.dayMonthYear(result.date),
              style: GoogleFonts.inter(
                  color: cs.onSurfaceVariant, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

}

class _HeroSection extends StatelessWidget {
  final AnalysisResult result;

  const _HeroSection({required this.result});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ScoreCircle(score: result.totalScore, size: 160),
      const SizedBox(height: 10),
      ScoreLabelPill(score: result.totalScore),
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          if (result.speechRateWpm > 0)
            _StatChip(
              icon: Icons.speed_rounded,
              label: '${result.speechRateWpm.toInt()} сл/мин',
              color: AppColors.accentBlue,
            ),
          if (result.ptr > 0)
            _StatChip(
              icon: Icons.mic_rounded,
              label: 'Речь ${result.ptr.toStringAsFixed(0)}% времени',
              color: AppColors.accentSuccess,
            ),
          if (result.totalFillers > 0)
            _StatChip(
              icon: Icons.record_voice_over_rounded,
              label: '${result.totalFillers} слов-паразитов',
              color: AppColors.accentDanger,
            ),
          if (result.longPauseCount > 0)
            _StatChip(
              icon: Icons.pause_rounded,
              label: '${result.longPauseCount} длинных пауз',
              color: AppColors.accentWarning,
            ),
        ],
      ),
    ]);
  }
}


class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) =>
      Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.25))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(label,
              style: GoogleFonts.inter(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ]),
      );
}
class _PlayerCard extends StatelessWidget {
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final List<TimecodeProblem> timecodes;
  final String? selectedFiller;
  final VoidCallback onToggle;
  final ValueChanged<Duration> onSeek;

  const _PlayerCard({
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.timecodes,
    required this.selectedFiller,
    required this.onToggle,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    final total = duration.inMilliseconds.toDouble();
    final cur = position.inMilliseconds.toDouble().clamp(
        0.0, total > 0 ? total : 1.0);

    return GlassCard(
      borderColor: AppColors.accentSuccess.withValues(alpha: 0.2),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          GestureDetector(
            onTap: onToggle,
            child: Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.accentSuccess, AppColors.accentBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Ваша запись',
                  style: GoogleFonts.inter(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 1),
              Text('${position.mmss}  /  ${duration.mmss}',
                  style: GoogleFonts.inter(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  )),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        _ProgressBar(
          progress: total > 0 ? cur / total : 0,
          timecodes: timecodes,
          selectedFiller: selectedFiller,
          duration: duration,
          onSeek: (ratio) =>
              onSeek(Duration(milliseconds: (ratio * total).round())),
        ),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          _dot(AppColors.accentDanger), const SizedBox(width: 4),
          Text('паразит  ', style: GoogleFonts.inter(
              color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10)),
          _dot(AppColors.accentWarning), const SizedBox(width: 4),
          Text('пауза', style: GoogleFonts.inter(
              color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10)),
        ]),
      ]),
    );
  }

  Widget _dot(Color c) =>
      Container(
          width: 7, height: 7,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle));

}

class _ProgressBar extends StatelessWidget {
  final double progress;
  final List<TimecodeProblem> timecodes;
  final String? selectedFiller;
  final Duration duration;
  final ValueChanged<double> onSeek;

  const _ProgressBar({
    required this.progress,
    required this.timecodes,
    required this.selectedFiller,
    required this.duration,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) {
        final box = context.findRenderObject() as RenderBox;
        onSeek((d.localPosition.dx / box.size.width).clamp(0.0, 1.0));
      },
      onHorizontalDragUpdate: (d) {
        final box = context.findRenderObject() as RenderBox;
        onSeek((d.localPosition.dx / box.size.width).clamp(0.0, 1.0));
      },
      child: SizedBox(
        height: 36,
        child: CustomPaint(
          painter: _BarPainter(
            progress: progress,
            timecodes: timecodes,
            selectedFiller: selectedFiller,
            duration: duration,
            trackColor: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
          ),
          size: const Size(double.infinity, 36),
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  final double progress;
  final List<TimecodeProblem> timecodes;
  final String? selectedFiller;
  final Duration duration;

  final Color trackColor;

  const _BarPainter({required this.progress,
    required this.timecodes,
    required this.selectedFiller,
    required this.duration,
    required this.trackColor});

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    const trackHeight = 4.0;
    final cornerRadius = Radius.circular(trackHeight);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, centerY - trackHeight / 2, size.width, trackHeight),
        cornerRadius,
      ),
      Paint()..color = trackColor,
    );

    final playedWidth = (size.width * progress).clamp(0.0, size.width);
    if (playedWidth > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, centerY - trackHeight / 2, playedWidth, trackHeight),
          cornerRadius,
        ),
        Paint()
          ..shader = const LinearGradient(
            colors: [AppColors.accentSuccess, AppColors.accentBlue],
          ).createShader(Rect.fromLTWH(0, 0, size.width, trackHeight)),
      );
    }

    final totalMs = duration.inMilliseconds.toDouble();
    if (totalMs > 0) {
      for (final tc in timecodes) {
        final ratio = tc.start.inMilliseconds / totalMs;
        final x = (ratio * size.width).clamp(0.0, size.width);
        final isParasite = tc.type == kTimecodeTypeParasite;
        final markerColor = isParasite
            ? AppColors.accentDanger
            : AppColors.accentWarning;

        final hasFilterActive = isParasite && selectedFiller != null;
        final match = RegExp(r'«([^»]+)»').firstMatch(tc.description);
        final word = match?.group(1) ?? '';
        final highlight = hasFilterActive && word == selectedFiller;

        canvas.drawCircle(
          Offset(x, centerY),
          highlight ? 7 : 5,
          Paint()..color = markerColor.withValues(alpha: highlight ? 1.0 : 0.7),
        );
        canvas.drawCircle(
          Offset(x, centerY),
          highlight ? 3 : 2,
          Paint()..color = Colors.white.withValues(alpha: 0.9),
        );
      }
    }
    final thumbX = (size.width * progress).clamp(0.0, size.width);
    canvas.drawCircle(Offset(thumbX, centerY), 9, Paint()..color = Colors.white);
    canvas.drawCircle(
      Offset(thumbX, centerY),
      5.5,
      Paint()..color = AppColors.accentSuccess,
    );
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.progress != progress ||
      old.duration != duration ||
      old.selectedFiller != selectedFiller ||
      old.trackColor != trackColor;
}

class _FillerCard extends StatefulWidget {
  final Map<String, int> fillerDetails;
  final List<TimecodeProblem> timecodes;
  final int totalFillers;
  final double fillerPct;
  final String? selected;
  final Duration position;
  final bool hasAudio;
  final ValueChanged<String> onSelect;
  final ValueChanged<Duration>? onSeek;

  const _FillerCard({
    required this.fillerDetails,
    required this.timecodes,
    required this.totalFillers,
    this.fillerPct = 0,
    required this.selected,
    required this.position,
    required this.hasAudio,
    required this.onSelect,
    this.onSeek,
  });

  @override
  State<_FillerCard> createState() => _FillerCardState();
}

class _FillerCardState extends State<_FillerCard> {
  @override
  Widget build(BuildContext context) {
    final allFillers = <String, int>{...widget.fillerDetails};
    for (final tc in widget.timecodes.where((t) => t.type == kTimecodeTypeParasite)) {
      final word = _extractWord(tc.description);
      if (word.isNotEmpty && !allFillers.containsKey(word)) {
        allFillers[word] = (allFillers[word] ?? 0) + 1;
      }
    }
    final actualTotal = allFillers.values.fold(0, (s, v) => s + v);
    final sorted = allFillers.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return GlassCard(
      borderColor: AppColors.accentDanger.withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentDanger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.record_voice_over_rounded,
                    color: AppColors.accentDanger, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Label('Слова-паразиты'),
                    Text(
                      actualTotal > 0
                          ? widget.fillerPct > 0
                              ? '$actualTotal употреблений · ${widget.fillerPct.toStringAsFixed(1)}% речи'
                              : '$actualTotal употреблений'
                          : 'паразитов не обнаружено',
                      style: GoogleFonts.inter(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: sorted.map((e) {
              final word = e.key;
              final count = e.value;
              final isSelected = widget.selected == word;

              return GestureDetector(
                onTap: () => widget.onSelect(word),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.accentDanger.withValues(alpha: 0.18)
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.accentDanger
                          : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '«$word»',
                        style: GoogleFonts.inter(
                          color: isSelected ? AppColors.accentDanger : Theme.of(context).colorScheme.onSurface,
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.accentDanger.withValues(alpha: isSelected ? 0.25 : 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: GoogleFonts.inter(
                            color: AppColors.accentDanger,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          if (widget.selected != null)
            ..._buildSelectedFillerTimecodes(),
        ],
      ),
    );
  }

  List<Widget> _buildSelectedFillerTimecodes() {
    final selectedTc = widget.timecodes
        .where((t) => t.type == kTimecodeTypeParasite && _extractWord(t.description) == widget.selected)
        .toList();

    if (selectedTc.isEmpty) return [];

    return [
      const SizedBox(height: 14),
      Divider(color: AppColors.neutral.withValues(alpha: 0.15), height: 1),
      const SizedBox(height: 10),
      Text(
        'Вхождения «${widget.selected}»',
        style: GoogleFonts.inter(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: selectedTc.map((tc) {
          final active = widget.position >= tc.start && widget.position <= tc.end + kTimecodeHighlightGracePeriod;
          return GestureDetector(
            onTap: widget.onSeek != null ? () => widget.onSeek!(tc.start) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: active ? AppColors.accentDanger.withValues(alpha: 0.2) : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: active ? AppColors.accentDanger : AppColors.neutral.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.onSeek != null)
                    Icon(Icons.play_arrow_rounded, color: AppColors.accentDanger.withValues(alpha: 0.8), size: 14),
                  const SizedBox(width: 4),
                  Text(
                    tc.start.mmss,
                    style: GoogleFonts.inter(
                      color: active ? AppColors.accentDanger : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    ];
  }

  String _extractWord(String description) {
    final match = RegExp(r'«([^»]+)»').firstMatch(description);
    return match?.group(1) ?? description.trim();
  }

}
class _TranscriptButton extends StatelessWidget {
  final String transcript;
  final Map<String, List<TimecodeProblem>> fillerGroups;
  final ValueChanged<Duration>? onSeek;

  const _TranscriptButton({required this.transcript,
    required this.fillerGroups,
    this.onSeek});

  void _open(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _TranscriptModal(
            transcript: transcript,
            fillerGroups: fillerGroups,
            onSeek: onSeek,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wordCount = transcript
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => !w.startsWith('[LP:') && !w.startsWith('[MP:'))
        .length;
    return GlassCard(
      onTap: () => _open(context),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
              color: AppColors.accentBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.text_snippet_outlined,
              color: AppColors.accentBlue, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _Label('Транскрипт'),
            Text('$wordCount слов — нажми чтобы прочитать',
                style: GoogleFonts.inter(
                    color: AppColors.textSecondary, fontSize: 12)),
          ]),
        ),
        const Icon(Icons.open_in_new_rounded,
            color: AppColors.textSecondary, size: 18),
      ]),
    );
  }
}

class _TranscriptModal extends StatelessWidget {
  final String transcript;
  final Map<String, List<TimecodeProblem>> fillerGroups;
  final ValueChanged<Duration>? onSeek;

  const _TranscriptModal({required this.transcript,
    required this.fillerGroups,
    this.onSeek});

  @override
  Widget build(BuildContext context) {
    final fillerWords = fillerGroups.keys.toSet();
    final allTokens = transcript.split(' ');
    final words = allTokens;
    final wordCount = allTokens
        .where((w) => !w.startsWith('[LP:') && !w.startsWith('[MP:'))
        .length;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      snap: true,
      snapSizes: const [0.5, 0.75, 0.95],
      builder: (ctx, ctrl) {
          final cs = Theme.of(ctx).colorScheme;
          return Container(
            decoration: BoxDecoration(
              color: cs.background,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24)),
              border: Border.all(color: cs.surface),
            ),
            child: Column(children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  Text('Транскрипт',
                      style: GoogleFonts.inter(
                          color: cs.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    _LegendBadge(label: 'паразит', color: AppColors.accentDanger),
                    const SizedBox(width: 6),
                    _LegendBadge(label: 'пауза', color: AppColors.accentWarning),
                  ]),
                ]),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  '$wordCount слов',
                  style: GoogleFonts.inter(
                      color: cs.onSurfaceVariant, fontSize: 13),
                ),
              ),
              Divider(
                  color: cs.surface,
                  height: 20,
                  thickness: 1),
              Expanded(
                child: ListView(
                  controller: ctrl,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  children: [
                    _HighlightedText(
                        words: words, fillerWords: fillerWords),
                  ],
                ),
              ),
            ]),
          );
        },
    );
  }
}

class _LegendBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _LegendBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.3))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 7, height: 7,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 4),
      Text(label,
          style: GoogleFonts.inter(color: color, fontSize: 10)),
    ]),
  );
}

class _HighlightedText extends StatelessWidget {
  final List<String> words;
  final Set<String> fillerWords;

  const _HighlightedText({required this.words, required this.fillerWords});

  static bool _isPauseLong(String w) => w.startsWith('[LP:');
  static bool _isPauseMedium(String w) => w.startsWith('[MP:');
  static bool _isPause(String w) => _isPauseLong(w) || _isPauseMedium(w);

  static double _parseDur(String token) {
    final m = RegExp(r'\[(?:LP|MP):(\d+\.?\d*)\]').firstMatch(token);
    return m != null ? double.tryParse(m.group(1) ?? '') ?? 0.0 : 0.0;
  }

  static String _clean(String word) =>
      word.toLowerCase().replaceAll(RegExp(r'[^а-яёa-z]'), '');

  InlineSpan _pauseSpan(BuildContext context, String w) {
    final dur = _parseDur(w);
    final isLong = _isPauseLong(w);
    final color = isLong ? AppColors.accentWarning : AppColors.accentBlue;
    final label = isLong
        ? ' ${dur.toStringAsFixed(1)}с'
        : '· · · ${dur.toStringAsFixed(1)}с';
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
              fontSize: 10, color: color, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  TextSpan _wordSpan(BuildContext context, String text, bool isFiller) =>
      TextSpan(
        text: '$text ',
        style: GoogleFonts.inter(
          fontSize: 15,
          height: 1.8,
          color: isFiller
              ? AppColors.accentDanger
              : Theme.of(context).colorScheme.onSurface,
          fontWeight: isFiller ? FontWeight.w700 : FontWeight.w400,
          backgroundColor:
              isFiller ? AppColors.accentDanger.withValues(alpha: 0.10) : null,
        ),
      );

  @override
  Widget build(BuildContext context) {
    // Sort fillers: longest (multi-word) first so we match greedily.
    final sortedFillers = fillerWords.toList()
      ..sort((a, b) {
        final diff = b.split(' ').length.compareTo(a.split(' ').length);
        return diff != 0 ? diff : a.compareTo(b);
      });
    final singleFillers =
        fillerWords.map((f) => f.toLowerCase()).toSet();

    final spans = <InlineSpan>[];
    int i = 0;
    while (i < words.length) {
      final w = words[i];

      if (_isPause(w)) {
        spans.add(_pauseSpan(context, w));
        spans.add(const TextSpan(text: ' '));
        i++;
        continue;
      }

      // Try multi-word fillers (2+ words), longest first.
      bool matched = false;
      for (final filler in sortedFillers) {
        final parts = filler.toLowerCase().split(' ');
        if (parts.length < 2) break; // past multi-word fillers

        // Collect the next parts.length non-pause word indices.
        final indices = <int>[];
        for (int j = i; j < words.length && indices.length < parts.length; j++) {
          if (!_isPause(words[j])) indices.add(j);
        }
        if (indices.length < parts.length) continue;

        // Check all parts match.
        bool ok = true;
        for (int k = 0; k < parts.length; k++) {
          if (_clean(words[indices[k]]) != parts[k]) {
            ok = false;
            break;
          }
        }
        if (!ok) continue;

        // Emit everything between i and last matched index, preserving
        // pause tokens between the filler words.
        final lastIdx = indices.last;
        final fillerTokens = <String>[];
        for (int j = i; j <= lastIdx; j++) {
          if (_isPause(words[j])) {
            spans.add(_pauseSpan(context, words[j]));
            spans.add(const TextSpan(text: ' '));
          } else {
            fillerTokens.add(words[j]);
          }
        }
        spans.add(_wordSpan(context, fillerTokens.join(' '), true));
        i = lastIdx + 1;
        matched = true;
        break;
      }
      if (matched) continue;

      // Single-word check.
      final isFiller = singleFillers.contains(_clean(w));
      spans.add(_wordSpan(context, w, isFiller));
      i++;
    }
    return Text.rich(TextSpan(children: spans));
  }
}

class _ParamCard extends StatefulWidget {
  final SpeechParameter param;
  final List<TimecodeProblem> timecodes;
  final ValueChanged<Duration>? onSeek;
  final bool isPlaying;
  final VoidCallback? onStop;

  const _ParamCard({
    required this.param,
    this.timecodes = const [],
    this.onSeek,
    this.isPlaying = false,
    this.onStop,
  });

  @override
  State<_ParamCard> createState() => _ParamCardState();
}

class _ParamCardState extends State<_ParamCard> {
  bool _open = false;

  void _showInfo(BuildContext context) {
    final info = paramInfoMap[widget.param.name];
    if (info == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ParamInfoSheet(info: info, score: widget.param.score),
    );
  }

  @override
  Widget build(BuildContext context) {
    final param = widget.param;
    final cs = Theme.of(context).colorScheme;
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 8),
      onTap: () => setState(() => _open = !_open),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
                color: param.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(param.icon, color: param.color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(param.nameRu,
                      style: GoogleFonts.inter(
                          color: cs.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                ),
                if (paramInfoMap.containsKey(param.name))
                  GestureDetector(
                    onTap: () => _showInfo(context),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.info_outline_rounded,
                          color: cs.onSurfaceVariant, size: 14),
                    ),
                  ),
              ]),
              const SizedBox(height: 5),
              ScoreBar(score: param.score),
            ]),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: param.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8)),
            child: Text(
              '${param.score.toInt()}',
              style: GoogleFonts.inter(
                  color: param.color,
                  fontSize: 13,
                  fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            _open
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            color: cs.onSurfaceVariant,
            size: 18,
          ),
        ]),
        AnimatedSize(
          duration: kAnimDurationShort,
          curve: Curves.easeInOut,
          child: _open
              ? Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.15),
                      height: 1),
                  const SizedBox(height: 10),
                  if (param.subScores.isNotEmpty)
                    _SubScoresSection(
                      paramName: param.name,
                      subScores: param.subScores,
                      rawData: param.rawData,
                      color: param.color,
                    ),
                  if (widget.timecodes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Divider(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.12),
                        height: 1),
                    const SizedBox(height: 10),
                    Row(children: [
                      Icon(Icons.timer_outlined,
                          color: param.color.withValues(alpha: 0.7), size: 13),
                      const SizedBox(width: 5),
                      Text(
                        'Моменты в записи',
                        style: GoogleFonts.inter(
                            color: cs.onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    ...widget.timecodes.take(15).map((tc) {
                      final start = tc.start;
                      final canPlay = widget.onSeek != null;
                      return GestureDetector(
                        onTap: canPlay ? () {
                          if (widget.isPlaying) {
                            widget.onStop?.call();
                          } else {
                            widget.onSeek!(start);
                          }
                        } : null,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: param.color.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                                color: param.color.withValues(alpha: 0.2)),
                          ),
                          child: Row(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: param.color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                  mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.play_arrow_rounded,
                                    color: param.color, size: 11),
                                const SizedBox(width: 2),
                                Text(
                                  start.mmss,
                                  style: GoogleFonts.inter(
                                    color: param.color,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                                ),
                              ]),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                tc.description.isNotEmpty
                                    ? tc.description
                                    : '—',
                                style: GoogleFonts.inter(
                                  color: cs.onSurface,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!canPlay)
                              Icon(Icons.lock_outline_rounded,
                                  color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                                  size: 13),
                          ]),
                        ),
                      );
                    }),
                  ],
                  if (param.topIssue.isEmpty && param.extraMetrics.isEmpty &&
                      widget.timecodes.isEmpty)
                    Text('Всё в порядке — продолжай!',
                        style: GoogleFonts.inter(
                            color: AppColors.accentSuccess,
                            fontSize: 13,
                            fontStyle: FontStyle.italic)),
                ]),
          )
              : const SizedBox.shrink(),
        ),
      ]),
    );
  }
}
class _MetricSpec {
  final String? scoreKey;
  final String label;
  final String rawKey;
  final String unit;
  final int decimals;
  const _MetricSpec(this.scoreKey, this.label, this.rawKey, this.unit,
      [this.decimals = 1]);
}

const _specsByParam = <String, List<_MetricSpec>>{
  'parasites': [
    _MetricSpec('score_filler_proc', 'Доля слов-паразитов', 'filler_pct', '%', 1),
    _MetricSpec('score_density', 'Эпизодов паразитов в минуту', 'filler_density', '/мин', 1),
    _MetricSpec('score_unique', 'Разных типов паразитов', 'unique_types', 'шт.', 0),
    _MetricSpec('score_consecutive', 'Максимальная серия подряд', 'max_consecutive', 'шт.', 0),
  ],
  'pauses': [
    _MetricSpec('score_ptr', 'Доля времени говорения (PTR)', 'ptr', '%', 0),
    _MetricSpec('score_long_pct', 'Длинные паузы (>1 с)', 'long_pause_pct', '% времени', 1),
    _MetricSpec('score_mlr', 'Средняя длина речевого такта (MLR)', 'mlr', 'слов', 1),
    _MetricSpec('score_filled', 'Заполненных пауз', 'filled_rate', '/100 сл', 1),
  ],
  'tempo': [
    _MetricSpec('score_cv', 'Стабильность темпа (CV)', 'window_cv', '', 2),
    _MetricSpec('score_speech_rate', 'Темп речи', 'speech_rate', 'слов/мин', 0),
    _MetricSpec('score_articulation_rate', 'Артикуляционная скорость', 'articulation_rate', 'слов/мин говорения', 0),
  ],
  'lexical': [
    _MetricSpec('score_mattr', 'Локальное разнообразие (MATTR)', 'mattr', '', 2),
    _MetricSpec('score_mtld', 'Глобальное разнообразие (MTLD)', 'mtld', '', 1),
    _MetricSpec('score_top_repeat_pct', 'Доля самых частых слов (Top Repeat Perc)', 'top_repeat_pct', '%', 1),
  ],
  'syntax': [
    _MetricSpec('score_mean_utterance_length', 'Средняя длина высказывания', 'mean_utterance_length', 'слов', 1),
    _MetricSpec('score_embedding_depth', 'Синтаксическая вложенность', 'embedding_depth', 'уровни', 1),
    _MetricSpec('score_mean_dep_distance', 'Среднее расстояние зависимости (MDD)', 'mean_dependency_distance', '', 2),
    _MetricSpec('score_clauses_per_sentence', 'Клауз на предложение', 'clauses_per_sentence', '', 2),
    _MetricSpec('score_complex_sentences_ratio', 'Сложноподчинённые предложения', 'complex_sentences_ratio', '%', 0),
  ],
};

class _SubScoresSection extends StatelessWidget {
  final String paramName;
  final Map<String, double> subScores;
  final Map<String, dynamic> rawData;
  final Color color;

  const _SubScoresSection({
    required this.paramName,
    required this.subScores,
    required this.rawData,
    required this.color,
  });

  String? _fmtValue(_MetricSpec spec) {
    final raw = rawData[spec.rawKey];
    if (raw == null) return null;
    final n = (raw as num?)?.toDouble();
    if (n == null) return null;
    final s = spec.decimals == 0
        ? '${n.toInt()}'
        : n.toStringAsFixed(spec.decimals);
    return spec.unit.isEmpty ? s : '$s ${spec.unit}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final specs = _specsByParam[paramName] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: cs.onSurfaceVariant.withValues(alpha: 0.12), height: 1),
        const SizedBox(height: 10),
        ...specs.map((spec) {
          final displayVal = _fmtValue(spec);
          final hasProgressBar = spec.scoreKey != null;
          double score = 0.0;
          Color scoreColor = color;
          if (hasProgressBar) {
            score = (subScores[spec.scoreKey!] ?? 0.0).clamp(0.0, 100.0);
            scoreColor = AppColors.scoreColor(score);
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        spec.label,
                        style: GoogleFonts.inter(
                            color: cs.onSurfaceVariant, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (displayVal != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        displayVal,
                        style: GoogleFonts.inter(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ],
                ),
                if (hasProgressBar) ...[
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: score / 100,
                      backgroundColor: cs.onSurfaceVariant.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation(scoreColor),
                      minHeight: 5,
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

}
class _AdviceCard extends StatelessWidget {
  final List<SpeechParameter> parameters;

  const _AdviceCard({required this.parameters});

  @override
  Widget build(BuildContext context) {
    final worst = parameters.reduce((a, b) => a.score < b.score ? a : b);
    final info = paramInfoMap[worst.name];
    final adviceText = info != null
        ? info.adviceForScore(worst.score)
        : 'Продолжай практиковаться — результаты улучшаются!';
    final cs = Theme.of(context).colorScheme;

    return GlassCard(
      borderColor: AppColors.accentWarning.withValues(alpha: 0.25),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: AppColors.accentWarning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.tips_and_updates_rounded,
                color: AppColors.accentWarning, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Фокус следующей тренировки',
                  style: GoogleFonts.inter(
                      color: AppColors.accentWarning,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3)),
              const SizedBox(height: 6),
              Text(
                adviceText,
                style: GoogleFonts.inter(
                    color: cs.onSurface,
                    fontSize: 14,
                    height: 1.5,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 6),
              Row(children: [
                Icon(worst.icon, color: worst.color, size: 13),
                const SizedBox(width: 4),
                Text('${worst.nameRu} — ${worst.score.toInt()} баллов',
                    style: GoogleFonts.inter(
                        color: cs.onSurfaceVariant, fontSize: 12)),
              ]),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Divider(color: cs.onSurface.withValues(alpha: 0.1), height: 1),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () =>
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TipsScreen()),
              ),
          child: Row(children: [
            const Icon(Icons.school_rounded,
                color: AppColors.accentSuccess, size: 16),
            const SizedBox(width: 8),
            Text(
              'Советы и упражнения',
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
      ]),
    );
  }
}
class _Label extends StatelessWidget {
  final String text;

  const _Label(this.text);

  @override
  Widget build(BuildContext context) =>
      Text(text,
          style: GoogleFonts.inter(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w700));
}

class _ParamInfoSheet extends StatelessWidget {
  final ParamInfo info;
  final double score;

  const _ParamInfoSheet({required this.info, required this.score});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.scoreColor(score);
    final advice = info.adviceForScore(score);

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      snap: true,
      snapSizes: const [0.65, 0.92],
      builder: (ctx, ctrl) {
          final cs = Theme.of(ctx).colorScheme;
          return Container(
            decoration: BoxDecoration(
              color: cs.background,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Text(
                      info.title,
                      style: GoogleFonts.inter(
                          color: cs.onSurface,
                          fontSize: 22,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.withValues(alpha: 0.3))),
                    child: Text(
                      '${score.toInt()} / 100',
                      style: GoogleFonts.inter(
                          color: color,
                          fontSize: 16,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ]),

                const SizedBox(height: 6),
                _InfoBlock(
                  icon: Icons.analytics_outlined,
                  title: 'Что измеряется',
                  text: info.whatItMeasures,
                  color: AppColors.accentBlue,
                ),

                if (info.subMetricsInfo.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _SubMetricsInfoBlock(subMetrics: info.subMetricsInfo),
                ],

                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.accentWarning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.accentWarning.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: AppColors.accentWarning.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.tips_and_updates_rounded,
                          color: AppColors.accentWarning, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Совет для тебя',
                                style: GoogleFonts.inter(
                                    color: AppColors.accentWarning,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3)),
                            const SizedBox(height: 6),
                            Text(advice,
                                style: GoogleFonts.inter(
                                    color: cs.onSurface,
                                    fontSize: 14,
                                    height: 1.5)),
                          ]),
                    ),
                  ]),
                ),
              ],
            ),
          );
        },
    );
  }
}

class _InfoBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final Color color;

  const _InfoBlock({required this.icon, required this.title,
    required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: GoogleFonts.inter(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3)),
            const SizedBox(height: 5),
            Text(text,
                style: GoogleFonts.inter(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 13,
                    height: 1.5)),
          ]),
        ),
      ]),
    );
  }
}

class _SubMetricsInfoBlock extends StatelessWidget {
  final List<SubMetricInfo> subMetrics;
  const _SubMetricsInfoBlock({required this.subMetrics});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accentBlue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.bar_chart_rounded,
                color: AppColors.accentBlue, size: 14),
            const SizedBox(width: 6),
            Text(
              'Подметрики',
              style: GoogleFonts.inter(
                color: AppColors.accentBlue,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ]),
          const SizedBox(height: 10),
          ...subMetrics.asMap().entries.map((entry) {
            final i = entry.key;
            final sm = entry.value;
            return Padding(
              padding: EdgeInsets.only(bottom: i < subMetrics.length - 1 ? 12 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sm.name,
                    style: GoogleFonts.inter(
                      color: cs.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sm.description,
                    style: GoogleFonts.inter(
                      color: cs.onSurfaceVariant,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  if (sm.unit.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Измеряется: ${sm.unit}',
                      style: GoogleFonts.inter(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.check_circle_outline_rounded,
                        color: AppColors.accentSuccess, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      'Норма: ${sm.goodRange}',
                      style: GoogleFonts.inter(
                        color: AppColors.accentSuccess,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ]),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
