import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;

class ShortsStreamCache {
  // Singleton pattern
  static final ShortsStreamCache instance = ShortsStreamCache._internal();
  ShortsStreamCache._internal();

  final Map<String, Future<String?>> _cache = {};
  final Map<String, DateTime> _fetchTimes = {};
  final List<String> _cacheKeys = [];
  final yt.YoutubeExplode _ytClient = yt.YoutubeExplode();
  
  static const int _maxCacheSize = 50;
  static const Duration _cacheTtl = Duration(hours: 5);

  int _currentWarmupGeneration = 0;
  Timer? _debounceTimer;

  Future<String?> getStreamUrl(String videoId) {
    // 1. Check if cached and within TTL
    if (_cache.containsKey(videoId)) {
      final fetchTime = _fetchTimes[videoId];
      if (fetchTime != null && DateTime.now().difference(fetchTime) < _cacheTtl) {
        debugPrint("🚀 [ShortsCache] Cache HIT for video: $videoId");
        return _cache[videoId]!;
      } else {
        debugPrint("🚀 [ShortsCache] Cache TTL expired for video: $videoId. Evicting...");
        _evict(videoId);
      }
    }

    debugPrint("🚀 [ShortsCache] Cache MISS for video: $videoId. Fetching...");
    
    // 2. Fetch and register Future in cache map (which automatically dedupes in-flight queries)
    final Future<String?> future = _resolveStreamUrl(videoId).then((url) {
      if (url == null) {
        _evict(videoId);
      }
      return url;
    }).catchError((e) {
      debugPrint("🚀 [ShortsCache] Manifest fetch failed and evicted for video: $videoId. Error: $e");
      _evict(videoId);
      throw e;
    });

    _cache[videoId] = future;
    _fetchTimes[videoId] = DateTime.now();
    _cacheKeys.add(videoId);

    // 3. FIFO eviction if cache size exceeded
    if (_cacheKeys.length > _maxCacheSize) {
      final oldestKey = _cacheKeys.removeAt(0);
      _cache.remove(oldestKey);
      _fetchTimes.remove(oldestKey);
      debugPrint("🚀 [ShortsCache] Cache limit exceeded. Evicted oldest entry: $oldestKey");
    }

    return future;
  }

  void warmUpAround(int index, List<Map<String, dynamic>> videos) {
    _debounceTimer?.cancel();
    _currentWarmupGeneration++;
    final generation = _currentWarmupGeneration;

    // Define warmup window: [index - 1, index, index + 1, index + 2]
    final List<int> targets = [index - 1, index, index + 1, index + 2];
    
    _debounceTimer = Timer(const Duration(milliseconds: 200), () async {
      if (generation != _currentWarmupGeneration) {
        debugPrint("🚀 [ShortsCache] Warmup skipped for index $index because generation changed.");
        return;
      }

      for (final i in targets) {
        if (i >= 0 && i < videos.length) {
          final videoId = videos[i]['id'] as String?;
          if (videoId != null) {
            // Check if already in cache (avoiding unnecessary triggers)
            if (!_cache.containsKey(videoId)) {
              // Initiate fetch without waiting for it sequentially
              getStreamUrl(videoId).catchError((e) {
                debugPrint("🚀 [ShortsCache] Warmup fetch failed for video $videoId: $e");
                return null;
              });
            }
          }
        }
      }
    });
  }

  Future<String?> _resolveStreamUrl(String videoId) async {
    try {
      final manifest = await _ytClient.videos.streams.getManifest(
        videoId,
        ytClients: [yt.YoutubeApiClient.androidVr],
      );
      final muxed = manifest.muxed.sortByVideoQuality();
      if (muxed.isNotEmpty) {
        return muxed.first.url.toString();
      }
    } catch (e) {
      debugPrint("🚀 [ShortsCache] _resolveStreamUrl error for video $videoId: $e");
      rethrow;
    }
    return null;
  }

  void _evict(String videoId) {
    _cache.remove(videoId);
    _fetchTimes.remove(videoId);
    _cacheKeys.remove(videoId);
  }

  void clear() {
    _cache.clear();
    _fetchTimes.clear();
    _cacheKeys.clear();
    debugPrint("🚀 [ShortsCache] Cache cleared.");
  }

  void dispose() {
    _debounceTimer?.cancel();
    _ytClient.close();
    clear();
  }
}
