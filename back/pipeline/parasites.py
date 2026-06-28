import re
import json
from collections import defaultdict
from pathlib import Path

from pipeline._utils import calculate_score_plateau


def load_parasites_config() -> dict:
    json_path = Path(__file__).parent / "parasites_config.json"
    try:
        with open(json_path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        print(f"Ошибка загрузки parasites_config.json: {e}")
        return {}


config = load_parasites_config()

FILLER_WORDS_LIST: list[str] = config.get("static_fillers", [])
FILLER_WORDS_SET: frozenset[str] = frozenset(FILLER_WORDS_LIST)
GRAY_ZONE: frozenset[str] = frozenset(config.get("gray_zone", []))
STOP_WORDS: frozenset[str] = frozenset(config.get("stop_words", []))
REPLACEMENTS: dict = config.get("normalization_replacements", {})
SINGLE_FILLERS: frozenset[str] = frozenset(f for f in FILLER_WORDS_LIST if " " not in f)
MULTI_FILLERS_2: frozenset[str] = frozenset(f for f in FILLER_WORDS_LIST if f.count(" ") == 1)
MULTI_FILLERS_3: frozenset[str] = frozenset(f for f in FILLER_WORDS_LIST if f.count(" ") == 2)
WEIGHTS = {
    "filler_proc":     0.35,
    "filler_density":  0.30,
    "unique_fillers":  0.20,
    "max_consecutive": 0.15,
}

def _normalize(text: str) -> str:
    if not text:
        return ""

    text = text.lower()
    text = re.sub(r"(.)\1{2,}", r"\1", text)
    if REPLACEMENTS:
        pattern = re.compile('|'.join(map(re.escape, REPLACEMENTS.keys())))
        text = pattern.sub(lambda m: REPLACEMENTS[m.group(0)], text)
    text = re.sub(r'[.,!?;:\'"-–—()«»\[\]{}…]+', ' ', text)
    text = re.sub(r'\s+', ' ', text).strip()
    return text


def get_duration_minutes(tr: dict) -> float:
    if not tr.get("word_segments"):
        return 0.0
    last_end = tr["word_segments"][-1].get("end", 0)
    return last_end / 60.0 if last_end > 0 else 0.0


def _detect_personal_fillers(
    word_segments: list[dict],
    total_words: int,
) -> dict[str, int]:
    if total_words == 0:
        return {}
    word_counts: dict[str, int] = defaultdict(int)
    for seg in word_segments:
        word = seg.get("word", "").lower().strip()
        word = re.sub(r'[.,!?;:\'"-–—()«»\[\]{}…]+$', '', word)
        if not word or word in STOP_WORDS or word in FILLER_WORDS_SET:
            continue
        word_counts[word] += 1
    personal: dict[str, int] = {}
    for word, count in word_counts.items():
        pct = (count / total_words * 100)
        if word in GRAY_ZONE:
            if count >= 5 and pct >= 2:
                personal[word] = count
        else:
            if count >= 7 and pct >= 2.5:
                personal[word] = count

    return personal


def analyze(tr: dict, extra_static_fillers: list[str] | None = None) -> dict:
    total_words = len(tr.get("word_segments", []))
    if total_words == 0:
        return {"error": "Нет слов для анализа"}
    extra = [w.lower().strip() for w in (extra_static_fillers or []) if w.strip()]
    eff_single = SINGLE_FILLERS | frozenset(w for w in extra if " " not in w)
    eff_multi2 = MULTI_FILLERS_2 | frozenset(w for w in extra if w.count(" ") == 1)
    eff_multi3 = MULTI_FILLERS_3 | frozenset(w for w in extra if w.count(" ") == 2)
    duration_min = get_duration_minutes(tr)
    personal_fillers_dict = _detect_personal_fillers(tr.get("word_segments", []), total_words)
    personal_fillers = [
        {"word": w, "count": c}
        for w, c in sorted(personal_fillers_dict.items(), key=lambda x: -x[1])
    ]
    segs_filler_stats: dict[str, int] = defaultdict(int)
    max_consecutive = 0
    current = 0
    filler_timecodes: list[dict] = []
    word_segs = tr.get("word_segments", [])
    i = 0
    while i < len(word_segs):
        seg = word_segs[i]
        word = seg.get("word", "").lower().strip(".,!?;:'\"-–—()")
        matched_word = None
        skip = 1
        if i + 2 < len(word_segs):
            w3 = " ".join(
                word_segs[j].get("word", "").lower().strip(".,!?;:'\"-–—()")
                for j in range(i, i + 3)
            )
            if w3 in eff_multi3:
                matched_word = w3
                skip = 3
        if matched_word is None and i + 1 < len(word_segs):
            w2 = " ".join(
                word_segs[j].get("word", "").lower().strip(".,!?;:'\"-–—()")
                for j in range(i, i + 2)
            )
            if w2 in eff_multi2:
                matched_word = w2
                skip = 2
        if matched_word is None and (word in eff_single or word in personal_fillers_dict):
            matched_word = word
            skip = 1
        if matched_word is not None:
            segs_filler_stats[matched_word] += 1
            current += 1
            if current > max_consecutive:
                max_consecutive = current
            if seg.get("start") is not None:
                end_seg = word_segs[i + skip - 1]
                filler_timecodes.append({
                    "start": round(float(seg["start"]), 2),
                    "end": round(float(end_seg.get("end", end_seg.get("start", seg["start"]) + 0.3)), 2),
                    "word": matched_word,
                })
        else:
            current = 0

        i += skip
    filler_stats = segs_filler_stats
    total_filler_words = sum(len(w.split()) * c for w, c in segs_filler_stats.items())
    total_fillers_all = len(filler_timecodes)
    filler_proc = (total_filler_words / total_words * 100) if total_words > 0 else 0.0
    filler_density = (total_fillers_all / duration_min) if duration_min > 0 else 0.0
    unique_filler_types = len(segs_filler_stats)
    total_filler_occurrences = total_fillers_all
    top_fillers_overall = [
        {"word": w, "count": c}
        for w, c in sorted(segs_filler_stats.items(), key=lambda x: -x[1])[:3]
    ]
    score_proc = calculate_score_plateau(filler_proc, opt_low=0.0, opt_high=5.0, low=0.0, high=25.0)
    score_density = calculate_score_plateau(filler_density, opt_low=0.0, opt_high=4.0, low=0.0, high=30.0)
    score_unique = calculate_score_plateau(float(unique_filler_types), opt_low=0.0, opt_high=2.0, low=0.0, high=15.0)
    score_consec = calculate_score_plateau(float(max_consecutive), opt_low=0.0, opt_high=1.0, low=0.0, high=5.0)

    final_score = round(
        WEIGHTS["filler_proc"] * score_proc +
        WEIGHTS["filler_density"] * score_density +
        WEIGHTS["unique_fillers"] * score_unique +
        WEIGHTS["max_consecutive"] * score_consec,
        1
    )

    return {
        "total_filler_occurrences": total_filler_occurrences,
        "total_fillers_all": total_fillers_all,
        "filler_proc": round(filler_proc, 2),
        "filler_density_per_minute": round(filler_density, 2),
        "unique_filler_types": unique_filler_types,
        "max_consecutive_fillers": max_consecutive,
        "score_filler_proc": score_proc,
        "score_density": score_density,
        "score_unique": score_unique,
        "score_consecutive": score_consec,
        "score": final_score,
        "details": dict(sorted(filler_stats.items(), key=lambda x: -x[1])),
        "personal_fillers": personal_fillers,
        "top_fillers_overall": top_fillers_overall,
        "filler_timecodes": filler_timecodes[:30],
    }