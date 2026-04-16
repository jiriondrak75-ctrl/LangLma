import 'package:uuid/uuid.dart';

class WeakArea {
  final String id;
  final String category;
  final String description;
  final int occurrences;
  final DateTime lastSeen;

  const WeakArea({
    required this.id,
    required this.category,
    required this.description,
    required this.occurrences,
    required this.lastSeen,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'description': description,
        'occurrences': occurrences,
        'lastSeen': lastSeen.toIso8601String(),
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
      );
}
