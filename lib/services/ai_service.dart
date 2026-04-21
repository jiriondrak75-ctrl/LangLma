import '../models/message.dart';
import '../models/user_settings.dart';
import '../models/weak_area.dart';
import '../models/test_question.dart';

// ---------- Shared model classes ----------

class AnalysisError {
  final String original;
  final String correction;
  final String explanation;

  AnalysisError({
    required this.original,
    required this.correction,
    required this.explanation,
  });

  factory AnalysisError.fromJson(Map<String, dynamic> json) => AnalysisError(
        original: json['original'] ?? '',
        correction: json['correction'] ?? '',
        explanation: json['explanation'] ?? '',
      );
}

class AnalysisResult {
  final List<AnalysisError> errors;
  final List<String> tips;
  final List<String> exercises;
  final String summary;
  final String? rawText;

  AnalysisResult({
    required this.errors,
    required this.tips,
    required this.exercises,
    required this.summary,
    this.rawText,
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> json) => AnalysisResult(
        errors: (json['errors'] as List<dynamic>? ?? [])
            .map((e) => AnalysisError.fromJson(e as Map<String, dynamic>))
            .toList(),
        tips: List<String>.from(json['tips'] ?? []),
        exercises: List<String>.from(json['exercises'] ?? []),
        summary: json['summary'] ?? '',
      );

  factory AnalysisResult.fromRaw(String raw) => AnalysisResult(
        errors: [],
        tips: [],
        exercises: [],
        summary: '',
        rawText: raw,
      );
}

class TranslationChallenge {
  final String original;
  final String language;
  final String? hint;

  TranslationChallenge({
    required this.original,
    required this.language,
    this.hint,
  });

  factory TranslationChallenge.fromJson(Map<String, dynamic> json) =>
      TranslationChallenge(
        original: json['original'] as String? ?? '',
        language: json['language'] as String? ?? 'cs',
        hint: json['hint'] as String?,
      );
}

class TranslationEvaluation {
  final bool correct;
  final int score;
  final String idealTranslation;
  final String feedback;
  final List<String> errors;

  TranslationEvaluation({
    required this.correct,
    required this.score,
    required this.idealTranslation,
    required this.feedback,
    required this.errors,
  });

  factory TranslationEvaluation.fromJson(Map<String, dynamic> json) =>
      TranslationEvaluation(
        correct: json['correct'] as bool? ?? false,
        score: json['score'] as int? ?? 0,
        idealTranslation: json['idealTranslation'] as String? ?? '',
        feedback: json['feedback'] as String? ?? '',
        errors: List<String>.from(json['errors'] ?? []),
      );
}

// ---------- Exceptions ----------

class ApiKeyMissingException implements Exception {
  final String message;
  ApiKeyMissingException([String provider = 'API'])
      : message = '$provider klíč není nastaven. Přejdi do Nastavení.';
}

class GemmaNotReadyException implements Exception {
  final String message =
      'Model Gemma není připraven. Nejprve ho stáhni v Nastavení.';
}

// ---------- Abstract interface ----------

abstract class AiService {
  Future<String> sendMessage(
    List<Message> history,
    UserSettings settings,
  );

  Future<AnalysisResult> analyzeConversation(
    List<Message> history,
    UserSettings settings,
  );

  Future<List<WeakArea>> extractWeakAreas(
    AnalysisResult analysis,
    List<WeakArea> existing,
    UserSettings settings,
  );

  Future<TranslationChallenge> getTranslationChallenge(
    String direction,
    List<Message> history,
    UserSettings settings,
  );

  Future<TranslationEvaluation> evaluateTranslation(
    String original,
    String userTranslation,
    String direction,
    UserSettings settings,
  );

  Future<List<TestQuestion>> generateTest(
    WeakArea area,
    UserSettings settings,
  );

  Future<String> evaluateTest(
    TestResult result,
    UserSettings settings,
  );
}

// ---------- Shared JSON helper ----------

String stripMarkdownJson(String text) {
  final trimmed = text.trim();
  final match =
      RegExp(r'^```(?:json)?\s*([\s\S]*?)\s*```$').firstMatch(trimmed);
  return match != null ? match.group(1)! : trimmed;
}
