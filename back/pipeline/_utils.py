"""
Общие утилиты для аналитических модулей
"""
from __future__ import annotations

import math


def norm_gauss(x: float, opt: float, diff: float) -> float:
    """Гаусс, нормированный так, что на границе (расстояние diff) равен 0, в opt — 1."""
    sigma = diff / 1.5
    g_x = math.exp(-((x - opt) ** 2) / (2 * sigma ** 2))
    g_b = math.exp(-(diff ** 2) / (2 * sigma ** 2))  # значение на границе
    scale = 1.0 - g_b
    if scale <= 0:
        return 0.0
    return max(0.0, (g_x - g_b) / scale)


def calculate_gauss_score(value: float, opt: float, low: float, high: float) -> float:
    """Универсальная оценка: 100 баллов в точке opt, плавный спад до 0 на границах."""
    if value < low or value > high:
        return 0.0
    diff = max(abs(high - opt), abs(low - opt))
    if diff == 0:
        return 0.0
    return round(norm_gauss(value, opt, diff) * 100, 1)


def calculate_score_plateau(
        value: float,
        opt_low: float,
        opt_high: float,
        low: float,
        high: float,
) -> float:
    if value < low or value > high:
        return 0.0
    if opt_low <= value <= opt_high:
        return 100.0
    if value < opt_low:
        diff = abs(opt_low - low)
        if diff == 0:
            return 0.0
        return round(norm_gauss(value, opt_low, diff) * 100, 1)
    else:
        diff = abs(high - opt_high)
        if diff == 0:
            return 0.0
        return round(norm_gauss(value, opt_high, diff) * 100, 1)


def calculate_score_higher_better(value: float, opt: float, low: float) -> float:
    if value >= opt:
        return 100.0
    if value < low:
        return 0.0
    diff = abs(opt - low)
    if diff == 0:
        return 0.0
    return round(norm_gauss(value, opt, diff) * 100, 1)


def get_audio_duration(tr: dict, words: list) -> float:
    """Возвращает длительность аудио в секундах.
    Берёт значение из transcript-словаря, иначе считает по таймкодам слов.
    """
    return tr.get("audio_duration_s") or (words[-1]["end"] - words[0]["start"])


__all__ = [
    "calculate_gauss_score",
    "calculate_score_higher_better",
    "calculate_score_plateau",
    "get_audio_duration",
]
