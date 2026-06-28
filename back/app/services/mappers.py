from __future__ import annotations
from app.core.deps import to_iso_utc
from app.models.recording import AnalysisResult
from app.schemas.analysis import (
    AnalysisDetail, RadarData, Parameter, Timecode,
    ParasiteDetail, PausesDetail, TempoDetail, LexicalDetail, SyntaxDetail,
    FillerPieItem, PauseHistogram, PauseStats,
)
def analysis_to_detail(result: AnalysisResult, audio_url: str | None = None) -> AnalysisDetail:
    par = result.details_parasites or {}
    pau = result.details_pauses    or {}
    tem = result.details_tempo     or {}
    lex = result.details_lexical   or {}
    syn = result.details_syntax    or {}

    radar = RadarData(
        parasites=result.score_parasites,
        pauses=result.score_pauses,
        tempo=result.score_tempo,
        lexical=result.score_lexical,
        syntax=result.score_syntax,
    )

    parameters = [
        Parameter(
            key="parasites", title="Слова-паразиты",
            score=result.score_parasites, icon="ban",
            description=parasites_desc(par),
        ),
        Parameter(
            key="pauses", title="Паузы",
            score=result.score_pauses, icon="pause_circle",
            description=pauses_desc(pau),
        ),
        Parameter(
            key="tempo", title="Темп",
            score=result.score_tempo, icon="speed",
            description=tempo_desc(tem),
        ),
        Parameter(
            key="lexical", title="Лексика",
            score=result.score_lexical, icon="book",
            description=lexical_desc(lex),
        ),
        Parameter(
            key="syntax", title="Синтаксис",
            score=result.score_syntax, icon="account_tree",
            description=syntax_desc(syn),
        ),
    ]

    timecodes = [
        Timecode(
            type=tc.get("type", ""),
            start=tc.get("start", tc.get("time_sec", 0)),
            end=tc.get("end", tc.get("end_sec")),
            description=tc.get("description", tc.get("label", "")),
        )
        for tc in (result.timecodes or [])
    ]
    top_fp = par.get("top_fillers_overall") or []
    total_fp = par.get("total_fillers_all") or par.get("total_filler_occurrences") or sum(i.get("count", 0) for i in top_fp)
    filler_pie_raw: list[dict] = []
    if total_fp:
        covered = 0
        for i in top_fp[:5]:
            cnt = i.get("count", 0)
            if cnt <= 0:
                continue
            filler_pie_raw.append({"word": i.get("word", ""), "percent": round(cnt / total_fp * 100), "count": cnt})
            covered += cnt
        other = total_fp - covered
        if other > 0:
            filler_pie_raw.append({"word": "другие", "percent": round(other / total_fp * 100), "count": other})
    filler_pie = [
        FillerPieItem(word=i["word"], percent=i.get("percent", 0), count=i.get("count", 0))
        for i in filler_pie_raw if i.get("word")
    ]
    pause_histogram = PauseHistogram(
        brief=round(pau.get("brief_pause_pct", 0)),
        medium=round(pau.get("medium_pause_pct", 0)),
        long=round(pau.get("long_pause_pct", 0)),
    )
    total_dur = pau.get("total_duration_s", 0) or 0
    long_pct  = pau.get("long_pause_pct", 0) or 0
    pause_stats = PauseStats(
        brief_count=pau.get("brief_pause_count", 0),
        medium_count=pau.get("medium_pause_count", 0),
        long_count=pau.get("long_pause_count", 0),
        long_total_seconds=round(total_dur * long_pct / 100, 1),
    )
    duration_sec = pau.get("total_duration_s") or 0.0
    top_fillers = sorted(
        [{"word": k, "count": v} for k, v in (par.get("details") or {}).items()],
        key=lambda x: -x["count"],
    )[:5]

    return AnalysisDetail(
        id=result.id,
        overall_score=result.total_score,
        duration_sec=duration_sec,
        transcript=result.transcript,
        created_at=to_iso_utc(result.analyzed_at),
        audio_url=audio_url,
        processing_times=result.processing_times,
        radar=radar,
        parameters=parameters,
        parasites=ParasiteDetail(
            score=result.score_parasites,

            filler_count=par.get("total_fillers_all", par.get("total_filler_occurrences", 0)),
            filler_pct=par.get("filler_proc", 0.0),
            filler_density=par.get("filler_density_per_minute", 0.0),
            unique_types=par.get("unique_filler_types", 0),
            max_consecutive=par.get("max_consecutive_fillers", 0),
            score_filler_proc=par.get("score_filler_proc", 0.0),
            score_density=par.get("score_density", 0.0),
            score_unique=par.get("score_unique", 0.0),
            score_consecutive=par.get("score_consecutive", 0.0),
            top_fillers=top_fillers,
            personal_fillers=par.get("personal_fillers", []),
            top_fillers_overall=par.get("top_fillers_overall", []),
        ),
        pauses=PausesDetail(
            score=result.score_pauses,
            ptr=pau.get("ptr", 0.0),
            speech_rate=pau.get("speech_rate", 0.0),
            artic_rate=pau.get("articulation_rate", pau.get("artic_rate", 0.0)),
            mlr=pau.get("mlr", 0.0),
            brief_pause_count=pau.get("brief_pause_count", 0),
            medium_pause_count=pau.get("medium_pause_count", 0),
            long_pause_count=pau.get("long_pause_count", 0),
            filled_pause_count=pau.get("filled_pause_count", 0),
            max_pause_ms=int(pau.get("max_pause_ms", 0)),
            filled_rate=pau.get("filled_rate", 0.0),
            medium_pause_pct=pau.get("medium_pause_pct", 0.0),
            long_pause_pct=pau.get("long_pause_pct", 0.0),
            score_ptr=pau.get("score_ptr", 0.0),
            score_mlr=pau.get("score_mlr", 0.0),
            score_long_pct=pau.get("score_long_pct", 0.0),
            score_max_pause=pau.get("score_max_pause", 0.0),
            score_medium_pct=pau.get("score_medium_pct", 0.0),
            score_filled=pau.get("score_filled", 0.0),
        ),
        tempo=TempoDetail(
            score=result.score_tempo,
            window_cv=tem.get("window_cv", 0.0),
            window_sr_mean=tem.get("window_sr_mean", 0.0),
            window_sr_min=tem.get("window_sr_min", 0.0),
            window_sr_max=tem.get("window_sr_max", 0.0),
            window_count=tem.get("window_count", 0),
            speech_rate=tem.get("speech_rate", pau.get("speech_rate", 0.0)),
            articulation_rate=tem.get("articulation_rate", pau.get("articulation_rate", pau.get("artic_rate", 0.0))),
            score_cv=tem.get("score_cv", 0.0),
            score_speech_rate=tem.get("score_speech_rate", 0.0),
            score_articulation_rate=tem.get("score_articulation_rate", 0.0),
        ),
        lexical=LexicalDetail(
            score=result.score_lexical,
            mattr=lex.get("mattr", 0.0),
            mtld=lex.get("mtld", 0.0),
            top_repeat_pct=lex.get("top_repeat_perc", lex.get("top_repeat_pct", 0.0)),
            top_repeated_words=[l for l, _ in (lex.get("top_lemmas") or [])[:10]],
            score_mattr=lex.get("score_mattr", 0.0),
            score_mtld=lex.get("score_mtld", 0.0),
            score_top_repeat_pct=lex.get("score_top_repeat_perc", lex.get("score_top_repeat_pct", 0.0)),
        ),
        syntax=SyntaxDetail(
            score=result.score_syntax,
            mean_utterance_length=syn.get("mean_utterance_length", 0.0),
            embedding_depth=syn.get("embedding_depth", 0.0),
            clauses_per_sentence=syn.get("clauses_per_sentence", 0.0),
            complex_sentences_ratio=syn.get("complex_sentences_ratio", 0.0),
            syntactic_variety=syn.get("syntactic_variety", 0.0),
            mean_dependency_distance=syn.get("mean_dependency_distance", 0.0),
            score_mean_utterance_length=syn.get("score_mean_utterance_length", 0.0),
            score_embedding_depth=syn.get("score_embedding_depth", 0.0),
            score_mean_dep_distance=syn.get("score_mean_dep_distance", 0.0),
            score_clauses_per_sentence=syn.get("score_clauses_per_sentence", 0.0),
            score_complex_sentences_ratio=syn.get("score_complex_sentences_ratio", 0.0),
            syntactic_type_count=syn.get("syntactic_type_count", 0),
        ),
        filler_pie=filler_pie,
        pause_histogram=pause_histogram,
        pause_stats=pause_stats,
        timecodes=timecodes,
    )


def parasites_desc(par: dict) -> str:
    count = par.get("total_fillers_all", par.get("total_filler_occurrences", 0))
    if count == 0:
        return " обнаружены"
    top_overall = par.get("top_fillers_overall") or []
    if top_overall:
        top = [item.get("word", "") for item in top_overall[:2] if item.get("word")]
    else:
        top = list((par.get("details") or {}).keys())[:2]
    words = ", ".join(f"«{w}»" for w in top) if top else ""
    pct = par.get("filler_proc", 0)
    return f"{words} — {pct:.0f}% речи" if words else f"Паразиты: {count} раз"


def pauses_desc(pau: dict) -> str:
    long_c = pau.get("long_pause_count", 0)
    sr = pau.get("speech_rate", 0)
    if long_c > 0:
        return f"{long_c} {'пауза' if long_c == 1 else 'паузы' if long_c < 5 else 'пауз'} > 1 с"
    return f"Темп: {sr:.0f} сл/мин" if sr else "Паузы в норме"


def tempo_desc(tem: dict) -> str:
    cv = tem.get("window_cv", 0)
    mean = tem.get("window_sr_mean", 0)
    if cv > 0.40:
        return f"Темп нестабилен (CV={cv:.2f})"
    return f"Среднее {mean:.0f} сл/мин, CV={cv:.2f}" if mean else "Вариативность темпа"


def lexical_desc(lex: dict) -> str:
    mattr = lex.get("mattr", 0)
    if mattr > 0:
        level = "богатый" if mattr > 0.7 else "средний" if mattr > 0.5 else "бедный"
        return f"MATTR {mattr:.2f} — {level} словарь"
    return "Лексическое разнообразие"


def syntax_desc(syn: dict) -> str:
    length = syn.get("mean_utterance_length", 0)
    return f"Средняя длина — {length:.1f} слова" if length > 0 else "Синтаксические характеристики"
