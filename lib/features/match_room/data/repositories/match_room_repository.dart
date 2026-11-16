import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../shared/models/movie_summary.dart';
import '../../../discover/data/datasources/tmdb_remote_data_source.dart';
import '../models/match_room_model.dart';

/// Repository managing real-time Movie Night Match Rooms in Cloud Firestore.
class MatchRoomRepository {
  MatchRoomRepository({
    required this.remoteDataSource,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final TmdbRemoteDataSource remoteDataSource;
  final FirebaseFirestore _firestore;
  final _random = Random();

  static const String _codeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  CollectionReference<Map<String, dynamic>> get _roomsRef {
    return _firestore.collection(AppConstants.matchRoomsCollection);
  }

  String _generateCode() {
    return List.generate(
      4,
      (_) => _codeChars[_random.nextInt(_codeChars.length)],
    ).join();
  }

  Future<List<MovieSummary>> _buildDeck(List<MovieSummary> seedMovies) async {
    final seenIds = <int>{};
    final deck = <MovieSummary>[];

    for (final m in seedMovies) {
      if (m.id > 0 && seenIds.add(m.id)) {
        deck.add(m);
      }
      if (deck.length >= 8) break;
    }

    try {
      final trending = await remoteDataSource.getTrendingMovies(page: 1);
      for (final m in trending.results) {
        if (m.id > 0 && seenIds.add(m.id)) {
          deck.add(m);
        }
        if (deck.length >= 20) break;
      }
    } catch (_) {
      if (deck.isEmpty) rethrow;
    }

    if (deck.length < 20) {
      try {
        final popular = await remoteDataSource.getPopularMovies(page: 1);
        for (final m in popular.results) {
          if (m.id > 0 && seenIds.add(m.id)) {
            deck.add(m);
          }
          if (deck.length >= 20) break;
        }
      } catch (_) {}
    }

    deck.shuffle(_random);
    return deck;
  }

  Future<MatchRoomModel> createRoom({
    required String hostUid,
    required String hostName,
    List<MovieSummary> seedMovies = const [],
  }) async {
    try {
      final deck = await _buildDeck(seedMovies);
      if (deck.isEmpty) {
        throw const WatchlistException(
          'Could not load movies for your Match Room.',
        );
      }

      String code = _generateCode();
      for (var i = 0; i < 4; i++) {
        final existing = await _roomsRef.doc(code).get();
        if (!existing.exists) break;
        code = _generateCode();
      }

      final room = MatchRoomModel(
        code: code,
        hostUid: hostUid,
        hostName: hostName,
        participantUids: [hostUid],
        participantNames: {hostUid: hostName},
        deck: deck,
        createdAt: DateTime.now(),
      );

      await _roomsRef.doc(code).set(room.toFirestoreMap());
      return room;
    } on AppException {
      rethrow;
    } on FirebaseException catch (e) {
      throw WatchlistException(
        e.message ?? 'Could not create Match Room.',
        code: e.code,
      );
    } catch (_) {
      throw const WatchlistException('Could not create Match Room.');
    }
  }

  Future<MatchRoomModel> joinRoom({
    required String code,
    required String uid,
    required String displayName,
  }) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.length < 4) {
      throw const WatchlistException('Enter a valid 4-character room code.');
    }

    try {
      final docRef = _roomsRef.doc(normalized);
      final snap = await docRef.get();
      final data = snap.data();
      if (!snap.exists || data == null) {
        throw WatchlistException('Match Room "$normalized" not found.');
      }

      await docRef.update({
        'participantUids': FieldValue.arrayUnion([uid]),
        'participantNames.$uid': displayName,
      });

      final updated = await docRef.get();
      return MatchRoomModel.fromMap(normalized, updated.data() ?? data);
    } on AppException {
      rethrow;
    } on FirebaseException catch (e) {
      throw WatchlistException(
        e.message ?? 'Could not join Match Room.',
        code: e.code,
      );
    } catch (_) {
      throw const WatchlistException('Could not join Match Room.');
    }
  }

  Stream<MatchRoomModel?> watchRoom(String code) {
    final normalized = code.trim().toUpperCase();
    return _roomsRef.doc(normalized).snapshots().map((doc) {
      final data = doc.data();
      if (!doc.exists || data == null) return null;
      return MatchRoomModel.fromMap(normalized, data);
    });
  }

  Future<void> vote({
    required String code,
    required String uid,
    required int movieId,
    required bool liked,
  }) async {
    final normalized = code.trim().toUpperCase();
    final field = liked ? 'likesByUser.$uid' : 'passesByUser.$uid';
    try {
      await _roomsRef.doc(normalized).update({
        field: FieldValue.arrayUnion([movieId]),
      });
    } on FirebaseException catch (e) {
      throw WatchlistException(
        e.message ?? 'Could not submit vote.',
        code: e.code,
      );
    } catch (_) {
      throw const WatchlistException('Could not submit vote.');
    }
  }
}
