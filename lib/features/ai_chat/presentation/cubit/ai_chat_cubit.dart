import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/storage/preferences_service.dart';
import '../../data/models/ai_chat_context.dart';
import '../../data/models/chat_message_model.dart';
import '../../data/repositories/ai_chat_repository.dart';
import 'ai_chat_state.dart';

/// Manages CineList AI chatbot conversation with streaming and Hive persistence.
class AiChatCubit extends Cubit<AiChatState> {
  AiChatCubit(this._repository, {PreferencesService? preferencesService})
    : _preferencesService = preferencesService,
      super(
        AiChatState(
          messages: preferencesService?.loadAiChatHistory() ?? const [],
        ),
      );

  final AiChatRepository _repository;
  final PreferencesService? _preferencesService;
  StreamSubscription<String>? _streamSub;

  static const String defaultImagePrompt =
      'Identify the movie(s) in this photo and tell me which ones match my watchlist.';

  Future<void> sendMessage(
    String rawText, {
    AiChatContext context = const AiChatContext(),
    String? imageBase64,
    String? imageMimeType,
  }) async {
    final hasImage = imageBase64 != null && imageBase64.isNotEmpty;
    final trimmed = rawText.trim();
    if ((trimmed.isEmpty && !hasImage) || state.isSending) return;

    final text = trimmed.isNotEmpty ? trimmed : defaultImagePrompt;

    await _streamSub?.cancel();

    final now = DateTime.now();
    final userMessage = ChatMessageModel(
      id: 'user-${now.microsecondsSinceEpoch}',
      text: text,
      isUser: true,
      timestamp: now,
      imageBase64: hasImage ? imageBase64 : null,
      imageMimeType: hasImage ? (imageMimeType ?? 'image/jpeg') : null,
    );
    final aiId = 'ai-${now.microsecondsSinceEpoch + 1}';
    final placeholderAi = ChatMessageModel(
      id: aiId,
      text: '',
      isUser: false,
      timestamp: now,
    );

    final historyForRequest = [...state.messages, userMessage];
    emit(
      state.copyWith(
        messages: [...historyForRequest, placeholderAi],
        isSending: true,
      ),
    );

    final buffer = StringBuffer();
    final completer = Completer<void>();

    _streamSub = _repository
        .streamMessage(history: historyForRequest, context: context)
        .listen(
          (chunk) {
            if (isClosed) return;
            buffer.write(chunk);
            final updated = List<ChatMessageModel>.from(state.messages);
            if (updated.isNotEmpty && updated.last.id == aiId) {
              updated[updated.length - 1] = updated.last.copyWith(
                text: buffer.toString(),
              );
              emit(state.copyWith(messages: updated));
            }
          },
          onError: (Object error) {
            if (isClosed) {
              if (!completer.isCompleted) completer.complete();
              return;
            }
            final errorText = error is AppException
                ? error.message
                : 'Something went wrong while contacting CineList AI.';
            final updated = List<ChatMessageModel>.from(state.messages);
            if (updated.isNotEmpty && updated.last.id == aiId) {
              if (buffer.isEmpty) {
                updated[updated.length - 1] = updated.last.copyWith(
                  text: errorText,
                  isError: true,
                );
              } else {
                updated.add(
                  ChatMessageModel(
                    id: 'err-${DateTime.now().microsecondsSinceEpoch}',
                    text: errorText,
                    isUser: false,
                    timestamp: DateTime.now(),
                    isError: true,
                  ),
                );
              }
            }
            emit(state.copyWith(messages: updated, isSending: false));
            _preferencesService?.saveAiChatHistory(state.messages);
            if (!completer.isCompleted) completer.complete();
          },
          onDone: () {
            if (isClosed) {
              if (!completer.isCompleted) completer.complete();
              return;
            }
            emit(state.copyWith(isSending: false));
            _preferencesService?.saveAiChatHistory(state.messages);
            if (!completer.isCompleted) completer.complete();
          },
          cancelOnError: true,
        );

    return completer.future;
  }

  Future<void> clearChat() async {
    await _streamSub?.cancel();
    _streamSub = null;
    emit(const AiChatState());
    await _preferencesService?.saveAiChatHistory(const []);
  }

  @override
  Future<void> close() async {
    await _streamSub?.cancel();
    return super.close();
  }
}
