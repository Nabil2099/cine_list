import 'package:equatable/equatable.dart';

/// Video/trailer metadata returned from TMDB `/movie/{id}/videos`.
class MovieVideoModel extends Equatable {
  const MovieVideoModel({
    required this.id,
    required this.key,
    required this.name,
    required this.site,
    required this.type,
    this.official = false,
  });

  factory MovieVideoModel.fromJson(Map<String, dynamic> json) {
    return MovieVideoModel(
      id: (json['id'] as String?) ?? '',
      key: (json['key'] as String?)?.trim() ?? '',
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? (json['name'] as String).trim()
          : 'Official Trailer',
      site: (json['site'] as String?) ?? '',
      type: (json['type'] as String?) ?? '',
      official: (json['official'] as bool?) ?? false,
    );
  }

  final String id;
  final String key;
  final String name;
  final String site;
  final String type;
  final bool official;

  bool get isYouTube => site.toLowerCase() == 'youtube' && key.isNotEmpty;
  bool get isTrailer => type.toLowerCase() == 'trailer';
  bool get isTeaser => type.toLowerCase() == 'teaser';

  Uri get youtubeUri => Uri.parse('https://www.youtube.com/watch?v=$key');
  String get thumbnailUrl => 'https://img.youtube.com/vi/$key/hqdefault.jpg';

  @override
  List<Object?> get props => [id, key, name, site, type, official];
}
