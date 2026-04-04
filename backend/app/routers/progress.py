from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from datetime import datetime, timedelta

from app.database import get_db
from app.models import User, Session
from app.schemas import ProgressResponse, SkillProgressResponse, SessionSummaryResponse

router = APIRouter()

SKILL_LABELS = {
    "suma_visual": "suma",
    "resta_visual": "resta",
    "conteo": "conteo",
    "comparar": "comparar",
    "secuencias": "secuencias",
    "reconocer_numeros": "reconocer",
}


@router.get("/{user_id}", response_model=ProgressResponse)
async def get_progress(
    user_id: str,
    db: AsyncSession = Depends(get_db),
):
    """Obtener progreso detallado del usuario con análisis por habilidad."""

    # Verificar usuario
    user_result = await db.execute(select(User).where(User.id == user_id))
    user = user_result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")

    # Sesiones de los últimos 30 días
    thirty_days_ago = datetime.utcnow() - timedelta(days=30)
    sessions_result = await db.execute(
        select(Session)
        .where(Session.user_id == user_id)
        .order_by(Session.completed_at.desc())
        .limit(50)
    )
    all_sessions = sessions_result.scalars().all()

    # Agrupar por habilidad
    skill_data: dict = {}
    for session in all_sessions:
        key = SKILL_LABELS.get(session.activity_type, session.activity_type)
        if key not in skill_data:
            skill_data[key] = {"accuracies": [], "total": 0, "correct": 0}
        skill_data[key]["accuracies"].append(session.accuracy)
        skill_data[key]["total"] += session.total_questions
        skill_data[key]["correct"] += session.correct_answers

    # Calcular skill progress
    skills = {}
    all_skill_keys = ["conteo", "suma", "resta", "comparar", "secuencias", "reconocer"]
    for skill_key in all_skill_keys:
        data = skill_data.get(skill_key, {})
        if data:
            accuracies = data["accuracies"]
            pct = sum(accuracies) / len(accuracies)
            # Calcular tendencia: últimas 3 vs anteriores
            if len(accuracies) >= 6:
                recent_avg = sum(accuracies[:3]) / 3
                older_avg = sum(accuracies[3:6]) / 3
                if recent_avg > older_avg + 0.05:
                    trend = "up"
                elif recent_avg < older_avg - 0.05:
                    trend = "down"
                else:
                    trend = "stable"
            else:
                trend = "stable"
        else:
            pct = (user.skill_levels or {}).get(skill_key, 0) / 100.0
            trend = "stable"

        skills[skill_key] = SkillProgressResponse(
            name=skill_key,
            percentage=round(pct, 3),
            total_attempts=data.get("total", 0) if data else 0,
            correct_attempts=data.get("correct", 0) if data else 0,
            trend=trend,
        )

    # Sesiones recientes (últimas 5)
    recent_sessions = [
        SessionSummaryResponse(
            activity_type=s.activity_type,
            accuracy=round(s.accuracy, 2),
            points=s.points_earned,
            date=s.completed_at.isoformat() if s.completed_at else datetime.utcnow().isoformat(),
        )
        for s in all_sessions[:5]
    ]

    # Calcular racha semanal
    weekly_streak = _calculate_weekly_streak(all_sessions)

    # Obtener último insight de IA
    ai_insight = ""
    from app.models import AiAnalysis
    ai_result = await db.execute(
        select(AiAnalysis)
        .where(AiAnalysis.user_id == user_id)
        .order_by(AiAnalysis.created_at.desc())
        .limit(1)
    )
    ai_analysis = ai_result.scalar_one_or_none()
    if ai_analysis:
        ai_insight = ai_analysis.insight

    # Recomendaciones basadas en habilidades débiles
    weak_skills = [
        k for k, v in skills.items() if v.percentage < 0.5
    ]
    activity_map = {
        "conteo": "conteo",
        "suma": "suma_visual",
        "resta": "resta_visual",
        "comparar": "comparar",
        "secuencias": "secuencias",
        "reconocer": "reconocer_numeros",
    }
    recommended = [activity_map[s] for s in weak_skills[:3] if s in activity_map]
    if not recommended:
        recommended = ["suma_visual", "conteo"]

    last_activity = (
        all_sessions[0].completed_at.isoformat()
        if all_sessions and all_sessions[0].completed_at
        else datetime.utcnow().isoformat()
    )

    return ProgressResponse(
        user_id=user_id,
        skills=skills,
        recent_sessions=recent_sessions,
        ai_insight=ai_insight or f"¡Sigue practicando para mejorar! Tienes {user.total_points} puntos.",
        recommended_activities=recommended,
        weekly_streak=weekly_streak,
        last_activity=last_activity,
    )


def _calculate_weekly_streak(sessions: list) -> int:
    """Calcular días consecutivos de práctica en la semana actual."""
    if not sessions:
        return 0

    today = datetime.utcnow().date()
    streak = 0
    check_date = today

    practice_dates = set()
    for s in sessions:
        if s.completed_at:
            practice_dates.add(s.completed_at.date())

    while check_date in practice_dates:
        streak += 1
        check_date -= timedelta(days=1)

    return min(streak, 7)