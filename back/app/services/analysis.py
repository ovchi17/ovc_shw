from __future__ import annotations
import asyncio
import logging
import time
import traceback
from datetime import datetime
from pathlib import Path
from sqlalchemy.orm import Session
from app.core.database import SessionLocal
from app.models.recording import Recording, AnalysisResult, AnalysisModuleResult
from app.services import task_store
from pipeline.audio_enhance import enhance, cleanup_enhanced
from pipeline.transcribe import transcribe
from pipeline.speech_analyzer import analyze as speech_analyze

log = logging.getLogger(__name__)

def run_and_save(
        db: Session,
        recording: Recording,
        *,
        on_progress=None,
) -> AnalysisResult:

    def progress(status: str, pct: int, message: str) -> None:
        if on_progress:
            on_progress(status, pct, message)

    log.info("=== [analysis] START recording_id=%s file=%s", recording.id, recording.file_path)
    t_total_start = time.time()

    progress("enhancing", 8, "Подавление шума и нормализация звука...")
    log.info("[analysis] Шаг 0 — предобработка аудио...")
    t0 = time.time()
    enhanced_path = enhance(recording.file_path)
    enhance_sec = round(time.time() - t0, 2)

    progress("transcribing", 20, "Транскрипция аудио...")
    log.info("[analysis] Шаг 1 — транскрипция...")
    t0 = time.time()
    try:
        tr = transcribe(enhanced_path)
    except Exception as e:
        log.error("[analysis] ОШИБКА транскрипции: %s", e)
        raise
    finally:
        cleanup_enhanced(enhanced_path, recording.file_path)
    transcribe_sec = round(time.time() - t0, 2)

    text = tr.get("text", "")
    words = tr.get("word_segments", [])
    log.info(
        "[analysis] Транскрипция готова: слов=%d, символов=%d, длина=%.1f сек",
        len(words), len(text), tr.get("audio_duration_s", 0),
    )

    progress("analyzing", 40, "Начинаем анализ речи...")

    def speech_cb(msg: str, pct: int) -> None:
        mapped = 40 + int(pct * 0.55)
        progress("analyzing", mapped, msg)

    try:
        user_fillers = recording.user.custom_fillers or []
    except Exception:
        user_fillers = []

    t0 = time.time()
    try:
        sa_result = speech_analyze(tr, progress_callback=speech_cb,
                                   extra_static_fillers=user_fillers)
    except Exception as e:
        log.error("[analysis] ОШИБКА speech_analyzer: %s\n%s", e, traceback.format_exc())
        raise
    analyze_sec = round(time.time() - t0, 2)

    modules = sa_result.get("modules", {})
    r_par = modules.get("parasites", {})
    r_pau = modules.get("pauses", {})
    r_tem = modules.get("tempo", {})
    r_lex = modules.get("lexical", {})
    r_syn = modules.get("syntax", {})

    log.info(
        "[analysis] Баллы: par=%.1f pau=%.1f tem=%.1f lex=%.1f syn=%.1f → overall=%.1f",
        r_par.get("score", 0), r_pau.get("score", 0), r_tem.get("score", 0),
        r_lex.get("score", 0), r_syn.get("score", 0), sa_result.get("overall_score", 0),
    )

    progress("saving", 96, "Сохранение результатов...")
    log.info("[analysis] Шаг 7 — сохранение в БД...")
    t0 = time.time()
    existing = recording.analysis
    result = existing or AnalysisResult(recording_id=recording.id)
    result.total_score = round(sa_result.get("overall_score", 0))
    result.timecodes = build_timecodes(r_par, r_pau)
    result.transcript = build_annotated_transcript(words)
    result.analyzed_at = datetime.utcnow()
    save_sec = round(time.time() - t0, 2)
    total_sec = round(time.time() - t_total_start, 2)
    result.processing_times = {
        "enhance_sec": enhance_sec,
        "transcribe_sec": transcribe_sec,
        "analyze_sec": analyze_sec,
        "save_sec": save_sec,
        "total_sec": total_sec,
    }
    log.info("[analysis] Время обработки: enhance=%.1fs transcribe=%.1fs analyze=%.1fs total=%.1fs",
             enhance_sec, transcribe_sec, analyze_sec, total_sec)
    db.add(result)
    module_data = {
        "parasites": r_par,
        "pauses": r_pau,
        "tempo": r_tem,
        "lexical": r_lex,
        "syntax": r_syn,
    }
    db.flush()
    for mod_name, mod_dict in module_data.items():
        mod_row = next((m for m in result.modules if m.module == mod_name), None)
        if mod_row is None:
            mod_row = AnalysisModuleResult(analysis_id=result.id, module=mod_name)
            result.modules.append(mod_row)
        mod_row.score = round(mod_dict.get("score", 0))
        mod_row.details = mod_dict
    recording.status = "done"
    db.commit()
    db.refresh(result)
    log.info(
        "=== [analysis] DONE recording_id=%s analysis_id=%s overall=%d",
        recording.id, result.id, result.total_score,
    )
    return result


def build_timecodes(parasites_r: dict, pauses_r: dict) -> list[dict]:
    timecodes: list[dict] = []
    for tc in parasites_r.get("filler_timecodes") or []:
        timecodes.append({
            "type": "parasite",
            "start": tc["start"],
            "end": tc["end"],
            "description": f"Слово-паразит «{tc['word']}»",
        })
    for tc in pauses_r.get("medium_pause_timecodes") or []:
        secs = tc["duration_ms"] / 1000
        timecodes.append({
            "type": "pause",
            "start": tc["start"],
            "end": tc["end"],
            "description": f"Пауза {secs:.1f} сек",
        })
    for tc in pauses_r.get("long_pause_timecodes") or []:
        secs = tc["duration_ms"] / 1000
        timecodes.append({
            "type": "pause",
            "start": tc["start"],
            "end": tc["end"],
            "description": f"Длинная пауза {secs:.1f} сек",
        })

    timecodes.sort(key=lambda x: x["start"])
    return timecodes


def build_annotated_transcript(
        word_segments: list[dict]) -> str:
    if not word_segments:
        return ""

    LONG_THRESHOLD = 1.000
    MEDIUM_THRESHOLD = 0.200
    MIN_GAP = 0.050

    result: list[str] = []
    for i, w in enumerate(word_segments):
        word = (w.get("word") or "").strip()
        if not word:
            continue
        result.append(word)
        if i < len(word_segments) - 1:
            gap = word_segments[i + 1].get("start", 0) - w.get("end", 0)
            if gap >= LONG_THRESHOLD:
                result.append(f"[LP:{gap:.1f}]")
            elif gap >= MEDIUM_THRESHOLD and gap > MIN_GAP:
                result.append(f"[MP:{gap:.1f}]")

    return " ".join(result)


def delete_audio_files(file_path: str | None) -> None:
    if not file_path:
        return
    p = Path(file_path)
    for candidate in [p, p.parent / (p.stem + "_play.mp3")]:
        try:
            if candidate.exists():
                candidate.unlink()
        except Exception:
            pass

async def run_analysis_background(task_id: str, recording_id: int) -> None:
    log.info("[bg] task_id=%s recording_id=%s", task_id, recording_id)
    db = SessionLocal()
    try:
        recording = db.get(Recording, recording_id)
        if recording is None:
            log.error("[bg] Запись %s не найдена", recording_id)
            task_store.update(task_id, status="error", error="Запись не найдена")
            return
        task_store.update(task_id, status="transcribing", progress_pct=10,
                          message="Загрузка модели...")
        def on_progress(status: str, pct: int, message: str) -> None:
            task_store.update(task_id, status=status, progress_pct=pct, message=message)
        import functools
        loop = asyncio.get_running_loop()
        result = await loop.run_in_executor(
            None,
            functools.partial(run_and_save, db, recording, on_progress=on_progress),
        )
        task_store.update(
            task_id, status="done", progress_pct=100,
            message="Анализ завершён", analysis_id=result.id,
        )
        log.info("[bg] DONE task_id=%s analysis_id=%s", task_id, result.id)
    except Exception as e:
        log.error("[bg] ОШИБКА task_id=%s: %s\n%s", task_id, e, traceback.format_exc())
        task_store.update(task_id, status="error", error=str(e))
        db.rollback()
        try:
            rec = db.get(Recording, recording_id)
            if rec:
                delete_audio_files(rec.file_path)
                db.delete(rec)
                db.commit()
        except Exception:
            pass
    finally:
        db.close()
