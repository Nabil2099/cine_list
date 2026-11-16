import 'package:hive_flutter/hive_flutter.dart';

import '../constants/app_constants.dart';

/// Lightweight local preferences persisted with Hive.
class PreferencesService {
  PreferencesService(this._box);

  final Box<dynamic> _box;

  static Future<PreferencesService> init() async {
    await Hive.initFlutter();
    final box = await Hive.openBox<dynamic>(AppConstants.settingsBox);
    return PreferencesService(box);
  }

  String get selectedDiscoverCategory {
    final value = _box.get(AppConstants.selectedCategoryKey);
    if (value is String && value.isNotEmpty) {
      return value;
    }
    return 'trending';
  }

  Future<void> setSelectedDiscoverCategory(String category) async {
    await _box.put(AppConstants.selectedCategoryKey, category);
  }

  bool get compactGridEnabled {
    final value = _box.get(AppConstants.compactGridKey);
    return value is bool ? value : false;
  }

  Future<void> setCompactGridEnabled(bool enabled) async {
    await _box.put(AppConstants.compactGridKey, enabled);
  }
}
