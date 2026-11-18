import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/utils/bloc_transformers.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/movie_summary.dart';
import '../../data/models/community_poll_model.dart';
import '../../data/models/curated_list_model.dart';
import '../../data/models/movie_review_model.dart';
import '../../data/models/review_report_model.dart';
import '../../data/models/user_profile_model.dart';
import '../../data/models/weekly_challenge_model.dart';
import '../../data/repositories/community_repository.dart';
import '../cubit/community_state.dart';

export '../cubit/community_state.dart';

part 'community_event.dart';

/// Manages the user's community profile, public movie reviews feed,
/// debounced search/filtering, and global 5s reaction anti-spam cooldowns.
class CommunityBloc extends Bloc<CommunityEvent, CommunityState> {
  CommunityBloc(
    this._repository, {
    DateTime Function()? clock,
    Duration? searchDebounceDuration,
  }) : _clock = clock ?? DateTime.now,
       super(const CommunityState()) {
    on<CommunityUserBound>(_onUserBound);
    on<CommunityRefreshed>(_onRefreshed);
    on<CommunityFeedbackCleared>(_onFeedbackCleared);
    on<CommunityProfileUpdated>(_onProfileUpdated);
    on<CommunitySortChanged>(_onSortChanged);
    on<CommunityFollowingFilterToggled>(_onFollowingFilterToggled);
    on<CommunitySearchQueryChanged>(
      _onSearchQueryChanged,
      transformer: debounceRestartable(
        searchDebounceDuration ?? const Duration(milliseconds: 160),
      ),
    );
    on<CommunityFollowToggled>(_onFollowToggled);
    on<CommunityReviewSubmitted>(_onReviewSubmitted);
    on<CommunityReactionToggled>(_onReactionToggled);
    on<CommunityReviewReported>(_onReviewReported);
    on<CommunityReviewDeleted>(_onReviewDeleted);
    on<CommunityPollVoted>(_onPollVoted);
    on<CommunityCuratedListPublished>(_onCuratedListPublished);
    on<CommunityCuratedListMoviesSynced>(_onCuratedListMoviesSynced);
    on<CommunityCuratedListLikeToggled>(_onCuratedListLikeToggled);
    on<CommunityCuratedListDeleted>(_onCuratedListDeleted);
    on<CommunityChallengeCompleted>(_onChallengeCompleted);

    on<_CommunityProfileReceived>(_onProfileReceived);
    on<_CommunityAllUsersReceived>(_onAllUsersReceived);
    on<_CommunityAdminUidsReceived>(_onAdminUidsReceived);
    on<_CommunityModeratorUidsReceived>(_onModeratorUidsReceived);
    on<_CommunityRolesResolved>(_onRolesResolved);
    on<_CommunityReviewsReceived>(_onReviewsReceived);
    on<_CommunityReviewsLoadFailed>(_onReviewsLoadFailed);
    on<_CommunityPinnedPollReceived>(_onPinnedPollReceived);
    on<_CommunityActiveChallengeReceived>(_onActiveChallengeReceived);
    on<_CommunityCuratedListsReceived>(_onCuratedListsReceived);
  }

  static const Duration reactionCooldown = Duration(seconds: 5);

  final CommunityRepository _repository;
  final DateTime Function() _clock;
  StreamSubscription<UserProfileModel?>? _profileSub;
  StreamSubscription<List<MovieReviewModel>>? _reviewsSub;
  StreamSubscription<List<UserProfileModel>>? _allUsersSub;
  StreamSubscription<Set<String>>? _adminUidsSub;
  StreamSubscription<Set<String>>? _moderatorUidsSub;
  StreamSubscription<CommunityPollModel?>? _pollSub;
  StreamSubscription<WeeklyChallengeModel?>? _challengeSub;
  StreamSubscription<List<CuratedListModel>>? _listsSub;
  String? _currentUid;
  String? _fallbackName;
  DateTime? _lastReactionAt;
  final Set<String> _pendingReactionIds = {};

  String? get currentUid => _currentUid;

  void _onUserBound(CommunityUserBound event, Emitter<CommunityState> emit) {
    final resolvedName =
        (event.displayName != null && event.displayName!.trim().isNotEmpty)
        ? event.displayName!.trim()
        : Formatters.greetingName(event.email);

    if (event.uid == _currentUid && _reviewsSub != null) {
      if (resolvedName != _fallbackName && resolvedName.isNotEmpty) {
        _fallbackName = resolvedName;
        final currentProfile = state.profile;
        if (currentProfile != null && currentProfile.bio.isEmpty) {
          emit(
            state.copyWith(
              profile: currentProfile.copyWith(displayName: resolvedName),
            ),
          );
        }
      }
      return;
    }

    _profileSub?.cancel();
    _reviewsSub?.cancel();
    _allUsersSub?.cancel();
    _adminUidsSub?.cancel();
    _moderatorUidsSub?.cancel();
    _pollSub?.cancel();
    _challengeSub?.cancel();
    _listsSub?.cancel();
    _profileSub = null;
    _reviewsSub = null;
    _allUsersSub = null;
    _adminUidsSub = null;
    _moderatorUidsSub = null;
    _pollSub = null;
    _challengeSub = null;
    _listsSub = null;
    _lastReactionAt = null;
    _pendingReactionIds.clear();
    _currentUid = event.uid;
    _fallbackName = resolvedName;

    final uid = event.uid;
    if (uid == null) {
      emit(const CommunityState(status: CommunityStatus.loaded));
      return;
    }

    emit(
      state.copyWith(
        status: CommunityStatus.loading,
        profile: UserProfileModel(
          uid: uid,
          displayName: _fallbackName ?? 'Movie Fan',
        ),
        clearError: true,
        clearFeedback: true,
      ),
    );

    _startUserStreams(uid);
  }

  Future<void> _onRefreshed(
    CommunityRefreshed event,
    Emitter<CommunityState> emit,
  ) async {
    final uid = _currentUid;
    if (uid == null) return;
    _cancelUserStreams();
    _startUserStreams(uid);
  }

  void _cancelUserStreams() {
    _profileSub?.cancel();
    _reviewsSub?.cancel();
    _allUsersSub?.cancel();
    _adminUidsSub?.cancel();
    _moderatorUidsSub?.cancel();
    _pollSub?.cancel();
    _challengeSub?.cancel();
    _listsSub?.cancel();
    _profileSub = null;
    _reviewsSub = null;
    _allUsersSub = null;
    _adminUidsSub = null;
    _moderatorUidsSub = null;
    _pollSub = null;
    _challengeSub = null;
    _listsSub = null;
  }

  void _startUserStreams(String uid) {
    _profileSub = _repository.watchProfile(uid).listen((profile) {
      if (!isClosed) add(_CommunityProfileReceived(profile));
    });

    try {
      _allUsersSub = _repository.watchAllUsers().listen((users) {
        if (!isClosed) add(_CommunityAllUsersReceived(users));
      }, onError: (_) {});
    } catch (_) {}

    try {
      _adminUidsSub = _repository.watchAdminUids().listen((uids) {
        if (!isClosed) add(_CommunityAdminUidsReceived(uids));
      }, onError: (_) {});
    } catch (_) {}

    try {
      _moderatorUidsSub = _repository.watchModeratorUids().listen((uids) {
        if (!isClosed) add(_CommunityModeratorUidsReceived(uids));
      }, onError: (_) {});
    } catch (_) {}

    try {
      _pollSub = _repository.watchPinnedPoll().listen((poll) {
        if (!isClosed) add(_CommunityPinnedPollReceived(poll));
      }, onError: (_) {});
    } catch (_) {}

    try {
      _challengeSub = _repository.watchActiveChallenge().listen((challenge) {
        if (!isClosed) add(_CommunityActiveChallengeReceived(challenge));
      }, onError: (_) {});
    } catch (_) {}

    try {
      _listsSub = _repository.watchCuratedLists().listen((lists) {
        if (!isClosed) add(_CommunityCuratedListsReceived(lists));
      }, onError: (_) {});
    } catch (_) {}

    Future<void>(() async {
      try {
        final admin = await _repository.isAdmin(uid);
        final moderator = await _repository.isModerator(uid);
        final banned = await _repository.isUserBanned(uid);
        if (!isClosed && _currentUid == uid) {
          add(
            _CommunityRolesResolved(
              uid: uid,
              isAdmin: admin,
              isModerator: moderator,
              isBanned: banned,
            ),
          );
        }
      } catch (_) {}
    });

    _reviewsSub = _repository.watchRecentReviews().listen(
      (reviews) {
        if (!isClosed) add(_CommunityReviewsReceived(reviews));
      },
      onError: (Object error) {
        if (!isClosed) {
          add(
            _CommunityReviewsLoadFailed(
              error is AppException
                  ? error.message
                  : 'Unable to load community feed. Check Firestore rules.',
            ),
          );
        }
      },
    );
  }

  void _onProfileReceived(
    _CommunityProfileReceived event,
    Emitter<CommunityState> emit,
  ) {
    if (event.profile != null) {
      emit(state.copyWith(profile: event.profile));
    }
  }

  void _onAllUsersReceived(
    _CommunityAllUsersReceived event,
    Emitter<CommunityState> emit,
  ) {
    final byUid = <String, UserProfileModel>{
      for (final u in event.users) u.uid: u,
    };
    emit(state.copyWith(userProfilesByUid: byUid));
  }

  void _onAdminUidsReceived(
    _CommunityAdminUidsReceived event,
    Emitter<CommunityState> emit,
  ) {
    emit(state.copyWith(adminUids: event.uids));
  }

  void _onModeratorUidsReceived(
    _CommunityModeratorUidsReceived event,
    Emitter<CommunityState> emit,
  ) {
    emit(state.copyWith(moderatorUids: event.uids));
  }

  void _onRolesResolved(
    _CommunityRolesResolved event,
    Emitter<CommunityState> emit,
  ) {
    if (_currentUid != event.uid) return;
    emit(
      state.copyWith(
        isAdmin: event.isAdmin,
        isModerator: event.isModerator,
        isBanned: event.isBanned,
      ),
    );
  }

  void _onReviewsReceived(
    _CommunityReviewsReceived event,
    Emitter<CommunityState> emit,
  ) {
    emit(
      state.copyWith(
        status: CommunityStatus.loaded,
        reviews: event.reviews,
        clearError: true,
      ),
    );
  }

  void _onReviewsLoadFailed(
    _CommunityReviewsLoadFailed event,
    Emitter<CommunityState> emit,
  ) {
    emit(
      state.copyWith(
        status: CommunityStatus.error,
        errorMessage: event.message,
      ),
    );
  }

  void _onFeedbackCleared(
    CommunityFeedbackCleared event,
    Emitter<CommunityState> emit,
  ) {
    emit(state.copyWith(clearFeedback: true, clearError: true));
  }

  Future<void> _onProfileUpdated(
    CommunityProfileUpdated event,
    Emitter<CommunityState> emit,
  ) async {
    final uid = _currentUid;
    if (uid == null) return;

    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      final updated = UserProfileModel(
        uid: uid,
        displayName: event.displayName.trim().isNotEmpty
            ? event.displayName.trim()
            : (_fallbackName ?? 'Movie Fan'),
        bio: event.bio.trim(),
        avatarKey: event.avatarKey,
        photoBase64: event.clearPhoto
            ? null
            : (event.photoBase64 ?? state.profile?.photoBase64),
        reputation: state.profile?.reputation ?? 0,
        followingUids: state.profile?.followingUids ?? const [],
        updatedAt: DateTime.now(),
      );
      await _repository.saveProfile(updated);
      emit(
        state.copyWith(
          profile: updated,
          isSubmitting: false,
          feedbackMessage: 'Profile updated.',
        ),
      );
    } on AppException catch (e) {
      emit(state.copyWith(isSubmitting: false, errorMessage: e.message));
    }
  }

  void _onSortChanged(
    CommunitySortChanged event,
    Emitter<CommunityState> emit,
  ) {
    emit(state.copyWith(sortOption: event.option));
  }

  void _onFollowingFilterToggled(
    CommunityFollowingFilterToggled event,
    Emitter<CommunityState> emit,
  ) {
    emit(state.copyWith(followingOnly: !state.followingOnly));
  }

  void _onSearchQueryChanged(
    CommunitySearchQueryChanged event,
    Emitter<CommunityState> emit,
  ) {
    emit(state.copyWith(searchQuery: event.query));
  }

  Future<void> _onFollowToggled(
    CommunityFollowToggled event,
    Emitter<CommunityState> emit,
  ) async {
    final uid = _currentUid;
    if (uid == null || uid == event.targetUid) return;

    final currentProfile = state.profile;
    final currentlyFollowing =
        currentProfile?.isFollowing(event.targetUid) ?? false;

    try {
      if (currentProfile == null || currentProfile.updatedAt == null) {
        final seeded = UserProfileModel(
          uid: uid,
          displayName: _fallbackName ?? 'Movie Fan',
          updatedAt: DateTime.now(),
        );
        await _repository.saveProfile(seeded);
      }
      await _repository.toggleFollowUser(
        currentUid: uid,
        targetUid: event.targetUid,
        currentlyFollowing: currentlyFollowing,
      );
    } on AppException catch (e) {
      emit(state.copyWith(errorMessage: e.message));
    }
  }

  Future<void> _onReviewSubmitted(
    CommunityReviewSubmitted event,
    Emitter<CommunityState> emit,
  ) async {
    final uid = _currentUid;
    if (uid == null) {
      emit(state.copyWith(errorMessage: 'Please sign in to post a review.'));
      return;
    }

    final profile =
        state.profile ??
        UserProfileModel(uid: uid, displayName: _fallbackName ?? 'Movie Fan');

    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      final review = MovieReviewModel(
        id: MovieReviewModel.docIdFor(event.movie.id, uid),
        movieId: event.movie.id,
        movieTitle: event.movie.title,
        posterPath: event.movie.posterPath,
        uid: uid,
        authorName: profile.displayName,
        authorAvatarKey: profile.avatarKey,
        rating: event.rating,
        comment: event.comment.trim(),
        hasSpoilers: event.hasSpoilers,
        isVerifiedWatch: event.isVerifiedWatch,
        createdAt: DateTime.now(),
      );
      await _repository.saveReview(review);
      emit(
        state.copyWith(
          isSubmitting: false,
          feedbackMessage: 'Published review for "${event.movie.title}".',
        ),
      );
    } on AppException catch (e) {
      emit(state.copyWith(isSubmitting: false, errorMessage: e.message));
    }
  }

  Future<void> _onReactionToggled(
    CommunityReactionToggled event,
    Emitter<CommunityState> emit,
  ) async {
    final uid = _currentUid;
    final review = event.review;
    if (uid == null || _pendingReactionIds.contains(review.id)) return;

    // Global 5-second cooldown across all reviews to prevent reaction spam.
    final now = _clock();
    final previousReactionAt = _lastReactionAt;
    if (previousReactionAt != null) {
      final elapsed = now.difference(previousReactionAt);
      if (elapsed < reactionCooldown) {
        final remainingSeconds =
            ((reactionCooldown.inMilliseconds - elapsed.inMilliseconds) / 1000)
                .ceil()
                .clamp(1, 5);
        emit(
          state.copyWith(
            feedbackMessage:
                'Please wait ${remainingSeconds}s before changing your reaction.',
          ),
        );
        return;
      }
    }

    _lastReactionAt = now;
    _pendingReactionIds.add(review.id);

    final prevReviews = state.reviews;
    final prevProfiles = state.userProfilesByUid;

    final likedBy = List<String>.from(review.likedBy);
    final dislikedBy = List<String>.from(review.dislikedBy);
    final wasLiked = likedBy.contains(uid);
    final wasDisliked = dislikedBy.contains(uid);

    int repDelta = 0;
    if (event.isLike) {
      if (wasLiked) {
        likedBy.remove(uid);
        repDelta = -10;
      } else {
        likedBy.add(uid);
        repDelta = 10;
        if (wasDisliked) {
          dislikedBy.remove(uid);
          repDelta += 5;
        }
      }
    } else {
      if (wasDisliked) {
        dislikedBy.remove(uid);
        repDelta = 5;
      } else {
        dislikedBy.add(uid);
        repDelta = -5;
        if (wasLiked) {
          likedBy.remove(uid);
          repDelta -= 10;
        }
      }
    }

    final updatedReview = review.copyWith(
      likedBy: likedBy,
      dislikedBy: dislikedBy,
    );
    final updatedReviews = [
      for (final item in prevReviews)
        if (item.id == review.id) updatedReview else item,
    ];

    var updatedProfiles = prevProfiles;
    if (review.uid != uid &&
        repDelta != 0 &&
        prevProfiles.containsKey(review.uid)) {
      final author = prevProfiles[review.uid]!;
      updatedProfiles = Map<String, UserProfileModel>.from(prevProfiles)
        ..[review.uid] = author.copyWith(
          reputation: (author.reputation + repDelta).clamp(0, 999999),
        );
    }

    // Emit optimistically so heart/thumb state, counts, and karma respond immediately.
    emit(
      state.copyWith(
        reviews: updatedReviews,
        userProfilesByUid: updatedProfiles,
      ),
    );

    try {
      if (event.isLike) {
        await _repository.toggleReviewLike(
          reviewId: review.id,
          uid: uid,
          currentlyLiked: wasLiked,
        );
      } else {
        await _repository.toggleReviewDislike(
          reviewId: review.id,
          uid: uid,
          currentlyDisliked: wasDisliked,
        );
      }
    } on AppException catch (e) {
      _lastReactionAt = previousReactionAt;
      if (!isClosed) {
        emit(
          state.copyWith(
            reviews: prevReviews,
            userProfilesByUid: prevProfiles,
            errorMessage: e.message,
          ),
        );
      }
    } finally {
      _pendingReactionIds.remove(review.id);
    }
  }

  Future<void> _onReviewReported(
    CommunityReviewReported event,
    Emitter<CommunityState> emit,
  ) async {
    final uid = _currentUid;
    if (uid == null) return;
    try {
      final report = ReviewReportModel(
        id: ReviewReportModel.docIdFor(event.review.id, uid),
        reviewId: event.review.id,
        reportedUid: event.review.uid,
        reportedAuthorName: event.review.authorName,
        movieTitle: event.review.movieTitle,
        reviewComment: event.review.comment,
        reporterUid: uid,
        reason: event.reason,
        details: event.details,
        createdAt: DateTime.now(),
      );
      await _repository.submitReport(report);
      emit(
        state.copyWith(
          feedbackMessage:
              'Report submitted. Thank you for keeping CineList safe.',
          clearError: true,
        ),
      );
    } on AppException catch (e) {
      emit(state.copyWith(errorMessage: e.message));
    }
  }

  Future<void> _onReviewDeleted(
    CommunityReviewDeleted event,
    Emitter<CommunityState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      await _repository.deleteReview(event.reviewId);
      emit(
        state.copyWith(isSubmitting: false, feedbackMessage: 'Review deleted.'),
      );
    } on AppException catch (e) {
      emit(state.copyWith(isSubmitting: false, errorMessage: e.message));
    }
  }

  void _onPinnedPollReceived(
    _CommunityPinnedPollReceived event,
    Emitter<CommunityState> emit,
  ) {
    emit(
      state.copyWith(
        pinnedPoll: event.poll,
        clearPinnedPoll: event.poll == null,
      ),
    );
  }

  void _onCuratedListsReceived(
    _CommunityCuratedListsReceived event,
    Emitter<CommunityState> emit,
  ) {
    emit(state.copyWith(curatedLists: event.lists));
  }

  Future<void> _onPollVoted(
    CommunityPollVoted event,
    Emitter<CommunityState> emit,
  ) async {
    final uid = _currentUid;
    final poll = state.pinnedPoll;
    if (uid == null || poll == null || poll.id != event.pollId) return;
    if (event.optionIndex < 0 || event.optionIndex >= poll.options.length) {
      return;
    }

    final prevVotes = Map<String, int>.from(poll.votesByUid);
    if (prevVotes[uid] == event.optionIndex) return;

    final nextVotes = Map<String, int>.from(prevVotes)
      ..[uid] = event.optionIndex;
    emit(state.copyWith(pinnedPoll: poll.copyWith(votesByUid: nextVotes)));

    try {
      await _repository.voteOnPoll(
        pollId: poll.id,
        uid: uid,
        optionIndex: event.optionIndex,
      );
    } on AppException catch (e) {
      if (!isClosed) {
        emit(
          state.copyWith(
            pinnedPoll: poll.copyWith(votesByUid: prevVotes),
            errorMessage: e.message,
          ),
        );
      }
    }
  }

  Future<void> _onCuratedListPublished(
    CommunityCuratedListPublished event,
    Emitter<CommunityState> emit,
  ) async {
    final uid = _currentUid;
    if (uid == null) {
      emit(state.copyWith(errorMessage: 'Please sign in to share a list.'));
      return;
    }
    if (event.movies.isEmpty) {
      emit(state.copyWith(errorMessage: 'Add movies to this list first.'));
      return;
    }

    final profile =
        state.profile ??
        UserProfileModel(uid: uid, displayName: _fallbackName ?? 'Movie Fan');

    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      final list = CuratedListModel(
        id: event.collectionId != null
            ? CuratedListModel.docIdFor(uid, event.collectionId!)
            : '',
        collectionId: event.collectionId,
        title: event.title.trim(),
        description: event.description.trim(),
        authorUid: uid,
        authorName: profile.displayName,
        authorAvatarKey: profile.avatarKey,
        movies: event.movies,
        createdAt: DateTime.now(),
      );
      await _repository.publishCuratedList(list);
      emit(
        state.copyWith(
          isSubmitting: false,
          feedbackMessage: 'Published "${list.title}" to Community Lists.',
        ),
      );
    } on AppException catch (e) {
      emit(state.copyWith(isSubmitting: false, errorMessage: e.message));
    }
  }

  Future<void> _onCuratedListMoviesSynced(
    CommunityCuratedListMoviesSynced event,
    Emitter<CommunityState> emit,
  ) async {
    final uid = _currentUid;
    if (uid == null || event.movies.isEmpty) return;

    final prevLists = state.curatedLists;
    final updatedLists = [
      for (final item in prevLists)
        if (item.id == event.listId && item.authorUid == uid)
          item.copyWith(movies: event.movies)
        else
          item,
    ];
    emit(state.copyWith(curatedLists: updatedLists));

    try {
      await _repository.syncCuratedListMovies(
        listId: event.listId,
        movies: event.movies,
      );
    } on AppException catch (e) {
      if (!isClosed) {
        emit(state.copyWith(curatedLists: prevLists, errorMessage: e.message));
      }
    }
  }

  Future<void> _onCuratedListLikeToggled(
    CommunityCuratedListLikeToggled event,
    Emitter<CommunityState> emit,
  ) async {
    final uid = _currentUid;
    if (uid == null) return;

    final list = event.list;
    final wasLiked = list.isLikedBy(uid);
    final nextLikes = List<String>.from(list.likedBy);
    if (wasLiked) {
      nextLikes.remove(uid);
    } else {
      nextLikes.add(uid);
    }

    final prevLists = state.curatedLists;
    final updatedLists = [
      for (final item in prevLists)
        if (item.id == list.id) list.copyWith(likedBy: nextLikes) else item,
    ];
    emit(state.copyWith(curatedLists: updatedLists));

    try {
      await _repository.toggleCuratedListLike(
        listId: list.id,
        uid: uid,
        currentlyLiked: wasLiked,
      );
    } on AppException catch (e) {
      if (!isClosed) {
        emit(state.copyWith(curatedLists: prevLists, errorMessage: e.message));
      }
    }
  }

  Future<void> _onCuratedListDeleted(
    CommunityCuratedListDeleted event,
    Emitter<CommunityState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      await _repository.deleteCuratedList(event.listId);
      emit(
        state.copyWith(
          isSubmitting: false,
          feedbackMessage: 'Curated list removed.',
        ),
      );
    } on AppException catch (e) {
      emit(state.copyWith(isSubmitting: false, errorMessage: e.message));
    }
  }

  void _onActiveChallengeReceived(
    _CommunityActiveChallengeReceived event,
    Emitter<CommunityState> emit,
  ) {
    emit(
      state.copyWith(
        activeChallenge: event.challenge,
        clearActiveChallenge: event.challenge == null,
      ),
    );
  }

  Future<void> _onChallengeCompleted(
    CommunityChallengeCompleted event,
    Emitter<CommunityState> emit,
  ) async {
    final uid = _currentUid;
    if (uid == null) return;
    final challenge = state.activeChallenge;
    if (challenge == null || challenge.id != event.challengeId) return;
    if (challenge.isCompletedBy(uid)) return;

    try {
      final completed = await _repository.completeWeeklyChallenge(
        challengeId: event.challengeId,
        uid: uid,
      );
      if (completed) {
        emit(
          state.copyWith(
            feedbackMessage:
                'Watch Party completed! +${challenge.bonusPoints} bonus rep earned.',
            clearError: true,
          ),
        );
      }
    } on AppException catch (e) {
      emit(state.copyWith(errorMessage: e.message));
    }
  }

  Future<UserProfileModel?> fetchUserProfile(String uid) async {
    try {
      return await _repository.getProfile(uid);
    } catch (_) {
      return null;
    }
  }

  Future<bool> checkIsAdmin(String uid) async {
    try {
      return await _repository.isAdmin(uid);
    } catch (_) {
      return false;
    }
  }

  Future<bool> checkIsModerator(String uid) async {
    try {
      return await _repository.isModerator(uid);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> close() {
    _profileSub?.cancel();
    _reviewsSub?.cancel();
    _allUsersSub?.cancel();
    _adminUidsSub?.cancel();
    _moderatorUidsSub?.cancel();
    _pollSub?.cancel();
    _challengeSub?.cancel();
    _listsSub?.cancel();
    return super.close();
  }
}
