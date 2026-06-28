import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:file_picker/file_picker.dart';
import '../core/colors.dart';
import '../services/api.dart';
import '../widgets/animated_waveform.dart';
import '../utils/formatters.dart';
import 'results_screen.dart';

enum _RecordingState { idle, countdown, recording, processing }

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen>
    with TickerProviderStateMixin {
  _RecordingState _state = _RecordingState.idle;
  int _elapsed = 0;
  int _countdown = 3;
  Timer? _timer;
  final AudioRecorder _recorder = AudioRecorder();
  String? _recordingPath;
  String _progressMessage = 'Загрузка...';

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  late AnimationController _stopBtnCtrl;
  late Animation<double> _stopBtnAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _stopBtnCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _stopBtnAnim = CurvedAnimation(parent: _stopBtnCtrl, curve: Curves.elasticOut);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    _stopBtnCtrl.dispose();
    _recorder.dispose();
    super.dispose();
  }

  void _startCountdown() {
    setState(() {
      _state = _RecordingState.countdown;
      _countdown = 3;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        t.cancel();
        _startRecording();
      }
    });
  }

  void _startRecording() {
    setState(() {
      _state = _RecordingState.recording;
      _elapsed = 0;
    });
    _stopBtnCtrl.forward();
    _beginRecording();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_elapsed < 300) {
        setState(() => _elapsed++);
      } else {
        _stopRecording();
      }
    });
  }

  Future<void> _beginRecording() async {
    final hasPerm = await _recorder.hasPermission();
    if (!hasPerm) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Нет доступа к микрофону', style: GoogleFonts.inter(color: Colors.white)),
            backgroundColor: Theme.of(context).colorScheme.surface,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/clarity_${DateTime.now().millisecondsSinceEpoch}.wav';
    _recordingPath = path;
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
        androidConfig: AndroidRecordConfig(
          audioSource: AndroidAudioSource.voiceRecognition,
        ),
      ),
      path: path,
    );
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    _pulseCtrl.stop();
    setState(() => _state = _RecordingState.processing);

    String? stoppedPath;
    try {
      stoppedPath = await _recorder.stop();
      final path = stoppedPath ?? _recordingPath;
      if (path == null) {
        throw Exception('Не удалось сохранить запись');
      }
      final file = File(path);
      final result = await Api.uploadAndAnalyze(
        file,
        onProgress: (msg, pct) {
          if (mounted) setState(() => _progressMessage = msg);
        },
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => ResultsScreen(result: result.withAudioPath(path)),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(
            opacity: anim,
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка анализа: $e', style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: Theme.of(context).colorScheme.surface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      setState(() => _state = _RecordingState.idle);
      _pulseCtrl.repeat(reverse: true);
    }
  }

  String get _timeString => Duration(seconds: _elapsed).mmss;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Stack(
        children: [
          if (_state == _RecordingState.recording)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).size.height * 0.5,
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.bottomCenter,
                    radius: 1.2,
                    colors: [
                      AppColors.accentSuccess.withValues(alpha: 0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: cs.surface.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            color: cs.onSurfaceVariant,
                            size: 20,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (_state == _RecordingState.recording) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.accentDanger.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.accentDanger.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              _BlinkingDot(),
                              const SizedBox(width: 6),
                              Text(
                                'REC',
                                style: GoogleFonts.inter(
                                  color: AppColors.accentDanger,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const Spacer(),

                if (_state == _RecordingState.idle) _buildIdleContent(),
                if (_state == _RecordingState.countdown) _buildCountdown(),
                if (_state == _RecordingState.recording) _buildRecordingContent(),
                if (_state == _RecordingState.processing) _buildProcessingContent(),

                const Spacer(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndAnalyze() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'm4a', 'wav', 'ogg', 'aac', 'flac', 'wma'],
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;

    final file = File(path);
    setState(() {
      _state = _RecordingState.processing;
      _progressMessage = 'Загрузка файла...';
    });
    try {
      final analysisResult = await Api.uploadAndAnalyze(
        file,
        onProgress: (msg, pct) {
          if (mounted) setState(() => _progressMessage = msg);
        },
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => ResultsScreen(result: analysisResult),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: $e', style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: Theme.of(context).colorScheme.surface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      setState(() => _state = _RecordingState.idle);
    }
  }

  Widget _buildIdleContent() {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          'Готов к записи?',
          style: GoogleFonts.inter(
            color: cs.onSurface,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Говори свободно — от 1 до 5 минут.\nАнализ запустится автоматически.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: cs.onSurfaceVariant,
            fontSize: 15,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 48),
        GestureDetector(
          onTap: _startCountdown,
          child: AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, child) => Transform.scale(
              scale: _pulseAnim.value,
              child: child,
            ),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppColors.accentSuccess, AppColors.accentBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentSuccess.withValues(alpha: 0.5),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(Icons.mic_rounded, color: Colors.white, size: 36),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Нажми, чтобы начать',
          style: GoogleFonts.inter(
            color: cs.onSurfaceVariant,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: _pickAndAnalyze,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.upload_file_rounded, color: cs.onSurfaceVariant, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Загрузить аудио',
                  style: GoogleFonts.inter(
                    color: cs.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCountdown() {
    return Column(
      children: [
        Text(
          '$_countdown',
          style: GoogleFonts.inter(
            color: AppColors.accentSuccess,
            fontSize: 120,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Приготовься говорить...',
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildRecordingContent() {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          _timeString,
          style: GoogleFonts.inter(
            color: cs.onSurface,
            fontSize: 56,
            fontWeight: FontWeight.w300,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'макс. 5:00',
          style: GoogleFonts.inter(
            color: cs.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 48),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: AnimatedWaveform(
            isPlaying: true,
            height: 120,
            barCount: 56,
          ),
        ),
        const SizedBox(height: 56),
        ScaleTransition(
          scale: _stopBtnAnim,
          child: GestureDetector(
            onTap: _stopRecording,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentDanger,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentDanger.withValues(alpha: 0.5),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.stop_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Стоп',
          style: GoogleFonts.inter(
            color: cs.onSurfaceVariant,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  int get _currentStep {
    final m = _progressMessage.toLowerCase();
    if (m.contains('транскрипц') || m.contains('распознав') || m.contains('whisper')) return 1;
    if (m.contains('анализ') || m.contains('обработ') || m.contains('завершен') ||
        m.contains('парази') || m.contains('пауз') || m.contains('темп') ||
        m.contains('лексик') || m.contains('синтакс')) return 2;
    return 0;
  }

  Widget _buildProcessingContent() {
    final cs = Theme.of(context).colorScheme;
    final step = _currentStep;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppColors.accentSuccess.withValues(alpha: 0.2),
                  AppColors.accentBlue.withValues(alpha: 0.2),
                ],
              ),
            ),
            child: Stack(alignment: Alignment.center, children: [
              SizedBox(
                width: 88,
                height: 88,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: const AlwaysStoppedAnimation(AppColors.accentSuccess),
                  backgroundColor: AppColors.accentSuccess.withValues(alpha: 0.1),
                ),
              ),
              const Icon(Icons.graphic_eq_rounded,
                  color: AppColors.accentSuccess, size: 32),
            ]),
          ),
          const SizedBox(height: 28),
          Text(
            'Анализирую речь...',
            style: GoogleFonts.inter(
              color: cs.onSurface,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Обычно занимает 30–90 секунд',
            style: GoogleFonts.inter(
              color: cs.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 32),
          _ProcessStep(
            index: 0,
            label: 'Загрузка аудио',
            description: 'Отправляем файл на сервер',
            state: step > 0 ? _StepState.done : step == 0 ? _StepState.active : _StepState.waiting,
          ),
          const SizedBox(height: 10),
          _ProcessStep(
            index: 1,
            label: 'Транскрипция',
            description: 'Распознаём слова из аудио',
            state: step > 1 ? _StepState.done : step == 1 ? _StepState.active : _StepState.waiting,
          ),
          const SizedBox(height: 10),
          _ProcessStep(
            index: 2,
            label: 'Анализ параметров',
            description: 'Оцениваем паузы, темп, лексику...',
            state: step > 2 ? _StepState.done : step == 2 ? _StepState.active : _StepState.waiting,
          ),
        ],
      ),
    );
  }
}

enum _StepState { waiting, active, done }

class _ProcessStep extends StatelessWidget {
  final int index;
  final String label;
  final String description;
  final _StepState state;

  const _ProcessStep({
    required this.index,
    required this.label,
    required this.description,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isActive = state == _StepState.active;
    final isDone = state == _StepState.done;
    final color = isDone
        ? AppColors.accentSuccess
        : isActive
        ? AppColors.accentBlue
        : cs.outline.withValues(alpha: 0.4);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.accentBlue.withValues(alpha: 0.08)
            : cs.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive
              ? AppColors.accentBlue.withValues(alpha: 0.35)
              : color.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: isDone || isActive ? 0.15 : 0.06),
          ),
          child: Center(
            child: isDone
                ? Icon(Icons.check_rounded, color: AppColors.accentSuccess, size: 16)
                : isActive
                ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(AppColors.accentBlue),
              ),
            )
                : Text(
              '${index + 1}',
              style: GoogleFonts.inter(
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              label,
              style: GoogleFonts.inter(
                color: isDone || isActive ? cs.onSurface : cs.onSurfaceVariant,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              description,
              style: GoogleFonts.inter(
                color: cs.onSurfaceVariant,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _BlinkingDot extends StatefulWidget {
  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.accentDanger,
        ),
      ),
    );
  }
}