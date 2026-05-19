import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../functions/global_variables.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../../functions/history.dart';
import '../../../functions/app_logger.dart';
import '../../../settings/shorts_settings_screen.dart';
import '../../../functions/file_operations.dart';

class ShortsPageTry extends StatefulWidget {
  const ShortsPageTry({super.key, required this.shortVideos});
  final List<AssetEntity> shortVideos;

  @override
  State<ShortsPageTry> createState() => _ShortsPageTryState();
}

class _ShortsPageTryState extends State<ShortsPageTry> with SingleTickerProviderStateMixin {
  late PageController _pageController;
  final ValueNotifier<int> _currentIndexNotifier = ValueNotifier<int>(0);
  late List<AssetEntity> _videos;
  late AnimationController _deleteAnimController;
  int? _deletingIndex;
  String? _deletingTitle;
  int? _deletingSize;

  // Preload Caches for Flagship devices
  final Map<int, Player> _preloadedPlayers = {};
  final Map<int, VideoController> _preloadedControllers = {};
  final Map<int, File?> _preloadedFiles = {};

  @override
  void initState() {
    super.initState();
    _videos = List.from(widget.shortVideos);
    _deleteAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pageController = PageController(initialPage: _currentIndexNotifier.value);
    pipActionTrigger.addListener(_handlePipAction);
    
    // Trigger initial prefetch and preload for the very first videos
    _prefetchFiles(0);
    _preloadAdjacentVideos(0);
  }

  // Background Disk I/O: Pre-fetch video files so paths are ready before rendering
  void _prefetchFiles(int currentIndex) {
    for (final offset in [1, 2, -1]) {
      final i = currentIndex + offset;
      if (i < 0 || i >= _videos.length) continue;
      // Trigger in background, result intentionally not awaited here
      _videos[i].file;
    }
  }

  Future<void> _preloadSingle(int index) async {
    if (index < 0 || index >= _videos.length) return;
    if (_preloadedPlayers.containsKey(index)) return; // already done

    final file = await _videos[index].file;
    if (!mounted) return;
    if (file == null) return;
    
    final player = Player();
    final controller = VideoController(player);
    // open but don't play
    await player.open(Media(file.path), play: false); 
    
    if (!mounted) {
      player.dispose();
      return;
    }
    
    _preloadedPlayers[index] = player;
    _preloadedControllers[index] = controller;
    _preloadedFiles[index] = file;
  }

  // Native Engine Preload: Initialize media_kit engines for surrounding videos
  void _preloadAdjacentVideos(int currentIndex) async {
    if (deviceTier == DeviceTier.lowEnd) return; // no preloading

    if (deviceTier == DeviceTier.midRange) {
      await _preloadSingle(currentIndex + 1); // next only
    } else {
      // flagship: both directions
      await _preloadSingle(currentIndex + 1);
      _preloadSingle(currentIndex - 1); // fire and forget, no await
    }
    
    // Memory Management: Cleanup players outside the ±1 range
    final keysToRemove = _preloadedPlayers.keys.where((k) => (k - currentIndex).abs() > 1).toList();
    for (final k in keysToRemove) {
      _preloadedPlayers[k]?.dispose();
      _preloadedPlayers.remove(k);
      _preloadedControllers.remove(k);
      _preloadedFiles.remove(k);
    }
  }

  void _claimPreloadedPlayer(int index) {
    // Child has taken ownership — remove from our map so cleanup won't dispose it
    _preloadedPlayers.remove(index);
    _preloadedControllers.remove(index);
    _preloadedFiles.remove(index);
  }

  void _handlePipAction() {
    if (pipActionTrigger.value == 1) {
      activeShortsPlayer.value = null;
      activeShortsVideoController.value = null;
      _scrollToNext();
      pipActionTrigger.value = 0;
    } else if (pipActionTrigger.value == 2) {
      activeShortsPlayer.value = null;
      activeShortsVideoController.value = null;
      _scrollToPrev();
      pipActionTrigger.value = 0;
    }
  }

  @override
  void dispose() {
    pipActionTrigger.removeListener(_handlePipAction);
    _deleteAnimController.dispose();
    _pageController.dispose();
    _currentIndexNotifier.dispose();
    
    // Clean up all preloaded native engines
    for (var player in _preloadedPlayers.values) {
      player.dispose();
    }
    _preloadedPlayers.clear();
    _preloadedControllers.clear();
    _preloadedFiles.clear();
    super.dispose();
  }

  void _scrollToPrev() {
    final currentIndex = _currentIndexNotifier.value;
    if (currentIndex > 0) {
      if (isShortsPiPMode.value) {
        _pageController.jumpToPage(currentIndex - 1);
      } else {
        _pageController.previousPage(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      }
    }
  }

  void _scrollToNext() {
    final currentIndex = _currentIndexNotifier.value;
    if (currentIndex < _videos.length - 1) {
      if (isShortsPiPMode.value) {
        _pageController.jumpToPage(currentIndex + 1);
      } else {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_videos.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.video_collection_outlined, size: 72.sp, color: Colors.white24),
                SizedBox(height: 24.h),
                Text(
                  "No Shorts Found",
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  "Try adjusting your minimum/maximum duration preferences or enable horizontal videos in your Feed Settings.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.white54,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 32.h),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorGreen,
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24.r),
                    ),
                    elevation: 8,
                    shadowColor: colorGreen.withValues(alpha: 0.4),
                  ),
                  icon: Icon(Icons.tune_rounded, size: 18.sp),
                  label: Text(
                    "Feed Settings",
                    style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ShortsSettingsScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false, // Bottom is already handled by Padding
        child: Padding(
          padding: EdgeInsets.only(bottom: 68.h),
          child: Stack(
            fit: StackFit.expand,
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollStartNotification) {
                    isShortsScrolling.value = true;
                  } else if (notification is ScrollEndNotification) {
                    isShortsScrolling.value = false;
                  }
                  return true;
                },
                child: PageView.builder(
                  scrollDirection: Axis.vertical,
                  controller: _pageController,
                  physics: const PageScrollPhysics(parent: ClampingScrollPhysics()), // snappy, no bounce
                  itemCount: _videos.length,
                  itemBuilder: (BuildContext context, int index) {
                    final isDeleting = index == _deletingIndex;
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        VideoPLayerPageForShorts(
                          key: ValueKey(_videos[index].id),
                          video: _videos[index],
                          index: index,
                          activeIndexNotifier: _currentIndexNotifier,
                          onVideoEnd: _scrollToNext,
                          preloadedPlayer: _preloadedPlayers[index],
                          preloadedController: _preloadedControllers[index],
                          preloadedFile: _preloadedFiles[index],
                          onClaimPreload: () => _claimPreloadedPlayer(index),
                          onPreloadSingle: _preloadSingle,
                          onVideoDeleted: (asset) async {
                            final currentIndex = _currentIndexNotifier.value;

                            // 1. Stop playback immediately
                            activeShortsPlayer.value?.pause();

                            // Fetch asset metadata for the animation
                            String? title = asset.title;
                            int? size;
                            try {
                              final file = await asset.file;
                              size = await file?.length();
                            } catch (_) {}

                            // 2. Mark this index as deleting and play Google Files Clean animation
                            if (mounted) {
                              setState(() {
                                _deletingIndex = currentIndex;
                                _deletingTitle = title;
                                _deletingSize = size;
                              });
                            }
                            _deleteAnimController.forward();
                            
                            // Wait for the full animation sequence (1500ms)
                            await Future.delayed(const Duration(milliseconds: 1500));
                            if (!mounted) return;

                            // 3. Scroll to adjacent video if possible
                            final hasNext = currentIndex < _videos.length - 1;
                            final hasPrev = currentIndex > 0;

                            if (hasNext) {
                              // Scroll down to next short
                              await _pageController.animateToPage(
                                currentIndex + 1,
                                duration: const Duration(milliseconds: 600),
                                curve: Curves.easeInOutCubic,
                              );
                            } else if (hasPrev) {
                              // Scroll up to previous short
                              await _pageController.animateToPage(
                                currentIndex - 1,
                                duration: const Duration(milliseconds: 600),
                                curve: Curves.easeInOutCubic,
                              );
                            }

                            // 4. Mutate list while hidden/scrolled away
                            if (mounted) {
                              setState(() {
                                _videos.removeWhere((v) => v.id == asset.id);
                                _deletingIndex = null;
                                _deletingTitle = null;
                                _deletingSize = null;
                              });
                            }

                            // 5. Instantly jump to the correct index in the new list to align state
                            if (_videos.isEmpty) {
                              // Scaffold will rebuild to show empty screen
                            } else if (hasNext) {
                              _pageController.jumpToPage(currentIndex);
                            } else if (hasPrev) {
                              _pageController.jumpToPage(currentIndex - 1);
                            }

                            // Reset animation controller instantly for the next deletion
                            _deleteAnimController.reset();
                          },
                        ),
                        if (isDeleting)
                          IgnorePointer(
                            child: _GoogleFilesCleanAnimation(
                              animation: _deleteAnimController,
                              videoTitle: _deletingTitle ?? 'Unknown',
                              videoSize: _deletingSize,
                              hasMoreVideos: _videos.length > 1,
                            ),
                          ),
                      ],
                    );
                  },
                  onPageChanged: (int pageIndex) {
                    _currentIndexNotifier.value = pageIndex;
                    _prefetchFiles(pageIndex);
                    _preloadAdjacentVideos(pageIndex);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VideoPLayerPageForShorts extends StatefulWidget {
  final AssetEntity video;
  final int index;
  final ValueNotifier<int> activeIndexNotifier;
  final VoidCallback onVideoEnd;
  final Player? preloadedPlayer;
  final VideoController? preloadedController;
  final File? preloadedFile;
  final VoidCallback? onClaimPreload;
  final Future<void> Function(int index)? onPreloadSingle;
  final Function(AssetEntity)? onVideoDeleted;

  const VideoPLayerPageForShorts({
    super.key, 
    required this.video, 
    required this.index,
    required this.activeIndexNotifier,
    required this.onVideoEnd,
    this.preloadedPlayer,
    this.preloadedController,
    this.preloadedFile,
    this.onClaimPreload,
    this.onPreloadSingle,
    this.onVideoDeleted,
  });

  @override
  State<VideoPLayerPageForShorts> createState() => _VideoPLayerPageForShortsState();
}

// Global lock to prevent overlapping hardware decoder requests on low-end devices
bool _globalDecoderLock = false;
DateTime? _decoderLockAcquiredTime;
String? _lockHolderVideoTitle;

class _VideoPLayerPageForShortsState extends State<VideoPLayerPageForShorts> with WidgetsBindingObserver {
  Player? _player;
  VideoController? _videoController;
  bool loaded = false;
  bool isTurboMode = false;
  bool hasError = false;
  bool _isManuallyPaused = false;
  bool _isPlayingCache = false;
  bool _ownsPlayer = false; // Tracks if this widget created the engine natively
  Uint8List? _cachedThumbnail;

  bool get _isActive => widget.activeIndexNotifier.value == widget.index;
  bool _wasActive = false;
  
  // Stream Subscriptions to prevent leaks
  StreamSubscription? _playingSub;
  StreamSubscription? _completedSub;

  int? _fileSizeBytes;


  @override
  void initState() {
    super.initState();
    _wasActive = _isActive;
    widget.activeIndexNotifier.addListener(_onActiveIndexChanged);
    WidgetsBinding.instance.addObserver(this);
    _loadThumbnail();
    
    _initDeviceTierState();
  }

  void _loadFileSizeBytes() async {
    try {
      final file = await widget.video.file;
      if (file != null && mounted) {
        final length = await file.length();
        setState(() => _fileSizeBytes = length);
      }
    } catch (_) {}
  }

  void _initDeviceTierState() async {
    switch (deviceTier) {
      case DeviceTier.lowEnd:
        if (_isActive) _initializeForLowEnd();
        return;

      case DeviceTier.midRange:
      case DeviceTier.flagship:
        if (_isActive) await _initializeForFlagship();
        break;
    }
  }

  void _onActiveIndexChanged() async {
    final currentlyActive = _isActive;
    if (_wasActive != currentlyActive) {
      _wasActive = currentlyActive;
      
      switch (deviceTier) {
        case DeviceTier.lowEnd:
          if (currentlyActive) {
            if (_player == null && !loaded && !hasError) {
              _initializeForLowEnd();
            }
          } else {
            _disposeVideoPlayer();
          }
          break;

        case DeviceTier.midRange:
        case DeviceTier.flagship:
          if (currentlyActive && _player == null && !loaded && !hasError) {
            await _initializeForFlagship();
          }
          break;
      }
      
      _syncPlayback();
    }
  }

  Future<void> _loadThumbnail() async {
    final data = await widget.video.thumbnailData;
    if (mounted) setState(() => _cachedThumbnail = data);
  }

  @override
  void didUpdateWidget(VideoPLayerPageForShorts oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeIndexNotifier != widget.activeIndexNotifier) {
      oldWidget.activeIndexNotifier.removeListener(_onActiveIndexChanged);
      widget.activeIndexNotifier.addListener(_onActiveIndexChanged);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _player?.pause();
    } else if (state == AppLifecycleState.resumed) {
      _syncPlayback();
    }
  }

  void _syncPlayback() {
    if (_player != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_isActive && (isShortsTabActive.value || isShortsPiPMode.value)) {
          if (!_isManuallyPaused) {
            _player!.play();
          }
          activeShortsPlayer.value = _player;
          activeShortsVideoController.value = _videoController;
        } else {
          _player!.pause();
          _player!.seek(Duration.zero);
          _player!.setRate(1.0);
          setState(() {
            isTurboMode = false;
            _isManuallyPaused = false;
          });
        }
      });
    }
  }

  void _onAutoPlayChanged() {
    _player?.setPlaylistMode(isShortsAutoPlay.value ? PlaylistMode.none : PlaylistMode.single);
  }

  void _disposeVideoPlayer({bool isDisposing = false}) {
    if (_player != null) {
      _playingSub?.cancel();
      _completedSub?.cancel();
      isShortsTabActive.removeListener(_syncPlayback);
      isShortsPiPMode.removeListener(_syncPlayback);
      isShortsAutoPlay.removeListener(_onAutoPlayChanged);

      if (_ownsPlayer) {
        _player!.dispose();
      }
      _player = null;
      _videoController = null;
      if (!isDisposing && mounted) setState(() { loaded = false; hasError = false; });
    }
  }

  @override
  void dispose() {
    widget.activeIndexNotifier.removeListener(_onActiveIndexChanged);
    WidgetsBinding.instance.removeObserver(this);
    _disposeVideoPlayer(isDisposing: true);
    super.dispose();
  }

  Future<void> _initializeForLowEnd() async {
    try {
      AppLogger.log("Shorts: Start low-end initializing video: ${widget.video.title}");
      
      AppLogger.log("Shorts: Low-end device detected. Waiting for decoder lock...");
      final waitStart = DateTime.now();
      
      // Wait for the previous native player to release the lock
      while (_globalDecoderLock) {
        // Safety Check: If the lock has been held by another video for more than 4 seconds,
        // the previous native initialization likely deadlocked in native C++/libmpv.
        // We must force-break the lock to prevent locking out the whole session!
        if (_decoderLockAcquiredTime != null && 
            DateTime.now().difference(_decoderLockAcquiredTime!).inSeconds > 4) {
          AppLogger.logWarning("Shorts: Global decoder lock FORCE-BROKEN! Held by '$_lockHolderVideoTitle' too long.");
          _globalDecoderLock = false;
          break;
        }

        await Future.delayed(const Duration(milliseconds: 100));
        
        // Guard against infinite loops inside this item's wait
        if (DateTime.now().difference(waitStart).inSeconds > 8) {
          AppLogger.logWarning("Shorts: Waited 8s for decoder lock. Proceeding anyway to avoid freeze.");
          break;
        }
        
        if (!mounted) {
          AppLogger.log("Shorts: Scrolled away while waiting for decoder lock: ${widget.video.title}");
          return;
        }
      }
      
      _globalDecoderLock = true;
      _decoderLockAcquiredTime = DateTime.now();
      _lockHolderVideoTitle = widget.video.title;
      
      AppLogger.log("Shorts: Decoder lock acquired. Adding 300ms delay...");
      await Future.delayed(const Duration(milliseconds: 300));
      
      if (!mounted) {
        _globalDecoderLock = false;
        _decoderLockAcquiredTime = null;
        AppLogger.log("Shorts: Scrolled away before fetching file: ${widget.video.title}");
        return;
      }

      final file = await widget.video.file.timeout(const Duration(seconds: 5));
      if (!mounted) {
        AppLogger.log("Shorts: Scrolled away while fetching file: ${widget.video.title}");
        return;
      }
      if (file == null) {
        if (mounted) setState(() => hasError = true);
        isShortsPiPError.value = true;
        return;
      }

      _player = Player();
      _ownsPlayer = true;
      _videoController = VideoController(_player!);

      // Pass play argument directly based on active state to guarantee playback
      bool shouldPlay = _isActive && (isShortsTabActive.value || isShortsPiPMode.value) && !_isManuallyPaused;
      
      // Wrap native player opening in a hard 6-second timeout to prevent C++ thread blocks from freezing Dart
      await _player!.open(Media(file.path), play: shouldPlay).timeout(const Duration(seconds: 6));
      
      if (!mounted) {
        _player!.dispose();
        return;
      }
      _player!.setPlaylistMode(isShortsAutoPlay.value ? PlaylistMode.none : PlaylistMode.single);

      _playingSub = _player!.stream.playing.listen((playing) {
        if (mounted) setState(() => _isPlayingCache = playing);
      });

      _completedSub = _player!.stream.completed.listen((completed) {
        if (completed && isShortsAutoPlay.value && _isActive) {
          widget.onVideoEnd();
        }
      });

      isShortsTabActive.addListener(_syncPlayback);
      isShortsPiPMode.addListener(_syncPlayback);
      isShortsAutoPlay.addListener(_onAutoPlayChanged);

      _syncPlayback();

      if (mounted) {
        setState(() {
          loaded = true;
          hasError = false;
        });
        isShortsPiPError.value = false;
        if (_isActive) {
          HistoryVideos.addToHistory(widget.video);
        }
      }
      AppLogger.log("Shorts: Low-end initialization complete for: ${widget.video.title}");
    } catch (e, stackTrace) {
      AppLogger.logError("Shorts Video Error on ${widget.video.title}", e, stackTrace);
      isShortsPiPError.value = true;
      if (mounted) {
        setState(() {
          hasError = true;
          loaded = false; // Ensure loading spinner goes away
        });
        
        // Show exact native exception on-screen for Release APK debugging
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Decoder Error: ${e.toString()}", style: TextStyle(fontSize: 12.sp, color: Colors.white)),
            backgroundColor: Colors.red.shade900,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'COPY ERROR',
              textColor: Colors.white,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: e.toString()));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Error copied to clipboard"), duration: Duration(seconds: 2)),
                );
              },
            ),
          ),
        );
      }
    } finally {
      _globalDecoderLock = false;
      _decoderLockAcquiredTime = null;
      AppLogger.log("Shorts: Decoder lock released for: ${widget.video.title}");
    }
  }

  Future<void> _initializeForFlagship() async {
    try {
      AppLogger.log("Shorts: Start flagship initialization: ${widget.video.title}");
      
      File? file = widget.preloadedFile;
      _player = widget.preloadedPlayer;
      _videoController = widget.preloadedController;

      if (file == null || _player == null || _videoController == null) {
        // Cache miss (e.g. fast scrolling), fetch dynamically
        AppLogger.log("Shorts: Cache miss, fetching natively on flagship: ${widget.video.title}");
        file = await widget.video.file.timeout(const Duration(seconds: 5));
        if (!mounted) return;
        if (file == null) {
          if (mounted) setState(() => hasError = true);
          isShortsPiPError.value = true;
          return;
        }
        _player = Player();
        _ownsPlayer = true;
        _videoController = VideoController(_player!);
        await _player!.open(Media(file.path), play: false).timeout(const Duration(seconds: 6));
        if (!mounted) {
          _player!.dispose();
          return;
        }
      } else {
        AppLogger.log("Shorts: Cache hit! Instant launch: ${widget.video.title}");
        _ownsPlayer = true;
        widget.onClaimPreload?.call();
      }

      // Guard here before any _player! usage
      if (_player == null) {
        if (mounted) setState(() => hasError = true);
        return;
      }

      bool shouldPlay = _isActive && (isShortsTabActive.value || isShortsPiPMode.value) && !_isManuallyPaused;
      
      if (shouldPlay) {
        _player!.play();
      }

      _player!.setPlaylistMode(isShortsAutoPlay.value ? PlaylistMode.none : PlaylistMode.single);

      _playingSub = _player!.stream.playing.listen((playing) {
        if (mounted) setState(() => _isPlayingCache = playing);
      });

      _completedSub = _player!.stream.completed.listen((completed) {
        if (completed && isShortsAutoPlay.value && _isActive) {
          widget.onVideoEnd();
        }
      });

      isShortsTabActive.addListener(_syncPlayback);
      isShortsPiPMode.addListener(_syncPlayback);
      isShortsAutoPlay.addListener(_onAutoPlayChanged);

      _syncPlayback();

      if (mounted) {
        setState(() {
          loaded = true;
          hasError = false;
        });
        isShortsPiPError.value = false;
        if (_isActive) {
          HistoryVideos.addToHistory(widget.video);
        }
      }
    } catch (e, stackTrace) {
      AppLogger.logError("Shorts Flagship Video Error on ${widget.video.title}", e, stackTrace);
      isShortsPiPError.value = true;
      if (mounted) {
        setState(() {
          hasError = true;
          loaded = false;
        });
      }
    }
  }

  void _openSettingsMenu() {
    try {
      _player?.pause();
      setState(() {
        _isManuallyPaused = true;
      });
    } catch (_) {}

    final video = widget.video;
    if (_fileSizeBytes == null) _loadFileSizeBytes();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      isScrollControlled: true, // allows sheet to size to content
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 32.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── DRAG HANDLE ──
                  Center(
                    child: Container(
                      width: 36.w,
                      height: 3.5.h,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                  ),
                  SizedBox(height: 20.h),

                  // ── VIDEO INFO STRIP ──
                  Container(
                    padding: EdgeInsets.all(12.r),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.06), width: 0.5),
                    ),
                    child: Row(
                      children: [
                        // Thumbnail
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8.r),
                          child: _cachedThumbnail != null
                              ? Image.memory(
                                  _cachedThumbnail!,
                                  width: 52.w,
                                  height: 52.w,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  width: 52.w,
                                  height: 52.w,
                                  color: Colors.white.withValues(alpha: 0.05),
                                  child: Icon(Icons.movie_rounded, color: Colors.white12, size: 20.sp),
                                ),
                        ),
                        SizedBox(width: 12.w),

                        // Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Filename
                              Text(
                                video.title ?? 'Unknown',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                  height: 1.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 6.h),

                              // Meta pills row
                              Wrap(
                                spacing: 6.w,
                                children: [
                                  _MetaPill(label: FileOperations.formatSize(_fileSizeBytes ?? 0)),
                                  _MetaPill(label: FileOperations.formatDuration(video.duration)),
                                  if (video.orientatedWidth > 0)
                                    _MetaPill(label: '${video.orientatedHeight}p'),
                                ],
                              ),
                              SizedBox(height: 6.h),

                              // Location
                              Row(
                                children: [
                                  Icon(Icons.folder_outlined, size: 11.sp, color: Colors.white24),
                                  SizedBox(width: 4.w),
                                  Expanded(
                                    child: Text(
                                      video.relativePath ?? '—',
                                      style: TextStyle(color: Colors.white24, fontSize: 10.sp),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20.h),

                  // ── ORGANIZE LABEL ──
                  Padding(
                    padding: EdgeInsets.only(left: 4.w, bottom: 10.h),
                    child: Text(
                      'ORGANIZE',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.2),
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),

                  // ── COPY ROW ──
                  _ActionRow(
                    iconBg: const Color(0xFF0A1A0E),
                    icon: Icons.copy_all_rounded,
                    iconColor: const Color(0xFF1D9E75),
                    label: 'Copy to folder',
                    subtitle: 'Keep original in place',
                    onTap: () {
                      Navigator.pop(ctx);
                      _openFolderPicker(mode: 'copy');
                    },
                  ),
                  SizedBox(height: 8.h),

                  // ── MOVE ROW ──
                  _ActionRow(
                    iconBg: const Color(0xFF0A0E1A),
                    icon: Icons.drive_file_move_outlined,
                    iconColor: const Color(0xFF378ADD),
                    label: 'Move to folder',
                    subtitle: 'Remove from current location',
                    onTap: () {
                      Navigator.pop(ctx);
                      _openFolderPicker(mode: 'move');
                    },
                  ),
                  SizedBox(height: 8.h),

                  // ── DELETE ROW ──
                  _ActionRow(
                    iconBg: const Color(0xFF1A0505),
                    icon: Icons.delete_outline_rounded,
                    iconColor: const Color(0xFFE24B4A),
                    label: 'Delete video',
                    subtitle: 'Permanently remove this file',
                    labelColor: const Color(0xFFE24B4A),
                    rowBg: const Color(0xFF160A0A),
                    rowBorder: const Color(0xFF2A1010),
                    onTap: () {
                      Navigator.pop(ctx);
                      _openDeleteConfirmation();
                    },
                  ),
                  SizedBox(height: 24.h),

                  // ── DIVIDER WITH PLAYBACK LABEL ──
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.06), thickness: 0.5)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12.w),
                        child: Text(
                          'PLAYBACK',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.2),
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.06), thickness: 0.5)),
                    ],
                  ),
                  SizedBox(height: 16.h),

                  // ── AUTOPLAY ROW ──
                  ValueListenableBuilder<bool>(
                    valueListenable: isShortsAutoPlay,
                    builder: (context, autoPlay, _) {
                      return _ActionRow(
                        iconBg: const Color(0xFF0E1A0E),
                        icon: Icons.play_circle_outline_rounded,
                        iconColor: colorGreen,
                        label: 'Auto play',
                        subtitle: 'Swipe automatically',
                        trailing: Switch(
                          value: autoPlay,
                          onChanged: (val) => isShortsAutoPlay.value = val,
                          activeColor: colorGreen,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onTap: () => isShortsAutoPlay.value = !autoPlay,
                      );
                    },
                  ),
                  SizedBox(height: 8.h),

                  // ── PiP ROW ──
                  _ActionRow(
                    iconBg: const Color(0xFF0E1A0E),
                    icon: Icons.picture_in_picture_alt_rounded,
                    iconColor: colorGreen,
                    label: 'Picture in picture',
                    subtitle: 'Watch while browsing',
                    onTap: () {
                      Navigator.pop(ctx);
                      isShortsPiPMode.value = true;
                      homeTabNotifier.value = 0;
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openDeleteConfirmation() {
    if (_fileSizeBytes == null) _loadFileSizeBytes();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 32.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // drag handle
            Container(
              width: 36.w, height: 3.5.h,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(height: 24.h),

            // thumbnail + info row (same as main sheet)
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.r),
                  child: _cachedThumbnail != null
                      ? Image.memory(_cachedThumbnail!, width: 48.w, height: 48.w, fit: BoxFit.cover)
                      : Container(width: 48.w, height: 48.w, color: Colors.white.withValues(alpha: 0.05)),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.video.title ?? 'Unknown',
                        style: TextStyle(color: Colors.white70, fontSize: 12.sp, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        FileOperations.formatSize(_fileSizeBytes ?? 0),
                        style: TextStyle(color: Colors.white24, fontSize: 10.sp),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),

            // Warning
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: const Color(0xFF1A0505),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: const Color(0xFF2A1010), width: 0.5),
              ),
              child: Column(
                children: [
                  Text(
                    'Permanently delete this video?',
                    style: TextStyle(color: const Color(0xFFE24B4A), fontSize: 13.sp, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'This cannot be undone.',
                    style: TextStyle(color: Colors.red.withValues(alpha: 0.4), fontSize: 10.sp),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),

            // Buttons row
            Row(
              children: [
                // Cancel
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      height: 44.h,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 0.5),
                      ),
                      child: Center(
                        child: Text('Cancel', style: TextStyle(color: Colors.white38, fontSize: 13.sp, fontWeight: FontWeight.w500)),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10.w),

                // Delete
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      try {
                        _player?.pause();
                        _player?.stop();
                      } catch (_) {}

                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      Navigator.pop(ctx);
                      final success = await FileOperations.deleteVideo(
                        context: context,
                        asset: widget.video,
                      );
                      if (success && mounted) {
                        widget.onVideoDeleted?.call(widget.video);
                      } else if (!success && mounted) {
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: Text('Could not delete video', style: TextStyle(fontSize: 12.sp)),
                            backgroundColor: const Color(0xFF1A0505),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    child: Container(
                      height: 44.h,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A0505),
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(color: const Color(0xFF7F1F1F), width: 0.5),
                      ),
                      child: Center(
                        child: Text('Delete', style: TextStyle(color: const Color(0xFFE24B4A), fontSize: 13.sp, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openFolderPicker({required String mode}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) => _FolderPickerSheet(
        video: widget.video,
        mode: mode,
        onComplete: (success) {
          if (success && mode == 'move' && mounted) {
            widget.onVideoDeleted?.call(widget.video);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_rounded, color: Colors.white24, size: 48.sp),
            SizedBox(height: 12.h),
            Text("Video unavailable", style: TextStyle(color: Colors.white30, fontSize: 12.sp)),
          ],
        ),
      );
    }

    final double videoAR = (widget.video.orientatedWidth > 0 && widget.video.orientatedHeight > 0)
        ? widget.video.orientatedWidth / widget.video.orientatedHeight
        : 9.0 / 16.0;
    final double screenAR = MediaQuery.of(context).size.width / 
        (MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - 68.h);

    // If video AR is close to screen AR (within 10%), use contain — no crop needed
    // If it's very different, use cover — fill the screen
    final BoxFit videoFit = (videoAR - screenAR).abs() < 0.1 ? BoxFit.contain : BoxFit.cover;

    return GestureDetector(
      behavior: HitTestBehavior.translucent, // Allow instant recognition during snaps
      onLongPressStart: (details) {
        if (_player == null) return;
        // Activate 2x speed only on the right half of the screen
        final screenWidth = MediaQuery.of(context).size.width;
        if (details.localPosition.dx > screenWidth / 2) {
          _player!.setRate(2.0);
          setState(() => isTurboMode = true);
        }
      },
      onLongPressEnd: (details) {
        if (_player == null) return;
        _player!.setRate(1.0);
        setState(() => isTurboMode = false);
      },
      onTap: () {
        if (_player == null) return;
        setState(() {
          if (_isPlayingCache) {
            _player!.pause();
            _isManuallyPaused = true;
          } else {
            _player!.play();
            _isManuallyPaused = false;
          }
        });
      },
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail — covers full screen, same as video
            if (_cachedThumbnail != null)
              Image.memory(_cachedThumbnail!, fit: videoFit, width: double.infinity, height: double.infinity)
            else
              const SizedBox.shrink(),

            // Video — always fills screen, crops if needed (YouTube behaviour)
            if (_videoController != null)
              Video(
                controller: _videoController!,
                controls: NoVideoControls,
                fill: Colors.transparent,
                fit: videoFit, // dynamically use contain or cover
              ),

            // Show subtle loading indicator while initializing
            if (!loaded)
              const Center(child: CircularProgressIndicator(color: Colors.white12)),
            // Instagram-style 2X Speed Hint
            if (isTurboMode)
              Positioned(
                top: 48.h,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fast_forward_rounded, color: colorGreen, size: 16.sp),
                        SizedBox(width: 6.w),
                        Text('>> 2X SPEED', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11.sp, letterSpacing: 0.8)),
                      ],
                    ),
                  ),
                ),
              ),
            // Playback Indicator
            if (_isManuallyPaused && isShortsTabActive.value && !isTurboMode)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.play_arrow_rounded, size: 52, color: Colors.white70),
                ),
              ),
            // Side Settings Menu
            Positioned(
              right: 12.w,
              bottom: 12.h,
              child: IconButton(
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white54, size: 28),
                onPressed: _openSettingsMenu,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reusable meta pill ──
class _MetaPill extends StatelessWidget {
  final String label;
  const _MetaPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(4.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 0.5),
      ),
      child: Text(label, style: TextStyle(color: Colors.white38, fontSize: 9.sp)),
    );
  }
}

// ── Reusable action row ──
class _ActionRow extends StatelessWidget {
  final Color iconBg;
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final Color? labelColor;
  final Color? rowBg;
  final Color? rowBorder;
  final Widget? trailing;
  final VoidCallback onTap;

  const _ActionRow({
    required this.iconBg,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.labelColor,
    this.rowBg,
    this.rowBorder,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: rowBg ?? Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color: rowBorder ?? Colors.white.withValues(alpha: 0.06),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            // Icon circle
            Container(
              width: 34.w,
              height: 34.w,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 16.sp),
            ),
            SizedBox(width: 12.w),

            // Labels
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: labelColor ?? Colors.white.withValues(alpha: 0.85),
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: labelColor != null
                          ? labelColor!.withValues(alpha: 0.4)
                          : Colors.white.withValues(alpha: 0.22),
                      fontSize: 10.sp,
                    ),
                  ),
                ],
              ),
            ),

            // Trailing widget or chevron
            trailing ??
                Icon(Icons.chevron_right_rounded,
                    color: Colors.white.withValues(alpha: 0.15), size: 18.sp),
          ],
        ),
      ),
    );
  }
}

class _FolderPickerSheet extends StatefulWidget {
  final AssetEntity video;
  final String mode; // 'copy' or 'move'
  final Function(bool success) onComplete;

  const _FolderPickerSheet({
    required this.video,
    required this.mode,
    required this.onComplete,
  });

  @override
  State<_FolderPickerSheet> createState() => _FolderPickerSheetState();
}

class _FolderPickerSheetState extends State<_FolderPickerSheet> {
  List<Map<String, dynamic>> _folders = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  bool _operating = false;
  Map<String, dynamic>? _selected;

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    final folders = await FileOperations.getVideoFolders();
    if (mounted) setState(() { _folders = folders; _filtered = folders; _loading = false; });
  }

  void _onSearch(String q) {
    setState(() {
      _filtered = q.isEmpty
          ? _folders
          : _folders.where((f) => (f['name'] as String).toLowerCase().contains(q.toLowerCase())).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.mode == 'copy' ? 'Copy' : 'Move';
    final buttonLabel = widget.mode == 'copy' ? 'Copy here' : 'Move here';

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollController) => Column(
        children: [
          // Fixed header
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 0),
            child: Column(
              children: [
                // drag handle
                Container(
                  width: 36.w, height: 3.5.h,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                SizedBox(height: 16.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$label to',
                      style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w600),
                    ),
                    // New folder button
                    GestureDetector(
                      onTap: _showNewFolderDialog,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A1A0E),
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(color: const Color(0xFF0F6E56), width: 0.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.create_new_folder_outlined, color: const Color(0xFF1D9E75), size: 13.sp),
                            SizedBox(width: 5.w),
                            Text('New folder', style: TextStyle(color: const Color(0xFF1D9E75), fontSize: 11.sp)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                // Search
                Container(
                  height: 36.h,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.07), width: 0.5),
                  ),
                  child: TextField(
                    onChanged: _onSearch,
                    style: TextStyle(color: Colors.white70, fontSize: 12.sp),
                    decoration: InputDecoration(
                      hintText: 'Search folders...',
                      hintStyle: TextStyle(color: Colors.white24, fontSize: 12.sp),
                      prefixIcon: Icon(Icons.search_rounded, color: Colors.white24, size: 16.sp),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 8.h),
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
              ],
            ),
          ),

          // Folder list
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: colorGreen, strokeWidth: 1.5))
                : ListView.separated(
                    controller: scrollController,
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => SizedBox(height: 6.h),
                    itemBuilder: (ctx, i) {
                      final folder = _filtered[i];
                      final name = folder['name'] as String;
                      final count = folder['videoCount'] as int;
                      final isCurrentFolder = widget.video.relativePath?.contains(name) ?? false;
                      final isSelected = _selected == folder;

                      return GestureDetector(
                        onTap: () => setState(() => _selected = isSelected ? null : folder),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF0A1A0E)
                                : Colors.white.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(10.r),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF0F6E56)
                                  : Colors.white.withValues(alpha: 0.06),
                              width: isSelected ? 1 : 0.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32.w, height: 32.w,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(6.r),
                                ),
                                child: Icon(Icons.folder_outlined,
                                    color: isSelected ? const Color(0xFF1D9E75) : Colors.white24,
                                    size: 16.sp),
                              ),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name,
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.85),
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w500,
                                        )),
                                    Text('$count videos',
                                        style: TextStyle(color: Colors.white24, fontSize: 9.sp)),
                                  ],
                                ),
                              ),
                              if (isCurrentFolder)
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1A1A0A),
                                    borderRadius: BorderRadius.circular(4.r),
                                    border: Border.all(color: const Color(0xFF63480A), width: 0.5),
                                  ),
                                  child: Text('current',
                                      style: TextStyle(color: const Color(0xFFBA7517), fontSize: 8.sp)),
                                )
                              else if (isSelected)
                                Icon(Icons.check_circle_rounded, color: const Color(0xFF1D9E75), size: 16.sp),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Confirm button
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 32.h),
            child: GestureDetector(
              onTap: _selected == null || _operating ? null : _executeOperation,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 48.h,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _selected != null ? colorGreen : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Center(
                  child: _operating
                      ? SizedBox(
                          width: 18.w, height: 18.w,
                          child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                        )
                      : Text(
                          buttonLabel,
                          style: TextStyle(
                            color: _selected != null ? Colors.black : Colors.white24,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _executeOperation() async {
    if (_selected == null) return;

    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    setState(() => _operating = true);

    // Get real path from album or fallback to localPath for newly created folders
    final album = _selected!['album'];
    String destPath;
    if (album != null) {
      final assets = await (album as AssetPathEntity).getAssetListRange(start: 0, end: 1);
      if (assets.isEmpty) { setState(() => _operating = false); return; }
      final sampleFile = await assets.first.file;
      if (sampleFile == null) { setState(() => _operating = false); return; }
      destPath = sampleFile.parent.path;
    } else {
      destPath = _selected!['localPath'] as String;
    }

    if (!mounted) return;

    bool success = false;
    if (widget.mode == 'copy') {
      final result = await FileOperations.copyVideo(asset: widget.video, destinationFolderPath: destPath);
      success = result != null;
    } else {
      success = await FileOperations.moveVideo(context: context, asset: widget.video, destinationFolderPath: destPath);
    }

    if (!mounted) return;
    navigator.pop();
    widget.onComplete(success);
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(
          success ? '${widget.mode == 'copy' ? 'Copied' : 'Moved'} successfully' : 'Operation failed',
          style: TextStyle(fontSize: 12.sp),
        ),
        backgroundColor: success ? const Color(0xFF0A1A0E) : const Color(0xFF1A0505),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
      ),
    );
  }

  void _showNewFolderDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161616),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text('New folder', style: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.w600)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: Colors.white, fontSize: 13.sp),
          decoration: InputDecoration(
            hintText: 'Folder name',
            hintStyle: TextStyle(color: Colors.white24, fontSize: 13.sp),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: colorGreen)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: Colors.white38, fontSize: 12.sp)),
          ),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);

              final basePath = widget.video.relativePath != null
                  ? '/storage/emulated/0/${widget.video.relativePath!.split('/').first}'
                  : '/storage/emulated/0/DCIM';
              final dirPath = '$basePath/$name';
              final dir = Directory(dirPath);
              await dir.create(recursive: true);

              // Immediately inject the new folder into state — don't wait for MediaStore
              if (mounted) {
                setState(() {
                  final newFolder = {
                    'name': name,
                    'path': dirPath,
                    'album': null,       // no MediaStore album entity yet
                    'localPath': dirPath, // use this directly for copy/move
                    'videoCount': 0,
                    'totalSizeBytes': 0,
                  };
                  _folders.insert(0, newFolder); // show at top of list
                  _filtered.insert(0, newFolder);
                  _selected = newFolder; // auto-select it so user can immediately confirm
                });
              }
            },
            child: Text('Create', style: TextStyle(color: colorGreen, fontSize: 12.sp, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _GoogleFilesCleanAnimation extends StatelessWidget {
  final Animation<double> animation;
  final String videoTitle;
  final int? videoSize;
  final bool hasMoreVideos;

  const _GoogleFilesCleanAnimation({
    required this.animation,
    required this.videoTitle,
    this.videoSize,
    required this.hasMoreVideos,
  });

  @override
  Widget build(BuildContext context) {
    final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: animation, curve: const Interval(0.0, 0.20, curve: Curves.easeOut)),
    );

    final scanAnimation = Tween<double>(begin: -0.2, end: 1.2).animate(
      CurvedAnimation(parent: animation, curve: const Interval(0.15, 0.55, curve: Curves.easeInOut)),
    );

    final cardScale = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: animation, curve: const Interval(0.55, 0.85, curve: Curves.easeInBack)),
    );

    final cardTranslateY = Tween<double>(begin: 0.0, end: 220.0).animate(
      CurvedAnimation(parent: animation, curve: const Interval(0.55, 0.85, curve: Curves.easeInBack)),
    );

    final trashBounce = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.3), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 1.3, end: 1.0), weight: 50),
    ]).animate(
      CurvedAnimation(parent: animation, curve: const Interval(0.80, 0.95, curve: Curves.easeInOut)),
    );

    final successScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: animation, curve: const Interval(0.85, 1.0, curve: Curves.elasticOut)),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Opacity(
          opacity: fadeAnimation.value,
          child: Container(
            color: Colors.black.withValues(alpha: 0.92),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Trash bin (cleaning target)
                Positioned(
                  bottom: 140.h,
                  child: Transform.scale(
                    scale: trashBounce.value,
                    child: Container(
                      width: 76.w,
                      height: 76.w,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E0D0D),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF5A1A1A), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE24B4A).withValues(alpha: 0.15),
                            blurRadius: 16.r,
                            spreadRadius: 1.r,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.delete_sweep_rounded,
                        color: const Color(0xFFE24B4A),
                        size: 32.sp,
                      ),
                    ),
                  ),
                ),

                // Sparkles / Stars when item falls into trash
                if (animation.value > 0.8)
                  Positioned(
                    bottom: 160.h,
                    child: Transform.scale(
                      scale: successScale.value,
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.amberAccent,
                        size: 20.sp,
                      ),
                    ),
                  ),

                // Deleting File Card
                Transform.translate(
                  offset: Offset(0, cardTranslateY.value - 40.h),
                  child: Transform.scale(
                    scale: cardScale.value,
                    child: Center(
                      child: Container(
                        width: 210.w,
                        padding: EdgeInsets.all(16.r),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161616),
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(color: Colors.white10, width: 0.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black54,
                              blurRadius: 16.r,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 52.w,
                                  height: 52.w,
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(10.r),
                                  ),
                                  child: Icon(
                                    Icons.video_file_rounded,
                                    color: const Color(0xFFE24B4A),
                                    size: 28.sp,
                                  ),
                                ),
                                SizedBox(height: 12.h),
                                Text(
                                  videoTitle,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (videoSize != null) ...[
                                  SizedBox(height: 4.h),
                                  Text(
                                    FileOperations.formatSize(videoSize!),
                                    style: TextStyle(
                                      color: Colors.white30,
                                      fontSize: 10.sp,
                                    ),
                                  ),
                                ],
                              ],
                            ),

                            // Glowing Scanning line
                            if (animation.value > 0.15 && animation.value < 0.55)
                              Positioned(
                                left: 0,
                                right: 0,
                                top: scanAnimation.value * 110.h,
                                child: Container(
                                  height: 2.h,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        const Color(0xFFE24B4A).withValues(alpha: 0.8),
                                        Colors.transparent,
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFE24B4A).withValues(alpha: 0.6),
                                        blurRadius: 6.r,
                                        spreadRadius: 0.5.r,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Clean Success Title
                if (animation.value > 0.8)
                  Positioned(
                    bottom: 240.h,
                    child: FadeTransition(
                      opacity: successScale,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Space Cleaned!',
                            style: TextStyle(
                              color: colorGreen,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            hasMoreVideos
                                ? 'Moving to next short...'
                                : 'No more shorts left',
                            style: TextStyle(
                              color: Colors.white24,
                              fontSize: 10.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}