import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../providers/app_mode_provider.dart';
import '../providers/conversation_provider.dart';
import '../services/ai_service.dart';

class AnalysisScreen extends ConsumerStatefulWidget {
  const AnalysisScreen({super.key});

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen> {
  AnalysisResult? _result;
  bool _loading = true;
  String? _error;
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _analyze();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final convState = ref.read(conversationProvider);
    if (convState.messages.isEmpty) {
      setState(() {
        _error = 'Žádné zprávy k analýze. Nejdřív si popovídej s učitelem.';
        _loading = false;
      });
      return;
    }
    if (!convState.hasNewMessages) {
      setState(() {
        _error = 'Žádné nové zprávy od poslední kontroly.';
        _loading = false;
      });
      return;
    }

    try {
      final result = await ref
          .read(conversationProvider.notifier)
          .analyzeConversation();
      setState(() {
        _result = result;
        _loading = false;
      });
    } on ApiKeyMissingException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } on DioException catch (e) {
      final body = e.response?.data?.toString() ?? '';
      setState(() {
        _error = 'API chyba ${e.response?.statusCode}: $body';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Chyba: $e';
        _loading = false;
      });
    }
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    await ref.read(conversationProvider.notifier).sendMessage(text);
  }

  int get _newMessageCount =>
      ref.read(conversationProvider).unanalyzedMessages.length;

  @override
  Widget build(BuildContext context) {
    final convState = ref.watch(conversationProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Kontrola konverzace'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.colorGreen.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.colorGreen.withAlpha(80)),
              ),
              child: Text(
                '$_newMessageCount nových',
                style: const TextStyle(color: AppColors.colorGreen, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? _buildSkeletonLoading()
                : _error != null
                    ? _buildError()
                    : _buildContent(),
          ),
          _buildBottomBar(convState),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (context, _) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.surfaceColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: Center(child: _buildDots()),
        ),
      ),
    );
  }

  Widget _buildDots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Container(
            width: 8,
            height: 8,
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
              .fadeOut(duration: const Duration(milliseconds: 400)),
        );
      }),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.colorRed, size: 48),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.textPrimary),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_result == null) return const SizedBox();
    final r = _result!;

    if (r.rawText != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _buildCard(
          tagLabel: 'Analýza',
          tagColor: AppColors.textSecondary,
          child: Text(r.rawText!,
              style: const TextStyle(color: AppColors.textPrimary)),
        ),
      );
    }

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        if (r.summary.isNotEmpty)
          _buildCard(
            tagLabel: 'Hodnocení',
            tagColor: AppColors.textSecondary,
            child: Text(r.summary,
                style: const TextStyle(color: AppColors.textPrimary)),
          ),
        const SizedBox(height: 8),
        ...r.errors.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildCard(
                tagLabel: 'Gramatická chyba',
                tagColor: AppColors.colorRed,
                bgColor: AppColors.colorRed.withAlpha(38),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.original,
                        style: const TextStyle(
                            color: AppColors.colorRed,
                            decoration: TextDecoration.lineThrough)),
                    const SizedBox(height: 4),
                    Text(e.correction,
                        style: const TextStyle(color: AppColors.colorGreen)),
                    const SizedBox(height: 6),
                    Text(e.explanation,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
            )),
        ...r.tips.map((tip) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildCard(
                tagLabel: 'Tip',
                tagColor: AppColors.colorGreen,
                bgColor: AppColors.colorGreen.withAlpha(30),
                child: Text(tip,
                    style: const TextStyle(color: AppColors.textPrimary)),
              ),
            )),
        ...r.exercises.map((ex) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildCard(
                tagLabel: 'Procvičení',
                tagColor: AppColors.accentSecondary,
                bgColor: AppColors.accentDim,
                child: Text(ex,
                    style: const TextStyle(color: AppColors.textPrimary)),
              ),
            )),
        _buildWeakAreasBanner(),
      ],
    );
  }

  Widget _buildWeakAreasBanner() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2a2740),
        border: Border.all(color: const Color(0xFF3c3770)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Text('🎯', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Seznam oblastí byl aktualizován',
              style: TextStyle(color: Color(0xFFAFA9EC), fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(appModeProvider.notifier).setMode(AppMode.test);
              context.go('/');
            },
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Přejít na Test →',
              style: TextStyle(color: Color(0xFF4ec9b0), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String tagLabel,
    required Color tagColor,
    Color? bgColor,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor ?? AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tagColor.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: tagColor.withAlpha(30),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(tagLabel,
                style: TextStyle(
                    color: tagColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 8),
          child,
        ],
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
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Odpověz na procvičení...',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onSubmitted: (_) => _send(),
              textInputAction: TextInputAction.send,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: isLoading ? null : _send,
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
        ],
      ),
    );
  }
}
