"""
Analizador de Progreso
======================
Genera reportes detallados del avance del niño,
detecta patrones de error específicos de la discalculia
y produce métricas para padres y educadores.
"""

from dataclasses import dataclass
from typing import List, Dict, Optional
from datetime import datetime, timedelta
from collections import Counter


@dataclass
class ProgressReport:
    """Reporte completo de progreso para padres/maestros."""
    user_id: str
    student_name: str
    report_date: str
    period_days: int

    # Métricas generales
    total_sessions: int
    total_questions: int
    overall_accuracy: float
    total_points: int
    weekly_streak: int

    # Por habilidad
    skill_summaries: Dict[str, dict]  # skill -> {accuracy, trend, sessions}

    # Patrones de error específicos
    error_patterns: List[str]

    # Recomendaciones pedagógicas
    pedagogical_recommendations: List[str]

    # Mensaje para el niño
    student_message: str

    # Mensaje para padres
    parent_message: str

    def to_dict(self) -> dict:
        return {
            "user_id": self.user_id,
            "student_name": self.student_name,
            "report_date": self.report_date,
            "period_days": self.period_days,
            "total_sessions": self.total_sessions,
            "total_questions": self.total_questions,
            "overall_accuracy": round(self.overall_accuracy * 100, 1),
            "total_points": self.total_points,
            "weekly_streak": self.weekly_streak,
            "skill_summaries": self.skill_summaries,
            "error_patterns": self.error_patterns,
            "pedagogical_recommendations": self.pedagogical_recommendations,
            "student_message": self.student_message,
            "parent_message": self.parent_message,
        }


class ProgressAnalyzer:
    """
    Analiza sesiones históricas y genera reportes pedagógicos
    basados en investigación sobre discalculia.
    """

    SKILL_NAMES_ES = {
        "suma_visual": "Suma con objetos",
        "resta_visual": "Resta con objetos",
        "conteo": "Conteo táctil",
        "comparar": "Comparar cantidades",
        "secuencias": "Ordenar números",
        "reconocer_numeros": "Reconocer números",
    }

    def generate_report(
        self,
        sessions: list,
        user_name: str,
        user_id: str,
        user_age: int,
        total_points: int,
        period_days: int = 7,
    ) -> ProgressReport:
        """Genera un reporte completo del período indicado."""

        # Filtrar sesiones del período
        cutoff = datetime.utcnow() - timedelta(days=period_days)
        period_sessions = [
            s for s in sessions
            if s.completed_at and s.completed_at >= cutoff
        ]

        if not period_sessions:
            return self._empty_report(user_id, user_name, period_days, total_points)

        # Métricas generales
        total_q = sum(s.total_questions for s in period_sessions)
        total_correct = sum(s.correct_answers for s in period_sessions)
        overall_acc = total_correct / total_q if total_q > 0 else 0.0

        # Resumen por habilidad
        skill_summaries = self._compute_skill_summaries(period_sessions, sessions)

        # Racha semanal
        streak = self._compute_streak(sessions)

        # Patrones de error
        error_patterns = self._detect_error_patterns(period_sessions)

        # Recomendaciones pedagógicas
        recommendations = self._generate_recommendations(skill_summaries, error_patterns, user_age)

        # Mensajes
        student_msg = self._student_message(user_name, overall_acc, streak)
        parent_msg = self._parent_message(user_name, overall_acc, skill_summaries, recommendations)

        return ProgressReport(
            user_id=user_id,
            student_name=user_name,
            report_date=datetime.utcnow().isoformat(),
            period_days=period_days,
            total_sessions=len(period_sessions),
            total_questions=total_q,
            overall_accuracy=overall_acc,
            total_points=total_points,
            weekly_streak=streak,
            skill_summaries=skill_summaries,
            error_patterns=error_patterns,
            pedagogical_recommendations=recommendations,
            student_message=student_msg,
            parent_message=parent_msg,
        )

    def _compute_skill_summaries(
        self, period_sessions: list, all_sessions: list
    ) -> Dict[str, dict]:
        summaries = {}
        skill_groups: Dict[str, list] = {}

        for s in period_sessions:
            key = s.activity_type
            if key not in skill_groups:
                skill_groups[key] = []
            skill_groups[key].append(s)

        for skill, sessions in skill_groups.items():
            accuracies = [s.accuracy for s in sessions]
            avg_acc = sum(accuracies) / len(accuracies)

            # Tendencia: comparar primera mitad vs segunda mitad
            if len(accuracies) >= 4:
                mid = len(accuracies) // 2
                first_half = sum(accuracies[:mid]) / mid
                second_half = sum(accuracies[mid:]) / (len(accuracies) - mid)
                if second_half > first_half + 0.1:
                    trend = "mejorando"
                elif second_half < first_half - 0.1:
                    trend = "bajando"
                else:
                    trend = "estable"
            else:
                trend = "inicio"

            summaries[skill] = {
                "name": self.SKILL_NAMES_ES.get(skill, skill),
                "accuracy": round(avg_acc * 100, 1),
                "sessions": len(sessions),
                "trend": trend,
                "total_questions": sum(s.total_questions for s in sessions),
                "correct_answers": sum(s.correct_answers for s in sessions),
            }

        return summaries

    def _detect_error_patterns(self, sessions: list) -> List[str]:
        """
        Detecta patrones de error específicos de discalculia.
        Basado en investigación de Butterworth (2005) y Desoete (2010).
        """
        patterns = []

        if not sessions:
            return patterns

        # Calcular métricas de error
        low_accuracy_activities = [
            s.activity_type for s in sessions if s.accuracy < 0.5
        ]
        activity_counts = Counter(low_accuracy_activities)

        # Patrón 1: Dificultad persistente en conteo
        if activity_counts.get("conteo", 0) >= 2:
            patterns.append(
                "Dificultad en conteo secuencial — puede saltar números o contar el mismo objeto dos veces"
            )

        # Patrón 2: Errores en reconocimiento visual de números
        if activity_counts.get("reconocer_numeros", 0) >= 2:
            patterns.append(
                "Dificultad en reconocimiento visual de símbolos numéricos — confunde números parecidos (6/9, 2/5)"
            )

        # Patrón 3: Dificultad en comparación
        if activity_counts.get("comparar", 0) >= 2:
            patterns.append(
                "Dificultad en el concepto de cantidad — no distingue intuitivamente mayor/menor"
            )

        # Patrón 4: Problemas en aritmética
        suma_err = activity_counts.get("suma_visual", 0)
        resta_err = activity_counts.get("resta_visual", 0)
        if suma_err + resta_err >= 3:
            patterns.append(
                "Dificultad en operaciones aritméticas — necesita apoyarse en objetos concretos más tiempo"
            )

        # Patrón 5: Sesiones muy rápidas con baja precisión (impulsividad)
        fast_inaccurate = [
            s for s in sessions
            if s.accuracy < 0.5 and s.time_taken_seconds < 60
        ]
        if len(fast_inaccurate) >= 2:
            patterns.append(
                "Respuestas impulsivas — selecciona opciones sin reflexionar; beneficia de instrucción para pausar y pensar"
            )

        # Patrón 6: Sesiones muy lentas (ansiedad matemática)
        slow_sessions = [
            s for s in sessions
            if s.time_taken_seconds > 300  # más de 5 minutos
        ]
        if len(slow_sessions) >= 2:
            patterns.append(
                "Ritmo muy lento — posible ansiedad matemática; reforzar ambiente positivo y sin presión de tiempo"
            )

        return patterns if patterns else ["No se detectaron patrones de error específicos en este período."]

    def _generate_recommendations(
        self,
        skill_summaries: dict,
        error_patterns: List[str],
        age: int,
    ) -> List[str]:
        """Genera recomendaciones pedagógicas concretas."""
        recommendations = []

        # Recomendación universal para discalculia
        recommendations.append(
            "Continuar con representación concreta (objetos físicos) antes de introducir símbolos abstractos."
        )

        # Según habilidades débiles
        for skill, summary in skill_summaries.items():
            if summary["accuracy"] < 50:
                if skill == "conteo":
                    recommendations.append(
                        "Practicar conteo táctil con objetos reales en casa: monedas, botones, frijoles."
                    )
                elif skill == "suma_visual":
                    recommendations.append(
                        "Practicar sumas con ábaco o bloques físicos antes de usar la app."
                    )
                elif skill == "comparar":
                    recommendations.append(
                        "Comparar grupos de objetos reales ('¿quién tiene más galletas?') en situaciones cotidianas."
                    )
                elif skill == "secuencias":
                    recommendations.append(
                        "Usar tarjetas numéricas físicas para ordenar en el piso o la mesa."
                    )

        # Recomendaciones de frecuencia
        if age == 6:
            recommendations.append(
                "Para niños de 6 años: sesiones de 10-15 minutos máximo, 4-5 veces por semana."
            )
        else:
            recommendations.append(
                f"Para {age} años: sesiones de 15-20 minutos, 5 veces por semana para mejores resultados."
            )

        # Recomendación basada en patrones
        if any("impulsiv" in p.lower() for p in error_patterns):
            recommendations.append(
                "Enseñar estrategia STOP-THINK: antes de responder, contar en voz alta y señalar cada objeto."
            )

        if any("ansiedad" in p.lower() for p in error_patterns):
            recommendations.append(
                "Reforzar que los errores son parte del aprendizaje. Celebrar el esfuerzo, no solo los aciertos."
            )

        return recommendations[:5]  # Máximo 5 recomendaciones

    def _compute_streak(self, sessions: list) -> int:
        if not sessions:
            return 0
        today = datetime.utcnow().date()
        dates = set()
        for s in sessions:
            if s.completed_at:
                dates.add(s.completed_at.date())
        streak = 0
        check = today
        while check in dates:
            streak += 1
            check -= timedelta(days=1)
        return min(streak, 7)

    def _student_message(self, name: str, accuracy: float, streak: int) -> str:
        if accuracy >= 0.85:
            return f"¡{name}, eres un supercampeón de las matemáticas! 🏆 ¡Sigue así!"
        elif accuracy >= 0.65:
            return f"¡{name}, lo estás haciendo muy bien! Cada día mejoras más. 💪🌟"
        elif accuracy >= 0.45:
            return f"¡{name}, vas aprendiendo paso a paso! Las matemáticas son como un músculo: ¡hay que practicar! 🦉"
        else:
            return f"¡{name}, cada vez que practicas tu cerebro crece! Estás en el camino correcto. ❤️"

    def _parent_message(
        self, name: str, accuracy: float, summaries: dict, recommendations: List[str]
    ) -> str:
        strong = [
            self.SKILL_NAMES_ES.get(k, k)
            for k, v in summaries.items()
            if v["accuracy"] >= 70
        ]
        weak = [
            self.SKILL_NAMES_ES.get(k, k)
            for k, v in summaries.items()
            if v["accuracy"] < 50
        ]

        msg = f"Estimado padre/madre de {name}:\n\n"
        msg += f"Precisión general este período: {accuracy * 100:.0f}%.\n\n"

        if strong:
            msg += f"✅ Fortalezas: {', '.join(strong)}.\n"
        if weak:
            msg += f"🎯 Áreas a reforzar: {', '.join(weak)}.\n"

        if recommendations:
            msg += f"\n📌 Recomendación principal: {recommendations[0]}"

        return msg

    def _empty_report(
        self, user_id: str, name: str, period_days: int, points: int
    ) -> ProgressReport:
        return ProgressReport(
            user_id=user_id,
            student_name=name,
            report_date=datetime.utcnow().isoformat(),
            period_days=period_days,
            total_sessions=0,
            total_questions=0,
            overall_accuracy=0.0,
            total_points=points,
            weekly_streak=0,
            skill_summaries={},
            error_patterns=[],
            pedagogical_recommendations=[
                "Comenzar con la actividad de conteo táctil para establecer una línea base.",
                "Practicar 10-15 minutos diarios para mejores resultados.",
            ],
            student_message=f"¡Hola {name}! ¡Empieza tu primera actividad hoy! 🦉",
            parent_message=f"Bienvenido/a. {name} aún no ha completado actividades. "
                           f"Se recomienda comenzar con 'Contar tocando'.",
        )


# Instancia global
progress_analyzer = ProgressAnalyzer()