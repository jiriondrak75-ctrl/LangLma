import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message.dart';
import '../models/user_settings.dart';
import '../models/weak_area.dart';
import '../models/test_question.dart';
import 'ai_service.dart';

class GeminiAiService implements AiService {
  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';
  final _storage = const FlutterSecureStorage();

  Future<String?> _getApiKey() async {
    // Try SharedPreferences first (works reliably on all platforms including web)
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = prefs.getString('gemini_api_key_fallback');
      if (key != null && key.isNotEmpty) return key;
    } catch (_) {}
    // Fallback: secure storage
    try {
      final key = await _storage.read(key: 'gemini_api_key');
      if (key != null && key.isNotEmpty) return key;
    } catch (_) {}
    return null;
  }

  Dio _buildDio(String apiKey) {
    final dio = Dio();
    // Don't throw on 4xx — let _extractText surface the API error message
    dio.options.validateStatus = (status) => status != null && status < 500;
    // Keys starting with 'AIza' → query-param API key
    // Keys starting with 'AQ.' or 'ya29.' → OAuth2 Bearer token
    if (apiKey.startsWith('AIza')) {
      dio.options.headers = {'content-type': 'application/json'};
    } else {
      dio.options.headers = {
        'content-type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      };
    }
    return dio;
  }

  String _extractText(dynamic responseData) {
    dynamic data = responseData;
    if (data is String) data = jsonDecode(data);
    if (data is! Map) throw Exception('Unexpected Gemini response: $data');

    // Surface API-level errors clearly
    if (data['error'] != null) {
      final err = data['error'];
      final msg = err['message'] ?? err.toString();
      throw Exception('Gemini API error: $msg');
    }

    final candidates = data['candidates'];
    if (candidates == null || candidates is! List || candidates.isEmpty) {
      throw Exception('No candidates in Gemini response: $data');
    }
    final content = candidates.first['content'];
    if (content == null) throw Exception('No content in Gemini candidate');
    final parts = content['parts'];
    if (parts == null || parts is! List || parts.isEmpty) {
      throw Exception('No parts in Gemini content');
    }
    return parts.first['text'] as String;
  }

  /// Convert conversation history to Gemini `contents` format.
  /// Gemini uses "user" / "model" roles.
  List<Map<String, dynamic>> _toContents(List<Message> history) {
    return history
        .map((m) => {
              'role': m.role == MessageRole.user ? 'user' : 'model',
              'parts': [
                {'text': m.content}
              ],
            })
        .toList();
  }

  Future<String> _post(
    String apiKey, {
    required String systemPrompt,
    required List<Map<String, dynamic>> contents,
    int maxTokens = 1024,
  }) async {
    // OAuth2 Bearer tokens go in header — no key in URL
    final url = apiKey.startsWith('AIza')
        ? '$_baseUrl?key=$apiKey'
        : _baseUrl;
    final response = await _buildDio(apiKey).post(
      url,
      data: {
        'system_instruction': {
          'parts': [
            {'text': systemPrompt}
          ]
        },
        'contents': contents,
        'generationConfig': {'maxOutputTokens': maxTokens},
      },
    );
    return _extractText(response.data);
  }

  // ---------- sendMessage ----------

  @override
  Future<String> sendMessage(
      List<Message> history, UserSettings settings) async {
    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) throw ApiKeyMissingException('Gemini');

    final systemPrompt = '''
You are a ${settings.targetLanguage.englishName} language teacher.
Your student's name is ${settings.name.isEmpty ? 'the student' : settings.name}, they are ${settings.gender}.
Their native language is Czech.
Their current level is ${settings.level.apiName}.
Teaching style: ${settings.teachingStyle}.

Rules:
- Always respond ONLY in ${settings.targetLanguage.englishName}, never in Czech
- Keep responses natural and conversational, 2-4 sentences max
- Adapt vocabulary and grammar complexity to the student's level
- Do NOT explicitly correct errors during conversation — just continue naturally
- Occasionally ask follow-up questions to keep conversation flowing
- Be encouraging and patient''';

    return _post(apiKey,
        systemPrompt: systemPrompt,
        contents: _toContents(history),
        maxTokens: 1024);
  }

  // ---------- analyzeConversation ----------

  @override
  Future<AnalysisResult> analyzeConversation(
      List<Message> history, UserSettings settings) async {
    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) throw ApiKeyMissingException('Gemini');

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

    final rawText = await _post(apiKey,
        systemPrompt: systemPrompt,
        contents: [
          {
            'role': 'user',
            'parts': [
              {
                'text':
                    'Here are the student\'s messages:\n$userMessages\n\nAnalyze and return JSON only.'
              }
            ]
          }
        ],
        maxTokens: 2048);

    try {
      final cleaned = stripMarkdownJson(rawText);
      return AnalysisResult.fromJson(jsonDecode(cleaned) as Map<String, dynamic>);
    } catch (_) {
      return AnalysisResult.fromRaw(rawText);
    }
  }

  // ---------- extractWeakAreas ----------

  @override
  Future<List<WeakArea>> extractWeakAreas(AnalysisResult analysis,
      List<WeakArea> existing, UserSettings settings) async {
    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) throw ApiKeyMissingException('Gemini');

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
increment occurrences for repeating issues, add new ones):
[{"id":"uuid","category":"short category in Czech (max 4 words)","description":"brief description in Czech (1 sentence)","occurrences":1,"lastSeen":"ISO8601 datetime"}]

No markdown, no extra text. Only JSON array.''';

    final rawText = await _post(apiKey,
        systemPrompt: systemPrompt,
        contents: [
          {
            'role': 'user',
            'parts': [
              {'text': 'Analysis result:\n$analysisText'}
            ]
          }
        ],
        maxTokens: 512);

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
    if (apiKey == null || apiKey.isEmpty) throw ApiKeyMissingException('Gemini');

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

    final rawText = await _post(apiKey,
        systemPrompt: systemPrompt,
        contents: [
          {
            'role': 'user',
            'parts': [
              {'text': 'Generate a translation exercise.'}
            ]
          }
        ],
        maxTokens: 256);

    final cleaned = stripMarkdownJson(rawText);
    return TranslationChallenge.fromJson(
        jsonDecode(cleaned) as Map<String, dynamic>);
  }

  // ---------- evaluateTranslation ----------

  @override
  Future<TranslationEvaluation> evaluateTranslation(String original,
      String userTranslation, String direction, UserSettings settings) async {
    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) throw ApiKeyMissingException('Gemini');

    final systemPrompt = '''
You are a ${settings.targetLanguage.englishName} language teacher evaluating a translation.
Student level: ${settings.level.apiName}.
Original: "$original"
Student's translation: "$userTranslation"
Direction: ${direction == 'toTarget' ? 'Czech → ${settings.targetLanguage.englishName}' : '${settings.targetLanguage.englishName} → Czech'}

Return ONLY valid JSON:
{"correct":true/false,"score":0-100,"idealTranslation":"best translation","feedback":"brief feedback in Czech, 1-2 sentences","errors":["list of errors in Czech or empty array"]}
No markdown, no extra text.''';

    final rawText = await _post(apiKey,
        systemPrompt: systemPrompt,
        contents: [
          {
            'role': 'user',
            'parts': [
              {'text': 'Evaluate the translation.'}
            ]
          }
        ],
        maxTokens: 512);

    final cleaned = stripMarkdownJson(rawText);
    return TranslationEvaluation.fromJson(
        jsonDecode(cleaned) as Map<String, dynamic>);
  }

  // ---------- generateTest ----------

  @override
  Future<List<TestQuestion>> generateTest(
      WeakArea selectedArea, UserSettings settings) async {
    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) throw ApiKeyMissingException('Gemini');

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

    final rawText = await _post(apiKey,
        systemPrompt: systemPrompt,
        contents: [
          {
            'role': 'user',
            'parts': [
              {'text': 'Generate the test questions.'}
            ]
          }
        ],
        maxTokens: 2048);

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
    if (apiKey == null || apiKey.isEmpty) throw ApiKeyMissingException('Gemini');

    final category = result.questions.isNotEmpty
        ? result.questions.first.weakAreaCategory
        : '';

    final systemPrompt = '''
You are a ${settings.targetLanguage.englishName} language teacher evaluating a test.
Student: ${settings.name.isEmpty ? 'the student' : settings.name}, level: ${settings.level.apiName}.
Score: ${result.score}/5. Focus area: $category
Write encouraging but honest overall feedback in Czech, 2-3 sentences.
Return ONLY a plain string (no JSON, no markdown).''';

    return _post(apiKey,
        systemPrompt: systemPrompt,
        contents: [
          {
            'role': 'user',
            'parts': [
              {'text': 'Provide feedback on the test.'}
            ]
          }
        ],
        maxTokens: 512);
  }
}
