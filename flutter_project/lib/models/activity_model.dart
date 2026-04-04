import 'dart:ui' show Color;
import 'package:equatable/equatable.dart';

enum ActivityType {
  sumaVisual,
  restaVisual,
  conteo,
  comparar,
  secuencias,
  reconocerNumeros,
  subitizacion,
  lineaNumerica,
  descomposicion,
  trazarNumeros,
}

enum Difficulty { easy, medium, hard }

class ActivityModel extends Equatable {
  final String id;
  final String title;
  final String description;
  final ActivityType type;
  final Difficulty difficulty;
  final String emoji;
  final Color color;
  final int pointsReward;
  final bool isUnlocked;
  final int completedCount;

  const ActivityModel({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.difficulty,
    required this.emoji,
    required this.color,
    this.pointsReward = 50,
    this.isUnlocked = true,
    this.completedCount = 0,
  });

  String get difficultyLabel {
    switch (difficulty) {
      case Difficulty.easy:
        return '⭐ Fácil';
      case Difficulty.medium:
        return '⭐⭐ Medio';
      case Difficulty.hard:
        return '⭐⭐⭐ Difícil';
    }
  }

  @override
  List<Object?> get props => [id, type, difficulty];
}

class QuestionModel extends Equatable {
  final String id;
  final String questionText;
  final String activityType;
  final List<dynamic> operands;
  final int correctAnswer;
  final List<int> choices;
  final String? hint;
  final String? emoji1;
  final String? emoji2;
  final String difficulty;

  const QuestionModel({
    required this.id,
    required this.questionText,
    required this.activityType,
    required this.operands,
    required this.correctAnswer,
    required this.choices,
    this.hint,
    this.emoji1,
    this.emoji2,
    this.difficulty = 'facil',
  });

  factory QuestionModel.fromJson(Map<String, dynamic> json) => QuestionModel(
        id: json['id'],
        questionText: json['question_text'],
        activityType: json['activity_type'],
        operands: List<dynamic>.from(json['operands']),
        correctAnswer: json['correct_answer'],
        choices: List<int>.from(json['choices']),
        hint: json['hint'],
        emoji1: json['emoji1'],
        emoji2: json['emoji2'],
        difficulty: json['difficulty'] ?? 'facil',
      );

  @override
  List<Object?> get props => [id, correctAnswer];
}

class ActivityResult extends Equatable {
  final String activityId;
  final String userId;
  final int totalQuestions;
  final int correctAnswers;
  final int pointsEarned;
  final Duration timeTaken;
  final List<QuestionResult> questionResults;
  final DateTime completedAt;

  const ActivityResult({
    required this.activityId,
    required this.userId,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.pointsEarned,
    required this.timeTaken,
    required this.questionResults,
    required this.completedAt,
  });

  double get accuracy => correctAnswers / totalQuestions;
  bool get isPerfect => correctAnswers == totalQuestions;

  Map<String, dynamic> toJson() => {
        'activity_id': activityId,
        'user_id': userId,
        'total_questions': totalQuestions,
        'correct_answers': correctAnswers,
        'points_earned': pointsEarned,
        'time_taken_seconds': timeTaken.inSeconds,
        'accuracy': accuracy,
        'completed_at': completedAt.toIso8601String(),
        'question_results': questionResults.map((r) => r.toJson()).toList(),
      };

  @override
  List<Object?> get props => [activityId, userId, completedAt];
}

class QuestionResult extends Equatable {
  final String questionId;
  final int userAnswer;
  final int correctAnswer;
  final bool isCorrect;
  final int hintsUsed;

  const QuestionResult({
    required this.questionId,
    required this.userAnswer,
    required this.correctAnswer,
    required this.isCorrect,
    required this.hintsUsed,
  });

  Map<String, dynamic> toJson() => {
        'question_id': questionId,
        'user_answer': userAnswer,
        'correct_answer': correctAnswer,
        'is_correct': isCorrect,
        'hints_used': hintsUsed,
      };

  @override
  List<Object?> get props => [questionId, isCorrect];
}