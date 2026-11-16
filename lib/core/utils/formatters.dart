/// Formatting helpers for movie metadata.
abstract final class Formatters {
  static String releaseYear(String? releaseDate) {
    if (releaseDate == null || releaseDate.trim().length < 4) {
      return 'TBA';
    }
    return releaseDate.trim().substring(0, 4);
  }

  static String runtime(int? minutes) {
    if (minutes == null || minutes <= 0) return '';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours == 0) return '${mins}m';
    if (mins == 0) return '${hours}h';
    return '${hours}h ${mins}m';
  }

  static String rating(double? voteAverage) {
    if (voteAverage == null || voteAverage <= 0) return 'N/A';
    return voteAverage.toStringAsFixed(1);
  }

  static String greetingName(String? email) {
    if (email == null || email.trim().isEmpty) return 'Movie Fan';
    final prefix = email.split('@').first.trim();
    if (prefix.isEmpty) return 'Movie Fan';
    return prefix[0].toUpperCase() + prefix.substring(1);
  }
}
