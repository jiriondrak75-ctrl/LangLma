import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message.dart';
import '../models/user_settings.dart';
import '../models/weak_area.dart';
import '../models/test_question.dart';
import 'ai_service.dart';

class ClaudeAiService implements AiService {
  static const _baseUrl = 'https://api.anthropic.com/v1/messages';
  static const _model = 'claude-opus-4-5';
  final _storage = const FlutterSecureStorage();

  Future<String?> _getApiKey() async {
    // Try SharedPreferences first (works reliably on all platforms including web)
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = prefs.getString('api_key_fallback');
      if (key != null && key.isNotEmpty) return key;
    } catch (_) {}
    // Fallback: secure storage
    try {
      final key = await _storage.read(key: 'claude_api_key');
      if (key != null && key.isNotEmpty) return key;
    } catch (_) {}
    return null;
  }

  String _extractText(dynamic responseData) {
    dynamic data = responseData;
    if (data is String) data = jsonDecode(data);
    if (data is! Map) {
      throw Exception('Unexpected response type: ${data.runtimeType}: $data');
    }
    final content = data['content'];
    if (content == null || content is! List || content.isEmpty) {
      throw Exception('Empty content in response: $data');
    }
    final first = content.first;
    if (first is! Map || first['text'] == null) {
      throw Exception('No text in content block: $content');
    }
    return first['text'] as String;
  }

  Dio _buildDio(String apiKey) {
    final dio = Dio();
    dio.options.headers = {
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01',
      'content-type': 'application/json',
      'anthropic-dangerous-direct-browser-access': 'true',
    };
    return dio;
  }

  // ---------- sendMessage ----------

  @override
  Future<String> sendMessage(
      List<Message> history, UserSettings settings) async {
    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) throw ApiKeyMissingException('Claude');

    final systemPrompt = '''
You are a ${settings.targetLanguage.englishName} language teacher.
Your student's name is ${settings.name.isEmpty ? 'the student' : settings.name}, they are ${settings.gender}.
Their native language is Czech.
Their current level is ${settings.level.apiName} (beginner/elementary/intermediate/advanced).
Teaching style: ${settings.teachingStyle}.

Rules:
- Always respond ONLY in ${settings.targetLanguage.englishName}, never in Czech
- Keep responses natural and conversational, 2-4 sentences max
- Adapt vocabulary and grammar complexity to the student's level
- Do NOT explicitly correct errors during conversation — just continue naturally
- Occasionally ask follow-up questions to keep conversation flowing
- Be encouraging and patient''';

    final response = await _buildDio(apiKey).post(
      _baseUrl,
      data: {
        'model': _model,
        'max_tokens': 1024,
        'system': systemPrompt,
        'messages': history.map((m) => m.toApiMap()).toList(),
      },
    );
    return _extractText(response.data);
  }

  // ---------- analyzeConversation ----------

  @override
  Future<AnalysisResult> analyzeConversation(
      List<Message> history, UserSettings settings) async {
    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) throw ApiKeyMissingException('Claude');

    final systemPrompt = '''
You are a strict but supportive ${settings.targetLanguage.englishName} language teacher
analyzing a conversation with your student ${settings.name.isEmpty ? 'the student' : settings.name} (level: ${settings.level.apiName}).

Analyze the student's messages only (not yours).
IMPORTANT: Messages may have been transcribed from speech-to-text, so do NOT flag missing capitalization or punctuation as errors.
Respond in Czech. Structure your response as JSON:
{
  "errors": [{"original": "...", "correction": "...", "explanation": "..."}],
  "tips": ["..."],
  "exercises": ["..."],
  "summary": "..."
}
Return ONLY valid JSON, no markdown, no extra text.''';

    final userMessages = history
        .where((m) => m.role == MessageRole.user)
        .map((m) => '- "${m.content}"')
        .join('\n');

    final response = await _buildDio(apiKey).post(
      _baseUrl,
      data: {
        'model': _model,
        'max_tokens': 2048,
        'system': systemPrompt,
        'messages': [
          {
            'role': 'user',
            'content':
                'Here are the student\'s messages:\n$userMessages\n\nAnalyze and return JSON only.',
          }
        ],
      },
    );

    final rawText = _extractText(response.data);
    try {
      final cleaned = stripMarkdownJson(rawText);
      final json = jsonDecode(cleaned) as Map<String, dynamic>;
      return AnalysisResult.fromJson(json);
    } catch (_) {
      return AnalysisResult.fromRaw(rawText);
    }
  }

  // ---------- extractWeakAreas ----------

  @override
  Future<List<WeakArea>> extractWeakAreas(AnalysisResult analysis,
      List<WeakArea> existing, UserSettings settings) async {
    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) throw ApiKeyMissingException('Claude');

    final existingJson = jsonEncode(existing.map((e) => e.toJson()).toList());
    final analysisText = [
      if (analysis.errors.isNotEmpty)
        'Errors: ${analysis.errors.map((e) => '${e.original} → ${e.correction}: ${e.explanation}').join('; ')}',
      if (analysis.tips.isNotEmpty) 'Tips: ${analysis.tips.join('; ')}',
      if (analysis.summary.isNotEmpty) 'Summary: ${analysis.summary}',
      if (analysis.rawText != null) analysis.rawText!,
    ].join('\n');

    final systemPrompt = '''
You are analyzing language learning data.
Based on the provided analysis result, extract recurring weak areas.
Current existing weak areas (JSON): $existingJson

Return ONLY valid JSON array, max 10 items total (merge with existing,
increment occurrences for repeating issues, add new ones, remove least
frequent if over 10):
[{"id":"uuid","category":"short category in Czech (max 4 words)","description":"brief description in Czech (1 sentence)","occurrences":1,"lastSeen":"ISO8601 datetime"}]

No markdown, no extra text. Only JSON array.''';

    final response = await _buildDio(apiKey).post(
      _baseUrl,
      data: {
        'model': _model,
        'max_tokens': 512,
        'system': systemPrompt,
        'messages': [
          {'role': 'user', 'content': 'Analysis result:\n$analysisText'}
        ],
      },
    );

    final rawText = _extractText(response.data);
    final cleaned = stripMarkdownJson(rawText);
    final list = jsonDecode(cleaned) as List<dynamic>;
    return list
        .map((e) => WeakArea.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---------- getTranslationChallenge ----------

  @override
  Future<TranslationChallenge> getTranslationChallenge(
      String direction, List<Message> history, UserSettings settings) async {
    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) throw ApiKeyMissingException('Claude');

    final historyHint = history.isNotEmpty
        ? 'Recent topics to avoid: ${history.take(10).map((m) => m.content).join('; ')}'
        : '';

    final directionInstruction = direction == 'toTarget'
        ? 'Give a Czech sentence to translate into ${settings.targetLanguage.englishName}.'
        : 'Give a ${settings.targetLanguage.englishName} sentence to translate into Czech.';

    final systemPrompt = '''
You are a ${settings.targetLanguage.englishName} language teacher giving translation exercises.
Student level: ${settings.level.apiName}. Native language: Czech.

Generate ONE sentence appropriate for the student's level.
Direction: $directionInstruction
Vary topics: daily life, travel, work, hobbies, current events.
$historyHint

Return ONLY valid JSON:
{"original":"sentence to translate","language":"${direction == 'toTarget' ? 'cs' : settings.targetLanguage.locale}","hint":"optional grammar hint in Czech or null"}
No markdown, no extra text.''';

    final response = await _buildDio(apiKey).post(
      _baseUrl,
      data: {
        'model': _model,
        'max_tokens': 256,
        'system': systemPrompt,
        'messages': [
          {'role': 'user', 'content': 'Generate a translation exercise.'}
        ],
      },
    );

    final rawText = _extractText(response.data);
    final cleaned = stripMarkdownJson(rawText);
    final json = jsonDecode(cleaned) as Map<String, dynamic>;
    return TranslationChallenge.fromJson(json);
  }

  // ---------- evaluateTranslation ----------

  @override
  Future<TranslationEvaluation> evaluateTranslation(String original,
      String userTranslation, String direction, UserSettings settings) async {
    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) throw ApiKeyMissingException('Claude');

    final systemPrompt = '''
You are a ${settings.targetLanguage.englishName} language teacher evaluating a translation.
Student level: ${settings.level.apiName}.
Original: "$original"
Student's translation: "$userTranslation"
Direction: ${direction == 'toTarget' ? 'Czech → ${settings.targetLanguage.englishName}' : '${settings.targetLanguage.englishName} → Czech'}

Return ONLY valid JSON:
{"correct":true/false,"score":0-100,"idealTranslation":"best translation","feedback":"brief feedback in Czech, 1-2 sentences","errors":["list of errors in Czech or empty array"]}
No markdown, no extra text.''';

    final response = await _buildDio(apiKey).post(
      _baseUrl,
      data: {
        'model': _model,
        'max_tokens': 512,
        'system': systemPrompt,
        'messages': [
          {'role': 'user', 'content': 'Evaluate the translation.'}
        ],
      },
    );

    final rawText = _extractText(response.data);
    final cleaned = stripMarkdownJson(rawText);
    final json = jsonDecode(cleaned) as Map<String, dynamic>;
    return TranslationEvaluation.fromJson(json);
  }

  // ---------- generateTest ----------

  @override
  Future<List<TestQuestion>> generateTest(
      WeakArea selectedArea, UserSettings settings) async {
    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) throw ApiKeyMissingException('Claude');

    final systemPrompt = '''
You are a ${settings.targetLanguage.englishName} language teacher creating a multiple choice test.
Student: ${settings.name.isEmpty ? 'the student' : settings.name}, level: ${settings.level.apiName}.
Focus area: ${selectedArea.category} — ${selectedArea.description}

Generate exactly 5 multiple choice questions targeting this weak area.
Each question must have exactly 4 options (A/B/C/D), only one correct.
IMPORTANT: Each question must be clearly different — vary the sentence structure, vocabulary, context, and grammar patterns.

Return ONLY valid JSON array:
[{"id":"uuid","question":"question in ${settings.targetLanguage.englishName}","options":["A","B","C","D"],"correctIndex":0,"explanation":"why correct — in Czech","weakAreaCategory":"${selectedArea.category}"}]
No markdown, no extra text.''';

    final response = await _buildDio(apiKey).post(
      _baseUrl,
      data: {
        'model': _model,
        'max_tokens': 2048,
        'system': systemPrompt,
        'messages': [
          {'role': 'user', 'content': 'Generate the test questions.'}
        ],
      },
    );

    final rawText = _extractText(response.data);
    final cleaned = stripMarkdownJson(rawText);
    final list = jsonDecode(cleaned) as List<dynamic>;
    return list
        .map((e) => TestQuestion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---------- evaluateTest ----------

  @override
  Future<String> evaluateTest(TestResult result, UserSettings settings) async {
    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) throw ApiKeyMissingException('Claude');

    final category = result.questions.isNotEmpty
        ? result.questions.first.weakAreaCategory
        : '';

    final systemPrompt = '''
You are a ${settings.targetLanguage.englishName} language teacher evaluating a test.
Student: ${settings.name.isEmpty ? 'the student' : settings.name}, level: ${settings.level.apiName}.
Score: ${result.score}/5. Focus area: $category
Write encouraging but honest overall feedback in Czech, 2-3 sentences.
Return ONLY a plain string (no JSON, no markdown).''';

    final response = await _buildDio(apiKey).post(
      _baseUrl,
      data: {
        'model': _model,
        'max_tokens': 512,
        'system': systemPrompt,
        'messages': [
          {'role': 'user', 'content': 'Provide feedback on the test.'}
        ],
      },
    );

    return _extractText(response.data);
  }
}
