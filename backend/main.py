from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from loguru import logger

from app.database import init_db
from app.routers import users, activities, progress, ai_tutor
from app.routers import reports, tts, teacher
from app.config import settings


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("🚀 Iniciando MathMágico Backend v1.0...")
    await init_db()
    logger.info("✅ Base de datos lista")
    yield
    logger.info("🛑 Servidor detenido")


app = FastAPI(
    title="MathMágico API",
    description="Backend del Tutor Inteligente para niños con discalculia.",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(users.router,      prefix="/api/v1/users",      tags=["Usuarios"])
app.include_router(activities.router, prefix="/api/v1/activities",  tags=["Actividades"])
app.include_router(progress.router,   prefix="/api/v1/progress",    tags=["Progreso"])
app.include_router(ai_tutor.router,   prefix="/api/v1/ai",          tags=["IA Tutor"])
app.include_router(reports.router,    prefix="/api/v1/reports",     tags=["Reportes"])
app.include_router(tts.router,        prefix="/api/v1/tts",         tags=["TTS Audio"])
app.include_router(teacher.router,    prefix="/api/v1/teachers",    tags=["Profesores"])


@app.get("/")
async def root():
    return {"app": "MathMágico API", "version": "1.0.0", "status": "running"}


@app.get("/health")
async def health():
    return {"status": "healthy"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)