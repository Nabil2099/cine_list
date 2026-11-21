import 'dart:collection';
import 'dart:convert';

import 'package:flutter/widgets.dart';

/// Bounded LRU cache mapping base64-encoded image strings to decoded
/// [MemoryImage] providers so scrolling feeds do not re-decode on every build.
abstract final class DecodedImageCache {
  static const int maxEntries = 100;

  static final LinkedHashMap<String, MemoryImage> _cache =
      LinkedHashMap<String, MemoryImage>();

  /// Returns a cached [MemoryImage] for [base64String], decoding once if needed.
  /// Returns `null` when [base64String] is null, empty, or invalid base64.
  static MemoryImage? getOrDecode(String? base64String) {
    final raw = base64String?.trim();
    if (raw == null || raw.isEmpty) return null;

    final existing = _cache.remove(raw);
    if (existing != null) {
      // Re-insert at the end to maintain LRU ordering.
      _cache[raw] = existing;
      return existing;
    }

    try {
      final bytes = base64Decode(raw);
      if (bytes.isEmpty) return null;
      final provider = MemoryImage(bytes);
      _cache[raw] = provider;
      if (_cache.length > maxEntries) {
        _cache.remove(_cache.keys.first);
      }
      return provider;
    } catch (_) {
      return null;
    }
  }

  /// Exposed for tests.
  static int get length => _cache.length;

  /// Clears all cached decoded images.
  static void clear() => _cache.clear();
}
