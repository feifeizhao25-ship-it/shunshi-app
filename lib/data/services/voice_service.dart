import 'package:speech_to_text/speech_to_text.dart';

class VoiceService {
  final SpeechToText _speech = SpeechToText();
  String _lastWords = '';

  String get lastWords => _lastWords;

  Future<bool> initialize() async {
    try {
      return await _speech.initialize();
    } catch (_) {
      return false;
    }
  }

  Future<bool> startListening({required void Function(String) onResult}) async {
    if (!_speech.isAvailable) {
      final initialized = await initialize();
      if (!initialized) return false;
    }
    try {
      await _speech.listen(
        localeId: 'zh_CN',
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 3),
        onResult: (result) {
          _lastWords = result.recognizedWords;
          onResult(_lastWords);
        },
      );
      return _speech.isListening;
    } catch (_) {
      return false;
    }
  }

  Future<void> stopListening() async {
    try {
      await _speech.stop();
    } catch (_) {
      // The platform plugin can be absent in widget tests and unsupported OSes.
    }
  }

  void reset() {
    _lastWords = '';
  }
}
