from datetime import date, timedelta
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.deps import get_current_user
from app.models.user import User
from app.models.recording import Recording
from app.schemas.common import ApiResponse
from app.schemas.progress import (
    ProgressOverview, DynamicsData, DynamicsPoint,
    ActivityData, ActivityDay, TipsData,
)
from app.services.dashboard import (
    calc_streak, get_recordings_in_period, get_latest_analysis,
    group_recordings_by_date,
)
from app.services.recommendations import get_tips_and_exercises

router = APIRouter(tags=["progress"])

PERIOD_DAYS: dict[str, int] = {"7d": 7, "30d": 30, "90d": 90, "all": 36500}


def recs_for_period(db: Session, user_id: int, period: str) -> list[Recording]:
    if period == "all":
        return (
            db.query(Recording)
            .filter(Recording.user_id == user_id, Recording.status == "done")
            .order_by(Recording.created_at.asc())
            .all()
        )
    days = PERIOD_DAYS.get(period, 30)
    return get_recordings_in_period(db, user_id, days)


@router.get("/progress/overview", response_model=ApiResponse[ProgressOverview])
async def get_progress_overview(
        period: str = Query("30d", description="Период: 7d | 30d | 90d | all"),
        current_user: User = Depends(get_current_user),
        db: Session = Depends(get_db),
):
    recs = recs_for_period(db, current_user.id, period)
    done = [r for r in recs if r.analysis]
    current_score = done[-1].analysis.total_score if done else 0
    first_score = done[0].analysis.total_score if done else 0

    return ApiResponse.ok(ProgressOverview(
        current_score=current_score,
        score_change=current_score - first_score,
        streak=calc_streak(db, current_user.id),
        total_recordings=len(done),
        period_days=PERIOD_DAYS.get(period, 30),
    ))


@router.get("/progress/dynamics", response_model=ApiResponse[DynamicsData])
async def get_dynamics(
        period: str = Query("30d", description="Период: 7d | 30d | 90d | all"),
        current_user: User = Depends(get_current_user),
        db: Session = Depends(get_db),
):
    recs = recs_for_period(db, current_user.id, period)
    done = [r for r in recs if r.analysis]
    by_date = group_recordings_by_date(done)

    points = [
        DynamicsPoint(
            date=d,
            score=round(sum(r.analysis.total_score for r in recs_day) / len(recs_day)),
            recording_id=recs_day[-1].id,
        )
        for d, recs_day in sorted(by_date.items())
    ]

    avg = round(sum(p.score for p in points) / len(points)) if points else None
    trend = "stable"
    if len(points) >= 4:
        mid = len(points) // 2
        first_avg = sum(p.score for p in points[:mid]) / mid
        second_avg = sum(p.score for p in points[mid:]) / (len(points) - mid)
        if second_avg - first_avg > 3:
            trend = "up"
        elif first_avg - second_avg > 3:
            trend = "down"

    return ApiResponse.ok(DynamicsData(period=period, points=points,
                                       avg_score=avg, trend=trend))


@router.get("/progress/activity", response_model=ApiResponse[ActivityData])
async def get_activity(
        current_user: User = Depends(get_current_user),
        db: Session = Depends(get_db),
):
    recs = get_recordings_in_period(db, current_user.id, 30)
    by_date = group_recordings_by_date(recs)

    days = []
    current = date.today() - timedelta(days=30)
    today = date.today()
    while current <= today:
        ds = current.isoformat()
        day_recs = by_date.get(ds, [])
        scores = [r.analysis.total_score for r in day_recs if r.analysis]
        days.append(ActivityDay(
            date=ds,
            count=len(day_recs),
            score=round(sum(scores) / len(scores)) if scores else None,
        ))
        current += timedelta(days=1)

    active = sum(1 for d in days if d.count > 0)
    return ApiResponse.ok(ActivityData(days=days, total_active_days=active,
                                       total_recordings=len(recs)))


@router.get("/progress/parameter_dynamics")
async def get_parameter_dynamics(
        period: str = Query("30d", description="Период: 7d | 30d | 90d | all"),
        current_user: User = Depends(get_current_user),
        db: Session = Depends(get_db),
):
    recs = recs_for_period(db, current_user.id, period)
    done = [r for r in recs if r.analysis]
    sorted_days = sorted(group_recordings_by_date(done).items())

    def avg(attr: str) -> list[int]:
        return [
            round(sum(getattr(r.analysis, attr) or 0 for r in recs_day) / len(recs_day))
            for _, recs_day in sorted_days
        ]

    result: dict = {
        "parasites": avg("score_parasites"),
        "pauses":    avg("score_pauses"),
        "tempo":     avg("score_tempo"),
        "lexical":   avg("score_lexical"),
        "syntax":    avg("score_syntax"),
        "dates":     [d for d, _ in sorted_days],
    }

    if done:
        latest = done[-1].analysis
        sub_keys = {
            "parasites": ("details_parasites", ["score_filler_proc", "score_density",
                                                "score_unique", "score_consecutive"]),
            "pauses": ("details_pauses", ["score_ptr", "score_mlr", "score_long_pct",
                                          "score_max_pause", "score_medium_pct", "score_filled"]),
            "tempo": ("details_tempo", ["score_cv", "score_speech_rate",
                                        "score_articulation_rate"]),
            "lexical": ("details_lexical", ["score_mattr", "score_mtld",
                                            "score_top_repeat_perc"]),
            "syntax": ("details_syntax", ["score_mean_utterance_length", "score_embedding_depth",
                                          "score_mean_dep_distance", "score_clauses_per_sentence",
                                          "score_complex_sentences_ratio"]),
        }
        latest_sub = {}
        for param_key, (details_attr, keys) in sub_keys.items():
            details = getattr(latest, details_attr, None) or {}
            latest_sub[param_key] = {k: float(details[k]) for k in keys if details.get(k)}
        result["latest_sub_scores"] = latest_sub

    return ApiResponse.ok(result)


@router.get("/tips", response_model=ApiResponse[TipsData])
async def get_tips(
        current_user: User = Depends(get_current_user),
        db: Session = Depends(get_db),
):
    latest = get_latest_analysis(db, current_user.id)
    if latest is None:
        return ApiResponse.ok(TipsData(tips=[]),
                              message="Сделайте первую запись, чтобы получить советы")

    data = get_tips_and_exercises(db, latest)
    return ApiResponse.ok(TipsData(**data))
