from typing import Callable
from pipeline import pauses, tempo, parasites, lexical, syntax


SCORE_WEIGHTS: dict[str, float] = {
    "parasites": 0.30,
    "pauses":    0.25,
    "tempo":     0.20,
    "lexical":   0.15,
    "syntax":    0.10,
}

PIPELINE_STAGES: list[tuple[str, str, int]] = [
    ("pauses",    "Анализ пауз...",                    10),
    ("tempo",     "Анализ темпа речи...",              30),
    ("parasites", "Анализ слов-паразитов...",          50),
    ("lexical",   "Анализ лексического разнообразия...", 68),
    ("syntax",    "Анализ синтаксиса...",              84),
]


def analyze(
        tr: dict,
        *,
        progress_callback: Callable[[str, int], None] | None = None,
        extra_static_fillers: list[str] | None = None,
) -> dict:
    def progress(msg: str, pct: int) -> None:
        if progress_callback:
            progress_callback(msg, pct)

    modules: dict[str, dict] = {}
    for name, message, pct in PIPELINE_STAGES:
        progress(message, pct)
        if name == "parasites":
            modules[name] = parasites.analyze(tr, extra_static_fillers=extra_static_fillers)
        else:
            modules[name] = {
                "pauses":  pauses.analyze,
                "tempo":   tempo.analyze,
                "lexical": lexical.analyze,
                "syntax":  syntax.analyze,
            }[name](tr)

    progress("Формирование итоговой оценки...", 95)

    overall_score = round(
        sum(
            SCORE_WEIGHTS[name] * float(modules.get(name, {}).get("score", 0.0))
            for name in SCORE_WEIGHTS
        ),
        1
    )

    progress("Анализ завершён", 100)
    return {
        "overall_score": overall_score,
        "modules": modules,
        "audio_duration_s": round(tr.get("audio_duration_s", 0.0), 1),
        "total_words": len(tr.get("word_segments", [])),
    }
