import logging
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.sessions import SessionMiddleware
from app.core.database import engine, Base
from app.api.v1 import auth, dashboard, progress, recordings, user
from app.admin import create_admin
from app.core.config import settings
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger(__name__)

Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="Clarity",
    description="API для лингвистического анализа устной речи",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)
app.add_middleware(
    SessionMiddleware,
    secret_key=settings.secret_key,
    session_cookie="admin_session",
    max_age=60 * 60 * 24
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

PREFIX = "/api/v1"

app.include_router(auth.router,       prefix=PREFIX)
app.include_router(dashboard.router,  prefix=PREFIX)
app.include_router(recordings.router, prefix=PREFIX)
app.include_router(user.router,       prefix=PREFIX)
app.include_router(progress.router,   prefix=PREFIX)

create_admin(app, engine)
