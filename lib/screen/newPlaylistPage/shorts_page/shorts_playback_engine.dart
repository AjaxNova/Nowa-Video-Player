import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:photo_manager/photo_manager.dart';
import 'shorts_player_pool.dart';
import 'shorts_performance_tracker.dart';

enum VideoPlaybackState {
  idle,       // No player resource assigned
  assigned,   // Player resource allocated but loading not started
  preparing,  // Decoder initializing / media opening
  prepared,   // Decoder initialized, first frame ready
  active,     // Actively playing
}

class ShortsPlaybackConfig {
  final int playerPoolSize;
  final int videoPreloadRange;
  final int maxConcurrentPrepares;

  const ShortsPlaybackConfig({
    this.playerPoolSize = 3,
    this.videoPreloadRange = 1,
    this.maxConcurrentPrepares = 1,
  });
}

class ShortsPlaybackEngine extends ChangeNotifier {
  final ShortsPlaybackConfig config;
  final ShortsPlayerPool pool;

  // Assignments maps videoId to Player/Controller resources
  final Map<String, Player> _assignments = {};
  final Map<String, VideoController> _controllers = {};
  final Map<String, VideoPlaybackState> _states = {};
  
  // Track preparation tracking times for first frame decoded latency
  final Map<String, DateTime> _prepStartTimes = {};

  final List<String> _prepareQueue = [];
  int _activePreparesCount = 0;

  String? _activeVideoId;
  int _activeIndex = 0;
  List<AssetEntity> _videos = [];

  ShortsPlaybackEngine({required this.config})
      : pool = ShortsPlayerPool(poolSize: config.playerPoolSize);

  void updateVideosList(List<AssetEntity> list) {
    _videos = list;
  }

  VideoPlaybackState getState(String videoId) {
    return _states[videoId] ?? VideoPlaybackState.idle;
  }

  Player? getPlayer(String videoId) {
    return _assignments[videoId];
  }

  VideoController? getController(String videoId) {
    return _controllers[videoId];
  }

  List<AssetEntity> get videos => _videos;

  /// Sets the current focused video index and plays it, pausing or preloading others.
  void updateActiveIndex(int activeIndex) {
    if (activeIndex < 0 || activeIndex >= _videos.length) return;
    
    _activeIndex = activeIndex;
    final activeVideo = _videos[activeIndex];
    _activeVideoId = activeVideo.id;

    // 1. Warm up/prepare range: N-2 to N+2
    final Set<String> targetIds = {};
    for (int offset = -config.videoPreloadRange; offset <= config.videoPreloadRange; offset++) {
      final i = activeIndex + offset;
      if (i >= 0 && i < _videos.length) {
        targetIds.add(_videos[i].id);
      }
    }

    // 2. Play active video
    _play(activeVideo.id);

    // 3. Prepare other target videos
    for (final id in targetIds) {
      if (id != _activeVideoId) {
        prepare(id);
      }
    }

    // 4. Clean up / evict players outside the active range
    final toRemove = _assignments.keys.where((id) => !targetIds.contains(id)).toList();
    for (final id in toRemove) {
      _evictPlayer(id);
    }
    notifyListeners();
  }

  void _play(String videoId) async {
    _states[videoId] = VideoPlaybackState.active;
    
    Player? player = _assignments[videoId];
    if (player == null) {
      player = _assignPlayer(videoId);
    }
    
    if (player != null) {
      final state = _states[videoId];
      if (state == VideoPlaybackState.assigned) {
        prepare(videoId);
      }
      player.play();
    }
    notifyListeners();
  }

  void prepare(String videoId) {
    final state = _states[videoId] ?? VideoPlaybackState.idle;
    if (state == VideoPlaybackState.preparing ||
        state == VideoPlaybackState.prepared ||
        state == VideoPlaybackState.active) {
      return; // Idempotent check
    }

    if (!_assignments.containsKey(videoId)) {
      _assignPlayer(videoId);
    }

    _states[videoId] = VideoPlaybackState.preparing;
    _enqueuePrepare(videoId);
    notifyListeners();
  }

  void _enqueuePrepare(String videoId) {
    if (!_prepareQueue.contains(videoId)) {
      _prepareQueue.add(videoId);
    }
    _processQueue();
  }

  void _processQueue() {
    if (_activePreparesCount >= config.maxConcurrentPrepares) return;
    if (_prepareQueue.isEmpty) return;

    final nextId = _prepareQueue.removeAt(0);
    _activePreparesCount++;
    
    _executePrepare(nextId).whenComplete(() {
      _activePreparesCount--;
      _processQueue();
    });
  }

  Future<void> _executePrepare(String videoId) async {
    final player = _assignments[videoId];
    if (player == null) return;

    final asset = _videos.firstWhere((v) => v.id == videoId);
    try {
      final file = await asset.file;
      if (file == null) return;

      _prepStartTimes[videoId] = DateTime.now();
      
      // Perform seek-free load of video files
      await player.open(Media(file.path), play: false);
      
      final startTime = _prepStartTimes.remove(videoId);
      if (startTime != null) {
        final elapsed = DateTime.now().difference(startTime).inMilliseconds;
        ShortsPerformanceTracker.recordFirstFrameTime(videoId, elapsed);
      }
      
      if (_states[videoId] == VideoPlaybackState.preparing) {
        _states[videoId] = VideoPlaybackState.prepared;
      }
    } catch (_) {
      _states[videoId] = VideoPlaybackState.idle;
    }
    notifyListeners();
  }

  Player? _assignPlayer(String videoId) {
    Player? player = pool.acquire();
    
    if (player == null) {
      // Eviction policy: Reclaim player from the assignment furthest from activeIndex
      final furthestId = _getFurthestAssignedVideoId();
      if (furthestId != null) {
        player = _assignments.remove(furthestId);
        _controllers.remove(furthestId);
        _states.remove(furthestId);
        if (player != null) {
          player.stop();
        }
      }
    }

    if (player != null) {
      _assignments[videoId] = player;
      _controllers[videoId] = VideoController(player);
      _states[videoId] = VideoPlaybackState.assigned;
    }
    
    notifyListeners();
    return player;
  }

  String? _getFurthestAssignedVideoId() {
    String? furthestId;
    int maxDistance = -1;

    for (final id in _assignments.keys) {
      // Find index of this video
      final idx = _videos.indexWhere((v) => v.id == id);
      if (idx != -1) {
        final distance = (idx - _activeIndex).abs();
        if (distance > maxDistance) {
          maxDistance = distance;
          furthestId = id;
        }
      }
    }
    return furthestId;
  }

  void _evictPlayer(String videoId) {
    final player = _assignments.remove(videoId);
    _controllers.remove(videoId);
    _states.remove(videoId);
    
    if (player != null) {
      pool.release(player);
    }
    notifyListeners();
  }

  /// Pauses nearby players instead of resetting them
  void pauseVideo(String videoId) {
    final player = _assignments[videoId];
    if (player != null) {
      player.pause();
      if (_states[videoId] == VideoPlaybackState.active) {
        _states[videoId] = VideoPlaybackState.prepared;
      }
    }
    notifyListeners();
  }

  void dispose() {
    pool.dispose();
    _assignments.clear();
    _controllers.clear();
    _states.clear();
    _prepareQueue.clear();
    super.dispose();
  }
}
