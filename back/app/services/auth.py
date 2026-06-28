from __future__ import annotations
from datetime import datetime, timedelta
from fastapi import HTTPException
from jose import jwt
from passlib.context import CryptContext
from sqlalchemy.orm import Session
from app.core.config import settings
from app.models.user import User
pwd = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_password(password: str) -> str:
    return pwd.hash(password)


def verify_password(plain: str, hashed: str) -> bool:
    return pwd.verify(plain, hashed)


def create_access_token(user_id: int) -> str:
    expire = datetime.utcnow() + timedelta(minutes=settings.access_token_expire_minutes)
    return jwt.encode(
        {"sub": str(user_id), "exp": expire},
        settings.secret_key,
        algorithm=settings.algorithm,
    )


def register_email_user(
    db: Session,
    *,
    email: str,
    password: str,
    name: str,
) -> User:
    if db.query(User).filter(User.email == email).first():
        raise HTTPException(400, "Пользователь с этой почтой уже существует")
    user = User(
        email=email,
        password_hash=hash_password(password),
        name=name,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def login_email_user(db: Session, *, email: str, password: str) -> User:
    user = db.query(User).filter(User.email == email).first()
    if user is None or user.password_hash is None:
        raise HTTPException(401, "Неверный email или пароль")
    if not verify_password(password, user.password_hash):
        raise HTTPException(401, "Неверный email или пароль")
    return user
