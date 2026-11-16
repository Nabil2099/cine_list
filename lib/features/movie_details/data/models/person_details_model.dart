import 'package:equatable/equatable.dart';

/// TMDB person profile details for cast/crew filmography sheet.
class PersonDetailsModel extends Equatable {
  const PersonDetailsModel({
    required this.id,
    required this.name,
    this.biography = '',
    this.knownForDepartment = '',
    this.birthday,
    this.placeOfBirth,
    this.profilePath,
  });

  final int id;
  final String name;
  final String biography;
  final String knownForDepartment;
  final String? birthday;
  final String? placeOfBirth;
  final String? profilePath;

  factory PersonDetailsModel.fromJson(Map<String, dynamic> json) {
    return PersonDetailsModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?)?.trim() ?? 'Unknown',
      biography: (json['biography'] as String?)?.trim() ?? '',
      knownForDepartment:
          (json['known_for_department'] as String?)?.trim() ?? '',
      birthday: (json['birthday'] as String?)?.trim(),
      placeOfBirth: (json['place_of_birth'] as String?)?.trim(),
      profilePath: json['profile_path'] as String?,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    biography,
    knownForDepartment,
    birthday,
    placeOfBirth,
    profilePath,
  ];
}
