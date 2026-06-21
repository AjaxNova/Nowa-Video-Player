import 'dart:collection';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';

class ShortsThumbnailCache {
  static const int maxEntries = 200;
  static final LinkedHashMap<String, Uint8List> _cache = LinkedHashMap<String, Uint8List>();

  /// Retrieves cached thumbnail data. If not cached, fetches it from photo_manager
  /// and caches it in an LRU manner.
  static Future<Uint8List?> getThumbnail(AssetEntity video) async {
    final String id = video.id;
    if (_cache.containsKey(id)) {
      final value = _cache.remove(id)!;
      _cache[id] = value; // Re-insert at the end to make it Most Recently Used
      return value;
    }
    
    try {
      final data = await video.thumbnailData;
      if (data != null) {
        if (_cache.length >= maxEntries) {
          final oldestKey = _cache.keys.first;
          _cache.remove(oldestKey);
        }
        _cache[id] = data;
      }
      return data;
    } catch (_) {
      return null;
    }
  }

  /// Explicitly remove a specific cached thumbnail (useful on deletion)
  static void remove(String id) {
    _cache.remove(id);
  }

  /// Clears cache on dispose/low-memory scenarios
  static void clear() {
    _cache.clear();
  }
}
