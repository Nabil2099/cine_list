import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/app_exception.dart';
import '../../../watchlist/data/models/watchlist_movie_model.dart';
import '../../data/models/chat_message_model.dart';
import '../../data/repositories/ai_chat_repository.dart';
import 'ai_chat_state.dart';

/// Manages CineList AI chatbot conversation and watchlist-grounded prompts.
class AiChatCubit extends Cubit<AiChatState> {
  AiChatCubit(this._repository) : super(const AiChatState());

  final AiChatRepository _repository;

  Future<void> sendMessage(
    String rawText, {
    required List<WatchlistMovieModel> watchlist,
  }) async {
    final text = rawText.trim();
    if (text.isEmpty || state.isSending) return;

    final userMessage = ChatMessageModel(
      id: 'user-${DateTime.now().microsecondsSinceEpoch}',
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );

    final updatedHistory = [...state.messages, userMessage];
    emit(state.copyWith(messages: updatedHistory, isSending: true));

    try {
      final reply = await _repository.sendMessage(
        history: updatedHistory,
        watchlist: watchlist,
      );

      if (isClosed) return;
      final aiMessage = ChatMessageModel(
        id: 'ai-${DateTime.now().microsecondsSinceEpoch}',
        text: reply,
        isUser: false,
        timestamp: DateTime.now(),
      );

      emit(
        state.copyWith(
          messages: [...updatedHistory, aiMessage],
          isSending: false,
        ),
      );
    } on AppException catch (e) {
      if (isClosed) return;
      final errorBubble = ChatMessageModel(
        id: 'err-${DateTime.now().microsecondsSinceEpoch}',
        text: e.message,
        isUser: false,
        timestamp: DateTime.now(),
        isError: true,
      );
      emit(
        state.copyWith(
          messages: [...updatedHistory, errorBubble],
          isSending: false,
        ),
      );
    } catch (_) {
      if (isClosed) return;
      final errorBubble = ChatMessageModel(
        id: 'err-${DateTime.now().microsecondsSinceEpoch}',
        text: 'Something went wrong while contacting CineList AI.',
        isUser: false,
        timestamp: DateTime.now(),
        isError: true,
      );
      emit(
        state.copyWith(
          messages: [...updatedHistory, errorBubble],
          isSending: false,
        ),
      );
    }
  }

  void clearChat() {
    emit(const AiChatState());
  }
}
