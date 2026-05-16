import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:nova_videoplayer/functions/history.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';

import '../functions/global_variables.dart';
import '../functions/gobal_functions.dart';

enum AspectRatioMode { fit, stretch, crop, original }

class MediaKitVideoPlayerPage extends StatefulWidget {
  final List<AssetEntity> videoList;
  final int initialIndex;
  final bool resumeFromPiP;

  const MediaKitVideoPlayerPage({
    super.key,
    required this.videoList,
    required this.initialIndex,
    this.resumeFromPiP = false,
  });

  @override
  State<MediaKitVideoPlayerPage> createState() => _MediaKitVideoPlayerPageState();
}

class _MediaKitVideoPlayerPageState extends State<MediaKitVideoPlayerPage> {
  // Media Kit Player
  late Player _player;
  late VideoController _videoController;
  
  // Stream Subscriptions
  StreamSubscription? _tracksSub;
  StreamSubscription? _completedSub;
  StreamSubscription? _errorSub;
  StreamSubscription? _widthSub;
  
  String? _lastPlayerError;
  bool _checkingAudioSwitch = false;

  int _currentIndex = 0;
  bool _isLoaded = false;
  bool _showControls = true;
  bool _controlsLocked = false;
  Timer? _hideControlsTimer;

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

  // Unified Gestures
  bool _isVerticalDrag = false;
  bool _isHorizontalDrag = false;
  double _dragTotalDelta = 0;

  // Zoom & Pan
  double _scale = 1.0;
  double _previousScale = 1.0;
  Offset _panOffset = Offset.zero;
  Offset _previousPanOffset = Offset.zero;
  bool _showZoomOverlay = false;
  Timer? _zoomOverlayTimer;

  // Track info
  late List<AudioTrack> _audioTracks = [];
  late AudioTrack _selectedAudioTrack = AudioTrack.auto();

  bool _isSpeedSelectorOpen = false;
  final Color _goldColor = const Color(0xFFFFD700);

  // Subtitle info
  late List<SubtitleTrack> _subtitleTracks = [];
  late SubtitleTrack _selectedSubtitleTrack = SubtitleTrack.auto();
  double _subtitleSize = 16.0;
  StreamSubscription? _subtitlesSub;

  @override
  void initState() {
    super.initState();
    
    _currentIndex = widget.initialIndex;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initializeBrightnessAndVolume();

    if (widget.resumeFromPiP && activeMainPlayer.value != null) {
      _player = activeMainPlayer.value!;
      _videoController = activeMainVideoController.value!;
      _isLoaded = true;
      _hookUpStreams();
      _startHideControlsTimer();
    } else {
      _player = Player();
      _videoController = VideoController(_player);
      
      // Instantly kill PiP and stop audio when launching a new full video
      isShortsPiPMode.value = false;
      activeShortsPlayer.value?.pause();
      isMainPiPMode.value = false;
      if (activeMainPlayer.value != null && activeMainPlayer.value != _player) {
        activeMainPlayer.value?.pause();
        activeMainPlayer.value?.dispose();
        activeMainPlayer.value = null;
      }
      
      _initializePlayer();
    }
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

  void _hookUpStreams() {
    _completedSub = _player.stream.completed.listen((completed) {
      if (completed) _nextVideo();
    });

    _tracksSub = _player.stream.tracks.listen((tracks) {
      if (!mounted) return;
      setState(() {
        _audioTracks = tracks.audio;
        _subtitleTracks = tracks.subtitle;
      });
    });

    _widthSub = _player.stream.width.listen((width) {
      if (width != null && _player.state.height != null) {
        final ar = width / _player.state.height!;
        _isLandscape = ar > 1.0;
        _updateOrientation();
      }
    });

    _errorSub = _player.stream.error.listen((error) {
      debugPrint("MEDIA_KIT_ERROR: $error");
      _lastPlayerError = error;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Player Error: $error"),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _brightnessTimer?.cancel();
    _volumeTimer?.cancel();

    _tracksSub?.cancel();
    _completedSub?.cancel();
    _errorSub?.cancel();
    _widthSub?.cancel();
    _subtitlesSub?.cancel();

    if (!isMainPiPMode.value) {
      _player.dispose();
    }

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    super.dispose();
  }

  Future<void> _initializePlayer() async {
    setState(() {
      _isLoaded = false;
      _audioTracks = [];
      _selectedAudioTrack = AudioTrack.auto();
      _lastPlayerError = null;
    });

    final file = await widget.videoList[_currentIndex].file;
    if (file == null) return;

    await _tracksSub?.cancel();
    await _completedSub?.cancel();
    await _errorSub?.cancel();
    await _widthSub?.cancel();
    await _subtitlesSub?.cancel();

    _hookUpStreams();

    await _player.open(Media(file.path));
    // Reset to auto to prevent previous selection from leaking
    await _player.setAudioTrack(AudioTrack.auto());
    await _player.setSubtitleTrack(SubtitleTrack.auto());

    setState(() => _isLoaded = true);

    _startHideControlsTimer();
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
      // Reset zoom when cycling aspect ratio
      _scale = 1.0;
      _panOffset = Offset.zero;
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
        if (mounted && _player.state.playing && !_controlsLocked && !_isDraggingSeeking && !_isHolding) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  void _toggleControls() {
    if (_controlsLocked || _isHolding || _isDraggingSeeking) return;
    
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
    final np = _player.state.position + Duration(seconds: _seekSeconds);
    await _player.seek(np < _player.state.duration ? np : _player.state.duration);
    setState(() => _showForwardOverlay = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _showForwardOverlay = false);
    });
    HapticFeedback.lightImpact();
  }

  Future<void> _seekBackward() async {
    if (_controlsLocked) return;
    final np = _player.state.position - Duration(seconds: _seekSeconds);
    await _player.seek(np > Duration.zero ? np : Duration.zero);
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
    _initializePlayer();
  }

  void _onLongPressStart(LongPressStartDetails details) {
    if (_controlsLocked || !_player.state.playing) return;
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
    _player.setRate(_activeSpeed);
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
      _player.setRate(_activeSpeed);
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
    _player.setRate(_currentSpeed);
    HapticFeedback.mediumImpact();
    if (_showControls && !_controlsLocked) _startHideControlsTimer();
  }

  void _showAudioTrackSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _glassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        borderRadius: 30,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Audio Tracks", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _audioTracks.length,
                itemBuilder: (context, index) {
                  final track = _audioTracks[index];
                  final isMute = track.id == AudioTrack.no().id;
                  final isSelected = track.id == _selectedAudioTrack.id;
                  
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      isMute ? Icons.volume_off_rounded : Icons.audiotrack_rounded, 
                      color: isSelected ? Colors.blue : Colors.white70,
                      size: 20,
                    ),
                    title: Text(
                      isMute ? "No Audio" : (track.title ?? track.language ?? "Track ${index + 1}"),
                      style: TextStyle(color: isSelected ? Colors.blue : Colors.white, fontSize: 14),
                    ),
                    subtitle: !isMute && (track.title != null || track.language != null) 
                      ? Text(
                          "${track.title ?? ''} ${track.language ?? ''}".trim(),
                          style: const TextStyle(color: Colors.white60, fontSize: 11),
                        ) 
                      : null,
                    trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.blue, size: 18) : null,
                    onTap: () async {
                      Navigator.pop(context); // Close immediately for speed
                      await _switchAudioTrack(track);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _switchAudioTrack(AudioTrack track) async {
    if (_checkingAudioSwitch) return;

    setState(() {
      _checkingAudioSwitch = true;
      _lastPlayerError = null;
    });

    final beforePos = _player.state.position;
    final wasPlaying = _player.state.playing;

    try {
      debugPrint("===== SWITCH AUDIO =====");
      debugPrint("Target id=${track.id}, title=${track.title}, lang=${track.language}");

      // Update UI state immediately
      if (mounted) {
        setState(() {
          _selectedAudioTrack = track;
        });
      }

      await _player.setAudioTrack(track);

      // Wake audio output.
      await _player.setVolume(100);

      // Small seek helps media_kit/mpv refresh decoder on Android.
      await Future.delayed(const Duration(milliseconds: 150));
      await _player.seek(beforePos + const Duration(milliseconds: 250));

      if (wasPlaying) {
        await _player.play();
      }

      await Future.delayed(const Duration(seconds: 2));

      final activeTrack = _player.state.track.audio;
      final afterPos = _player.state.position;

      final trackActuallySelected = activeTrack.id == track.id;
      final hasPlayerError = _lastPlayerError != null;

      debugPrint("===== AUDIO SWITCH RESULT =====");
      debugPrint("Selected id=${activeTrack.id}, title=${activeTrack.title}, lang=${activeTrack.language}");
      debugPrint("trackActuallySelected=$trackActuallySelected");
      debugPrint("lastError=$_lastPlayerError");

      if (!mounted) return;

      setState(() {
        _checkingAudioSwitch = false;
      });

      if (!trackActuallySelected || hasPlayerError) {
        _showAudioUnsupportedWarning(track, _lastPlayerError);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Audio: ${track.title ?? track.language ?? track.id}"),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint("AUDIO SWITCH ERROR: $e");

      if (!mounted) return;

      setState(() {
        _checkingAudioSwitch = false;
      });

      _showAudioUnsupportedWarning(track, e.toString());
    }
  }

  void _showAudioUnsupportedWarning(AudioTrack track, String? error) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black87,
        title: const Text(
          "Audio track may be unsupported",
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          "The app selected this track, but Android/media_kit may not be decoding it correctly.\n\n"
          "Track:\n"
          "ID: ${track.id}\n"
          "Title: ${track.title ?? 'Unknown'}\n"
          "Language: ${track.language ?? 'Unknown'}\n\n"
          "Error:\n"
          "${error ?? 'No direct player error reported'}\n\n"
          "If this same track works in MX Player, MX Player may be using a different decoder/backend.",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
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

          // 2. Subtitle Layer (Separate from video for perfect positioning)
          _buildSubtitleLayer(size),

          // 3. Gesture Detection Layer (Visible when controls are hidden)
          _buildGestureLayer(size),

          // 3. Overlays (Seek ripples, Brightness, Volume, Speed)
          _buildOverlays(size),

          // 4. Control Layer (Custom UI)
          _buildControlLayer(size),
          
          // 5. Lock Indicator
          if (_controlsLocked) _buildLockIndicator(),
        ],
      ),
    );
  }

  Widget _buildVideoLayer() {
    return ClipRect(
      child: Center(
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..translate(_panOffset.dx, _panOffset.dy)
            ..scale(_scale),
          child: Video(
            controller: _videoController,
            fit: _aspectRatioMode == AspectRatioMode.stretch 
                ? BoxFit.fill 
                : (_aspectRatioMode == AspectRatioMode.crop ? BoxFit.cover : BoxFit.contain),
            controls: NoVideoControls,
            subtitleViewConfiguration: const SubtitleViewConfiguration(
              visible: false, // We use our own layer
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitleLayer(Size size) {
    final isPortrait = size.height > size.width;
    double bottomPadding = _showControls ? 110.h : (isPortrait ? 25.h : 10.h);
    
    return Positioned(
      bottom: bottomPadding,
      left: 20.w,
      right: 20.w,
      child: IgnorePointer(
        child: SubtitleView(
          controller: _videoController,
          configuration: SubtitleViewConfiguration(
            style: TextStyle(
              fontSize: _subtitleSize, // Normal pixels, no .sp
              color: Colors.white,
              fontWeight: FontWeight.bold,
              shadows: const [Shadow(blurRadius: 8.0, color: Colors.black, offset: Offset(2, 2))],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGestureLayer(Size size) {
    return GestureDetector(
      onTap: _toggleControls,
      onDoubleTapDown: (details) {
        if (_controlsLocked) return;
        if (details.localPosition.dx < size.width / 2) _seekBackward();
        else _seekForward();
      },
      onLongPressStart: _onLongPressStart,
      onLongPressMoveUpdate: (d) => _onLongPressMoveUpdate(d, size),
      onLongPressEnd: _onLongPressEnd,
      onScaleStart: (details) {
        if (_controlsLocked) return;
        _previousScale = _scale;
        _previousPanOffset = details.localFocalPoint;
        _isVerticalDrag = false;
        _isHorizontalDrag = false;
        _dragTotalDelta = 0;
        
        if (!_showControls && details.pointerCount == 1) {
          _dragStartPosition = details.localFocalPoint.dx;
        }
      },
      onScaleUpdate: (details) {
        if (_controlsLocked) return;

        // 1. Two-finger Zoom
        if (details.pointerCount == 2 && !_showControls) {
          setState(() {
            _scale = (_previousScale * details.scale).clamp(0.5, 4.0);
            _showZoomOverlay = true;
            _zoomOverlayTimer?.cancel();
            _zoomOverlayTimer = Timer(const Duration(seconds: 2), () => setState(() => _showZoomOverlay = false));
          });
          return;
        }

        // 2. Single-finger Gestures (Drag/Volume/Brightness)
        if (details.pointerCount == 1) {
          final delta = details.localFocalPoint - _previousPanOffset;
          
          // Decide direction if not already decided
          if (!_isVerticalDrag && !_isHorizontalDrag) {
            if (delta.dy.abs() > delta.dx.abs() && delta.dy.abs() > 2) {
              _isVerticalDrag = true;
            } else if (delta.dx.abs() > delta.dy.abs() && delta.dx.abs() > 2) {
              _isHorizontalDrag = true;
            }
          }

          if (_isVerticalDrag) {
            // Volume / Brightness
            if (_showControls || _scale > 1.0) return;
            final isLeft = details.localFocalPoint.dx < size.width / 2;
            final dy = -delta.dy / size.height;
            setState(() {
              if (isLeft) {
                _currentBrightness = (_currentBrightness + dy).clamp(0.0, 1.0);
                _showBrightnessOverlay = true;
                ScreenBrightness().setScreenBrightness(_currentBrightness);
              } else {
                _currentVolume = (_currentVolume + dy).clamp(0.0, 1.0);
                _showVolumeOverlay = true;
                VolumeController.instance.setVolume(_currentVolume);
              }
            });
            _brightnessTimer?.cancel();
            _volumeTimer?.cancel();
            _brightnessTimer = Timer(const Duration(seconds: 3), () => setState(() => _showBrightnessOverlay = false));
            _volumeTimer = Timer(const Duration(seconds: 3), () => setState(() => _showVolumeOverlay = false));
          } 
          else if (_isHorizontalDrag) {
            // Seeking
            if (_showControls || _scale > 1.0 || _dragStartPosition == null) return;
            final dxDelta = details.localFocalPoint.dx - _dragStartPosition!;
            final seekAmt = (dxDelta / size.width) * _player.state.duration.inSeconds * 0.5;
            final cur = _player.state.position;
            final np = cur + Duration(seconds: seekAmt.toInt());
            final dur = _player.state.duration;
            setState(() {
              _isDraggingSeeking = true;
              _seekPreviewPosition = np < Duration.zero ? Duration.zero : (np > dur ? dur : np);
            });
            if (_showControls) _hideControlsTimer?.cancel();
          }
          else if (_scale > 1.0) {
            // Panning
            setState(() {
              _panOffset += delta;
            });
          }
          
          _previousPanOffset = details.localFocalPoint;
        }
      },
      onScaleEnd: (details) {
        if (_isDraggingSeeking && _seekPreviewPosition != null) {
          _player.seek(_seekPreviewPosition!);
        }
        setState(() {
          _dragStartPosition = null;
          _isDraggingSeeking = false;
          _seekPreviewPosition = null;
          _isHorizontalDrag = false;
          _isVerticalDrag = false;
        });
        if (_showControls) _startHideControlsTimer();
      },
      child: Container(color: Colors.transparent),
    );
  }

  void _handleHorizontalDragSeek(DragUpdateDetails d, Size s) {
    if (_controlsLocked || _dragStartPosition == null) return;
    final delta = d.globalPosition.dx - _dragStartPosition!;
    final seekAmt = (delta / s.width) * _player.state.duration.inSeconds * 0.5;
    final cur = _player.state.position;
    final np = cur + Duration(seconds: seekAmt.toInt());
    final dur = _player.state.duration;
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
        if (_showBackwardOverlay) _buildSeekRipple(Icons.fast_rewind_rounded, "10s", Alignment.centerLeft),
        if (_showForwardOverlay) _buildSeekRipple(Icons.fast_forward_rounded, "10s", Alignment.centerRight),
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
                    style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
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
        if (_showZoomOverlay)
          Positioned(
            top: 60.h,
            left: 0, right: 0,
            child: Center(
              child: _glassContainer(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                borderRadius: 20,
                child: Text(
                  "${(_scale * 100).toInt()}%",
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ),
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
      return _glassContainer(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        borderRadius: 20,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_speedBreakpoints.length, (i) => _buildSpeedPill(i, true)),
        ),
      );
    }
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
          _player.setRate(speed);
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
      if (_showBrightnessOverlay || _showVolumeOverlay || _isHolding || _isDraggingSeeking) opacity = 0.2;
      else opacity = 1.0;
    }

    return AnimatedOpacity(
      opacity: opacity,
      duration: const Duration(milliseconds: 300),
      child: IgnorePointer(
        ignoring: opacity < 0.5,
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
                _player.setVolume(_currentVolume * 100);
              }
            });
            _brightnessTimer?.cancel();
            _volumeTimer?.cancel();
            _brightnessTimer = Timer(const Duration(seconds: 2), () => setState(() => _showBrightnessOverlay = false));
            _volumeTimer = Timer(const Duration(seconds: 2), () => setState(() => _showVolumeOverlay = false));
            _hideControlsTimer?.cancel();
          },
          onVerticalDragEnd: (_) => _startHideControlsTimer(),
          onHorizontalDragStart: (d) => _dragStartPosition = d.globalPosition.dx,
          onHorizontalDragUpdate: (d) => _handleHorizontalDragSeek(d, size),
          onHorizontalDragEnd: (d) {
            if (_seekPreviewPosition != null) _player.seek(_seekPreviewPosition!);
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
    final isLandscape = MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isLandscape) SizedBox(height: 2.5.h),
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
                icon: const Icon(Icons.audiotrack_rounded, color: Colors.white),
                onPressed: _showAudioTrackSelector,
              ),
              IconButton(
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                onPressed: _showMoreSettings,
              ),
            ],
          ),
        ),
        SizedBox(height: 2.5.h),
        Padding(
          padding: const EdgeInsets.only(left: 20, bottom: 8),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _isSpeedSelectorOpen 
              ? _buildInPlaceSpeedSelector()
              : Row(
                  key: const ValueKey("default_pills"),
                  children: [
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
                            Icon(_isLandscape ? Icons.screen_rotation_rounded : Icons.stay_current_portrait_rounded, color: Colors.white, size: 16),
                            const SizedBox(width: 6),
                            Text(_isLandscape ? "Landscape" : "Portrait", style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        // Trigger PiP Mode
                        isMainPiPMode.value = true;
                        activeMainPlayer.value = _player;
                        activeMainVideoController.value = _videoController;
                        mainPiPVideoList.value = widget.videoList;
                        mainPiPVideoIndex.value = _currentIndex;
                        Navigator.pop(context); // Go back to Home Screen
                      },
                      child: _glassContainer(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        borderRadius: 10,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.picture_in_picture_alt_rounded, color: Colors.white, size: 16),
                            const SizedBox(width: 6),
                            const Text("PiP", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _isSpeedSelectorOpen = true);
                        _hideControlsTimer?.cancel();
                      },
                      child: _glassContainer(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        borderRadius: 10,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.speed_rounded, color: _currentSpeed != 1.0 ? _goldColor : Colors.white, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              "${_currentSpeed}x", 
                              style: TextStyle(
                                color: _currentSpeed != 1.0 ? _goldColor : Colors.white, 
                                fontSize: 11, 
                                fontWeight: FontWeight.w500
                              )
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildInPlaceSpeedSelector() {
    final isPortrait = MediaQuery.of(context).size.height > MediaQuery.of(context).size.width;
    return Row(
      key: const ValueKey("speed_selector"),
      children: [
        GestureDetector(
          onTap: () => setState(() {
            _isSpeedSelectorOpen = false;
            _startHideControlsTimer();
          }),
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(color: Colors.white12, shape: BoxShape.circle),
            child: const Icon(Icons.close_rounded, color: Colors.white, size: 12),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: _speedBreakpoints.map((s) {
                final isSel = s == _currentSpeed;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentSpeed = s;
                      _activeSpeed = s;
                      _activeSpeedIndex = _speedBreakpoints.indexOf(s);
                      _player.setRate(s);
                      _isSpeedSelectorOpen = false;
                      _startHideControlsTimer();
                    });
                    HapticFeedback.selectionClick();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: EdgeInsets.symmetric(horizontal: isPortrait ? 8 : 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSel ? _goldColor : Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isSel ? _goldColor : Colors.white10),
                    ),
                    child: Text(
                      "${s}x",
                      style: TextStyle(
                        color: isSel ? Colors.black : Colors.white,
                        fontSize: isPortrait ? 10 : 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }



  Widget _buildBottomControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              StreamBuilder<Duration>(
                stream: _player.stream.position,
                builder: (context, snapshot) {
                  final pos = snapshot.data ?? Duration.zero;
                  return Text(durationToString(pos.inSeconds), style: const TextStyle(color: Colors.white70, fontSize: 12));
                },
              ),
              Expanded(
                child: StreamBuilder<Duration>(
                  stream: _player.stream.position,
                  builder: (context, snapshot) {
                    final pos = snapshot.data ?? Duration.zero;
                    final dur = _player.state.duration;
                    return SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                      ),
                      child: Slider(
                        value: pos.inMilliseconds.toDouble().clamp(0.0, dur.inMilliseconds.toDouble()),
                        min: 0,
                        max: dur.inMilliseconds.toDouble() == 0 ? 1.0 : dur.inMilliseconds.toDouble(),
                        onChanged: (v) => _player.seek(Duration(milliseconds: v.toInt())),
                      ),
                    );
                  },
                ),
              ),
              Text(durationToString(_player.state.duration.inSeconds), style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(icon: const Icon(Icons.aspect_ratio_rounded, color: Colors.white), onPressed: _cycleAspectRatio),
            IconButton(icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 36), onPressed: _previousVideo),
            StreamBuilder<bool>(
              stream: _player.stream.playing,
              initialData: _player.state.playing,
              builder: (context, snapshot) {
                final isPlaying = snapshot.data ?? _player.state.playing;
                return IconButton(
                  icon: Icon(isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded, color: Colors.white, size: 64),
                  onPressed: () => _player.playOrPause(),
                );
              },
            ),
            IconButton(icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 36), onPressed: _nextVideo),
            IconButton(icon: Icon(_controlsLocked ? Icons.lock_rounded : Icons.lock_open_rounded, color: Colors.white), onPressed: _toggleLock),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  void _showMoreSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return _glassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            borderRadius: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 12),
                ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  leading: const Icon(Icons.subtitles_rounded, color: Colors.white, size: 20),
                  title: const Text("Subtitle Tracks", style: TextStyle(color: Colors.white, fontSize: 14)),
                  onTap: () {
                    Navigator.pop(context);
                    _showSubtitleSelector();
                  },
                ),
                ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  leading: const Icon(Icons.format_size_rounded, color: Colors.white, size: 20),
                  title: const Text("Font Size", style: TextStyle(color: Colors.white, fontSize: 14)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.white70, size: 20),
                        onPressed: () {
                          setState(() => _subtitleSize = (_subtitleSize - 1).clamp(8, 60));
                          setSheetState(() {});
                        },
                      ),
                      Text("${_subtitleSize.toInt()}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.add_circle_outline, color: Colors.white70, size: 20),
                        onPressed: () {
                          setState(() => _subtitleSize = (_subtitleSize + 1).clamp(8, 60));
                          setSheetState(() {});
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showSubtitleSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _glassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        borderRadius: 24,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _subtitleTracks.length,
                itemBuilder: (context, index) {
                  final track = _subtitleTracks[index];
                  final isNone = track.id == SubtitleTrack.no().id;
                  final isSelected = track.id == _selectedSubtitleTrack.id;
                  return ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    leading: Icon(isNone ? Icons.subtitles_off_rounded : Icons.subtitles_rounded, color: isSelected ? Colors.blue : Colors.white70, size: 20),
                    title: Text(
                      isNone ? "None" : (track.title ?? track.language ?? "Track ${index + 1}"),
                      style: TextStyle(color: isSelected ? Colors.blue : Colors.white, fontSize: 14),
                    ),
                    trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.blue, size: 18) : null,
                    onTap: () async {
                      await _player.setSubtitleTrack(track);
                      setState(() => _selectedSubtitleTrack = track);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLockIndicator() {
    return Positioned(
      left: 20, top: 0, bottom: 0,
      child: Center(
        child: GestureDetector(
          onTap: _toggleLock,
          child: _glassContainer(
            padding: const EdgeInsets.all(15),
            borderRadius: 50,
            child: const Icon(Icons.lock_rounded, color: Colors.white, size: 30),
          ),
        ),
      ),
    );
  }

  Widget _glassContainer({required Widget child, EdgeInsets? padding, double borderRadius = 20, double? width}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: width,
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: child,
        ),
      ),
    );
  }
}
