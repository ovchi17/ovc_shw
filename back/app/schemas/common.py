from __future__ import annotations
from typing import Any, Generic, TypeVar
from pydantic import BaseModel

T = TypeVar("T")

class ApiResponse(BaseModel, Generic[T]):
    success: bool = True
    data: T | None = None
    error: str | None = None
    message: str | None = None

    @classmethod
    def ok(cls, data: Any, message: str | None = None) -> "ApiResponse":
        return cls(success=True, data=data, message=message)

    @classmethod
    def fail(cls, error: str) -> "ApiResponse":
        return cls(success=False, error=error)
