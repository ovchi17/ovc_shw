from datetime import date, timedelta
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.deps import get_current_user
from app.models.user import User
from app.models.recording import Recording, AnalysisResult
from app.schemas.common import ApiResponse
from app.schemas.user import (
    UserMe, ProfileStats, Goal, WeeklyReport, WeeklyDay, UpdateProfileRequest,
    FillerItem, FillersOut,
)
from app.services.dashboard import build_user_me, calc_streak

router = APIRouter(prefix="/user", tags=["user"])


@router.patch("/me", response_model=ApiResponse[UserMe])
async def update_me(
        body: UpdateProfileRequest,
        current_user: User = Depends(get_current_user),
        db: Session = Depends(get_db),
):
    if body.name is not None:
        name = body.name.strip()
        if not name:
            raise HTTPException(400, "Имя не может быть пустым")
        current_user.name = name
    db.commit()
    db.refresh(current_user)
    return ApiResponse.ok(build_user_me(current_user, db))


@router.get("/profile", response_model=ApiResponse[ProfileStats])
async def get_profile(
        current_user: User = Depends(get_current_user),
        db: Session = Depends(get_db),
):
    analyses = (
        db.query(AnalysisResult)
        .join(Recording)
        .filter(Recording.user_id == current_user.id)
        .all()
    )
    scores = [a.total_score for a in analyses]
    total_dur = (
                    db.query(func.sum(Recording.duration_sec))
                    .filter_by(user_id=current_user.id, status="done")
                    .scalar()
                ) or 0

    return ApiResponse.ok(ProfileStats(
        id=current_user.id,
        name=current_user.name,
        avatar=current_user.name[0].upper(),
        streak=calc_streak(db, current_user.id),
        total_recordings=len(scores),
        best_score=max(scores) if scores else 0,
        avg_score=round(sum(scores) / len(scores)) if scores else 0,
        total_minutes=int(total_dur / 60),
        member_since=current_user.created_at.date().isoformat(),
    ))


@router.get("/goals", response_model=ApiResponse[Goal])
async def get_goals(
        current_user: User = Depends(get_current_user),
        db: Session = Depends(get_db),
):
    today = date.today()
    month_start = today.replace(day=1)

    recs_this_month = (
        db.query(Recording)
        .filter(
            Recording.user_id == current_user.id,
            Recording.status == "done",
            func.date(Recording.created_at) >= month_start,
        )
        .count()
    )

    latest = (
        db.query(AnalysisResult)
        .join(Recording)
        .filter(Recording.user_id == current_user.id)
        .order_by(AnalysisResult.analyzed_at.desc())
        .first()
    )

    if today.month == 12:
        next_month = today.replace(year=today.year + 1, month=1, day=1)
    else:
        next_month = today.replace(month=today.month + 1, day=1)

    recordings_target = 20
    return ApiResponse.ok(Goal(
        target_score=80,
        current_score=latest.total_score if latest else 0,
        recordings_done=recs_this_month,
        recordings_target=recordings_target,
        days_left=(next_month - today).days,
        progress_pct=min(round(recs_this_month / recordings_target * 100), 100),
    ))


@router.get("/weekly", response_model=ApiResponse[WeeklyReport])
async def get_weekly_report(
        current_user: User = Depends(get_current_user),
        db: Session = Depends(get_db),
):
    today = date.today()
    week_start = today - timedelta(days=6)

    recs = (
        db.query(Recording)
        .filter(
            Recording.user_id == current_user.id,
            Recording.status == "done",
            func.date(Recording.created_at) >= week_start,
            func.date(Recording.created_at) <= today,
        )
        .order_by(Recording.created_at.asc())
        .all()
    )

    by_date: dict[str, list] = {}
    for r in recs:
        d = r.created_at.date().isoformat()
        by_date.setdefault(d, []).append(r)

    days = []
    for i in range(7):
        d = (week_start + timedelta(days=i)).isoformat()
        day_recs = by_date.get(d, [])
        scores = [r.analysis.total_score for r in day_recs if r.analysis]
        days.append(WeeklyDay(
            date=d,
            score=round(sum(scores) / len(scores)) if scores else None,
            has_recording=len(day_recs) > 0,
        ))

    all_scores = [r.analysis.total_score for r in recs if r.analysis]

    # Предыдущие 7 дней для расчёта улучшения
    prev_start = week_start - timedelta(days=7)
    prev_recs = (
        db.query(AnalysisResult)
        .join(Recording)
        .filter(
            Recording.user_id == current_user.id,
            Recording.status == "done",
            func.date(Recording.created_at) >= prev_start,
            func.date(Recording.created_at) < week_start,
        )
        .all()
    )
    prev_scores = [r.total_score for r in prev_recs]
    prev_avg = round(sum(prev_scores) / len(prev_scores)) if prev_scores else None
    curr_avg = round(sum(all_scores) / len(all_scores)) if all_scores else None
    improvement = (curr_avg - prev_avg) if (curr_avg is not None and prev_avg is not None) else None

    return ApiResponse.ok(WeeklyReport(
        week_start=week_start.isoformat(),
        week_end=today.isoformat(),
        avg_score=curr_avg,
        best_score=max(all_scores) if all_scores else None,
        recordings_count=len(recs),
        days=days,
        improvement=improvement,
    ))


def load_fillers(user: User) -> list[str]:
    return user.custom_fillers or []


def save_fillers(user: User, fillers: list[str], db: Session) -> None:
    user.custom_fillers = fillers
    db.commit()


@router.get("/fillers", response_model=ApiResponse[FillersOut])
async def get_fillers(
    current_user: User = Depends(get_current_user),
):
    return ApiResponse.ok(FillersOut(fillers=load_fillers(current_user)))


@router.post("/fillers", response_model=ApiResponse[FillersOut])
async def add_filler(
    body: FillerItem,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    fillers = load_fillers(current_user)
    if body.word not in fillers:
        if len(fillers) >= 50:
            raise HTTPException(400, "Максимум 50 пользовательских паразитов")
        fillers.append(body.word)
        save_fillers(current_user, fillers, db)
    return ApiResponse.ok(FillersOut(fillers=fillers))


@router.delete("/fillers/{word}", response_model=ApiResponse[FillersOut])
async def remove_filler(
    word: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    fillers = load_fillers(current_user)
    fillers = [f for f in fillers if f != word.lower().strip()]
    save_fillers(current_user, fillers, db)
    return ApiResponse.ok(FillersOut(fillers=fillers))
