import asyncio
import functools
import uuid
from pathlib import Path as FsPath

from fastapi import APIRouter, Depends, Path, Query, UploadFile, File, HTTPException
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.deps import get_current_user, get_user_recording, to_iso_utc
from app.models.user import User
from app.models.recording import Recording, AnalysisResult
from app.schemas.common import ApiResponse
from app.schemas.recordings import (
    RecordingShort, CompareData, CompareParam,
    UploadOut, TaskStatus,
)
from app.schemas.analysis import AnalysisDetail
from app.services.audio import save_upload, get_duration, create_playback_file, get_playback_path
from app.services import task_store
from app.services.analysis import run_analysis_background
from app.services.mappers import analysis_to_detail

router = APIRouter(tags=["recordings"])


@router.get("/recordings", response_model=ApiResponse[list[RecordingShort]])
async def list_recordings(
        limit: int = Query(20, ge=1, le=100, description="Максимальное количество записей"),
        offset: int = Query(0, ge=0, description="Смещение для пагинации"),
        current_user: User = Depends(get_current_user),
        db: Session = Depends(get_db),
):
    recs = (
        db.query(Recording)
        .filter_by(user_id=current_user.id)
        .filter(Recording.status != "error")
        .order_by(Recording.created_at.desc())
        .offset(offset)
        .limit(limit)
        .all()
    )

    result = []
    prev_score = None
    for rec in reversed(recs):
        score = rec.analysis.total_score if rec.analysis else None
        delta = (score - prev_score) if (score is not None and prev_score is not None) else None
        result.append(RecordingShort(
            id=rec.id,
            title=f"Запись #{rec.id}",
            score=score,
            score_change=delta,
            duration_sec=rec.duration_sec or 0.0,
            created_at=to_iso_utc(rec.created_at),
            status=rec.status,
            analysis_id=rec.analysis.id if rec.analysis else None,
            audio_url=f"/api/v1/recordings/{rec.id}/audio",
        ))
        if score is not None:
            prev_score = score
    result.reverse()
    return ApiResponse.ok(result)


@router.get("/recordings/compare", response_model=ApiResponse[CompareData])
async def compare_recordings(
        recording_a: int = Query(..., description="analysis_id первой записи"),
        recording_b: int = Query(..., description="analysis_id второй записи"),
        current_user: User = Depends(get_current_user),
        db: Session = Depends(get_db),
):
    rec_a = get_user_recording(db, recording_a, current_user.id)
    rec_b = get_user_recording(db, recording_b, current_user.id)

    def short(r: Recording, delta: int | None) -> RecordingShort:
        sc = r.analysis.total_score if r.analysis else None
        return RecordingShort(
            id=r.id, title=f"Запись #{r.id}",
            score=sc, score_change=delta,
            duration_sec=r.duration_sec or 0.0,
            created_at=to_iso_utc(r.created_at),
            status=r.status,
        )

    sc_a = rec_a.analysis.total_score if rec_a.analysis else 0
    sc_b = rec_b.analysis.total_score if rec_b.analysis else 0
    total_delta = sc_b - sc_a
    param_keys = [
        ("parasites", "Слова-паразиты", "score_parasites", "details_parasites",
         ["score_filler_proc", "score_density", "score_unique", "score_consecutive"]),
        ("pauses", "Паузы", "score_pauses", "details_pauses",
         ["score_ptr", "score_mlr", "score_long_pct", "score_max_pause", "score_medium_pct", "score_filled"]),
        ("tempo", "Темп", "score_tempo", "details_tempo",
         ["score_cv", "score_speech_rate", "score_articulation_rate"]),
        ("lexical", "Лексика", "score_lexical", "details_lexical",
         ["score_mattr", "score_mtld", "score_top_repeat_pct"]),
        ("syntax", "Синтаксис", "score_syntax", "details_syntax",
         ["score_mean_utterance_length", "score_embedding_depth", "score_mean_dep_distance",
          "score_clauses_per_sentence", "score_complex_sentences_ratio", ]),
    ]
    KEY_ALIASES = {
        "score_top_repeat_pct": "score_top_repeat_perc",
    }

    def extract_sub(analysis, details_attr: str, sub_keys: list[str]) -> dict[str, float]:
        if not analysis:
            return {}
        details = getattr(analysis, details_attr, None) or {}
        return {
            k: float(v)
            for k in sub_keys
            if (v := details.get(k) or details.get(KEY_ALIASES.get(k, k)))
        }
    METRIC_KEYS = {
        "parasites": [
            ("Всего", "total_filler_occurrences", lambda v: f"{int(v)} раз"),
            ("Доля речи", "filler_proc", lambda v: f"{v:.1f}%"),
            ("Плотность", "filler_density_per_minute", lambda v: f"{v:.1f} раз/мин"),
            ("Разных типов", "unique_filler_types", lambda v: str(int(v))),
        ],
        "pauses": [
            ("PTR (доля речи)", "ptr", lambda v: f"{v:.0f}%"),
            ("Темп речи", "speech_rate", lambda v: f"{v:.0f} сл/мин"),
            ("Макс. пауза", "max_pause_ms", lambda v: f"{v / 1000:.1f} с"),
            ("Длинных пауз (>1 с)", "long_pause_count", lambda v: f"{int(v)} шт."),
            ("Средних пауз (0.2–1 с)", "medium_pause_count", lambda v: f"{int(v)} шт."),
        ],
        "tempo": [
            ("Темп речи", "speech_rate", lambda v: f"{v:.0f} сл/мин"),
            ("Артикуляция", "articulation_rate", lambda v: f"{v:.0f} сл/мин"),
            ("Вариативность", "window_cv", lambda v: f"{v:.2f}"),
        ],
        "lexical": [
            ("MATTR", "mattr", lambda v: f"{v:.3f}"),
            ("MTLD", "mtld", lambda v: f"{v:.1f}"),
            ("Повторений", "top_repeat_perc", lambda v: f"{v:.1f}%"),
        ],
        "syntax": [
            ("Длина фраз", "mean_utterance_length", lambda v: f"{v:.1f} слова"),
            ("Глубина", "embedding_depth", lambda v: f"{v:.1f}"),
            ("Клаузы/предл.", "clauses_per_sentence", lambda v: f"{v:.2f}"),
            ("Сложные предл.", "complex_sentences_ratio", lambda v: f"{v:.0f}%"),
        ],
    }

    def extract_extra_metrics(analysis, details_attr: str, param_key: str) -> dict[str, str]:
        if not analysis:
            return {}
        details = getattr(analysis, details_attr, None) or {}
        result = {}
        for label, raw_key, fmt in METRIC_KEYS.get(param_key, []):
            v = details.get(raw_key)
            if v is not None and v != 0:
                try:
                    result[label] = fmt(float(v))
                except Exception:
                    pass
        return result

    params = []
    for key, title, attr, details_attr, sub_keys in param_keys:
        va = getattr(rec_a.analysis, attr, 0) or 0 if rec_a.analysis else 0
        vb = getattr(rec_b.analysis, attr, 0) or 0 if rec_b.analysis else 0
        params.append(CompareParam(
            key=key, title=title, score_a=va, score_b=vb, delta=vb - va,
            sub_scores_a=extract_sub(rec_a.analysis, details_attr, sub_keys),
            sub_scores_b=extract_sub(rec_b.analysis, details_attr, sub_keys),
            extra_metrics_a=extract_extra_metrics(rec_a.analysis, details_attr, key),
            extra_metrics_b=extract_extra_metrics(rec_b.analysis, details_attr, key),
        ))

    return ApiResponse.ok(CompareData(
        recording_a=short(rec_a, None),
        recording_b=short(rec_b, total_delta),
        parameters=params,
        total_delta=total_delta,
    ))


@router.get("/recordings/status/{task_id}", response_model=ApiResponse[TaskStatus])
async def get_task_status(
        task_id: str = Path(..., description="UUID задачи из ответа /upload"),
):
    info = task_store.get(task_id)
    if info is None:
        raise HTTPException(404, "Задача не найдена")
    return ApiResponse.ok(TaskStatus(
        task_id=info.task_id,
        recording_id=info.recording_id,
        status=info.status,
        progress_pct=info.progress_pct,
        message=info.message,
        analysis_id=info.analysis_id,
        error=info.error,
    ))


@router.get("/recordings/{recording_id}/audio", response_class=FileResponse)
async def get_audio(
        recording_id: int = Path(...),
        current_user: User = Depends(get_current_user),
        db: Session = Depends(get_db),
):
    rec = get_user_recording(db, recording_id, current_user.id)

    play_path = get_playback_path(rec.file_path) if rec.file_path else None
    if play_path:
        return FileResponse(play_path, media_type="audio/mpeg",
                            filename=f"recording_{recording_id}.mp3")

    if rec.file_path and FsPath(rec.file_path).exists():
        ext = FsPath(rec.file_path).suffix.lower().lstrip(".")
        MIME = {
            "mp3": "audio/mpeg", "wav": "audio/wav", "m4a": "audio/mp4",
            "ogg": "audio/ogg", "webm": "audio/webm", "aac": "audio/aac",
        }
        return FileResponse(
            rec.file_path,
            media_type=MIME.get(ext, "audio/mpeg"),
            filename=f"recording_{recording_id}.{ext}",
        )

    raise HTTPException(404, "Аудиофайл не найден на сервере")


@router.post("/recordings/upload", response_model=ApiResponse[UploadOut], status_code=202)
async def upload_recording( file: UploadFile = File(...),current_user: User = Depends(get_current_user),
        db: Session = Depends(get_db)):
    filename, file_path = await save_upload(file, current_user.id)
    duration = get_duration(file_path)
    loop = asyncio.get_event_loop()
    loop.run_in_executor(None, functools.partial(create_playback_file, file_path))
    recording = Recording(
        user_id=current_user.id,
        filename=filename,
        file_path=file_path,
        duration_sec=duration,
        status="processing",
    )
    db.add(recording)
    db.commit()
    db.refresh(recording)
    task_id = str(uuid.uuid4())
    task_store.create(task_id, recording.id)
    task_store.update(task_id, status="transcribing", progress_pct=10,
                      message="Транскрипция аудио...")
    try:
        asyncio.create_task(run_analysis_background(task_id, recording.id))
    except Exception as e:
        task_store.update(task_id, status="error", error=str(e),
                          message="Ошибка запуска анализа")

    return ApiResponse.ok(UploadOut(recording_id=recording.id, task_id=task_id))


@router.get("/analysis/{analysis_id}", response_model=ApiResponse[AnalysisDetail])
async def get_analysis(
        analysis_id: int = Path(...),
        current_user: User = Depends(get_current_user),
        db: Session = Depends(get_db),
):
    result = db.get(AnalysisResult, analysis_id)
    if result is None or result.recording.user_id != current_user.id:
        raise HTTPException(404, "Анализ не найден")
    audio_url = f"/api/v1/recordings/{result.recording_id}/audio"
    return ApiResponse.ok(analysis_to_detail(result, audio_url=audio_url))
