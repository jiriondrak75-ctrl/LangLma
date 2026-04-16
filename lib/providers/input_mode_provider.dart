import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_settings.dart';
import '../services/speech_service.dart';

class InputModeNotifier extends StateNotifier<InputMode> {
  final SpeechService _speechService;

  InputModeNotifier(this._speechService) : super(InputMode.text) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt('inputMode') ?? InputMode.text.index;
    state = InputMode.values[index];
  }

  Future<void> setMode(InputMode mode) async {
    if (mode == InputMode.text) {
      await _speechService.stopListening();
      await _speechService.stopSpeaking();
    } else {
      await _speechService.requestPermissions();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('inputMode', mode.index);
    state = mode;
  }
}

final speechServiceProvider = Provider<SpeechService>((ref) => SpeechService());

final inputModeProvider =
    StateNotifierProvider<InputModeNotifier, InputMode>((ref) {
  final speechService = ref.watch(speechServiceProvider);
  return InputModeNotifier(speechService);
});
