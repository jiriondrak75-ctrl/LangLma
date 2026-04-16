import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message.dart';
import '../models/user_settings.dart';
import '../services/claude_service.dart';
import '../services/speech_service.dart';
import 'settings_provider.dart';
import 'input_mode_provider.dart' show speechServiceProvider;

enum ConversationStatus { idle, loading, speaking, error }

class ConversationState {
  final List<Message> messages;
  final ConversationStatus status;
  final String? errorMessage;
  final bool isSpeaking;
  final int analyzedUpTo; // index up to which messages have been analyzed

  const ConversationState({
    this.messages = const [],
    this.status = ConversationStatus.idle,
    this.errorMessage,
    this.isSpeaking = false,
    this.analyzedUpTo = 0,
  });

  bool get hasNewMessages => messages.length > analyzedUpTo;

  List<Message> get unanalyzedMessages => messages.sublist(analyzedUpTo);

  ConversationState copyWith({
    List<Message>? messages,
    ConversationStatus? status,
    String? errorMessage,
    bool? isSpeaking,
    int? analyzedUpTo,
  }) {
    return ConversationState(
      messages: messages ?? this.messages,
      status: status ?? this.status,
      errorMessage: errorMessage,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      analyzedUpTo: analyzedUpTo ?? this.analyzedUpTo,
    );
  }
}

class ConversationNotifier extends StateNotifier<ConversationState> {
  final ClaudeService _claudeService;
  final SpeechService _speechService;
  final Ref _ref;

  ConversationNotifier(this._claudeService, this._speechService, this._ref)
      : super(const ConversationState());

  UserSettings get _settings => _ref.read(settingsProvider);

  Future<void> sendMessage(String text, {MessageType type = MessageType.text}) async {
    if (text.trim().isEmpty) return;

    final userMsg = Message(
      role: MessageRole.user,
      content: text.trim(),
      type: type,
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      status: ConversationStatus.loading,
      errorMessage: null,
    );

    try {
      final response =
          await _claudeService.sendMessage(state.messages, _settings);

      final assistantMsg = Message(
        role: MessageRole.assistant,
        content: response,
      );

      state = state.copyWith(
        messages: [...state.messages, assistantMsg],
        status: ConversationStatus.idle,
      );

      if (type == MessageType.voice) {
        state = state.copyWith(isSpeaking: true, status: ConversationStatus.speaking);
        await _speechService.speak(response, _settings.targetLanguage.locale);
        state = state.copyWith(isSpeaking: false, status: ConversationStatus.idle);
      }
    } on ApiKeyMissingException catch (e) {
      state = state.copyWith(
        status: ConversationStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        status: ConversationStatus.error,
        errorMessage: 'Chyba komunikace: $e',
      );
    }
  }

  Future<AnalysisResult> analyzeConversation() async {
    final newMessages = state.unanalyzedMessages;
    final result = await _claudeService.analyzeConversation(newMessages, _settings);
    // Mark all current messages as analyzed
    state = state.copyWith(analyzedUpTo: state.messages.length);
    return result;
  }

  void clearConversation() {
    state = const ConversationState();
  }

  void clearError() {
    state = state.copyWith(status: ConversationStatus.idle, errorMessage: null);
  }
}

final claudeServiceProvider = Provider<ClaudeService>((ref) => ClaudeService());

final conversationProvider =
    StateNotifierProvider<ConversationNotifier, ConversationState>((ref) {
  final claudeService = ref.watch(claudeServiceProvider);
  final speechService = ref.watch(speechServiceProvider);
  return ConversationNotifier(claudeService, speechService, ref);
});
