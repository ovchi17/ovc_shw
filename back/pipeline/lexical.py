import json
import re
from collections import Counter
import numpy as np

try:
    import pymorphy3 as pymorphy2
except ImportError:
    import pymorphy2

from pipeline._utils import calculate_score_higher_better, calculate_score_plateau

import logging
logger = logging.getLogger(__name__)

MATTR_WINDOW = 50
MTLD_THRESHOLD = 0.72
TOP_N_LEMMAS = 10


def load_lexical_config() -> dict:
    from pathlib import Path
    json_path = Path(__file__).parent / "parasites_config.json"
    try:
        with open(json_path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        logger.warning(f"Ошибка загрузки parasites_config.json: {e}")
        return {}


config = load_lexical_config()
STOP_WORDS: frozenset[str] = frozenset(config.get("stop_words", []))
REPLACEMENTS: dict = config.get("normalization_replacements", {})
try:
    from pipeline.parasites import FILLER_WORDS_SET as _FILLER_SET
except ImportError:
    _FILLER_SET = frozenset()

_morph = pymorphy2.MorphAnalyzer()


def clean(word: str) -> str:
    word = re.sub(r"[^\wа-яё\-]", "", word.lower())
    return word.strip("-")


def lemmatize(word: str) -> str:
    try:
        return _morph.parse(word)[0].normal_form
    except Exception:
        return word

def mattr(words: list, window: int = MATTR_WINDOW) -> float:
    if not words:
        return 0.0
    if len(words) < window:
        return len(set(words)) / len(words)
    scores = [
        len(set(words[i:i + window])) / window
        for i in range(len(words) - window + 1)
    ]
    return float(np.mean(scores))


def mtld(words: list, threshold: float = MTLD_THRESHOLD) -> float:
    def one_pass(ws):
        factors = 0.0
        types = set()
        count = 0
        for w in ws:
            count += 1
            types.add(w)
            ttr = len(types) / count
            if ttr <= threshold:
                factors += 1.0
                types = set()
                count = 0
        if count > 0:
            ttr = len(types) / count
            if ttr != 1.0:
                factors += (1.0 - ttr) / (1.0 - threshold)
        return len(ws) / factors if factors > 0 else 0.0

    if not words:
        return 0.0
    return (one_pass(words) + one_pass(words[::-1])) / 2.0

def _top_repeat_perc(lemmas: list, n: int = TOP_N_LEMMAS) -> float:
    if not lemmas:
        return 0.0
    counter = Counter(lemmas)
    top_freq = sum(freq for _, freq in counter.most_common(n))
    return (top_freq / len(lemmas)) * 100.0


# ВЕСА

WEIGHTS = {
    "mattr":             0.3,
    "mtld":              0.4,
    "top_repeat_perc":   0.3,
}

def analyze(tr: dict) -> dict:
    word_segments = tr.get("word_segments", [])
    raw_words = [clean(w.get("word", "")) for w in word_segments]
    raw_words = [w for w in raw_words if re.search(r"[а-яёА-ЯЁ]", w)]

    if not raw_words:
        return {"error": "Не найдено слов для анализа"}

    lemmas = [lemmatize(w) for w in raw_words]
    lemmas_filtered = [
        l for l, w in zip(lemmas, raw_words)
        if l not in STOP_WORDS
        and w not in _FILLER_SET    ]

    if not lemmas_filtered:
        return {"error": "После удаления стоп-слов и паразитов не осталось лемм"}

    mattr_val = mattr(lemmas_filtered)
    mtld_val = mtld(lemmas_filtered)
    top_rep = _top_repeat_perc(lemmas_filtered)
    sm = calculate_score_higher_better(mattr_val, opt=0.72, low=0.35)
    st = calculate_score_higher_better(mtld_val, opt=65.0, low=15.0)
    sr = calculate_score_plateau(float(top_rep), opt_low=0.0, opt_high=25.0, low=0.0, high=65.0)
    final_score = round(
        WEIGHTS["mattr"] * sm +
        WEIGHTS["mtld"] * st +
        WEIGHTS["top_repeat_perc"] * sr,
        1
    )

    return {
        "mattr": round(mattr_val, 4),
        "mtld": round(mtld_val, 2),
        "top_repeat_perc": round(top_rep, 2),
        "top_lemmas": Counter(lemmas_filtered).most_common(TOP_N_LEMMAS),
        "score_mattr": round(sm, 1),
        "score_mtld": round(st, 1),
        "score_top_repeat_perc": round(sr, 1),
        "score": final_score,
    }