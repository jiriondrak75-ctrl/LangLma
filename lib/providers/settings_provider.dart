import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_settings.dart';

class SettingsNotifier extends StateNotifier<UserSettings> {
  SettingsNotifier() : super(const UserSettings()) {
    _load();
  }

  static const _storage = FlutterSecureStorage();

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final langIndex = prefs.getInt('targetLanguage') ?? Language.english.index;
    final levelIndex =
        prefs.getInt('level') ?? LanguageLevel.intermediate.index;
    final inputModeIndex = prefs.getInt('inputMode') ?? InputMode.text.index;

    state = UserSettings(
      name: prefs.getString('name') ?? '',
      gender: prefs.getString('gender') ?? 'Neuvedeno',
      nativeLanguage: prefs.getString('nativeLanguage') ?? 'Čeština',
      targetLanguage: Language.values[langIndex],
      level: LanguageLevel.values[levelIndex],
      inputMode: InputMode.values[inputModeIndex],
      teachingStyle: prefs.getString('teachingStyle') ?? 'Přátelský',
    );
  }

  Future<void> save(UserSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('name', settings.name);
    await prefs.setString('gender', settings.gender);
    await prefs.setString('nativeLanguage', settings.nativeLanguage);
    await prefs.setInt('targetLanguage', settings.targetLanguage.index);
    await prefs.setInt('level', settings.level.index);
    await prefs.setInt('inputMode', settings.inputMode.index);
    await prefs.setString('teachingStyle', settings.teachingStyle);
    state = settings;
  }

  Future<void> updateLanguageAndLevel(
      Language language, LanguageLevel level) async {
    final updated = state.copyWith(targetLanguage: language, level: level);
    await save(updated);
  }

  Future<void> updateInputMode(InputMode mode) async {
    final updated = state.copyWith(inputMode: mode);
    await save(updated);
  }

  Future<void> saveApiKey(String key) async {
    // Always write to SharedPreferences (reliable on all platforms incl. web)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_key_fallback', key);
    // Also attempt secure storage
    try {
      await _storage.write(key: 'claude_api_key', value: key);
    } catch (_) {}
  }

  Future<String> getApiKey() async {
    try {
      final key = await _storage.read(key: 'claude_api_key');
      if (key != null && key.isNotEmpty) return key;
    } catch (_) {}
    // Fallback to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('api_key_fallback') ?? '';
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, UserSettings>((ref) {
  return SettingsNotifier();
});
