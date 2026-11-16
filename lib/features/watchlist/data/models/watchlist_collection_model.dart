import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Custom user-created movie collection stored under `users/{uid}/collections`.
class WatchlistCollectionModel extends Equatable {
  const WatchlistCollectionModel({
    required this.id,
    required this.name,
    this.movieIds = const [],
    required this.createdAt,
  });

  final String id;
  final String name;
  final List<int> movieIds;
  final DateTime createdAt;

  bool containsMovie(int movieId) => movieIds.contains(movieId);

  Map<String, dynamic> toFirestoreMap() {
    return {
      'name': name.trim(),
      'movieIds': movieIds,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory WatchlistCollectionModel.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    final rawCreatedAt = map['createdAt'];
    final createdAt = rawCreatedAt is Timestamp
        ? rawCreatedAt.toDate()
        : DateTime.now();
    final rawIds = map['movieIds'];
    final movieIds = rawIds is List
        ? rawIds.whereType<num>().map((e) => e.toInt()).toList()
        : const <int>[];

    return WatchlistCollectionModel(
      id: id,
      name: (map['name'] as String?)?.trim() ?? 'Untitled List',
      movieIds: movieIds,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [id, name, movieIds, createdAt];
}
