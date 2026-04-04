import '../services/server_config.dart';

class AppConstants {
  // URL del backend — configurable desde la app sin recompilar
  static String get baseUrl => ServerConfig.baseUrl;

  // Duración de animaciones
  static const Duration shortAnimation = Duration(milliseconds: 300);
  static const Duration mediumAnimation = Duration(milliseconds: 600);
  static const Duration longAnimation = Duration(milliseconds: 1000);

  // Puntos por actividad
  static const int pointsPerCorrectAnswer = 10;
  static const int pointsPerActivity = 50;
  static const int bonusPoints = 20;

  // Límites del juego
  static const int maxQuestionsPerSession = 10;
  static const int maxHintsPerActivity = 3;
  static const int minAgeYears = 6;
  static const int maxAgeYears = 8;

  // Tipos de actividades
  static const String activitySuma = 'suma_visual';
  static const String activityResta = 'resta_visual';
  static const String activityConteo = 'conteo';
  static const String activityComparar = 'comparar';
  static const String activitySecuencias = 'secuencias';
  static const String activityReconocer = 'reconocer_numeros';

  // Dificultades
  static const String difficultyEasy = 'facil';
  static const String difficultyMedium = 'medio';
  static const String difficultyHard = 'dificil';

  // Emojis por categoría (apoyo visual para discalculia)
  static const Map<String, List<String>> activityEmojis = {
    activitySuma: ['🍎', '🍊', '🍋', '🍇', '🍓', '🌟', '🎈', '🐶', '🦋'],
    activityResta: ['🍕', '🍰', '🍩', '🧁', '🍬', '🎁'],
    activityConteo: ['🐱', '🐶', '🐭', '🐸', '🐻', '🦁', '🦊'],
    activityComparar: ['⭐', '🌙', '❤️', '💎', '🍀'],
    activitySecuencias: ['1️⃣', '2️⃣', '3️⃣', '4️⃣', '5️⃣', '6️⃣', '7️⃣', '8️⃣', '9️⃣'],
  };

  // Mensajes de la mascota (Lechuza)
  static const List<String> encouragementMessages = [
    '¡Muy bien! Eres increíble 🦉',
    '¡Sigue así! Puedes lograrlo 💪',
    '¡Excelente trabajo! 🌟',
    '¡Casi lo tienes! Inténtalo de nuevo 😊',
    '¡Eres un campeón de las matemáticas! 🏆',
    '¡Wow! ¡Qué listo/a eres! 🎉',
  ];

  static const List<String> hintMessages = [
    'Cuenta los objetos uno por uno con tu dedo 👆',
    'Puedes usar tus dedos para ayudarte 🤲',
    'Primero cuenta los de un lado, luego los del otro ✋',
    'Mira los dibujos, te darán una pista 👀',
  ];
}