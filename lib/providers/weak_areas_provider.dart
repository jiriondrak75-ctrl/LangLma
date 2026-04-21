import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/weak_area.dart';
import '../models/user_settings.dart';
import '../services/ai_service.dart';
import 'settings_provider.dart';
import 'ai_service_provider.dart';

class WeakAreasNotifier extends StateNotifier<List<WeakArea>> {
  final Ref _ref;
  String? _currentKey;

  WeakAreasNotifier(this._ref) : super([]) {
    _init();
  }

  Future<void> _init() async {
    final settings = _ref.read(settingsProvider);
    _currentKey = _keyFor(settings.targetLanguage);
    await _load(_currentKey!);
  }

  String _keyFor(Language lang) => 'weak_areas_${lang.name}';

  Future<void> _load(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) {
      state = [];
      return;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      state = list
          .map((e) => WeakArea.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      state = [];
    }
  }

  Future<void> _save(String key, List<WeakArea> areas) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        key, jsonEncode(areas.map((e) => e.toJson()).toList()));
  }

  Future<void> switchLanguage(Language lang) async {
    _currentKey = _keyFor(lang);
    await _load(_currentKey!);
  }

  void incrementProgress(String weakAreaId) {
    final updated = state.map((area) {
      if (area.id != weakAreaId) return area;
      final newProgress = (area.masteryProgress + 10).clamp(0, 100);
      return area.copyWith(masteryProgress: newProgress);
    }).toList();

    final filtered = updated.where((a) => a.masteryProgress < 100).toList();
    state = filtered;
    if (_currentKey != null) _save(_currentKey!, filtered);
  }

  Future<void> updateFromAnalysis(AnalysisResult analysis) async {
    try {
      final settings = _ref.read(settingsProvider);
      final aiService = _ref.read(aiServiceProvider);
      final updated =
          await aiService.extractWeakAreas(analysis, state, settings);
      _currentKey ??= _keyFor(settings.targetLanguage);
      await _save(_currentKey!, updated);
      state = updated;
    } catch (e) {
      debugPrint('extractWeakAreas failed: $e');
    }
  }
}

final weakAreasProvider =
    StateNotifierProvider<WeakAreasNotifier, List<WeakArea>>(
        (ref) => WeakAreasNotifier(ref));
