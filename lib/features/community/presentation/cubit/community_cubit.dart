import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/movie_summary.dart';
import '../../data/models/movie_review_model.dart';
import '../../data/models/review_report_model.dart';
import '../../data/models/user_profile_model.dart';
import '../../data/repositories/community_repository.dart';
import 'community_state.dart';

/// Manages the user's community profile (bio, avatar) and public movie reviews.
class CommunityCubit extends Cubit<CommunityState> {
  CommunityCubit(this._repository) : super(const CommunityState());

  final CommunityRepository _repository;
  StreamSubscription<UserProfileModel?>? _profileSub;
  StreamSubscription<List<MovieReviewModel>>? _reviewsSub;
  StreamSubscription<List<UserProfileModel>>? _allUsersSub;
  StreamSubscription<Set<String>>? _adminUidsSub;
  StreamSubscription<Set<String>>? _moderatorUidsSub;
  String? _currentUid;
  String? _fallbackName;

  void bindUser({required String? uid, String? email, String? displayName}) {
    final resolvedName = (displayName != null && displayName.trim().isNotEmpty)
        ? displayName.trim()
        : Formatters.greetingName(email);

    if (uid == _currentUid && _reviewsSub != null) {
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
    _profileSub = null;
    _reviewsSub = null;
    _allUsersSub = null;
    _adminUidsSub = null;
    _moderatorUidsSub = null;
    _currentUid = uid;
    _fallbackName = resolvedName;

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

    _profileSub = _repository.watchProfile(uid).listen((profile) {
      if (profile != null) {
        emit(state.copyWith(profile: profile));
      }
    });

    try {
      _allUsersSub = _repository.watchAllUsers().listen((users) {
        final byUid = <String, UserProfileModel>{
          for (final u in users) u.uid: u,
        };
        emit(state.copyWith(userProfilesByUid: byUid));
      }, onError: (_) {});
    } catch (_) {}

    try {
      _adminUidsSub = _repository.watchAdminUids().listen((uids) {
        emit(state.copyWith(adminUids: uids));
      }, onError: (_) {});
    } catch (_) {}

    try {
      _moderatorUidsSub = _repository.watchModeratorUids().listen((uids) {
        emit(state.copyWith(moderatorUids: uids));
      }, onError: (_) {});
    } catch (_) {}

    Future<void>(() async {
      try {
        final admin = await _repository.isAdmin(uid);
        final moderator = await _repository.isModerator(uid);
        final banned = await _repository.isUserBanned(uid);
        if (!isClosed && _currentUid == uid) {
          emit(
            state.copyWith(
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
        emit(
          state.copyWith(
            status: CommunityStatus.loaded,
            reviews: reviews,
            clearError: true,
          ),
        );
      },
      onError: (Object error) {
        emit(
          state.copyWith(
            status: CommunityStatus.error,
            errorMessage: error is AppException
                ? error.message
                : 'Unable to load community feed. Check Firestore rules.',
          ),
        );
      },
    );
  }

  void clearFeedback() {
    emit(state.copyWith(clearFeedback: true, clearError: true));
  }

  Future<void> updateProfile({
    required String displayName,
    required String bio,
    required String avatarKey,
    String? photoBase64,
    bool clearPhoto = false,
  }) async {
    final uid = _currentUid;
    if (uid == null) return;

    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      final updated = UserProfileModel(
        uid: uid,
        displayName: displayName.trim().isNotEmpty
            ? displayName.trim()
            : (_fallbackName ?? 'Movie Fan'),
        bio: bio.trim(),
        avatarKey: avatarKey,
        photoBase64: clearPhoto ? null : (photoBase64 ?? state.profile?.photoBase64),
        reputation: state.profile?.reputation ?? 0,
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

  Future<void> submitReview({
    required MovieSummary movie,
    required int rating,
    required String comment,
  }) async {
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
        id: MovieReviewModel.docIdFor(movie.id, uid),
        movieId: movie.id,
        movieTitle: movie.title,
        posterPath: movie.posterPath,
        uid: uid,
        authorName: profile.displayName,
        authorAvatarKey: profile.avatarKey,
        rating: rating,
        comment: comment.trim(),
        createdAt: DateTime.now(),
      );
      await _repository.saveReview(review);
      emit(
        state.copyWith(
          isSubmitting: false,
          feedbackMessage: 'Published review for "${movie.title}".',
        ),
      );
    } on AppException catch (e) {
      emit(state.copyWith(isSubmitting: false, errorMessage: e.message));
    }
  }

  Future<void> toggleLike(MovieReviewModel review) async {
    final uid = _currentUid;
    if (uid == null) return;
    try {
      await _repository.toggleReviewLike(
        reviewId: review.id,
        uid: uid,
        currentlyLiked: review.isLikedBy(uid),
      );
    } on AppException catch (e) {
      emit(state.copyWith(errorMessage: e.message));
    }
  }

  Future<void> toggleDislike(MovieReviewModel review) async {
    final uid = _currentUid;
    if (uid == null) return;
    try {
      await _repository.toggleReviewDislike(
        reviewId: review.id,
        uid: uid,
        currentlyDisliked: review.isDislikedBy(uid),
      );
    } on AppException catch (e) {
      emit(state.copyWith(errorMessage: e.message));
    }
  }

  Future<void> reportReview({
    required MovieReviewModel review,
    required ReportReason reason,
    String details = '',
  }) async {
    final uid = _currentUid;
    if (uid == null) return;
    try {
      final report = ReviewReportModel(
        id: ReviewReportModel.docIdFor(review.id, uid),
        reviewId: review.id,
        reportedUid: review.uid,
        reportedAuthorName: review.authorName,
        movieTitle: review.movieTitle,
        reviewComment: review.comment,
        reporterUid: uid,
        reason: reason,
        details: details,
        createdAt: DateTime.now(),
      );
      await _repository.submitReport(report);
      emit(
        state.copyWith(
          feedbackMessage: 'Report submitted. Thank you for keeping CineList safe.',
          clearError: true,
        ),
      );
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

  Future<void> deleteReview(String reviewId) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      await _repository.deleteReview(reviewId);
      emit(
        state.copyWith(isSubmitting: false, feedbackMessage: 'Review deleted.'),
      );
    } on AppException catch (e) {
      emit(state.copyWith(isSubmitting: false, errorMessage: e.message));
    }
  }

  @override
  Future<void> close() {
    _profileSub?.cancel();
    _reviewsSub?.cancel();
    _allUsersSub?.cancel();
    _adminUidsSub?.cancel();
    _moderatorUidsSub?.cancel();
    return super.close();
  }
}
