import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'audio_js_stub.dart'
    if (dart.library.js) 'audio_js_web.dart' as audio_js;

class AudioService {
  // flutter_tts used only on non-web platforms
  FlutterTts? _tts;
  bool _ttsReady = false;

  AudioService() {
    _init();
  }

  Future<void> _init() async {
    if (kIsWeb) {
      // On web everything goes through window.mathMagicoAudio (JS)
      // Voice is already being loaded via initVoice() in index.html
      _ttsReady = true;
      return;
    }

    // Mobile / desktop — use flutter_tts
    _tts = FlutterTts();
    try {
      await _tts!.setLanguage('es-ES');
      await _tts!.setSpeechRate(0.22); // Muy lento y cálido para niños
      await _tts!.setVolume(1.0);
      await _tts!.setPitch(1.05);      // Tono ligeramente cálido

      final voices = await _tts!.getVoices;
      if (voices is List) {
        // Prefer female Spanish voice
        final pick = voices.firstWhere(
          (v) =>
              v is Map &&
              v['locale']?.toString().startsWith('es') == true &&
              v['name']?.toString().toLowerCase().contains('female') == true,
          orElse: () => voices.firstWhere(
            (v) =>
                v is Map && v['locale']?.toString().startsWith('es') == true,
            orElse: () => null,
          ),
        );
        if (pick != null && pick is Map) {
          await _tts!.setVoice({
            'name': pick['name'].toString(),
            'locale': pick['locale'].toString(),
          });
        }
      }
      _tts!.setCompletionHandler(() {});
      _ttsReady = true;
    } catch (_) {
      _ttsReady = false;
    }
  }

  // ── TTS principal ──────────────────────────────────────

  /// [rate]  0.75 = instrucción lenta · 0.88 = normal · 1.0 = festivo
  /// [pitch] 1.25 = amigable para niños · 1.4 = muy animado
  Future<void> speak(String text,
      {double rate = 0.88, double pitch = 1.25}) async {
    if (!_ttsReady) return;
    if (kIsWeb) {
      _callJs('stopSpeech');
      _callJsWith('speak', [text, rate, pitch]);
    } else {
      try {
        await _tts?.stop();
        // Los rates del web (0.75–1.0) se escalan a móvil (0.0–0.5)
        // 0.88 web → ~0.24 móvil (ritmo muy suave para niños)
        final mobileRate = (rate * 0.28).clamp(0.08, 0.40);
        await _tts?.setSpeechRate(mobileRate);
        await _tts?.setPitch(pitch.clamp(0.5, 2.0));
        await _tts?.speak(text);
      } catch (_) {}
    }
  }

  Future<void> speakNumber(int number) async {
    // Numbers: slightly slower & higher pitch so kids hear clearly
    await speak(_numberToWord(number), rate: 0.80, pitch: 1.30);
  }

  Future<void> speakInstruction(String activityType) async {
    const instructions = {
      'suma_visual':
          '¡Vamos a sumar! Cuenta todos los objetos juntos.',
      'resta_visual':
          '¡Vamos a restar! Quita los objetos y cuenta cuántos quedan.',
      'conteo':
          '¡Toca cada objeto una vez para contarlo!',
      'comparar':
          '¿Cuál grupo tiene más? ¡Mira bien los dos grupos!',
      'secuencias':
          '¡Ordena los números del más pequeño al más grande!',
      'reconocer_numeros':
          '¿Qué número ves? ¡Dímelo!',
      'subitizacion':
          '¿Cuántos puntos ves? ¡Mira rápido y responde!',
      'linea_numerica':
          '¿Dónde va ese número en la línea? ¡Toca el lugar correcto!',
      'descomposicion':
          '¿Qué número falta para completar la suma?',
      'trazar_numeros':
          '¡Sigue los puntos en orden para dibujar el número!',
    };
    // Instructions: slower so kids can follow
    await speak(
      instructions[activityType] ?? '¡Vamos a empezar!',
      rate: 0.78,
      pitch: 1.20,
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
    // Correct: fast & excited
    await speak(msg, rate: 0.95, pitch: 1.40);
  }

  Future<void> speakIncorrect() async {
    const messages = [
      '¡Casi! Inténtalo de nuevo. ¡Tú puedes!',
      'No te rindas. Cuenta otra vez despacio.',
      'Estás aprendiendo. ¡Vamos de nuevo!',
      '¡Casi lo tienes! Mira bien y vuelve a intentar.',
      'Tranquilo, nadie aprende sin equivocarse. ¡Otra vez!',
    ];
    final msg = messages[DateTime.now().millisecond % messages.length];
    // Incorrect: calm & encouraging
    await speak(msg, rate: 0.82, pitch: 1.15);
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
