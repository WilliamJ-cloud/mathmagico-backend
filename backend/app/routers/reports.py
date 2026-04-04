from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.database import get_db
from app.models import User, Session
from app.services.progress_analyzer import progress_analyzer
from app.services.adaptive_engine import adaptive_engine, StudentProfile

router = APIRouter()


@router.get("/report/{user_id}")
async def get_progress_report(
    user_id: str,
    period_days: int = Query(default=7, ge=1, le=30),
    db: AsyncSession = Depends(get_db),
):
    """
    Genera reporte completo de progreso para padres/educadores.
    Incluye análisis pedagógico, patrones de error y recomendaciones.
    """
    # Obtener usuario
    user_result = await db.execute(select(User).where(User.id == user_id))
    user = user_result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")

    # Obtener todas las sesiones
    sessions_result = await db.execute(
        select(Session)
        .where(Session.user_id == user_id)
        .order_by(Session.completed_at.desc())
        .limit(100)
    )
    sessions = sessions_result.scalars().all()

    # Generar reporte
    report = progress_analyzer.generate_report(
        sessions=sessions,
        user_name=user.name,
        user_id=user_id,
        user_age=user.age,
        total_points=user.total_points or 0,
        period_days=period_days,
    )

    return report.to_dict()


@router.get("/adaptive-profile/{user_id}")
async def get_adaptive_profile(
    user_id: str,
    db: AsyncSession = Depends(get_db),
):
    """
    Retorna el perfil adaptativo del niño y la recomendación
    de la próxima actividad más beneficiosa.
    """
    user_result = await db.execute(select(User).where(User.id == user_id))
    user = user_result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")

    sessions_result = await db.execute(
        select(Session)
        .where(Session.user_id == user_id)
        .order_by(Session.completed_at.desc())
        .limit(30)
    )
    sessions = sessions_result.scalars().all()

    # Construir perfil del estudiante
    skill_accuracies: dict = {}
    session_count: dict = {}
    response_times: dict = {}
    hints_usage: dict = {}

    for s in sessions:
        key = s.activity_type
        if key not in skill_accuracies:
            skill_accuracies[key] = []
            session_count[key] = 0
            response_times[key] = []

        skill_accuracies[key].append(s.accuracy)
        session_count[key] += 1
        response_times[key].append(s.time_taken_seconds / max(s.total_questions, 1))

        # Tasa de pistas (de question_results)
        qr = s.question_results or []
        if qr:
            hints_rate = sum(1 for r in qr if r.get("hints_used", 0) > 0) / len(qr)
            hints_usage[key] = hints_rate

    # Promediar por habilidad
    avg_accs = {k: sum(v) / len(v) for k, v in skill_accuracies.items()}
    avg_times = {k: sum(v) / len(v) for k, v in response_times.items()}

    profile = StudentProfile(
        user_id=user_id,
        age=user.age,
        skill_accuracies=avg_accs,
        session_count=session_count,
        response_times=avg_times,
        hints_usage=hints_usage,
    )

    # Obtener recomendación adaptativa
    recommendation = adaptive_engine.recommend(profile)
    dyscalculia_profile = adaptive_engine.analyze_profile(profile)

    return {
        "user_id": user_id,
        "dyscalculia_profile": dyscalculia_profile.value,
        "recommendation": {
            "difficulty": recommendation.difficulty,
            "scaffolding_level": recommendation.scaffolding_level,
            "recommended_activity": recommendation.recommended_activity,
            "session_length": recommendation.session_length,
            "use_physical_objects": recommendation.use_physical_objects,
            "use_number_line": recommendation.use_number_line,
            "slow_pace": recommendation.slow_pace,
            "explanation": recommendation.explanation,
        },
        "skill_accuracies": {k: round(v * 100, 1) for k, v in avg_accs.items()},
        "total_sessions": len(sessions),
    }