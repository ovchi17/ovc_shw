from __future__ import annotations
from pydantic import BaseModel, field_validator


class RegisterRequest(BaseModel):
    email: str
    password: str
    name: str

    @field_validator("email")
    @classmethod
    def email_lower(cls, v: str) -> str:
        return v.strip().lower()

    @field_validator("password")
    @classmethod
    def password_min(cls, v: str) -> str:
        if len(v) < 6:
            raise ValueError("Пароль должен содержать не менее 6 символов")
        return v

    @field_validator("name")
    @classmethod
    def name_strip(cls, v: str) -> str:
        v = v.strip()
        if len(v) < 2:
            raise ValueError("Имя слишком короткое")
        return v


class LoginRequest(BaseModel):
    email: str
    password: str

    @field_validator("email")
    @classmethod
    def email_lower(cls, v: str) -> str:
        return v.strip().lower()


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    is_new_user: bool = False

class UserMe(BaseModel):

    id: int
    name: str
    avatar: str
    streak: int
    total_recordings: int
    email: str | None = None


class ProfileStats(BaseModel):
    id: int
    name: str
    avatar: str
    streak: int
    total_recordings: int
    best_score: int
    avg_score: int
    total_minutes: int
    member_since: str


class UpdateProfileRequest(BaseModel):
    name: str | None = None


class FillerItem(BaseModel):
    word: str
    @field_validator("word")
    @classmethod
    def clean_word(cls, v: str) -> str:
        v = v.strip().lower()
        if not v:
            raise ValueError("Слово не может быть пустым")
        return v


class FillersOut(BaseModel):
    fillers: list[str]

class Goal(BaseModel):
    target_score: int
    current_score: int
    recordings_done: int
    recordings_target: int
    days_left: int
    progress_pct: int


class WeeklyDay(BaseModel):
    date: str
    score: int | None
    has_recording: bool


class WeeklyReport(BaseModel):
    week_start: str
    week_end: str
    avg_score: int | None
    best_score: int | None
    recordings_count: int
    days: list[WeeklyDay]
    improvement: int | None
