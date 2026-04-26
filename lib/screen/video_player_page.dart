import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nova_videoplayer/functions/history.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:video_player/video_player.dart';
import 'package:volume_controller/volume_controller.dart';

import '../functions/global_variables.dart';
import '../functions/gobal_functions.dart';

enum AspectRatioMode { fit, stretch, crop, original }

class VideoPLayerPage extends StatefulWidget {
  final List<AssetEntity> videoList;
  final int initialIndex;

  const VideoPLayerPage({
    super.key,
    required this.videoList,
    required this.initialIndex,
  });

  @override
  State<VideoPLayerPage> createState() => _VideoPLayerPageState();
}

class _VideoPLayerPageState extends State<VideoPLayerPage> with SingleTickerProviderStateMixin {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  int _currentIndex = 0;
  bool _isLoaded = false;
  bool _showControls = true;
  bool _controlsLocked = false;
  Timer? _hideControlsTimer;
  Timer? _progressUpdateTimer;

  bool _isLandscape = true;
  AspectRatioMode _aspectRatioMode = AspectRatioMode.fit;

  // Double-tap overlays
  bool _showForwardOverlay = false;
  bool _showBackwardOverlay = false;
  final int _seekSeconds = 10;

  // Hold-to-seek speed selector
  final List<double> _speedBreakpoints = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0, 4.0];
  double _currentSpeed = 1.0;
  double _activeSpeed = 1.0;
  bool _isHolding = false;
  bool _showSpeedWidget = false;
  double? _holdStartX;
  double? _holdStartY;
  int _activeSpeedIndex = 3;

  // Brightness & Volume
  double _currentBrightness = 0.5;
  double _currentVolume = 0.5;
  bool _showBrightnessOverlay = false;
  bool _showVolumeOverlay = false;
  Timer? _brightnessTimer;
  Timer? _volumeTimer;

  // Drag seeking
  double? _dragStartPosition;
  bool _isDraggingSeeking = false;
  Duration? _seekPreviewPosition;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initializeBrightnessAndVolume();
    _initializeVideoPlayer();
  }

  Future<void> _initializeBrightnessAndVolume() async {
    try {
      _currentBrightness = await ScreenBrightness().current;
    } catch (_) {
      _currentBrightness = 0.5;
    }
    try {
      _currentVolume = await VolumeController.instance.getVolume();
    } catch (_) {
      _currentVolume = 0.5;
    }
    VolumeController.instance.showSystemUI = false;
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _progressUpdateTimer?.cancel();
    _brightnessTimer?.cancel();
    _volumeTimer?.cancel();
    _videoPlayerController.removeListener(_videoListener);
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  void _videoListener() {
    if (mounted && _videoPlayerController.value.isInitialized) {
      if (_videoPlayerController.value.position >= _videoPlayerController.value.duration && 
          !_videoPlayerController.value.isPlaying && 
          _videoPlayerController.value.duration != Duration.zero) {
        _nextVideo();
      }
      setState(() {});
    }
  }

  void _startProgressTimer() {
    _progressUpdateTimer?.cancel();
    _progressUpdateTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted && _videoPlayerController.value.isPlaying) setState(() {});
    });
  }

  Future<void> _initializeVideoPlayer() async {
    setState(() => _isLoaded = false);
    final file = await widget.videoList[_currentIndex].file;
    if (file == null) return;

    _videoPlayerController = VideoPlayerController.file(File(file.path));
    await _videoPlayerController.initialize();
    
    final ar = _videoPlayerController.value.aspectRatio;
    _isLandscape = ar > 1.0;
    _updateOrientation();

    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController,
      autoPlay: true,
      looping: false,
      showControls: false,
      autoInitialize: true,
    );

    _videoPlayerController.addListener(_videoListener);
    _startProgressTimer();
    setState(() => _isLoaded = true);
    _startHideControlsTimer();
    
    // Add to history
    HistoryVideos.addToHistory(widget.videoList[_currentIndex]);
  }

  void _updateOrientation() {
    SystemChrome.setPreferredOrientations(_isLandscape
        ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
        : [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  }

  void _toggleOrientation() {
    setState(() => _isLandscape = !_isLandscape);
    _updateOrientation();
  }

  void _cycleAspectRatio() {
    setState(() {
      _aspectRatioMode = AspectRatioMode.values[(_aspectRatioMode.index + 1) % AspectRatioMode.values.length];
    });
    
    final msgs = {
      AspectRatioMode.fit: 'Fit',
      AspectRatioMode.stretch: 'Stretch',
      AspectRatioMode.crop: 'Crop',
      AspectRatioMode.original: 'Original'
    };
    
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msgs[_aspectRatioMode]!, style: const TextStyle(fontWeight: FontWeight.bold)),
      duration: const Duration(milliseconds: 600),
      backgroundColor: Colors.white.withOpacity(0.1),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: EdgeInsets.only(bottom: MediaQuery.of(context).size.height * 0.15, left: 100, right: 100),
    ));
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    if (!_controlsLocked) {
      _hideControlsTimer = Timer(const Duration(seconds: 4), () {
        if (mounted && _videoPlayerController.value.isPlaying && !_controlsLocked && !_isDraggingSeeking && !_isHolding) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  void _toggleControls() {
    if (_controlsLocked || _isHolding || _isDraggingSeeking) return;
    
    // If an overlay is visible, dismiss it and show controls
    if (_showBrightnessOverlay || _showVolumeOverlay) {
      setState(() {
        _showBrightnessOverlay = false;
        _showVolumeOverlay = false;
        _showControls = true;
      });
      _startHideControlsTimer();
      return;
    }

    setState(() {
      _showControls = !_showControls;
    });

    if (_showControls) {
      _startHideControlsTimer();
    } else {
      _hideControlsTimer?.cancel();
    }
  }

  void _toggleLock() {
    setState(() {
      _controlsLocked = !_controlsLocked;
      if (_controlsLocked) {
        _hideControlsTimer?.cancel();
        _showControls = false;
      } else {
        _showControls = true;
        _startHideControlsTimer();
      }
    });
    HapticFeedback.mediumImpact();
  }

  Future<void> _seekForward() async {
    if (_controlsLocked) return;
    final pos = await _videoPlayerController.position;
    final dur = _videoPlayerController.value.duration;
    final np = pos! + Duration(seconds: _seekSeconds);
    await _videoPlayerController.seekTo(np < dur ? np : dur);
    setState(() => _showForwardOverlay = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _showForwardOverlay = false);
    });
    HapticFeedback.lightImpact();
  }

  Future<void> _seekBackward() async {
    if (_controlsLocked) return;
    final pos = await _videoPlayerController.position;
    final np = pos! - Duration(seconds: _seekSeconds);
    await _videoPlayerController.seekTo(np > Duration.zero ? np : Duration.zero);
    setState(() => _showBackwardOverlay = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _showBackwardOverlay = false);
    });
    HapticFeedback.lightImpact();
  }

  Future<void> _nextVideo() async {
    if (_currentIndex + 1 < widget.videoList.length) {
      _currentIndex++;
      await _cleanupAndReinit();
    }
  }

  Future<void> _previousVideo() async {
    if (_currentIndex > 0) {
      _currentIndex--;
      await _cleanupAndReinit();
    }
  }

  Future<void> _cleanupAndReinit() async {
    _hideControlsTimer?.cancel();
    _progressUpdateTimer?.cancel();
    _videoPlayerController.removeListener(_videoListener);
    await _videoPlayerController.pause();
    _chewieController?.dispose();
    await _videoPlayerController.dispose();
    _initializeVideoPlayer();
  }

  // Hold-to-seek handlers
  void _onLongPressStart(LongPressStartDetails details) {
    if (_controlsLocked || !_videoPlayerController.value.isPlaying) return;
    _hideControlsTimer?.cancel();
    
    final startIndex = _speedBreakpoints.indexOf(_currentSpeed);
    final safeIndex = startIndex == -1 ? 3 : startIndex;

    setState(() {
      _isHolding = true;
      _showSpeedWidget = true;
      _holdStartX = details.globalPosition.dx;
      _holdStartY = details.globalPosition.dy;
      _activeSpeedIndex = safeIndex;
      _activeSpeed = _speedBreakpoints[safeIndex];
    });

    HapticFeedback.heavyImpact();
    _videoPlayerController.setPlaybackSpeed(_activeSpeed);
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details, Size screenSize) {
    if (!_isHolding || _controlsLocked) return;
    final isPortrait = screenSize.height > screenSize.width;

    int newIndex;
    if (isPortrait) {
      final dy = details.globalPosition.dy - (_holdStartY ?? screenSize.height / 2);
      const pxPerStep = 40.0;
      final startIndex = _speedBreakpoints.indexOf(_currentSpeed);
      final safeStart = startIndex == -1 ? 3 : startIndex;
      // In vertical, dragging UP (negative dy) should increase speed? 
      // Actually, let's make dragging DOWN increase speed to match the list order (top to bottom).
      newIndex = safeStart + (dy / pxPerStep).round();
    } else {
      final dx = details.globalPosition.dx - (_holdStartX ?? screenSize.width / 2);
      const pxPerStep = 50.0;
      final startIndex = _speedBreakpoints.indexOf(_currentSpeed);
      final safeStart = startIndex == -1 ? 3 : startIndex;
      newIndex = safeStart + (dx / pxPerStep).round();
    }

    newIndex = newIndex.clamp(0, _speedBreakpoints.length - 1);

    if (newIndex != _activeSpeedIndex) {
      HapticFeedback.selectionClick();
      setState(() {
        _activeSpeedIndex = newIndex;
        _activeSpeed = _speedBreakpoints[newIndex];
      });
      _videoPlayerController.setPlaybackSpeed(_activeSpeed);
    }
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    if (!_isHolding) return;
    setState(() {
      _currentSpeed = _activeSpeed;
      _isHolding = false;
      _showSpeedWidget = false;
      _holdStartX = null;
      _holdStartY = null;
    });
    _videoPlayerController.setPlaybackSpeed(_currentSpeed);
    HapticFeedback.mediumImpact();
    if (_showControls && !_controlsLocked) _startHideControlsTimer();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
      );
    }

    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Video Layer
          _buildVideoLayer(),

          // 2. Gesture Detection Layer
          _buildGestureLayer(size),

          // 3. Overlays (Seek ripples, Brightness, Volume, Speed)
          _buildOverlays(size),

          // 4. Control Layer
          _buildControlLayer(size),
          
          // 5. Lock Indicator
          if (_controlsLocked) _buildLockIndicator(),
        ],
      ),
    );
  }

  Widget _buildVideoLayer() {
    return Center(
      child: _aspectRatioMode == AspectRatioMode.stretch
          ? SizedBox.expand(child: FittedBox(fit: BoxFit.fill, child: SizedBox(width: _videoPlayerController.value.size.width, height: _videoPlayerController.value.size.height, child: VideoPlayer(_videoPlayerController))))
          : _aspectRatioMode == AspectRatioMode.crop
              ? SizedBox.expand(child: FittedBox(fit: BoxFit.cover, child: SizedBox(width: _videoPlayerController.value.size.width, height: _videoPlayerController.value.size.height, child: VideoPlayer(_videoPlayerController))))
              : _aspectRatioMode == AspectRatioMode.original
                  ? SizedBox(width: _videoPlayerController.value.size.width, height: _videoPlayerController.value.size.height, child: VideoPlayer(_videoPlayerController))
                  : AspectRatio(aspectRatio: _videoPlayerController.value.aspectRatio, child: VideoPlayer(_videoPlayerController)),
    );
  }

  Widget _buildGestureLayer(Size size) {
    return Row(
      children: [
        // Left side gestures
        Expanded(
          child: GestureDetector(
            onTap: _toggleControls,
            onDoubleTap: _seekBackward,
            onLongPressStart: _onLongPressStart,
            onLongPressMoveUpdate: (d) => _onLongPressMoveUpdate(d, size),
            onLongPressEnd: _onLongPressEnd,
            onVerticalDragUpdate: (d) {
              if (_controlsLocked) return;
              final delta = -d.delta.dy / size.height;
              setState(() {
                _currentBrightness = (_currentBrightness + delta).clamp(0.0, 1.0);
                _showBrightnessOverlay = true;
              });
              ScreenBrightness().setScreenBrightness(_currentBrightness);
              _brightnessTimer?.cancel();
              _brightnessTimer = Timer(const Duration(seconds: 3), () => setState(() => _showBrightnessOverlay = false));
            },
            onHorizontalDragStart: (d) => _dragStartPosition = d.globalPosition.dx,
            onHorizontalDragUpdate: (d) => _handleHorizontalDragSeek(d, size),
            onHorizontalDragEnd: (d) {
              if (_seekPreviewPosition != null) _videoPlayerController.seekTo(_seekPreviewPosition!);
              setState(() { _dragStartPosition = null; _isDraggingSeeking = false; _seekPreviewPosition = null; });
              if (_showControls) _startHideControlsTimer();
            },
            child: Container(color: Colors.transparent),
          ),
        ),
        // Right side gestures
        Expanded(
          child: GestureDetector(
            onTap: _toggleControls,
            onDoubleTap: _seekForward,
            onLongPressStart: _onLongPressStart,
            onLongPressMoveUpdate: (d) => _onLongPressMoveUpdate(d, size),
            onLongPressEnd: _onLongPressEnd,
            onVerticalDragUpdate: (d) {
              if (_controlsLocked) return;
              final delta = -d.delta.dy / size.height;
              setState(() {
                _currentVolume = (_currentVolume + delta).clamp(0.0, 1.0);
                _showVolumeOverlay = true;
              });
              VolumeController.instance.setVolume(_currentVolume);
              _volumeTimer?.cancel();
              _volumeTimer = Timer(const Duration(seconds: 3), () => setState(() => _showVolumeOverlay = false));
            },
            onHorizontalDragStart: (d) => _dragStartPosition = d.globalPosition.dx,
            onHorizontalDragUpdate: (d) => _handleHorizontalDragSeek(d, size),
            onHorizontalDragEnd: (d) {
              if (_seekPreviewPosition != null) _videoPlayerController.seekTo(_seekPreviewPosition!);
              setState(() { _dragStartPosition = null; _isDraggingSeeking = false; _seekPreviewPosition = null; });
              if (_showControls) _startHideControlsTimer();
            },
            child: Container(color: Colors.transparent),
          ),
        ),
      ],
    );
  }

  void _handleHorizontalDragSeek(DragUpdateDetails d, Size s) {
    if (_controlsLocked || _dragStartPosition == null) return;
    final delta = d.globalPosition.dx - _dragStartPosition!;
    final seekAmt = (delta / s.width) * _videoPlayerController.value.duration.inSeconds * 0.5; // Scaled for better control
    final cur = _videoPlayerController.value.position;
    final np = cur + Duration(seconds: seekAmt.toInt());
    final dur = _videoPlayerController.value.duration;
    setState(() {
      _isDraggingSeeking = true;
      _seekPreviewPosition = np < Duration.zero ? Duration.zero : (np > dur ? dur : np);
    });
    if (_showControls) _hideControlsTimer?.cancel();
  }

  Widget _buildOverlays(Size size) {
    final isPortrait = size.height > size.width;
    return Stack(
      children: [
        // Backward Ripple
        if (_showBackwardOverlay) _buildSeekRipple(Icons.fast_rewind_rounded, "10s", Alignment.centerLeft),
        // Forward Ripple
        if (_showForwardOverlay) _buildSeekRipple(Icons.fast_forward_rounded, "10s", Alignment.centerRight),
        
        // Seek Preview Pill
        if (_isDraggingSeeking && _seekPreviewPosition != null)
          Center(
            child: _glassContainer(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              borderRadius: 20,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history_toggle_off_rounded, color: Colors.white70, size: 16.sp),
                  SizedBox(width: 8.w),
                  Text(
                    durationToString(_seekPreviewPosition!.inSeconds),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Speed Selector
        if (_showSpeedWidget && _isHolding)
          Positioned(
            top: isPortrait ? (size.height * 0.23) : 80.h,
            left: 0, right: 0,
            child: Align(
              alignment: isPortrait ? Alignment.centerRight : Alignment.center,
              child: Padding(
                padding: EdgeInsets.only(right: isPortrait ? 20.w : 0),
                child: _buildSpeedSelector(isPortrait),
              ),
            ),
          ),

        // Side Indicators (Swapped so finger doesn't block them)
        if (_showBrightnessOverlay) Positioned(
          right: 24.w, 
          top: isPortrait ? size.height * 0.42 : size.height * 0.27, 
          bottom: isPortrait ? size.height * 0.42 : size.height * 0.27, 
          child: _buildVerticalIndicator(Icons.brightness_7_rounded, _currentBrightness, Colors.orange)
        ),
        if (_showVolumeOverlay) Positioned(
          left: 24.w, 
          top: isPortrait ? size.height * 0.42 : size.height * 0.27, 
          bottom: isPortrait ? size.height * 0.42 : size.height * 0.27, 
          child: _buildVerticalIndicator(Icons.volume_up_rounded, _currentVolume, Colors.blueAccent)
        ),
      ],
    );
  }

  Widget _buildSeekRipple(IconData icon, String text, Alignment alignment) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 150, height: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(colors: [Colors.white.withOpacity(0.15), Colors.transparent], radius: 0.8),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 40),
          Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  Widget _buildSpeedSelector(bool isPortrait) {
    if (isPortrait) {
      // Very compact vertical list for Portrait
      return _glassContainer(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        borderRadius: 20,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_speedBreakpoints.length, (i) => _buildSpeedPill(i, true)),
        ),
      );
    }
    
    // Horizontal row for Landscape
    return _glassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      borderRadius: 40,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(_speedBreakpoints.length, (i) => _buildSpeedPill(i, false)),
      ),
    );
  }

  Widget _buildSpeedPill(int index, bool isPortrait) {
    final speed = _speedBreakpoints[index];
    final isSelected = index == _activeSpeedIndex;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeSpeedIndex = index;
          _activeSpeed = speed;
          _currentSpeed = speed;
          _videoPlayerController.setPlaybackSpeed(speed);
        });
        HapticFeedback.selectionClick();
        if (!_isHolding) {
          setState(() => _showSpeedWidget = false);
          _startHideControlsTimer();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: EdgeInsets.symmetric(horizontal: isPortrait ? 0 : 2, vertical: isPortrait ? 1 : 0),
        padding: EdgeInsets.symmetric(horizontal: isPortrait ? 10 : 12, vertical: isPortrait ? 5 : 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isSelected ? Colors.white : Colors.white.withOpacity(0.1)),
        ),
        child: Text(
          "${speed}x",
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white.withOpacity(0.8),
            fontSize: isPortrait ? 9 : 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalIndicator(IconData icon, double value, Color color) {
    return _glassContainer(
      width: 22.w,
      padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 2.w),
      borderRadius: 8,
      child: Column(
        children: [
          Icon(icon, color: color, size: 11.sp),
          SizedBox(height: 6.h),
          Expanded(
            child: Container(
              width: 1.5.w,
              decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(1)),
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: value.clamp(0.01, 1.0),
                child: Container(
                  width: 1.5.w,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [color, color.withOpacity(0.6)],
                    ),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 6.h),
          SizedBox(
            width: 30.w,
            child: Text(
              "${(value * 100).toInt()}%",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 7.sp, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlLayer(Size size) {
    double opacity = 0.0;
    if (_showControls) {
      if (_showBrightnessOverlay || _showVolumeOverlay || _isHolding || _isDraggingSeeking) {
        opacity = 0.2;
      } else {
        opacity = 1.0;
      }
    }

    return AnimatedOpacity(
      opacity: opacity,
      duration: const Duration(milliseconds: 300),
      child: IgnorePointer(
        ignoring: opacity < 0.5, // Disable buttons when dimmed for focus
        child: GestureDetector(
          onTap: _toggleControls,
          onDoubleTapDown: (details) {
            if (details.localPosition.dx < size.width / 2) _seekBackward();
            else _seekForward();
          },
          onLongPressStart: _onLongPressStart,
          onLongPressMoveUpdate: (d) => _onLongPressMoveUpdate(d, size),
          onLongPressEnd: _onLongPressEnd,
          onVerticalDragUpdate: (d) {
            if (_controlsLocked) return;
            final isLeft = d.localPosition.dx < size.width / 2;
            final delta = -d.delta.dy / size.height;
            setState(() {
              if (isLeft) {
                _currentBrightness = (_currentBrightness + delta).clamp(0.0, 1.0);
                _showBrightnessOverlay = true;
                ScreenBrightness().setScreenBrightness(_currentBrightness);
              } else {
                _currentVolume = (_currentVolume + delta).clamp(0.0, 1.0);
                _showVolumeOverlay = true;
                VolumeController.instance.setVolume(_currentVolume);
              }
            });
            _brightnessTimer?.cancel();
            _volumeTimer?.cancel();
            _brightnessTimer = Timer(const Duration(seconds: 2), () => setState(() => _showBrightnessOverlay = false));
            _volumeTimer = Timer(const Duration(seconds: 2), () => setState(() => _showVolumeOverlay = false));
            _hideControlsTimer?.cancel(); // Keep controls visible while dragging
          },
          onVerticalDragEnd: (_) => _startHideControlsTimer(),
          onHorizontalDragStart: (d) => _dragStartPosition = d.globalPosition.dx,
          onHorizontalDragUpdate: (d) => _handleHorizontalDragSeek(d, size),
          onHorizontalDragEnd: (d) {
            if (_seekPreviewPosition != null) _videoPlayerController.seekTo(_seekPreviewPosition!);
            setState(() { _dragStartPosition = null; _isDraggingSeeking = false; _seekPreviewPosition = null; });
            _startHideControlsTimer();
          },
          behavior: HitTestBehavior.translucent,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withOpacity(0.8), Colors.transparent, Colors.transparent, Colors.black.withOpacity(0.8)],
                stops: const [0.0, 0.2, 0.8, 1.0],
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildTopBar(),
                  _buildBottomControls(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main Row: Back, Title, More
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Text(
                  widget.videoList[_currentIndex].title ?? 'Unknown Video',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                onPressed: () {},
              ),
            ],
          ),
        ),
        // Mini Controls Row: Orientation and Speed
        Padding(
          padding: const EdgeInsets.only(left: 20, bottom: 8),
          child: Row(
            children: [
              // Orientation Toggle
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _toggleOrientation();
                },
                child: _glassContainer(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  borderRadius: 10,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isLandscape ? Icons.screen_rotation_rounded : Icons.stay_current_portrait_rounded,
                        color: Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isLandscape ? "Landscape" : "Portrait",
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Speed Indicator (Interactive)
              GestureDetector(
                onTap: () {
                  setState(() => _showSpeedWidget = !_showSpeedWidget);
                  if (_showSpeedWidget) _hideControlsTimer?.cancel();
                  else _startHideControlsTimer();
                  HapticFeedback.mediumImpact();
                },
                child: _glassContainer(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  borderRadius: 10,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.speed_rounded, color: Colors.white70, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        "${_currentSpeed}x",
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Slider and Time
          _buildSliderRow(),
          const SizedBox(height: 16),
          // Main buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(icon: const Icon(Icons.lock_open_rounded, color: Colors.white70), onPressed: _toggleLock),
              IconButton(icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 40), onPressed: _previousVideo),
              _playPauseButton(),
              IconButton(icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 40), onPressed: _nextVideo),
              IconButton(icon: const Icon(Icons.aspect_ratio_rounded, color: Colors.white70), onPressed: _cycleAspectRatio),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSliderRow() {
    final pos = _videoPlayerController.value.position;
    final dur = _videoPlayerController.value.duration;
    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white24,
            thumbColor: Colors.white,
          ),
          child: Slider(
            value: pos.inSeconds.toDouble().clamp(0.0, dur.inSeconds.toDouble()),
            max: dur.inSeconds.toDouble() == 0 ? 1.0 : dur.inSeconds.toDouble(),
            onChanged: (v) => _videoPlayerController.seekTo(Duration(seconds: v.toInt())),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(durationToString(pos.inSeconds), style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Text(durationToString(dur.inSeconds), style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _playPauseButton() {
    return Container(
      width: 70, height: 70,
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
      child: IconButton(
        icon: Icon(_videoPlayerController.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 45),
        onPressed: () {
          setState(() {
            _videoPlayerController.value.isPlaying ? _videoPlayerController.pause() : _videoPlayerController.play();
          });
        },
      ),
    );
  }

  Widget _buildLockIndicator() {
    return Positioned(
      top: 40, right: 20,
      child: GestureDetector(
        onTap: _toggleLock,
        child: _glassContainer(
          padding: const EdgeInsets.all(12),
          borderRadius: 30,
          child: const Icon(Icons.lock_rounded, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  Widget _glassContainer({required Widget child, double? width, double? height, double borderRadius = 16, EdgeInsets? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: width, height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: child,
        ),
      ),
    );
  }
}
