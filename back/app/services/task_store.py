from __future__ import annotations
from dataclasses import dataclass
from typing import Optional

from app.core.database import SessionLocal
from app.models.recording import Task as TaskModel


@dataclass
class TaskInfo:
    task_id: str
    recording_id: int
    status: str = "queued"
    progress_pct: int = 0
    message: str = "В очереди..."
    analysis_id: Optional[int] = None
    error: Optional[str] = None


def to_info(t: TaskModel) -> TaskInfo:
    return TaskInfo(
        task_id=t.task_id,
        recording_id=t.recording_id,
        status=t.status,
        progress_pct=t.progress_pct,
        message=t.message,
        analysis_id=t.analysis_id,
        error=t.error,
    )


def create(task_id: str, recording_id: int) -> TaskInfo:
    db = SessionLocal()
    try:
        t = db.get(TaskModel, task_id)
        if t is None:
            t = TaskModel(task_id=task_id, recording_id=recording_id)
            db.add(t)
        else:
            t.recording_id = recording_id
            t.status       = "queued"
            t.progress_pct = 0
            t.message      = "В очереди..."
            t.analysis_id  = None
            t.error        = None
        db.commit()
        db.refresh(t)
        return to_info(t)
    finally:
        db.close()


def get(task_id: str) -> Optional[TaskInfo]:
    db = SessionLocal()
    try:
        t = db.get(TaskModel, task_id)
        return to_info(t) if t is not None else None
    finally:
        db.close()


def update(task_id: str, **kwargs) -> None:
    db = SessionLocal()
    try:
        t = db.get(TaskModel, task_id)
        if t is None:
            return
        for k, v in kwargs.items():
            if hasattr(t, k):
                setattr(t, k, v)
        db.commit()
    finally:
        db.close()
