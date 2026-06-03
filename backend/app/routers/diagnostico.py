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

# ── Clasificación por porcentaje (Butterworth) ────────────────────────────────
def calcular_nivel(porcentaje: float) -> str:
    if porcentaje >= 85:
        return "sin_indicadores"
    elif porcentaje >= 70:
        return "leve"
    elif porcentaje >= 50:
        return "moderado"
    return "alto"

def etiqueta_nivel(nivel: str) -> str:
    return {
        "sin_indicadores": "Sin indicadores significativos",
        "leve":            "Dificultades leves",
        "moderado":        "Dificultades moderadas",
        "alto":            "Posibles indicadores de discalculia",
    }.get(nivel, nivel)

def mensaje_resultado(nivel: str, nombre: str, porcentaje: float, debilidades: List[str]) -> str:
    areas = ", ".join(debilidades) if debilidades else "ninguna área"
    base = f"{nombre} obtuvo un {porcentaje:.0f}% en la evaluación. "

    if nivel == "sin_indicadores":
        return (
            base +
            "¡Muy buen desempeño! Demostró dominio en las habilidades evaluadas. "
            "¡Sigue practicando con MathMágico para seguir mejorando! 🌟"
        )
    elif nivel == "leve":
        return (
            base +
            f"Se identificaron algunas áreas a reforzar: {areas}. "
            f"Se recomienda practicar con las actividades sugeridas. 💪 "
            f"Nota: Esta evaluación es referencial. Consulta al docente para orientación adicional."
        )
    elif nivel == "moderado":
        return (
            base +
            f"Se identificaron áreas que necesitan refuerzo: {areas}. "
            f"Se sugiere trabajar con las actividades recomendadas y comunicar los resultados al docente. 📚 "
            f"Nota: Esta evaluación es orientativa y no reemplaza la valoración de un especialista."
        )
    return (
        base +
        f"Se identificaron varias áreas de dificultad: {areas}. "
        f"Se sugiere informar estos resultados al docente o especialista para una valoración profesional. "
        f"¡MathMágico te ayudará a practicar y mejorar! 💙 "
        f"Nota: Esta evaluación es orientativa y no constituye un diagnóstico clínico."
    )


@router.get("/preguntas", response_model=List[DiagnosticoPreguntaResponse])
async def get_preguntas():
    """Retorna las 15 preguntas del diagnóstico."""
    return [DiagnosticoPreguntaResponse(**p) for p in DIAGNOSTICO_PREGUNTAS]


@router.post("/submit", response_model=DiagnosticoResultadoResponse)
async def submit_diagnostico(
    data: DiagnosticoSubmitRequest,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).where(User.id == data.user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")

    # Evaluar respuestas
    total = len(DIAGNOSTICO_PREGUNTAS)
    correctas = 0
    errores_por_categoria: dict = {}

    for r in data.respuestas:
        pregunta = next((p for p in DIAGNOSTICO_PREGUNTAS if p["id"] == r.pregunta_id), None)
        if not pregunta:
            continue
        es_correcta = r.respuesta == pregunta["correcta"]
        if es_correcta:
            correctas += 1
        else:
            cat = pregunta["categoria"]
            errores_por_categoria[cat] = errores_por_categoria.get(cat, 0) + 1

    porcentaje = (correctas / total * 100) if total > 0 else 0
    nivel = calcular_nivel(porcentaje)

    # Categorías con más errores (debilidades)
    NOMBRES_CAT = {
        "reconocimiento": "Reconocimiento de números",
        "conteo":         "Conteo",
        "comparacion":    "Comparación de cantidades",
        "operaciones":    "Operaciones básicas",
        "secuencias":     "Secuencias numéricas",
        "relacion_cantidad": "Relación número-cantidad",
    }
    debilidades = [NOMBRES_CAT.get(c, c) for c, e in errores_por_categoria.items() if e >= 1]

    # Guardar en BD
    diag = Diagnostico(
        id=str(uuid.uuid4()),
        user_id=data.user_id,
        total_dificultades=total - correctas,
        nivel_riesgo=nivel,
    )
    for r in data.respuestas:
        pregunta = next((p for p in DIAGNOSTICO_PREGUNTAS if p["id"] == r.pregunta_id), None)
        if not pregunta:
            continue
        diag.respuestas.append(DiagnosticoRespuesta(
            id=str(uuid.uuid4()),
            pregunta_id=r.pregunta_id,
            indicador=pregunta["indicador"],
            respuesta=(r.respuesta == pregunta["correcta"]),  # True=correcto
        ))
    db.add(diag)
    await db.commit()

    return DiagnosticoResultadoResponse(
        diagnostico_id=diag.id,
        porcentaje=round(porcentaje, 1),
        correctas=correctas,
        total=total,
        nivel_riesgo=nivel,
        etiqueta_nivel=etiqueta_nivel(nivel),
        debilidades=debilidades,
        mensaje=mensaje_resultado(nivel, user.name, porcentaje, debilidades),
        actividades_recomendadas=_actividades_recomendadas(errores_por_categoria),
    )


@router.get("/resultado/{user_id}", response_model=DiagnosticoResultadoResponse)
async def get_ultimo_resultado(user_id: str, db: AsyncSession = Depends(get_db)):
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
    total = len(DIAGNOSTICO_PREGUNTAS)
    correctas = total - diag.total_dificultades
    porcentaje = correctas / total * 100 if total > 0 else 0

    return DiagnosticoResultadoResponse(
        diagnostico_id=diag.id,
        porcentaje=round(porcentaje, 1),
        correctas=correctas,
        total=total,
        nivel_riesgo=diag.nivel_riesgo,
        etiqueta_nivel=etiqueta_nivel(diag.nivel_riesgo),
        debilidades=[],
        mensaje=mensaje_resultado(diag.nivel_riesgo, user.name if user else "", porcentaje, []),
        actividades_recomendadas=_actividades_recomendadas({}),
    )


@router.get("/profesor/{user_id}")
async def get_diagnostico_profesor(user_id: str, db: AsyncSession = Depends(get_db)):
    """Vista detallada para el profesor."""
    result = await db.execute(
        select(Diagnostico)
        .where(Diagnostico.user_id == user_id)
        .order_by(Diagnostico.created_at.desc())
        .limit(1)
    )
    diag = result.scalar_one_or_none()
    if not diag:
        raise HTTPException(status_code=404, detail="Sin diagnóstico")

    resp_result = await db.execute(
        select(DiagnosticoRespuesta).where(DiagnosticoRespuesta.diagnostico_id == diag.id)
    )
    respuestas = resp_result.scalars().all()
    total = len(DIAGNOSTICO_PREGUNTAS)
    correctas = sum(1 for r in respuestas if r.respuesta)
    porcentaje = correctas / total * 100 if total > 0 else 0

    detalle = []
    for r in respuestas:
        pregunta = next((p for p in DIAGNOSTICO_PREGUNTAS if p["id"] == r.pregunta_id), {})
        detalle.append({
            "pregunta_id":  r.pregunta_id,
            "categoria":    pregunta.get("categoria", ""),
            "texto":        pregunta.get("texto", ""),
            "correcta":     pregunta.get("correcta", ""),
            "es_correcto":  r.respuesta,
        })

    return {
        "diagnostico_id":    diag.id,
        "fecha":             diag.created_at.isoformat(),
        "porcentaje":        round(porcentaje, 1),
        "correctas":         correctas,
        "total":             total,
        "nivel_riesgo":      diag.nivel_riesgo,
        "etiqueta_nivel":    etiqueta_nivel(diag.nivel_riesgo),
        "criterio":          "Butterworth: 85%+ sin indicadores | 70-84% leve | 50-69% moderado | <50% alto",
        "detalle":           detalle,
    }


def _actividades_recomendadas(errores: dict) -> List[str]:
    recomendadas = []
    if errores.get("reconocimiento", 0) >= 1:
        recomendadas.append("reconocer_numeros")
    if errores.get("conteo", 0) >= 1:
        recomendadas.append("conteo")
    if errores.get("comparacion", 0) >= 1:
        recomendadas.append("comparar")
    if errores.get("operaciones", 0) >= 1:
        recomendadas.append("suma_visual")
        recomendadas.append("resta_visual")
    if errores.get("secuencias", 0) >= 1:
        recomendadas.append("secuencias")
    if not recomendadas:
        recomendadas = ["suma_visual", "secuencias", "comparar"]
    return list(dict.fromkeys(recomendadas))[:4]
