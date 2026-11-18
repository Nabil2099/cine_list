import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../../features/ai_chat/data/models/chat_message_model.dart';
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

  List<ChatMessageModel> loadAiChatHistory() {
    final raw = _box.get(AppConstants.aiChatHistoryKey);
    if (raw is! String || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((m) => ChatMessageModel.fromMap(Map<String, dynamic>.from(m)))
          .where((m) => m.text.trim().isNotEmpty && !m.isError)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveAiChatHistory(List<ChatMessageModel> messages) async {
    final toSave = messages
        .where((m) => !m.isError && m.text.trim().isNotEmpty)
        .toList();
    final trimmed = toSave.length > 40
        ? toSave.sublist(toSave.length - 40)
        : toSave;
    await _box.put(
      AppConstants.aiChatHistoryKey,
      jsonEncode(trimmed.map((m) => m.toMap()).toList()),
    );
  }
}
