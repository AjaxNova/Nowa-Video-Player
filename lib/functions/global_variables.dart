// ignore_for_file: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member

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

/// Fetches YouTube shorts lazily.
/// - [limit]: how many new streams to extract
/// - [append]: true = add to existing list, false = replace
/// - [query]: new search query (triggers fresh YouTube search)
/// - [force]: true = bypass loading guard (used by new searches)
Future<void> prefetchYouTubeShorts({
  int limit = 5,
  bool append = false,
  String? query,
  bool force = false,
}) async {
  // For background appends, skip if already loading
  if (isYouTubeShortsLoading && !force) {
    AppLogger.log('[Shorts] Skipped fetch — already loading (append=$append, force=$force)');
    return;
  }

  final isNewQuery = query != null;

  // If not appending and not a new query and we already have enough, skip
  if (!append && !isNewQuery && globalYouTubeShorts.value.length >= limit) return;

  // If forcing (new search), cancel any stale running fetch
  if (force) _fetchVersion++;
  final myVersion = _fetchVersion;

  isYouTubeShortsLoading = true;
  youtubeShortsError = null;

  if (isNewQuery) {
    currentSearchQuery = query;
    _cachedSearchResults = [];
    _cachedSearchQuery = null;
    _lastSearchPage = null;
    _usedSeedIds.clear();
    _curatedUploadsOffset = 40;
    AppLogger.log('[Shorts] New search query: "$query"');
  }

  final ytClient = yt.YoutubeExplode();
  try {
    // Only search YouTube if we don't have cached results for this query
    if (_cachedSearchQuery != currentSearchQuery || _cachedSearchResults.isEmpty) {
      final List<yt.Video> allResults = [];
      final queryStopwatch = Stopwatch()..start();

      if (currentSearchQuery.trim().toLowerCase() == 'malayalam shorts') {
        AppLogger.log('[Shorts] Fetching uploads directly from default curated channels...');
        final defaultHandles = [
          '@hashireeeee777',
          '@Karikku_Fresh',
          '@TrollMalayalamOfficial',
          '@malayalamcomedyscenes',
          '@sujithbhaktan',
        ];
        final List<List<yt.Video>> channelsLists = [];

        await Future.wait(defaultHandles.map((handle) async {
          final chStopwatch = Stopwatch()..start();
          try {
            final searchContent = await ytClient.search.searchContent(handle);
            String? channelId;
            for (final item in searchContent) {
              if (item is yt.SearchChannel) {
                channelId = item.id.value;
                break;
              }
            }

            if (channelId != null) {
              final uploadsStream = ytClient.channels.getUploads(channelId);
              // Fetch latest 40 videos from each channel to get plenty of candidate shorts
              final videosList = await uploadsStream.take(40).toList();
              // Filter to shorts immediately before interleaving!
              final shortsList = videosList.where((v) => v.duration != null && v.duration!.inSeconds <= 90).toList();
              channelsLists.add(shortsList);
              AppLogger.log('[Shorts] Pulled ${shortsList.length} shorts candidates from channel: $handle in ${chStopwatch.elapsedMilliseconds}ms');
            }
          } catch (e) {
            AppLogger.logWarning('[Shorts] Failed fetching uploads for $handle (${chStopwatch.elapsedMilliseconds}ms): $e');
          }
        }));

        // Interleave the channels lists so we get alternating videos from each channel
        final List<yt.Video> interleaved = [];
        if (channelsLists.isNotEmpty) {
          int maxLen = channelsLists.map((l) => l.length).fold(0, (max, len) => len > max ? len : max);
          for (int i = 0; i < maxLen; i++) {
            for (final list in channelsLists) {
              if (i < list.length) {
                interleaved.add(list[i]);
              }
            }
          }
        }
        allResults.addAll(interleaved);
      } else {
        AppLogger.log('[Shorts] Searching YouTube for "$currentSearchQuery" (parallel queries with hashtags)...');
        
        // Clean query to construct hashtags (e.g. "malayalam shorts" -> "malayalam")
        final queryClean = currentSearchQuery.toLowerCase()
            .replaceAll('shorts', '')
            .replaceAll('short', '')
            .replaceAll('funny', '')
            .replaceAll('reels', '')
            .trim()
            .replaceAll(' ', '');

        final queries = [
          '#${queryClean}shorts',
          '#${queryClean}comedy shorts',
          '#kerala$queryClean shorts',
          '$currentSearchQuery shorts',
        ];

        await Future.wait(queries.map((q) async {
          try {
            final page = await ytClient.search.search(q);
            allResults.addAll(page.whereType<yt.Video>());
            // Store first page of first query for pagination backup
            if (q == queries.first) {
              _lastSearchPage = page;
            }
          } catch (_) {}
        }));
      }

      queryStopwatch.stop();
      AppLogger.log('[Shorts] Metadata candidate search completed in ${queryStopwatch.elapsedMilliseconds}ms. Found ${allResults.length} total results.');

      // Check if this fetch was cancelled by a newer search
      if (_fetchVersion != myVersion) {
        AppLogger.logWarning('[Shorts] Fetch v$myVersion cancelled by newer search v$_fetchVersion');
        return;
      }

      // Cache ALL video results (no duration filter yet — filter when picking)
      _cachedSearchResults = allResults;
      _cachedSearchQuery = currentSearchQuery;

      final shortsCount = _cachedSearchResults.where((v) => v.duration != null && v.duration!.inSeconds <= 90).length;
      AppLogger.log('[Shorts] Cached ${_cachedSearchResults.length} total videos, $shortsCount are ≤90s shorts');
    }

    // Dynamic pagination: If candidates are running low, fetch more pages from YouTube in background
    final existingTitles = globalYouTubeShorts.value.map((v) => v['title'] as String).toSet();
    
    // Find matching candidates with dynamic fallback for durations (up to 90s)
    List<yt.Video> candidates = _cachedSearchResults
        .where((v) => v.duration != null && v.duration!.inSeconds <= 90 && !existingTitles.contains(v.title))
        .toList();

    // Infinite paging trigger: if we have few candidates left, pull more
    if (candidates.length < 5) {
      if (currentSearchQuery.trim().toLowerCase() == 'malayalam shorts') {
        AppLogger.log('[Shorts] Curated candidates low (${candidates.length} left). Pulling next uploads page from channels...');
        _curatedUploadsOffset += 40;
        final defaultHandles = ['@hashireeeee777', '@Karikku_Fresh'];
        final List<List<yt.Video>> channelsLists = [];
        
        await Future.wait(defaultHandles.map((handle) async {
          final chStopwatch = Stopwatch()..start();
          try {
            final searchContent = await ytClient.search.searchContent(handle);
            String? channelId;
            for (final item in searchContent) {
              if (item is yt.SearchChannel) {
                channelId = item.id.value;
                break;
              }
            }
            if (channelId != null) {
              final uploadsStream = ytClient.channels.getUploads(channelId);
              // Fetch latest _curatedUploadsOffset videos
              final videosList = await uploadsStream.take(_curatedUploadsOffset).toList();
              // Filter to shorts immediately
              final shortsList = videosList.where((v) => v.duration != null && v.duration!.inSeconds <= 90).toList();
              channelsLists.add(shortsList);
              AppLogger.log('[Shorts] Pulled ${shortsList.length} shorts candidates from channel: $handle in ${chStopwatch.elapsedMilliseconds}ms');
            }
          } catch (e) {
            AppLogger.logWarning('[Shorts] Failed fetching uploads for $handle: $e');
          }
        }));
        
        // Interleave the channels lists
        final List<yt.Video> interleaved = [];
        if (channelsLists.isNotEmpty) {
          int maxLen = channelsLists.map((l) => l.length).fold(0, (max, len) => len > max ? len : max);
          for (int i = 0; i < maxLen; i++) {
            for (final list in channelsLists) {
              if (i < list.length) {
                interleaved.add(list[i]);
              }
            }
          }
        }
        _cachedSearchResults = interleaved;
        
        // Re-evaluate candidates
        candidates = _cachedSearchResults
            .where((v) => v.duration != null && v.duration!.inSeconds <= 90 && !existingTitles.contains(v.title))
            .toList();
      } else if (_lastSearchPage != null) {
        AppLogger.log('[Shorts] Candidates are low (${candidates.length} left). Fetching next page from YouTube search...');
        try {
          final dynamic nextPage = await _lastSearchPage!.nextPage();
          if (nextPage != null) {
            _lastSearchPage = nextPage;
            final newVideos = nextPage.whereType<yt.Video>().toList();
            _cachedSearchResults.addAll(newVideos);
            AppLogger.log('[Shorts] Appended ${newVideos.length} new videos to cache. Cache size: ${_cachedSearchResults.length}');
            
            // Re-evaluate candidates
            candidates = _cachedSearchResults
                .where((v) => v.duration != null && v.duration!.inSeconds <= 90 && !existingTitles.contains(v.title))
                .toList();
          }
        } catch (e) {
          AppLogger.logWarning('[Shorts] Failed to fetch next page in background: $e');
        }
      }
    }

    // Dynamic duration fallback: If still no videos ≤60s found, relax constraint to ≤180s, then to all available videos
    if (candidates.isEmpty) {
      AppLogger.log('[Shorts] No strict ≤60s shorts found. Relaxing filter to ≤180s...');
      candidates = _cachedSearchResults
          .where((v) => v.duration != null && v.duration!.inSeconds <= 180 && !existingTitles.contains(v.title))
          .toList();
      
      if (candidates.isEmpty) {
        AppLogger.log('[Shorts] No videos ≤180s found. Relaxing filter to any video...');
        candidates = _cachedSearchResults
            .where((v) => !existingTitles.contains(v.title))
            .toList();
      }
    }

    // Try loading cached videos instantly if list is empty and not appending
    final cacheBox = await Hive.openBox('cachedYouTubeShortsBox');
    if (!append && globalYouTubeShorts.value.isEmpty) {
      final cachedList = cacheBox.get(currentSearchQuery) as List?;
      if (cachedList != null && cachedList.isNotEmpty) {
        globalYouTubeShorts.value = cachedList.map((v) => Map<String, dynamic>.from(v)).toList();
        AppLogger.log('[Shorts] Loaded ${globalYouTubeShorts.value.length} cached videos instantly from Hive for query "$currentSearchQuery"');
      }
    }

    final int alreadyPresent = globalYouTubeShorts.value.length;
    final int targetNewCount = append ? limit : (limit - alreadyPresent).clamp(1, limit);
    AppLogger.log('[Shorts] ${candidates.length} unprocessed candidates remain. Target to resolve: $targetNewCount (limit: $limit, alreadyPresent: $alreadyPresent)...');

    if (targetNewCount <= 0) return;

    final List<Map<String, dynamic>> newlyFetched = [];
    int candidateIndex = 0;
    final totalResolveStopwatch = Stopwatch()..start();

    // Helper task to resolve a single video
    Future<void> resolveVideo(yt.Video video) async {
      if (_fetchVersion != myVersion) return;
      if (newlyFetched.length >= targetNewCount) return;

      final stopwatch = Stopwatch()..start();
      final currentProcIndex = newlyFetched.length + 1;
      try {
        final manifest = await ytClient.videos.streams.getManifest(
          video.id,
          ytClients: [yt.YoutubeApiClient.android],
        );
        stopwatch.stop();

        final muxedStreams = manifest.muxed.sortByVideoQuality();
        if (muxedStreams.isNotEmpty) {
          final bestStream = muxedStreams.first;
          final publishDate = (video.publishDate ?? video.uploadDate)?.toIso8601String() ?? DateTime.now().toIso8601String();
          final videoMap = {
            'id': video.id.value,
            'title': video.title,
            'thumbnail': video.thumbnails.mediumResUrl,
            'stream_url': bestStream.url.toString(),
            'duration': video.duration?.inSeconds ?? 0,
            'publish_date': publishDate,
            'seedVideo': video, // store for next round of related
          };

          newlyFetched.add(videoMap);
          final loggedTotalCount = (append || newlyFetched.length >= 3) 
              ? (globalYouTubeShorts.value.length + (newlyFetched.length > 3 || append ? 1 : 3)) 
              : 0;

          AppLogger.log(
            '[Shorts] [$currentProcIndex/$targetNewCount] Resolved successfully in ${stopwatch.elapsedMilliseconds}ms | '
            'Channel: "${video.author}" | Title: "${video.title}" | New Feed Total: $loggedTotalCount'
          );

          // Periodical Append logic:
          if (!append) {
            if (newlyFetched.length == 3) {
              globalYouTubeShorts.value = List.from(newlyFetched);
              AppLogger.log('[Shorts] Released initial threshold of 3 videos to UI.');
            } else if (newlyFetched.length > 3) {
              globalYouTubeShorts.value = [...globalYouTubeShorts.value, videoMap];
            }
          } else {
            globalYouTubeShorts.value = [...globalYouTubeShorts.value, videoMap];
          }
        } else {
          AppLogger.logWarning('[Shorts] [$currentProcIndex/$targetNewCount] No muxed streams for "${video.title}" (took ${stopwatch.elapsedMilliseconds}ms), skipping.');
        }
      } catch (e) {
        stopwatch.stop();
        AppLogger.logWarning(
          '[Shorts] [$currentProcIndex/$targetNewCount] ⚠️ Decryption failed for "${video.title}" '
          'from Channel: "${video.author}" after ${stopwatch.elapsedMilliseconds}ms: $e'
        );
      }
    }

    for (final video in candidates) {
      if (_fetchVersion != myVersion) break;
      if (newlyFetched.length >= targetNewCount) break;
      
      await resolveVideo(video);
      // Small safety delay between sequential requests to prevent triggering YouTube rate limit blocks
      await Future.delayed(const Duration(milliseconds: 300));
    }

    totalResolveStopwatch.stop();
    AppLogger.log('[Shorts] Resolved $targetNewCount streams in total time: ${totalResolveStopwatch.elapsedMilliseconds}ms');

    // Final cancellation check before updating state
    if (_fetchVersion != myVersion) return;

    // Save final merged feed to Hive cache box
    if (globalYouTubeShorts.value.isNotEmpty) {
      // Deduplicate before saving
      final seenIds = <String>{};
      final uniqueFeed = globalYouTubeShorts.value.where((v) {
        final id = v['id'] as String?;
        if (id == null) return true;
        return seenIds.add(id);
      }).toList();

      globalYouTubeShorts.value = uniqueFeed;

      // Save to Hive
      final cacheData = uniqueFeed.map((v) {
        // Strip out the non-serializable yt.Video object before caching
        final cacheMap = Map<String, dynamic>.from(v);
        cacheMap.remove('seedVideo');
        return cacheMap;
      }).toList();

      await cacheBox.put(currentSearchQuery, cacheData);
      AppLogger.log('[Shorts] Saved ${cacheData.length} unique items to Hive cache box under key "$currentSearchQuery"');
    } else if (newlyFetched.isNotEmpty) {
      if (append) {
        globalYouTubeShorts.value = [...globalYouTubeShorts.value, ...newlyFetched];
      } else {
        globalYouTubeShorts.value = newlyFetched;
      }
    } else if (globalYouTubeShorts.value.isEmpty) {
      youtubeShortsError = "No shorts found for '$currentSearchQuery'. Try a different search.";
      AppLogger.logWarning('[Shorts] No shorts found for "$currentSearchQuery"');
    }
  } catch (e, stackTrace) {
    if (_fetchVersion != myVersion) return;
    AppLogger.logError('[Shorts] Fetch error', e, stackTrace);
    youtubeShortsError = e.toString();
  } finally {
    if (_fetchVersion == myVersion) {
      isYouTubeShortsLoading = false;
    }
    ytClient.close();
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
            'thumbnail': item.thumbnails.mediumResUrl,
            'stream_url': stream.url.toString(),
            'duration': item.duration?.inSeconds ?? 0,
            'publish_date': (item.publishDate ?? item.uploadDate)?.toIso8601String() ?? DateTime.now().toIso8601String(),
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
