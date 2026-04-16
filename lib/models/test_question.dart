class TestQuestion {
  final String id;
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final String weakAreaCategory;

  const TestQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    required this.weakAreaCategory,
  });

  factory TestQuestion.fromJson(Map<String, dynamic> json) => TestQuestion(
        id: json['id'] as String? ?? '',
        question: json['question'] as String? ?? '',
        options: List<String>.from(json['options'] ?? []),
        correctIndex: ((json['correctIndex'] as int?) ?? 0).clamp(0, 3),
        explanation: json['explanation'] as String? ?? '',
        weakAreaCategory: json['weakAreaCategory'] as String? ?? '',
      );
}

class TestResult {
  final List<TestQuestion> questions;
  final List<int?> userAnswers;
  final int score;
  final String feedback;

  const TestResult({
    required this.questions,
    required this.userAnswers,
    this.score = 0,
    this.feedback = '',
  });

  TestResult copyWith({
    List<int?>? userAnswers,
    int? score,
    String? feedback,
  }) =>
      TestResult(
        questions: questions,
        userAnswers: userAnswers ?? this.userAnswers,
        score: score ?? this.score,
        feedback: feedback ?? this.feedback,
      );
}
