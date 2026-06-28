from datetime import datetime
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import JWTError, jwt
from sqlalchemy.orm import Session
from app.core.config import settings
from app.core.database import get_db
from app.models.recording import Recording
from app.models.user import User
_bearer = HTTPBearer()

def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(_bearer),
    db: Session = Depends(get_db),
) -> User:
    exc = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Неверный или просроченный токен",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(
            credentials.credentials,
            settings.secret_key,
            algorithms=[settings.algorithm],
        )
        user_id: int | None = payload.get("sub")
        if user_id is None:
            raise exc
    except JWTError:
        raise exc

    user = db.get(User, int(user_id))
    if user is None:
        raise exc
    return user


def get_user_recording(db: Session, recording_id: int, user_id: int) -> Recording:
    rec = db.get(Recording, recording_id)
    if rec is None or rec.user_id != user_id:
        raise HTTPException(status_code=404, detail="Запись не найдена")
    return rec

def to_iso_utc(dt: datetime | None) -> str | None:
    return dt.isoformat() + "Z" if dt else None
