import 'dart:convert';
import 'dart:typed_data';

import 'package:cine_list/core/utils/decoded_image_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    DecodedImageCache.clear();
  });

  test('returns identical MemoryImage instance for repeated base64 strings', () {
    final encoded = base64Encode(Uint8List.fromList([137, 80, 78, 71, 1, 2, 3]));

    final first = DecodedImageCache.getOrDecode(encoded);
    final second = DecodedImageCache.getOrDecode(encoded);

    expect(first, isNotNull);
    expect(identical(first, second), isTrue);
    expect(DecodedImageCache.length, 1);
  });

  test('returns null for null, empty, or malformed base64', () {
    expect(DecodedImageCache.getOrDecode(null), isNull);
    expect(DecodedImageCache.getOrDecode('   '), isNull);
    expect(DecodedImageCache.getOrDecode('%%%not-valid-base64%%%'), isNull);
    expect(DecodedImageCache.length, 0);
  });

  test('evicts least recently used entry beyond maxEntries', () {
    for (var i = 0; i < DecodedImageCache.maxEntries + 10; i++) {
      final encoded = base64Encode(Uint8List.fromList([i, i + 1, i + 2]));
      DecodedImageCache.getOrDecode(encoded);
    }

    expect(DecodedImageCache.length, DecodedImageCache.maxEntries);
  });
}
