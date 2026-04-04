import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// URL del servidor guardada en el dispositivo.
/// Puede cambiarse desde la pantalla del profesor sin recompilar.
class ServerConfig {
  static const _key = 'server_url';

  // URL por defecto según plataforma
  static String get _defaultUrl => kIsWeb
      ? 'http://localhost:8000/api/v1'
      : 'http://192.168.0.7:8000/api/v1';

  static String _current = '';

  /// Carga la URL guardada (llamar al inicio de la app)
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _current = prefs.getString(_key) ?? _defaultUrl;
  }

  /// URL activa (ya cargada)
  static String get baseUrl => _current.isEmpty ? _defaultUrl : _current;

  /// Guarda una nueva URL y la activa inmediatamente
  static Future<void> save(String url) async {
    final clean = url.trim().replaceAll(RegExp(r'/$'), '');
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
