from sqlalchemy import Column, String, Integer, Float, DateTime, JSON, Text, Boolean, ForeignKey
from sqlalchemy.sql import func
from app.database import Base
import uuid


def gen_uuid():
    return str(uuid.uuid4())


class Teacher(Base):
    """Tabla de profesores."""
    __tablename__ = "teachers"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    name = Column(String(100), nullable=False)
    email = Column(String(100), nullable=False, unique=True)
    password_hash = Column(String(255), nullable=False)
    school = Column(String(200), nullable=True)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    def to_dict(self):
        return {
            "id": self.id,
            "name": self.name,
            "email": self.email,
            "school": self.school,
            "is_active": self.is_active,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }


class User(Base):
    """Tabla de estudiantes (niños)."""
    __tablename__ = "users"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    name = Column(String(100), nullable=False)
    age = Column(Integer, nullable=False)
    avatar_emoji = Column(String(10), default="🦁")
    total_points = Column(Integer, default=0)
    level = Column(Integer, default=1)
    achievements = Column(JSON, default=list)
    skill_levels = Column(JSON, default=dict)
    teacher_id = Column(String(36), nullable=True)
    grade = Column(String(20), nullable=True)
    parent_name = Column(String(200), nullable=True)   
    parent_phone = Column(String(20), nullable=True)   
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    def to_dict(self):
        return {
            "id": self.id,
            "name": self.name,
            "age": self.age,
            "avatar_emoji": self.avatar_emoji,
            "total_points": self.total_points,
            "level": self.level,
            "achievements": self.achievements or [],
            "skill_levels": self.skill_levels or {},
            "teacher_id": self.teacher_id,
            "grade": self.grade,
            "parent_name": self.parent_name,
            "parent_phone": self.parent_phone,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }


class Session(Base):
    """Resultados de actividades."""
    __tablename__ = "sessions"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    user_id = Column(String(36), nullable=False)
    activity_type = Column(String(50), nullable=False)
    difficulty = Column(String(20), default="facil")
    total_questions = Column(Integer, nullable=False)
    correct_answers = Column(Integer, nullable=False)
    points_earned = Column(Integer, nullable=False)
    time_taken_seconds = Column(Integer, nullable=False)
    accuracy = Column(Float, nullable=False)
    question_results = Column(JSON, default=list)
    completed_at = Column(DateTime(timezone=True), server_default=func.now())

    def to_dict(self):
        return {
            "id": self.id,
            "user_id": self.user_id,
            "activity_type": self.activity_type,
            "total_questions": self.total_questions,
            "correct_answers": self.correct_answers,
            "points_earned": self.points_earned,
            "accuracy": self.accuracy,
            "completed_at": self.completed_at.isoformat() if self.completed_at else None,
        }


class Question(Base):
    __tablename__ = "questions"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    activity_type = Column(String(50), nullable=False)
    difficulty = Column(String(20), nullable=False)
    question_text = Column(String(200), nullable=False)
    operands = Column(JSON, nullable=False)
    correct_answer = Column(Integer, nullable=False)
    choices = Column(JSON, nullable=False)
    hint = Column(Text, nullable=True)
    emoji1 = Column(String(10), nullable=True)
    emoji2 = Column(String(10), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    def to_dict(self):
        return {
            "id": self.id,
            "activity_type": self.activity_type,
            "difficulty": self.difficulty,
            "question_text": self.question_text,
            "operands": self.operands,
            "correct_answer": self.correct_answer,
            "choices": self.choices,
            "hint": self.hint,
            "emoji1": self.emoji1,
            "emoji2": self.emoji2,
        }


class AiAnalysis(Base):
    __tablename__ = "ai_analyses"

    id = Column(String(36), primary_key=True, default=gen_uuid)
    user_id = Column(String(36), nullable=False)
    insight = Column(Text, nullable=False)
    recommended_activities = Column(JSON, default=list)
    weak_skills = Column(JSON, default=list)
    strong_skills = Column(JSON, default=list)
    created_at = Column(DateTime(timezone=True), server_default=func.now())