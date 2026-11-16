import 'package:bloc_test/bloc_test.dart';
import 'package:cine_list/features/community/data/models/movie_review_model.dart';
import 'package:cine_list/features/community/data/models/user_profile_model.dart';
import 'package:cine_list/features/community/data/repositories/community_repository.dart';
import 'package:cine_list/features/community/presentation/cubit/community_cubit.dart';
import 'package:cine_list/features/community/presentation/cubit/community_state.dart';
import 'package:cine_list/shared/models/movie_summary.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCommunityRepository extends Mock implements CommunityRepository {}

void main() {
  late MockCommunityRepository repository;

  final sampleProfile = UserProfileModel(
    uid: 'uid-1',
    displayName: 'Yami',
    bio: 'Sci-fi & thriller fan',
    avatarKey: 'scifi',
    updatedAt: DateTime(2026, 1, 1),
  );

  final sampleReview = MovieReviewModel(
    id: '157336_uid-1',
    movieId: 157336,
    movieTitle: 'Interstellar',
    uid: 'uid-1',
    authorName: 'Yami',
    authorAvatarKey: 'scifi',
    rating: 5,
    comment: 'A masterpiece of cinema.',
    createdAt: DateTime(2026, 1, 1),
  );

  setUpAll(() {
    registerFallbackValue(sampleProfile);
    registerFallbackValue(sampleReview);
  });

  setUp(() {
    repository = MockCommunityRepository();
  });

  group('CommunityCubit', () {
    blocTest<CommunityCubit, CommunityState>(
      'binds user profile and community reviews stream',
      build: () {
        when(() => repository.watchProfile('uid-1'))
            .thenAnswer((_) => Stream.value(sampleProfile));
        when(() => repository.watchRecentReviews())
            .thenAnswer((_) => Stream.value([sampleReview]));
        return CommunityCubit(repository);
      },
      act: (cubit) => cubit.bindUser(uid: 'uid-1', email: 'yami@cinelist.app'),
      verify: (cubit) {
        expect(cubit.state.status, CommunityStatus.loaded);
        expect(cubit.state.profile?.bio, 'Sci-fi & thriller fan');
        expect(cubit.state.profile?.avatarKey, 'scifi');
        expect(cubit.state.reviews, hasLength(1));
        expect(cubit.state.reviewsForMovie(157336), hasLength(1));
      },
    );

    blocTest<CommunityCubit, CommunityState>(
      'updateProfile persists bio and avatar via repository',
      build: () {
        when(() => repository.watchProfile('uid-1'))
            .thenAnswer((_) => Stream.value(null));
        when(() => repository.watchRecentReviews())
            .thenAnswer((_) => Stream.value(const []));
        when(() => repository.saveProfile(any())).thenAnswer((_) async {});
        return CommunityCubit(repository);
      },
      act: (cubit) async {
        cubit.bindUser(uid: 'uid-1', email: 'yami@cinelist.app');
        await Future<void>.delayed(Duration.zero);
        await cubit.updateProfile(
          displayName: 'Yami',
          bio: 'Love Nolan films',
          avatarKey: 'director',
        );
      },
      verify: (cubit) {
        verify(() => repository.saveProfile(any())).called(1);
        expect(cubit.state.profile?.bio, 'Love Nolan films');
        expect(cubit.state.profile?.avatarKey, 'director');
        expect(cubit.state.feedbackMessage, 'Profile updated.');
      },
    );

    blocTest<CommunityCubit, CommunityState>(
      'submitReview saves public movie review',
      build: () {
        when(() => repository.watchProfile('uid-1'))
            .thenAnswer((_) => Stream.value(sampleProfile));
        when(() => repository.watchRecentReviews())
            .thenAnswer((_) => Stream.value(const []));
        when(() => repository.saveReview(any())).thenAnswer((_) async {});
        return CommunityCubit(repository);
      },
      act: (cubit) async {
        cubit.bindUser(uid: 'uid-1', email: 'yami@cinelist.app');
        await Future<void>.delayed(Duration.zero);
        await cubit.submitReview(
          movie: const MovieSummary(id: 157336, title: 'Interstellar'),
          rating: 5,
          comment: 'Unforgettable score!',
        );
      },
      verify: (cubit) {
        verify(() => repository.saveReview(any())).called(1);
        expect(
          cubit.state.feedbackMessage,
          'Published review for "Interstellar".',
        );
      },
    );

    blocTest<CommunityCubit, CommunityState>(
      'toggleLike forwards current like status to repository',
      build: () {
        when(() => repository.watchProfile('uid-1'))
            .thenAnswer((_) => Stream.value(sampleProfile));
        when(() => repository.watchRecentReviews())
            .thenAnswer((_) => Stream.value([sampleReview]));
        when(
          () => repository.toggleReviewLike(
            reviewId: '157336_uid-1',
            uid: 'uid-1',
            currentlyLiked: false,
          ),
        ).thenAnswer((_) async {});
        return CommunityCubit(repository);
      },
      act: (cubit) async {
        cubit.bindUser(uid: 'uid-1', email: 'yami@cinelist.app');
        await Future<void>.delayed(Duration.zero);
        await cubit.toggleLike(sampleReview);
      },
      verify: (_) {
        verify(
          () => repository.toggleReviewLike(
            reviewId: '157336_uid-1',
            uid: 'uid-1',
            currentlyLiked: false,
          ),
        ).called(1);
      },
    );

    test('fetchUserProfile returns profile from repository', () async {
      when(() => repository.getProfile('uid-2'))
          .thenAnswer((_) async => sampleProfile);
      final cubit = CommunityCubit(repository);
      final result = await cubit.fetchUserProfile('uid-2');
      expect(result, sampleProfile);
      verify(() => repository.getProfile('uid-2')).called(1);
      await cubit.close();
    });
  });
}
