
from __future__ import annotations
from datetime import datetime
from typing import List
from sqlalchemy import String, DateTime, JSON
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.core.database import Base


class User(Base):
    __tablename__ = "users"
    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    # Аутентификация
    email: Mapped[str | None] = mapped_column(String(255), unique=True, index=True)
    password_hash: Mapped[str | None] = mapped_column(String(255))
    # Базовые данные
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    # Пользовательские слова-паразиты
    custom_fillers: Mapped[list | None] = mapped_column(JSON, default=list)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    recordings: Mapped[List["Recording"]] = relationship(
        back_populates="user", cascade="all, delete-orphan"
    )
