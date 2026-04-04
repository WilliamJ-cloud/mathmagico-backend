"""
Servicio Text-to-Speech (TTS) para el backend
==============================================
Genera instrucciones de audio en español para niños con discalculia.
Soporta generación de frases motivadoras, instrucciones de actividad
y pistas pedagógicas en formato de texto optimizado para síntesis de voz.
"""

from typing import List, Optional
import random


class TtsScriptService:
    """
    Genera scripts de texto optimizados para TTS (text-to-speech).
    Frases cortas, simples y positivas — diseñadas para niños de 6-8 años.
    """

    # Instrucciones por tipo de actividad
    ACTIVITY_INSTRUCTIONS = {
        "suma_visual": [
            "Vamos a sumar. Mira los objetos de cada grupo y cuéntalos todos juntos.",
            "¡Hora de sumar! Cuenta los objetos del lado izquierdo, luego los del derecho.",
            "Para sumar, junta todos los objetos y cuéntalos uno por uno.",
        ],
        "resta_visual": [
            "Vamos a restar. Empieza con todos los objetos y quita los que te digo.",
            "Para restar, cuenta cuántos objetos se van y cuántos quedan.",
            "¡Hora de restar! Quita los objetos uno por uno y cuenta los que quedan.",
        ],
        "conteo": [
            "Toca cada objeto una sola vez para contarlo. Di el número en voz alta.",
            "¡Vamos a contar! Pon tu dedo en cada objeto y di: uno, dos, tres...",
            "Para contar, toca cada objeto sin saltarte ninguno. ¡Despacio!",
        ],
        "comparar": [
            "Mira los dos grupos. ¿Cuál tiene más? ¿Cuál tiene menos?",
            "Compara los dos lados. El que tiene más objetos es el mayor.",
            "¡Vamos a comparar! Cuenta cada grupo y decide cuál es más grande.",
        ],
        "secuencias": [
            "Ordena los números del más pequeño al más grande, como una escalera.",
            "Busca el número más pequeño primero. Luego el siguiente, y así...",
            "¡Orden perfecto! Pon los números en fila de menor a mayor.",
        ],
        "reconocer_numeros": [
            "Mira el número grande. ¿Cómo se llama? Elige la respuesta correcta.",
            "¿Qué número ves? Toma tu tiempo para reconocerlo.",
            "Observa bien el número y elige su nombre correcto.",
        ],
    }

    # Mensajes de éxito
    SUCCESS_MESSAGES = [
        "¡Muy bien! ¡Lo lograste! Eres increíble.",
        "¡Excelente trabajo! Eso estuvo perfecto.",
        "¡Fantástico! Cada vez eres más listo.",
        "¡Correcto! ¡Eres un campeón de las matemáticas!",
        "¡Perfecto! ¡Sigue así, eres genial!",
        "¡Lo hiciste! ¡Qué orgulloso me siento de ti!",
    ]

    # Mensajes de aliento (respuesta incorrecta)
    ENCOURAGEMENT_MESSAGES = [
        "Casi, inténtalo de nuevo. Tú puedes.",
        "No te rindas. Cuenta otra vez, despacio.",
        "Estás aprendiendo. Vuelve a intentarlo.",
        "Cada intento te hace más inteligente. ¡Inténtalo de nuevo!",
        "Está bien equivocarse. Eso es aprender. Vuelve a intentarlo.",
    ]

    # Mensajes de pista
    HINT_TEMPLATES = {
        "suma_visual": [
            "Cuenta los {emoji1} uno por uno, luego sigue contando los {emoji2}.",
            "Usa tus dedos: {num1} en una mano y {num2} en la otra. ¿Cuántos son?",
            "Junta todos los objetos y cuenta desde el principio.",
        ],
        "resta_visual": [
            "Empieza con {num1} objetos. Quita {num2} uno por uno. Cuenta los que quedan.",
            "Tacha {num2} objetos con tu dedo. ¿Cuántos quedan sin tachar?",
        ],
        "conteo": [
            "Toca cada {emoji} con el dedo y di su número en voz alta.",
            "Marca cada objeto que ya contaste para no contarlo dos veces.",
        ],
        "comparar": [
            "Cuenta los objetos del lado izquierdo. Luego los del derecho. ¿Cuál tiene más?",
            "La línea de números te ayuda: el número más grande a la derecha es el mayor.",
        ],
        "secuencias": [
            "Busca el número 1 primero si está ahí. Luego el 2, luego el 3...",
            "¿Cuál es el más pequeño de todos? Ese va primero.",
        ],
        "reconocer_numeros": [
            "Cuenta los puntos debajo del número. Te dicen cuánto vale.",
            "Mira la forma. Este número tiene {num_word} puntos. Búscalo.",
        ],
    }

    # Felicitaciones al completar actividad
    COMPLETION_MESSAGES = [
        "¡Actividad completada! ¡Eres increíble, {name}!",
        "¡Lo lograste {name}! ¡Eres un matemático de primera!",
        "¡Fantástico {name}! Cada día mejoras más. ¡Sigue así!",
        "¡Bien hecho {name}! Tu cerebro está creciendo con cada ejercicio.",
    ]

    def get_instruction(self, activity_type: str) -> str:
        msgs = self.ACTIVITY_INSTRUCTIONS.get(activity_type, [
            "¡Empecemos! Lee la pregunta y elige la respuesta correcta."
        ])
        return random.choice(msgs)

    def get_success_message(self) -> str:
        return random.choice(self.SUCCESS_MESSAGES)

    def get_encouragement(self) -> str:
        return random.choice(self.ENCOURAGEMENT_MESSAGES)

    def get_hint(
        self,
        activity_type: str,
        num1: Optional[int] = None,
        num2: Optional[int] = None,
        emoji1: Optional[str] = None,
        emoji2: Optional[str] = None,
    ) -> str:
        templates = self.HINT_TEMPLATES.get(activity_type, [
            "Mira con cuidado y cuenta despacio. ¡Tú puedes!"
        ])
        template = random.choice(templates)

        # Reemplazar variables en la plantilla
        try:
            hint = template.format(
                num1=num1 or "varios",
                num2=num2 or "algunos",
                emoji1=emoji1 or "objetos",
                emoji2=emoji2 or "objetos",
                num_word=self._number_to_word(num1) if num1 else "varios",
            )
        except (KeyError, TypeError):
            hint = template

        return hint

    def get_completion_message(self, name: str) -> str:
        template = random.choice(self.COMPLETION_MESSAGES)
        return template.format(name=name)

    def get_number_name(self, n: int) -> str:
        return self._number_to_word(n)

    def get_motivational_greeting(self, name: str, session_number: int) -> str:
        if session_number == 1:
            return f"¡Hola {name}! Bienvenido a tu primera actividad. ¡Vamos a aprender juntos!"
        elif session_number <= 5:
            return f"¡Hola {name}! Me alegra verte de nuevo. ¡Sigamos aprendiendo!"
        else:
            return f"¡{name}, ya eres todo un matemático! Practiquemos un poco más."

    def _number_to_word(self, n: Optional[int]) -> str:
        if n is None:
            return "varios"
        words = [
            "cero", "uno", "dos", "tres", "cuatro", "cinco",
            "seis", "siete", "ocho", "nueve", "diez",
            "once", "doce", "trece", "catorce", "quince",
            "dieciséis", "diecisiete", "dieciocho", "diecinueve", "veinte",
        ]
        if 0 <= n < len(words):
            return words[n]
        return str(n)


# Instancia global
tts_service = TtsScriptService()