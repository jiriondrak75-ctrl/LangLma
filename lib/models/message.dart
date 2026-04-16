import 'package:uuid/uuid.dart';

enum MessageRole { user, assistant }

enum MessageType { text, voice }

class Message {
  final String id;
  final MessageRole role;
  final String content;
  final MessageType type;
  final DateTime timestamp;

  Message({
    String? id,
    required this.role,
    required this.content,
    this.type = MessageType.text,
    DateTime? timestamp,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toApiMap() => {
        'role': role == MessageRole.user ? 'user' : 'assistant',
        'content': content,
      };
}
