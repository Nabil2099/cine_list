import 'package:equatable/equatable.dart';

import '../../data/models/movie_review_model.dart';
import '../../data/models/user_profile_model.dart';

enum CommunityStatus { initial, loading, loaded, error }

class CommunityState extends Equatable {
  const CommunityState({
    this.status = CommunityStatus.initial,
    this.profile,
    this.reviews = const [],
    this.userProfilesByUid = const {},
    this.adminUids = const {},
    this.moderatorUids = const {},
    this.isAdmin = false,
    this.isModerator = false,
    this.isBanned = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.feedbackMessage,
  });

  final CommunityStatus status;
  final UserProfileModel? profile;
  final List<MovieReviewModel> reviews;
  final Map<String, UserProfileModel> userProfilesByUid;
  final Set<String> adminUids;
  final Set<String> moderatorUids;
  final bool isAdmin;
  final bool isModerator;
  final bool isBanned;
  final bool isSubmitting;

  bool get isStaff => isAdmin || isModerator;
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
    Map<String, UserProfileModel>? userProfilesByUid,
    Set<String>? adminUids,
    Set<String>? moderatorUids,
    bool? isAdmin,
    bool? isModerator,
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
      userProfilesByUid: userProfilesByUid ?? this.userProfilesByUid,
      adminUids: adminUids ?? this.adminUids,
      moderatorUids: moderatorUids ?? this.moderatorUids,
      isAdmin: isAdmin ?? this.isAdmin,
      isModerator: isModerator ?? this.isModerator,
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
    userProfilesByUid,
    adminUids,
    moderatorUids,
    isAdmin,
    isModerator,
    isBanned,
    isSubmitting,
    errorMessage,
    feedbackMessage,
  ];
}
