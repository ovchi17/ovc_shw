from datetime import date, datetime
from fastapi import APIRouter, Depends
from sqlalchemy import func
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.deps import get_current_user
from app.models.recording import Recording, AnalysisResult, AnalysisModuleResult
from app.models.user import User
from app.schemas.analysis import RadarData, Parameter
from app.schemas.common import ApiResponse
from app.schemas.progress import DashboardData
from app.schemas.user import UserMe
from app.core.deps import to_iso_utc
from app.services.dashboard import build_user_me, get_latest_analysis, get_previous_analysis
from app.services.mappers import parasites_desc, pauses_desc, tempo_desc, lexical_desc, syntax_desc

router = APIRouter(tags=["dashboard"])


@router.get("/user/me", response_model=ApiResponse[UserMe])
async def get_me(
        current_user: User = Depends(get_current_user),
        db: Session = Depends(get_db),
):
    return ApiResponse.ok(build_user_me(current_user, db))


@router.get("/dashboard", response_model=ApiResponse[DashboardData])
async def get_dashboard(
        current_user: User = Depends(get_current_user),
        db: Session = Depends(get_db),
):
    latest = get_latest_analysis(db, current_user.id)
    user_me = build_user_me(current_user, db)

    if latest is None:
        return ApiResponse.ok(DashboardData(
            user=user_me,
            score=0,
            score_change=0,
            has_recording_today=False,
            radar=RadarData(parasites=0, pauses=0, tempo=0, lexical=0, syntax=0),
            parameters=[],
            last_recording_at=None,
        ))

    previous = get_previous_analysis(db, current_user.id, latest.id)
    score_change = (latest.total_score - previous.total_score) if previous else 0

    def _avg(v) -> int:
        return round(v) if v is not None else 0
    avg_total = (
        db.query(func.avg(AnalysisResult.total_score))
        .join(Recording)
        .filter(Recording.user_id == current_user.id, Recording.status == "done")
        .scalar()
    )
    avg_score = _avg(avg_total)
    module_rows = (
        db.query(AnalysisModuleResult.module, func.avg(AnalysisModuleResult.score))
        .join(AnalysisResult, AnalysisResult.id == AnalysisModuleResult.analysis_id)
        .join(Recording, Recording.id == AnalysisResult.recording_id)
        .filter(Recording.user_id == current_user.id, Recording.status == "done")
        .group_by(AnalysisModuleResult.module)
        .all()
    )
    avg_by_module = {name: _avg(value) for name, value in module_rows}

    avg_parasites = avg_by_module.get("parasites", 0)
    avg_pauses    = avg_by_module.get("pauses", 0)
    avg_tempo     = avg_by_module.get("tempo", 0)
    avg_lexical   = avg_by_module.get("lexical", 0)
    avg_syntax    = avg_by_module.get("syntax", 0)

    today_rec = db.query(Recording).filter(
        Recording.user_id == current_user.id,
        Recording.status == "done",
        Recording.created_at >= datetime.combine(date.today(), datetime.min.time()),
    ).first()

    par = latest.details_parasites or {}
    pau = latest.details_pauses or {}
    tem = latest.details_tempo or {}
    lex = latest.details_lexical or {}
    syn = latest.details_syntax or {}

    def param(key, title, score, desc, icon):
        return Parameter(key=key, title=title, score=score, icon=icon,
                         description=desc)
    parameters = [
        param("parasites", "Слова-паразиты", avg_parasites, parasites_desc(par), "ban"),
        param("pauses", "Паузы", avg_pauses, pauses_desc(pau), "pause_circle"),
        param("tempo", "Темп", avg_tempo, tempo_desc(tem), "speed"),
        param("lexical", "Лексика", avg_lexical, lexical_desc(lex), "book"),
        param("syntax", "Синтаксис", avg_syntax, syntax_desc(syn), "account_tree"),
    ]
    return ApiResponse.ok(DashboardData(
        user=user_me,
        score=avg_score,
        score_change=score_change,
        has_recording_today=today_rec is not None,
        radar=RadarData(
            parasites=avg_parasites,
            pauses=avg_pauses,
            tempo=avg_tempo,
            lexical=avg_lexical,
            syntax=avg_syntax,
        ),
        parameters=parameters,
        last_recording_at=to_iso_utc(latest.analyzed_at),
    ))
