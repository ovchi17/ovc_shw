from __future__ import annotations

import numpy as np

from pipeline._utils import calculate_score_plateau, get_audio_duration

WEIGHTS = {
    "cv": 0.5,
    "speech_rate": 0.35,
    "articulation_rate": 0.15,
}


def analyze(
        tr: dict,
        *,
        window_sec: int = 10,
        min_words_per_window: int = 5,
) -> dict:
    words = tr.get("word_segments", [])
    if len(words) < 3:
        return {"error": "Недостаточно слов для анализа темпа", "score": 0.0}
    total_duration = get_audio_duration(tr, words)
    window_rates: list[float] = []
    win_words: list[dict] = []
    speaking_time = 0.0

    for i, w in enumerate(words):
        win_words.append(w)
        speaking_time += w["end"] - w["start"]
        if i + 1 < len(words):
            gap = words[i + 1]["start"] - w["end"]
            if gap < 1.0:
                speaking_time += gap
        if speaking_time >= window_sec:
            if len(win_words) >= min_words_per_window:
                rate = len(win_words) / speaking_time * 60
                window_rates.append(rate)
            win_words = []
            speaking_time = 0.0
    if len(win_words) >= min_words_per_window and speaking_time >= window_sec * 0.5:
        rate = len(win_words) / speaking_time * 60
        window_rates.append(rate)
    if len(window_rates) >= 2:
        cv = float(np.std(window_rates) / np.mean(window_rates))
    else:
        cv = 0.0

    speech_time_for_rate = sum(w["end"] - w["start"] for w in words)
    for i in range(len(words) - 1):
        gap = words[i + 1]["start"] - words[i]["end"]
        if gap < 1.0:
            speech_time_for_rate += gap
    speech_rate = len(words) / speech_time_for_rate * 60 if speech_time_for_rate > 0 else 0.0

    articulation_rate = 0.0
    if total_duration > 0:
        speaking_time = 0.0
        for i in range(1, len(words)):
            gap = words[i]["start"] - words[i - 1]["end"]
            if gap < 0.15:
                speaking_time += gap
            speaking_time += (words[i]["end"] - words[i]["start"])

        if speaking_time > 0:
            articulation_rate = len(words) / speaking_time * 60

    sp_cv = calculate_score_plateau(cv, opt_low=0.08, opt_high=0.25, low=0.0, high=0.35)
    sp_sr = calculate_score_plateau(speech_rate, opt_low=115.0, opt_high=150.0, low=80.0, high=220.0)
    sp_ar = calculate_score_plateau(articulation_rate, opt_low=150.0, opt_high=185.0, low=100.0, high=250.0)

    if window_rates:
        sr_mean = float(np.mean(window_rates))
        sr_min = float(min(window_rates))
        sr_max = float(max(window_rates))
    else:
        sr_mean = speech_rate
        sr_min = speech_rate
        sr_max = speech_rate

    final_score = round(
        WEIGHTS["cv"] * sp_cv +
        WEIGHTS["speech_rate"] * sp_sr +
        WEIGHTS["articulation_rate"] * sp_ar,
        1
    )
    return {
        "window_cv": round(cv, 3),
        "window_sr_mean": round(sr_mean, 1),
        "window_sr_min": round(sr_min, 1),
        "window_sr_max": round(sr_max, 1),
        "window_count": len(window_rates),
        "speech_rate": round(speech_rate, 1),
        "articulation_rate": round(articulation_rate, 1),
        "score_cv": round(sp_cv, 1),
        "score_speech_rate": round(sp_sr, 1),
        "score_articulation_rate": round(sp_ar, 1),
        "score": final_score,
    }
