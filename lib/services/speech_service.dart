import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _sttInitialized = false;

  Future<void> requestPermissions() async {
    await Permission.microphone.request();
  }

  Future<bool> _initStt() async {
    if (_sttInitialized) return true;
    _sttInitialized = await _stt.initialize(
      onError: (error) {},
      onStatus: (status) {},
    );
    return _sttInitialized;
  }

  Future<void> startListening(
      String locale, void Function(String text) onResult) async {
    final ready = await _initStt();
    if (!ready) return;

    await _stt.listen(
      localeId: locale,
      onResult: (result) {
        if (result.finalResult) {
          onResult(result.recognizedWords);
        }
      },
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.confirmation,
        cancelOnError: false,
        partialResults: false,
      ),
    );
  }

  Future<void> stopListening() async {
    await _stt.stop();
  }

  bool get isListening => _stt.isListening;

  Future<void> speak(String text, String locale) async {
    await _tts.setLanguage(locale);
    await _tts.speak(text);
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
  }

  Future<void> setTtsCompletionHandler(VoidCallback onComplete) async {
    _tts.setCompletionHandler(onComplete);
  }

  Future<void> dispose() async {
    await _stt.stop();
    await _tts.stop();
  }
}

typedef VoidCallback = void Function();
