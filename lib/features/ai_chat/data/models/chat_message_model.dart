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

  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;

  @override
  List<Object?> get props => [id, text, isUser, timestamp, isError];
}
