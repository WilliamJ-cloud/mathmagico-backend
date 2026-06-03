"""
Dependencias de FastAPI reutilizables para autenticacion.
"""
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.security import verify_token

bearer = HTTPBearer()


def get_current_teacher(
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
) -> dict:
    """
    Extrae el JWT del header  Authorization: Bearer <token>
    y verifica que sea valido y corresponda a un profesor.

    Devuelve el payload del token: {'sub': teacher_id, 'role': 'teacher', 'exp': ...}
    Lanza HTTP 401 si el token falta o es invalido.
    Lanza HTTP 403 si el token no corresponde a un profesor.
    """
    payload = verify_token(credentials.credentials)

    if payload.get("role") != "teacher":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Acceso restringido a profesores.",
        )
    return payload
