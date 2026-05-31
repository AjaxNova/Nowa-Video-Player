import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:nova_videoplayer/functions/global_variables.dart';
import 'shorts_stream_cache.dart';

class ShortsPlayerTile extends StatefulWidget {
  final Map<String, dynamic> videoData;
  final bool isActive;

  const ShortsPlayerTile({
    super.key,
    required this.videoData,
    required this.isActive,
  });

  @override
  State<ShortsPlayerTile> createState() => _ShortsPlayerTileState();
}

class _ShortsPlayerTileState extends State<ShortsPlayerTile> with WidgetsBindingObserver {
  late final Player _player;
  late final VideoController _videoController;
  
  bool _isPlayerReady = false;
  bool _hasFirstFrame = false;
  bool _isManuallyPaused = false;
  bool isTurboMode = false;
  String? _error;

  StreamSubscription? _playingSub;
  StreamSubscription? _positionSub;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _videoController = VideoController(_player);
    WidgetsBinding.instance.addObserver(this);

    isShortsTabActive.addListener(_syncPlayback);
    isShortsPiPMode.addListener(_syncPlayback);

    _initializeVideo();
  }

  @override
  void didUpdateWidget(covariant ShortsPlayerTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.videoData['id'] != oldWidget.videoData['id']) {
      _cleanupCurrentPlayback();
      setState(() {
        _hasFirstFrame = false;
        _isPlayerReady = false;
        _error = null;
      });
      _initializeVideo();
    } else if (widget.isActive != oldWidget.isActive) {
      _syncPlayback();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _player.pause();
    } else if (state == AppLifecycleState.resumed) {
      _syncPlayback();
    }
  }

  void _cleanupCurrentPlayback() {
    _playingSub?.cancel();
    _positionSub?.cancel();
    _player.stop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    isShortsTabActive.removeListener(_syncPlayback);
    isShortsPiPMode.removeListener(_syncPlayback);
    
    _cleanupCurrentPlayback();

    if (activeShortsPlayer.value == _player) {
      activeShortsPlayer.value = null;
      activeShortsVideoController.value = null;
    }

    _player.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    final videoId = widget.videoData['id'];
    try {
      debugPrint("🤖 [ShortsTile] Initializing video ID: $videoId");
      
      // Get the stream URL from in-memory cache layer
      final String? streamUrl = await ShortsStreamCache.instance.getStreamUrl(videoId);
      
      if (streamUrl == null) {
        if (mounted) {
          setState(() {
            _error = "Video stream is not available.";
          });
        }
        return;
      }

      if (!mounted) return;

      await _player.open(Media(streamUrl), play: widget.isActive && isShortsTabActive.value);
      await _player.setPlaylistMode(PlaylistMode.loop);

      _playingSub = _player.stream.playing.listen((playing) {
        if (widget.isActive && mounted) {
          isShortsPlaying.value = playing;
        }
      });

      // The Thumbnail remains visible until position has moved beyond 0 (first frame painted)
      _positionSub = _player.stream.position.listen((pos) {
        if (!_hasFirstFrame && pos > Duration.zero && mounted) {
          setState(() => _hasFirstFrame = true);
          debugPrint("🤖 [ShortsTile] First frame rendered for: $videoId");
        }
      });

      if (mounted) {
        setState(() {
          _isPlayerReady = true;
          _error = null;
        });
        if (widget.isActive) {
          _syncPlayback();
        }
      }
    } catch (e) {
      debugPrint("❌ [ShortsTile] Error resolving stream for: $videoId ($e)");
      if (mounted) {
        setState(() {
          _error = "Error loading video stream. Tap to retry.";
        });
      }
    }
  }

  void _syncPlayback() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.isActive && (isShortsTabActive.value || isShortsPiPMode.value)) {
        if (!_isManuallyPaused) {
          _player.play();
          isShortsPlaying.value = true;
        }
        activeShortsPlayer.value = _player;
        activeShortsVideoController.value = _videoController;
      } else {
        _player.pause();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPressStart: (details) {
        final screenWidth = MediaQuery.of(context).size.width;
        if (details.localPosition.dx > screenWidth / 2) {
          _player.setRate(2.0);
          setState(() => isTurboMode = true);
        }
      },
      onLongPressEnd: (details) {
        _player.setRate(1.0);
        setState(() => isTurboMode = false);
      },
      onTap: () {
        setState(() {
          if (_player.state.playing) {
            _player.pause();
            _isManuallyPaused = true;
            isShortsPlaying.value = false;
          } else {
            _player.play();
            _isManuallyPaused = false;
            isShortsPlaying.value = true;
          }
        });
      },
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Video always underneath
                  if (_isPlayerReady)
                    Video(
                      controller: _videoController,
                      controls: NoVideoControls,
                      fit: BoxFit.cover,
                    ),

                  // Thumbnail + spinner fades OUT only when the first frame renders
                  AnimatedOpacity(
                    opacity: _hasFirstFrame ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 180),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          'https://img.youtube.com/vi/${widget.videoData['id']}/hqdefault.jpg',
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          errorBuilder: (c, o, s) => Container(color: Colors.black87),
                        ),
                        if (!_isPlayerReady && _error == null)
                          Container(
                            color: Colors.black38,
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white70,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Retry Overlay if error occurs (offline/rate-limited)
                  if (_error != null)
                    Container(
                      color: Colors.black87,
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.w),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.wifi_off_rounded, color: Colors.white70, size: 48.sp),
                              SizedBox(height: 12.h),
                              Text(
                                _error!,
                                style: TextStyle(color: Colors.white70, fontSize: 13.sp),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 16.h),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white10,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                                ),
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text("Retry"),
                                onPressed: () {
                                  _initializeVideo();
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

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

            if (_isManuallyPaused && !_player.state.playing && !isTurboMode)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded, size: 52, color: Colors.white70),
                ),
              ),

            Positioned(
              bottom: 30.h,
              left: 20.w,
              right: 80.w,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.videoData['title'] ?? 'Short Video Clip',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      shadows: const [Shadow(blurRadius: 4, color: Colors.black)],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
