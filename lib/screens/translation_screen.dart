import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../providers/input_mode_provider.dart' show speechServiceProvider;
import '../providers/settings_provider.dart';
import '../providers/conversation_provider.dart';
import '../services/claude_service.dart';

class TranslationWidget extends ConsumerStatefulWidget {
  const TranslationWidget({super.key});

  @override
  ConsumerState<TranslationWidget> createState() => _TranslationWidgetState();
}

class _TranslationWidgetState extends ConsumerState<TranslationWidget> {
  // 'toTarget' = CZ → target, 'fromTarget' = target → CZ
  String _direction = 'toTarget';

  TranslationChallenge? _challenge;
  TranslationEvaluation? _evaluation;
  bool _loadingChallenge = false;
  bool _loadingEvaluation = false;
  String? _error;

  final _textController = TextEditingController();
  bool _isRecording = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;

  @override
  void initState() {
    super.initState();
    _loadChallenge();
  }

  @override
  void dispose() {
    _textController.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadChallenge() async {
    setState(() {
      _loadingChallenge = true;
      _error = null;
      _evaluation = null;
      _textController.clear();
    });
    try {
      final settings = ref.read(settingsProvider);
      final history = ref.read(conversationProvider).messages;
      final claudeService = ClaudeService();
      final challenge = await claudeService.getTranslationChallenge(
          _direction, history, settings);
      setState(() {
        _challenge = challenge;
        _loadingChallenge = false;
      });
    } on ApiKeyMissingException {
      setState(() {
        _error = 'API klíč není nastaven. Přejdi do Nastavení.';
        _loadingChallenge = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Chyba: $e';
        _loadingChallenge = false;
      });
    }
  }

  Future<void> _submit() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _challenge == null) return;
    setState(() {
      _loadingEvaluation = true;
      _error = null;
    });
    try {
      final settings = ref.read(settingsProvider);
      final claudeService = ClaudeService();
      final eval = await claudeService.evaluateTranslation(
          _challenge!.original, text, _direction, settings);
      setState(() {
        _evaluation = eval;
        _loadingEvaluation = false;
      });
    } on ApiKeyMissingException {
      setState(() {
        _error = 'API klíč není nastaven. Přejdi do Nastavení.';
        _loadingEvaluation = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Chyba: $e';
        _loadingEvaluation = false;
      });
    }
  }

  void _nextChallenge() {
    _direction = _direction == 'toTarget' ? 'fromTarget' : 'toTarget';
    _loadChallenge();
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
    // For translation, listen in the direction's source language
    final locale = _direction == 'toTarget'
        ? 'cs-CZ'
        : settings.targetLanguage.locale;
    await speechService.startListening(locale, (text) async {
      if (text.isNotEmpty) {
        await _stopRecording();
        setState(() => _textController.text = text);
      }
    });
  }

  Future<void> _stopRecording() async {
    final speechService = ref.read(speechServiceProvider);
    _recordingTimer?.cancel();
    setState(() => _isRecording = false);
    await speechService.stopListening();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    final directionLabel = _direction == 'toTarget'
        ? 'Přelož do ${settings.targetLanguage.displayName} ↓'
        : 'Přelož do češtiny ↓';

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  directionLabel,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 10),
                _buildChallengeCard(),
                if (_evaluation != null) ...[
                  const SizedBox(height: 12),
                  _buildEvaluationCard(_evaluation!),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _nextChallenge,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accentPrimary,
                      side: const BorderSide(color: AppColors.accentPrimary),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Další věta →'),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.colorRed.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: AppColors.colorRed.withAlpha(80)),
                    ),
                    child: Text(_error!,
                        style:
                            const TextStyle(color: AppColors.textPrimary)),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_evaluation == null) _buildInputBar(),
      ],
    );
  }

  Widget _buildChallengeCard() {
    if (_loadingChallenge) {
      return Container(
        height: 100,
        decoration: BoxDecoration(
          color: AppColors.surfaceColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: const Center(
          child: CircularProgressIndicator(
              color: AppColors.accentPrimary, strokeWidth: 2),
        ),
      );
    }

    if (_challenge == null) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _challenge!.original,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w500),
          ),
          if (_challenge!.hint != null &&
              _challenge!.hint!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('💡 ',
                    style: TextStyle(fontSize: 14)),
                Expanded(
                  child: Text(
                    _challenge!.hint!,
                    style: const TextStyle(
                        color: AppColors.textHint, fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEvaluationCard(TranslationEvaluation eval) {
    final Color bgColor;
    final Color borderColor;

    if (eval.score >= 80) {
      bgColor = AppColors.colorGreen.withAlpha(30);
      borderColor = AppColors.colorGreen.withAlpha(76);
    } else if (eval.score >= 50) {
      bgColor = AppColors.colorOrange.withAlpha(30);
      borderColor = AppColors.colorOrange.withAlpha(76);
    } else {
      bgColor = AppColors.colorRed.withAlpha(30);
      borderColor = AppColors.colorRed.withAlpha(76);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eval.score >= 80) ...[
            Row(children: [
              const Icon(Icons.check_circle,
                  color: AppColors.colorGreen, size: 16),
              const SizedBox(width: 6),
              Text('Správně! (${eval.score}/100)',
                  style: const TextStyle(
                      color: AppColors.colorGreen,
                      fontWeight: FontWeight.w600)),
            ]),
            if (eval.idealTranslation.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(eval.idealTranslation,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
            ],
          ] else ...[
            Text(eval.feedback,
                style: const TextStyle(color: AppColors.textPrimary)),
            if (eval.errors.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...eval.errors.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ',
                            style:
                                TextStyle(color: AppColors.textSecondary)),
                        Expanded(
                          child: Text(e,
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13)),
                        ),
                      ],
                    ),
                  )),
            ],
            if (eval.idealTranslation.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Ideální překlad: ${eval.idealTranslation}',
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontStyle: FontStyle.italic)),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    final isLoading = _loadingEvaluation;

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
              enabled: !_isRecording && !isLoading,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: _isRecording
                    ? 'Nahrávám ${_recordingSeconds ~/ 60}:${(_recordingSeconds % 60).toString().padLeft(2, '0')}'
                    : 'Zadej překlad...',
                hintStyle: TextStyle(
                  color: _isRecording
                      ? AppColors.colorRed
                      : AppColors.textHint,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
              ),
              onSubmitted: (_) => _submit(),
              textInputAction: TextInputAction.send,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: (isLoading || _isRecording) ? null : _submit,
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
        ],
      ),
    );
  }
}
