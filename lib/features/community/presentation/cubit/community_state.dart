import 'package:equatable/equatable.dart';

import '../../data/models/community_poll_model.dart';
import '../../data/models/curated_list_model.dart';
import '../../data/models/movie_review_model.dart';
import '../../data/models/user_profile_model.dart';
import '../../data/models/weekly_challenge_model.dart';

enum CommunityStatus { initial, loading, loaded, error }

enum CommunitySortOption {
  latest('Latest'),
  mostHelpful('Most Helpful'),
  highestRated('Highest Rated');

  const CommunitySortOption(this.label);

  final String label;
}

class CommunityState extends Equatable {
  const CommunityState({
    this.status = CommunityStatus.initial,
    this.profile,
    this.reviews = const [],
    this.userProfilesByUid = const {},
    this.adminUids = const {},
    this.moderatorUids = const {},
    this.pinnedPoll,
    this.activeChallenge,
    this.curatedLists = const [],
    this.sortOption = CommunitySortOption.latest,
    this.followingOnly = false,
    this.searchQuery = '',
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
  final CommunityPollModel? pinnedPoll;
  final WeeklyChallengeModel? activeChallenge;
  final List<CuratedListModel> curatedLists;
  final CommunitySortOption sortOption;
  final bool followingOnly;
  final String searchQuery;
  final bool isAdmin;
  final bool isModerator;
  final bool isBanned;
  final bool isSubmitting;
  final String? errorMessage;
  final String? feedbackMessage;

  bool get isStaff => isAdmin || isModerator;

  List<MovieReviewModel> reviewsForMovie(int movieId) {
    return reviews.where((r) => r.movieId == movieId).toList();
  }

  List<MovieReviewModel> get filteredReviews {
    final following = profile?.followingUids.toSet() ?? const <String>{};
    final query = searchQuery.trim().toLowerCase();

    var list = reviews.where((r) {
      if (followingOnly && !following.contains(r.uid)) return false;
      if (query.isNotEmpty) {
        final inMovie = r.movieTitle.toLowerCase().contains(query);
        final inAuthor = r.authorName.toLowerCase().contains(query);
        final inComment = r.comment.toLowerCase().contains(query);
        if (!inMovie && !inAuthor && !inComment) return false;
      }
      return true;
    }).toList();

    switch (sortOption) {
      case CommunitySortOption.latest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case CommunitySortOption.mostHelpful:
        list.sort((a, b) {
          final scoreA = a.likedBy.length - a.dislikedBy.length;
          final scoreB = b.likedBy.length - b.dislikedBy.length;
          final cmp = scoreB.compareTo(scoreA);
          return cmp != 0 ? cmp : b.createdAt.compareTo(a.createdAt);
        });
      case CommunitySortOption.highestRated:
        list.sort((a, b) {
          final cmp = b.rating.compareTo(a.rating);
          return cmp != 0 ? cmp : b.createdAt.compareTo(a.createdAt);
        });
    }

    return list;
  }

  List<UserProfileModel> get topCritics {
    final list = userProfilesByUid.values
        .where((u) => u.reputation > 0)
        .toList();
    list.sort((a, b) => b.reputation.compareTo(a.reputation));
    return list.take(8).toList();
  }

  List<UserProfileModel> get leaderboard {
    final list = userProfilesByUid.values.toList();
    list.sort((a, b) {
      final repCmp = b.reputation.compareTo(a.reputation);
      if (repCmp != 0) return repCmp;
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });
    return list;
  }

  CommunityState copyWith({
    CommunityStatus? status,
    UserProfileModel? profile,
    bool clearProfile = false,
    List<MovieReviewModel>? reviews,
    Map<String, UserProfileModel>? userProfilesByUid,
    Set<String>? adminUids,
    Set<String>? moderatorUids,
    CommunityPollModel? pinnedPoll,
    bool clearPinnedPoll = false,
    WeeklyChallengeModel? activeChallenge,
    bool clearActiveChallenge = false,
    List<CuratedListModel>? curatedLists,
    CommunitySortOption? sortOption,
    bool? followingOnly,
    String? searchQuery,
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
      pinnedPoll: clearPinnedPoll ? null : (pinnedPoll ?? this.pinnedPoll),
      activeChallenge: clearActiveChallenge
          ? null
          : (activeChallenge ?? this.activeChallenge),
      curatedLists: curatedLists ?? this.curatedLists,
      sortOption: sortOption ?? this.sortOption,
      followingOnly: followingOnly ?? this.followingOnly,
      searchQuery: searchQuery ?? this.searchQuery,
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
    pinnedPoll,
    activeChallenge,
    curatedLists,
    sortOption,
    followingOnly,
    searchQuery,
    isAdmin,
    isModerator,
    isBanned,
    isSubmitting,
    errorMessage,
    feedbackMessage,
  ];
}
