import logging
import os
import warnings
from functools import lru_cache
from typing import Optional, Union
import numpy as np
import torch
import whisperx

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s | %(levelname)s | %(name)s | %(message)s',
    datefmt='%H:%M:%S'
)
logger = logging.getLogger(__name__)

DEFAULT_MODEL_SIZE = "small"
DEFAULT_DEVICE = "cpu"
DEFAULT_COMPUTE_TYPE = "int8"
DEFAULT_BATCH_SIZE = 16
DEFAULT_VAD_FILTER = True
DEFAULT_VAD_THRESHOLD = 0.30
DEFAULT_LANGUAGE = "ru"

warnings.filterwarnings("ignore", category=UserWarning, module="whisperx")
warnings.filterwarnings("ignore", category=UserWarning, module="lightning")
warnings.filterwarnings("ignore", category=UserWarning, module="pytorch_lightning")

for name in ("whisperx", "lightning", "pytorch_lightning"):
    logging.getLogger(name).setLevel(logging.ERROR)

cpu_count = os.cpu_count() or 4
torch.set_num_threads(cpu_count)
torch.set_num_interop_threads(max(1, cpu_count // 2))

def best_align_device() -> str:
    try:
        if torch.backends.mps.is_available() and torch.backends.mps.is_built():
            logger.info("Обнаружено устройство MPS (Apple Silicon)")
            return "mps"
    except Exception:
        pass
    return "cpu"


ALIGN_DEVICE = best_align_device()

@lru_cache
def load_model(model_size: str, device: str, compute_type: str):
    return whisperx.load_model(model_size, device, compute_type=compute_type)

@lru_cache
def load_align_model(language_code: str, device: str):
    return whisperx.load_align_model(language_code=language_code, device=device)

SILENCE_RMS_THRESHOLD = 0.005

HALLUCINATION_PHRASES = frozenset({
    "редактор субтитров",
    "корректор",
    "субтитры сделал",
    "субтитры создал",
    "субтитры сделаны",
    "субтитры подготовил",
    "продолжение следует",
    "спасибо за просмотр",
    "спасибо за внимание",
    "подписывайтесь на канал",
    "подпишись на канал",
    "ставьте лайки",
    "всем пока",
    "до новых встреч",
})


def is_hallucination(text: str) -> bool:
    if not text:
        return False
    low = text.strip().lower()
    return any(phrase in low for phrase in HALLUCINATION_PHRASES)


def filter_hallucinations(segments: list) -> list:
    clean = []
    for s in segments:
        if is_hallucination(s.get("text", "")):
            logger.warning(f"Удалён сегмент-галлюцинация: «{s.get('text', '').strip()}»")
            continue
        clean.append(s)
    return clean


def trim_and_filter(word_segments: list) -> list:
    result = []
    for w in word_segments:
        start = w.get("start")
        end = w.get("end")
        word = w.get("word")
        if start is None or end is None or not word:
            continue
        duration = end - start
        word_str = str(word).strip()
        if duration <= 0.02 or not word_str:
            continue
        if duration > 4.0:
            end = start + 3.5
        result.append({
            "start": float(start),
            "end": float(end),
            "word": word_str,
        })
    return result


def transcribe(
    audio: Union[str, np.ndarray],
    model_size: str = DEFAULT_MODEL_SIZE,
    device: str = DEFAULT_DEVICE,
    compute_type: str = DEFAULT_COMPUTE_TYPE,
    batch_size: int = DEFAULT_BATCH_SIZE,
    vad_filter: bool = DEFAULT_VAD_FILTER,
    vad_threshold: float = DEFAULT_VAD_THRESHOLD,
    language: Optional[str] = DEFAULT_LANGUAGE,
) -> dict:

    logger.info(f"Загрузка Whisper модели '{model_size}' на {device} ({compute_type})...")
    model = load_model(model_size, device, compute_type)
    if isinstance(audio, str):
        logger.info(f"Загрузка аудиофайла: {audio}")
        audio_array = whisperx.load_audio(audio)
    else:
        audio_array = audio

    audio_duration_s = round(len(audio_array) / 16000, 2)
    rms = float(np.sqrt(np.mean(audio_array ** 2)))

    if rms < SILENCE_RMS_THRESHOLD:
        logger.warning(
            f"Аудио почти беззвучное (RMS={rms:.5f} < {SILENCE_RMS_THRESHOLD}). "
            f"Транскрипция пропущена во избежание галлюцинаций."
        )
        return {
            "text": "",
            "segments": [],
            "word_segments": [],
            "audio_duration_s": audio_duration_s,
            "language": language or "ru",
            "warning": "silent_audio",
        }

    logger.info(f"Транскрипция (VAD={'вкл' if vad_filter else 'выкл'}, batch_size={batch_size})...")
    transcribe_kwargs = {
        "language": language,
        "batch_size": batch_size,
    }
    result = model.transcribe(audio_array, **transcribe_kwargs)
    segments = result.get("segments", [])

    segments = filter_hallucinations(segments)

    full_text = " ".join(s.get("text", "").strip() for s in segments if s.get("text"))
    logger.info(f"Forced alignment на устройстве: {ALIGN_DEVICE}...")
    align_language = language or result.get("language", "ru")
    align_model, align_meta = load_align_model(align_language, ALIGN_DEVICE)
    try:
        aligned = whisperx.align(
            segments,
            align_model,
            align_meta,
            audio_array,
            ALIGN_DEVICE,
            return_char_alignments=False,
        )
    except Exception as e:
        if ALIGN_DEVICE != "cpu":
            logger.warning(f"Alignment на {ALIGN_DEVICE} не удался: {e}. Переключаемся на CPU...")
            align_model_cpu, align_meta_cpu = load_align_model(align_language, "cpu")
            aligned = whisperx.align(
                segments,
                align_model_cpu,
                align_meta_cpu,
                audio_array,
                "cpu",
                return_char_alignments=False,
            )
        else:
            raise
    word_segments = trim_and_filter(aligned.get("word_segments", []))
    logger.info(
        f"Транскрипция успешно завершена. "
        f"Слов с таймкодами: {len(word_segments)} | "
        f"Длительность: {audio_duration_s:.2f} сек | "
        f"Язык: {result.get('language', language)}"
    )
    return {
        "text": full_text.strip(),
        "segments": segments,
        "word_segments": word_segments,
        "audio_duration_s": audio_duration_s,
        "language": result.get("language", language or "ru"),
    }


def load_audio(audio_path: str) -> np.ndarray:
    return whisperx.load_audio(audio_path)