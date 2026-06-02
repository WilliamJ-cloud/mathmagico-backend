from sqlalchemy import Column, String, Integer, Float, DateTime, Text, Boolean, ForeignKey
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.database import Base
import uuid


def gen_uuid():
    return str(uuid.uuid4())


# ── Preguntas del diagnóstico Butterworth (8 indicadores clave) ──────────────
DIAGNOSTICO_PREGUNTAS = [
    {
        "id": 1,
        "texto": "¿Puedes contar estos objetos tocándolos uno por uno?",
        "emoji": "🍎🍎🍎🍎",
        "audio": "¿Puedes contar estos objetos tocándolos uno por uno?",
        "indicador": "conteo_ordenado",
    },
    {
        "id": 2,
        "texto": "¿Sabes qué número es este?",
        "emoji": "7️⃣",
        "audio": "¿Sabes qué número es este?",
        "indicador": "reconoce_numeros",
    },
    {
        "id": 3,
        "texto": "¿Puedes decir cuál grupo tiene más?",
        "emoji": "🌟🌟🌟  vs  🌟🌟🌟🌟🌟",
        "audio": "¿Puedes decir cuál grupo tiene más?",
        "indicador": "compara_cantidades",
    },
    {
        "id": 4,
        "texto": "¿Puedes sumar usando tus dedos? Por ejemplo: 2 + 1",
        "emoji": "✌️ + ☝️",
        "audio": "¿Puedes sumar usando tus dedos? Por ejemplo: dos más uno",
        "indicador": "suma_con_dedos",
    },
    {
        "id": 5,
        "texto": "¿Estos dos números te parecen iguales?",
        "emoji": "6️⃣ y 9️⃣",
        "audio": "¿Estos dos números te parecen iguales?",
        "indicador": "confusion_numeros",
    },
    {
        "id": 6,
        "texto": "¿Puedes ordenar estos números del más pequeño al más grande?",
        "emoji": "3️⃣ 1️⃣ 5️⃣ 2️⃣",
        "audio": "¿Puedes ordenar estos números del más pequeño al más grande?",
        "indicador": "orden_numeros",
    },
    {
        "id": 7,
        "texto": "¿Sabes que cada objeto que cuentas tiene un número diferente?",
        "emoji": "🐶=1  🐱=2  🐭=3",
        "audio": "¿Sabes que cuando cuentas, cada objeto tiene su propio número?",
        "indicador": "correspondencia_uno_a_uno",
    },
    {
        "id": 8,
        "texto": "¿Puedes quitar objetos? Por ejemplo: tienes 3 manzanas y comes 1",
        "emoji": "🍎🍎🍎 − 🍎",
        "audio": "¿Puedes quitar objetos? Por ejemplo: tienes tres manzanas y comes una",
        "indicador": "resta_con_objetos",
    },
]

# ── Niveles por puntos (evita almacenar dato derivado) ────────────────────────
def calc_level(total_points: int) -> int:
    if total_points >= 1000:
        return 5
    elif total_points >= 600:
        return 4
    elif total_points >= 300:
        return 3
    elif total_points >= 100:
        return 2
    return 1


# ══════════════════════════════════════════════════════════════════════════════
# TEACHERS
# ══════════════════════════════════════════════════════════════════════════════
class Teacher(Base):
    __tablename__ = "teachers"

    id            = Column(String(36), primary_key=True, default=gen_uuid)
    name          = Column(String(100), nullable=False)
    email         = Column(String(100), nullable=False, unique=True)
    password_hash = Column(String(255), nullable=False)
    school        = Column(String(200), nullable=True)
    is_active     = Column(Boolean, default=True)
    created_at    = Column(DateTime(timezone=True), server_default=func.now())

    # 2FN: relación declarada
    students = relationship("User", back_populates="teacher")

    def to_dict(self):
        return {
            "id": self.id,
            "name": self.name,
            "email": self.email,
            "school": self.school,
            "is_active": self.is_active,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }


# ══════════════════════════════════════════════════════════════════════════════
# USERS (estudiantes)
# 3FN: se eliminan 'achievements' (JSON), 'skill_levels' (JSON) y 'level'
#      (level es dato derivado de total_points → se calcula con calc_level())
# ══════════════════════════════════════════════════════════════════════════════
class User(Base):
    __tablename__ = "users"

    id           = Column(String(36), primary_key=True, default=gen_uuid)
    name         = Column(String(100), nullable=False)
    age          = Column(Integer, nullable=False)
    avatar_emoji = Column(String(10), default="🦁")
    total_points = Column(Integer, default=0)
    # 2FN: FK real hacia teachers
    teacher_id   = Column(String(36), ForeignKey("teachers.id"), nullable=True)
    grade        = Column(String(20), nullable=True)
    parent_name  = Column(String(200), nullable=True)
    parent_phone = Column(String(20), nullable=True)
    created_at   = Column(DateTime(timezone=True), server_default=func.now())
    updated_at   = Column(DateTime(timezone=True), onupdate=func.now())

    teacher      = relationship("Teacher", back_populates="students")
    # 1FN: logros y habilidades en tablas propias
    achievements = relationship("UserAchievement", back_populates="user", cascade="all, delete-orphan")
    skill_levels = relationship("UserSkillLevel",  back_populates="user", cascade="all, delete-orphan")
    sessions     = relationship("Session", back_populates="user", cascade="all, delete-orphan")
    ai_analyses  = relationship("AiAnalysis", back_populates="user", cascade="all, delete-orphan")

    @property
    def level(self):
        return calc_level(self.total_points or 0)

    def to_dict(self):
        return {
            "id": self.id,
            "name": self.name,
            "age": self.age,
            "avatar_emoji": self.avatar_emoji,
            "total_points": self.total_points,
            "level": self.level,
            "teacher_id": self.teacher_id,
            "grade": self.grade,
            "parent_name": self.parent_name,
            "parent_phone": self.parent_phone,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }


# ══════════════════════════════════════════════════════════════════════════════
# USER_ACHIEVEMENTS  (1FN: antes era JSON en User.achievements)
# ══════════════════════════════════════════════════════════════════════════════
class UserAchievement(Base):
    __tablename__ = "user_achievements"

    id              = Column(String(36), primary_key=True, default=gen_uuid)
    user_id         = Column(String(36), ForeignKey("users.id"), nullable=False)
    achievement_key = Column(String(50), nullable=False)
    unlocked_at     = Column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", back_populates="achievements")


# ══════════════════════════════════════════════════════════════════════════════
# USER_SKILL_LEVELS  (1FN: antes era JSON en User.skill_levels)
# ══════════════════════════════════════════════════════════════════════════════
class UserSkillLevel(Base):
    __tablename__ = "user_skill_levels"

    id         = Column(String(36), primary_key=True, default=gen_uuid)
    user_id    = Column(String(36), ForeignKey("users.id"), nullable=False)
    skill_name = Column(String(50), nullable=False)
    level      = Column(Integer, default=0)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    user = relationship("User", back_populates="skill_levels")


# ══════════════════════════════════════════════════════════════════════════════
# SESSIONS
# 3FN: se elimina 'accuracy' (dato derivado: correct_answers / total_questions)
# 1FN: question_results (JSON) pasa a tabla QuestionResult
# ══════════════════════════════════════════════════════════════════════════════
class Session(Base):
    __tablename__ = "sessions"

    id                  = Column(String(36), primary_key=True, default=gen_uuid)
    # 2FN: FK real
    user_id             = Column(String(36), ForeignKey("users.id"), nullable=False)
    activity_type       = Column(String(50), nullable=False)
    difficulty          = Column(String(20), default="facil")
    total_questions     = Column(Integer, nullable=False)
    correct_answers     = Column(Integer, nullable=False)
    points_earned       = Column(Integer, nullable=False)
    time_taken_seconds  = Column(Integer, nullable=False)
    completed_at        = Column(DateTime(timezone=True), server_default=func.now())

    user             = relationship("User", back_populates="sessions")
    # 1FN: resultados por pregunta en tabla propia
    question_results = relationship("QuestionResult", back_populates="session", cascade="all, delete-orphan")

    @property
    def accuracy(self):
        if self.total_questions and self.total_questions > 0:
            return self.correct_answers / self.total_questions
        return 0.0

    def to_dict(self):
        return {
            "id": self.id,
            "user_id": self.user_id,
            "activity_type": self.activity_type,
            "difficulty": self.difficulty,
            "total_questions": self.total_questions,
            "correct_answers": self.correct_answers,
            "points_earned": self.points_earned,
            "accuracy": self.accuracy,
            "completed_at": self.completed_at.isoformat() if self.completed_at else None,
        }


# ══════════════════════════════════════════════════════════════════════════════
# QUESTION_RESULTS  (1FN: antes era JSON en Session.question_results)
# ══════════════════════════════════════════════════════════════════════════════
class QuestionResult(Base):
    __tablename__ = "question_results"

    id             = Column(String(36), primary_key=True, default=gen_uuid)
    session_id     = Column(String(36), ForeignKey("sessions.id"), nullable=False)
    question_id    = Column(String(36), ForeignKey("questions.id"), nullable=True)
    is_correct     = Column(Boolean, nullable=False)
    answer_given   = Column(Integer, nullable=True)
    hints_used     = Column(Integer, default=0)
    time_seconds   = Column(Integer, default=0)

    session  = relationship("Session", back_populates="question_results")
    question = relationship("Question")


# ══════════════════════════════════════════════════════════════════════════════
# QUESTIONS
# 1FN: operands (JSON) y choices (JSON) pasan a tablas propias
# ══════════════════════════════════════════════════════════════════════════════
class Question(Base):
    __tablename__ = "questions"

    id             = Column(String(36), primary_key=True, default=gen_uuid)
    activity_type  = Column(String(50), nullable=False)
    difficulty     = Column(String(20), nullable=False)
    question_text  = Column(String(200), nullable=False)
    correct_answer = Column(Integer, nullable=False)
    hint           = Column(Text, nullable=True)
    emoji1         = Column(String(10), nullable=True)
    emoji2         = Column(String(10), nullable=True)
    created_at     = Column(DateTime(timezone=True), server_default=func.now())

    # 1FN: operandos y opciones en tablas propias
    operands = relationship("QuestionOperand", back_populates="question",
                            order_by="QuestionOperand.position", cascade="all, delete-orphan")
    choices  = relationship("QuestionChoice",  back_populates="question",
                            order_by="QuestionChoice.position",  cascade="all, delete-orphan")

    def to_dict(self):
        return {
            "id": self.id,
            "activity_type": self.activity_type,
            "difficulty": self.difficulty,
            "question_text": self.question_text,
            "operands": [o.value for o in self.operands],
            "correct_answer": self.correct_answer,
            "choices": [c.value for c in self.choices],
            "hint": self.hint,
            "emoji1": self.emoji1,
            "emoji2": self.emoji2,
        }


# ══════════════════════════════════════════════════════════════════════════════
# QUESTION_OPERANDS  (1FN: antes era JSON en Question.operands)
# ══════════════════════════════════════════════════════════════════════════════
class QuestionOperand(Base):
    __tablename__ = "question_operands"

    id          = Column(String(36), primary_key=True, default=gen_uuid)
    question_id = Column(String(36), ForeignKey("questions.id"), nullable=False)
    position    = Column(Integer, nullable=False)
    value       = Column(Integer, nullable=False)

    question = relationship("Question", back_populates="operands")


# ══════════════════════════════════════════════════════════════════════════════
# QUESTION_CHOICES  (1FN: antes era JSON en Question.choices)
# ══════════════════════════════════════════════════════════════════════════════
class QuestionChoice(Base):
    __tablename__ = "question_choices"

    id          = Column(String(36), primary_key=True, default=gen_uuid)
    question_id = Column(String(36), ForeignKey("questions.id"), nullable=False)
    position    = Column(Integer, nullable=False)
    value       = Column(Integer, nullable=False)

    question = relationship("Question", back_populates="choices")


# ══════════════════════════════════════════════════════════════════════════════
# AI_ANALYSES
# 1FN: recommended_activities, weak_skills, strong_skills (JSON) → tablas propias
# ══════════════════════════════════════════════════════════════════════════════
class AiAnalysis(Base):
    __tablename__ = "ai_analyses"

    id         = Column(String(36), primary_key=True, default=gen_uuid)
    # 2FN: FK real
    user_id    = Column(String(36), ForeignKey("users.id"), nullable=False)
    insight    = Column(Text, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    user                   = relationship("User", back_populates="ai_analyses")
    recommended_activities = relationship("AiRecommendation",   back_populates="analysis", cascade="all, delete-orphan")
    skill_assessments      = relationship("AiSkillAssessment",  back_populates="analysis", cascade="all, delete-orphan")


# ══════════════════════════════════════════════════════════════════════════════
# AI_RECOMMENDATIONS  (1FN: antes era JSON en AiAnalysis.recommended_activities)
# ══════════════════════════════════════════════════════════════════════════════
class AiRecommendation(Base):
    __tablename__ = "ai_recommendations"

    id            = Column(String(36), primary_key=True, default=gen_uuid)
    analysis_id   = Column(String(36), ForeignKey("ai_analyses.id"), nullable=False)
    activity_type = Column(String(50), nullable=False)
    position      = Column(Integer, default=0)

    analysis = relationship("AiAnalysis", back_populates="recommended_activities")


# ══════════════════════════════════════════════════════════════════════════════
# AI_SKILL_ASSESSMENTS  (1FN: antes era JSON en AiAnalysis.weak_skills / strong_skills)
# ══════════════════════════════════════════════════════════════════════════════
class AiSkillAssessment(Base):
    __tablename__ = "ai_skill_assessments"

    id              = Column(String(36), primary_key=True, default=gen_uuid)
    analysis_id     = Column(String(36), ForeignKey("ai_analyses.id"), nullable=False)
    skill_name      = Column(String(50), nullable=False)
    assessment_type = Column(String(10), nullable=False)  # 'weak' o 'strong'

    analysis = relationship("AiAnalysis", back_populates="skill_assessments")


# ══════════════════════════════════════════════════════════════════════════════
# DIAGNOSTICO  (Butterworth — 8 indicadores)
# ══════════════════════════════════════════════════════════════════════════════
class Diagnostico(Base):
    __tablename__ = "diagnosticos"

    id           = Column(String(36), primary_key=True, default=gen_uuid)
    user_id      = Column(String(36), ForeignKey("users.id"), nullable=False)
    # 3FN: riesgo es dato derivado, se calcula desde las respuestas
    # Se almacena para consulta rápida del profesor
    total_dificultades = Column(Integer, nullable=False)  # cuántos "no"
    nivel_riesgo       = Column(String(20), nullable=False)  # sin_riesgo / moderado / alto
    created_at         = Column(DateTime(timezone=True), server_default=func.now())

    user       = relationship("User")
    # 1FN: respuestas en tabla propia
    respuestas = relationship("DiagnosticoRespuesta", back_populates="diagnostico",
                              cascade="all, delete-orphan")


# ══════════════════════════════════════════════════════════════════════════════
# DIAGNOSTICO_RESPUESTAS  (1FN: cada respuesta es una fila)
# ══════════════════════════════════════════════════════════════════════════════
class DiagnosticoRespuesta(Base):
    __tablename__ = "diagnostico_respuestas"

    id              = Column(String(36), primary_key=True, default=gen_uuid)
    diagnostico_id  = Column(String(36), ForeignKey("diagnosticos.id"), nullable=False)
    pregunta_id     = Column(Integer, nullable=False)   # 1 al 8
    indicador       = Column(String(50), nullable=False)
    respuesta       = Column(Boolean, nullable=False)   # True=Sí, False=No

    diagnostico = relationship("Diagnostico", back_populates="respuestas")
