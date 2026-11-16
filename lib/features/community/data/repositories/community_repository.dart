import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/app_exception.dart';
import '../models/movie_review_model.dart';
import '../models/user_profile_model.dart';

/// Repository managing community user profiles and public movie reviews.
class CommunityRepository {
  CommunityRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String reviewsCollection = 'reviews';

  DocumentReference<Map<String, dynamic>> _profileRef(String uid) {
    return _firestore.collection(AppConstants.usersCollection).doc(uid);
  }

  CollectionReference<Map<String, dynamic>> get _reviewsRef {
    return _firestore.collection(reviewsCollection);
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
    try {
      final docId = MovieReviewModel.docIdFor(review.movieId, review.uid);
      await _reviewsRef.doc(docId).set(review.toFirestoreMap());
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
  }) async {
    try {
      await _reviewsRef.doc(reviewId).update({
        'likedBy': currentlyLiked
            ? FieldValue.arrayRemove([uid])
            : FieldValue.arrayUnion([uid]),
      });
    } on FirebaseException catch (e) {
      throw WatchlistException(_mapError(e), code: e.code);
    } catch (_) {
      throw const WatchlistException('Could not update review like.');
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
