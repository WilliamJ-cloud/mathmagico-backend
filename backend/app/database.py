from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase
from loguru import logger


class Base(DeclarativeBase):
    pass


# ── Motor singleton ───────────────────────────────────────
_engine = None
_session_factory = None


def _get_or_create_engine(database_url: str):
    global _engine, _session_factory
    if _engine is not None:
        return _engine, _session_factory

    is_postgres = "postgresql" in database_url or "asyncpg" in database_url

    if is_postgres:
        # PostgreSQL: pool completo + SSL requerido por Render
        _engine = create_async_engine(
            database_url,
            echo=False,
            future=True,
            pool_pre_ping=True,
            pool_size=5,
            max_overflow=5,
            pool_recycle=1800,
            connect_args={"ssl": "require"},
        )
    else:
        # SQLite: NullPool no admite pool_size ni max_overflow
        _engine = create_async_engine(
            database_url,
            echo=False,
            future=True,
        )

    _session_factory = async_sessionmaker(
        _engine, class_=AsyncSession, expire_on_commit=False
    )
    return _engine, _session_factory


async def init_db():
    from app.config import settings
    from app import models  # noqa
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
