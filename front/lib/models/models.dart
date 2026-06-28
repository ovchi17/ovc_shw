import 'package:flutter/material.dart';
import '../core/colors.dart';
import '../core/icon_mapper.dart';

class SpeechParameter {
  final String name;
  final String nameRu;
  final double score;
  final IconData icon;
  final String topIssue;
  final Map<String, String> extraMetrics;
  final Map<String, dynamic> rawData;
  final Map<String, double> subScores;

  const SpeechParameter({
    required this.name,
    required this.nameRu,
    required this.score,
    required this.icon,
    this.topIssue = '',
    this.extraMetrics = const {},
    this.rawData = const {},
    this.subScores = const {},
  });

  Color get color => AppColors.scoreColor(score);
}

const subScoreLabels = <String, String>{
  'score_filler_proc':             'Доля паразитов в речи',
  'score_density':                 'Частота паразитов',
  'score_unique':                  'Контроль разнообразия паразитов',
  'score_consecutive':             'Серии паразитов подряд',
  'score_ptr':                     'Доля активной речи',
  'score_mlr':                     'Длина речевых сегментов',
  'score_long_pct':                'Контроль длинных пауз (>1 сек)',
  'score_max_pause':               'Контроль максимальной паузы',
  'score_medium_pct':              'Контроль средних пауз (0.2–1 сек)',
  'score_filled':                  'Контроль заполненных пауз',
  'score_cv':                      'Равномерность темпа',
  'score_speech_rate':             'Темп речи',
  'score_articulation_rate':       'Скорость артикуляции',
  'score_mattr':                   'Лексическое разнообразие',
  'score_mtld':                    'Богатство словаря',
  'score_top_repeat_pct':          'Частота повторений слов',
  'score_mean_utterance_length':   'Длина высказываний',
  'score_embedding_depth':         'Глубина предложений',
  'score_mean_dep_distance':       'Связность слов в предложении',
  'score_clauses_per_sentence':    'Насыщенность предложений',
  'score_complex_sentences_ratio': 'Доля сложных предложений',
};

class AnalysisResult {
  final DateTime date;
  final Duration duration;
  final double totalScore;
  final List<SpeechParameter> parameters;
  final List<TimecodeProblem> timecodes;
  final String audioPath;
  final String transcript;

  // Ключевые метрики для быстрой статистики
  final double speechRateWpm;
  final double ptr;
  final int briefPauseCount;
  final int mediumPauseCount;
  final int longPauseCount;
  final int totalFillers;
  final double fillerPct;
  final Map<String, int> fillerDetails;

  const AnalysisResult({
    required this.date,
    required this.duration,
    required this.totalScore,
    required this.parameters,
    required this.timecodes,
    required this.audioPath,
    this.transcript = '',
    this.speechRateWpm = 0,
    this.ptr = 0,
    this.briefPauseCount = 0,
    this.mediumPauseCount = 0,
    this.longPauseCount = 0,
    this.totalFillers = 0,
    this.fillerPct = 0,
    this.fillerDetails = const {},
  });

  Color get scoreColor => AppColors.scoreColor(totalScore);

  AnalysisResult withAudioPath(String path) => AnalysisResult(
        date: date, duration: duration, totalScore: totalScore,
        parameters: parameters, timecodes: timecodes, audioPath: path,
        transcript: transcript, speechRateWpm: speechRateWpm, ptr: ptr,
        briefPauseCount: briefPauseCount, mediumPauseCount: mediumPauseCount,
        longPauseCount: longPauseCount, totalFillers: totalFillers,
        fillerPct: fillerPct, fillerDetails: fillerDetails,
      );

  factory AnalysisResult.fromApi(Map<String, dynamic> json) {
    final pau = json['pauses'] as Map? ?? {};
    final tem = json['tempo'] as Map? ?? {};
    final lex = Map<String, dynamic>.from(json['lexical'] as Map? ?? {});
    final syn = Map<String, dynamic>.from(json['syntax'] as Map? ?? {});
    final par = Map<String, dynamic>.from(json['parasites'] as Map? ?? {});
    par['filler_pct'] ??= par['filler_proc'];
    par['filler_density'] ??= par['filler_density_per_minute'];
    par['unique_types'] ??= par['unique_filler_types'];
    par['max_consecutive'] ??= par['max_consecutive_fillers'];
    par['filler_count'] ??= par['total_filler_occurrences'];
    lex['top_repeat_pct'] ??= lex['top_repeat_perc'];
    lex['score_top_repeat_pct'] ??= lex['score_top_repeat_perc'];
    if (lex['top_repeated_words'] == null && lex['top_lemmas'] != null) {
      final lemmas = lex['top_lemmas'] as List;
      lex['top_repeated_words'] = lemmas
          .map((e) => e is List ? e[0].toString() : e.toString())
          .toList();
    }
    Map<String, String> parasiteExtra() {
      int count     = (par['filler_count'] ?? par['total_filler_occurrences'] as num?)?.toInt() ?? 0;
      final pct     = ((par['filler_pct'] ?? par['filler_proc']) as num?)?.toDouble() ?? 0.0;
      final density = ((par['filler_density'] ?? par['filler_density_per_minute']) as num?)?.toDouble() ?? 0.0;
      final unique  = ((par['unique_types'] ?? par['unique_filler_types']) as num?)?.toInt() ?? 0;
      final maxCons = ((par['max_consecutive'] ?? par['max_consecutive_fillers']) as num?)?.toInt() ?? 0;
      final overallRaw = par['top_fillers_overall'] as List? ?? [];
      final staticRaw  = par['top_fillers'] as List? ?? [];
      final topRaw = overallRaw.isNotEmpty ? overallRaw : staticRaw;
      if (count == 0) {
        final merged = <String, int>{};
        for (final f in [...overallRaw, ...staticRaw]) {
          if (f is! Map) continue;
          final word = (f['word'] ?? '').toString();
          if (word.isEmpty) continue;
          final c = ((f['count'] ?? 0) as num).toInt();
          merged[word] = (merged[word] ?? 0) >= c ? merged[word]! : c;
        }
        count = merged.values.fold(0, (s, v) => s + v);
      }
      final top = topRaw.take(3).map((f) => '«${(f as Map?)?['word'] ?? ''}»').join(', ');
      return {
        if (count > 0)      'Всего':         '$count раз',
        'Доля речи':        '${pct.toStringAsFixed(1)}%',
        'Плотность':        '${density.toStringAsFixed(1)} раз/мин',
        if (unique > 0)     'Разных типов':  '$unique',
        if (maxCons > 0)    'Макс. подряд':  '$maxCons шт.',
        if (top.isNotEmpty) 'Топ слова':     top,
      };
    }

    Map<String, String> pausesExtra() {
      final ptr       = (pau['ptr'] as num?)?.toDouble() ?? 0.0;
      final sr        = (pau['speech_rate'] as num?)?.toDouble() ?? 0.0;
      final ar        = (pau['artic_rate'] as num?)?.toDouble() ?? 0.0;
      final mlr       = (pau['mlr'] as num?)?.toDouble() ?? 0.0;
      final maxMs     = (pau['max_pause_ms'] as num?)?.toInt() ?? 0;
      final briefC    = (pau['brief_pause_count'] as num?)?.toInt() ?? 0;
      final medC      = (pau['medium_pause_count'] as num?)?.toInt() ?? 0;
      final longC     = (pau['long_pause_count'] as num?)?.toInt() ?? 0;
      final filledRate = (pau['filled_rate'] as num?)?.toDouble() ?? 0.0;
      final medPct    = (pau['medium_pause_pct'] as num?)?.toDouble() ?? 0.0;
      final longPct   = (pau['long_pause_pct'] as num?)?.toDouble() ?? 0.0;
      return {
        if (ptr > 0)    'PTR (доля речи)':       '${ptr.toStringAsFixed(0)}%',
        if (sr > 0)     'Темп речи':              '${sr.toStringAsFixed(0)} сл/мин',
        if (ar > 0)     'Темп артикуляции':       '${ar.toStringAsFixed(0)} сл/мин',
        if (mlr > 0)    'Средний спурт':          '${mlr.toStringAsFixed(1)} сл',
        if (maxMs > 0)  'Макс. пауза':            '${(maxMs / 1000).toStringAsFixed(1)} с',
        if (briefC > 0) 'Кратких пауз (<0.2 с)':  '$briefC шт.',
        if (medPct > 0) 'Средних пауз (0.2–1 с)': '${medPct.toStringAsFixed(1)}%',
        if (medC > 0)   'Средних пауз, шт.':      '$medC шт.',
        if (longPct > 0)'Длинных пауз (>1 с)':    '${longPct.toStringAsFixed(1)}%',
        if (longC > 0)  'Длинных пауз, шт.':      '$longC шт.',
        'Заполненных пауз':                        '${filledRate.toStringAsFixed(1)} /100 сл',
      };
    }

    Map<String, String> tempoExtra() {
      final mean = (tem['window_sr_mean'] as num?)?.toDouble() ?? 0.0;
      final minS = (tem['window_sr_min'] as num?)?.toDouble() ?? 0.0;
      final maxS = (tem['window_sr_max'] as num?)?.toDouble() ?? 0.0;
      final cv   = (tem['window_cv'] as num?)?.toDouble() ?? 0.0;
      final cnt  = (tem['window_count'] as num?)?.toInt() ?? 0;
      final sr   = (tem['speech_rate'] as num?)?.toDouble() ?? 0.0;
      final ar   = (tem['articulation_rate'] as num?)?.toDouble() ?? 0.0;
      return {
        if (sr > 0)   'Темп речи':          '${sr.toStringAsFixed(0)} сл/мин',
        if (ar > 0)   'Темп артикуляции': '${ar.toStringAsFixed(0)} сл/мин',
        if (mean > 0) 'Средний темп':    '${mean.toStringAsFixed(0)} сл/мин',
        if (minS > 0) 'Мин. темп':       '${minS.toStringAsFixed(0)} сл/мин',
        if (maxS > 0) 'Макс. темп':      '${maxS.toStringAsFixed(0)} сл/мин',
        if (cv > 0)   'Вариативность':   cv.toStringAsFixed(2),
        if (cnt > 0)  'Окон анализа':    '$cnt',
      };
    }

    Map<String, String> lexicalExtra() {
      final mattr = (lex['mattr'] as num?)?.toDouble() ?? 0.0;
      final mtld  = (lex['mtld'] as num?)?.toDouble() ?? 0.0;
      final pct   = ((lex['top_repeat_pct'] ?? lex['top_repeat_perc']) as num?)?.toDouble() ?? 0.0;
      final topWords = lex['top_repeated_words'] ?? lex['top_lemmas'];
      final topW  = (topWords is List)
          ? topWords.take(3).map((w) => w is List ? w[0].toString() : w.toString()).join(', ')
          : '';
      return {
        if (mattr > 0) 'MATTR': mattr.toStringAsFixed(2),
        if (mtld > 0)  'MTLD': mtld.toStringAsFixed(1),
        if (pct > 0)   'Повторений': '${pct.toStringAsFixed(1)}%',
        if (topW.isNotEmpty) 'Частые слова': topW,
      };
    }

    Map<String, String> syntaxExtra() {
      final length  = (syn['mean_utterance_length'] as num?)?.toDouble() ?? 0.0;
      final depth   = (syn['embedding_depth'] as num?)?.toDouble() ?? 0.0;
      final clauses = (syn['clauses_per_sentence'] as num?)?.toDouble() ?? 0.0;
      final complexR = (syn['complex_sentences_ratio'] as num?)?.toDouble() ?? 0.0;
      final variety = (syn['syntactic_variety'] as num?)?.toDouble() ?? 0.0;
      final mdd     = (syn['mean_dependency_distance'] as num?)?.toDouble() ?? 0.0;
      return {
        if (length > 0)   'Длина фраз':         '${length.toStringAsFixed(1)} слова',
        if (depth > 0)    'Глубина':             depth.toStringAsFixed(1),
        if (mdd > 0)      'Связность слов':      mdd.toStringAsFixed(2),
        if (clauses > 0)  'Клаузы/предл.':       clauses.toStringAsFixed(2),
        if (complexR > 0) 'Сложные предл.':      '${complexR.toStringAsFixed(0)}%',
        if (variety > 0)  'Синт. разнообразие':  variety.toStringAsFixed(2),
      };
    }
    Map<String, double> _extractSubScores(Map data, List<String> keys) {
      final result = <String, double>{};
      for (final key in keys) {
        final raw = data[key];
        if (raw != null) result[key] = (raw as num).toDouble();
      }
      return result;
    }

    final parasiteSubScores = _extractSubScores(par, [
      'score_filler_proc', 'score_density', 'score_unique', 'score_consecutive',
    ]);
    final pausesSubScores = _extractSubScores(pau, [
      'score_ptr', 'score_mlr', 'score_long_pct', 'score_max_pause',
      'score_medium_pct', 'score_filled',
    ]);
    final tempoSubScores = _extractSubScores(tem, [
      'score_cv', 'score_speech_rate', 'score_articulation_rate',
    ]);
    final lexicalSubScores = _extractSubScores(lex, [
      'score_mattr', 'score_mtld', 'score_top_repeat_pct',
    ]);
    // Syntax: normalize score key alias
    final syntaxSubScores = _extractSubScores(syn, [
      'score_mean_utterance_length', 'score_embedding_depth',
      'score_mean_dep_distance', 'score_clauses_per_sentence',
      'score_complex_sentences_ratio',
    ]);

    final params = (json['parameters'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((p) {
          final key = (p['key'] ?? '').toString();
          return SpeechParameter(
            name: key,
            nameRu: (p['title'] ?? '').toString(),
            score: ((p['score'] ?? 0) as num).toDouble(),
            icon: iconFromParamKey((p['icon'] ?? '').toString()),
            topIssue: (() {
              final desc = (p['description'] ?? '').toString();
              if (key == 'parasites') {
                final fillerCount = ((par['filler_count'] ?? 0) as num).toInt();
                final hasTopFillers =
                    (par['top_fillers_overall'] as List?)?.isNotEmpty == true ||
                    (par['top_fillers'] as List?)?.isNotEmpty == true;
                if ((fillerCount > 0 || hasTopFillers) &&
                    desc.toLowerCase().contains('не обнаружен')) {
                  return '';
                }
              }
              return desc;
            })(),
            extraMetrics: key == 'parasites' ? parasiteExtra()
                : key == 'pauses'   ? pausesExtra()
                : key == 'tempo'    ? tempoExtra()
                : key == 'lexical'  ? lexicalExtra()
                : key == 'syntax'   ? syntaxExtra()
                : const {},
          rawData: key == 'parasites' ? Map<String, dynamic>.from(par)
                : key == 'pauses'   ? Map<String, dynamic>.from(pau)
                : key == 'tempo'    ? Map<String, dynamic>.from(tem)
                : key == 'lexical'  ? Map<String, dynamic>.from(lex)
                : key == 'syntax'   ? Map<String, dynamic>.from(syn)
                : const {},
          subScores: key == 'parasites' ? parasiteSubScores
                : key == 'pauses'   ? pausesSubScores
                : key == 'tempo'    ? tempoSubScores
                : key == 'lexical'  ? lexicalSubScores
                : key == 'syntax'   ? syntaxSubScores
                : const {},
          );
        })
        .toList();

    final tcs = (json['timecodes'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((tc) => TimecodeProblem(
              start: Duration(
                milliseconds: (((tc['start'] ?? tc['time_sec'] ?? 0) as num).toDouble() * 1000).round(),
              ),
              end: Duration(
                milliseconds: (((tc['end'] ?? tc['end_sec'] ?? tc['start'] ?? tc['time_sec'] ?? 0) as num).toDouble() * 1000).round(),
              ),
              type: (tc['type'] ?? '').toString(),
              description: (tc['description'] ?? tc['label'] ?? '').toString(),
            ))
        .toList();

    final overallRaw = par['top_fillers_overall'] as List<dynamic>? ?? [];
    final staticRaw  = par['top_fillers'] as List<dynamic>? ?? [];
    final fillerMap = <String, int>{};
    for (final f in overallRaw) {
      if (f is Map) {
        final word = (f['word'] ?? '').toString();
        if (word.isNotEmpty) {
          fillerMap[word] = ((f['count'] ?? 0) as num).toInt();
        }
      }
    }
    for (final f in staticRaw) {
      if (f is Map) {
        final word = (f['word'] ?? '').toString();
        final count = ((f['count'] ?? 0) as num).toInt();
        if (word.isNotEmpty) {
          fillerMap[word] = (fillerMap[word] ?? 0) < count ? count : (fillerMap[word] ?? 0);
        }
      }
    }
    final ps = json['pause_stats'] as Map? ?? {};

    return AnalysisResult(
      date: DateTime.tryParse(((json['created_at'] ?? json['analyzed_at'] ?? '') as String)) ?? DateTime.now(),
      duration: Duration(seconds: ((json['duration_sec'] ?? 0) as num).toInt()),
      totalScore: ((json['overall_score'] ?? json['total_score'] ?? 0) as num).toDouble(),
      parameters: params,
      timecodes: tcs,
      audioPath: (json['audio_url'] as String?) ?? '',
      transcript: (json['transcript'] ?? '').toString(),
      speechRateWpm: ((pau['speech_rate'] ?? 0) as num).toDouble(),
      ptr: ((pau['ptr'] ?? 0) as num).toDouble(),
      briefPauseCount: ((ps['brief_count'] ?? pau['brief_pause_count'] ?? 0) as num).toInt(),
      mediumPauseCount: ((ps['medium_count'] ?? pau['medium_pause_count'] ?? 0) as num).toInt(),
      longPauseCount: ((ps['long_count'] ?? pau['long_pause_count'] ?? 0) as num).toInt(),
      totalFillers: (() {
        int c = ((par['filler_count'] ?? 0) as num).toInt();
        if (c == 0) {
          c = fillerMap.values.fold(0, (s, v) => s + v);
        }
        return c;
      })(),
      fillerPct: ((par['filler_pct'] ?? 0) as num).toDouble(),
      fillerDetails: fillerMap,
    );
  }
}

class TimecodeProblem {
  final Duration start;
  final Duration end;
  final String type;
  final String description;

  const TimecodeProblem({
    required this.start,
    required this.end,
    required this.type,
    required this.description,
  });
}

