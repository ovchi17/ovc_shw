from __future__ import annotations
import logging
import subprocess
from pathlib import Path
log = logging.getLogger(__name__)
FILTER_CHAIN = ",".join([
    "highpass=f=80",
    "afftdn=nf=-25",
    "loudnorm",
])


def enhance(input_path: str) -> str:
    inp = Path(input_path)
    out = inp.with_suffix(".enhanced.wav")

    cmd = [
        "ffmpeg",
        "-y",
        "-i", str(inp),
        "-af", FILTER_CHAIN,
        "-ac", "1",
        "-ar", "16000",
        "-c:a", "pcm_s16le",
        str(out),
    ]

    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=180,
        )
        if proc.returncode != 0:
            log.warning(
                "[enhance] ffmpeg завершился с ошибкой (code=%d): %s",
                proc.returncode,
                proc.stderr[-400:],
            )
            return input_path

        size_kb = out.stat().st_size // 1024
        log.info("[enhance] OK  %s → %s (%d КБ)", inp.name, out.name, size_kb)
        return str(out)

    except FileNotFoundError:
        log.warning("[enhance] ffmpeg не найден — пропускаем предобработку")
        return input_path
    except subprocess.TimeoutExpired:
        log.warning("[enhance] ffmpeg превысил таймаут — пропускаем предобработку")
        return input_path
    except Exception as e:
        log.warning("[enhance] Неожиданная ошибка: %s — пропускаем предобработку", e)
        return input_path


def cleanup_enhanced(enhanced_path: str, original_path: str) -> None:
    if enhanced_path != original_path:
        try:
            Path(enhanced_path).unlink(missing_ok=True)
        except Exception:
            pass
