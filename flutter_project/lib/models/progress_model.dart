import 'package:flutter/foundation.dart';
import 'package:equatable/equatable.dart';

class ProgressModel extends Equatable {
  final String userId;
  final Map<String, SkillProgress> skills;
  final List<SessionSummary> recentSessions;
  final String aiInsight; // Análisis generado por IA
  final List<String> recommendedActivities;
  final int weeklyStreak;
  final DateTime lastActivity;

  const ProgressModel({
    required this.userId,
    required this.skills,
    this.recentSessions = const [],
    this.aiInsight = '',
    this.recommendedActivities = const [],
    this.weeklyStreak = 0,
    required this.lastActivity,
  });

  factory ProgressModel.fromJson(Map<String, dynamic> json) => ProgressModel(
        userId: json['user_id'],
        skills: (json['skills'] as Map<String, dynamic>).map(
          (key, value) => MapEntry(key, SkillProgress.fromJson(value)),
        ),
        recentSessions: (json['recent_sessions'] as List? ?? [])
            .map((s) => SessionSummary.fromJson(s))
            .toList(),
        aiInsight: json['ai_insight'] ?? '',
        recommendedActivities:
            List<String>.from(json['recommended_activities'] ?? []),
        weeklyStreak: json['weekly_streak'] ?? 0,
        lastActivity: DateTime.parse(
            json['last_activity'] ?? DateTime.now().toIso8601String()),
      );

  // Habilidad más débil (prioridad para practicar)
  String? get weakestSkill {
    if (skills.isEmpty) return null;
    return skills.entries
        .reduce((a, b) => a.value.percentage < b.value.percentage ? a : b)
        .key;
  }

  // Promedio general
  double get overallProgress {
    if (skills.isEmpty) return 0;
    return skills.values.map((s) => s.percentage).reduce((a, b) => a + b) /
        skills.length;
  }

  @override
  List<Object?> get props => [userId, skills, weeklyStreak];
}

class SkillProgress extends Equatable {
  final String name;
  final double percentage; // 0.0 - 1.0
  final int totalAttempts;
  final int correctAttempts;
  final String trend; // 'up', 'down', 'stable'

  const SkillProgress({
    required this.name,
    required this.percentage,
    this.totalAttempts = 0,
    this.correctAttempts = 0,
    this.trend = 'stable',
  });

  factory SkillProgress.fromJson(Map<String, dynamic> json) => SkillProgress(
        name: json['name'],
        percentage: (json['percentage'] as num).toDouble(),
        totalAttempts: json['total_attempts'] ?? 0,
        correctAttempts: json['correct_attempts'] ?? 0,
        trend: json['trend'] ?? 'stable',
      );

  String get label {
    if (percentage >= 0.8) return 'Excelente';
    if (percentage >= 0.6) return 'Bien';
    if (percentage >= 0.4) return 'Practicando';
    return 'Necesita práctica';
  }

  @override
  List<Object?> get props => [name, percentage];
}

class SessionSummary extends Equatable {
  final String activityType;
  final double accuracy;
  final int points;
  final DateTime date;

  const SessionSummary({
    required this.activityType,
    required this.accuracy,
    required this.points,
    required this.date,
  });

  factory SessionSummary.fromJson(Map<String, dynamic> json) => SessionSummary(
        activityType: json['activity_type'],
        accuracy: (json['accuracy'] as num).toDouble(),
        points: json['points'],
        date: DateTime.parse(json['date']),
      );

  @override
  List<Object?> get props => [activityType, date];
}

// Provider de progreso
class ProgressProvider extends ChangeNotifier {
  ProgressModel? _progress;
  bool _isLoading = false;

  ProgressModel? get progress => _progress;
  bool get isLoading => _isLoading;

  void setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  void setProgress(ProgressModel progress) {
    _progress = progress;
    notifyListeners();
  }

  void updateSkill(String skill, double accuracy) {
    if (_progress == null) return;
    final updated = Map<String, SkillProgress>.from(_progress!.skills);
    final existing = updated[skill];
    if (existing != null) {
      final newPct =
          (existing.percentage * 0.7 + accuracy * 0.3).clamp(0.0, 1.0);
      updated[skill] = SkillProgress(
        name: existing.name,
        percentage: newPct,
        totalAttempts: existing.totalAttempts + 1,
        correctAttempts:
            existing.correctAttempts + (accuracy >= 0.5 ? 1 : 0),
        trend: newPct > existing.percentage
            ? 'up'
            : newPct < existing.percentage
                ? 'down'
                : 'stable',
      );
      _progress = ProgressModel(
        userId: _progress!.userId,
        skills: updated,
        recentSessions: _progress!.recentSessions,
        aiInsight: _progress!.aiInsight,
        recommendedActivities: _progress!.recommendedActivities,
        weeklyStreak: _progress!.weeklyStreak,
        lastActivity: DateTime.now(),
      );
      notifyListeners();
    }
  }
}