import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'audio_js_stub.dart'
    if (dart.library.js) 'audio_js_web.dart' as audio_js;

class AudioService {
  FlutterTts? _tts;
  bool _ttsReady = false;
  bool _isSpeaking = false;

  // Locales preferidos en orden — Android suele tener mejores voces en es-US
  static const _localePrefs = ['es-US', 'es-MX', 'es-ES', 'es'];

  AudioService() {
    _init();
  }

  Future<void> _init() async {
    if (kIsWeb) {
      _ttsReady = true;
      return;
    }

    _tts = FlutterTts();
    try {
      // Que no bloquee el hilo esperando que termine cada frase
      await _tts!.awaitSpeakCompletion(false);

      final voices = await _tts!.getVoices;
      final voiceList = voices is List ? voices.cast<dynamic>() : <dynamic>[];

      // 1. Buscar voz Google en español (la más natural en Android)
      Map? bestVoice = _findVoice(voiceList, requireGoogle: true);
      // 2. Si no hay Google, cualquier voz española
      bestVoice ??= _findVoice(voiceList, requireGoogle: false);

      if (bestVoice != null) {
        final locale = bestVoice['locale']?.toString() ?? 'es-US';
        await _tts!.setLanguage(locale);
        await _tts!.setVoice({
          'name': bestVoice['name'].toString(),
          'locale': locale,
        });
      } else {
        // Ninguna voz española instalada — usar locale por defecto
        await _tts!.setLanguage('es-US');
      }

      // Parámetros naturales: ritmo y tono próximos al habla humana
      await _tts!.setSpeechRate(0.48); // normal Android es 1.0; 0.48 = suave
      await _tts!.setVolume(1.0);
      await _tts!.setPitch(1.0);       // 1.0 = tono natural, sin distorsión

      _tts!.setStartHandler(() => _isSpeaking = true);
      _tts!.setCompletionHandler(() => _isSpeaking = false);
      _tts!.setCancelHandler(() => _isSpeaking = false);
      _tts!.setErrorHandler((_) => _isSpeaking = false);

      _ttsReady = true;
    } catch (_) {
      _ttsReady = false;
    }
  }

  /// Selecciona la mejor voz española disponible.
  /// [requireGoogle] = true → solo voces con "google" en el nombre.
  Map? _findVoice(List<dynamic> voices, {required bool requireGoogle}) {
    for (final locale in _localePrefs) {
      for (final v in voices) {
        if (v is! Map) continue;
        final name   = v['name']?.toString().toLowerCase() ?? '';
        final vLocale = v['locale']?.toString() ?? '';
        if (!vLocale.toLowerCase().startsWith(locale.toLowerCase())) continue;
        if (requireGoogle && !name.contains('google')) continue;
        // Preferir voces femeninas (suelen sonar más cálidas para niños)
        if (name.contains('female') || name.contains('mujer') ||
            name.contains('sofia') || name.contains('paulina') ||
            name.contains('monica') || name.contains('laura') ||
            name.contains('lucia') || name.contains('-f-')) {
          return v as Map;
        }
      }
      // Segunda pasada: cualquier voz del locale (sin filtro de género)
      for (final v in voices) {
        if (v is! Map) continue;
        final name    = v['name']?.toString().toLowerCase() ?? '';
        final vLocale = v['locale']?.toString() ?? '';
        if (!vLocale.toLowerCase().startsWith(locale.toLowerCase())) continue;
        if (requireGoogle && !name.contains('google')) continue;
        return v as Map;
      }
    }
    return null;
  }

  // ── TTS principal ──────────────────────────────────────

  /// [rate]  escala semántica: 0.75 lento · 1.0 normal · 1.15 animado
  /// [pitch] 1.0 natural · 1.10 cálido para niños
  Future<void> speak(String text,
      {double rate = 1.0, double pitch = 1.05}) async {
    if (!_ttsReady) return;

    if (kIsWeb) {
      _callJs('stopSpeech');
      _callJsWith('speak', [text, rate, pitch]);
      return;
    }

    try {
      // Parar lo que esté sonando y dar 80 ms para que el motor libere recursos
      await _tts?.stop();
      await Future.delayed(const Duration(milliseconds: 80));

      // Mapear la escala semántica (0.75–1.15) al rango Android (0.35–0.60)
      // rate=0.75 → 0.38  |  rate=1.0 → 0.48  |  rate=1.15 → 0.55
      final mobileRate = ((rate - 0.75) / 0.40 * 0.17 + 0.38).clamp(0.35, 0.60);
      await _tts?.setSpeechRate(mobileRate);
      await _tts?.setPitch(pitch.clamp(0.85, 1.20));
      await _tts?.speak(text);
    } catch (_) {}
  }

  Future<void> speakNumber(int number) async {
    await speak(_numberToWord(number), rate: 0.85, pitch: 1.05);
  }

  Future<void> speakInstruction(String activityType) async {
    const instructions = {
      'suma_visual':
          '¡Vamos a sumar! Cuenta todos los objetos juntos.',
      'resta_visual':
          '¡Vamos a restar! Quita los que sobran y cuenta cuántos quedan.',
      'conteo':
          '¡Toca cada objeto una vez para contarlo!',
      'comparar':
          '¿Cuál grupo tiene más, menos, o son iguales?',
      'secuencias':
          '¡Ordena los números del más pequeño al más grande!',
      'reconocer_numeros':
          '¿Qué número ves? ¡Dímelo!',
      'subitizacion':
          '¿Cuántos puntos ves? ¡Responde rápido sin contar uno por uno!',
      'linea_numerica':
          '¿Dónde está ese número en la línea? ¡Toca el lugar correcto!',
      'descomposicion':
          '¿Qué número falta para completar la suma?',
      'trazar_numeros':
          '¡Sigue los puntos en orden para dibujar el número!',
    };
    await speak(
      instructions[activityType] ?? '¡Vamos a empezar!',
      rate: 0.82,
      pitch: 1.05,
    );
  }

  Future<void> speakCorrect() async {
    const messages = [
      '¡Muy bien! ¡Lo lograste!',
      '¡Excelente! ¡Eres increíble!',
      '¡Correcto! ¡Sigue así, campeón!',
      '¡Perfecto! ¡Eres muy inteligente!',
      '¡Genial! ¡Eso es exactamente!',
      '¡Súper! ¡Eres una estrella!',
    ];
    final msg = messages[DateTime.now().millisecond % messages.length];
    await speak(msg, rate: 1.05, pitch: 1.10);
  }

  Future<void> speakIncorrect() async {
    const messages = [
      '¡Casi! Inténtalo de nuevo. ¡Tú puedes!',
      'No te rindas. Mira bien y cuenta otra vez.',
      'Estás aprendiendo. ¡Vamos de nuevo!',
      '¡Casi lo tienes! Observa con cuidado.',
      'Tranquilo, ¡nadie aprende sin equivocarse! ¡Otra vez!',
    ];
    final msg = messages[DateTime.now().millisecond % messages.length];
    await speak(msg, rate: 0.90, pitch: 1.02);
  }

  // ── Efectos de sonido — Web Audio API ─────────────────

  void playCorrectSound()   => _callJs('playCorrect');
  void playIncorrectSound() => _callJs('playIncorrect');
  void playCelebration()    => _callJs('playCelebration');
  void playTapSound()       => _callJs('playTap');
  void playUnlockSound()    => _callJs('playUnlock');
  void playSelectSound()    => _callJs('playSelect');

  // ── Helpers ────────────────────────────────────────────

  void _callJs(String method) {
    if (!kIsWeb) return;
    audio_js.callJs(method);
  }

  void _callJsWith(String method, List<dynamic> args) {
    if (!kIsWeb) return;
    audio_js.callJsWith(method, args);
  }

  Future<void> stop() async {
    if (kIsWeb) {
      _callJs('stopSpeech');
    } else {
      try { await _tts?.stop(); } catch (_) {}
    }
  }

  void dispose() {
    if (!kIsWeb) {
      try { _tts?.stop(); } catch (_) {}
    }
  }

  String _numberToWord(int n) {
    const words = [
      'cero', 'uno', 'dos', 'tres', 'cuatro', 'cinco',
      'seis', 'siete', 'ocho', 'nueve', 'diez',
    ];
    return (n >= 0 && n < words.length) ? words[n] : n.toString();
  }
}
