from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import List
import uuid

from app.database import get_db
from app.models import Diagnostico, DiagnosticoRespuesta, User, DIAGNOSTICO_PREGUNTAS
from app.schemas import (
    DiagnosticoPreguntaResponse,
    DiagnosticoSubmitRequest,
    DiagnosticoResultadoResponse,
)

router = APIRouter()


def calcular_riesgo(total_dificultades: int) -> str:
    """Criterio Butterworth: 4+ dificultades = riesgo."""
    if total_dificultades >= 6:
        return "alto"
    elif total_dificultades >= 4:
        return "moderado"
    return "sin_riesgo"


def mensaje_riesgo(nivel: str, nombre: str) -> str:
    if nivel == "alto":
        return f"¡{nombre} necesita apoyo especial! Presenta varias dificultades con los números. Te recomendamos empezar con las actividades de conteo."
    elif nivel == "moderado":
        return f"¡{nombre} está aprendiendo! Tiene algunas dificultades que podemos trabajar juntos. ¡Tú puedes!"
    return f"¡{nombre} va muy bien con los números! Sigue practicando para ser un campeón de las matemáticas. 🌟"


@router.get("/preguntas", response_model=List[DiagnosticoPreguntaResponse])
async def get_preguntas():
    """Retorna las 8 preguntas del diagnóstico Butterworth."""
    return [DiagnosticoPreguntaResponse(**p) for p in DIAGNOSTICO_PREGUNTAS]


@router.post("/submit", response_model=DiagnosticoResultadoResponse)
async def submit_diagnostico(
    data: DiagnosticoSubmitRequest,
    db: AsyncSession = Depends(get_db),
):
    """Guarda las respuestas y calcula el nivel de riesgo según Butterworth."""

    # Verificar usuario
    result = await db.execute(select(User).where(User.id == data.user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")

    # Calcular dificultades (respuesta False = No = dificultad)
    # Pregunta 5 es inversa: responder Sí = confunde números = dificultad
    dificultades = 0
    for r in data.respuestas:
        pregunta = next((p for p in DIAGNOSTICO_PREGUNTAS if p["id"] == r.pregunta_id), None)
        if pregunta:
            if pregunta["indicador"] == "confusion_numeros":
                # Sí = confunde = dificultad
                if r.respuesta is True:
                    dificultades += 1
            else:
                # No = no puede = dificultad
                if r.respuesta is False:
                    dificultades += 1

    nivel = calcular_riesgo(dificultades)

    # Guardar diagnóstico
    diag = Diagnostico(
        id=str(uuid.uuid4()),
        user_id=data.user_id,
        total_dificultades=dificultades,
        nivel_riesgo=nivel,
    )
    for r in data.respuestas:
        pregunta = next((p for p in DIAGNOSTICO_PREGUNTAS if p["id"] == r.pregunta_id), None)
        diag.respuestas.append(DiagnosticoRespuesta(
            id=str(uuid.uuid4()),
            pregunta_id=r.pregunta_id,
            indicador=pregunta["indicador"] if pregunta else "",
            respuesta=r.respuesta,
        ))

    db.add(diag)
    await db.commit()

    return DiagnosticoResultadoResponse(
        diagnostico_id=diag.id,
        total_dificultades=dificultades,
        nivel_riesgo=nivel,
        mensaje=mensaje_riesgo(nivel, user.name),
        actividades_recomendadas=_actividades_recomendadas(nivel),
    )


@router.get("/resultado/{user_id}", response_model=DiagnosticoResultadoResponse)
async def get_ultimo_resultado(user_id: str, db: AsyncSession = Depends(get_db)):
    """Obtiene el último diagnóstico del estudiante."""
    result = await db.execute(
        select(Diagnostico)
        .where(Diagnostico.user_id == user_id)
        .order_by(Diagnostico.created_at.desc())
        .limit(1)
    )
    diag = result.scalar_one_or_none()
    if not diag:
        raise HTTPException(status_code=404, detail="Sin diagnóstico previo")

    user_r = await db.execute(select(User).where(User.id == user_id))
    user = user_r.scalar_one_or_none()

    return DiagnosticoResultadoResponse(
        diagnostico_id=diag.id,
        total_dificultades=diag.total_dificultades,
        nivel_riesgo=diag.nivel_riesgo,
        mensaje=mensaje_riesgo(diag.nivel_riesgo, user.name if user else ""),
        actividades_recomendadas=_actividades_recomendadas(diag.nivel_riesgo),
    )


@router.get("/profesor/{user_id}")
async def get_diagnostico_profesor(user_id: str, db: AsyncSession = Depends(get_db)):
    """Vista detallada para el profesor con todas las respuestas."""
    result = await db.execute(
        select(Diagnostico)
        .where(Diagnostico.user_id == user_id)
        .order_by(Diagnostico.created_at.desc())
        .limit(1)
    )
    diag = result.scalar_one_or_none()
    if not diag:
        raise HTTPException(status_code=404, detail="Sin diagnóstico")

    # Cargar respuestas
    resp_result = await db.execute(
        select(DiagnosticoRespuesta).where(DiagnosticoRespuesta.diagnostico_id == diag.id)
    )
    respuestas = resp_result.scalars().all()

    detalle = []
    for r in respuestas:
        pregunta = next((p for p in DIAGNOSTICO_PREGUNTAS if p["id"] == r.pregunta_id), {})
        detalle.append({
            "pregunta_id": r.pregunta_id,
            "indicador": r.indicador,
            "texto": pregunta.get("texto", ""),
            "respuesta": "Sí" if r.respuesta else "No",
            "es_dificultad": (
                r.respuesta is True if r.indicador == "confusion_numeros"
                else r.respuesta is False
            ),
        })

    return {
        "diagnostico_id": diag.id,
        "fecha": diag.created_at.isoformat(),
        "nivel_riesgo": diag.nivel_riesgo,
        "total_dificultades": diag.total_dificultades,
        "criterio": "Butterworth: 4+ dificultades = riesgo de discalculia",
        "detalle": detalle,
    }


def _actividades_recomendadas(nivel: str) -> List[str]:
    if nivel == "alto":
        return ["conteo", "reconocer_numeros", "comparar"]
    elif nivel == "moderado":
        return ["conteo", "suma_visual"]
    return ["suma_visual", "secuencias", "resta_visual"]
