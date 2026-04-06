from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase
from loguru import logger


class Base(DeclarativeBase):
    pass


# ── Motor singleton ───────────────────────────────────────
# Se crea una sola vez al primer uso y se reutiliza en cada request.
# Esto evita agotar el pool de conexiones de PostgreSQL en Render (máx 25).
_engine = None
_session_factory = None


def _get_or_create_engine(database_url: str):
    global _engine, _session_factory
    if _engine is not None:
        return _engine, _session_factory

    is_postgres = "postgresql" in database_url or "asyncpg" in database_url

    connect_args = {}
    if is_postgres:
        # Render PostgreSQL exige SSL; asyncpg acepta este parámetro
        connect_args = {"ssl": "require"}

    _engine = create_async_engine(
        database_url,
        echo=False,
        future=True,
        pool_pre_ping=True,          # descarta conexiones muertas
        pool_size=5,                 # conexiones activas en el pool
        max_overflow=5,              # extras temporales bajo carga
        pool_recycle=1800,           # recicla conexiones cada 30 min
        connect_args=connect_args,
    )
    _session_factory = async_sessionmaker(
        _engine, class_=AsyncSession, expire_on_commit=False
    )
    return _engine, _session_factory


async def init_db():
    from app.config import settings
    from app import models  # noqa – importar para registrar los modelos
    engine, _ = _get_or_create_engine(settings.async_database_url)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    logger.info("✅ Tablas creadas correctamente")


async def get_db():
    from app.config import settings
    _, session_factory = _get_or_create_engine(settings.async_database_url)
    async with session_factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()
