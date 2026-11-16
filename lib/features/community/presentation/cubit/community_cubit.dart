import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/movie_summary.dart';
import '../../data/models/movie_review_model.dart';
import '../../data/models/user_profile_model.dart';
import '../../data/repositories/community_repository.dart';
import 'community_state.dart';

/// Manages the user's community profile (bio, avatar) and public movie reviews.
class CommunityCubit extends Cubit<CommunityState> {
  CommunityCubit(this._repository) : super(const CommunityState());

  final CommunityRepository _repository;
  StreamSubscription<UserProfileModel?>? _profileSub;
  StreamSubscription<List<MovieReviewModel>>? _reviewsSub;
  String? _currentUid;
  String? _fallbackName;

  void bindUser({required String? uid, String? email}) {
    if (uid == _currentUid && _reviewsSub != null) return;

    _profileSub?.cancel();
    _reviewsSub?.cancel();
    _profileSub = null;
    _reviewsSub = null;
    _currentUid = uid;
    _fallbackName = Formatters.greetingName(email);

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

  Future<UserProfileModel?> fetchUserProfile(String uid) async {
    try {
      return await _repository.getProfile(uid);
    } catch (_) {
      return null;
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
    return super.close();
  }
}
