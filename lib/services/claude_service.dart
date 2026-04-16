import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message.dart';
import '../models/user_settings.dart';

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

class ClaudeService {
  static const _baseUrl = 'https://api.anthropic.com/v1/messages';
  static const _model = 'claude-opus-4-5';
  final _storage = const FlutterSecureStorage();

  Future<String?> _getApiKey() async {
    // Check SharedPreferences first (always reliable, written by saveApiKey)
    final prefs = await SharedPreferences.getInstance();
    final fallback = prefs.getString('api_key_fallback');
    if (fallback != null && fallback.isNotEmpty) return fallback;
    // Try secure storage as secondary source
    try {
      final key = await _storage.read(key: 'claude_api_key');
      if (key != null && key.isNotEmpty) return key;
    } catch (_) {}
    return null;
  }

  String _stripMarkdownJson(String text) {
    final trimmed = text.trim();
    // Strip ```json ... ``` or ``` ... ``` wrappers
    final match = RegExp(r'^```(?:json)?\s*([\s\S]*?)\s*```$').firstMatch(trimmed);
    return match != null ? match.group(1)! : trimmed;
  }

  String _extractText(dynamic responseData) {
    // On Flutter web, Dio may return data as a raw String instead of a decoded Map
    dynamic data = responseData;
    if (data is String) {
      data = jsonDecode(data);
    }
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
    };
    return dio;
  }

  Future<String> sendMessage(
      List<Message> history, UserSettings settings) async {
    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw ApiKeyMissingException();
    }

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

    final messages = history
        .map((m) => m.toApiMap())
        .toList();

    final response = await _buildDio(apiKey).post(
      _baseUrl,
      data: {
        'model': _model,
        'max_tokens': 1024,
        'system': systemPrompt,
        'messages': messages,
      },
    );

    return _extractText(response.data);
  }

  Future<AnalysisResult> analyzeConversation(
      List<Message> history, UserSettings settings) async {
    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw ApiKeyMissingException();
    }

    final systemPrompt = '''
You are a strict but supportive ${settings.targetLanguage.englishName} language teacher
analyzing a conversation with your student ${settings.name.isEmpty ? 'the student' : settings.name} (level: ${settings.level.apiName}).

Analyze the student's messages only (not yours).
Respond in Czech. Structure your response as JSON:
{
  "errors": [
    {
      "original": "original wrong text",
      "correction": "correct version",
      "explanation": "vysvětlení chyby česky"
    }
  ],
  "tips": [
    "tip na zlepšení česky"
  ],
  "exercises": [
    "procvičovací otázka nebo úkol česky v cílovém jazyce"
  ],
  "summary": "celkové hodnocení česky, 1-2 věty"
}

Return ONLY valid JSON, no markdown, no extra text.''';

    // Send only user messages as quoted text — avoids model confusion
    // from multi-turn conversation history
    final userMessages = history
        .where((m) => m.role == MessageRole.user)
        .map((m) => '- "${m.content}"')
        .join('\n');

    final analysisMessages = [
      {
        'role': 'user',
        'content':
            'Here are the student\'s messages from our conversation:\n$userMessages\n\nPlease analyze them and return JSON only.',
      }
    ];

    final response = await _buildDio(apiKey).post(
      _baseUrl,
      data: {
        'model': _model,
        'max_tokens': 2048,
        'system': systemPrompt,
        'messages': analysisMessages,
      },
    );

    final rawText = _extractText(response.data);

    try {
      final cleaned = _stripMarkdownJson(rawText);
      final json = jsonDecode(cleaned) as Map<String, dynamic>;
      return AnalysisResult.fromJson(json);
    } catch (_) {
      return AnalysisResult.fromRaw(rawText);
    }
  }
}

class ApiKeyMissingException implements Exception {
  final String message = 'API klíč není nastaven. Přejdi do Nastavení.';
}
