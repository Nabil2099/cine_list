import 'package:bloc_test/bloc_test.dart';
import 'package:cine_list/core/error/app_exception.dart';
import 'package:cine_list/features/ai_chat/data/repositories/ai_chat_repository.dart';
import 'package:cine_list/features/ai_chat/presentation/cubit/ai_chat_cubit.dart';
import 'package:cine_list/features/ai_chat/presentation/cubit/ai_chat_state.dart';
import 'package:cine_list/features/watchlist/data/models/watchlist_movie_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAiChatRepository extends Mock implements AiChatRepository {}

void main() {
  late MockAiChatRepository repository;

  final watchlist = [
    WatchlistMovieModel(
      movieId: 157336,
      title: 'Interstellar',
      releaseDate: '2014-11-05',
      voteAverage: 8.7,
      status: WatchlistFilterStatus.watched,
      addedAt: DateTime(2026, 1, 1),
    ),
  ];

  setUp(() {
    repository = MockAiChatRepository();
  });

  group('AiChatCubit', () {
    blocTest<AiChatCubit, AiChatState>(
      'appends user message and AI reply using watchlist context',
      build: () {
        when(
          () => repository.sendMessage(
            history: any(named: 'history'),
            watchlist: watchlist,
          ),
        ).thenAnswer((_) async => 'Try Arrival (2016) or The Martian (2015).');
        return AiChatCubit(repository);
      },
      act: (cubit) => cubit.sendMessage(
        'Recommend something like Interstellar',
        watchlist: watchlist,
      ),
      verify: (cubit) {
        expect(cubit.state.isSending, isFalse);
        expect(cubit.state.messages, hasLength(2));
        expect(cubit.state.messages.first.isUser, isTrue);
        expect(cubit.state.messages.last.isUser, isFalse);
        expect(cubit.state.messages.last.isError, isFalse);
        expect(cubit.state.messages.last.text, contains('Arrival'));
        verify(
          () => repository.sendMessage(
            history: any(named: 'history'),
            watchlist: watchlist,
          ),
        ).called(1);
      },
    );

    blocTest<AiChatCubit, AiChatState>(
      'appends error bubble when AI repository throws NetworkException',
      build: () {
        when(
          () => repository.sendMessage(
            history: any(named: 'history'),
            watchlist: watchlist,
          ),
        ).thenThrow(
          const NetworkException('Gemini API key is not configured.'),
        );
        return AiChatCubit(repository);
      },
      act: (cubit) => cubit.sendMessage('Hi', watchlist: watchlist),
      verify: (cubit) {
        expect(cubit.state.isSending, isFalse);
        expect(cubit.state.messages, hasLength(2));
        expect(cubit.state.messages.last.isError, isTrue);
        expect(
          cubit.state.messages.last.text,
          'Gemini API key is not configured.',
        );
      },
    );
  });
}
