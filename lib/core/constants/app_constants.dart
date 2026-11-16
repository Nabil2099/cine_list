/// Application-wide constants for Hive, Firestore, and UI behavior.
abstract final class AppConstants {
  static const String appName = 'CineList';
  static const String appTagline = 'Discover. Save. Watch.';

  // Hive boxes and keys
  static const String settingsBox = 'cinelist_settings';
  static const String selectedCategoryKey = 'selected_discover_category';
  static const String compactGridKey = 'compact_grid_enabled';

  // Firestore collections & fields
  static const String usersCollection = 'users';
  static const String watchlistCollection = 'watchlist';
  static const String collectionsCollection = 'collections';
  static const String matchRoomsCollection = 'match_rooms';
  static const String webAppBaseUrl = 'https://cine-list-mauve.vercel.app';

  // Watchlist statuses
  static const String statusWantToWatch = 'want_to_watch';
  static const String statusWatched = 'watched';

  // Responsive breakpoints
  static const double tabletBreakpoint = 650;
  static const double desktopBreakpoint = 1024;
  static const double maxContentWidth = 1120;

  // Debounce duration for search
  static const Duration searchDebounce = Duration(milliseconds: 400);
}
