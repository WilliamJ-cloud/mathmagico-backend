import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// URL del servidor guardada en el dispositivo.
/// Puede cambiarse desde la pantalla del profesor sin recompilar.
class ServerConfig {
  static const _key = 'server_url';

  // URL por defecto según plataforma
  static String get _defaultUrl => kIsWeb
      ? 'http://localhost:8000/api/v1'
      : 'https://mathmagico-backend.onrender.com/api/v1';

  static String _current = '';

  /// Carga la URL guardada (llamar al inicio de la app)
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key) ?? _defaultUrl;
    // Si la URL guardada apunta a una IP local antigua, migrar a Render
    if (saved.contains('192.168') || saved.contains('localhost:8000') ||
        saved.contains('loca.lt') || saved.contains('serveo') ||
        !saved.startsWith('http')) {
      await prefs.setString(_key, _defaultUrl);
      _current = _defaultUrl;
    } else {
      _current = saved;
    }
  }

  /// URL activa (ya cargada)
  static String get baseUrl => _current.isEmpty ? _defaultUrl : _current;

  /// Guarda una nueva URL y la activa inmediatamente
  static Future<void> save(String url) async {
    // Eliminar caracteres inválidos al inicio (puntos, espacios, etc.)
    var clean = url.trim().replaceAll(RegExp(r'^[^a-zA-Z]+'), '');
    clean = clean.replaceAll(RegExp(r'/$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, clean);
    _current = clean;
  }

  /// Restaura la URL por defecto
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    _current = _defaultUrl;
  }
}
