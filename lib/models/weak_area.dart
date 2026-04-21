import 'package:uuid/uuid.dart';

class WeakArea {
  final String id;
  final String category;
  final String description;
  final int occurrences;
  final DateTime lastSeen;
  final int masteryProgress; // 0–100

  const WeakArea({
    required this.id,
    required this.category,
    required this.description,
    required this.occurrences,
    required this.lastSeen,
    this.masteryProgress = 0,
  });

  WeakArea copyWith({
    String? id,
    String? category,
    String? description,
    int? occurrences,
    DateTime? lastSeen,
    int? masteryProgress,
  }) =>
      WeakArea(
        id: id ?? this.id,
        category: category ?? this.category,
        description: description ?? this.description,
        occurrences: occurrences ?? this.occurrences,
        lastSeen: lastSeen ?? this.lastSeen,
        masteryProgress: masteryProgress ?? this.masteryProgress,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'description': description,
        'occurrences': occurrences,
        'lastSeen': lastSeen.toIso8601String(),
        'masteryProgress': masteryProgress,
      };

  factory WeakArea.fromJson(Map<String, dynamic> json) => WeakArea(
        id: (json['id'] as String?)?.isNotEmpty == true
            ? json['id'] as String
            : const Uuid().v4(),
        category: json['category'] as String? ?? '',
        description: json['description'] as String? ?? '',
        occurrences: json['occurrences'] as int? ?? 1,
        lastSeen: DateTime.tryParse(json['lastSeen'] as String? ?? '') ??
            DateTime.now(),
        masteryProgress:
            ((json['masteryProgress'] as int?) ?? 0).clamp(0, 100),
      );
}
