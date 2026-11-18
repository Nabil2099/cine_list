import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:cine_list/core/error/app_exception.dart';
import 'package:cine_list/features/community/data/models/community_poll_model.dart';
import 'package:cine_list/features/community/data/models/curated_list_model.dart';
import 'package:cine_list/features/community/data/models/movie_review_model.dart';
import 'package:cine_list/features/community/data/models/review_report_model.dart';
import 'package:cine_list/features/community/data/models/user_profile_model.dart';
import 'package:cine_list/features/community/data/repositories/community_repository.dart';
import 'package:cine_list/features/community/presentation/bloc/community_bloc.dart';
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

  final secondReview = MovieReviewModel(
    id: '438631_uid-2',
    movieId: 438631,
    movieTitle: 'Dune',
    uid: 'uid-2',
    authorName: 'Paul',
    authorAvatarKey: 'director',
    rating: 5,
    comment: 'Monumental sci-fi.',
    createdAt: DateTime(2026, 1, 2),
  );

  setUpAll(() {
    registerFallbackValue(sampleProfile);
    registerFallbackValue(sampleReview);
    registerFallbackValue(
      CuratedListModel(
        id: 'list-1',
        title: 'Mind-Bending Sci-Fi',
        authorUid: 'uid-1',
        authorName: 'Yami',
        movies: const [
          CuratedListMovie(movieId: 157336, title: 'Interstellar'),
        ],
        createdAt: DateTime(2026, 1, 1),
      ),
    );
    registerFallbackValue(
      ReviewReportModel(
        id: '157336_uid-1_uid-2',
        reviewId: '157336_uid-1',
        reportedUid: 'uid-1',
        reportedAuthorName: 'Yami',
        movieTitle: 'Interstellar',
        reviewComment: 'Test',
        reporterUid: 'uid-2',
        reason: ReportReason.hateSpeech,
        createdAt: DateTime(2026, 1, 1),
      ),
    );
  });

  setUp(() {
    repository = MockCommunityRepository();
    when(() => repository.isAdmin(any())).thenAnswer((_) async => false);
    when(() => repository.isModerator(any())).thenAnswer((_) async => false);
    when(() => repository.isUserBanned(any())).thenAnswer((_) async => false);
  });

  group('CommunityBloc', () {
    blocTest<CommunityBloc, CommunityState>(
      'binds user profile and community reviews stream',
      build: () {
        when(() => repository.watchProfile('uid-1'))
            .thenAnswer((_) => Stream.value(sampleProfile));
        when(() => repository.watchRecentReviews())
            .thenAnswer((_) => Stream.value([sampleReview]));
        return CommunityBloc(repository);
      },
      act: (bloc) async {
        bloc.add(
          const CommunityUserBound(uid: 'uid-1', email: 'yami@cinelist.app'),
        );
        await Future<void>.delayed(Duration.zero);
      },
      verify: (bloc) {
        expect(bloc.state.status, CommunityStatus.loaded);
        expect(bloc.state.profile?.bio, 'Sci-fi & thriller fan');
        expect(bloc.state.profile?.avatarKey, 'scifi');
        expect(bloc.state.reviews, hasLength(1));
        expect(bloc.state.reviewsForMovie(157336), hasLength(1));
      },
    );

    blocTest<CommunityBloc, CommunityState>(
      'CommunityProfileUpdated persists bio and avatar via repository',
      build: () {
        when(() => repository.watchProfile('uid-1'))
            .thenAnswer((_) => Stream.value(null));
        when(() => repository.watchRecentReviews())
            .thenAnswer((_) => Stream.value(const []));
        when(() => repository.saveProfile(any())).thenAnswer((_) async {});
        return CommunityBloc(repository);
      },
      act: (bloc) async {
        bloc.add(
          const CommunityUserBound(uid: 'uid-1', email: 'yami@cinelist.app'),
        );
        await Future<void>.delayed(Duration.zero);
        bloc.add(
          const CommunityProfileUpdated(
            displayName: 'Yami',
            bio: 'Love Nolan films',
            avatarKey: 'director',
          ),
        );
        await Future<void>.delayed(Duration.zero);
      },
      verify: (bloc) {
        verify(() => repository.saveProfile(any())).called(1);
        expect(bloc.state.profile?.bio, 'Love Nolan films');
        expect(bloc.state.profile?.avatarKey, 'director');
        expect(bloc.state.feedbackMessage, 'Profile updated.');
      },
    );

    blocTest<CommunityBloc, CommunityState>(
      'CommunityReviewSubmitted saves public movie review',
      build: () {
        when(() => repository.watchProfile('uid-1'))
            .thenAnswer((_) => Stream.value(sampleProfile));
        when(() => repository.watchRecentReviews())
            .thenAnswer((_) => Stream.value(const []));
        when(() => repository.saveReview(any())).thenAnswer((_) async {});
        return CommunityBloc(repository);
      },
      act: (bloc) async {
        bloc.add(
          const CommunityUserBound(uid: 'uid-1', email: 'yami@cinelist.app'),
        );
        await Future<void>.delayed(Duration.zero);
        bloc.add(
          const CommunityReviewSubmitted(
            movie: MovieSummary(id: 157336, title: 'Interstellar'),
            rating: 5,
            comment: 'Unforgettable score!',
          ),
        );
        await Future<void>.delayed(Duration.zero);
      },
      verify: (bloc) {
        verify(() => repository.saveReview(any())).called(1);
        expect(
          bloc.state.feedbackMessage,
          'Published review for "Interstellar".',
        );
      },
    );

    blocTest<CommunityBloc, CommunityState>(
      'CommunityReactionToggled (like) forwards current like status to repository',
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
        return CommunityBloc(repository);
      },
      act: (bloc) async {
        bloc.add(
          const CommunityUserBound(uid: 'uid-1', email: 'yami@cinelist.app'),
        );
        await Future<void>.delayed(Duration.zero);
        bloc.add(CommunityReactionToggled(review: sampleReview, isLike: true));
        await Future<void>.delayed(Duration.zero);
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
      final bloc = CommunityBloc(repository);
      final result = await bloc.fetchUserProfile('uid-2');
      expect(result, sampleProfile);
      verify(() => repository.getProfile('uid-2')).called(1);
      await bloc.close();
    });

    blocTest<CommunityBloc, CommunityState>(
      'CommunityReactionToggled (dislike) forwards current dislike status to repository',
      build: () {
        when(() => repository.watchProfile('uid-1'))
            .thenAnswer((_) => Stream.value(sampleProfile));
        when(() => repository.watchRecentReviews())
            .thenAnswer((_) => Stream.value([sampleReview]));
        when(
          () => repository.toggleReviewDislike(
            reviewId: '157336_uid-1',
            uid: 'uid-1',
            currentlyDisliked: false,
          ),
        ).thenAnswer((_) async {});
        return CommunityBloc(repository);
      },
      act: (bloc) async {
        bloc.add(
          const CommunityUserBound(uid: 'uid-1', email: 'yami@cinelist.app'),
        );
        await Future<void>.delayed(Duration.zero);
        bloc.add(CommunityReactionToggled(review: sampleReview, isLike: false));
        await Future<void>.delayed(Duration.zero);
      },
      verify: (_) {
        verify(
          () => repository.toggleReviewDislike(
            reviewId: '157336_uid-1',
            uid: 'uid-1',
            currentlyDisliked: false,
          ),
        ).called(1);
      },
    );

    blocTest<CommunityBloc, CommunityState>(
      'CommunityReviewReported submits safety report and emits feedback',
      build: () {
        when(() => repository.watchProfile('uid-1'))
            .thenAnswer((_) => Stream.value(sampleProfile));
        when(() => repository.watchRecentReviews())
            .thenAnswer((_) => Stream.value([sampleReview]));
        when(() => repository.submitReport(any())).thenAnswer((_) async {});
        return CommunityBloc(repository);
      },
      act: (bloc) async {
        bloc.add(
          const CommunityUserBound(uid: 'uid-1', email: 'yami@cinelist.app'),
        );
        await Future<void>.delayed(Duration.zero);
        bloc.add(
          CommunityReviewReported(
            review: sampleReview,
            reason: ReportReason.childAbuse,
            details: 'Inappropriate content',
          ),
        );
        await Future<void>.delayed(Duration.zero);
      },
      verify: (bloc) {
        verify(() => repository.submitReport(any())).called(1);
        expect(
          bloc.state.feedbackMessage,
          'Report submitted. Thank you for keeping CineList safe.',
        );
      },
    );

    test('ReputationTier maps karma points to expected rank tiers', () {
      expect(ReputationTier.fromPoints(0), ReputationTier.viewer);
      expect(ReputationTier.fromPoints(24), ReputationTier.viewer);
      expect(ReputationTier.fromPoints(25), ReputationTier.critic);
      expect(ReputationTier.fromPoints(100), ReputationTier.cinephile);
      expect(ReputationTier.fromPoints(250), ReputationTier.auteur);
      expect(ReputationTier.fromPoints(500), ReputationTier.legend);
    });

    blocTest<CommunityBloc, CommunityState>(
      'CommunityReviewSubmitted passes spoiler and verified watch flags',
      build: () {
        when(() => repository.watchProfile('uid-1'))
            .thenAnswer((_) => Stream.value(sampleProfile));
        when(() => repository.watchRecentReviews())
            .thenAnswer((_) => Stream.value(const []));
        when(() => repository.saveReview(any())).thenAnswer((_) async {});
        return CommunityBloc(repository);
      },
      act: (bloc) async {
        bloc.add(
          const CommunityUserBound(uid: 'uid-1', email: 'yami@cinelist.app'),
        );
        await Future<void>.delayed(Duration.zero);
        bloc.add(
          const CommunityReviewSubmitted(
            movie: MovieSummary(id: 157336, title: 'Interstellar'),
            rating: 5,
            comment: 'Murph solves the gravity equation.',
            hasSpoilers: true,
            isVerifiedWatch: true,
          ),
        );
        await Future<void>.delayed(Duration.zero);
      },
      verify: (_) {
        final captured =
            verify(() => repository.saveReview(captureAny())).captured.single
                as MovieReviewModel;
        expect(captured.hasSpoilers, isTrue);
        expect(captured.isVerifiedWatch, isTrue);
      },
    );

    blocTest<CommunityBloc, CommunityState>(
      'CommunityFollowToggled calls repository.toggleFollowUser',
      build: () {
        when(() => repository.watchProfile('uid-1'))
            .thenAnswer((_) => Stream.value(sampleProfile));
        when(() => repository.watchRecentReviews())
            .thenAnswer((_) => Stream.value(const []));
        when(
          () => repository.toggleFollowUser(
            currentUid: 'uid-1',
            targetUid: 'uid-2',
            currentlyFollowing: false,
          ),
        ).thenAnswer((_) async {});
        return CommunityBloc(repository);
      },
      act: (bloc) async {
        bloc.add(
          const CommunityUserBound(uid: 'uid-1', email: 'yami@cinelist.app'),
        );
        await Future<void>.delayed(Duration.zero);
        bloc.add(const CommunityFollowToggled('uid-2'));
        await Future<void>.delayed(Duration.zero);
      },
      verify: (_) {
        verify(
          () => repository.toggleFollowUser(
            currentUid: 'uid-1',
            targetUid: 'uid-2',
            currentlyFollowing: false,
          ),
        ).called(1);
      },
    );

    test(
      'CommunityState.filteredReviews handles sort, search, and following',
      () {
        final reviewA = MovieReviewModel(
          id: '1_uid-1',
          movieId: 1,
          movieTitle: 'Interstellar',
          uid: 'uid-1',
          authorName: 'Yami',
          rating: 4,
          comment: 'Amazing score',
          likedBy: const ['a', 'b', 'c'],
          createdAt: DateTime(2026, 1, 1),
        );
        final reviewB = MovieReviewModel(
          id: '2_uid-2',
          movieId: 2,
          movieTitle: 'Dune',
          uid: 'uid-2',
          authorName: 'Paul',
          rating: 5,
          comment: 'Epic visuals',
          likedBy: const ['a'],
          createdAt: DateTime(2026, 1, 3),
        );

        final baseState = CommunityState(
          profile: sampleProfile.copyWith(followingUids: const ['uid-2']),
          reviews: [reviewA, reviewB],
        );

        expect(baseState.filteredReviews.map((r) => r.id).toList(), [
          '2_uid-2',
          '1_uid-1',
        ]);
        expect(
          baseState
              .copyWith(sortOption: CommunitySortOption.mostHelpful)
              .filteredReviews
              .map((r) => r.id)
              .toList(),
          ['1_uid-1', '2_uid-2'],
        );
        expect(
          baseState
              .copyWith(sortOption: CommunitySortOption.highestRated)
              .filteredReviews
              .map((r) => r.id)
              .toList(),
          ['2_uid-2', '1_uid-1'],
        );
        expect(
          baseState
              .copyWith(followingOnly: true)
              .filteredReviews
              .map((r) => r.id)
              .toList(),
          ['2_uid-2'],
        );
        expect(
          baseState
              .copyWith(searchQuery: 'interstellar')
              .filteredReviews
              .map((r) => r.id)
              .toList(),
          ['1_uid-1'],
        );
      },
    );

    test('CommunityState.topCritics excludes 0-pt users and sorts by reputation descending', () {
      final users = {
        'u0': const UserProfileModel(
          uid: 'u0',
          displayName: 'Zero',
          reputation: 0,
        ),
        'u1': const UserProfileModel(
          uid: 'u1',
          displayName: 'User 1',
          reputation: 20,
        ),
        'u2': const UserProfileModel(
          uid: 'u2',
          displayName: 'User 2',
          reputation: 150,
        ),
        'u3': const UserProfileModel(
          uid: 'u3',
          displayName: 'User 3',
          reputation: 80,
        ),
      };
      final state = CommunityState(userProfilesByUid: users);
      expect(state.topCritics.map((u) => u.uid).toList(), ['u2', 'u3', 'u1']);
      expect(state.leaderboard.map((u) => u.uid).toList(), [
        'u2',
        'u3',
        'u1',
        'u0',
      ]);
    });

    test(
      'like updates state optimistically before repository completes',
      () async {
        final completer = Completer<void>();
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
        ).thenAnswer((_) => completer.future);

        final bloc = CommunityBloc(repository);
        bloc.add(
          const CommunityUserBound(uid: 'uid-1', email: 'yami@cinelist.app'),
        );
        await Future<void>.delayed(Duration.zero);

        bloc.add(CommunityReactionToggled(review: sampleReview, isLike: true));
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.reviews.single.isLikedBy('uid-1'), isTrue);

        completer.complete();
        await Future<void>.delayed(Duration.zero);
        await bloc.close();
      },
    );

    blocTest<CommunityBloc, CommunityState>(
      'dislike rolls back optimistic state when repository throws',
      build: () {
        when(() => repository.watchProfile('uid-1'))
            .thenAnswer((_) => Stream.value(sampleProfile));
        when(() => repository.watchRecentReviews())
            .thenAnswer((_) => Stream.value([sampleReview]));
        when(
          () => repository.toggleReviewDislike(
            reviewId: '157336_uid-1',
            uid: 'uid-1',
            currentlyDisliked: false,
          ),
        ).thenThrow(
          const WatchlistException('Could not update review dislike.'),
        );
        return CommunityBloc(repository);
      },
      act: (bloc) async {
        bloc.add(
          const CommunityUserBound(uid: 'uid-1', email: 'yami@cinelist.app'),
        );
        await Future<void>.delayed(Duration.zero);
        bloc.add(CommunityReactionToggled(review: sampleReview, isLike: false));
        await Future<void>.delayed(Duration.zero);
      },
      verify: (bloc) {
        expect(bloc.state.reviews.single.isDislikedBy('uid-1'), isFalse);
        expect(bloc.state.errorMessage, 'Could not update review dislike.');
      },
    );

    test('enforces global 5-second cooldown across all reviews with remaining-time SnackBar message', () async {
      var fakeNow = DateTime(2026, 1, 1, 12, 0, 0);
      when(() => repository.watchProfile('uid-1'))
          .thenAnswer((_) => Stream.value(sampleProfile));
      when(() => repository.watchRecentReviews())
          .thenAnswer((_) => Stream.value([sampleReview, secondReview]));
      when(
        () => repository.toggleReviewLike(
          reviewId: any(named: 'reviewId'),
          uid: 'uid-1',
          currentlyLiked: any(named: 'currentlyLiked'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => repository.toggleReviewDislike(
          reviewId: any(named: 'reviewId'),
          uid: 'uid-1',
          currentlyDisliked: any(named: 'currentlyDisliked'),
        ),
      ).thenAnswer((_) async {});

      final bloc = CommunityBloc(repository, clock: () => fakeNow);
      bloc.add(
        const CommunityUserBound(uid: 'uid-1', email: 'yami@cinelist.app'),
      );
      await Future<void>.delayed(Duration.zero);

      // 1st reaction at t=0 succeeds.
      bloc.add(CommunityReactionToggled(review: sampleReview, isLike: true));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.reviews.first.isLikedBy('uid-1'), isTrue);

      // 2nd reaction at t=2s on a DIFFERENT review is blocked globally (3s left).
      fakeNow = fakeNow.add(const Duration(seconds: 2));
      bloc.add(CommunityReactionToggled(review: secondReview, isLike: false));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.reviews.last.isDislikedBy('uid-1'), isFalse);
      expect(
        bloc.state.feedbackMessage,
        'Please wait 3s before changing your reaction.',
      );

      // Switching like -> dislike on the same review at t=6s (>5s) succeeds.
      fakeNow = fakeNow.add(const Duration(seconds: 4));
      final updatedFirst = bloc.state.reviews.first;
      bloc.add(CommunityReactionToggled(review: updatedFirst, isLike: false));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.reviews.first.isLikedBy('uid-1'), isFalse);
      expect(bloc.state.reviews.first.isDislikedBy('uid-1'), isTrue);

      await bloc.close();
    });

    test('CommunityPollModel computes vote counts and percentages', () {
      final poll = CommunityPollModel(
        id: 'poll-1',
        question: 'Best Nolan ending?',
        options: const ['Inception', 'Interstellar', 'The Prestige'],
        votesByUid: const {'u1': 0, 'u2': 0, 'u3': 2},
        createdByUid: 'admin',
        createdAt: DateTime(2026, 1, 1),
      );

      expect(poll.totalVotes, 3);
      expect(poll.votesForOption(0), 2);
      expect(poll.votesForOption(1), 0);
      expect(poll.selectedOptionFor('u3'), 2);
      expect(poll.percentageForOption(0), closeTo(2 / 3, 0.001));
    });

    blocTest<CommunityBloc, CommunityState>(
      'CommunityPollVoted updates poll optimistically and calls repository',
      build: () {
        final poll = CommunityPollModel(
          id: 'poll-1',
          question: 'Best sci-fi?',
          options: const ['Dune', 'Blade Runner 2049'],
          createdByUid: 'admin',
          createdAt: DateTime(2026, 1, 1),
        );
        when(() => repository.watchProfile('uid-1'))
            .thenAnswer((_) => Stream.value(sampleProfile));
        when(() => repository.watchRecentReviews())
            .thenAnswer((_) => Stream.value(const []));
        when(() => repository.watchPinnedPoll())
            .thenAnswer((_) => Stream.value(poll));
        when(
          () => repository.voteOnPoll(
            pollId: 'poll-1',
            uid: 'uid-1',
            optionIndex: 1,
          ),
        ).thenAnswer((_) async {});
        return CommunityBloc(repository);
      },
      act: (bloc) async {
        bloc.add(
          const CommunityUserBound(uid: 'uid-1', email: 'yami@cinelist.app'),
        );
        await Future<void>.delayed(Duration.zero);
        bloc.add(const CommunityPollVoted(pollId: 'poll-1', optionIndex: 1));
        await Future<void>.delayed(Duration.zero);
      },
      verify: (bloc) {
        expect(bloc.state.pinnedPoll?.selectedOptionFor('uid-1'), 1);
        verify(
          () => repository.voteOnPoll(
            pollId: 'poll-1',
            uid: 'uid-1',
            optionIndex: 1,
          ),
        ).called(1);
      },
    );

    blocTest<CommunityBloc, CommunityState>(
      'CommunityCuratedListPublished and LikeToggled update repository and state',
      build: () {
        final list = CuratedListModel(
          id: 'list-1',
          title: 'Top Sci-Fi',
          authorUid: 'uid-2',
          authorName: 'Paul',
          movies: const [CuratedListMovie(movieId: 438631, title: 'Dune')],
          createdAt: DateTime(2026, 1, 1),
        );
        when(() => repository.watchProfile('uid-1'))
            .thenAnswer((_) => Stream.value(sampleProfile));
        when(() => repository.watchRecentReviews())
            .thenAnswer((_) => Stream.value(const []));
        when(() => repository.watchCuratedLists())
            .thenAnswer((_) => Stream.value([list]));
        when(() => repository.publishCuratedList(any()))
            .thenAnswer((_) async {});
        when(
          () => repository.toggleCuratedListLike(
            listId: 'list-1',
            uid: 'uid-1',
            currentlyLiked: false,
          ),
        ).thenAnswer((_) async {});
        return CommunityBloc(repository);
      },
      act: (bloc) async {
        bloc.add(
          const CommunityUserBound(uid: 'uid-1', email: 'yami@cinelist.app'),
        );
        await Future<void>.delayed(Duration.zero);
        bloc.add(
          CommunityCuratedListLikeToggled(bloc.state.curatedLists.first),
        );
        bloc.add(
          const CommunityCuratedListPublished(
            title: 'Nolan Favorites',
            movies: [CuratedListMovie(movieId: 157336, title: 'Interstellar')],
          ),
        );
        await Future<void>.delayed(Duration.zero);
      },
      verify: (bloc) {
        expect(bloc.state.curatedLists.first.isLikedBy('uid-1'), isTrue);
        verify(() => repository.publishCuratedList(any())).called(1);
        verify(
          () => repository.toggleCuratedListLike(
            listId: 'list-1',
            uid: 'uid-1',
            currentlyLiked: false,
          ),
        ).called(1);
      },
    );

    blocTest<CommunityBloc, CommunityState>(
      'CommunityCuratedListMoviesSynced updates published list movies automatically',
      build: () {
        final list = CuratedListModel(
          id: 'uid-1_col-1',
          collectionId: 'col-1',
          title: 'Top Sci-Fi',
          authorUid: 'uid-1',
          authorName: 'Yami',
          movies: const [CuratedListMovie(movieId: 438631, title: 'Dune')],
          createdAt: DateTime(2026, 1, 1),
        );
        when(() => repository.watchProfile('uid-1'))
            .thenAnswer((_) => Stream.value(sampleProfile));
        when(() => repository.watchRecentReviews())
            .thenAnswer((_) => Stream.value(const []));
        when(() => repository.watchCuratedLists())
            .thenAnswer((_) => Stream.value([list]));
        when(
          () => repository.syncCuratedListMovies(
            listId: 'uid-1_col-1',
            movies: any(named: 'movies'),
          ),
        ).thenAnswer((_) async {});
        return CommunityBloc(repository);
      },
      act: (bloc) async {
        bloc.add(
          const CommunityUserBound(uid: 'uid-1', email: 'yami@cinelist.app'),
        );
        await Future<void>.delayed(Duration.zero);
        bloc.add(
          const CommunityCuratedListMoviesSynced(
            listId: 'uid-1_col-1',
            movies: [
              CuratedListMovie(movieId: 438631, title: 'Dune'),
              CuratedListMovie(movieId: 157336, title: 'Interstellar'),
            ],
          ),
        );
        await Future<void>.delayed(Duration.zero);
      },
      verify: (bloc) {
        expect(bloc.state.curatedLists.first.movies, hasLength(2));
        verify(
          () => repository.syncCuratedListMovies(
            listId: 'uid-1_col-1',
            movies: any(named: 'movies'),
          ),
        ).called(1);
      },
    );
  });
}
