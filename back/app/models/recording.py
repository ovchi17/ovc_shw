from __future__ import annotations
from datetime import datetime
from typing import List
from sqlalchemy import String, Float, Integer, DateTime, ForeignKey, Text, JSON
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.core.database import Base

_MODULES = ("parasites", "pauses", "tempo", "lexical", "syntax")


class Recording(Base):
    __tablename__ = "recordings"
    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    filename: Mapped[str] = mapped_column(String(255), nullable=False)
    file_path: Mapped[str] = mapped_column(String(255), nullable=False)
    duration_sec: Mapped[float | None] = mapped_column(Float)
    status: Mapped[str] = mapped_column(String(20), default="processing")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    user: Mapped["User"] = relationship(back_populates="recordings")
    analysis: Mapped["AnalysisResult | None"] = relationship(
        back_populates="recording", uselist=False, cascade="all, delete-orphan"
    )


class AnalysisModuleResult(Base):
    __tablename__ = "analysis_module_results"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    analysis_id: Mapped[int] = mapped_column(
        ForeignKey("analysis_results.id", ondelete="CASCADE"), nullable=False, index=True
    )
    module: Mapped[str] = mapped_column(String(20), nullable=False)
    score: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    details: Mapped[dict] = mapped_column(JSON, default=dict)

    analysis: Mapped["AnalysisResult"] = relationship(back_populates="modules")


class AnalysisResult(Base):
    __tablename__ = "analysis_results"
    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    recording_id: Mapped[int] = mapped_column(
        ForeignKey("recordings.id", ondelete="CASCADE"), unique=True, nullable=False
    )
    total_score: Mapped[int] = mapped_column(Integer, nullable=False)
    timecodes: Mapped[list] = mapped_column(JSON, default=list)
    transcript: Mapped[str | None] = mapped_column(Text)
    analyzed_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    processing_times: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    wer: Mapped[float | None] = mapped_column(Float, nullable=True)

    recording: Mapped["Recording"] = relationship(back_populates="analysis")
    modules: Mapped[List["AnalysisModuleResult"]] = relationship(
        back_populates="analysis",
        cascade="all, delete-orphan",
        lazy="selectin",
    )

    def module(self, name: str) -> "AnalysisModuleResult | None":
        for m in self.modules:
            if m.module == name:
                return m
        return None
    def score(self, name: str) -> int:
        m = self.module(name)
        return m.score if m else 0
    def details(self, name: str) -> dict:
        m = self.module(name)
        return m.details if m else {}

    @property
    def score_parasites(self) -> int: return self.score("parasites")
    @property
    def score_pauses(self) -> int:    return self.score("pauses")
    @property
    def score_tempo(self) -> int:     return self.score("tempo")
    @property
    def score_lexical(self) -> int:   return self.score("lexical")
    @property
    def score_syntax(self) -> int:    return self.score("syntax")

    @property
    def details_parasites(self) -> dict: return self.details("parasites")
    @property
    def details_pauses(self) -> dict:    return self.details("pauses")
    @property
    def details_tempo(self) -> dict:     return self.details("tempo")
    @property
    def details_lexical(self) -> dict:   return self.details("lexical")
    @property
    def details_syntax(self) -> dict:    return self.details("syntax")


class Task(Base):
    __tablename__ = "tasks"

    task_id: Mapped[str] = mapped_column(String(64), primary_key=True)
    recording_id: Mapped[int] = mapped_column(Integer, nullable=False, index=True)
    status: Mapped[str] = mapped_column(String(20), default="queued", nullable=False)
    progress_pct: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    message: Mapped[str] = mapped_column(String(255), default="В очереди...", nullable=False)
    analysis_id: Mapped[int | None] = mapped_column(Integer, nullable=True)
    error: Mapped[str | None] = mapped_column(String(255), nullable=True)