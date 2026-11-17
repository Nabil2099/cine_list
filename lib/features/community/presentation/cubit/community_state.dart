import 'package:equatable/equatable.dart';

import '../../data/models/movie_review_model.dart';
import '../../data/models/user_profile_model.dart';

enum CommunityStatus { initial, loading, loaded, error }

class CommunityState extends Equatable {
  const CommunityState({
    this.status = CommunityStatus.initial,
    this.profile,
    this.reviews = const [],
    this.isAdmin = false,
    this.isBanned = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.feedbackMessage,
  });

  final CommunityStatus status;
  final UserProfileModel? profile;
  final List<MovieReviewModel> reviews;
  final bool isAdmin;
  final bool isBanned;
  final bool isSubmitting;
  final String? errorMessage;
  final String? feedbackMessage;

  List<MovieReviewModel> reviewsForMovie(int movieId) {
    return reviews.where((r) => r.movieId == movieId).toList();
  }

  CommunityState copyWith({
    CommunityStatus? status,
    UserProfileModel? profile,
    bool clearProfile = false,
    List<MovieReviewModel>? reviews,
    bool? isAdmin,
    bool? isBanned,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
    String? feedbackMessage,
    bool clearFeedback = false,
  }) {
    return CommunityState(
      status: status ?? this.status,
      profile: clearProfile ? null : (profile ?? this.profile),
      reviews: reviews ?? this.reviews,
      isAdmin: isAdmin ?? this.isAdmin,
      isBanned: isBanned ?? this.isBanned,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      feedbackMessage: clearFeedback
          ? null
          : (feedbackMessage ?? this.feedbackMessage),
    );
  }

  @override
  List<Object?> get props => [
    status,
    profile,
    reviews,
    isAdmin,
    isBanned,
    isSubmitting,
    errorMessage,
    feedbackMessage,
  ];
}
