import "package:shared_preferences/shared_preferences.dart";
import "dart:convert";
import "../models/user_model.dart";
import "../models/activity_model.dart";

class StorageService {
  static final StorageService instance = StorageService._internal();
  StorageService._internal();

  Future<void> init() async {}

  Future<void> saveUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("user_${user.id}", jsonEncode(user.toJson()));
  }

  Future<UserModel?> getUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString("user_$userId");
    if (data == null) return null;
    return UserModel.fromJson(jsonDecode(data));
  }

  Future<void> updateUserPoints(String userId, int points) async {
    final user = await getUser(userId);
    if (user == null) return;
    final updated = user.copyWith(totalPoints: user.totalPoints + points);
    await saveUser(updated);
  }

  Future<void> saveSession(ActivityResult result) async {
    final prefs = await SharedPreferences.getInstance();
    final key = "session_${result.userId}_${result.completedAt.millisecondsSinceEpoch}";
    await prefs.setString(key, jsonEncode(result.toJson()));
  }

  Future<List<Map<String, dynamic>>> getRecentSessions(String userId, int limit) async => [];
  Future<List<Map<String, dynamic>>> getUnsynced() async => [];
  Future<void> markSynced(String sessionId) async {}

  Future<void> saveCurrentUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("current_user_id", userId);
  }

  Future<String?> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("current_user_id");
  }

  Future<void> savePreference(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) await prefs.setBool(key, value);
    if (value is String) await prefs.setString(key, value);
    if (value is int) await prefs.setInt(key, value);
    if (value is double) await prefs.setDouble(key, value);
  }

  Future<dynamic> getPreference(String key, dynamic defaultValue) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.get(key) ?? defaultValue;
  }
}
