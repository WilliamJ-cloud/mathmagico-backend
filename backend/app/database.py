from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase
from loguru import logger


class Base(DeclarativeBase):
    pass


def get_engine(database_url: str):
    return create_async_engine(
        database_url,
        echo=False,
        future=True,
        pool_pre_ping=True,
    )


async def init_db():
    from app.config import settings
    from app import models  # noqa
    engine = get_engine(settings.async_database_url)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    logger.info("✅ Tablas creadas correctamente")


async def get_db():
    from app.config import settings
    engine = get_engine(settings.async_database_url)
    AsyncSessionLocal = async_sessionmaker(
        engine, class_=AsyncSession, expire_on_commit=False
    )
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()