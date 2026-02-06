"""
NeuroVerse Configuration Settings
"""

from pydantic_settings import BaseSettings
from typing import Optional, List
from functools import lru_cache
import os


class Settings(BaseSettings):
    # App Settings
    APP_NAME: str = "NeuroVerse API"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = False

    # Server Settings
    HOST: str = "0.0.0.0"
    PORT: int = 8000

    # Database (Supabase PostgreSQL)
    DATABASE_URL: str = "postgresql+asyncpg://user:password@localhost:5432/neuroverse"
    DATABASE_ECHO: bool = False

    # JWT Authentication
    SECRET_KEY: str = "your-super-secret-key-change-in-production-min-32-chars"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    # OTP Settings
    OTP_EXPIRE_MINUTES: int = 10
    OTP_LENGTH: int = 6

    # Email Settings
    MAIL_USERNAME: Optional[str] = None
    MAIL_PASSWORD: Optional[str] = None
    MAIL_FROM: str = "noreply@neuroverse.pk"
    MAIL_FROM_NAME: str = "NeuroVerse"
    MAIL_PORT: int = 587
    MAIL_SERVER: str = "smtp.gmail.com"
    MAIL_STARTTLS: bool = True
    MAIL_SSL_TLS: bool = False

    # File Upload Settings
    MAX_FILE_SIZE: int = 10 * 1024 * 1024  # 10MB
    UPLOAD_DIR: str = "uploads"
    ALLOWED_AUDIO_TYPES: List[str] = ["audio/wav", "audio/mp3", "audio/mpeg", "audio/webm"]
    ALLOWED_IMAGE_TYPES: List[str] = ["image/jpg", "image/jpeg", "image/png", "image/webp"]
    ALLOWED_FILE_TYPES: str = ".jpg,.jpeg,.png,.pdf,.docx,.txt"  # Added this
    
    # CORS Settings
    ALLOWED_ORIGINS: str = "*"  # Added this

    class Config:
        env_file = ".env"
        case_sensitive = True


@lru_cache()
def get_settings() -> Settings:
    return Settings()


settings = get_settings()