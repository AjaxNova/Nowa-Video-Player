import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';

class HostedShortsMetadataService {
  static const String metadataUrl = 'https://nowa-web-e2a45.web.app/playlist_metadata.json';
  static const String cacheKey = 'malayalam shorts'; // matches curatedFeedQuery
  static const String assetPath = 'assets/video-info/playlist_metadata.json';

  Future<List<Map<String, dynamic>>> fetchShorts({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final cacheBox = await Hive.openBox('cachedYouTubeShortsBox');

    // 1. Try Firebase hosted JSON first
    try {
      debugPrint("🚀 [HostedShorts] Fetching curated feed from: $metadataUrl with timeout: ${timeout.inSeconds}s");
      final response = await http.get(Uri.parse(metadataUrl)).timeout(timeout);

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        final parsedList = _parseRawList(data);

        // Save to Hive cache
        await cacheBox.put(cacheKey, parsedList);
        debugPrint("🚀 [HostedShorts] Curated feed metadata successfully fetched and cached (${parsedList.length} items).");
        return parsedList;
      } else {
        throw Exception('Server returned status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("🚀 [HostedShorts] Failed to fetch hosted metadata: $e. Checking Hive cache fallback...");
    }

    // 2. Try Hive cache fallback
    try {
      final cachedList = cacheBox.get(cacheKey) as List?;
      if (cachedList != null && cachedList.isNotEmpty) {
        final List<Map<String, dynamic>> parsedCache =
            cachedList.map((v) => Map<String, dynamic>.from(v)).toList();
        debugPrint("🚀 [HostedShorts] Fallback loaded ${parsedCache.length} cached items from Hive.");
        return parsedCache;
      }
    } catch (e) {
      debugPrint("🚀 [HostedShorts] Hive cache read failed: $e");
    }

    // 3. Try bundled asset fallback
    try {
      debugPrint("🚀 [HostedShorts] Hive cache empty/missing. Loading bundled asset: $assetPath");
      final jsonString = await rootBundle.loadString(assetPath);
      final List data = jsonDecode(jsonString);
      final parsedList = _parseRawList(data);

      // Save to Hive cache to avoid loading asset next time if offline
      await cacheBox.put(cacheKey, parsedList);
      debugPrint("🚀 [HostedShorts] Loaded ${parsedList.length} items from bundled asset JSON and saved to Hive.");
      return parsedList;
    } catch (e) {
      debugPrint("🚀 [HostedShorts] Bundled asset fallback failed: $e");
      rethrow;
    }
  }

  List<Map<String, dynamic>> _parseRawList(List data) {
    return data.map((item) {
      final String videoId = item['videoId'] ?? '';
      return {
        'id': videoId,
        'title': item['title'] ?? '',
        'thumbnail': item['thumbnail'] ?? 'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
        'author': item['channelName'] ?? '',
        'channelId': item['channelId'] ?? '',
        'publish_date': item['uploadedAt'] ?? '',
        'duration': _parseIsoDuration(item['duration']),
        'view_count': int.tryParse(item['viewCount']?.toString() ?? '0') ?? 0,
        'like_count': int.tryParse(item['likeCount']?.toString() ?? '0') ?? 0,
        'comment_count': int.tryParse(item['commentCount']?.toString() ?? '0') ?? 0,
        'stream_url': null,
      };
    }).toList();
  }

  int _parseIsoDuration(String? value) {
    if (value == null) return 0;

    final regex = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?');
    final match = regex.firstMatch(value);

    if (match == null) return 0;

    final hours = int.tryParse(match.group(1) ?? '0') ?? 0;
    final minutes = int.tryParse(match.group(2) ?? '0') ?? 0;
    final seconds = int.tryParse(match.group(3) ?? '0') ?? 0;

    return hours * 3600 + minutes * 60 + seconds;
  }
}
