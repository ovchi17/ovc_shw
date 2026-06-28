from __future__ import annotations
from datetime import date, timedelta
from sqlalchemy.orm import Session
from sqlalchemy import func
from app.models.recording import Recording, AnalysisResult
from app.models.user import User
from app.schemas.user import UserMe


def build_user_me(user: User, db: Session) -> UserMe:
    return UserMe(
        id=user.id,
        name=user.name,
        avatar=user.name[0].upper(),
        streak=calc_streak(db, user.id),
        total_recordings=db.query(Recording).filter_by(
            user_id=user.id, status="done"
        ).count(),
        email=user.email,
    )


def get_latest_analysis(db: Session, user_id: int) -> AnalysisResult | None:
    return (
        db.query(AnalysisResult)
        .join(Recording)
        .filter(Recording.user_id == user_id, Recording.status == "done")
        .order_by(AnalysisResult.analyzed_at.desc())
        .first()
    )


def get_previous_analysis(db: Session, user_id: int, before_id: int) -> AnalysisResult | None:
    return (
        db.query(AnalysisResult)
        .join(Recording)
        .filter(Recording.user_id == user_id, AnalysisResult.id < before_id)
        .order_by(AnalysisResult.id.desc())
        .first()
    )


def calc_streak(db: Session, user_id: int) -> int:
    streak = 0
    day    = date.today()
    while True:
        has = db.query(Recording).filter(
            Recording.user_id == user_id,
            func.date(Recording.created_at) == day,
            Recording.status == "done",
        ).first()
        if has is None:
            break
        streak += 1
        day    -= timedelta(days=1)
    return streak


def group_recordings_by_date(recs: list[Recording]) -> dict[str, list[Recording]]:
    by_date: dict[str, list[Recording]] = {}
    for r in recs:
        d = r.created_at.date().isoformat()
        by_date.setdefault(d, []).append(r)
    return by_date


def get_recordings_in_period(db: Session, user_id: int, days: int) -> list[Recording]:
    since = date.today() - timedelta(days=days)
    return (
        db.query(Recording)
        .filter(
            Recording.user_id == user_id,
            Recording.status  == "done",
            func.date(Recording.created_at) >= since,
        )
        .order_by(Recording.created_at.asc())
        .all()
    )
