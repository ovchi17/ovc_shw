from pathlib import Path
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str = "sqlite:///./diploma.db"
    secret_key: str = "dev-insecure-change-in-production"
    algorithm: str = "HS256"
    admin_username: str = "admin"
    admin_password: str = "admin"
    access_token_expire_minutes: int = 60 * 24 * 7
    upload_dir: Path = Path("uploads")
    max_audio_size_mb: int = 50
    max_recording_minutes: int = 5
    allowed_audio_formats: frozenset[str] = frozenset(
        {"mp3", "m4a", "wav", "ogg", "webm", "aac", "flac", "wma"}
    )

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
settings = Settings()
