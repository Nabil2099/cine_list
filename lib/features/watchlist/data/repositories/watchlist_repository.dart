import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/app_exception.dart';
import '../models/watchlist_collection_model.dart';
import '../models/watchlist_movie_model.dart';

/// Repository managing per-user Cloud Firestore watchlist CRUD operations.
class WatchlistRepository {
  WatchlistRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _watchlistRef(String uid) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .collection(AppConstants.watchlistCollection);
  }

  CollectionReference<Map<String, dynamic>> _collectionsRef(String uid) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .collection(AppConstants.collectionsCollection);
  }

  Stream<List<WatchlistCollectionModel>> watchCollections(String uid) {
    return _collectionsRef(uid)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => WatchlistCollectionModel.fromMap(doc.id, doc.data()),
              )
              .toList(),
        );
  }

  Future<String> createCollection({
    required String uid,
    required String name,
  }) async {
    try {
      final doc = _collectionsRef(uid).doc();
      final collection = WatchlistCollectionModel(
        id: doc.id,
        name: name.trim(),
        createdAt: DateTime.now(),
      );
      await doc.set(collection.toFirestoreMap());
      return doc.id;
    } on FirebaseException catch (e) {
      throw WatchlistException(_mapFirestoreError(e), code: e.code);
    } catch (_) {
      throw const WatchlistException('Could not create collection.');
    }
  }

  Future<void> deleteCollection({
    required String uid,
    required String collectionId,
  }) async {
    try {
      await _collectionsRef(uid).doc(collectionId).delete();
    } on FirebaseException catch (e) {
      throw WatchlistException(_mapFirestoreError(e), code: e.code);
    } catch (_) {
      throw const WatchlistException('Could not delete collection.');
    }
  }

  Future<void> toggleMovieInCollection({
    required String uid,
    required String collectionId,
    required int movieId,
    required bool currentlyInCollection,
  }) async {
    try {
      await _collectionsRef(uid).doc(collectionId).update({
        'movieIds': currentlyInCollection
            ? FieldValue.arrayRemove([movieId])
            : FieldValue.arrayUnion([movieId]),
      });
    } on FirebaseException catch (e) {
      throw WatchlistException(_mapFirestoreError(e), code: e.code);
    } catch (_) {
      throw const WatchlistException('Could not update collection.');
    }
  }

  Stream<List<WatchlistMovieModel>> watchWatchlist(String uid) {
    return _watchlistRef(uid)
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => WatchlistMovieModel.fromMap(doc.data()))
              .where((item) => item.movieId > 0)
              .toList(),
        );
  }

  Future<void> saveMovie(String uid, WatchlistMovieModel movie) async {
    try {
      await _watchlistRef(uid)
          .doc(movie.movieId.toString())
          .set(movie.toFirestoreMap());
    } on FirebaseException catch (e) {
      throw WatchlistException(_mapFirestoreError(e), code: e.code);
    } catch (_) {
      throw const WatchlistException('Could not save movie to watchlist.');
    }
  }

  Future<void> updateStatus({
    required String uid,
    required int movieId,
    required WatchlistFilterStatus status,
  }) async {
    try {
      await _watchlistRef(uid).doc(movieId.toString()).update({
        'status': status.value,
        'watchedAt': status == WatchlistFilterStatus.watched
            ? Timestamp.fromDate(DateTime.now())
            : null,
      });
    } on FirebaseException catch (e) {
      throw WatchlistException(_mapFirestoreError(e), code: e.code);
    } catch (_) {
      throw const WatchlistException('Could not update watch status.');
    }
  }

  Future<void> updateReview({
    required String uid,
    required int movieId,
    int? userRating,
    String? userNote,
  }) async {
    try {
      await _watchlistRef(uid).doc(movieId.toString()).update({
        'userRating': userRating,
        'userNote': userNote?.trim().isNotEmpty == true
            ? userNote!.trim()
            : null,
      });
    } on FirebaseException catch (e) {
      throw WatchlistException(_mapFirestoreError(e), code: e.code);
    } catch (_) {
      throw const WatchlistException('Could not save your rating and note.');
    }
  }

  Future<void> removeMovie({required String uid, required int movieId}) async {
    try {
      await _watchlistRef(uid).doc(movieId.toString()).delete();
    } on FirebaseException catch (e) {
      throw WatchlistException(_mapFirestoreError(e), code: e.code);
    } catch (_) {
      throw const WatchlistException('Could not remove movie from watchlist.');
    }
  }

  String _mapFirestoreError(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'Permission denied. Please sign in again or check Firestore rules.';
      case 'unavailable':
        return 'Firestore is currently unreachable. Changes will sync when online.';
      case 'not-found':
        return 'Watchlist item was not found.';
      default:
        return e.message ?? 'Watchlist operation failed.';
    }
  }
}
