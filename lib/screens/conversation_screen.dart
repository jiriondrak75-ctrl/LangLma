import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../models/message.dart';
import '../models/user_settings.dart';
import '../providers/conversation_provider.dart';
import '../providers/input_mode_provider.dart' show speechServiceProvider;
import '../providers/settings_provider.dart';

class ConversationWidget extends ConsumerStatefulWidget {
  const ConversationWidget({super.key});

  @override
  ConsumerState<ConversationWidget> createState() =>
      _ConversationWidgetState();
}

class _ConversationWidgetState extends ConsumerState<ConversationWidget> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isRecording = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    await ref.read(conversationProvider.notifier).sendMessage(text);
    _scrollToBottom();
  }

  Future<void> _startRecording() async {
    final speechService = ref.read(speechServiceProvider);
    final settings = ref.read(settingsProvider);
    setState(() {
      _isRecording = true;
      _recordingSeconds = 0;
    });
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _recordingSeconds++);
    });
    await speechService.startListening(
      settings.targetLanguage.locale,
      (text) async {
        if (text.isNotEmpty) {
          await _stopRecording();
          await ref
              .read(conversationProvider.notifier)
              .sendMessage(text, type: MessageType.voice);
          _scrollToBottom();
        }
      },
    );
  }

  Future<void> _stopRecording() async {
    final speechService = ref.read(speechServiceProvider);
    _recordingTimer?.cancel();
    setState(() => _isRecording = false);
    await speechService.stopListening();
  }

  void _showApiKeyDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceColor,
        title: const Text('Chybí API klíč',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
            'Pro použití aplikace potřebuješ nastavit API klíč Claude.',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(conversationProvider.notifier).clearError();
            },
            child: const Text('Zrušit'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(conversationProvider.notifier).clearError();
              context.push('/settings');
            },
            child: const Text('Nastavení'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final convState = ref.watch(conversationProvider);
    final settings = ref.watch(settingsProvider);

    if (convState.status == ConversationStatus.error &&
        convState.errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showApiKeyDialog();
      });
    }

    if (convState.messages.isNotEmpty) {
      _scrollToBottom();
    }

    return Column(
      children: [
        Expanded(
          child: convState.messages.isEmpty
              ? _buildEmptyState(settings)
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: convState.messages.length +
                      (convState.status == ConversationStatus.loading
                          ? 1
                          : 0),
                  itemBuilder: (context, index) {
                    if (index == convState.messages.length) {
                      return _buildLoadingBubble();
                    }
                    final msg = convState.messages[index];
                    final isLastAssistant =
                        msg.role == MessageRole.assistant &&
                            index == convState.messages.length - 1;
                    return _buildMessageBubble(
                      msg,
                      isSpeaking:
                          isLastAssistant && convState.isSpeaking,
                    );
                  },
                ),
        ),
        _buildBottomBar(convState),
      ],
    );
  }

  Widget _buildEmptyState(UserSettings settings) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              settings.targetLanguage.flag,
              style: const TextStyle(fontSize: 64),
            ),
            const SizedBox(height: 16),
            Text(
              'Začni konverzaci v ${settings.targetLanguage.displayName}',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Message msg, {bool isSpeaking = false}) {
    final isUser = msg.role == MessageRole.user;
    final isVoiceMsg = msg.type == MessageType.voice;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          child: Column(
            crossAxisAlignment:
                isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isUser
                      ? AppColors.userBubbleBg
                      : AppColors.assistantBubbleBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isUser
                        ? AppColors.userBubbleBorder
                        : AppColors.assistantBubbleBorder,
                  ),
                ),
                child: isVoiceMsg && isUser
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.mic,
                              size: 14,
                              color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(msg.content,
                                style: const TextStyle(
                                    color: AppColors.textPrimary)),
                          ),
                        ],
                      )
                    : Text(msg.content,
                        style: const TextStyle(
                            color: AppColors.textPrimary)),
              ),
              if (isSpeaking) ...[
                const SizedBox(height: 4),
                _buildSoundWaves(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSoundWaves() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1.5),
          child: Container(
            width: 3,
            height: 12,
            decoration: BoxDecoration(
              color: AppColors.colorGreen,
              borderRadius: BorderRadius.circular(2),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleY(
                begin: 0.3,
                end: 1.0,
                duration: Duration(milliseconds: 300 + i * 80),
                curve: Curves.easeInOut,
              ),
        );
      }),
    );
  }

  Widget _buildLoadingBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.assistantBubbleBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.assistantBubbleBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.textSecondary,
                    shape: BoxShape.circle,
                  ),
                )
                    .animate(onPlay: (c) => c.repeat())
                    .fadeIn(
                      delay: Duration(milliseconds: i * 200),
                      duration: const Duration(milliseconds: 400),
                    )
                    .then()
                    .fadeOut(
                        duration: const Duration(milliseconds: 400)),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(ConversationState convState) {
    final isLoading = convState.status == ConversationStatus.loading;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceColor,
        border: Border(top: BorderSide(color: AppColors.borderColor)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              enabled: !_isRecording,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: _isRecording
                    ? 'Nahrávám ${_recordingSeconds ~/ 60}:${(_recordingSeconds % 60).toString().padLeft(2, '0')}'
                    : 'Napiš zprávu...',
                hintStyle: TextStyle(
                  color: _isRecording
                      ? AppColors.colorRed
                      : AppColors.textHint,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
              ),
              onSubmitted: (_) => _sendText(),
              textInputAction: TextInputAction.send,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: (isLoading || _isRecording) ? null : _sendText,
            icon: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.accentPrimary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.accentDim,
              disabledForegroundColor: AppColors.textHint,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: isLoading
                ? null
                : (_isRecording ? _stopRecording : _startRecording),
            icon: Icon(_isRecording ? Icons.stop : Icons.mic),
            style: IconButton.styleFrom(
              backgroundColor: _isRecording
                  ? AppColors.colorRed
                  : AppColors.cardColor,
              foregroundColor: _isRecording
                  ? Colors.white
                  : AppColors.textPrimary,
              side: BorderSide(
                  color: _isRecording
                      ? AppColors.colorRed
                      : AppColors.borderColor),
            ),
          ),
          const SizedBox(width: 4),
          OutlinedButton(
            onPressed: () => context.push('/analysis'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.colorGreen,
              side: const BorderSide(color: AppColors.colorGreen),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: const Text('Kontrola'),
          ),
        ],
      ),
    );
  }
}
