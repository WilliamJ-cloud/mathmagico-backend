from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
from datetime import datetime


# ==================== USUARIOS ====================

class UserRegisterRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    age: int = Field(..., ge=5, le=12)
    avatar_emoji: str = Field(default="🦁")


class UserLoginRequest(BaseModel):
    user_id: str


class UserResponse(BaseModel):
    id: str
    name: str
    age: int
    avatar_emoji: str
    total_points: int
    level: int
    achievements: List[str]
    skill_levels: Dict[str, int]
    created_at: Optional[str] = None

    class Config:
        from_attributes = True


class UserAuthResponse(BaseModel):
    user: UserResponse
    token: str


# ==================== ACTIVIDADES ====================

class QuestionResponse(BaseModel):
    id: str
    activity_type: str
    difficulty: str
    question_text: str
    operands: List[Any]
    correct_answer: int
    choices: List[int]
    hint: Optional[str] = None
    emoji1: Optional[str] = None
    emoji2: Optional[str] = None


class QuestionResultItem(BaseModel):
    question_id: str
    user_answer: int
    correct_answer: int
    is_correct: bool
    hints_used: int = 0


class ActivitySubmitRequest(BaseModel):
    activity_id: str
    user_id: str
    total_questions: int
    correct_answers: int
    points_earned: int
    time_taken_seconds: int
    accuracy: float
    completed_at: str
    question_results: List[QuestionResultItem] = []


class ActivitySubmitResponse(BaseModel):
    success: bool
    points_awarded: int
    new_total_points: int
    achievements_unlocked: List[str] = []
    message: str


# ==================== PROGRESO ====================

class SkillProgressResponse(BaseModel):
    name: str
    percentage: float
    total_attempts: int
    correct_attempts: int
    trend: str  # 'up', 'down', 'stable'


class SessionSummaryResponse(BaseModel):
    activity_type: str
    accuracy: float
    points: int
    date: str


class ProgressResponse(BaseModel):
    user_id: str
    skills: Dict[str, SkillProgressResponse]
    recent_sessions: List[SessionSummaryResponse] = []
    ai_insight: str = ""
    recommended_activities: List[str] = []
    weekly_streak: int = 0
    last_activity: str


# ==================== IA ====================

class HintRequest(BaseModel):
    activity_type: str
    question_number: int
    user_id: str
    question_context: Dict[str, Any]


class HintResponse(BaseModel):
    hint: str
    spoken_hint: str  # Versión simplificada para TTS


class AnalysisResponse(BaseModel):
    insight: str
    recommended_activities: List[str]
    weak_skills: List[str]
    strong_skills: List[str]
    encouragement: str