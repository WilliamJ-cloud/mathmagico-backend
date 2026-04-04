/// Implementación web real usando dart:js.
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

void callJs(String method) {
  try {
    js.context['mathMagicoAudio']?.callMethod(method);
  } catch (_) {}
}

void callJsWith(String method, List<dynamic> args) {
  try {
    js.context['mathMagicoAudio']?.callMethod(method, args);
  } catch (_) {}
}
