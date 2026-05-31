import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:nova_videoplayer/functions/global_variables.dart';
import 'shorts_stream_cache.dart';

class ShortsPoolSlot {
  final Player player;
  final VideoController controller;
  
  int? index;
  String? videoId;
  int generation = 0;
  bool isReady = false;
  bool hasFirstFrame = false;
  String? error;
  
  StreamSubscription? _positionSub;
  StreamSubscription? _playingSub;
  VoidCallback? onStateChanged;

  ShortsPoolSlot({
    required this.player,
    required this.controller,
  });

  void reset() {
    _positionSub?.cancel();
    _playingSub?.cancel();
    _positionSub = null;
    _playingSub = null;
    
    player.stop();
    
    index = null;
    videoId = null;
    generation++;
    isReady = false;
    hasFirstFrame = false;
    error = null;
    onStateChanged = null;
  }

  void dispose() {
    reset();
    player.dispose();
  }
}

class ShortsPlayerPool {
  static const int poolSize = 3;

  final List<ShortsPoolSlot> _slots = [];
  bool _isDisposed = false;

  ShortsPlayerPool() {
    for (int i = 0; i < poolSize; i++) {
      final player = Player();
      final controller = VideoController(player);
      _slots.add(ShortsPoolSlot(player: player, controller: controller));
    }
    debugPrint("[POOL] Initialized player pool with $poolSize slots.");
  }

  ShortsPoolSlot? getSlotForIndex(int index) {
    if (_isDisposed) return null;
    for (final slot in _slots) {
      if (slot.index == index) return slot;
    }
    return null;
  }

  void updateActiveIndex(int activeIndex, List<Map<String, dynamic>> videos) {
    if (_isDisposed || videos.isEmpty) return;

    final startTime = DateTime.now();
    debugPrint("[POOL] assign index $activeIndex (total videos: ${videos.length})");

    // Target indices we want to preload/maintain
    // N-1 (previous), N (current), N+1 (next)
    final List<int> targets = [];
    if (activeIndex - 1 >= 0) targets.add(activeIndex - 1);
    targets.add(activeIndex);
    if (activeIndex + 1 < videos.length) targets.add(activeIndex + 1);

    // Keep tracks of which slots are mapped to which target indices
    final Map<int, ShortsPoolSlot> mappedSlots = {};
    final List<ShortsPoolSlot> unmappedSlots = [];

    // 1. Identify which slots are already pointing to target indices
    for (final slot in _slots) {
      if (slot.index != null && targets.contains(slot.index)) {
        mappedSlots[slot.index!] = slot;
      } else {
        unmappedSlots.add(slot);
      }
    }

    // 2. Map unmapped targets to available/recycled slots
    for (final target in targets) {
      if (!mappedSlots.containsKey(target)) {
        if (unmappedSlots.isNotEmpty) {
          final recycledSlot = unmappedSlots.removeAt(0);
          recycledSlot.reset();
          recycledSlot.index = target;
          recycledSlot.videoId = videos[target]['id'];
          mappedSlots[target] = recycledSlot;
          debugPrint("[POOL] Recycle slot for target index $target (videoId: ${recycledSlot.videoId})");
        }
      }
    }

    // 3. Any remaining unmapped slots are reset and freed
    for (final slot in unmappedSlots) {
      slot.reset();
    }

    // 4. Log warmup target reuse hits/misses
    for (final target in targets) {
      final videoId = videos[target]['id'] as String;
      debugPrint("[POOL] target $target — ${ownsVideo(videoId) ? 'HIT reuse' : 'MISS recycle'} for $videoId");
    }

    // 5. Trigger asynchronous loading/playback updates for the mapped targets (Non-blocking)
    for (final target in targets) {
      final slot = mappedSlots[target]!;
      final videoId = slot.videoId!;
      final isCurrent = (target == activeIndex);

      if (isCurrent) {
        // If it is the current video, play it immediately (or once loaded)
        _activateSlot(slot, videoId, startTime);
      } else {
        // If next/previous, pre-load in a paused state
        _preloadSlot(slot, videoId);
      }
    }
  }

  bool ownsVideo(String videoId) {
    return _slots.any((s) => 
      s.videoId == videoId && 
      s.isReady && 
      s.hasFirstFrame && 
      s.error == null
    );
  }

  void _activateSlot(ShortsPoolSlot slot, String videoId, DateTime startTime) {
    if (slot.isReady && 
        slot.videoId == videoId && 
        slot.hasFirstFrame && 
        slot.error == null) {
      debugPrint("[POOL] HIT reuse — instant play for $videoId");
      slot.player.play();
      isShortsPlaying.value = true;
      activeShortsPlayer.value = slot.player;
      activeShortsVideoController.value = slot.controller;
    } else {
      debugPrint("[POOL] MISS recycle — reloading for $videoId (isReady: ${slot.isReady}, videoMatch: ${slot.videoId == videoId}, hasFirstFrame: ${slot.hasFirstFrame}, error: ${slot.error})");
      _loadMediaInSlot(slot, videoId, playAfterLoad: true, startTime: startTime);
    }
  }

  void _preloadSlot(ShortsPoolSlot slot, String videoId) {
    if (!slot.isReady) {
      _loadMediaInSlot(slot, videoId, playAfterLoad: false);
    } else {
      slot.player.pause();
    }
  }

  Future<void> _loadMediaInSlot(ShortsPoolSlot slot, String videoId, {required bool playAfterLoad, DateTime? startTime}) async {
    final startGen = ++slot.generation;
    debugPrint("[POOL] open start for video $videoId (slot generation: $startGen)");

    try {
      // 1. Get stream URL from the debounced caches
      final String? streamUrl = await ShortsStreamCache.instance.getStreamUrl(videoId);

      if (slot.generation != startGen || _isDisposed) {
        debugPrint("[POOL] stale preload ignored for video $videoId (generation mismatch: $startGen vs ${slot.generation})");
        return;
      }

      if (streamUrl == null) {
        slot.error = "Video stream is not available.";
        slot.onStateChanged?.call();
        return;
      }

      // 2. Open the media paused by default, then coordinate play
      await slot.player.open(Media(streamUrl), play: false);
      await slot.player.setPlaylistMode(PlaylistMode.loop);

      if (slot.generation != startGen || _isDisposed) {
        debugPrint("[POOL] stale preload ignored for video $videoId after native open.");
        return;
      }

      // 3. Setup position sub to check first frame painted
      slot._positionSub = slot.player.stream.position.listen((pos) {
        if (slot.generation != startGen) return;
        
        final hasPosition = pos > Duration.zero;
        final hasSize = slot.player.state.width != null && slot.player.state.height != null;

        if (!slot.hasFirstFrame && (hasPosition || hasSize)) {
          slot.hasFirstFrame = true;
          slot.onStateChanged?.call();
          
          final elapsed = startTime != null ? DateTime.now().difference(startTime).inMilliseconds : -1;
          debugPrint("[POOL] first frame ready for video $videoId (render ready time: ${elapsed}ms)");
        }
      });

      slot._playingSub = slot.player.stream.playing.listen((playing) {
        if (slot.generation != startGen) return;
        if (slot.index != null && activeShortsPlayer.value == slot.player) {
          isShortsPlaying.value = playing;
        }
      });

      slot.isReady = true;
      slot.onStateChanged?.call();

      if (playAfterLoad) {
        debugPrint("[POOL] play active for index ${slot.index} (play triggered after load completion)");
        slot.player.play();
        isShortsPlaying.value = true;
        activeShortsPlayer.value = slot.player;
        activeShortsVideoController.value = slot.controller;
      } else {
        slot.player.pause();
      }
    } catch (e) {
      debugPrint("[POOL] Error loading video in slot: $e");
      if (slot.generation == startGen && !_isDisposed) {
        slot.error = "Failed to load stream. Tap to retry.";
        slot.onStateChanged?.call();
      }
    }
  }

  void clear() {
    for (final slot in _slots) {
      slot.reset();
    }
    debugPrint("[POOL] Cleared pool players.");
  }

  void dispose() {
    _isDisposed = true;
    for (final slot in _slots) {
      slot.dispose();
    }
    _slots.clear();
    debugPrint("[POOL] Disposed player pool.");
  }
}
