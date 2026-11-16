import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:cine_list/features/match_room/data/models/match_room_model.dart';
import 'package:cine_list/features/match_room/data/repositories/match_room_repository.dart';
import 'package:cine_list/features/match_room/presentation/cubit/match_room_cubit.dart';
import 'package:cine_list/features/match_room/presentation/cubit/match_room_state.dart';
import 'package:cine_list/shared/models/movie_summary.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMatchRoomRepository extends Mock implements MatchRoomRepository {}

void main() {
  late MockMatchRoomRepository repository;

  const movie1 = MovieSummary(id: 157336, title: 'Interstellar');
  const movie2 = MovieSummary(id: 27205, title: 'Inception');

  final baseRoom = MatchRoomModel(
    code: 'X9K2',
    hostUid: 'uid-1',
    hostName: 'Yami',
    participantUids: const ['uid-1', 'uid-2'],
    participantNames: const {'uid-1': 'Yami', 'uid-2': 'Alex'},
    deck: const [movie1, movie2],
    likesByUser: const {
      'uid-1': [157336],
    },
    createdAt: DateTime(2026, 1, 1),
  );

  setUp(() {
    repository = MockMatchRoomRepository();
  });

  group('MatchRoomModel', () {
    test('matchedMovies returns movies liked by at least 2 participants', () {
      expect(baseRoom.matchedMovies, isEmpty);

      final matchedRoom = MatchRoomModel(
        code: 'X9K2',
        hostUid: 'uid-1',
        hostName: 'Yami',
        participantUids: const ['uid-1', 'uid-2'],
        participantNames: const {'uid-1': 'Yami', 'uid-2': 'Alex'},
        deck: const [movie1, movie2],
        likesByUser: const {
          'uid-1': [157336],
          'uid-2': [157336, 27205],
        },
        createdAt: DateTime(2026, 1, 1),
      );

      expect(matchedRoom.matchedMovies, [movie1]);
      expect(matchedRoom.unvotedMoviesFor('uid-1'), [movie2]);
    });
  });

  group('MatchRoomCubit', () {
    late StreamController<MatchRoomModel?> controller;

    setUp(() {
      controller = StreamController<MatchRoomModel?>.broadcast();
    });

    tearDown(() async {
      await controller.close();
    });

    blocTest<MatchRoomCubit, MatchRoomState>(
      'createRoom subscribes to room stream and emits latestMatch when friend likes same movie',
      build: () {
        when(
          () => repository.createRoom(
            hostUid: 'uid-1',
            hostName: 'Yami',
            seedMovies: const [],
          ),
        ).thenAnswer((_) async => baseRoom);
        when(() => repository.watchRoom('X9K2'))
            .thenAnswer((_) => controller.stream);
        return MatchRoomCubit(repository);
      },
      act: (cubit) async {
        await cubit.createRoom(uid: 'uid-1', displayName: 'Yami');
        controller.add(
          MatchRoomModel(
            code: 'X9K2',
            hostUid: 'uid-1',
            hostName: 'Yami',
            participantUids: const ['uid-1', 'uid-2'],
            participantNames: const {'uid-1': 'Yami', 'uid-2': 'Alex'},
            deck: const [movie1, movie2],
            likesByUser: const {
              'uid-1': [157336],
              'uid-2': [157336],
            },
            createdAt: DateTime(2026, 1, 1),
          ),
        );
        await Future<void>.delayed(Duration.zero);
      },
      verify: (cubit) {
        expect(cubit.state.status, MatchRoomStatus.active);
        expect(cubit.state.latestMatch, movie1);
        expect(cubit.state.matchedMovies, [movie1]);
      },
    );
  });
}
