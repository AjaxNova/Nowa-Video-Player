// ignore_for_file: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;

import 'new_playlist_class.dart';
import 'package:nova_videoplayer/functions/app_logger.dart';

Color colorBlack = Colors.black;
Color colorWhite = Colors.white;
Color colorGreen = const Color(0xFF4FEC68);

ValueNotifier<List<Map<String, dynamic>>> globalYouTubeShorts = ValueNotifier([]);
bool isYouTubeShortsLoading = false;
String? youtubeShortsError;
ValueNotifier<bool> isShortsPlaying = ValueNotifier(true);
String currentSearchQuery = 'malayalam shorts';

// Keep track of the last search page to fetch next page dynamically
dynamic _lastSearchPage;
List<yt.Video> _cachedSearchResults = [];
String? _cachedSearchQuery;
int _fetchVersion = 0; // Incremented on new search to cancel stale fetches
bool _isRelatedFeedRunning = false;
final Set<String> _usedSeedIds = {};
int _curatedUploadsOffset = 40;
bool _hasRunMetadataFetcherThisSession = false;

/// Fetches YouTube shorts lazily.
/// - [limit]: how many new streams to extract
/// - [append]: true = add to existing list, false = replace
/// - [query]: new search query (triggers fresh YouTube search)
/// - [force]: true = bypass loading guard (used by new searches)
const String curatedPlaylistId = 'PLKYxHjgtNOLtpJbnlqHsN_zxsd5WMj7cc';

Future<void> prefetchYouTubeShorts({
  int limit = 10,
  bool append = false,
  String? query,
  bool force = false,
}) async {
  if (isYouTubeShortsLoading && !force) return;

  if (force) _fetchVersion++;
  final myVersion = _fetchVersion;

  isYouTubeShortsLoading = true;
  youtubeShortsError = null;

  if (query != null) {
    currentSearchQuery = query;
    _cachedSearchResults = [];
    _cachedSearchQuery = null;
    _lastSearchPage = null;
    _usedSeedIds.clear();
  }

  // Load from local cache instantly if list is empty and not appending
  final cacheBox = await Hive.openBox('cachedYouTubeShortsBox');
  if (!append && globalYouTubeShorts.value.isEmpty) {
    final cachedList = cacheBox.get(currentSearchQuery) as List?;
    if (cachedList != null && cachedList.isNotEmpty) {
      globalYouTubeShorts.value = cachedList.map((v) => Map<String, dynamic>.from(v)).toList();
      AppLogger.log('[Shorts] Loaded ${globalYouTubeShorts.value.length} cached videos instantly from Hive for query "$currentSearchQuery"');
    }
  }

  final ytClient = yt.YoutubeExplode();
  try {
    List<Map<String, dynamic>> newVideos = [];

    if (currentSearchQuery.trim().toLowerCase() == 'malayalam shorts') {
      AppLogger.log('[Shorts] Loading default Malayalam curated feed from playlist: $curatedPlaylistId...');
      
      // Try fetching using YoutubeExplode first
      List<yt.Video> videos = [];
      try {
        videos = await ytClient.playlists
            .getVideos(curatedPlaylistId)
            .take(150)
            .toList();
      } catch (e) {
        AppLogger.logWarning('[Shorts] YoutubeExplode playlist fetch failed: $e');
      }

      final existingIds = globalYouTubeShorts.value
          .map((v) => v['id'] as String)
          .toSet();

      if (videos.isNotEmpty) {
        newVideos = videos
            .where((v) => !existingIds.contains(v.id.value))
            .map((v) => {
              'id': v.id.value,
              'title': v.title,
              'thumbnail': 'https://img.youtube.com/vi/${v.id.value}/hqdefault.jpg',
              'duration': v.duration?.inSeconds ?? 0,
              'publish_date': v.uploadDate?.toIso8601String(),
              'stream_url': null, // lazy fetched per video
              'seedVideo': v,
            })
            .toList();
      } else {
        AppLogger.log('[Shorts] YoutubeExplode returned 0 videos. Trying InnerTube scraper fallback...');
        try {
          final url = Uri.parse('https://www.youtube.com/youtubei/v1/browse?key=AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8');
          final headers = {
            'content-type': 'application/json',
            'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.18 Safari/537.36',
          };
          final body = json.encode({
            "context": {
              "client": {
                "browserName": "Chrome",
                "browserVersion": "105.0.0.0",
                "clientFormFactor": "UNKNOWN_FORM_FACTOR",
                "clientName": "WEB",
                "clientVersion": "2.20220921.00.00"
              }
            },
            "browseId": "VL$curatedPlaylistId"
          });

          final response = await http.post(url, headers: headers, body: body);
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            final Set<String> seenIds = {};
            final List<Map<String, dynamic>> parsedVideos = [];

            void findKeys(dynamic obj) {
              if (obj is Map) {
                if (obj.containsKey('shortsLockupViewModel')) {
                  final model = obj['shortsLockupViewModel'];
                  final videoId = model['onTap']?['innertubeCommand']?['reelWatchEndpoint']?['videoId'] as String?;
                  final title = model['overlayMetadata']?['primaryText']?['content'] as String? ?? model['accessibilityText'] as String? ?? '';
                  final thumbnails = model['thumbnailViewModel']?['thumbnailViewModel']?['image']?['sources'] as List?;
                  final thumbnailUrl = thumbnails != null && thumbnails.isNotEmpty ? thumbnails.first['url'] as String? : null;

                  if (videoId != null && videoId.isNotEmpty && !seenIds.contains(videoId)) {
                    seenIds.add(videoId);
                    parsedVideos.add({
                      'id': videoId,
                      'title': title,
                      'thumbnail': 'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
                      'duration': 0,
                      'publish_date': null,
                      'stream_url': null,
                      'seedVideo': null,
                    });
                  }
                } else {
                  for (var val in obj.values) {
                    findKeys(val);
                  }
                }
              } else if (obj is List) {
                for (var val in obj) {
                  findKeys(val);
                }
              }
            }

            findKeys(data);
            newVideos = parsedVideos.where((v) => !existingIds.contains(v['id'])).toList();
            AppLogger.log('[Shorts] InnerTube scraper parsed ${newVideos.length} new videos from curated playlist.');
          } else {
            AppLogger.logWarning('[Shorts] InnerTube browse failed: ${response.statusCode}');
          }
        } catch (innerErr, stack) {
          AppLogger.logError('[Shorts] InnerTube scraper failed', innerErr, stack);
        }
      }
    } else {
      AppLogger.log('[Shorts] Searching YouTube for "$currentSearchQuery"...');
      if (_cachedSearchQuery != currentSearchQuery || _cachedSearchResults.isEmpty) {
        final searchResults = await ytClient.search.search(currentSearchQuery);
        _cachedSearchResults = searchResults.whereType<yt.Video>().toList();
        _cachedSearchQuery = currentSearchQuery;
      }

      final existingIds = globalYouTubeShorts.value
          .map((v) => v['id'] as String)
          .toSet();

      newVideos = _cachedSearchResults
          .where((v) => !existingIds.contains(v.id.value))
          .map((v) => {
            'id': v.id.value,
            'title': v.title,
            'thumbnail': 'https://img.youtube.com/vi/${v.id.value}/hqdefault.jpg',
            'duration': v.duration?.inSeconds ?? 0,
            'publish_date': v.uploadDate?.toIso8601String(),
            'stream_url': null, // lazy fetched per video
            'seedVideo': v,
          })
          .toList();
    }

    if (_fetchVersion != myVersion) return;

    if (newVideos.isNotEmpty) {
      if (append) {
        globalYouTubeShorts.value = [...globalYouTubeShorts.value, ...newVideos];
      } else {
        globalYouTubeShorts.value = newVideos;
      }
      
      final cacheData = globalYouTubeShorts.value.map((v) {
        final cacheMap = Map<String, dynamic>.from(v);
        cacheMap.remove('seedVideo');
        return cacheMap;
      }).toList();
      await cacheBox.put(currentSearchQuery, cacheData);
      AppLogger.log('[Shorts] Saved ${cacheData.length} items to Hive cache box.');
    }
  } catch (e, stackTrace) {
    if (_fetchVersion != myVersion) return;
    AppLogger.logError('[Shorts] Fetch failed', e, stackTrace);
    youtubeShortsError = e.toString();
  } finally {
    if (_fetchVersion == myVersion) {
      isYouTubeShortsLoading = false;
    }
    ytClient.close();
    if (currentSearchQuery.trim().toLowerCase() == 'malayalam shorts' &&
        globalYouTubeShorts.value.isNotEmpty &&
        !append &&
        !_hasRunMetadataFetcherThisSession) {
      _hasRunMetadataFetcherThisSession = true;
      _startBackgroundMetadataFetcher();
    }
  }
}

bool _isMetadataFetcherRunning = false;

Future<void> _fetchVideoMetadataInBackground(String videoId) async {
  final ytClient = yt.YoutubeExplode();
  try {
    final video = await ytClient.videos.get(videoId);
    final updated = globalYouTubeShorts.value.map((v) {
      if (v['id'] == videoId) {
        return {
          ...v,
          'duration': video.duration?.inSeconds ?? 0,
          'publish_date': video.publishDate?.toIso8601String() ?? video.uploadDate?.toIso8601String(),
          'author': video.author,
          'view_count': video.engagement.viewCount,
          'like_count': video.engagement.likeCount,
        };
      }
      return v;
    }).toList();
    globalYouTubeShorts.value = updated;
    try {
      final cacheBox = await Hive.openBox('cachedYouTubeShortsBox');
      final cacheData = updated.map((v) {
        final cacheMap = Map<String, dynamic>.from(v);
        cacheMap.remove('seedVideo');
        return cacheMap;
      }).toList();
      await cacheBox.put(currentSearchQuery, cacheData);
    } catch (_) {}
  } catch (e) {
    AppLogger.logWarning('[Shorts] Metadata fetch failed for $videoId: $e');
    // Set duration to -1 so we don't try this failing video again in this run
    final updated = globalYouTubeShorts.value.map((v) {
      if (v['id'] == videoId) {
        return {
          ...v,
          'duration': -1,
        };
      }
      return v;
    }).toList();
    globalYouTubeShorts.value = updated;
    try {
      final cacheBox = await Hive.openBox('cachedYouTubeShortsBox');
      final cacheData = updated.map((v) {
        final cacheMap = Map<String, dynamic>.from(v);
        cacheMap.remove('seedVideo');
        return cacheMap;
      }).toList();
      await cacheBox.put(currentSearchQuery, cacheData);
    } catch (_) {}
  } finally {
    ytClient.close();
  }
}

Future<void> _startBackgroundMetadataFetcher() async {
  if (_isMetadataFetcherRunning) return;
  _isMetadataFetcherRunning = true;

  try {
    final List<String> videoIds = globalYouTubeShorts.value
        .where((v) => (v['duration'] as num? ?? 0) == 0)
        .map((v) => v['id'] as String)
        .toList();

    for (final id in videoIds) {
      await _fetchVideoMetadataInBackground(id);
      await Future.delayed(const Duration(milliseconds: 1000));
    }
  } catch (e) {
    AppLogger.logWarning('[Shorts] Background metadata fetcher error: $e');
  } finally {
    _isMetadataFetcherRunning = false;
  }
}

/// Streams related videos one-by-one into the feed as each resolves.
/// Call this after the first batch is loaded. Fire and forget.
Future<void> streamRelatedVideosIntoFeed(yt.Video seedVideo) async {

  if (_isRelatedFeedRunning) return;
  if (_usedSeedIds.contains(seedVideo.id.value)) {
    AppLogger.log('[Shorts] Seed already used: "${seedVideo.title}", skipping.');
    return;
  }
  _usedSeedIds.add(seedVideo.id.value);
  _isRelatedFeedRunning = true;

  final ytClient = yt.YoutubeExplode();
  try {
    AppLogger.log('[Shorts] Related stream kicked off for "${seedVideo.title}"');
    List<yt.Video> allRelated = [];
    try {
      final related = await ytClient.videos.getRelatedVideos(seedVideo);
      if (related != null) {
        allRelated = related.whereType<yt.Video>().toList();
      }
    } catch (_) {}

    if (allRelated.isEmpty) {
      AppLogger.log('[Shorts] getRelatedVideos returned 0 results. Running search fallback using keywords...');
      final titleKeywords = seedVideo.title
          .replaceAll(RegExp(r'[#@\-–_|]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final fallbackQuery = titleKeywords.split(' ').take(3).join(' ') + ' shorts';
      AppLogger.log('[Shorts] Fallback search query: "$fallbackQuery"');
      try {
        final searchPage = await ytClient.search.search(fallbackQuery);
        allRelated = searchPage.whereType<yt.Video>().toList();
      } catch (e) {
        AppLogger.logWarning('[Shorts] Fallback search failed: $e');
      }
    }

    final shortRelated = allRelated.where((v) => v.duration != null && v.duration!.inSeconds <= 90).toList();
    AppLogger.log('[Shorts] Related: ${allRelated.length} total, ${shortRelated.length} are ≤90s');

    for (final item in shortRelated) {
      if (isYouTubeShortsLoading) break;

      final existingUrls = globalYouTubeShorts.value.map((v) => v['title']).toSet();
      if (existingUrls.contains(item.title)) continue;

      try {
        final manifest = await ytClient.videos.streams.getManifest(
          item.id,
          ytClients: [yt.YoutubeApiClient.android],
        );
        final muxedStreams = manifest.muxed.sortByVideoQuality();
        if (muxedStreams.isEmpty) continue;
        final stream = muxedStreams.first;
        
        globalYouTubeShorts.value = [
          ...globalYouTubeShorts.value,
          {
            'title': item.title,
            'thumbnail': 'https://img.youtube.com/vi/${item.id.value}/hqdefault.jpg',
            'stream_url': stream.url.toString(),
            'duration': item.duration?.inSeconds ?? 0,
            'publish_date': (item.publishDate ?? item.uploadDate)?.toIso8601String(),
            'seedVideo': item,
          }
        ];
        AppLogger.log('[Shorts] 🔁 Related appended: "${item.title}"');
      } catch (_) {
        continue;
      }
    }
  } catch (e) {
    AppLogger.logWarning('[Shorts] Related fetch failed: $e');
  } finally {
    _isRelatedFeedRunning = false;
    ytClient.close();
  }
}

List<String> allTheFavoriteVideosList = [];

ValueNotifier<List<NovaPlaylist>> playListnotifier = ValueNotifier([]);

// Shorts PiP State
ValueNotifier<Player?> activeShortsPlayer = ValueNotifier(null);
ValueNotifier<VideoController?> activeShortsVideoController = ValueNotifier(null);
ValueNotifier<bool> isShortsScrolling = ValueNotifier(false);
ValueNotifier<bool> isShortsTabActive = ValueNotifier(false);
ValueNotifier<bool> isShortsAutoPlay = ValueNotifier(false);
ValueNotifier<bool> isShortsPiPMode = ValueNotifier(false);
ValueNotifier<bool> isShortsPiPError = ValueNotifier(false);

// Main Video PiP State
ValueNotifier<bool> isMainPiPMode = ValueNotifier(false);
ValueNotifier<Player?> activeMainPlayer = ValueNotifier(null);
ValueNotifier<VideoController?> activeMainVideoController = ValueNotifier(null);
ValueNotifier<List<AssetEntity>> mainPiPVideoList = ValueNotifier([]);
ValueNotifier<int> mainPiPVideoIndex = ValueNotifier(0);
ValueNotifier<int> mainPipActionTrigger = ValueNotifier(0); // 1 for next, 2 for prev

ValueNotifier<int> homeTabNotifier = ValueNotifier(0);
ValueNotifier<int> pipActionTrigger = ValueNotifier(0);


// Hardware Capability State
enum DeviceTier { lowEnd, midRange, flagship }
DeviceTier deviceTier = DeviceTier.midRange;
double totalRamGb = 0.0;

// Alias — keeps all existing isLowEndDevice usages compiling:
bool get isLowEndDevice => deviceTier == DeviceTier.lowEnd;

Future<void> checkHardwareCapability() async {
  try {
    const platform = MethodChannel('com.thenowavideoplayer.app/hardware');
    final String ramStr = await platform.invokeMethod('getTotalRAM');
    final int totalRamInBytes = int.parse(ramStr);
    final double totalRamInGB = totalRamInBytes / (1024 * 1024 * 1024);
    debugPrint("Total System RAM: ${totalRamInGB.toStringAsFixed(2)} GB");
    
    totalRamGb = totalRamInGB; // store before the check

    if (totalRamInGB <= 2.0) {
      deviceTier = DeviceTier.lowEnd;
      debugPrint("Device classified as LOW END. Enforcing strict video decoder limits.");
    } else if (totalRamInGB <= 4.0) {
      deviceTier = DeviceTier.midRange;
      debugPrint("Device classified as MID RANGE. Enabling moderate background preloading.");
    } else {
      deviceTier = DeviceTier.flagship;
      debugPrint("Device classified as FLAGSHIP. Enabling full layout preloading.");
    }
  } catch (e) {
    debugPrint("Failed to get RAM: $e");
    // Default to strict lowEnd if we can't tell, to be safe
    deviceTier = DeviceTier.lowEnd;
  }
}

// void addPlaylist(String playlistName,Playlist playlist)async {

//   final playlistDB=await Hive.openBox<Playlist>('playlist_db');
//     if (playlistDB.values.any((Playlist) => Playlist.name==playlistName)) {
//      print('allready exist');
//     }else{
//           final id = await playlistDB.add(playlist);
//           playlist.uniqueId=id;

//     }

//   if (playListnotifier.value.any((playlist) => playlist.name == playlistName)) {
//      print('already exist');
//     return;
//   }  else{
//       final newPlaylist = Playlist(name: playlistName);
//   playListnotifier.value.add(newPlaylist);
//   playListnotifier.notifyListeners();
//   }

// }
   

late List<AssetEntity> theAllVideosListFortheSelectionPage;

late List<AssetEntity> theAllShortVideos;

Future<List<AssetEntity>> getShortsVideos(List<AssetEntity> videos) async {
  final result = <AssetEntity>[];

  final settingsBox = Hive.box<dynamic>('appSettings');
  final minDuration = settingsBox.get('shortsMinDuration', defaultValue: 2.0) as double;
  final maxDuration = settingsBox.get('shortsMaxDuration', defaultValue: 180.0) as double;
  final includeHorizontal = settingsBox.get('shortsIncludeHorizontal', defaultValue: false) as bool;

  for (final video in videos) {
    final int durationSecs = video.videoDuration.inSeconds > 0
        ? video.videoDuration.inSeconds
        : video.duration;

    // Use orientatedWidth/Height — photo_manager applies rotation metadata
    // so these reflect actual display dimensions, not raw sensor dimensions
    final int displayWidth = video.orientatedWidth;
    final int displayHeight = video.orientatedHeight;

    final bool isPortrait;
    if (displayWidth == 0 || displayHeight == 0) {
      isPortrait = true; // unknown — assume portrait
    } else {
      isPortrait = displayHeight > displayWidth;
    }

    if (!includeHorizontal && !isPortrait) {
      continue;
    }

    if (durationSecs == 0 || (durationSecs >= minDuration && durationSecs <= maxDuration)) {
      result.add(video);
    }
  }

  AppLogger.log('getShortsVideos: ${videos.length} checked, ${result.length} found');
  result.shuffle();
  return result;
}

// void addToPlaylist(PlayListModel value)async{

//    playListnotifier.value.add(value);
//     playListnotifier.notifyListeners();
//     print('added');

// }
getAllPlayListFromDb() async {
  final playlistDB = await Hive.openBox<NovaPlaylist>('playlist_db');
  playListnotifier.value.clear();
  playListnotifier.value.addAll(playlistDB.values);
  playListnotifier.notifyListeners();
}

// List<AssetEntity> getAssetsFromIds(List<String> ids) {
//   final List<AssetEntity> assets = [];
//   for (String id in ids) {
//     final AssetEntity asset = AssetEntity.fromId(id) as AssetEntity;
//     assets.add(asset);
//   }
//   return assets;
// }
List<AssetEntity> getAssetsFromIds(
    List<AssetEntity> allVideos, List<String> ids) {
  List<AssetEntity> playlistVideos = [];

  for (String id in ids) {
    AssetEntity? video = allVideos.firstWhere((video) => video.id == id);
    playlistVideos.add(video);
  }

  return playlistVideos;
}
