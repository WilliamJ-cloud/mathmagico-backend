from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from jose import jwt
from datetime import datetime, timedelta
import hashlib
import uuid
import io

from app.database import get_db
from app.models import Teacher, User, Session
from app.config import settings

router = APIRouter()


# ── Utilidades auth ───────────────────────────────────────
def _hash(password: str) -> str:
    return hashlib.sha256(password.encode("utf-8")).hexdigest()


def _verify(plain: str, hashed: str) -> bool:
    return _hash(plain) == hashed


def _token(teacher_id: str) -> str:
    expire = datetime.utcnow() + timedelta(
        minutes=settings.jwt_expire_minutes
    )
    return jwt.encode(
        {"sub": teacher_id, "exp": expire, "role": "teacher"},
        settings.secret_key,
        algorithm=settings.jwt_algorithm,
    )


# ── Registro ──────────────────────────────────────────────
@router.post("/register", status_code=201)
async def register_teacher(
    data: dict, db: AsyncSession = Depends(get_db)
):
    if not data.get("email") or not data.get("password"):
        raise HTTPException(
            status_code=422,
            detail="email y password son requeridos",
        )

    result = await db.execute(
        select(Teacher).where(Teacher.email == data["email"])
    )
    if result.scalar_one_or_none():
        raise HTTPException(
            status_code=400,
            detail="El correo ya esta registrado",
        )

    teacher = Teacher(
        id=str(uuid.uuid4()),
        name=str(data.get("name") or "Profesor"),
        email=str(data["email"]),
        password_hash=_hash(str(data["password"])),
        school=str(data.get("school") or ""),
    )
    db.add(teacher)
    await db.commit()
    await db.refresh(teacher)

    return {
        "teacher": teacher.to_dict(),
        "token": _token(teacher.id),
    }


# ── Login ─────────────────────────────────────────────────
@router.post("/login")
async def login_teacher(
    data: dict, db: AsyncSession = Depends(get_db)
):
    if not data.get("email") or not data.get("password"):
        raise HTTPException(
            status_code=422,
            detail="email y password son requeridos",
        )

    result = await db.execute(
        select(Teacher).where(Teacher.email == str(data["email"]))
    )
    teacher = result.scalar_one_or_none()

    if not teacher or not _verify(
        str(data["password"]), teacher.password_hash
    ):
        raise HTTPException(
            status_code=401,
            detail="Correo o contrasena incorrectos",
        )

    return {
        "teacher": teacher.to_dict(),
        "token": _token(teacher.id),
    }


# ── Listar estudiantes ────────────────────────────────────
@router.get("/{teacher_id}/students")
async def get_students(
    teacher_id: str, db: AsyncSession = Depends(get_db)
):
    result = await db.execute(
        select(User)
        .where(User.teacher_id == teacher_id)
        .order_by(User.name)
    )
    students = result.scalars().all()

    out = []
    for s in students:
        last_q = await db.execute(
            select(Session)
            .where(Session.user_id == s.id)
            .order_by(Session.completed_at.desc())
            .limit(1)
        )
        last = last_q.scalar_one_or_none()

        cnt_q = await db.execute(
            select(func.count(Session.id)).where(
                Session.user_id == s.id
            )
        )
        avg_q = await db.execute(
            select(func.avg(Session.accuracy)).where(
                Session.user_id == s.id
            )
        )
        d = s.to_dict()
        d["total_sessions"] = cnt_q.scalar() or 0
        d["avg_accuracy"] = round(
            float(avg_q.scalar() or 0.0) * 100, 1
        )
        d["last_activity"] = (
            last.completed_at.isoformat()
            if last and last.completed_at
            else None
        )
        out.append(d)

    return {"students": out, "total": len(out)}


# ── Agregar estudiante ────────────────────────────────────
@router.post("/{teacher_id}/students")
async def add_student(
    teacher_id: str,
    data: dict,
    db: AsyncSession = Depends(get_db),
):
    student = User(
        id=str(uuid.uuid4()),
        name=str(data.get("name") or "Estudiante"),
        age=int(data.get("age") or 7),
        avatar_emoji=str(data.get("avatar_emoji") or "🦁"),
        teacher_id=teacher_id,
        grade=str(data.get("grade") or ""),
        parent_name=str(data.get("parent_name") or ""),
        parent_phone=str(data.get("parent_phone") or ""),
        total_points=0,
        level=1,
        achievements=[],
        skill_levels={
            "conteo": 0,
            "suma": 0,
            "resta": 0,
            "comparar": 0,
            "secuencias": 0,
            "reconocer": 0,
        },
    )
    db.add(student)
    await db.commit()
    await db.refresh(student)
    return {
        "student": student.to_dict(),
        "message": "Estudiante agregado",
    }


# ── Actualizar datos de estudiante ────────────────────────
@router.put("/{teacher_id}/students/{student_id}")
async def update_student(
    teacher_id: str,
    student_id: str,
    data: dict,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(User).where(
            User.id == student_id,
            User.teacher_id == teacher_id,
        )
    )
    student = result.scalar_one_or_none()
    if not student:
        raise HTTPException(status_code=404, detail="Estudiante no encontrado")

    if "name" in data:
        student.name = str(data["name"]).strip() or student.name
    if "age" in data:
        student.age = int(data["age"])
    if "grade" in data:
        student.grade = str(data["grade"]).strip()
    if "parent_name" in data:
        student.parent_name = str(data["parent_name"]).strip()
    if "parent_phone" in data:
        student.parent_phone = str(data["parent_phone"]).strip()
    if "avatar_emoji" in data:
        student.avatar_emoji = str(data["avatar_emoji"]).strip()

    await db.commit()
    await db.refresh(student)
    return {"message": "Estudiante actualizado", "student": student.to_dict()}


# ── Eliminar estudiante ───────────────────────────────────
@router.delete("/{teacher_id}/students/{student_id}")
async def delete_student(
    teacher_id: str,
    student_id: str,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(User).where(
            User.id == student_id,
            User.teacher_id == teacher_id,
        )
    )
    student = result.scalar_one_or_none()
    if not student:
        raise HTTPException(
            status_code=404, detail="Estudiante no encontrado"
        )
    await db.delete(student)
    await db.commit()
    return {"message": "Estudiante eliminado"}


# ── Progreso de un estudiante ─────────────────────────────
@router.get("/{teacher_id}/students/{student_id}/progress")
async def get_student_progress(
    teacher_id: str,
    student_id: str,
    db: AsyncSession = Depends(get_db),
):
    sr = await db.execute(
        select(User).where(User.id == student_id)
    )
    student = sr.scalar_one_or_none()
    if not student:
        raise HTTPException(
            status_code=404, detail="Estudiante no encontrado"
        )

    sess_r = await db.execute(
        select(Session)
        .where(Session.user_id == student_id)
        .order_by(Session.completed_at.desc())
        .limit(50)
    )
    sessions = sess_r.scalars().all()

    skill_stats: dict = {}
    for s in sessions:
        key = s.activity_type
        if key not in skill_stats:
            skill_stats[key] = {
                "total": 0, "correct": 0, "sessions": 0
            }
        skill_stats[key]["total"] += s.total_questions
        skill_stats[key]["correct"] += s.correct_answers
        skill_stats[key]["sessions"] += 1

    summary = {
        k: {
            "accuracy": (
                round(v["correct"] / v["total"] * 100, 1)
                if v["total"] > 0 else 0
            ),
            "sessions": v["sessions"],
            "total_questions": v["total"],
            "correct_answers": v["correct"],
        }
        for k, v in skill_stats.items()
    }

    # Unique activity dates (ISO "2026-04-04") from all sessions
    activity_dates = sorted(set(
        s.completed_at.strftime("%Y-%m-%d")
        for s in sessions
        if s.completed_at
    ))

    # Consecutive streak calculation
    from datetime import date as _date
    streak = 0
    if activity_dates:
        today   = _date.today()
        dates   = sorted(set(_date.fromisoformat(d) for d in activity_dates), reverse=True)
        latest  = dates[0]
        if latest == today or latest == today - timedelta(days=1):
            streak = 1
            for i in range(1, len(dates)):
                if dates[i] == dates[i - 1] - timedelta(days=1):
                    streak += 1
                else:
                    break

    return {
        "student": student.to_dict(),
        "skills": summary,
        "recent_sessions": [s.to_dict() for s in sessions[:10]],
        "total_sessions": len(sessions),
        "activity_dates": activity_dates,
        "streak": streak,
    }


# ── Dashboard del profesor ────────────────────────────────
@router.get("/{teacher_id}/dashboard")
async def get_dashboard(
    teacher_id: str, db: AsyncSession = Depends(get_db)
):
    cnt_r = await db.execute(
        select(func.count(User.id)).where(
            User.teacher_id == teacher_id
        )
    )
    total = cnt_r.scalar() or 0

    week_ago = datetime.utcnow() - timedelta(days=7)
    ids_r = await db.execute(
        select(User.id).where(User.teacher_id == teacher_id)
    )
    student_ids = [row[0] for row in ids_r.fetchall()]

    active = 0
    avg_acc = 0.0
    if student_ids:
        for sid in student_ids:
            ar = await db.execute(
                select(func.count(Session.id)).where(
                    Session.user_id == sid,
                    Session.completed_at >= week_ago,
                )
            )
            if (ar.scalar() or 0) > 0:
                active += 1
        acc_r = await db.execute(
            select(func.avg(Session.accuracy)).where(
                Session.user_id.in_(student_ids)
            )
        )
        avg_acc = float(acc_r.scalar() or 0.0)

    return {
        "total_students": total,
        "active_this_week": active,
        "avg_accuracy": round(avg_acc * 100, 1),
        "student_ids": student_ids,
    }


# ── Reporte PDF del estudiante ────────────────────────────
@router.get("/{teacher_id}/students/{student_id}/report-pdf")
async def get_student_report_pdf(
    teacher_id: str,
    student_id: str,
    db: AsyncSession = Depends(get_db),
):
    from fpdf import FPDF

    sr = await db.execute(
        select(User).where(User.id == student_id)
    )
    student = sr.scalar_one_or_none()
    if not student:
        raise HTTPException(
            status_code=404, detail="Estudiante no encontrado"
        )

    sess_r = await db.execute(
        select(Session)
        .where(Session.user_id == student_id)
        .order_by(Session.completed_at.desc())
        .limit(20)
    )
    sessions = sess_r.scalars().all()

    total_sess = len(sessions)
    avg_acc = 0.0
    if sessions:
        avg_acc = (
            sum(s.accuracy for s in sessions) / len(sessions) * 100
        )

    skill_stats: dict = {}
    for s in sessions:
        key = s.activity_type
        if key not in skill_stats:
            skill_stats[key] = {"total": 0, "correct": 0}
        skill_stats[key]["total"] += s.total_questions
        skill_stats[key]["correct"] += s.correct_answers

    nombres = {
        "suma_visual":       "Suma visual",
        "resta_visual":      "Resta visual",
        "conteo":            "Conteo tactil",
        "comparar":          "Comparar cantidades",
        "secuencias":        "Ordenar secuencias",
        "reconocer_numeros": "Reconocer numeros",
    }

    pdf = FPDF()
    pdf.add_page()
    pdf.set_auto_page_break(auto=True, margin=15)

    # Encabezado
    pdf.set_fill_color(31, 56, 100)
    pdf.rect(0, 0, 210, 40, "F")
    pdf.set_font("Helvetica", "B", 22)
    pdf.set_text_color(255, 255, 255)
    pdf.set_xy(10, 8)
    pdf.cell(0, 12, "MathMagico", ln=True, align="C")
    pdf.set_font("Helvetica", "", 12)
    pdf.set_xy(10, 22)
    pdf.cell(0, 8, "Reporte de Progreso Academico", ln=True, align="C")

    pdf.set_text_color(0, 0, 0)
    pdf.set_xy(10, 46)
    pdf.set_font("Helvetica", "", 10)
    fecha = datetime.now().strftime("%d/%m/%Y %H:%M")
    pdf.cell(0, 6, f"Fecha de emision: {fecha}", ln=True)

    def seccion(titulo):
        pdf.ln(4)
        pdf.set_fill_color(46, 117, 182)
        pdf.set_text_color(255, 255, 255)
        pdf.set_font("Helvetica", "B", 12)
        pdf.cell(0, 8, f"  {titulo}", ln=True, fill=True)
        pdf.set_text_color(0, 0, 0)
        pdf.set_font("Helvetica", "", 11)
        pdf.ln(2)

    def fila(label, valor, negrita=False):
        pdf.cell(65, 7, label)
        if negrita:
            pdf.set_font("Helvetica", "B", 11)
        pdf.cell(0, 7, str(valor), ln=True)
        pdf.set_font("Helvetica", "", 11)

    # Datos estudiante
    seccion("DATOS DEL ESTUDIANTE")
    fila("Nombre:", student.name, negrita=True)
    fila("Edad:", f"{student.age} años")
    fila("Grado:", student.grade or "No especificado")
    fila("Nivel alcanzado:", f"Nivel {student.level}", negrita=True)
    fila("Puntos totales:", f"{student.total_points} pts", negrita=True)

    # Datos del tutor
    seccion("DATOS DEL PADRE / MADRE / TUTOR")
    fila("Nombre del tutor:", student.parent_name or "No registrado")
    fila("Celular:", student.parent_phone or "No registrado")

    # Resumen
    seccion("RESUMEN DE RENDIMIENTO")
    fila("Total sesiones completadas:", str(total_sess), negrita=True)
    pdf.cell(65, 7, "Precisión promedio:")
    color = (
        (0, 150, 0) if avg_acc >= 70
        else (200, 100, 0) if avg_acc >= 50
        else (200, 0, 0)
    )
    pdf.set_text_color(*color)
    pdf.set_font("Helvetica", "B", 11)
    pdf.cell(0, 7, f"{avg_acc:.1f}%", ln=True)
    pdf.set_text_color(0, 0, 0)
    pdf.set_font("Helvetica", "", 11)

    # Progreso por habilidad
    if skill_stats:
        seccion("PROGRESO POR HABILIDAD")
        pdf.set_fill_color(220, 230, 245)
        pdf.set_font("Helvetica", "B", 10)
        pdf.cell(80, 7, "Habilidad", border=1, fill=True)
        pdf.cell(30, 7, "Sesiones", border=1, fill=True, align="C")
        pdf.cell(35, 7, "Correctas", border=1, fill=True, align="C")
        pdf.cell(35, 7, "Precisión", border=1, fill=True, align="C")
        pdf.ln()
        pdf.set_font("Helvetica", "", 10)
        for act_key, stats in skill_stats.items():
            prec = (
                stats["correct"] / stats["total"] * 100
                if stats["total"] > 0 else 0
            )
            nombre = nombres.get(act_key, act_key)
            clr = (
                (0, 120, 0) if prec >= 70
                else (180, 90, 0) if prec >= 50
                else (180, 0, 0)
            )
            pdf.set_text_color(*clr)
            pdf.cell(80, 7, nombre, border=1)
            pdf.set_text_color(0, 0, 0)
            pdf.cell(30, 7, "1", border=1, align="C")
            pdf.cell(
                35, 7,
                f"{stats['correct']}/{stats['total']}",
                border=1, align="C",
            )
            pdf.set_text_color(*clr)
            pdf.cell(35, 7, f"{prec:.1f}%", border=1, align="C")
            pdf.set_text_color(0, 0, 0)
            pdf.ln()

    # Recomendación
    seccion("RECOMENDACIÓN PEDAGÓGICA")
    pdf.set_font("Helvetica", "", 10)
    if not skill_stats:
        rec = (
            "El estudiante aún no ha completado actividades. "
            "Se recomienda comenzar con Conteo táctil."
        )
    else:
        min_key = min(
            skill_stats,
            key=lambda k: (
                skill_stats[k]["correct"] / skill_stats[k]["total"]
                if skill_stats[k]["total"] > 0 else 0
            ),
        )
        min_prec = (
            skill_stats[min_key]["correct"]
            / skill_stats[min_key]["total"] * 100
            if skill_stats[min_key]["total"] > 0 else 0
        )
        nombre_debil = nombres.get(min_key, min_key)
        if min_prec < 60:
            rec = (
                f"Se recomienda reforzar {nombre_debil} "
                f"(precisión: {min_prec:.0f}%). "
                "Usar objetos físicos como apoyo y practicar "
                "al menos 15 minutos diarios."
            )
        else:
            rec = (
                "Excelente desempeño. Se recomienda continuar "
                "practicando para consolidar las habilidades "
                "y avanzar al siguiente nivel."
            )
    pdf.multi_cell(0, 6, rec)


    pdf_bytes = pdf.output()
    nombre_archivo = (student.name or "reporte").replace(" ", "_")
    return StreamingResponse(
        io.BytesIO(bytes(pdf_bytes)),
        media_type="application/pdf",
        headers={
            "Content-Disposition": (
                f"attachment; filename=reporte_{nombre_archivo}.pdf"
            )
        },
    )