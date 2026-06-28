from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.schemas.common import ApiResponse
from app.schemas.user import RegisterRequest, LoginRequest, TokenOut
from app.services import auth as auth_svc

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=ApiResponse[TokenOut])
async def register(body: RegisterRequest, db: Session = Depends(get_db)):
    user = auth_svc.register_email_user(
        db,
        email=body.email,
        password=body.password,
        name=body.name,
    )
    token = auth_svc.create_access_token(user.id)
    return ApiResponse.ok(
        TokenOut(access_token=token, is_new_user=True),
        message="Добро пожаловать!",
    )


@router.post("/login", response_model=ApiResponse[TokenOut])
async def login(body: LoginRequest, db: Session = Depends(get_db)):
    user = auth_svc.login_email_user(db, email=body.email, password=body.password)
    token = auth_svc.create_access_token(user.id)
    return ApiResponse.ok(
        TokenOut(access_token=token, is_new_user=False),
        message="С возвращением!",
    )
