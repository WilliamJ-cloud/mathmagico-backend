from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update
from typing import List
import random
import uuid

from app.database import get_db
from app.models import User, Session, Question
from app.schemas import (
    QuestionResponse,
    ActivitySubmitRequest,
    ActivitySubmitResponse,
)
from app.services.question_generator import QuestionGenerator

router = APIRouter()
generator = QuestionGenerator()

# Logros disponibles con sus condiciones
ACHIEVEMENTS = {
    "primer_suma": lambda sessions, user: any(s.activity_type == "suma_visual" for s in sessions),
    "contador_experto": lambda sessions, user: sum(
        1 for s in sessions if s.activity_type == "conteo" and s.accuracy == 1.0
    ) >= 10,
    "cien_puntos": lambda sessions, user: (user.total_points or 0) >= 100,
    "sin_pistas": lambda sessions, user: any(
        all(not r.get("hints_used") for r in (s.question_results or []))
        for s in sessions
    ),
}


@router.get("/questions", response_model=List[QuestionResponse])
async def get_questions(
    activity_type: str = Query(..., description="Tipo de actividad"),
    difficulty: str = Query("facil", description="Dificultad: facil, medio, dificil"),
    user_id: str = Query(...),
    count: int = Query(5, ge=3, le=10),
    db: AsyncSession = Depends(get_db),
):
    """
    Genera preguntas adaptadas al nivel del usuario.
    Usa el historial para ajustar dificultad dinámicamente.
    """
    # Obtener historial reciente del usuario para adaptar
    result = await db.execute(
        select(Session)
        .where(Session.user_id == user_id, Session.activity_type == activity_type)
        .order_by(Session.completed_at.desc())
        .limit(5)
    )
    recent_sessions = result.scalars().all()

    # Calcular precisión reciente para adaptar dificultad
    if recent_sessions:
        avg_accuracy = sum(s.accuracy for s in recent_sessions) / len(recent_sessions)
        if avg_accuracy >= 0.85 and difficulty == "facil":
            difficulty = "medio"
        elif avg_accuracy >= 0.9 and difficulty == "medio":
            difficulty = "dificil"
        elif avg_accuracy < 0.4 and difficulty != "facil":
            difficulty = "facil"

    # Generar preguntas
    questions = generator.generate(activity_type, difficulty, count)

    # Guardar en BD para análisis posterior
    for q in questions:
        db_q = Question(
            id=q["id"],
            activity_type=activity_type,
            difficulty=difficulty,
            question_text=q["question_text"],
            operands=q["operands"],
            correct_answer=q["correct_answer"],
            choices=q["choices"],
            hint=q.get("hint"),
            emoji1=q.get("emoji1"),
            emoji2=q.get("emoji2"),
        )
        db.add(db_q)
    try:
        await db.commit()
    except Exception:
        await db.rollback()

    return [QuestionResponse(**q) for q in questions]


@router.post("/submit", response_model=ActivitySubmitResponse)
async def submit_activity(
    data: ActivitySubmitRequest,
    db: AsyncSession = Depends(get_db),
):
    """Guardar resultado de sesión y actualizar progreso del usuario."""

    # Guardar sesión
    session = Session(
        id=str(uuid.uuid4()),
        user_id=data.user_id,
        activity_type=data.activity_id,
        total_questions=data.total_questions,
        correct_answers=data.correct_answers,
        points_earned=data.points_earned,
        time_taken_seconds=data.time_taken_seconds,
        accuracy=data.accuracy,
        question_results=[r.model_dump() for r in data.question_results],
    )
    db.add(session)

    # Obtener usuario y actualizar puntos
    result = await db.execute(select(User).where(User.id == data.user_id))
    user = result.scalar_one_or_none()

    achievements_unlocked = []
    if user:
        # Actualizar puntos
        user.total_points = (user.total_points or 0) + data.points_earned

        # Actualizar nivel
        pts = user.total_points
        if pts >= 1000:
            user.level = 5
        elif pts >= 600:
            user.level = 4
        elif pts >= 300:
            user.level = 3
        elif pts >= 100:
            user.level = 2
        else:
            user.level = 1

        # Actualizar habilidad correspondiente
        skill_map = {
            "suma_visual": "suma",
            "resta_visual": "resta",
            "conteo": "conteo",
            "comparar": "comparar",
            "secuencias": "secuencias",
            "reconocer_numeros": "reconocer",
        }
        skill_key = skill_map.get(data.activity_id, data.activity_id)
        skills = dict(user.skill_levels or {})
        current = skills.get(skill_key, 0)
        # Media exponencial: combina valor previo con nueva precisión
        new_val = int(current * 0.7 + data.accuracy * 100 * 0.3)
        skills[skill_key] = min(100, new_val)
        user.skill_levels = skills

        # Verificar logros
        all_sessions_result = await db.execute(
            select(Session).where(Session.user_id == data.user_id)
        )
        all_sessions = all_sessions_result.scalars().all()
        earned = list(user.achievements or [])

        for ach_id, condition in ACHIEVEMENTS.items():
            if ach_id not in earned:
                try:
                    if condition(all_sessions + [session], user):
                        earned.append(ach_id)
                        achievements_unlocked.append(ach_id)
                except Exception:
                    pass

        user.achievements = earned

    await db.commit()

    return ActivitySubmitResponse(
        success=True,
        points_awarded=data.points_earned,
        new_total_points=user.total_points if user else data.points_earned,
        achievements_unlocked=achievements_unlocked,
        message="¡Muy bien! Tu progreso ha sido guardado.",
    )