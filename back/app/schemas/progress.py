from __future__ import annotations
from pydantic import BaseModel
from app.schemas.analysis import RadarData, Parameter
from app.schemas.user import UserMe


class DashboardData(BaseModel):
    user: UserMe
    score: int
    score_change: int
    has_recording_today: bool
    radar: RadarData
    parameters: list[Parameter]
    last_recording_at: str | None


class ProgressOverview(BaseModel):
    current_score: int
    score_change: int
    streak: int
    total_recordings: int
    period_days: int


class DynamicsPoint(BaseModel):
    date: str
    score: int | None
    recording_id: int | None


class DynamicsData(BaseModel):
    period: str
    points: list[DynamicsPoint]
    avg_score: int | None
    trend: str


class ActivityDay(BaseModel):
    date: str
    count: int
    score: int | None


class ActivityData(BaseModel):
    days: list[ActivityDay]
    total_active_days: int
    total_recordings: int


class Tip(BaseModel):
    id: int
    category: str
    title: str
    body: str
    source: str | None = None
    is_personalized: bool = True


class TipsData(BaseModel):
    tips: list[Tip]
