"""
Seguridad centralizada de MathMagico.

  - SHA-256  → hash de contrasenas de profesores
  - JWT HS256 → tokens de sesion (7 dias por defecto)

Todos los routers importan desde aqui en vez de redefinir funciones.
"""
import hashlib
import hmac
from datetime import datetime, timedelta, timezone

from fastapi import HTTPException, status
from jose import JWTError, jwt

from app.config import settings


# ── SHA-256 ───────────────────────────────────────────────────────────────────

def hash_password(password: str) -> str:
    """Devuelve el hash SHA-256 de la contraseña como cadena hex de 64 chars."""
    return hashlib.sha256(password.encode("utf-8")).hexdigest()


def verify_password(plain: str, hashed: str) -> bool:
    """
    Compara en tiempo constante para evitar timing attacks.
    Calcula SHA-256 del texto plano y lo compara con el hash almacenado.
    """
    return hmac.compare_digest(hash_password(plain), hashed)


# ── JWT HS256 ─────────────────────────────────────────────────────────────────

def create_token(subject: str, role: str = "teacher") -> str:
    """
    Crea un JWT firmado con HS256.
    Payload: sub (ID del usuario), role, exp (expiracion).
    """
    expire = datetime.now(timezone.utc) + timedelta(
        minutes=settings.jwt_expire_minutes
    )
    payload = {"sub": subject, "role": role, "exp": expire}
    return jwt.encode(payload, settings.secret_key, algorithm=settings.jwt_algorithm)


def verify_token(token: str) -> dict:
    """
    Decodifica y verifica la firma del JWT.
    Lanza HTTP 401 si el token es invalido o expiro.
    """
    try:
        return jwt.decode(
            token, settings.secret_key, algorithms=[settings.jwt_algorithm]
        )
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token invalido o expirado. Inicia sesion nuevamente.",
            headers={"WWW-Authenticate": "Bearer"},
        )
