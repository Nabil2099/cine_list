import 'package:equatable/equatable.dart';

/// Single chat message in the CineList AI conversation.
class ChatMessageModel extends Equatable {
  const ChatMessageModel({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
  });

  factory ChatMessageModel.fromMap(Map<String, dynamic> map) {
    return ChatMessageModel(
      id: (map['id'] as String?) ?? '',
      text: (map['text'] as String?) ?? '',
      isUser: map['isUser'] == true,
      timestamp:
          DateTime.tryParse((map['timestamp'] as String?) ?? '') ??
          DateTime.now(),
      isError: map['isError'] == true,
    );
  }

  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;

  ChatMessageModel copyWith({String? text, bool? isError}) {
    return ChatMessageModel(
      id: id,
      text: text ?? this.text,
      isUser: isUser,
      timestamp: timestamp,
      isError: isError ?? this.isError,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'text': text,
    'isUser': isUser,
    'timestamp': timestamp.toIso8601String(),
    'isError': isError,
  };

  @override
  List<Object?> get props => [id, text, isUser, timestamp, isError];
}
