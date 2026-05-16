import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nova_videoplayer/functions/global_variables.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../../functions/history.dart';
import '../../../functions/app_logger.dart';
import '../../../settings/shorts_settings_screen.dart';

class ShortsPageTry extends StatefulWidget {
  const ShortsPageTry({super.key, required this.shortVideos});
  final List<AssetEntity> shortVideos;

  @override
  State<ShortsPageTry> createState() => _ShortsPageTryState();
}

class _ShortsPageTryState extends State<ShortsPageTry> {
  late PageController _pageController;
  final ValueNotifier<int> _currentIndexNotifier = ValueNotifier<int>(0);

  // Preload Caches for Flagship devices
  final Map<int, Player> _preloadedPlayers = {};
  final Map<int, VideoController> _preloadedControllers = {};
  final Map<int, File?> _preloadedFiles = {};

  @override
  void initState() {
    super.initState();
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
      if (i < 0 || i >= widget.shortVideos.length) continue;
      // Trigger in background, result intentionally not awaited here
      widget.shortVideos[i].file;
    }
  }

  // Native Engine Preload: Initialize media_kit engines for surrounding videos
  void _preloadAdjacentVideos(int currentIndex) async {
    if (isLowEndDevice) return; // low-end: skip entirely

    for (final offset in [1, -1]) {
      final i = currentIndex + offset;
      if (i < 0 || i >= widget.shortVideos.length) continue;
      if (_preloadedPlayers.containsKey(i)) continue; // already done

      final file = await widget.shortVideos[i].file;
      if (!mounted) return;
      if (file == null) continue;
      
      final player = Player();
      final controller = VideoController(player);
      // open but don't play
      await player.open(Media(file.path), play: false); 
      
      if (!mounted) {
        player.dispose();
        return;
      }
      
      _preloadedPlayers[i] = player;
      _preloadedControllers[i] = controller;
      _preloadedFiles[i] = file;
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
    if (currentIndex < widget.shortVideos.length - 1) {
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
    if (widget.shortVideos.isEmpty) {
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
          child: NotificationListener<ScrollNotification>(
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
            itemCount: widget.shortVideos.length,
            itemBuilder: (BuildContext context, int index) {
              return ValueListenableBuilder<int>(
                valueListenable: _currentIndexNotifier,
                builder: (context, activeIndex, child) {
                  return VideoPLayerPageForShorts(
                    video: widget.shortVideos[index],
                    isActive: activeIndex == index,
                    onVideoEnd: _scrollToNext,
                    preloadedPlayer: _preloadedPlayers[index],
                    preloadedController: _preloadedControllers[index],
                    preloadedFile: _preloadedFiles[index],
                    onClaimPreload: () => _claimPreloadedPlayer(index),
                  );
                },
              );
            },
            onPageChanged: (int pageIndex) {
              _currentIndexNotifier.value = pageIndex;
              _prefetchFiles(pageIndex);
              _preloadAdjacentVideos(pageIndex);
            },
          ),
        ),
        ),
      ),
    );
  }
}

class VideoPLayerPageForShorts extends StatefulWidget {
  final AssetEntity video;
  final bool isActive;
  final VoidCallback onVideoEnd;
  final Player? preloadedPlayer;
  final VideoController? preloadedController;
  final File? preloadedFile;
  final VoidCallback? onClaimPreload;

  const VideoPLayerPageForShorts({
    super.key, 
    required this.video, 
    required this.isActive,
    required this.onVideoEnd,
    this.preloadedPlayer,
    this.preloadedController,
    this.preloadedFile,
    this.onClaimPreload,
  });

  @override
  State<VideoPLayerPageForShorts> createState() => _VideoPLayerPageForShortsState();
}

// Global lock to prevent overlapping hardware decoder requests on low-end devices
bool _globalDecoderLock = false;
DateTime? _decoderLockAcquiredTime;
String? _lockHolderVideoTitle;

class _VideoPLayerPageForShortsState extends State<VideoPLayerPageForShorts> with WidgetsBindingObserver {
  static bool _decoderLock = false;
  Player? _player;
  VideoController? _videoController;
  bool loaded = false;
  bool isTurboMode = false;
  bool hasError = false;
  bool _isManuallyPaused = false;
  bool _isPlayingCache = false;
  bool _ownsPlayer = false; // Tracks if this widget created the engine natively
  Uint8List? _cachedThumbnail;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadThumbnail();
    
    if (isLowEndDevice) {
      if (widget.isActive) _initializeForLowEnd();
    } else {
      _initializeForFlagship();
    }
  }

  Future<void> _loadThumbnail() async {
    final data = await widget.video.thumbnailData;
    if (mounted) setState(() => _cachedThumbnail = data);
  }

  @override
  void didUpdateWidget(VideoPLayerPageForShorts oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (isLowEndDevice && widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        if (_player == null && !loaded && !hasError) {
          _initializeForLowEnd();
        }
      } else {
        _disposeVideoPlayer();
      }
    } else if (!isLowEndDevice && widget.isActive != oldWidget.isActive) {
      // Flagships also might need to resume if they were paused
      if (widget.isActive && _player == null && !loaded && !hasError) {
        _initializeForFlagship();
      }
    }
    _syncPlayback();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _player?.pause();
    } else if (state == AppLifecycleState.resumed && widget.isActive && (isShortsTabActive.value || isShortsPiPMode.value)) {
      _player?.play();
    }
  }

  void _syncPlayback() {
    if (_player != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.isActive && (isShortsTabActive.value || isShortsPiPMode.value)) {
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

  void _disposeVideoPlayer({bool isDisposing = false}) {
    if (_player != null) {
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
    WidgetsBinding.instance.removeObserver(this);
    _disposeVideoPlayer(isDisposing: true);
    super.dispose();
  }

  void _initializeForLowEnd() async {
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
      bool shouldPlay = widget.isActive && (isShortsTabActive.value || isShortsPiPMode.value) && !_isManuallyPaused;
      
      // Wrap native player opening in a hard 6-second timeout to prevent C++ thread blocks from freezing Dart
      await _player!.open(Media(file.path), play: shouldPlay).timeout(const Duration(seconds: 6));
      
      if (!mounted) {
        _player!.dispose();
        return;
      }
      _player!.setPlaylistMode(isShortsAutoPlay.value ? PlaylistMode.none : PlaylistMode.single);

      _player!.stream.playing.listen((playing) {
        if (mounted) setState(() => _isPlayingCache = playing);
      });

      _player!.stream.completed.listen((completed) {
        if (completed && isShortsAutoPlay.value && widget.isActive) {
          widget.onVideoEnd();
        }
      });

      isShortsTabActive.addListener(_syncPlayback);
      isShortsPiPMode.addListener(_syncPlayback);
      isShortsAutoPlay.addListener(() {
        _player?.setPlaylistMode(isShortsAutoPlay.value ? PlaylistMode.none : PlaylistMode.single);
      });

      _syncPlayback();

      if (mounted) {
        setState(() {
          loaded = true;
          hasError = false;
        });
        isShortsPiPError.value = false;
        if (widget.isActive) {
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

  void _initializeForFlagship() async {
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

      bool shouldPlay = widget.isActive && (isShortsTabActive.value || isShortsPiPMode.value) && !_isManuallyPaused;
      
      if (shouldPlay) {
        _player!.play();
      }

      _player!.setPlaylistMode(isShortsAutoPlay.value ? PlaylistMode.none : PlaylistMode.single);

      _player!.stream.playing.listen((playing) {
        if (mounted) setState(() => _isPlayingCache = playing);
      });

      _player!.stream.completed.listen((completed) {
        if (completed && isShortsAutoPlay.value && widget.isActive) {
          widget.onVideoEnd();
        }
      });

      isShortsTabActive.addListener(_syncPlayback);
      isShortsPiPMode.addListener(_syncPlayback);
      isShortsAutoPlay.addListener(() {
        _player?.setPlaylistMode(isShortsAutoPlay.value ? PlaylistMode.none : PlaylistMode.single);
      });

      _syncPlayback();

      if (mounted) {
        setState(() {
          loaded = true;
          hasError = false;
        });
        isShortsPiPError.value = false;
        if (widget.isActive) {
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
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
      builder: (context) => ValueListenableBuilder<bool>(
        valueListenable: isShortsAutoPlay,
        builder: (context, autoPlay, child) {
          return Container(
            padding: EdgeInsets.symmetric(vertical: 24.h, horizontal: 24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36.w,
                  height: 4.h,
                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(2.r)),
                ),
                SizedBox(height: 24.h),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: SwitchListTile(
                    title: Text('Enable Auto Play', style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w600)),
                    subtitle: Text('Automatically swipe to the next video', style: TextStyle(color: Colors.white30, fontSize: 11.sp)),
                    value: autoPlay,
                    activeColor: colorGreen,
                    onChanged: (val) {
                      isShortsAutoPlay.value = val;
                      Navigator.pop(context);
                    },
                  ),
                ),
                SizedBox(height: 12.h),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: ListTile(
                    leading: Icon(Icons.picture_in_picture_alt_rounded, color: colorGreen),
                    title: Text('Enable Picture-in-Picture', style: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.w600)),
                    subtitle: Text('Watch this short while browsing', style: TextStyle(color: Colors.white30, fontSize: 11.sp)),
                    onTap: () {
                      Navigator.pop(context);
                      isShortsPiPMode.value = true;
                      homeTabNotifier.value = 0;
                    },
                  ),
                ),
              ],
            ),
          );
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

    return GestureDetector(
      behavior: HitTestBehavior.translucent, // Allow instant recognition during snaps
      onLongPressStart: (details) {
        // Activate 2x speed only on the right half of the screen
        final screenWidth = MediaQuery.of(context).size.width;
        if (details.localPosition.dx > screenWidth / 2) {
          _player!.setRate(2.0);
          setState(() => isTurboMode = true);
        }
      },
      onLongPressEnd: (details) {
        _player!.setRate(1.0);
        setState(() => isTurboMode = false);
      },
      onTap: () {
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
            Align(
              alignment: (widget.video.width > widget.video.height) 
                  ? Alignment.center 
                  : Alignment.topCenter,
              child: AspectRatio(
                aspectRatio: widget.video.width > 0 && widget.video.height > 0
                    ? widget.video.width / widget.video.height
                    : 9 / 16,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Show thumbnail instantly using persistent cache to eliminate async layout popping
                    if (_cachedThumbnail != null)
                      Image.memory(_cachedThumbnail!, fit: BoxFit.cover)
                    else
                      Container(color: Colors.black),
                    // Show video over thumbnail ALWAYS, with transparent background so thumbnail shows through
                    if (_videoController != null)
                      Video(
                        controller: _videoController!, 
                        controls: NoVideoControls, 
                        fill: Colors.transparent, // Prevents black flash before frame 1
                        fit: BoxFit.cover, // Matches the cover scaling of the thumbnail perfectly
                      ),
                    // Show subtle loading indicator while initializing
                    if (!loaded)
                      const Center(child: CircularProgressIndicator(color: Colors.white12)),
                  ],
                ),
              ),
            ),
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