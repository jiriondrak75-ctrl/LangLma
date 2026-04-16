import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppMode { conversation, translation, test }

class AppModeNotifier extends StateNotifier<AppMode> {
  AppModeNotifier() : super(AppMode.conversation) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final index = (prefs.getInt('appMode') ?? 0)
        .clamp(0, AppMode.values.length - 1);
    state = AppMode.values[index];
  }

  Future<void> setMode(AppMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('appMode', mode.index);
    state = mode;
  }
}

final appModeProvider =
    StateNotifierProvider<AppModeNotifier, AppMode>((ref) => AppModeNotifier());
