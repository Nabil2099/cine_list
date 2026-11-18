part of 'community_bloc.dart';

sealed class CommunityEvent extends Equatable {
  const CommunityEvent();

  @override
  List<Object?> get props => [];
}

final class CommunityUserBound extends CommunityEvent {
  const CommunityUserBound({
    required this.uid,
    this.email,
    this.displayName,
  });

  final String? uid;
  final String? email;
  final String? displayName;

  @override
  List<Object?> get props => [uid, email, displayName];
}

final class CommunityFeedbackCleared extends CommunityEvent {
  const CommunityFeedbackCleared();
}

final class CommunityProfileUpdated extends CommunityEvent {
  const CommunityProfileUpdated({
    required this.displayName,
    required this.bio,
    required this.avatarKey,
    this.photoBase64,
    this.clearPhoto = false,
  });

  final String displayName;
  final String bio;
  final String avatarKey;
  final String? photoBase64;
  final bool clearPhoto;

  @override
  List<Object?> get props => [
    displayName,
    bio,
    avatarKey,
    photoBase64,
    clearPhoto,
  ];
}

final class CommunitySortChanged extends CommunityEvent {
  const CommunitySortChanged(this.option);

  final CommunitySortOption option;

  @override
  List<Object?> get props => [option];
}

final class CommunityFollowingFilterToggled extends CommunityEvent {
  const CommunityFollowingFilterToggled();
}

final class CommunitySearchQueryChanged extends CommunityEvent {
  const CommunitySearchQueryChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

final class CommunityFollowToggled extends CommunityEvent {
  const CommunityFollowToggled(this.targetUid);

  final String targetUid;

  @override
  List<Object?> get props => [targetUid];
}

final class CommunityReviewSubmitted extends CommunityEvent {
  const CommunityReviewSubmitted({
    required this.movie,
    required this.rating,
    required this.comment,
    this.hasSpoilers = false,
    this.isVerifiedWatch = false,
  });

  final MovieSummary movie;
  final int rating;
  final String comment;
  final bool hasSpoilers;
  final bool isVerifiedWatch;

  @override
  List<Object?> get props => [
    movie,
    rating,
    comment,
    hasSpoilers,
    isVerifiedWatch,
  ];
}

final class CommunityReactionToggled extends CommunityEvent {
  const CommunityReactionToggled({
    required this.review,
    required this.isLike,
  });

  final MovieReviewModel review;
  final bool isLike;

  @override
  List<Object?> get props => [review, isLike];
}

final class CommunityReviewReported extends CommunityEvent {
  const CommunityReviewReported({
    required this.review,
    required this.reason,
    this.details = '',
  });

  final MovieReviewModel review;
  final ReportReason reason;
  final String details;

  @override
  List<Object?> get props => [review, reason, details];
}

final class CommunityReviewDeleted extends CommunityEvent {
  const CommunityReviewDeleted(this.reviewId);

  final String reviewId;

  @override
  List<Object?> get props => [reviewId];
}

final class _CommunityProfileReceived extends CommunityEvent {
  const _CommunityProfileReceived(this.profile);

  final UserProfileModel? profile;

  @override
  List<Object?> get props => [profile];
}

final class _CommunityAllUsersReceived extends CommunityEvent {
  const _CommunityAllUsersReceived(this.users);

  final List<UserProfileModel> users;

  @override
  List<Object?> get props => [users];
}

final class _CommunityAdminUidsReceived extends CommunityEvent {
  const _CommunityAdminUidsReceived(this.uids);

  final Set<String> uids;

  @override
  List<Object?> get props => [uids];
}

final class _CommunityModeratorUidsReceived extends CommunityEvent {
  const _CommunityModeratorUidsReceived(this.uids);

  final Set<String> uids;

  @override
  List<Object?> get props => [uids];
}

final class _CommunityRolesResolved extends CommunityEvent {
  const _CommunityRolesResolved({
    required this.uid,
    required this.isAdmin,
    required this.isModerator,
    required this.isBanned,
  });

  final String uid;
  final bool isAdmin;
  final bool isModerator;
  final bool isBanned;

  @override
  List<Object?> get props => [uid, isAdmin, isModerator, isBanned];
}

final class _CommunityReviewsReceived extends CommunityEvent {
  const _CommunityReviewsReceived(this.reviews);

  final List<MovieReviewModel> reviews;

  @override
  List<Object?> get props => [reviews];
}

final class _CommunityReviewsLoadFailed extends CommunityEvent {
  const _CommunityReviewsLoadFailed(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

