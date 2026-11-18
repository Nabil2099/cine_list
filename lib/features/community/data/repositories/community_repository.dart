import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/app_exception.dart';
import '../models/movie_review_model.dart';
import '../models/review_report_model.dart';
import '../models/user_profile_model.dart';

/// Repository managing community user profiles and public movie reviews.
class CommunityRepository {
  CommunityRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String reviewsCollection = 'reviews';
  static const String reportsCollection = 'reports';
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
