from pydantic_settings import BaseSettings
from functools import lru_cache
import os


class Settings(BaseSettings):
    app_name: str = "MathMagico"
    debug: bool = True
    secret_key: str = "mathmagico-secret-key-2024"
    database_url: str = "sqlite+aiosqlite:///./mathmagico.db"
    anthropic_api_key: str = ""
    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = 10080

    model_config = {"env_file": ".env"}

    @property
    def async_database_url(self) -> str:
        url = self.database_url
        # Render provee DATABASE_URL con prefijo postgres:// o postgresql://
        # SQLAlchemy async necesita postgresql+asyncpg://
        if url.startswith("postgres://"):
            url = url.replace("postgres://", "postgresql+asyncpg://", 1)
        elif url.startswith("postgresql://") and "+asyncpg" not in url:
            url = url.replace("postgresql://", "postgresql+asyncpg://", 1)
        return url


@lru_cache()
def get_settings():
    return Settings()


settings = get_settings()