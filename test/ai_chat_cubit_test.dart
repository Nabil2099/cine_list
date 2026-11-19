import 'package:bloc_test/bloc_test.dart';
import 'package:cine_list/core/error/app_exception.dart';
import 'package:cine_list/core/storage/preferences_service.dart';
import 'package:cine_list/features/ai_chat/data/models/ai_chat_context.dart';
import 'package:cine_list/features/ai_chat/data/models/chat_message_model.dart';
import 'package:cine_list/features/ai_chat/data/repositories/ai_chat_repository.dart';
import 'package:cine_list/features/ai_chat/presentation/cubit/ai_chat_cubit.dart';
import 'package:cine_list/features/ai_chat/presentation/cubit/ai_chat_state.dart';
import 'package:cine_list/features/watchlist/data/models/watchlist_movie_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAiChatRepository extends Mock implements AiChatRepository {}

class MockPreferencesService extends Mock implements PreferencesService {}

void main() {
  late MockAiChatRepository repository;
  late MockPreferencesService preferencesService;

  final watchlist = [
    WatchlistMovieModel(
      movieId: 157336,
      title: 'Interstellar',
      releaseDate: '2014-11-05',
      voteAverage: 8.7,
      status: WatchlistFilterStatus.watched,
      addedAt: DateTime(2026, 1, 1),
      isUpNext: false,
      rewatchCount: 1,
    ),
  ];

  final aiContext = AiChatContext(watchlist: watchlist);

  setUp(() {
    repository = MockAiChatRepository();
    preferencesService = MockPreferencesService();
    when(() => preferencesService.loadAiChatHistory()).thenReturn(const []);
    when(
      () => preferencesService.saveAiChatHistory(any()),
    ).thenAnswer((_) async {});
  });

  group('AiChatCubit', () {
    blocTest<AiChatCubit, AiChatState>(
      'streams AI chunks into reply and persists history',
      build: () {
        when(
          () => repository.streamMessage(
            history: any(named: 'history'),
            context: aiContext,
          ),
        ).thenAnswer(
          (_) => Stream.fromIterable([
            'Try **Arrival (2016)** ',
            'or **The Martian (2015)**.',
          ]),
        );
        return AiChatCubit(
          repository,
          preferencesService: preferencesService,
        );
      },
      act: (cubit) => cubit.sendMessage(
        'Recommend something like Interstellar',
        context: aiContext,
      ),
      verify: (cubit) {
        expect(cubit.state.isSending, isFalse);
        expect(cubit.state.messages, hasLength(2));
        expect(cubit.state.messages.first.isUser, isTrue);
        expect(cubit.state.messages.last.isUser, isFalse);
        expect(cubit.state.messages.last.isError, isFalse);
        expect(
          cubit.state.messages.last.text,
          'Try **Arrival (2016)** or **The Martian (2015)**.',
        );
        verify(
          () => repository.streamMessage(
            history: any(named: 'history'),
            context: aiContext,
          ),
        ).called(1);
        verify(() => preferencesService.saveAiChatHistory(any())).called(1);
      },
    );

    blocTest<AiChatCubit, AiChatState>(
      'appends error bubble when AI stream throws NetworkException',
      build: () {
        when(
          () => repository.streamMessage(
            history: any(named: 'history'),
            context: aiContext,
          ),
        ).thenAnswer(
          (_) => Stream.error(
            const NetworkException('Gemini API key is not configured.'),
          ),
        );
        return AiChatCubit(
          repository,
          preferencesService: preferencesService,
        );
      },
      act: (cubit) => cubit.sendMessage('Hi', context: aiContext),
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

    test('loads persisted history on init and clears it on clearChat', () async {
      final savedMsg = ChatMessageModel(
        id: 'm1',
        text: 'Hello',
        isUser: true,
        timestamp: DateTime(2026, 1, 1),
      );
      when(() => preferencesService.loadAiChatHistory()).thenReturn([savedMsg]);

      final cubit = AiChatCubit(
        repository,
        preferencesService: preferencesService,
      );
      expect(cubit.state.messages, [savedMsg]);

      await cubit.clearChat();
      expect(cubit.state.messages, isEmpty);
      verify(() => preferencesService.saveAiChatHistory(const [])).called(1);
      await cubit.close();
    });

    test('ChatMessageModel serializes toMap and fromMap accurately', () {
      final msg = ChatMessageModel(
        id: 'id-1',
        text: 'Test reply',
        isUser: false,
        timestamp: DateTime(2026, 5, 10, 14, 30),
        imageBase64: 'YWJjMTIz',
        imageMimeType: 'image/jpeg',
      );
      final restored = ChatMessageModel.fromMap(msg.toMap());
      expect(restored, msg);
      expect(restored.hasImage, isTrue);
    });

    blocTest<AiChatCubit, AiChatState>(
      'sendMessage with image-only uses default vision prompt and attaches base64',
      build: () {
        when(
          () => repository.streamMessage(
            history: any(named: 'history'),
            context: aiContext,
          ),
        ).thenAnswer(
          (_) => Stream.value('I spotted **Blade Runner 2049 (2017)**!'),
        );
        return AiChatCubit(
          repository,
          preferencesService: preferencesService,
        );
      },
      act: (cubit) => cubit.sendMessage(
        '',
        context: aiContext,
        imageBase64: 'aW1hZ2VkYXRh',
        imageMimeType: 'image/png',
      ),
      verify: (cubit) {
        expect(cubit.state.messages, hasLength(2));
        expect(cubit.state.messages.first.text, AiChatCubit.defaultImagePrompt);
        expect(cubit.state.messages.first.imageBase64, 'aW1hZ2VkYXRh');
        expect(cubit.state.messages.first.imageMimeType, 'image/png');
        expect(cubit.state.messages.last.text, contains('Blade Runner 2049'));
      },
    );
  });
}
