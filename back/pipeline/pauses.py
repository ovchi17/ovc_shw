from __future__ import annotations
import numpy as np
from pipeline._utils import calculate_gauss_score, calculate_score_plateau, get_audio_duration

_SENTENCE_END = frozenset(".!?")


def ends_sentence(word_text: str) -> bool:
    cleaned = word_text.strip().rstrip("»\"'")
    return bool(cleaned) and cleaned[-1] in _SENTENCE_END


WEIGHTS = {
    "ptr":         0.30,
    "long_pct":    0.50,
    "mlr":         0.20,
}

assert abs(sum(WEIGHTS.values()) - 1.0) < 1e-6


def analyze(
    tr: dict,
    *,
    brief_threshold: float = 0.500,
    long_threshold: float = 1.000,
    min_gap: float = 0.100,
) -> dict:
    words = tr.get("word_segments", [])
    if len(words) < 3:
        return {"error": "Недостаточно слов для анализа пауз", "score": 0.0}

    total_words = len(words)
    total_duration = get_audio_duration(tr, words)

    brief_pauses = []
    medium_pauses = []
    long_pauses = []
    medium_pause_timecodes = []
    long_pause_timecodes = []
    filled_count = 0
    run_lengths_punct = []
    run_lengths_long = []

    cur_punct = 0
    cur_long = 0

    for i, w in enumerate(words):
        word_text = w.get("word", "").strip()

        cur_punct += 1
        cur_long += 1

        if ends_sentence(word_text):
            run_lengths_punct.append(cur_punct)
            cur_punct = 0

        if i < len(words) - 1:
            gap = words[i + 1]["start"] - w["end"]

            if gap < min_gap:
                continue

            if gap >= long_threshold:
                run_lengths_long.append(cur_long)
                cur_long = 0

            if gap < brief_threshold:
                brief_pauses.append(gap)
            elif gap < long_threshold:
                medium_pauses.append(gap)
                medium_pause_timecodes.append({
                    "start": round(float(w["end"]), 2),
                    "end": round(float(words[i + 1]["start"]), 2),
                    "duration_ms": round(gap * 1000),
                })
            else:
                long_pauses.append(gap)
                long_pause_timecodes.append({
                    "start": round(float(w["end"]), 2),
                    "end": round(float(words[i + 1]["start"]), 2),
                    "duration_ms": round(gap * 1000),
                })

    if cur_punct > 0:
        run_lengths_punct.append(cur_punct)
    if cur_long > 0:
        run_lengths_long.append(cur_long)

    sum_medium = sum(medium_pauses)
    sum_long = sum(long_pauses)
    all_pauses = medium_pauses + long_pauses
    brief_pct = (sum(brief_pauses) / total_duration * 100) if total_duration > 0 else 0.0
    medium_pct = (sum_medium / total_duration * 100) if total_duration > 0 else 0.0
    long_pct = (sum_long / total_duration * 100) if total_duration > 0 else 0.0
    max_pause_ms = max((p * 1000 for p in all_pauses), default=0.0)
    filled_rate = (filled_count / total_words * 100) if total_words > 0 else 0.0
    phonation_time = sum(w["end"] - w["start"] for w in words)
    ptr = (phonation_time / total_duration * 100) if total_duration > 0 else 0.0
    mlr_punct = float(np.mean(run_lengths_punct)) if run_lengths_punct else None
    mlr_long = float(np.mean(run_lengths_long)) if run_lengths_long else float(total_words)
    mlr = mlr_punct if mlr_punct is not None else mlr_long
    speech_rate = (total_words / total_duration * 60) if total_duration > 0 else 0.0
    articulation_rate = (total_words / phonation_time * 60) if phonation_time > 0 else 0.0
    sp_ptr = calculate_score_plateau(ptr, opt_low=70.0, opt_high=85.0, low=40.0, high=100.0)
    sp_mlr = calculate_score_plateau(mlr, opt_low=7.0, opt_high=13.0, low=3.0, high=30.0)
    sp_long = calculate_gauss_score(long_pct, opt=0.0, low=0.0, high=40.0)

    score = (
        WEIGHTS["ptr"] * sp_ptr +
        WEIGHTS["long_pct"] * sp_long +
        WEIGHTS["mlr"] * sp_mlr
    )

    return {
        "total_duration_s": round(total_duration, 2),
        "speech_rate": round(speech_rate, 1),
        "articulation_rate": round(articulation_rate, 1),
        "brief_pause_count": len(brief_pauses),
        "medium_pause_count": len(medium_pauses),
        "long_pause_count": len(long_pauses),
        "filled_pause_count": filled_count,
        "brief_pause_pct": round(brief_pct, 2),
        "medium_pause_pct": round(medium_pct, 2),
        "long_pause_pct": round(long_pct, 2),
        "max_pause_ms": round(max_pause_ms, 0),
        "filled_rate": round(filled_rate, 2),
        "ptr": round(ptr, 1),
        "mlr": round(mlr, 2),
        "mlr_punct": round(mlr_punct, 2) if mlr_punct is not None else None,
        "mlr_long": round(mlr_long, 2),
        "score_ptr": round(sp_ptr, 1),
        "score_mlr": round(sp_mlr, 1),
        "score_long_pct": round(sp_long, 1),
        "score": round(score, 1),
        "medium_pause_timecodes": medium_pause_timecodes,
        "long_pause_timecodes": long_pause_timecodes,
        "all_pause_timecodes": medium_pause_timecodes + long_pause_timecodes,
        "run_count_punct": len(run_lengths_punct),
        "run_count_long": len(run_lengths_long),
        "run_lengths_sample": (run_lengths_punct or run_lengths_long)[:10],
    }