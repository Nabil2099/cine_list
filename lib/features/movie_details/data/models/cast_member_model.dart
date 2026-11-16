import 'package:equatable/equatable.dart';

/// Cast member returned from TMDB `/movie/{id}/credits`.
class CastMemberModel extends Equatable {
  const CastMemberModel({
    required this.id,
    required this.name,
    required this.character,
    this.profilePath,
  });

  factory CastMemberModel.fromJson(Map<String, dynamic> json) {
    return CastMemberModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? 'Unknown',
      character: (json['character'] as String?) ?? '',
      profilePath: json['profile_path'] as String?,
    );
  }

  final int id;
  final String name;
  final String character;
  final String? profilePath;

  @override
  List<Object?> get props => [id, name, character, profilePath];
}
