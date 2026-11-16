import 'package:equatable/equatable.dart';

import '../../data/models/chat_message_model.dart';

class AiChatState extends Equatable {
  const AiChatState({this.messages = const [], this.isSending = false});

  final List<ChatMessageModel> messages;
  final bool isSending;

  AiChatState copyWith({List<ChatMessageModel>? messages, bool? isSending}) {
    return AiChatState(
      messages: messages ?? this.messages,
      isSending: isSending ?? this.isSending,
    );
  }

  @override
  List<Object?> get props => [messages, isSending];
}
