import 'package:equatable/equatable.dart';

import '../../data/models/app_notification_model.dart';
import '../../data/models/community_movie_spotlight.dart';
import '../../data/models/community_poll_model.dart';
import '../../data/models/curated_list_model.dart';
import '../../data/models/movie_review_model.dart';
import '../../data/models/user_profile_model.dart';
import '../../data/models/weekly_challenge_model.dart';

enum CommunityStatus { initial, loading, loaded, error }

enum CommunitySortOption {
  curated('Curated'),
  mostHelpful('Most Helpful'),
  highestRated('Highest Rated'),
  latest('Recent');

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
    this.notifications = const [],
    this.sortOption = CommunitySortOption.curated,
    this.followingOnly = false,
    this.searchQuery = '',
    this.isAdmin = false,
    this.isModerator = false,
    this.isBanned = false,
    this.isSubmitting = false,
    this.requiresSignInToRead = false,
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
  final List<AppNotificationModel> notifications;
  final CommunitySortOption sortOption;
  final bool followingOnly;
  final String searchQuery;
  final bool isAdmin;
  final bool isModerator;
  final bool isBanned;
  final bool isSubmitting;
  final bool requiresSignInToRead;
  final String? errorMessage;
  final String? feedbackMessage;

  bool get isStaff => isAdmin || isModerator;

  int get unreadNotificationCount =>
      notifications.where((n) => !n.isRead).length;

  /// Whether [review] contains enough commentary or community engagement
  /// to surface in Curated mode instead of being hidden as a bare raw rating.
  static bool isSubstantiveReview(MovieReviewModel review) {
    return review.comment.trim().length >= 20 ||
        review.likedBy.isNotEmpty ||
        review.replyCount > 0;
  }

  /// Deterministic Letterboxd-inspired quality + engagement + recency score.
  static double curationScore(
    MovieReviewModel review, {
    DateTime? referenceTime,
  }) {
    final netVotes = review.likedBy.length - review.dislikedBy.length;
    final length = review.comment.trim().length;
    final double lengthBonus;
    if (length >= 120) {
      lengthBonus = 4.0;
    } else if (length >= 45) {
      lengthBonus = 2.5;
    } else if (length >= 20) {
      lengthBonus = 1.0;
    } else {
      lengthBonus = -2.0;
    }
    final verifiedBonus = review.isVerifiedWatch ? 2.5 : 0.0;
    final replyBonus = review.replyCount * 2.0;
    final ref = referenceTime ?? review.createdAt;
    final ageDays =
        ref.difference(review.createdAt).inHours.clamp(0, 24 * 60) / 24.0;
    final recencyBonus = 3.0 / (1.0 + (ageDays / 7.0));
    return (netVotes * 3.0) +
        replyBonus +
        verifiedBonus +
        lengthBonus +
        recencyBonus;
  }

  DateTime? get _newestReviewTimestamp {
    if (reviews.isEmpty) return null;
    var newest = reviews.first.createdAt;
    for (final r in reviews.skip(1)) {
      if (r.createdAt.isAfter(newest)) newest = r.createdAt;
    }
    return newest;
  }

  bool get _shouldFilterRawReviews {
    if (reviews.length < 5) return false;
    return reviews.where(isSubstantiveReview).length >= 3;
  }

  int get hiddenRawReviewsCount {
    if (sortOption != CommunitySortOption.curated ||
        searchQuery.trim().isNotEmpty ||
        followingOnly ||
        !_shouldFilterRawReviews) {
      return 0;
    }
    return reviews.where((r) => !isSubstantiveReview(r)).length;
  }

  List<MovieReviewModel> reviewsForMovie(
    int movieId, {
    bool sortByCurated = true,
  }) {
    final list = reviews.where((r) => r.movieId == movieId).toList();
    if (list.length <= 1) return list;

    if (sortByCurated) {
      var newest = list.first.createdAt;
      for (final r in list.skip(1)) {
        if (r.createdAt.isAfter(newest)) newest = r.createdAt;
      }
      list.sort((a, b) {
        final cmp = curationScore(
          b,
          referenceTime: newest,
        ).compareTo(curationScore(a, referenceTime: newest));
        return cmp != 0 ? cmp : b.createdAt.compareTo(a.createdAt);
      });
    } else {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return list;
  }

  /// Top-rated films aggregated from CineList community reviews using
  /// Bayesian smoothing so single-review outliers don't drown consensus hits.
  List<CommunityMovieSpotlight> get topRatedCommunityMovies {
    if (reviews.isEmpty) return const [];

    final buckets =
        <
          int,
          ({
            String title,
            String? posterPath,
            int sumRating,
            int count,
            int totalLikes,
            DateTime latest,
          })
        >{};

    for (final r in reviews) {
      if (r.movieId <= 0) continue;
      final existing = buckets[r.movieId];
      if (existing == null) {
        buckets[r.movieId] = (
          title: r.movieTitle,
          posterPath: r.posterPath,
          sumRating: r.rating,
          count: 1,
          totalLikes: r.likedBy.length,
          latest: r.createdAt,
        );
      } else {
        buckets[r.movieId] = (
          title: existing.title,
          posterPath: existing.posterPath ?? r.posterPath,
          sumRating: existing.sumRating + r.rating,
          count: existing.count + 1,
          totalLikes: existing.totalLikes + r.likedBy.length,
          latest: r.createdAt.isAfter(existing.latest)
              ? r.createdAt
              : existing.latest,
        );
      }
    }

    final scored =
        <({CommunityMovieSpotlight spotlight, double rankScore})>[];
    for (final entry in buckets.entries) {
      final v = entry.value;
      final avg = v.sumRating / v.count;
      // Prior of 3.5 across 2 virtual votes + mild engagement tie-breaker.
      final bayesian = ((v.sumRating + 7.0) / (v.count + 2.0)) +
          (v.totalLikes * 0.02);
      scored.add((
        spotlight: CommunityMovieSpotlight(
          movieId: entry.key,
          movieTitle: v.title,
          posterPath: v.posterPath,
          averageRating: avg,
          reviewCount: v.count,
          totalLikes: v.totalLikes,
          latestReviewedAt: v.latest,
        ),
        rankScore: bayesian,
      ));
    }

    scored.sort((a, b) {
      final scoreCmp = b.rankScore.compareTo(a.rankScore);
      if (scoreCmp != 0) return scoreCmp;
      final countCmp = b.spotlight.reviewCount.compareTo(
        a.spotlight.reviewCount,
      );
      if (countCmp != 0) return countCmp;
      return b.spotlight.latestReviewedAt.compareTo(
        a.spotlight.latestReviewedAt,
      );
    });

    return scored.take(10).map((e) => e.spotlight).toList();
  }

  /// Up to 3 standout reviews across distinct films for the Community spotlight.
  List<MovieReviewModel> get featuredReviews {
    if (reviews.isEmpty) return const [];
    final ref = _newestReviewTimestamp;
    final substantive = reviews.where(isSubstantiveReview).toList();
    final pool = substantive.isNotEmpty
        ? substantive
        : List<MovieReviewModel>.from(reviews);

    pool.sort((a, b) {
      final cmp = curationScore(
        b,
        referenceTime: ref,
      ).compareTo(curationScore(a, referenceTime: ref));
      return cmp != 0 ? cmp : b.createdAt.compareTo(a.createdAt);
    });

    final picked = <MovieReviewModel>[];
    final seenMovies = <int>{};
    for (final r in pool) {
      if (seenMovies.add(r.movieId)) {
        picked.add(r);
        if (picked.length == 3) return picked;
      }
    }
    for (final r in pool) {
      if (!picked.contains(r)) {
        picked.add(r);
        if (picked.length == 3) break;
      }
    }
    return picked;
  }

  List<MovieReviewModel> get filteredReviews {
    final following = profile?.followingUids.toSet() ?? const <String>{};
    final query = searchQuery.trim().toLowerCase();
    final filterRawInCurated =
        sortOption == CommunitySortOption.curated &&
        query.isEmpty &&
        !followingOnly &&
        _shouldFilterRawReviews;

    var list = reviews.where((r) {
      if (followingOnly && !following.contains(r.uid)) return false;
      if (filterRawInCurated && !isSubstantiveReview(r)) return false;
      if (query.isNotEmpty) {
        final inMovie = r.movieTitle.toLowerCase().contains(query);
        final inAuthor = r.authorName.toLowerCase().contains(query);
        final inComment = r.comment.toLowerCase().contains(query);
        if (!inMovie && !inAuthor && !inComment) return false;
      }
      return true;
    }).toList();

    switch (sortOption) {
      case CommunitySortOption.curated:
        final ref = _newestReviewTimestamp;
        list.sort((a, b) {
          final cmp = curationScore(
            b,
            referenceTime: ref,
          ).compareTo(curationScore(a, referenceTime: ref));
          return cmp != 0 ? cmp : b.createdAt.compareTo(a.createdAt);
        });
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
    List<AppNotificationModel>? notifications,
    CommunitySortOption? sortOption,
    bool? followingOnly,
    String? searchQuery,
    bool? isAdmin,
    bool? isModerator,
    bool? isBanned,
    bool? isSubmitting,
    bool? requiresSignInToRead,
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
      notifications: notifications ?? this.notifications,
      sortOption: sortOption ?? this.sortOption,
      followingOnly: followingOnly ?? this.followingOnly,
      searchQuery: searchQuery ?? this.searchQuery,
      isAdmin: isAdmin ?? this.isAdmin,
      isModerator: isModerator ?? this.isModerator,
      isBanned: isBanned ?? this.isBanned,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      requiresSignInToRead: requiresSignInToRead ?? this.requiresSignInToRead,
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
    notifications,
    sortOption,
    followingOnly,
    searchQuery,
    isAdmin,
    isModerator,
    isBanned,
    isSubmitting,
    requiresSignInToRead,
    errorMessage,
    feedbackMessage,
  ];
}
