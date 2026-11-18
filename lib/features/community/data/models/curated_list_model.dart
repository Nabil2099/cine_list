import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import '../../../../shared/models/movie_summary.dart';

/// Compact movie snapshot stored inside a shared [CuratedListModel].
class CuratedListMovie extends Equatable {
  const CuratedListMovie({
    required this.movieId,
    required this.title,
    this.posterPath,
  });

  factory CuratedListMovie.fromMap(Map<String, dynamic> map) {
    return CuratedListMovie(
      movieId: (map['movieId'] as num?)?.toInt() ?? 0,
      title: (map['title'] as String?)?.trim() ?? 'Untitled',
      posterPath: map['posterPath'] as String?,
    );
  }

  final int movieId;
  final String title;
  final String? posterPath;

  MovieSummary toMovieSummary() =>
      MovieSummary(id: movieId, title: title, posterPath: posterPath);

  Map<String, dynamic> toMap() => {
    'movieId': movieId,
    'title': title,
    'posterPath': posterPath,
  };

  @override
  List<Object?> get props => [movieId, title, posterPath];
}

/// Public curated movie list shared from a user's Watchlist collection (`community_lists/{id}`).
class CuratedListModel extends Equatable {
  const CuratedListModel({
    required this.id,
    this.collectionId,
    required this.title,
    this.description = '',
    required this.authorUid,
    required this.authorName,
    this.authorAvatarKey = 'cinema',
    required this.movies,
    this.likedBy = const [],
    required this.createdAt,
  });

  static String docIdFor(String uid, String collectionId) =>
      '${uid}_$collectionId';

  factory CuratedListModel.fromMap(String id, Map<String, dynamic> map) {
    final rawMovies = map['movies'];
    final movies = rawMovies is List
        ? rawMovies
              .whereType<Map>()
              .map(
                (m) => CuratedListMovie.fromMap(Map<String, dynamic>.from(m)),
              )
              .where((m) => m.movieId > 0)
              .toList()
        : const <CuratedListMovie>[];

    final rawLikes = map['likedBy'];
    final likedBy = rawLikes is List
        ? rawLikes.whereType<String>().toList()
        : const <String>[];

    final rawCreatedAt = map['createdAt'];
    final createdAt = rawCreatedAt is Timestamp
        ? rawCreatedAt.toDate()
        : DateTime.now();

    return CuratedListModel(
      id: id,
      collectionId: map['collectionId'] as String?,
      title: (map['title'] as String?)?.trim() ?? 'Curated List',
      description: (map['description'] as String?)?.trim() ?? '',
      authorUid: (map['authorUid'] as String?) ?? '',
      authorName: (map['authorName'] as String?) ?? 'Movie Fan',
      authorAvatarKey: (map['authorAvatarKey'] as String?) ?? 'cinema',
      movies: movies,
      likedBy: likedBy,
      createdAt: createdAt,
    );
  }

  final String id;
  final String? collectionId;
  final String title;
  final String description;
  final String authorUid;
  final String authorName;
  final String authorAvatarKey;
  final List<CuratedListMovie> movies;
  final List<String> likedBy;
  final DateTime createdAt;

  bool isLikedBy(String? uid) => uid != null && likedBy.contains(uid);

  CuratedListModel copyWith({
    List<String>? likedBy,
    List<CuratedListMovie>? movies,
  }) {
    return CuratedListModel(
      id: id,
      collectionId: collectionId,
      title: title,
      description: description,
      authorUid: authorUid,
      authorName: authorName,
      authorAvatarKey: authorAvatarKey,
      movies: movies ?? this.movies,
      likedBy: likedBy ?? this.likedBy,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      if (collectionId != null) 'collectionId': collectionId,
      'title': title.trim(),
      'description': description.trim(),
      'authorUid': authorUid,
      'authorName': authorName.trim(),
      'authorAvatarKey': authorAvatarKey,
      'movies': movies.map((m) => m.toMap()).toList(),
      'likedBy': likedBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  @override
  List<Object?> get props => [
    id,
    collectionId,
    title,
    description,
    authorUid,
    authorName,
    authorAvatarKey,
    movies,
    likedBy,
    createdAt,
  ];
}
