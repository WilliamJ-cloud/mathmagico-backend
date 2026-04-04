import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/constants.dart';

class ApiService {
  static String get _base => AppConstants.baseUrl;

  // ── Sanitizar nulls ───────────────────────────────────
  static Map<String, dynamic> _sanitizeStatic(Map<String, dynamic> input) {
    final result = <String, dynamic>{};
    input.forEach((key, value) {
      if (value == null) {
        result[key] = '';
      } else if (value is String) {
        result[key] = value.trim();
      } else {
        result[key] = value;
      }
    });
    return result;
  }

  static Map<String, String> _headersStatic() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    // LocalTunnel requiere este header para evitar la página de bloqueo
    if (_base.contains('loca.lt')) {
      headers['bypass-tunnel-reminder'] = 'true';
    }
    return headers;
  }

  static Map<String, dynamic>? _parseStatic(http.Response res) {
    try {
      final body = utf8.decode(res.bodyBytes);
      if (body.isEmpty) return null;
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        if (res.statusCode >= 400) {
          return {
            'error': true,
            'status': res.statusCode,
            'detail': decoded['detail']?.toString() ?? 'Error del servidor',
          };
        }
        return decoded;
      }
      return {'data': decoded};
    } catch (e) {
      print('ApiService parse error: $e');
      return null;
    }
  }

  // ════════════════════════════════════════════════════
  // MÉTODOS ESTÁTICOS (para usar como ApiService.metodo())
  // ════════════════════════════════════════════════════

  static Future<Map<String, dynamic>?> get(String endpoint) async {
    try {
      final res = await http
          .get(Uri.parse('$_base$endpoint'), headers: _headersStatic())
          .timeout(const Duration(seconds: 15));
      return _parseStatic(res);
    } catch (e) {
      print('GET error: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final clean = _sanitizeStatic(body);
      final res = await http
          .post(
            Uri.parse('$_base$endpoint'),
            headers: _headersStatic(),
            body: jsonEncode(clean),
          )
          .timeout(const Duration(seconds: 15));
      return _parseStatic(res);
    } catch (e) {
      print('POST error: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> put(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final clean = _sanitizeStatic(body);
      final res = await http
          .put(
            Uri.parse('$_base$endpoint'),
            headers: _headersStatic(),
            body: jsonEncode(clean),
          )
          .timeout(const Duration(seconds: 15));
      return _parseStatic(res);
    } catch (e) {
      print('PUT error: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> deleteReq(String endpoint) async {
    try {
      final res = await http
          .delete(Uri.parse('$_base$endpoint'), headers: _headersStatic())
          .timeout(const Duration(seconds: 15));
      return _parseStatic(res);
    } catch (e) {
      print('DELETE error: $e');
      return null;
    }
  }

  // ════════════════════════════════════════════════════
  // MÉTODOS DE INSTANCIA (para usar como apiService.metodo())
  // Estas son las que usan splash_screen, activity_screen, progress_screen
  // ════════════════════════════════════════════════════

  // ── USUARIOS ─────────────────────────────────────────

  Future<Map<String, dynamic>?> registerUser({
    required String name,
    required int age,
    required String avatarEmoji,
  }) async {
    return post('/users/register', {
      'name': name,
      'age': age,
      'avatar_emoji': avatarEmoji,
    });
  }

  Future<Map<String, dynamic>?> getUser(String userId) async {
    return get('/users/$userId');
  }

  Future<Map<String, dynamic>?> updateUserPoints(
    String userId, {
    required int points,
    required List<String> achievements,
    required Map<String, dynamic> skillLevels,
  }) async {
    return post('/users/$userId/update', {
      'points': points,
      'achievements': achievements,
      'skill_levels': skillLevels,
    });
  }

  // ── ACTIVIDADES ───────────────────────────────────────

  Future<Map<String, dynamic>?> getQuestions({
    required String userId,
    required String activityType,
    String difficulty = 'facil',
    int count = 5,
  }) async {
    final endpoint =
        '/activities/questions?user_id=$userId'
        '&activity_type=$activityType'
        '&difficulty=$difficulty'
        '&count=$count';
    return get(endpoint);
  }

  Future<Map<String, dynamic>?> submitActivityResult(
    Map<String, dynamic> result,
  ) async {
    return post('/activities/submit', result);
  }

  // ── PROGRESO ──────────────────────────────────────────

  Future<Map<String, dynamic>?> getUserProgress(String userId) async {
    return get('/progress/$userId');
  }

  Future<Map<String, dynamic>?> getAiAnalysis(String userId) async {
    return get('/progress/$userId/ai-analysis');
  }

  // ── IA / PISTAS ───────────────────────────────────────

  Future<Map<String, dynamic>?> getHint({
    required String userId,
    required String activityType,
    required String questionText,
    required int correctAnswer,
    String? userAnswer,
  }) async {
    return post('/ai/hint', {
      'user_id': userId,
      'activity_type': activityType,
      'question_text': questionText,
      'correct_answer': correctAnswer,
      'user_answer': userAnswer ?? '',
    });
  }

  Future<Map<String, dynamic>?> analyzeDiscalculia(String userId) async {
    return post('/ai/analyze', {'user_id': userId});
  }

  // ── TTS ───────────────────────────────────────────────

  Future<Map<String, dynamic>?> textToSpeech(String text) async {
    return post('/tts/speak', {'text': text});
  }

  // ── PORTAL DEL PROFESOR (instancia) ──────────────────

  Future<Map<String, dynamic>?> registerTeacher({
    required String name,
    required String school,
    required String email,
    required String password,
  }) async {
    return post('/teachers/register', {
      'name': name,
      'school': school,
      'email': email,
      'password': password,
    });
  }

  Future<Map<String, dynamic>?> loginTeacher({
    required String email,
    required String password,
  }) async {
    return post('/teachers/login', {
      'email': email,
      'password': password,
    });
  }

  Future<Map<String, dynamic>?> getTeacherStudents(String teacherId) async {
    return get('/teachers/$teacherId/students');
  }

  Future<Map<String, dynamic>?> addStudentToTeacher({
    required String teacherId,
    required String name,
    required int age,
    required String avatarEmoji,
    String grade = '',
    String parentName = '',
    String parentPhone = '',
  }) async {
    return post('/teachers/$teacherId/students', {
      'name': name,
      'age': age,
      'avatar_emoji': avatarEmoji,
      'grade': grade,
      'parent_name': parentName,
      'parent_phone': parentPhone,
    });
  }

  Future<Map<String, dynamic>?> deleteStudent({
    required String teacherId,
    required String studentId,
  }) async {
    return deleteReq('/teachers/$teacherId/students/$studentId');
  }

  Future<Map<String, dynamic>?> getStudentProgress({
    required String teacherId,
    required String studentId,
  }) async {
    return get('/teachers/$teacherId/students/$studentId/progress');
  }

  Future<Map<String, dynamic>?> getTeacherDashboard(String teacherId) async {
    return get('/teachers/$teacherId/dashboard');
  }

  String getReportPdfUrl({
    required String teacherId,
    required String studentId,
  }) {
    return '$_base/teachers/$teacherId/students/$studentId/report-pdf';
  }
}