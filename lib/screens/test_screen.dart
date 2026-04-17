import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../models/weak_area.dart';
import '../models/test_question.dart';
import '../providers/settings_provider.dart';
import '../providers/weak_areas_provider.dart';
import '../services/claude_service.dart';

enum _TestState { selectArea, loading, inProgress, showResults }

class TestWidget extends ConsumerStatefulWidget {
  const TestWidget({super.key});

  @override
  ConsumerState<TestWidget> createState() => _TestWidgetState();
}

class _TestWidgetState extends ConsumerState<TestWidget> {
  _TestState _state = _TestState.selectArea;
  WeakArea? _selectedArea;
  List<TestQuestion> _questions = [];
  List<int?> _userAnswers = [];
  int _currentQuestion = 0;
  String _feedback = '';
  bool _loadingFeedback = false;
  String? _error;

  Future<void> _startTest(WeakArea area) async {
    setState(() {
      _selectedArea = area;
      _state = _TestState.loading;
      _error = null;
    });
    try {
      final settings = ref.read(settingsProvider);
      final claudeService = ClaudeService();
      final questions = await claudeService.generateTest(area, settings);
      setState(() {
        _questions = questions;
        _userAnswers = List<int?>.filled(questions.length, null);
        _currentQuestion = 0;
        _state = _TestState.inProgress;
      });
    } on ApiKeyMissingException {
      setState(() {
        _error = 'API klíč není nastaven. Přejdi do Nastavení.';
        _state = _TestState.selectArea;
      });
    } catch (e) {
      setState(() {
        _error = 'Chyba načítání testu: $e';
        _state = _TestState.selectArea;
      });
    }
  }

  void _selectAnswer(int index) {
    if (_userAnswers[_currentQuestion] != null) return;
    setState(() {
      _userAnswers[_currentQuestion] = index;
    });
  }

  void _nextQuestion() {
    if (_currentQuestion < _questions.length - 1) {
      setState(() => _currentQuestion++);
    } else {
      _finishTest();
    }
  }

  Future<void> _finishTest() async {
    final score =
        _userAnswers.asMap().entries.where((e) {
          final q = _questions[e.key];
          return e.value == q.correctIndex;
        }).length;

    setState(() {
      _state = _TestState.showResults;
      _loadingFeedback = true;
      _feedback = '';
    });

    try {
      final settings = ref.read(settingsProvider);
      final result = TestResult(
        questions: _questions,
        userAnswers: _userAnswers,
        score: score,
      );
      final claudeService = ClaudeService();
      final feedback = await claudeService.evaluateTest(result, settings);
      setState(() {
        _feedback = feedback;
        _loadingFeedback = false;
      });
    } catch (_) {
      setState(() => _loadingFeedback = false);
    }
  }

  void _resetToAreaSelection() {
    setState(() {
      _state = _TestState.selectArea;
      _selectedArea = null;
      _questions = [];
      _userAnswers = [];
      _currentQuestion = 0;
      _feedback = '';
      _error = null;
    });
  }

  void _retryTest() {
    if (_selectedArea != null) _startTest(_selectedArea!);
  }

  @override
  Widget build(BuildContext context) {
    return switch (_state) {
      _TestState.selectArea => _buildSelectArea(),
      _TestState.loading => _buildLoading(),
      _TestState.inProgress => _buildInProgress(),
      _TestState.showResults => _buildResults(),
    };
  }

  // ---------- State A: Area selection ----------

  Widget _buildSelectArea() {
    final weakAreas = ref.watch(weakAreasProvider);
    final sorted = [...weakAreas]
      ..sort((a, b) => b.occurrences.compareTo(a.occurrences));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.colorRed.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.colorRed.withAlpha(80)),
              ),
              child: Text(_error!,
                  style: const TextStyle(color: AppColors.textPrimary)),
            ),
          ],
          if (sorted.isEmpty)
            _buildEmptyState()
          else ...[
            const Text(
              'Vyber oblast k procvičení',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            ...sorted.map((area) => _buildAreaCard(area)),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.assignment_outlined,
                color: AppColors.textSecondary, size: 56),
            SizedBox(height: 16),
            Text(
              'Zatím žádné oblasti\nk procvičení',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10),
            Text(
              'Nejprve si popovídej\nv Konverzaci a stiskni\nKontrola.',
              style:
                  TextStyle(color: AppColors.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAreaCard(WeakArea area) {
    return GestureDetector(
      onTap: () => _startTest(area),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.accentDim,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.userBubbleBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    area.category,
                    style: const TextStyle(
                        color: AppColors.accentSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    area.description,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.userBubbleBorder,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${area.occurrences}×',
                style: const TextStyle(
                    color: AppColors.accentSecondary, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Loading state ----------

  Widget _buildLoading() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 24),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.accentSecondary,
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
            ),
          ),
        ),
        const SizedBox(height: 20),
        ...List.generate(
          5,
          (_) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.surfaceColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderColor),
            ),
          ),
        ),
      ],
    );
  }

  // ---------- State B: In progress ----------

  Widget _buildInProgress() {
    if (_questions.isEmpty) return const SizedBox();

    final q = _questions[_currentQuestion];
    final answered = _userAnswers[_currentQuestion];
    final isLast = _currentQuestion == _questions.length - 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Progress label
          Text(
            '${_selectedArea?.category ?? ''} — ${_currentQuestion + 1} / ${_questions.length}',
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: (_currentQuestion + 1) / _questions.length,
            backgroundColor: AppColors.borderColor,
            color: AppColors.accentPrimary,
            minHeight: 3,
            borderRadius: BorderRadius.circular(2),
          ),
          const SizedBox(height: 16),
          // Question
          Text(
            q.question,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          // Options
          ...List.generate(q.options.length, (i) {
            final label = String.fromCharCode(65 + i); // A B C D
            Color bg = AppColors.cardColor;
            Color border = AppColors.borderColor;
            Widget? trailingIcon;

            if (answered != null) {
              if (i == q.correctIndex) {
                bg = AppColors.colorGreen.withAlpha(38);
                border = AppColors.colorGreen;
                trailingIcon = const Icon(Icons.check,
                    color: AppColors.colorGreen, size: 16);
              } else if (i == answered) {
                bg = AppColors.colorRed.withAlpha(38);
                border = AppColors.colorRed;
                trailingIcon = const Icon(Icons.close,
                    color: AppColors.colorRed, size: 16);
              }
            }

            return GestureDetector(
              onTap: answered == null ? () => _selectAnswer(i) : null,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: border),
                ),
                child: Row(
                  children: [
                    Text('$label)  ',
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600)),
                    Expanded(
                      child: Text(q.options[i],
                          style: const TextStyle(
                              color: AppColors.textPrimary)),
                    ),
                    ?trailingIcon,
                  ],
                ),
              ),
            );
          }),
          // Explanation + next button
          if (answered != null) ...[
            const SizedBox(height: 12),
            if (q.explanation.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.borderColor),
                ),
                child: Text(
                  q.explanation,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13),
                ),
              ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _nextQuestion,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              child: Text(isLast ? 'Zobrazit výsledky' : 'Další otázka →'),
            ),
          ],
        ],
      ),
    );
  }

  // ---------- State C: Results ----------

  Widget _buildResults() {
    final score = _userAnswers.asMap().entries
        .where((e) => e.value == _questions[e.key].correctIndex)
        .length;
    final total = _questions.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Center(
            child: Text(
              '$score / $total',
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 48,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          Center(child: _buildStars(score, total)),
          const SizedBox(height: 20),
          if (_loadingFeedback)
            const Center(
                child: CircularProgressIndicator(
                    color: AppColors.accentPrimary, strokeWidth: 2))
          else if (_feedback.isNotEmpty)
            Text(
              _feedback,
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 28),
          OutlinedButton(
            onPressed: _retryTest,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accentPrimary,
              side: const BorderSide(color: AppColors.accentPrimary),
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
            child: const Text('Zkusit znovu'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _resetToAreaSelection,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.borderColor),
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
            child: const Text('Vybrat jinou oblast'),
          ),
        ],
      ),
    );
  }

  Widget _buildStars(int score, int total) {
    final stars = total > 0 ? (score / total * 5).round() : 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Text(
          i < stars ? '⭐' : '☆',
          style: const TextStyle(fontSize: 24),
        );
      }),
    );
  }
}
