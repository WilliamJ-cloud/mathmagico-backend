import 'package:flutter/foundation.dart';
import 'package:equatable/equatable.dart';
import '../services/storage_service.dart';

class UserModel extends Equatable {
  final String id;
  final String name;
  final int age;
  final String avatarEmoji;
  final int totalPoints;
  final int level;
  final List<String> achievements;
  final DateTime createdAt;
  final Map<String, int> skillLevels;
  /// ISO dates "2026-04-04" — one entry per day practiced (no duplicates)
  final List<String> activityDates;

  const UserModel({
    required this.id,
    required this.name,
    required this.age,
    this.avatarEmoji = '🦁',
    this.totalPoints = 0,
    this.level = 1,
    this.achievements = const [],
    required this.createdAt,
    this.skillLevels = const {
      'conteo': 0,
      'suma': 0,
      'resta': 0,
      'comparar': 0,
      'secuencias': 0,
      'reconocer': 0,
    },
    this.activityDates = const [],
  });

  UserModel copyWith({
    String? name,
    int? age,
    String? avatarEmoji,
    int? totalPoints,
    int? level,
    List<String>? achievements,
    Map<String, int>? skillLevels,
    List<String>? activityDates,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      age: age ?? this.age,
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
      totalPoints: totalPoints ?? this.totalPoints,
      level: level ?? this.level,
      achievements: achievements ?? this.achievements,
      createdAt: createdAt,
      skillLevels: skillLevels ?? this.skillLevels,
      activityDates: activityDates ?? this.activityDates,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'age': age,
        'avatarEmoji': avatarEmoji,
        'totalPoints': totalPoints,
        'level': level,
        'achievements': achievements,
        'createdAt': createdAt.toIso8601String(),
        'skillLevels': skillLevels,
        'activityDates': activityDates,
      };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'],
        name: json['name'],
        age: json['age'],
        // Accept both camelCase (local) and snake_case (API)
        avatarEmoji: json['avatarEmoji'] ?? json['avatar_emoji'] ?? '🦁',
        totalPoints: json['totalPoints'] ?? json['total_points'] ?? 0,
        level: json['level'] ?? 1,
        achievements: List<String>.from(json['achievements'] ?? []),
        createdAt: DateTime.parse(
            json['createdAt'] ?? json['created_at'] ?? DateTime.now().toIso8601String()),
        skillLevels: Map<String, int>.from(
            (json['skillLevels'] ?? json['skill_levels'] ?? {})
                .map((k, v) => MapEntry(k as String, (v as num).toInt()))),
        activityDates: List<String>.from(json['activityDates'] ?? []),
      );

  // ── Computed helpers ───────────────────────────────────

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool practicedOn(DateTime date) => activityDates.contains(_fmt(date));

  /// Consecutive days streak ending today (or yesterday)
  int get currentStreak {
    if (activityDates.isEmpty) return 0;

    final dates = activityDates
        .map((s) => DateTime.parse(s))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a)); // newest first

    final today = DateTime.now();
    final todayStr = _fmt(today);
    final yestStr = _fmt(today.subtract(const Duration(days: 1)));

    // Streak must touch today or yesterday
    final latestStr = _fmt(dates.first);
    if (latestStr != todayStr && latestStr != yestStr) return 0;

    int streak = 1;
    for (int i = 1; i < dates.length; i++) {
      final expected = _fmt(dates[i - 1].subtract(const Duration(days: 1)));
      if (_fmt(dates[i]) == expected) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  /// Number of unique days practiced in the last 30 days
  int get daysThisMonth {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    return activityDates
        .where((s) => DateTime.parse(s).isAfter(cutoff))
        .toSet()
        .length;
  }

  int get calculatedLevel {
    if (totalPoints < 100) return 1;
    if (totalPoints < 300) return 2;
    if (totalPoints < 600) return 3;
    if (totalPoints < 1000) return 4;
    return 5;
  }

  double get levelProgress {
    const thresholds = [0, 100, 300, 600, 1000];
    final lv = calculatedLevel;
    if (lv >= 5) return 1.0;
    final cur = thresholds[lv - 1];
    final nxt = thresholds[lv];
    return (totalPoints - cur) / (nxt - cur);
  }

  @override
  List<Object?> get props =>
      [id, name, age, totalPoints, level, achievements, skillLevels, activityDates];
}

// ── Provider ───────────────────────────────────────────────

class UserProvider extends ChangeNotifier {
  UserModel? _user;

  UserModel? get user => _user;
  bool get isLoggedIn => _user != null;

  void setUser(UserModel user) {
    _user = user;
    notifyListeners();
  }

  // Persists current state to SharedPreferences automatically
  void _save() {
    if (_user != null) StorageService.instance.saveUser(_user!);
  }

  void addPoints(int points) {
    if (_user == null) return;
    _user = _user!.copyWith(
      totalPoints: _user!.totalPoints + points,
      level: _user!.calculatedLevel,
    );
    notifyListeners();
    _save();
  }

  void updateSkill(String skill, int increment) {
    if (_user == null) return;
    final updated = Map<String, int>.from(_user!.skillLevels);
    updated[skill] = ((updated[skill] ?? 0) + increment).clamp(0, 100);
    _user = _user!.copyWith(skillLevels: updated);
    notifyListeners();
    _save();
  }

  void addAchievement(String achievement) {
    if (_user == null) return;
    if (!_user!.achievements.contains(achievement)) {
      _user = _user!.copyWith(
          achievements: [..._user!.achievements, achievement]);
      notifyListeners();
      _save();
    }
  }

  /// Records today as an activity day (idempotent — safe to call multiple times)
  void recordToday() {
    if (_user == null) return;
    final today = DateTime.now();
    final str =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    if (!_user!.activityDates.contains(str)) {
      _user = _user!.copyWith(
          activityDates: [..._user!.activityDates, str]);
      notifyListeners();
      _save();
    }
  }

  void logout() {
    _user = null;
    notifyListeners();
  }
}
