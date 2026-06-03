from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from typing import List
import uuid

from app.database import get_db
from app.models import User, Session, Question, QuestionOperand, QuestionChoice, QuestionResult, UserAchievement, UserSkillLevel, calc_level
from app.schemas import QuestionResponse, ActivitySubmitRequest, ActivitySubmitResponse
from app.services.question_generator import QuestionGenerator

router = APIRouter()
generator = QuestionGenerator()

ACHIEVEMENTS = {
    "primer_suma":      lambda sessions, achievements: any(s.activity_type == "suma_visual" for s in sessions),
    "contador_experto": lambda sessions, achievements: sum(
        1 for s in sessions if s.activity_type == "conteo" and s.accuracy >= 1.0
    ) >= 10,
    "cien_puntos":      lambda sessions, achievements: False,  # se evalúa por puntos en submit
    "sin_pistas":       lambda sessions, achievements: any(
        all(r.hints_used == 0 for r in s.question_results) and len(s.question_results) > 0
        for s in sessions
    ),
}

SKILL_MAP = {
    "suma_visual":      "suma",
    "resta_visual":     "resta",
    "conteo":           "conteo",
    "comparar":         "comparar",
    "secuencias":       "secuencias",
    "reconocer_numeros":"reconocer",
}


@router.get("/questions", response_model=List[QuestionResponse])
async def get_questions(
    activity_type: str = Query(...),
    difficulty: str    = Query("facil"),
    user_id: str       = Query(...),
    count: int         = Query(5, ge=3, le=10),
    db: AsyncSession   = Depends(get_db),
):
    # Adaptar dificultad según historial reciente
    result = await db.execute(
        select(Session)
        .where(Session.user_id == user_id, Session.activity_type == activity_type)
        .order_by(Session.completed_at.desc())
        .limit(5)
    )
    recent = result.scalars().all()

    if recent:
        avg = sum(s.accuracy for s in recent) / len(recent)
        if avg >= 0.85 and difficulty == "facil":
            difficulty = "medio"
        elif avg >= 0.9 and difficulty == "medio":
            difficulty = "dificil"
        elif avg < 0.4 and difficulty != "facil":
            difficulty = "facil"

    questions = generator.generate(activity_type, difficulty, count)

    for q in questions:
        db_q = Question(
            id=q["id"],
            activity_type=activity_type,
            difficulty=difficulty,
            question_text=q["question_text"],
            correct_answer=q["correct_answer"],
            hint=q.get("hint"),
            emoji1=q.get("emoji1"),
            emoji2=q.get("emoji2"),
        )
        # 1FN: operands y choices como filas separadas
        for pos, val in enumerate(q["operands"]):
            db_q.operands.append(QuestionOperand(id=str(uuid.uuid4()), position=pos, value=int(val)))
        for pos, val in enumerate(q["choices"]):
            db_q.choices.append(QuestionChoice(id=str(uuid.uuid4()), position=pos, value=int(val)))

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
    # Guardar sesión (sin accuracy: es dato derivado)
    session = Session(
        id=str(uuid.uuid4()),
        user_id=data.user_id,
        activity_type=data.activity_id,
        difficulty="facil",
        total_questions=data.total_questions,
        correct_answers=data.correct_answers,
        points_earned=data.points_earned,
        time_taken_seconds=data.time_taken_seconds,
    )

    # 1FN: guardar resultados por pregunta en tabla propia
    for r in data.question_results:
        db.add(QuestionResult(
            id=str(uuid.uuid4()),
            session_id=session.id,
            question_id=None,  # No forzar FK que puede no existir
            is_correct=r.is_correct,
            answer_given=r.user_answer,
            hints_used=r.hints_used,
        ))

    db.add(session)

    # Actualizar usuario
    result = await db.execute(select(User).options(selectinload(User.skill_levels), selectinload(User.achievements)).where(User.id == data.user_id))
    user = result.scalar_one_or_none()

    achievements_unlocked = []
    if user:
        user.total_points = (user.total_points or 0) + data.points_earned

        # Logro "cien_puntos"
        earned_keys = {a.achievement_key for a in user.achievements}
        if "cien_puntos" not in earned_keys and user.total_points >= 100:
            user.achievements.append(UserAchievement(
                id=str(uuid.uuid4()), achievement_key="cien_puntos"
            ))
            achievements_unlocked.append("cien_puntos")

        # Actualizar nivel de habilidad (1FN: en tabla user_skill_levels)
        skill_key = SKILL_MAP.get(data.activity_id, data.activity_id)
        skill_result = await db.execute(
            select(UserSkillLevel)
            .where(UserSkillLevel.user_id == data.user_id,
                   UserSkillLevel.skill_name == skill_key)
        )
        skill_row = skill_result.scalar_one_or_none()
        new_val = int((skill_row.level if skill_row else 0) * 0.7 + data.accuracy * 100 * 0.3)
        new_val = min(100, new_val)

        if skill_row:
            skill_row.level = new_val
        else:
            db.add(UserSkillLevel(
                id=str(uuid.uuid4()),
                user_id=data.user_id,
                skill_name=skill_key,
                level=new_val,
            ))

        # Verificar otros logros
        all_sessions_r = await db.execute(select(Session).where(Session.user_id == data.user_id))
        all_sessions = all_sessions_r.scalars().all()

        for ach_id, condition in ACHIEVEMENTS.items():
            if ach_id not in earned_keys and ach_id != "cien_puntos":
                try:
                    if condition(all_sessions + [session], earned_keys):
                        user.achievements.append(UserAchievement(
                            id=str(uuid.uuid4()), achievement_key=ach_id
                        ))
                        achievements_unlocked.append(ach_id)
                        earned_keys.add(ach_id)
                except Exception:
                    pass

    await db.commit()

    return ActivitySubmitResponse(
        success=True,
        points_awarded=data.points_earned,
        new_total_points=user.total_points if user else data.points_earned,
        achievements_unlocked=achievements_unlocked,
        message="¡Muy bien! Tu progreso ha sido guardado.",
    )
