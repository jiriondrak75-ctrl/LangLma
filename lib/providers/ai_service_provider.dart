import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_settings.dart';
import '../services/ai_service.dart';
import '../services/claude_ai_service.dart';
import '../services/gemini_ai_service.dart';
import 'settings_provider.dart';

final aiServiceProvider = Provider<AiService>((ref) {
  final settings = ref.watch(settingsProvider);
  return switch (settings.aiProvider) {
    AiProvider.claude => ClaudeAiService(),
    AiProvider.gemini => GeminiAiService(),
  };
});
