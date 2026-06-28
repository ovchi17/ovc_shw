from __future__ import annotations
import logging
import subprocess
import uuid
from pathlib import Path

from fastapi import UploadFile, HTTPException

from app.core.config import settings

log = logging.getLogger(__name__)


def project_root() -> Path:
    return Path(__file__).parent.parent.parent


def user_upload_dir(user_id: int) -> Path:
    base = settings.upload_dir
    if not base.is_absolute():
        base = project_root() / base
    path = base / str(user_id)
    path.mkdir(parents=True, exist_ok=True)
    return path


async def save_upload(file: UploadFile, user_id: int) -> tuple[str, str]:
    ext = (file.filename or "").rsplit(".", 1)[-1].lower()
    if ext not in settings.allowed_audio_formats:
        raise HTTPException(400, f"Формат .{ext} не поддерживается")

    content = await file.read()
    if len(content) > settings.max_audio_size_mb * 1024 * 1024:
        raise HTTPException(413, f"Файл превышает {settings.max_audio_size_mb} МБ")

    filename = f"{uuid.uuid4()}.{ext}"
    dest     = user_upload_dir(user_id) / filename
    dest.write_bytes(content)
    return filename, str(dest)


def get_duration(file_path: str) -> float | None:
    try:
        from mutagen import File as MutagenFile
        audio = MutagenFile(file_path)
        if audio is not None and audio.info is not None:
            return float(audio.info.length)
    except Exception:
        pass
    return None


def create_playback_file(original_path: str) -> str | None:
    inp = Path(original_path)
    out = inp.parent / (inp.stem + "_play.mp3")

    AF = "highpass=f=80,afftdn=nf=-25,loudnorm=I=-16:LRA=11:TP=-1.5"
    cmd = [
        "ffmpeg", "-y",
        "-i", str(inp),
        "-af", AF,
        "-ac", "2",
        "-ar", "44100",
        "-c:a", "libmp3lame",
        "-b:a", "128k",
        str(out),
    ]

    try:
        proc = subprocess.run(cmd, capture_output=True, timeout=120)
        if proc.returncode == 0:
            log.info("[audio] playback file created: %s", out.name)
            return str(out)
        log.warning(
            "[audio] ffmpeg failed (code=%d): %s",
            proc.returncode,
            proc.stderr[-300:].decode(errors="replace"),
        )
    except (FileNotFoundError, subprocess.TimeoutExpired) as e:
        log.warning("[audio] ffmpeg unavailable: %s", e)
    except Exception as e:
        log.warning("[audio] unexpected error in create_playback_file: %s", e)

    return None


def get_playback_path(file_path: str) -> str | None:
    play = Path(file_path).parent / (Path(file_path).stem + "_play.mp3")
    return str(play) if play.exists() else None
