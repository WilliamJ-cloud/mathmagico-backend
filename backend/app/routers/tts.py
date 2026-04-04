from fastapi import APIRouter, Depends, Query
from app.services.tts_service import tts_service

router = APIRouter()


@router.get("/instruction")
async def get_instruction(
    activity_type: str = Query(...),
):
    """Obtiene la instrucción de voz para una actividad."""
    return {
        "text": tts_service.get_instruction(activity_type),
        "activity_type": activity_type,
    }


@router.get("/hint-text")
async def get_hint_text(
    activity_type: str = Query(...),
    num1: int = Query(default=None),
    num2: int = Query(default=None),
    emoji1: str = Query(default=None),
    emoji2: str = Query(default=None),
):
    """Obtiene texto de pista optimizado para TTS."""
    return {
        "hint": tts_service.get_hint(
            activity_type,
            num1=num1,
            num2=num2,
            emoji1=emoji1,
            emoji2=emoji2,
        )
    }


@router.get("/success")
async def get_success():
    """Mensaje de éxito aleatorio."""
    return {"message": tts_service.get_success_message()}


@router.get("/encouragement")
async def get_encouragement():
    """Mensaje de aliento aleatorio."""
    return {"message": tts_service.get_encouragement()}


@router.get("/completion")
async def get_completion(name: str = Query(...)):
    """Mensaje de finalización de actividad."""
    return {"message": tts_service.get_completion_message(name)}


@router.get("/number/{n}")
async def get_number_name(n: int):
    """Nombre en español de un número."""
    return {
        "number": n,
        "name": tts_service.get_number_name(n),
        "display": str(n),
    }