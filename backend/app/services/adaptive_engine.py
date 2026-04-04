"""
Motor de Adaptación Inteligente para Discalculia
=================================================
Ajusta dinámicamente la dificultad y el tipo de ejercicios
basándose en el perfil cognitivo del niño.

Tipos de discalculia considerados:
- Tipo 1: Dificultad en subitización (reconocer cantidades de un vistazo)
- Tipo 2: Dificultad en conteo (pierde la cuenta, cuenta doble)
- Tipo 3: Dificultad en relaciones numéricas (mayor/menor)
- Tipo 4: Dificultad en aritmética básica (suma/resta)
"""

from dataclasses import dataclass, field
from typing import List, Dict, Optional
from enum import Enum
import math


class DyscalculiaProfile(Enum):
    SUBITIZING = "subitizing"      # Reconocimiento visual de cantidades
    COUNTING = "counting"           # Conteo secuencial
    NUMBER_SENSE = "number_sense"   # Sentido numérico (mayor/menor)
    ARITHMETIC = "arithmetic"       # Operaciones aritméticas
    MIXED = "mixed"                 # Combinación de dificultades


@dataclass
class StudentProfile:
    user_id: str
    age: int
    skill_accuracies: Dict[str, float]   # habilidad -> precisión 0.0-1.0
    session_count: Dict[str, int]        # habilidad -> número de sesiones
    response_times: Dict[str, float]     # habilidad -> tiempo promedio en segundos
    hints_usage: Dict[str, float]        # habilidad -> tasa de uso de pistas
    error_patterns: Dict[str, List[int]] = field(default_factory=dict)

    @property
    def total_sessions(self) -> int:
        return sum(self.session_count.values())

    @property
    def overall_accuracy(self) -> float:
        if not self.skill_accuracies:
            return 0.0
        return sum(self.skill_accuracies.values()) / len(self.skill_accuracies)


@dataclass
class AdaptationRecommendation:
    difficulty: str                     # facil, medio, dificil
    scaffolding_level: int             # 1-5 (cantidad de apoyo visual)
    recommended_activity: str
    session_length: int                # número de preguntas recomendadas
    use_physical_objects: bool         # usar representación con objetos
    use_number_line: bool              # usar línea numérica
    slow_pace: bool                    # ritmo lento con más tiempo
    dyscalculia_profile: str
    explanation: str                   # por qué se recomienda esto


class AdaptiveEngine:
    """
    Motor que analiza el rendimiento del niño y genera
    recomendaciones pedagógicas adaptadas a su perfil.
    """

    # Umbrales de rendimiento
    MASTERY_THRESHOLD = 0.85       # Por encima: subir dificultad
    FRUSTRATION_THRESHOLD = 0.40   # Por debajo: bajar dificultad
    HINT_HIGH_USAGE = 0.60         # Tasa de pistas alta (necesita más apoyo)

    # Rangos numéricos por dificultad y edad
    NUMBER_RANGES = {
        6: {"facil": (1, 5),  "medio": (1, 8),  "dificil": (1, 10)},
        7: {"facil": (1, 7),  "medio": (1, 10), "dificil": (1, 15)},
        8: {"facil": (1, 9),  "medio": (1, 12), "dificil": (1, 20)},
    }

    def analyze_profile(self, profile: StudentProfile) -> DyscalculiaProfile:
        """
        Identifica el perfil de discalculia predominante del niño
        basándose en sus patrones de error y rendimiento.
        """
        accs = profile.skill_accuracies

        # Sin datos suficientes
        if profile.total_sessions < 3:
            return DyscalculiaProfile.MIXED

        low_skills = [k for k, v in accs.items() if v < 0.5]

        # Dificultad principal en reconocimiento visual
        if accs.get("reconocer", 1.0) < 0.5 and accs.get("conteo", 1.0) < 0.5:
            return DyscalculiaProfile.SUBITIZING

        # Dificultad principal en conteo
        if accs.get("conteo", 1.0) < 0.5:
            return DyscalculiaProfile.COUNTING

        # Dificultad en relaciones (mayor/menor, secuencias)
        if accs.get("comparar", 1.0) < 0.5 and accs.get("secuencias", 1.0) < 0.5:
            return DyscalculiaProfile.NUMBER_SENSE

        # Dificultad en operaciones
        if accs.get("suma", 1.0) < 0.5 or accs.get("resta", 1.0) < 0.5:
            return DyscalculiaProfile.ARITHMETIC

        # Múltiples dificultades
        if len(low_skills) >= 3:
            return DyscalculiaProfile.MIXED

        return DyscalculiaProfile.MIXED

    def recommend(
        self,
        profile: StudentProfile,
        requested_activity: Optional[str] = None,
    ) -> AdaptationRecommendation:
        """
        Genera una recomendación de adaptación completa para el niño.
        """
        dyscalculia_type = self.analyze_profile(profile)
        age = min(max(profile.age, 6), 8)

        # Determinar actividad si no se especificó
        activity = requested_activity or self._select_best_activity(profile, dyscalculia_type)

        # Determinar dificultad adaptativa
        activity_accuracy = profile.skill_accuracies.get(
            self._skill_from_activity(activity), 0.0
        )
        difficulty = self._compute_difficulty(activity_accuracy, profile)

        # Nivel de andamiaje (scaffolding)
        scaffolding = self._compute_scaffolding(profile, dyscalculia_type)

        # Longitud de sesión adaptativa
        session_length = self._compute_session_length(profile, dyscalculia_type)

        # Estrategias específicas por perfil
        use_physical = dyscalculia_type in [
            DyscalculiaProfile.COUNTING,
            DyscalculiaProfile.SUBITIZING,
            DyscalculiaProfile.MIXED,
        ]
        use_number_line = dyscalculia_type in [
            DyscalculiaProfile.NUMBER_SENSE,
            DyscalculiaProfile.ARITHMETIC,
        ]
        slow_pace = (
            profile.hints_usage.get(self._skill_from_activity(activity), 0) > self.HINT_HIGH_USAGE
            or activity_accuracy < 0.45
        )

        explanation = self._build_explanation(dyscalculia_type, activity_accuracy, age)

        return AdaptationRecommendation(
            difficulty=difficulty,
            scaffolding_level=scaffolding,
            recommended_activity=activity,
            session_length=session_length,
            use_physical_objects=use_physical,
            use_number_line=use_number_line,
            slow_pace=slow_pace,
            dyscalculia_profile=dyscalculia_type.value,
            explanation=explanation,
        )

    def get_number_range(self, age: int, difficulty: str) -> tuple:
        """Rango numérico apropiado según edad y dificultad."""
        age = min(max(age, 6), 8)
        return self.NUMBER_RANGES[age].get(difficulty, (1, 10))

    def compute_next_difficulty(
        self,
        current_difficulty: str,
        recent_accuracies: List[float],
    ) -> str:
        """
        Algoritmo de zona de desarrollo próximo (ZDP):
        Sube si domina, baja si se frustra, mantiene si está aprendiendo.
        """
        if not recent_accuracies:
            return current_difficulty

        # Promedio ponderado: sesiones recientes pesan más
        weights = [math.exp(0.3 * i) for i in range(len(recent_accuracies))]
        weights.reverse()
        total_weight = sum(weights)
        weighted_avg = sum(a * w for a, w in zip(recent_accuracies, weights)) / total_weight

        if weighted_avg >= self.MASTERY_THRESHOLD:
            return self._next_difficulty(current_difficulty, up=True)
        elif weighted_avg <= self.FRUSTRATION_THRESHOLD:
            return self._next_difficulty(current_difficulty, up=False)
        else:
            return current_difficulty

    def _next_difficulty(self, current: str, up: bool) -> str:
        order = ["facil", "medio", "dificil"]
        idx = order.index(current) if current in order else 0
        if up:
            return order[min(idx + 1, 2)]
        else:
            return order[max(idx - 1, 0)]

    def _select_best_activity(
        self, profile: StudentProfile, dyscalculia_type: DyscalculiaProfile
    ) -> str:
        """Selecciona la actividad más beneficiosa para el perfil."""
        profile_to_activity = {
            DyscalculiaProfile.SUBITIZING: "reconocer_numeros",
            DyscalculiaProfile.COUNTING: "conteo",
            DyscalculiaProfile.NUMBER_SENSE: "comparar",
            DyscalculiaProfile.ARITHMETIC: "suma_visual",
            DyscalculiaProfile.MIXED: "conteo",
        }
        # Si hay una habilidad muy débil, priorizar esa
        if profile.skill_accuracies:
            weakest = min(profile.skill_accuracies, key=profile.skill_accuracies.get)
            activity_map = {
                "conteo": "conteo",
                "suma": "suma_visual",
                "resta": "resta_visual",
                "comparar": "comparar",
                "secuencias": "secuencias",
                "reconocer": "reconocer_numeros",
            }
            if profile.skill_accuracies[weakest] < 0.5:
                return activity_map.get(weakest, "conteo")

        return profile_to_activity.get(dyscalculia_type, "conteo")

    def _skill_from_activity(self, activity: str) -> str:
        mapping = {
            "suma_visual": "suma",
            "resta_visual": "resta",
            "conteo": "conteo",
            "comparar": "comparar",
            "secuencias": "secuencias",
            "reconocer_numeros": "reconocer",
        }
        return mapping.get(activity, activity)

    def _compute_difficulty(self, accuracy: float, profile: StudentProfile) -> str:
        if accuracy >= self.MASTERY_THRESHOLD:
            return "medio" if profile.total_sessions < 10 else "dificil"
        elif accuracy <= self.FRUSTRATION_THRESHOLD:
            return "facil"
        elif accuracy < 0.65:
            return "facil"
        else:
            return "medio"

    def _compute_scaffolding(
        self, profile: StudentProfile, dyscalculia_type: DyscalculiaProfile
    ) -> int:
        """
        Nivel de andamiaje 1-5:
        5 = máximo apoyo (objetos físicos, pistas automáticas, ritmo lento)
        1 = mínimo apoyo (solo número, sin apoyo visual extra)
        """
        base = 3
        if profile.overall_accuracy < 0.4:
            base = 5
        elif profile.overall_accuracy < 0.6:
            base = 4
        elif profile.overall_accuracy > 0.85:
            base = 2

        if dyscalculia_type == DyscalculiaProfile.MIXED:
            base = min(5, base + 1)
        if profile.total_sessions < 5:
            base = min(5, base + 1)

        avg_hints = (
            sum(profile.hints_usage.values()) / len(profile.hints_usage)
            if profile.hints_usage else 0.0
        )
        if avg_hints > 0.5:
            base = min(5, base + 1)

        return base

    def _compute_session_length(
        self, profile: StudentProfile, dyscalculia_type: DyscalculiaProfile
    ) -> int:
        """
        Sesiones más cortas al principio o cuando hay frustración.
        Rango: 3-8 preguntas por sesión.
        """
        if profile.overall_accuracy < 0.45:
            return 3  # Sesión muy corta para no frustrar
        elif profile.overall_accuracy < 0.65:
            return 5
        elif profile.overall_accuracy > 0.85:
            return 8  # Domina bien, puede hacer más
        return 5  # Default recomendado para discalculia

    def _build_explanation(
        self, profile: DyscalculiaProfile, accuracy: float, age: int
    ) -> str:
        base_messages = {
            DyscalculiaProfile.SUBITIZING: (
                "El niño tiene dificultad para reconocer cantidades visualmente. "
                "Se recomienda trabajar con grupos de puntos (dados) y objetos físicos."
            ),
            DyscalculiaProfile.COUNTING: (
                "El niño necesita apoyo en el conteo secuencial. "
                "Usar conteo táctil (tocar cada objeto) y conteo en voz alta."
            ),
            DyscalculiaProfile.NUMBER_SENSE: (
                "Dificultad en relaciones numéricas. "
                "Usar línea numérica visual y comparación con objetos concretos."
            ),
            DyscalculiaProfile.ARITHMETIC: (
                "Dificultad en operaciones aritméticas. "
                "Empezar con representación concreta antes de símbolos abstractos."
            ),
            DyscalculiaProfile.MIXED: (
                "Dificultades en múltiples áreas. "
                "Se recomienda máximo apoyo visual y sesiones cortas y frecuentes."
            ),
        }
        msg = base_messages.get(profile, "Continuar con práctica estructurada.")
        if accuracy < 0.4:
            msg += f" Precisión actual muy baja ({accuracy*100:.0f}%), reducir dificultad."
        return msg


# Instancia global
adaptive_engine = AdaptiveEngine()