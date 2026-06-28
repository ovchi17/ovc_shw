from __future__ import annotations
from pydantic import BaseModel


class RecordingShort(BaseModel):
    id: int
    title: str
    score: int | None
    score_change: int | None
    duration_sec: float
    created_at: str
    status: str
    analysis_id: int | None = None
    audio_url: str | None = None


class UploadOut(BaseModel):
    recording_id: int
    task_id: str
    message: str = "Аудио принято, анализ запущен"


class TaskStatus(BaseModel):
    task_id: str
    recording_id: int | None
    status: str
    progress_pct: int
    message: str
    analysis_id: int | None
    error: str | None


class CompareParam(BaseModel):
    key: str
    title: str
    score_a: int
    score_b: int
    delta: int
    sub_scores_a: dict[str, float] = {}
    sub_scores_b: dict[str, float] = {}
    extra_metrics_a: dict[str, str] = {}
    extra_metrics_b: dict[str, str] = {}


class CompareData(BaseModel):
    recording_a: RecordingShort
    recording_b: RecordingShort
    parameters: list[CompareParam]
    total_delta: int
