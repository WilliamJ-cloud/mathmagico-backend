import random
import uuid
from typing import List, Dict, Any


class QuestionGenerator:
    EMOJI_SETS = {
        "frutas": ["🍎", "🍊", "🍋", "🍇", "🍓", "🍑", "🍒"],
        "animales": ["🐶", "🐱", "🐭", "🐸", "🐻", "🦁", "🦊", "🐰"],
        "objetos": ["⭐", "🌙", "❤️", "🎈", "🌟", "💎", "🎁"],
        "comida": ["🍕", "🍰", "🍩", "🧁", "🍬", "🍭", "🍦"],
    }

    DIFFICULTY_RANGES = {
        "facil": (1, 5),
        "medio": (1, 9),
        "dificil": (1, 15),
    }

    def generate(self, activity_type: str, difficulty: str, count: int) -> List[Dict[str, Any]]:
        generators = {
            "suma_visual": self._generate_suma,
            "resta_visual": self._generate_resta,
            "conteo": self._generate_conteo,
            "comparar": self._generate_comparar,
            "secuencias": self._generate_secuencias,
            "reconocer_numeros": self._generate_reconocer,
        }
        gen_func = generators.get(activity_type, self._generate_suma)
        questions = []
        for _ in range(count):
            q = gen_func(difficulty)
            questions.append(q)
        return questions

    def _generate_suma(self, difficulty: str) -> Dict[str, Any]:
        min_n, max_n = self.DIFFICULTY_RANGES[difficulty]
        if difficulty == "facil":
            num1 = random.randint(1, 5)
            num2 = random.randint(1, 5)
        else:
            num1 = random.randint(min_n, max_n)
            num2 = random.randint(min_n, max_n)
        correct = num1 + num2
        choices = self._generate_choices(correct, min_val=2, max_val=correct + 5)
        emoji_set = random.choice(list(self.EMOJI_SETS.values()))
        emoji1 = random.choice(emoji_set)
        emoji2 = random.choice([e for e in emoji_set if e != emoji1] or emoji_set)
        return {
            "id": str(uuid.uuid4()),
            "activity_type": "suma_visual",
            "difficulty": difficulty,
            "question_text": f"¿Cuánto es {num1} + {num2}?",
            "operands": [num1, num2],
            "correct_answer": correct,
            "choices": choices,
            "hint": f"Cuenta {num1} {emoji1} y luego {num2} {emoji2} más.",
            "emoji1": emoji1,
            "emoji2": emoji2,
        }

    def _generate_resta(self, difficulty: str) -> Dict[str, Any]:
        min_n, max_n = self.DIFFICULTY_RANGES[difficulty]
        num1 = random.randint(2, max_n)
        num2 = random.randint(1, num1)
        correct = num1 - num2
        choices = self._generate_choices(correct, min_val=0, max_val=num1)
        emoji_set = random.choice(list(self.EMOJI_SETS.values()))
        emoji = random.choice(emoji_set)
        return {
            "id": str(uuid.uuid4()),
            "activity_type": "resta_visual",
            "difficulty": difficulty,
            "question_text": f"Tienes {num1} {emoji} y quitas {num2}. ¿Cuántos quedan?",
            "operands": [num1, num2],
            "correct_answer": correct,
            "choices": choices,
            "hint": f"Empieza con {num1} y quita {num2} uno por uno.",
            "emoji1": emoji,
            "emoji2": emoji,
        }

    def _generate_conteo(self, difficulty: str) -> Dict[str, Any]:
        min_n, max_n = self.DIFFICULTY_RANGES[difficulty]
        count = random.randint(min_n, min(max_n, 10))
        choices = self._generate_choices(count, min_val=max(1, count - 3), max_val=count + 3)
        emoji_set = random.choice(list(self.EMOJI_SETS.values()))
        emoji = random.choice(emoji_set)
        return {
            "id": str(uuid.uuid4()),
            "activity_type": "conteo",
            "difficulty": difficulty,
            "question_text": f"Toca cada {emoji} para contarlo. ¿Cuántos hay?",
            "operands": [count],
            "correct_answer": count,
            "choices": choices,
            "hint": "Toca cada objeto una sola vez y cuenta en voz alta.",
            "emoji1": emoji,
            "emoji2": None,
        }

    def _generate_comparar(self, difficulty: str) -> Dict[str, Any]:
        min_n, max_n = self.DIFFICULTY_RANGES[difficulty]
        num1 = random.randint(min_n, max_n)
        num2 = random.randint(min_n, max_n)
        while num1 == num2 and difficulty == "facil":
            num2 = random.randint(min_n, max_n)
        if num1 < num2:
            correct = 1
        elif num1 == num2:
            correct = 2
        else:
            correct = 3
        emoji_set = random.choice(list(self.EMOJI_SETS.values()))
        emoji = random.choice(emoji_set)
        return {
            "id": str(uuid.uuid4()),
            "activity_type": "comparar",
            "difficulty": difficulty,
            "question_text": f"¿Cómo se comparan {num1} y {num2}?",
            "operands": [num1, num2],
            "correct_answer": correct,
            "choices": [1, 2, 3],
            "hint": f"Cuenta los {emoji} de cada lado. ¿Cuál lado tiene más?",
            "emoji1": emoji,
            "emoji2": emoji,
        }

    def _generate_secuencias(self, difficulty: str) -> Dict[str, Any]:
        min_n, max_n = self.DIFFICULTY_RANGES[difficulty]
        if difficulty == "facil":
            length = 3
        elif difficulty == "medio":
            length = 4
        else:
            length = 5
        start = random.randint(min_n, max(min_n, max_n - length))
        sequence = list(range(start, start + length))
        shuffled = sequence.copy()
        random.shuffle(shuffled)
        while shuffled == sequence:
            random.shuffle(shuffled)
        return {
            "id": str(uuid.uuid4()),
            "activity_type": "secuencias",
            "difficulty": difficulty,
            "question_text": "Ordena estos números de menor a mayor:",
            "operands": shuffled,
            "correct_answer": sequence[-1],
            "choices": sequence,
            "hint": "Busca el número más pequeño primero.",
            "emoji1": None,
            "emoji2": None,
        }

    def _generate_reconocer(self, difficulty: str) -> Dict[str, Any]:
        min_n, max_n = self.DIFFICULTY_RANGES[difficulty]
        target = random.randint(min_n, max_n)
        choices = self._generate_choices(target, min_val=min_n, max_val=max_n)
        return {
            "id": str(uuid.uuid4()),
            "activity_type": "reconocer_numeros",
            "difficulty": difficulty,
            "question_text": "¿Qué número es este?",
            "operands": [target],
            "correct_answer": target,
            "choices": choices,
            "hint": f"Este número se llama '{self._number_to_word(target)}'.",
            "emoji1": None,
            "emoji2": None,
        }

    def _generate_choices(self, correct: int, min_val: int = 0, max_val: int = 20) -> List[int]:
        choices = {correct}
        attempts = 0
        while len(choices) < 4 and attempts < 50:
            delta = random.choice([-2, -1, 1, 2, 3])
            distractor = correct + delta
            if min_val <= distractor <= max_val and distractor != correct:
                choices.add(distractor)
            attempts += 1
        n = min_val
        while len(choices) < 4:
            if n != correct and n >= min_val:
                choices.add(n)
            n += 1
        result = list(choices)
        random.shuffle(result)
        return result[:4]

    def _number_to_word(self, n: int) -> str:
        words = [
            "cero", "uno", "dos", "tres", "cuatro", "cinco",
            "seis", "siete", "ocho", "nueve", "diez",
            "once", "doce", "trece", "catorce", "quince",
        ]
        if 0 <= n < len(words):
            return words[n]
        return str(n)