import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/app_exception.dart';
import '../models/community_poll_model.dart';
import '../models/curated_list_model.dart';
import '../models/movie_review_model.dart';
import '../models/review_comment_model.dart';
import '../models/review_report_model.dart';
import '../models/user_profile_model.dart';
import '../models/weekly_challenge_model.dart';

/// Repository managing community user profiles and public movie reviews.
class CommunityRepository {
  CommunityRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String reviewsCollection = 'reviews';
  static const String reportsCollection = 'reports';
  static const String pollsCollection = 'community_polls';
  static const String listsCollection = 'community_lists';
  static const String challengesCollection = 'community_challenges';
  static const String commentsSubcollection = 'comments';
  static const String adminsCollection = 'admins';
  static const String moderatorsCollection = 'moderators';
  static const String bannedUsersCollection = 'banned_users';

  static const Duration reviewCooldown = Duration(seconds: 60);
  static const int maxReviewsPer24Hours = 5;

  DocumentReference<Map<String, dynamic>> _profileRef(String uid) {
    return _firestore.collection(AppConstants.usersCollection).doc(uid);
  }

  CollectionReference<Map<String, dynamic>> get _reviewsRef {
    return _firestore.collection(reviewsCollection);
  }

  CollectionReference<Map<String, dynamic>> get _reportsRef {
    return _firestore.collection(reportsCollection);
  }

  CollectionReference<Map<String, dynamic>> get _pollsRef {
    return _firestore.collection(pollsCollection);
  }

  CollectionReference<Map<String, dynamic>> get _listsRef {
    return _firestore.collection(listsCollection);
  }

  CollectionReference<Map<String, dynamic>> get _adminsRef {
    return _firestore.collection(adminsCollection);
  }

  CollectionReference<Map<String, dynamic>> get _moderatorsRef {
    return _firestore.collection(moderatorsCollection);
  }

  CollectionReference<Map<String, dynamic>> get _bannedRef {
    return _firestore.collection(bannedUsersCollection);
  }

  Stream<UserProfileModel?> watchProfile(String uid) {
    return _profileRef(uid).snapshots().map((doc) {
      final data = doc.data();
      if (!doc.exists || data == null) return null;
      return UserProfileModel.fromMap(uid, data);
    });
  }

  Future<UserProfileModel?> getProfile(String uid) async {
    try {
      final doc = await _profileRef(uid).get();
      final data = doc.data();
      if (!doc.exists || data == null) return null;
      return UserProfileModel.fromMap(uid, data);
    } on FirebaseException catch (e) {
      throw WatchlistException(_mapError(e), code: e.code);
    } catch (_) {
      throw const WatchlistException('Could not load user profile.');
    }
  }

  Future<void> saveProfile(UserProfileModel profile) async {
    try {
      await _profileRef(profile.uid)
          .set(profile.toFirestoreMap(), SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw WatchlistException(_mapError(e), code: e.code);
    } catch (_) {
      throw const WatchlistException('Could not save your profile.');
    }
  }

  Future<void> toggleFollowUser({
    required String currentUid,
    required String targetUid,
    required bool currentlyFollowing,
  }) async {
    try {
      await _profileRef(currentUid).update({
        'followingUids': currentlyFollowing
            ? FieldValue.arrayRemove([targetUid])
            : FieldValue.arrayUnion([targetUid]),
      });
    } on FirebaseException catch (e) {
      throw WatchlistException(_mapError(e), code: e.code);
    } catch (_) {
      throw const WatchlistException('Could not update follow status.');
    }
  }

  Stream<List<MovieReviewModel>> watchRecentReviews({int limit = 40}) {
    return _reviewsRef
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => MovieReviewModel.fromMap(doc.id, doc.data()))
              .where((r) => r.movieId > 0)
              .toList(),
        );
  }

  Stream<List<MovieReviewModel>> watchMovieReviews(int movieId) {
    return _reviewsRef.where('movieId', isEqualTo: movieId).snapshots().map((
      snap,
    ) {
      final list = snap.docs
          .map((doc) => MovieReviewModel.fromMap(doc.id, doc.data()))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Future<void> saveReview(MovieReviewModel review) async {
    final trimmedComment = review.comment.trim();
    if (trimmedComment.length < 5) {
      throw const WatchlistException(
        'Review must be at least 5 characters long.',
      );
    }

    try {
      if (await isUserBanned(review.uid)) {
        throw const WatchlistException(
          'Your account has been suspended from posting reviews.',
        );
      }

      final existingSnap = await _reviewsRef
          .where('uid', isEqualTo: review.uid)
          .get();
      final otherReviews = existingSnap.docs
          .map((d) => MovieReviewModel.fromMap(d.id, d.data()))
          .where((r) => r.movieId != review.movieId)
          .toList();

      final now = DateTime.now();
      for (final existing in otherReviews) {
        if (existing.comment.trim().toLowerCase() ==
            trimmedComment.toLowerCase()) {
          throw const WatchlistException(
            'Duplicate review detected. Please write an original review.',
          );
        }
        if (now.difference(existing.createdAt) < reviewCooldown) {
          throw const WatchlistException(
            'Slow down! Please wait 60 seconds before posting another review.',
          );
        }
      }

      final recent24hCount = otherReviews
          .where((r) => now.difference(r.createdAt) < const Duration(hours: 24))
          .length;
      if (recent24hCount >= maxReviewsPer24Hours) {
        throw const WatchlistException(
          'Daily limit reached (5 reviews per 24 hours).',
        );
      }

      final docId = MovieReviewModel.docIdFor(review.movieId, review.uid);
      final reviewRef = _reviewsRef.doc(docId);
      final existingDoc = await reviewRef.get();
      await reviewRef.set(review.toFirestoreMap());

      if (!existingDoc.exists) {
        final profileRef = _profileRef(review.uid);
        final profileSnap = await profileRef.get();
        if (profileSnap.exists) {
          final currentRep =
              (profileSnap.data()?['reputation'] as num?)?.toInt() ?? 0;
          await profileRef.update({'reputation': currentRep + 5});
        }
      }
    } on WatchlistException {
      rethrow;
    } on FirebaseException catch (e) {
      throw WatchlistException(_mapError(e), code: e.code);
    } catch (_) {
      throw const WatchlistException('Could not publish your review.');
    }
  }

  Future<void> toggleReviewLike({
    required String reviewId,
    required String uid,
    required bool currentlyLiked,
  }) {
    return _toggleReviewReaction(
      reviewId: reviewId,
      uid: uid,
      isLike: true,
      errorMessage: 'Could not update review like.',
    );
  }

  Future<void> toggleReviewDislike({
    required String reviewId,
    required String uid,
    required bool currentlyDisliked,
  }) {
    return _toggleReviewReaction(
      reviewId: reviewId,
      uid: uid,
      isLike: false,
      errorMessage: 'Could not update review dislike.',
    );
  }

  Future<void> _toggleReviewReaction({
    required String reviewId,
    required String uid,
    required bool isLike,
    required String errorMessage,
  }) async {
    try {
      await _firestore.runTransaction((tx) async {
        final reviewRef = _reviewsRef.doc(reviewId);
        final reviewSnap = await tx.get(reviewRef);
        final data = reviewSnap.data();
        if (!reviewSnap.exists || data == null) return;

        final authorUid = (data['uid'] as String?) ?? '';
        final likedBy = List<String>.from(
          (data['likedBy'] as List?)?.whereType<String>() ?? const [],
        );
        final dislikedBy = List<String>.from(
          (data['dislikedBy'] as List?)?.whereType<String>() ?? const [],
        );

        final wasLiked = likedBy.contains(uid);
        final wasDisliked = dislikedBy.contains(uid);

        int delta = 0;
        if (isLike) {
          if (wasLiked) {
            likedBy.remove(uid);
            delta = -10;
          } else {
            likedBy.add(uid);
            delta = 10;
            if (wasDisliked) {
              dislikedBy.remove(uid);
              delta += 5;
            }
          }
        } else {
          if (wasDisliked) {
            dislikedBy.remove(uid);
            delta = 5;
          } else {
            dislikedBy.add(uid);
            delta = -5;
            if (wasLiked) {
              likedBy.remove(uid);
              delta -= 10;
            }
          }
        }

        if (authorUid.isNotEmpty && authorUid != uid && delta != 0) {
          final authorRef = _profileRef(authorUid);
          final authorSnap = await tx.get(authorRef);
          if (authorSnap.exists) {
            final currentRep =
                (authorSnap.data()?['reputation'] as num?)?.toInt() ?? 0;
            final nextRep = (currentRep + delta).clamp(0, 999999);
            tx.update(authorRef, {'reputation': nextRep});
          }
        }

        tx.update(reviewRef, {'likedBy': likedBy, 'dislikedBy': dislikedBy});
      });
    } on FirebaseException catch (e) {
      throw WatchlistException(_mapError(e), code: e.code);
    } catch (_) {
      throw WatchlistException(errorMessage);
    }
  }

  Future<void> submitReport(ReviewReportModel report) async {
    try {
      final docId = ReviewReportModel.docIdFor(
        report.reviewId,
        report.reporterUid,
      );
      await _reportsRef.doc(docId).set(report.toFirestoreMap());
    } on FirebaseException catch (e) {
      throw WatchlistException(_mapError(e), code: e.code);
    } catch (_) {
      throw const WatchlistException('Could not submit report.');
    }
  }

  Future<bool> isAdmin(String uid) async {
    try {
      final doc = await _adminsRef.doc(uid).get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isModerator(String uid) async {
    try {
      final doc = await _moderatorsRef.doc(uid).get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  Stream<Set<String>> watchAdminUids() {
    return _adminsRef.snapshots().map(
      (snap) => snap.docs.map((d) => d.id).toSet(),
    );
  }

  Stream<Set<String>> watchModeratorUids() {
    return _moderatorsRef.snapshots().map(
      (snap) => snap.docs.map((d) => d.id).toSet(),
    );
  }

  Future<void> setModerator({
    required String uid,
    required bool makeModerator,
  }) async {
    try {
      if (makeModerator) {
        await _moderatorsRef.doc(uid).set({
          'uid': uid,
          'role': 'moderator',
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      } else {
        await _moderatorsRef.doc(uid).delete();
      }
    } on FirebaseException catch (e) {
      throw WatchlistException(_mapError(e), code: e.code);
    } catch (_) {
      throw const WatchlistException('Could not update moderator role.');
    }
  }

  Future<bool> isUserBanned(String uid) async {
    try {
      final doc = await _bannedRef.doc(uid).get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  Stream<List<UserProfileModel>> watchAllUsers() {
    return _firestore
        .collection(AppConstants.usersCollection)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => UserProfileModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<List<ReviewReportModel>> watchReports() {
    return _reportsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => ReviewReportModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> resolveReport(String reportId) async {
    try {
      await _reportsRef.doc(reportId).update({'status': 'resolved'});
    } on FirebaseException catch (e) {
      throw WatchlistException(_mapError(e), code: e.code);
    } catch (_) {
      throw const WatchlistException('Could not resolve report.');
    }
  }

  Future<void> adminDeleteReview(String reviewId) async {
    try {
      await _reviewsRef.doc(reviewId).delete();
      final related = await _reportsRef
          .where('reviewId', isEqualTo: reviewId)
          .get();
      for (final doc in related.docs) {
        await doc.reference.update({'status': 'resolved'});
      }
    } on FirebaseException catch (e) {
      throw WatchlistException(_mapError(e), code: e.code);
    } catch (_) {
      throw const WatchlistException('Could not delete review.');
    }
  }

  Future<void> adminDeleteAndBanUser(String uid) async {
    try {
      await _bannedRef.doc(uid).set({
        'uid': uid,
        'bannedAt': Timestamp.fromDate(DateTime.now()),
        'reason': 'Removed by admin',
      });
      await _profileRef(uid).delete();

      final userReviews = await _reviewsRef.where('uid', isEqualTo: uid).get();
      for (final doc in userReviews.docs) {
        await doc.reference.delete();
      }

      final userReports = await _reportsRef
          .where('reportedUid', isEqualTo: uid)
          .get();
      for (final doc in userReports.docs) {
        await doc.reference.update({'status': 'resolved'});
      }
    } on FirebaseException catch (e) {
      throw WatchlistException(_mapError(e), code: e.code);
    } catch (_) {
      throw const WatchlistException('Could not remove user.');
    }
  }

  Future<void> deleteReview(String reviewId) async {
    try {
      await _reviewsRef.doc(reviewId).delete();
    } on FirebaseException catch (e) {
      throw WatchlistException(_mapError(e), code: e.code);
    } catch (_) {
      throw const WatchlistException('Could not delete review.');
    }
  }

  Stream<CommunityPollModel?> watchPinnedPoll() {
    return _pollsRef
        .orderBy('createdAt', descending: true)
        .limit(5)
        .snapshots()
        .map((snap) {
          for (final doc in snap.docs) {
            final poll = CommunityPollModel.fromMap(doc.id, doc.data());
            if (poll.isPinned && poll.options.length >= 2) {
              return poll;
            }
          }
          return null;
        });
  }

  Future<void> createPoll({
    required String question,
    required List<String> options,
    required String createdByUid,
  }) async {
    try {
      final cleanOptions = options
          .map((o) => o.trim())
          .where((o) => o.isNotEmpty)
          .toList();
      final doc = _pollsRef.doc();
      final poll = CommunityPollModel(
        id: doc.id,
        question: question.trim(),
        options: cleanOptions,
        createdByUid: createdByUid,
        createdAt: DateTime.now(),
      );
      await doc.set(poll.toFirestoreMap());
    } on FirebaseException catch (e) {
      throw WatchlistException(_mapError(e), code: e.code);
    } catch (_) {
      throw const WatchlistException('Could not create community poll.');
    }
  }

  Future<void> voteOnPoll({
    required String pollId,
    required String uid,
    required int optionIndex,
  }) async {
    try {
      await _pollsRef.doc(pollId).update({'votesByUid.$uid': optionIndex});
    } on FirebaseException catch (e) {
      throw WatchlistException(_mapError(e), code: e.code);
    } catch (_) {
      throw const WatchlistException('Could not submit your vote.');
    }
  }

  Future<void> deletePoll(String pollId) async {
    try {
      await _pollsRef.doc(pollId).delete();
    } on FirebaseException catch (e) {
      throw WatchlistException(_mapError(e), code: e.code);
    } catch (_) {
      throw const WatchlistException('Could not delete poll.');
    }
  }

  Stream<List<CuratedListModel>> watchCuratedLists({int limit = 30}) {
    return _listsRef
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => CuratedListModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> publishCuratedList(CuratedListModel list) async {
    try {
      final doc =
          (list.collectionId != null && list.collectionId!.trim().isNotEmpty)
          ? _listsRef.doc(
              CuratedListModel.docIdFor(list.authorUid, list.collectionId!),
            )
          : _listsRef.doc();
      await doc.set(list.toFirestoreMap());
    } on FirebaseException catch (e) {
      throw WatchlistException(_mapError(e), code: e.code);
    } catch (_) {
      throw const WatchlistException('Could not publish curated list.');
    }
  }

  Future<void> syncCuratedListMovies({
    required String listId,
    required List<CuratedListMovie> movies,
  }) async {
    try {
      await _listsRef.doc(listId).update({
        'movies': movies.map((m) => m.toMap()).toList(),
      });
    } on FirebaseException catch (e) {
      throw WatchlistException(_mapError(e), code: e.code);
    } catch (_) {
      throw const WatchlistException('Could not sync curated list movies.');
    }
  }

  Future<void> toggleCuratedListLike({
    required String listId,
    required String uid,
    required bool currentlyLiked,
  }) async {
    try {
      await _listsRef.doc(listId).update({
        'likedBy': currentlyLiked
            ? FieldValue.arrayRemove([uid])
            : FieldValue.arrayUnion([uid]),
      });
    } on FirebaseException catch (e) {
      throw WatchlistException(_mapError(e), code: e.code);
    } catch (_) {
      throw const WatchlistException('Could not update list upvote.');
    }
  }

  Future<void> deleteCuratedList(String listId) async {
    try {
      await _listsRef.doc(listId).delete();
    } on FirebaseException catch (e) {
      throw WatchlistException(_mapError(e), code: e.code);
    } catch (_) {
      throw const WatchlistException('Could not delete curated list.');
    }
  }

  CollectionReference<Map<String, dynamic>> _commentsRef(String reviewId) {
    return _reviewsRef.doc(reviewId).collection(commentsSubcollection);
  }

  CollectionReference<Map<String, dynamic>> get _challengesRef {
    return _firestore.collection(challengesCollection);
  }

  Stream<List<ReviewCommentModel>> watchReviewComments(String reviewId) {
    return _commentsRef(reviewId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (doc) =>
                    ReviewCommentModel.fromMap(doc.id, reviewId, doc.data()),
              )
              .toList(),
        );
  }

  Future<void> addReviewComment({
    required String reviewId,
    required ReviewCommentModel comment,
  }) async {
    final trimmed = comment.text.trim();
    if (trimmed.isEmpty) {
      throw const WatchlistException('Reply cannot be empty.');
    }
    if (trimmed.length > 300) {
      throw const WatchlistException('Reply must be 300 characters or less.');
    }
    try {
      if (await isUserBanned(comment.uid)) {
        throw const WatchlistException(
          'Your account has been suspended from commenting.',
        );
      }
      final batch = _firestore.batch();
      final commentDoc = _commentsRef(reviewId).doc();
      batch.set(commentDoc, comment.toFirestoreMap());
      batch.update(_reviewsRef.doc(reviewId), {
        'replyCount': FieldValue.increment(1),
      });
      await batch.commit();
    } on WatchlistException {
      rethrow;
    } on FirebaseException catch (e) {
      throw WatchlistException(_mapError(e), code: e.code);
    } catch (_) {
      throw const WatchlistException('Could not post your reply.');
    }
  }

  Future<void> deleteReviewComment({
    required String reviewId,
    required String commentId,
  }) async {
    try {
      final batch = _firestore.batch();
      batch.delete(_commentsRef(reviewId).doc(commentId));
      batch.update(_reviewsRef.doc(reviewId), {
        'replyCount': FieldValue.increment(-1),
      });
      await batch.commit();
    } on FirebaseException catch (e) {
      throw WatchlistException(_mapError(e), code: e.code);
    } catch (_) {
      throw const WatchlistException('Could not delete reply.');
    }
  }

  Stream<WeeklyChallengeModel?> watchActiveChallenge() {
    return _challengesRef
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) {
          if (snap.docs.isEmpty) return null;
          final doc = snap.docs.first;
          return WeeklyChallengeModel.fromMap(doc.id, doc.data());
        });
  }

  Future<void> createWeeklyChallenge({
    required String title,
    required int movieId,
    required String movieTitle,
    String? posterPath,
    required String prompt,
    required String createdByUid,
    int bonusPoints = 15,
  }) async {
    try {
      final prevActive = await _challengesRef
          .where('isActive', isEqualTo: true)
          .get();
      final batch = _firestore.batch();
      for (final doc in prevActive.docs) {
        batch.update(doc.reference, {'isActive': false});
      }
      final doc = _challengesRef.doc();
      final now = DateTime.now();
      final challenge = WeeklyChallengeModel(
        id: doc.id,
        title: title.trim().isEmpty ? 'Movie of the Week' : title.trim(),
        movieId: movieId,
        movieTitle: movieTitle.trim(),
        posterPath: posterPath,
        prompt: prompt.trim(),
        bonusPoints: bonusPoints.clamp(1, 50),
        createdByUid: createdByUid,
        createdAt: now,
        endsAt: now.add(const Duration(days: 7)),
      );
      batch.set(doc, challenge.toFirestoreMap());
      await batch.commit();
    } on FirebaseException catch (e) {
      throw WatchlistException(_mapError(e), code: e.code);
    } catch (_) {
      throw const WatchlistException('Could not create weekly challenge.');
    }
  }

  Future<void> deleteWeeklyChallenge(String challengeId) async {
    try {
      await _challengesRef.doc(challengeId).delete();
    } on FirebaseException catch (e) {
      throw WatchlistException(_mapError(e), code: e.code);
    } catch (_) {
      throw const WatchlistException('Could not delete weekly challenge.');
    }
  }

  Future<bool> completeWeeklyChallenge({
    required String challengeId,
    required String uid,
  }) async {
    try {
      if (await isUserBanned(uid)) {
        throw const WatchlistException(
          'Your account has been suspended from participating.',
        );
      }
      return await _firestore.runTransaction((tx) async {
        final challengeRef = _challengesRef.doc(challengeId);
        final snap = await tx.get(challengeRef);
        final data = snap.data();
        if (!snap.exists || data == null) return false;

        final participants = (data['participantUids'] is List)
            ? (data['participantUids'] as List).whereType<String>().toList()
            : <String>[];
        if (participants.contains(uid)) return false;

        final bonus = ((data['bonusPoints'] as num?)?.toInt() ?? 15).clamp(
          1,
          50,
        );
        final profileRef = _profileRef(uid);
        final profileSnap = await tx.get(profileRef);

        tx.update(challengeRef, {
          'participantUids': FieldValue.arrayUnion([uid]),
        });
        if (profileSnap.exists) {
          final currentRep =
              (profileSnap.data()?['reputation'] as num?)?.toInt() ?? 0;
          tx.update(profileRef, {'reputation': currentRep + bonus});
        }
        return true;
      });
    } on WatchlistException {
      rethrow;
    } on FirebaseException catch (e) {
      throw WatchlistException(_mapError(e), code: e.code);
    } catch (_) {
      throw const WatchlistException('Could not complete weekly challenge.');
    }
  }

  String _mapError(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'Permission denied. Please deploy the updated Firestore rules.';
      case 'unavailable':
        return 'Firestore is temporarily unreachable.';
      default:
        return e.message ?? 'Community operation failed.';
    }
  }
}
