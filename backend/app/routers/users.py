from fastapi import APIRouter, Depends, HTTPException, status, Query
from typing import List
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import datetime, timedelta
from jose import jwt
import uuid

from app.database import get_db
from app.models import User, UserAchievement, UserSkillLevel
from app.schemas import UserRegisterRequest, UserLoginRequest, UserAuthResponse, UserResponse
from app.config import settings

router = APIRouter()


def create_token(user_id: str) -> str:
    expire = datetime.utcnow() + timedelta(minutes=settings.jwt_expire_minutes)
    payload = {"sub": user_id, "exp": expire}
    return jwt.encode(payload, settings.secret_key, algorithm=settings.jwt_algorithm)


def _user_to_response(user: User) -> UserResponse:
    """Convierte User a UserResponse leyendo tablas normalizadas."""
    achievements = [a.achievement_key for a in (user.achievements or [])]
    skill_levels = {s.skill_name: s.level for s in (user.skill_levels or [])}
    return UserResponse(
        id=user.id,
        name=user.name,
        age=user.age,
        avatar_emoji=user.avatar_emoji,
        total_points=user.total_points or 0,
        level=user.level,
        achievements=achievements,
        skill_levels=skill_levels,
        created_at=user.created_at.isoformat() if user.created_at else None,
    )


@router.post("/register", response_model=UserAuthResponse, status_code=status.HTTP_201_CREATED)
async def register_user(
    data: UserRegisterRequest,
    db: AsyncSession = Depends(get_db),
):
    user = User(
        id=str(uuid.uuid4()),
        name=data.name,
        age=data.age,
        avatar_emoji=data.avatar_emoji,
        total_points=0,
    )
    # Inicializar habilidades en tabla normalizada (1FN)
    for skill in ["conteo", "suma", "resta", "comparar", "secuencias", "reconocer"]:
        user.skill_levels.append(UserSkillLevel(
            id=str(uuid.uuid4()), skill_name=skill, level=0
        ))
    db.add(user)
    await db.commit()
    await db.refresh(user)

    token = create_token(user.id)
    return UserAuthResponse(user=_user_to_response(user), token=token)


@router.post("/login", response_model=UserAuthResponse)
async def login_user(
    data: UserLoginRequest,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).where(User.id == data.user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND,
                            detail="Usuario no encontrado")
    token = create_token(user.id)
    return UserAuthResponse(user=_user_to_response(user), token=token)


@router.get("/search", response_model=List[UserResponse])
async def search_users(name: str = Query(..., min_length=2),
                       db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(User).where(User.name.ilike(f"%{name}%")).limit(10)
    )
    users = result.scalars().all()
    return [_user_to_response(u) for u in users]


@router.get("/{user_id}", response_model=UserResponse)
async def get_user(user_id: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    return _user_to_response(user)
