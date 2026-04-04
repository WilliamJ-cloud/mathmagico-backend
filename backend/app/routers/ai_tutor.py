from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
import anthropic
from loguru import logger

from app.database import get_db
from app.models import User, Session, AiAnalysis
from app.schemas import HintRequest, HintResponse, AnalysisResponse
from app.config import settings
import uuid

router = APIRouter()

# Cliente Anthropic
_client = None

def get_anthropic_client():
    global _client
    if _client is None and settings.anthropic_api_key:
        _client = anthropic.Anthropic(api_key=settings.anthropic_api_key)
    return _client


SYSTEM_PROMPT_TUTOR = """Eres MathMágico, un tutor de matemáticas amable y paciente para niños de 6 a 8 años con discalculia.

Tu misión es ayudar a estos niños a aprender operaciones básicas de aritmética de manera:
- CONCRETA: usa objetos físicos como referencia (manzanas, dedos, animales)
- VISUAL: describe lo que pueden ver y tocar
- POSITIVA: nunca digas que algo está mal, siempre anima
- SIMPLE: frases cortas, vocabulario de niño pequeño
- PASO A PASO: divide cada tarea en pasos muy pequeños

Reglas importantes:
1. Máximo 2 oraciones por respuesta
2. Siempre menciona un objeto concreto (manzana, dedo, estrella)
3. Nunca uses palabras difíciles
4. Siempre termina con aliento ("¡Tú puedes!", "¡Muy bien!", etc.)
5. Si el niño tiene dificultades, sugiere usar los dedos primero
"""

SYSTEM_PROMPT_ANALYST = """Eres un experto en discalculia y educación matemática para niños de 6-8 años.
Analiza el rendimiento del estudiante y proporciona:
1. Un mensaje de aliento en español, máximo 2 oraciones, dirigido al niño
2. Las habilidades más débiles que necesitan práctica
3. Las habilidades más fuertes para reforzar la autoestima
4. Actividades recomendadas prioritarias

Responde SIEMPRE en formato JSON con estas claves exactas:
{
  "insight": "mensaje para el niño",
  "recommended_activities": ["actividad1", "actividad2"],
  "weak_skills": ["habilidad1"],
  "strong_skills": ["habilidad1"],
  "encouragement": "frase motivadora corta"
}
"""


@router.post("/hint", response_model=HintResponse)
async def get_hint(
    data: HintRequest,
    db: AsyncSession = Depends(get_db),
):
    """Generar una pista adaptativa para el niño."""

    # Obtener contexto del usuario
    result = await db.execute(select(User).where(User.id == data.user_id))
    user = result.scalar_one_or_none()

    # Preparar contexto de la pregunta
    ctx = data.question_context
    activity = data.activity_type
    question_num = data.question_number

    # Pista predeterminada (si no hay API key)
    default_hints = {
        "suma_visual": f"Cuenta los objetos del primer grupo con tu dedo, luego sigue contando los del segundo grupo. ¡Tú puedes!",
        "resta_visual": f"Empieza con todos los objetos y quita uno por uno los que se van. Cuenta los que quedan. ¡Vas muy bien!",
        "conteo": f"Toca cada objeto una sola vez y di el número en voz alta: uno, dos, tres... ¡Así se hace!",
        "comparar": f"Cuenta los objetos de cada lado. El lado que tiene más, ¡ese es el mayor! ¡Muy bien!",
        "secuencias": f"Busca el número más pequeño de todos primero. Luego el siguiente más pequeño. ¡Sigue así!",
        "reconocer_numeros": f"Mira la forma del número. ¿Lo reconoces? Puedes contarlo en la línea de números. ¡Tú puedes!",
    }

    client = get_anthropic_client()
    if not client:
        hint_text = default_hints.get(activity, "Inténtalo paso a paso. ¡Tú puedes!")
        return HintResponse(hint=hint_text, spoken_hint=hint_text)

    try:
        user_context = f"El niño se llama {user.name}, tiene {user.age} años." if user else ""
        prompt = f"""{user_context}

Actividad: {activity}
Pregunta número: {question_num}
Contexto: {ctx}

El niño necesita una pista. Dame una pista concreta y visual de máximo 2 oraciones."""

        message = client.messages.create(
            model="claude-3-haiku-20240307",
            max_tokens=150,
            system=SYSTEM_PROMPT_TUTOR,
            messages=[{"role": "user", "content": prompt}],
        )

        hint_text = message.content[0].text.strip()
        return HintResponse(hint=hint_text, spoken_hint=hint_text)

    except Exception as e:
        logger.error(f"Error obteniendo pista IA: {e}")
        hint_text = default_hints.get(activity, "Cuenta despacio con tu dedo. ¡Tú puedes!")
        return HintResponse(hint=hint_text, spoken_hint=hint_text)


@router.get("/analysis/{user_id}", response_model=AnalysisResponse)
async def get_analysis(
    user_id: str,
    db: AsyncSession = Depends(get_db),
):
    """Análisis IA completo del progreso del niño con discalculia."""

    # Obtener datos del usuario
    user_result = await db.execute(select(User).where(User.id == user_id))
    user = user_result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")

    # Obtener sesiones recientes
    sessions_result = await db.execute(
        select(Session)
        .where(Session.user_id == user_id)
        .order_by(Session.completed_at.desc())
        .limit(20)
    )
    sessions = sessions_result.scalars().all()

    # Análisis por defecto si no hay sesiones
    if not sessions:
        return AnalysisResponse(
            insight=f"¡Hola {user.name}! Estás empezando tu aventura matemática. ¡Elige una actividad!",
            recommended_activities=["conteo", "reconocer_numeros"],
            weak_skills=[],
            strong_skills=[],
            encouragement="¡Cada día que practicas te haces más listo!",
        )

    # Calcular métricas por habilidad
    skill_stats = {}
    for s in sessions:
        skill = s.activity_type
        if skill not in skill_stats:
            skill_stats[skill] = {"total": 0, "correct": 0, "count": 0}
        skill_stats[skill]["total"] += s.total_questions
        skill_stats[skill]["correct"] += s.correct_answers
        skill_stats[skill]["count"] += 1

    skill_accuracies = {
        k: v["correct"] / v["total"] if v["total"] > 0 else 0
        for k, v in skill_stats.items()
    }

    weak = [k for k, v in skill_accuracies.items() if v < 0.6]
    strong = [k for k, v in skill_accuracies.items() if v >= 0.8]

    # Intentar análisis con Claude
    client = get_anthropic_client()
    if not client:
        # Análisis basado en reglas
        insight = _rule_based_insight(user.name, skill_accuracies)
        recommended = weak[:2] if weak else list(skill_stats.keys())[:2]
        return AnalysisResponse(
            insight=insight,
            recommended_activities=recommended,
            weak_skills=weak,
            strong_skills=strong,
            encouragement="¡Cada día que practicas mejoras más!",
        )

    try:
        skill_summary = "\n".join([
            f"- {k}: {v*100:.0f}% de precisión ({skill_stats[k]['count']} sesiones)"
            for k, v in skill_accuracies.items()
        ])

        prompt = f"""Analiza el progreso de {user.name} ({user.age} años) con discalculia:

Habilidades:
{skill_summary}

Puntos totales: {user.total_points}
Sesiones completadas: {len(sessions)}

Proporciona tu análisis en el formato JSON indicado."""

        message = client.messages.create(
            model="claude-3-haiku-20240307",
            max_tokens=400,
            system=SYSTEM_PROMPT_ANALYST,
            messages=[{"role": "user", "content": prompt}],
        )

        import json
        text = message.content[0].text.strip()
        # Limpiar markdown si viene con ```json
        if "```" in text:
            text = text.split("```")[1]
            if text.startswith("json"):
                text = text[4:]

        analysis = json.loads(text)

        # Guardar análisis en BD
        ai_rec = AiAnalysis(
            id=str(uuid.uuid4()),
            user_id=user_id,
            insight=analysis.get("insight", ""),
            recommended_activities=analysis.get("recommended_activities", []),
            weak_skills=analysis.get("weak_skills", []),
            strong_skills=analysis.get("strong_skills", []),
        )
        db.add(ai_rec)
        await db.commit()

        return AnalysisResponse(**analysis)

    except Exception as e:
        logger.error(f"Error en análisis IA: {e}")
        insight = _rule_based_insight(user.name, skill_accuracies)
        recommended = weak[:2] if weak else ["conteo", "suma_visual"]
        return AnalysisResponse(
            insight=insight,
            recommended_activities=recommended,
            weak_skills=weak,
            strong_skills=strong,
            encouragement="¡Sigue practicando, cada día mejoras!",
        )


def _rule_based_insight(name: str, accuracies: dict) -> str:
    """Genera insight basado en reglas cuando no hay API."""
    if not accuracies:
        return f"¡{name}, estás empezando tu aventura! Practica todos los días."

    best_skill = max(accuracies, key=accuracies.get, default=None)
    worst_skill = min(accuracies, key=accuracies.get, default=None)

    skill_names = {
        "suma_visual": "sumar",
        "resta_visual": "restar",
        "conteo": "contar",
        "comparar": "comparar",
        "secuencias": "ordenar números",
        "reconocer_numeros": "reconocer números",
    }

    if best_skill and accuracies[best_skill] >= 0.7:
        return (
            f"¡{name}, eres muy bueno/a en {skill_names.get(best_skill, best_skill)}! "
            f"Sigue practicando {skill_names.get(worst_skill, worst_skill)} para mejorar aún más. ¡Tú puedes!"
        )

    return f"¡{name}, vas mejorando cada día! Sigue practicando y serás un campeón de las matemáticas. 🌟"