// import 'dart:async';
// import 'dart:io';

// import 'package:chewie/chewie.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:nova_videoplayer/functions/history.dart';
// import 'package:photo_manager/photo_manager.dart';
// import 'package:screen_brightness/screen_brightness.dart';
// import 'package:video_player/video_player.dart';
// import 'package:volume_controller/volume_controller.dart';

// enum AspectRatioMode {
//   fit,
//   stretch,
//   crop,
//   original,
// }

// class VideoPLayerPage extends StatefulWidget {
//   final List<AssetEntity> videoList;
//   final int initialIndex;

//   const VideoPLayerPage({
//     super.key,
//     required this.videoList,
//     required this.initialIndex,
//   });

//   @override
//   State<VideoPLayerPage> createState() => _VideoPLayerPageState();
// }

// class _VideoPLayerPageState extends State<VideoPLayerPage> {
//   late VideoPlayerController _videoPlayerController;
//   late ChewieController _chewieController;
//   int _currentIndex = 0;
//   bool loaded = false;
//   bool _showControls = true;
//   bool _controlsLocked = false;
//   Timer? _hideControlsTimer;
//   Timer? _progressUpdateTimer;

//   bool _isLandscape = true;
//   AspectRatioMode _aspectRatioMode = AspectRatioMode.fit;

//   bool _showForwardOverlay = false;
//   bool _showBackwardOverlay = false;
//   int _seekSeconds = 10;

//   // 2x Speed playback (hold to activate)
//   bool _is2xSpeedActive = false;
//   bool _is2xSpeedLocked = false;
//   bool _isHolding2xSpeed = false;
//   String _holdingSide = ''; // 'left' or 'right'
//   double _lockIconProgress = 0.0; // 0.0 to 1.0 for animation

//   // Brightness and Volume
//   double _currentBrightness = 0.5;
//   double _currentVolume = 0.5;
//   bool _showBrightnessOverlay = false;
//   bool _showVolumeOverlay = false;
//   Timer? _brightnessTimer;
//   Timer? _volumeTimer;

//   // Drag seeking
//   double? _dragStartPosition;
//   bool _isDraggingSeeking = false;
//   Duration? _seekPreviewPosition;

//   @override
//   void initState() {
//     super.initState();
//     _currentIndex = widget.initialIndex;
//     SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
//     _initializeBrightnessAndVolume();
//     _initializeVideoPlayer();
//   }

//   Future<void> _initializeBrightnessAndVolume() async {
//     try {
//       _currentBrightness = await ScreenBrightness().current;
//     } catch (e) {
//       _currentBrightness = 0.5;
//     }

//     try {
//       _currentVolume = await VolumeController.instance.getVolume();
//     } catch (e) {
//       _currentVolume = 0.5;
//     }

//     VolumeController.instance.showSystemUI = false;
//   }

//   @override
//   void dispose() {
//     _hideControlsTimer?.cancel();
//     _progressUpdateTimer?.cancel();
//     _brightnessTimer?.cancel();
//     _volumeTimer?.cancel();
//     _videoPlayerController.removeListener(_videoListener);
//     _videoPlayerController.dispose();
//     _chewieController.dispose();
//     SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
//     SystemChrome.setPreferredOrientations([
//       DeviceOrientation.portraitUp,
//       DeviceOrientation.portraitDown,
//       DeviceOrientation.landscapeLeft,
//       DeviceOrientation.landscapeRight,
//     ]);
//     super.dispose();
//   }

//   void _videoListener() {
//     if (mounted && _videoPlayerController.value.isInitialized) {
//       setState(() {});
//     }
//   }

//   void _startProgressTimer() {
//     _progressUpdateTimer?.cancel();
//     _progressUpdateTimer =
//         Timer.periodic(const Duration(milliseconds: 100), (timer) {
//       if (mounted && _videoPlayerController.value.isPlaying) {
//         setState(() {});
//       }
//     });
//   }

//   void _initializeVideoPlayer() async {
//     final file = await widget.videoList[_currentIndex].file;
//     _videoPlayerController = VideoPlayerController.file(File(file?.path ?? ''));
//     await _videoPlayerController.initialize();

//     final aspectRatio = _videoPlayerController.value.aspectRatio;
//     _isLandscape = aspectRatio > 1.0;

//     if (_isLandscape) {
//       SystemChrome.setPreferredOrientations([
//         DeviceOrientation.landscapeLeft,
//         DeviceOrientation.landscapeRight,
//       ]);
//     } else {
//       SystemChrome.setPreferredOrientations([
//         DeviceOrientation.portraitUp,
//         DeviceOrientation.portraitDown,
//       ]);
//     }

//     _chewieController = ChewieController(
//       videoPlayerController: _videoPlayerController,
//       autoPlay: true,
//       looping: false,
//       showControls: false,
//       autoInitialize: true,
//     );

//     _videoPlayerController.addListener(_videoListener);
//     _startProgressTimer();

//     setState(() {
//       loaded = true;
//     });

//     _startHideControlsTimer();
//   }

//   void _toggleOrientation() {
//     setState(() {
//       _isLandscape = !_isLandscape;
//     });

//     if (_isLandscape) {
//       SystemChrome.setPreferredOrientations([
//         DeviceOrientation.landscapeLeft,
//         DeviceOrientation.landscapeRight,
//       ]);
//     } else {
//       SystemChrome.setPreferredOrientations([
//         DeviceOrientation.portraitUp,
//         DeviceOrientation.portraitDown,
//       ]);
//     }
//   }

//   void _cycleAspectRatio() {
//     setState(() {
//       switch (_aspectRatioMode) {
//         case AspectRatioMode.fit:
//           _aspectRatioMode = AspectRatioMode.stretch;
//           break;
//         case AspectRatioMode.stretch:
//           _aspectRatioMode = AspectRatioMode.crop;
//           break;
//         case AspectRatioMode.crop:
//           _aspectRatioMode = AspectRatioMode.original;
//           break;
//         case AspectRatioMode.original:
//           _aspectRatioMode = AspectRatioMode.fit;
//           break;
//       }
//     });

//     _showAspectRatioChangeMessage();
//   }

//   void _showAspectRatioChangeMessage() {
//     String message = '';
//     switch (_aspectRatioMode) {
//       case AspectRatioMode.fit:
//         message = 'Fit to Screen';
//         break;
//       case AspectRatioMode.stretch:
//         message = 'Stretch';
//         break;
//       case AspectRatioMode.crop:
//         message = 'Crop';
//         break;
//       case AspectRatioMode.original:
//         message = '100% (Original)';
//         break;
//     }

//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         duration: const Duration(milliseconds: 800),
//         behavior: SnackBarBehavior.floating,
//         margin: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
//       ),
//     );
//   }

//   void _startHideControlsTimer() {
//     _hideControlsTimer?.cancel();
//     if (!_controlsLocked) {
//       _hideControlsTimer = Timer(const Duration(seconds: 3), () {
//         if (mounted &&
//             _videoPlayerController.value.isPlaying &&
//             !_controlsLocked &&
//             !_isDraggingSeeking) {
//           setState(() {
//             _showControls = false;
//           });
//         }
//       });
//     }
//   }

//   void _toggleControls() {
//     if (_controlsLocked) return;

//     // IMPORTANT: Don't toggle controls while holding 2x speed
//     if (_isHolding2xSpeed && !_is2xSpeedLocked) return;

//     setState(() {
//       _showControls = !_showControls;
//     });

//     if (_showControls) {
//       _startHideControlsTimer();
//     } else {
//       _hideControlsTimer?.cancel();
//     }
//   }

//   void _toggleLock() {
//     setState(() {
//       _controlsLocked = !_controlsLocked;
//       if (_controlsLocked) {
//         _hideControlsTimer?.cancel();
//         _showControls = false;
//       } else {
//         _showControls = true;
//         _startHideControlsTimer();
//       }
//     });
//   }

//   Future<void> _seekForward() async {
//     if (_controlsLocked) return;

//     final currentPosition = await _videoPlayerController.position;
//     final duration = _videoPlayerController.value.duration;
//     final newPosition = currentPosition! + Duration(seconds: _seekSeconds);

//     if (newPosition < duration) {
//       await _videoPlayerController.seekTo(newPosition);
//     } else {
//       await _videoPlayerController.seekTo(duration);
//     }

//     setState(() {
//       _showForwardOverlay = true;
//     });

//     Future.delayed(const Duration(milliseconds: 600), () {
//       if (mounted) {
//         setState(() {
//           _showForwardOverlay = false;
//         });
//       }
//     });
//   }

//   Future<void> _seekBackward() async {
//     if (_controlsLocked) return;

//     final currentPosition = await _videoPlayerController.position;
//     final newPosition = currentPosition! - Duration(seconds: _seekSeconds);

//     if (newPosition > Duration.zero) {
//       await _videoPlayerController.seekTo(newPosition);
//     } else {
//       await _videoPlayerController.seekTo(Duration.zero);
//     }

//     setState(() {
//       _showBackwardOverlay = true;
//     });

//     Future.delayed(const Duration(milliseconds: 600), () {
//       if (mounted) {
//         setState(() {
//           _showBackwardOverlay = false;
//         });
//       }
//     });
//   }

//   void _start2xSpeed(String side) {
//     if (_controlsLocked || _is2xSpeedLocked) return;

//     // Cancel auto-hide timer so controls don't disappear while holding 2x speed
//     _hideControlsTimer?.cancel();

//     setState(() {
//       _isHolding2xSpeed = true;
//       _is2xSpeedActive = true;
//       _holdingSide = side;
//       _lockIconProgress = 0.0;
//     });
//     _videoPlayerController.setPlaybackSpeed(2.0);
//   }

//   void _stop2xSpeed() {
//     if (_controlsLocked || _is2xSpeedLocked) return;

//     setState(() {
//       _isHolding2xSpeed = false;
//       _is2xSpeedActive = false;
//       _holdingSide = '';
//       _lockIconProgress = 0.0;
//     });
//     _videoPlayerController.setPlaybackSpeed(1.0);

//     // Restart auto-hide timer if controls are still visible
//     if (_showControls && !_controlsLocked) {
//       _startHideControlsTimer();
//     }
//   }

//   void _handle2xSpeedDrag(LongPressMoveUpdateDetails details, Size screenSize) {
//     if (!_isHolding2xSpeed || _is2xSpeedLocked) return;

//     double progress = 0.0;
//     bool shouldLock = false;

//     // Check if dragged to lock area and calculate progress
//     if (_holdingSide == 'left') {
//       // Left side - only track if dragging towards left edge (x decreasing)
//       final currentX = details.globalPosition.dx;

//       // Ignore if dragging opposite direction (towards right)
//       if (currentX > screenSize.width / 2) {
//         return; // Invalid drag direction, ignore
//       }

//       // Calculate progress: from half screen to left edge
//       final halfScreen = screenSize.width / 2;
//       final distance = halfScreen - currentX;
//       progress = (distance / (halfScreen - 80)).clamp(0.0, 1.0);

//       if (currentX < 80) {
//         shouldLock = true;
//       }
//     } else if (_holdingSide == 'right') {
//       // Right side - only track if dragging towards right edge (x increasing)
//       final currentX = details.globalPosition.dx;

//       // Ignore if dragging opposite direction (towards left)
//       if (currentX < screenSize.width / 2) {
//         return; // Invalid drag direction, ignore
//       }

//       // Calculate progress: from half screen to right edge
//       final halfScreen = screenSize.width / 2;
//       final distance = currentX - halfScreen;
//       progress = (distance / (halfScreen - 80)).clamp(0.0, 1.0);

//       if (currentX > screenSize.width - 80) {
//         shouldLock = true;
//       }
//     }

//     setState(() {
//       _lockIconProgress = progress;
//     });

//     if (shouldLock && _lockIconProgress >= 0.95) {
//       _lock2xSpeed();
//     }
//   }

//   void _lock2xSpeed() {
//     if (_controlsLocked) return;

//     HapticFeedback.mediumImpact(); // Haptic feedback when locked

//     setState(() {
//       _is2xSpeedLocked = true;
//       _isHolding2xSpeed = false;
//       // Keep _holdingSide to remember which side was locked
//     });
//     _videoPlayerController.setPlaybackSpeed(2.0);
//   }

//   void _unlock2xSpeed() {
//     if (_controlsLocked) return;

//     HapticFeedback.lightImpact(); // Haptic feedback when unlocked

//     setState(() {
//       _is2xSpeedLocked = false;
//       _is2xSpeedActive = false;
//       _holdingSide = ''; // Reset side when unlocking
//     });
//     _videoPlayerController.setPlaybackSpeed(1.0);
//   }

//   Future<void> _nextVideo() async {
//     final int nextIndex = _currentIndex + 1;
//     if (nextIndex < widget.videoList.length) {
//       setState(() {
//         loaded = false;
//       });

//       _hideControlsTimer?.cancel();
//       _progressUpdateTimer?.cancel();
//       _videoPlayerController.removeListener(_videoListener);
//       await _videoPlayerController.pause();
//       _chewieController.dispose();
//       await _videoPlayerController.dispose();

//       _currentIndex = nextIndex;
//       HistoryVideos.addToHistory(widget.videoList[nextIndex]);

//       _initializeVideoPlayer();
//     }
//   }

//   Future<void> _previousVideo() async {
//     final int previousIndex = _currentIndex - 1;
//     if (previousIndex >= 0) {
//       setState(() {
//         loaded = false;
//       });

//       _hideControlsTimer?.cancel();
//       _progressUpdateTimer?.cancel();
//       _videoPlayerController.removeListener(_videoListener);
//       await _videoPlayerController.pause();
//       _chewieController.dispose();
//       await _videoPlayerController.dispose();

//       _currentIndex = previousIndex;
//       HistoryVideos.addToHistory(widget.videoList[previousIndex]);

//       _initializeVideoPlayer();
//     }
//   }

//   String _formatDuration(Duration duration) {
//     String twoDigits(int n) => n.toString().padLeft(2, '0');
//     final hours = twoDigits(duration.inHours);
//     final minutes = twoDigits(duration.inMinutes.remainder(60));
//     final seconds = twoDigits(duration.inSeconds.remainder(60));

//     if (duration.inHours > 0) {
//       return '$hours:$minutes:$seconds';
//     }
//     return '$minutes:$seconds';
//   }

//   void _handleVerticalDragLeft(DragUpdateDetails details, Size screenSize) {
//     if (_controlsLocked) return;

//     final delta = -details.delta.dy / screenSize.height;
//     setState(() {
//       _currentBrightness = (_currentBrightness + delta).clamp(0.0, 1.0);
//       _showBrightnessOverlay = true;
//     });

//     ScreenBrightness().setScreenBrightness(_currentBrightness);

//     _brightnessTimer?.cancel();
//     _brightnessTimer = Timer(const Duration(seconds: 5), () {
//       if (mounted) {
//         setState(() {
//           _showBrightnessOverlay = false;
//         });
//       }
//     });
//   }

//   void _handleVerticalDragRight(DragUpdateDetails details, Size screenSize) {
//     if (_controlsLocked) return;

//     final delta = -details.delta.dy / screenSize.height;
//     setState(() {
//       _currentVolume = (_currentVolume + delta).clamp(0.0, 1.0);
//       _showVolumeOverlay = true;
//     });

//     VolumeController.instance.setVolume(_currentVolume);

//     _volumeTimer?.cancel();
//     _volumeTimer = Timer(const Duration(seconds: 5), () {
//       if (mounted) {
//         setState(() {
//           _showVolumeOverlay = false;
//         });
//       }
//     });
//   }

//   void _handleHorizontalDragSeek(DragUpdateDetails details, Size screenSize) {
//     if (_controlsLocked || _dragStartPosition == null) return;

//     final delta = details.globalPosition.dx - _dragStartPosition!;
//     final seekAmount = (delta / screenSize.width) *
//         _videoPlayerController.value.duration.inSeconds;

//     final currentPosition = _videoPlayerController.value.position;
//     final newPosition = currentPosition + Duration(seconds: seekAmount.toInt());

//     Duration clampedPosition;
//     if (newPosition < Duration.zero) {
//       clampedPosition = Duration.zero;
//     } else if (newPosition > _videoPlayerController.value.duration) {
//       clampedPosition = _videoPlayerController.value.duration;
//     } else {
//       clampedPosition = newPosition;
//     }

//     setState(() {
//       _isDraggingSeeking = true;
//       _seekPreviewPosition = clampedPosition;
//     });

//     if (_showControls) {
//       _hideControlsTimer?.cancel();
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (!loaded) {
//       return const Scaffold(
//         backgroundColor: Colors.black,
//         body: Center(
//           child: CircularProgressIndicator(color: Colors.white),
//         ),
//       );
//     }

//     final screenSize = MediaQuery.of(context).size;
//     final isPortrait = !_isLandscape;

//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: Stack(
//         children: [
//           // Layer 1: Video Player
//           Center(
//             child: _aspectRatioMode == AspectRatioMode.stretch
//                 ? SizedBox.expand(
//                     child: FittedBox(
//                       fit: BoxFit.fill,
//                       child: SizedBox(
//                         width: _videoPlayerController.value.size.width,
//                         height: _videoPlayerController.value.size.height,
//                         child: VideoPlayer(_videoPlayerController),
//                       ),
//                     ),
//                   )
//                 : _aspectRatioMode == AspectRatioMode.crop
//                     ? SizedBox.expand(
//                         child: FittedBox(
//                           fit: BoxFit.cover,
//                           child: SizedBox(
//                             width: _videoPlayerController.value.size.width,
//                             height: _videoPlayerController.value.size.height,
//                             child: VideoPlayer(_videoPlayerController),
//                           ),
//                         ),
//                       )
//                     : _aspectRatioMode == AspectRatioMode.original
//                         ? Center(
//                             child: SizedBox(
//                               width: _videoPlayerController.value.size.width,
//                               height: _videoPlayerController.value.size.height,
//                               child: VideoPlayer(_videoPlayerController),
//                             ),
//                           )
//                         : AspectRatio(
//                             aspectRatio:
//                                 _videoPlayerController.value.aspectRatio,
//                             child: VideoPlayer(_videoPlayerController),
//                           ),
//           ),

//           // Layer 2: Gradient Background (IgnorePointer)
//           if (!_controlsLocked && _showControls)
//             IgnorePointer(
//               child: AnimatedOpacity(
//                 opacity: _showControls ? 1.0 : 0.0,
//                 duration: const Duration(milliseconds: 300),
//                 child: Container(
//                   decoration: BoxDecoration(
//                     gradient: LinearGradient(
//                       begin: Alignment.topCenter,
//                       end: Alignment.bottomCenter,
//                       colors: [
//                         Colors.black.withOpacity(0.7),
//                         Colors.transparent,
//                         Colors.transparent,
//                         Colors.black.withOpacity(0.8),
//                       ],
//                       stops: const [0.0, 0.3, 0.7, 1.0],
//                     ),
//                   ),
//                 ),
//               ),
//             ),

//           // Layer 3: Touch Zones
//           Row(
//             children: [
//               // Left side
//               Expanded(
//                 child: GestureDetector(
//                   behavior: HitTestBehavior.translucent,
//                   onTap: () {
//                     if (!_controlsLocked) {
//                       if (_showBrightnessOverlay || _showVolumeOverlay) {
//                         setState(() {
//                           _showBrightnessOverlay = false;
//                           _showVolumeOverlay = false;
//                         });
//                         _brightnessTimer?.cancel();
//                         _volumeTimer?.cancel();
//                       }
//                       _toggleControls();
//                     }
//                   },
//                   onDoubleTap: !_controlsLocked ? _seekBackward : null,
//                   onLongPressStart:
//                       !_controlsLocked ? (_) => _start2xSpeed('left') : null,
//                   onLongPressMoveUpdate: !_controlsLocked
//                       ? (details) => _handle2xSpeedDrag(details, screenSize)
//                       : null,
//                   onLongPressEnd:
//                       !_controlsLocked ? (_) => _stop2xSpeed() : null,
//                   onVerticalDragUpdate: (details) =>
//                       _handleVerticalDragLeft(details, screenSize),
//                   onHorizontalDragStart: !_controlsLocked
//                       ? (details) {
//                           _dragStartPosition = details.globalPosition.dx;
//                         }
//                       : null,
//                   onHorizontalDragUpdate: (details) =>
//                       _handleHorizontalDragSeek(details, screenSize),
//                   onHorizontalDragEnd: !_controlsLocked
//                       ? (details) {
//                           if (_seekPreviewPosition != null) {
//                             _videoPlayerController
//                                 .seekTo(_seekPreviewPosition!);
//                           }
//                           setState(() {
//                             _dragStartPosition = null;
//                             _isDraggingSeeking = false;
//                             _seekPreviewPosition = null;
//                           });
//                           if (_showControls) {
//                             _startHideControlsTimer();
//                           }
//                         }
//                       : null,
//                   child: Container(
//                     color: Colors.transparent,
//                     child: AnimatedOpacity(
//                       opacity: _showBackwardOverlay ? 1.0 : 0.0,
//                       duration: const Duration(milliseconds: 200),
//                       child: Container(
//                         decoration: BoxDecoration(
//                           gradient: LinearGradient(
//                             begin: Alignment.centerLeft,
//                             end: Alignment.centerRight,
//                             colors: [
//                               Colors.black.withOpacity(0.6),
//                               Colors.transparent,
//                             ],
//                           ),
//                         ),
//                         child: Center(
//                           child: Column(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               const Icon(
//                                 Icons.fast_rewind_rounded,
//                                 color: Colors.white,
//                                 size: 50,
//                               ),
//                               const SizedBox(height: 8),
//                               Text(
//                                 '« $_seekSeconds seconds',
//                                 style: const TextStyle(
//                                   color: Colors.white,
//                                   fontSize: 16,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//               ),

//               // Right side
//               Expanded(
//                 child: GestureDetector(
//                   behavior: HitTestBehavior.translucent,
//                   onTap: () {
//                     if (!_controlsLocked) {
//                       if (_showBrightnessOverlay || _showVolumeOverlay) {
//                         setState(() {
//                           _showBrightnessOverlay = false;
//                           _showVolumeOverlay = false;
//                         });
//                         _brightnessTimer?.cancel();
//                         _volumeTimer?.cancel();
//                       }
//                       _toggleControls();
//                     }
//                   },
//                   onDoubleTap: !_controlsLocked ? _seekForward : null,
//                   onLongPressStart:
//                       !_controlsLocked ? (_) => _start2xSpeed('right') : null,
//                   onLongPressMoveUpdate: !_controlsLocked
//                       ? (details) => _handle2xSpeedDrag(details, screenSize)
//                       : null,
//                   onLongPressEnd:
//                       !_controlsLocked ? (_) => _stop2xSpeed() : null,
//                   onVerticalDragUpdate: (details) =>
//                       _handleVerticalDragRight(details, screenSize),
//                   onHorizontalDragStart: !_controlsLocked
//                       ? (details) {
//                           _dragStartPosition = details.globalPosition.dx;
//                         }
//                       : null,
//                   onHorizontalDragUpdate: (details) =>
//                       _handleHorizontalDragSeek(details, screenSize),
//                   onHorizontalDragEnd: !_controlsLocked
//                       ? (details) {
//                           if (_seekPreviewPosition != null) {
//                             _videoPlayerController
//                                 .seekTo(_seekPreviewPosition!);
//                           }
//                           setState(() {
//                             _dragStartPosition = null;
//                             _isDraggingSeeking = false;
//                             _seekPreviewPosition = null;
//                           });
//                           if (_showControls) {
//                             _startHideControlsTimer();
//                           }
//                         }
//                       : null,
//                   child: Container(
//                     color: Colors.transparent,
//                     child: AnimatedOpacity(
//                       opacity: _showForwardOverlay ? 1.0 : 0.0,
//                       duration: const Duration(milliseconds: 200),
//                       child: Container(
//                         decoration: BoxDecoration(
//                           gradient: LinearGradient(
//                             begin: Alignment.centerRight,
//                             end: Alignment.centerLeft,
//                             colors: [
//                               Colors.black.withOpacity(0.6),
//                               Colors.transparent,
//                             ],
//                           ),
//                         ),
//                         child: Center(
//                           child: Column(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               const Icon(
//                                 Icons.fast_forward_rounded,
//                                 color: Colors.white,
//                                 size: 50,
//                               ),
//                               const SizedBox(height: 8),
//                               Text(
//                                 '$_seekSeconds seconds »',
//                                 style: const TextStyle(
//                                   color: Colors.white,
//                                   fontSize: 16,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),

//           // Brightness Overlay
//           if (_showBrightnessOverlay)
//             Positioned(
//               left: 40,
//               top: isPortrait
//                   ? (screenSize.height / 2) - 70
//                   : (screenSize.height / 2) - 105,
//               child: Material(
//                 color: Colors.transparent,
//                 child: Container(
//                   padding: isPortrait
//                       ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
//                       : const EdgeInsets.symmetric(
//                           horizontal: 16, vertical: 12),
//                   decoration: BoxDecoration(
//                     color: Colors.black.withOpacity(0.85),
//                     borderRadius: BorderRadius.circular(12),
//                     border: Border.all(
//                         color: Colors.white.withOpacity(0.2), width: 1),
//                   ),
//                   child: Column(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Icon(
//                         Icons.brightness_6,
//                         color: Colors.yellow,
//                         size: isPortrait ? 24 : 28,
//                       ),
//                       SizedBox(height: isPortrait ? 8 : 10),
//                       GestureDetector(
//                         behavior: HitTestBehavior.opaque,
//                         onVerticalDragStart: (_) {
//                           _brightnessTimer?.cancel();
//                         },
//                         onVerticalDragUpdate: (details) {
//                           final barHeight = isPortrait ? 70.0 : 100.0;
//                           final double relativeY = details.localPosition.dy;
//                           final clampedY = relativeY.clamp(0.0, barHeight);
//                           double newBrightness = 1.0 - (clampedY / barHeight);
//                           newBrightness = (newBrightness * 50).round() / 50.0;
//                           newBrightness = newBrightness.clamp(0.0, 1.0);
//                           setState(() {
//                             _currentBrightness = newBrightness;
//                           });
//                           ScreenBrightness()
//                               .setScreenBrightness(_currentBrightness);
//                         },
//                         onVerticalDragEnd: (_) {
//                           _brightnessTimer =
//                               Timer(const Duration(seconds: 5), () {
//                             if (mounted)
//                               setState(() => _showBrightnessOverlay = false);
//                           });
//                         },
//                         child: Container(
//                           color: Colors.transparent,
//                           height: isPortrait ? 70.0 : 100.0,
//                           width: 40.0,
//                           alignment: Alignment.center,
//                           child: SizedBox(
//                             width: 6,
//                             child: Stack(
//                               alignment: Alignment.bottomCenter,
//                               children: [
//                                 Container(
//                                   decoration: BoxDecoration(
//                                     borderRadius: BorderRadius.circular(3),
//                                     color: Colors.white12,
//                                   ),
//                                 ),
//                                 FractionallySizedBox(
//                                   heightFactor: _currentBrightness,
//                                   child: Container(
//                                     decoration: BoxDecoration(
//                                       borderRadius: BorderRadius.circular(3),
//                                       gradient: LinearGradient(
//                                         begin: Alignment.bottomCenter,
//                                         end: Alignment.topCenter,
//                                         colors: [
//                                           Colors.yellow.shade700,
//                                           Colors.yellow.shade300,
//                                         ],
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ),
//                       ),
//                       SizedBox(height: isPortrait ? 8 : 10),
//                       SizedBox(
//                         width: 36,
//                         child: Text(
//                           '${(_currentBrightness * 100).toInt()}%',
//                           textAlign: TextAlign.center,
//                           style: TextStyle(
//                             color: Colors.white,
//                             fontSize: (_currentBrightness * 100).toInt() >= 100
//                                 ? (isPortrait ? 11 : 13)
//                                 : (isPortrait ? 12 : 14),
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),

//           // Volume Overlay
//           if (_showVolumeOverlay)
//             Positioned(
//               right: 40,
//               top: isPortrait
//                   ? (screenSize.height / 2) - 70
//                   : (screenSize.height / 2) - 105,
//               child: Material(
//                 color: Colors.transparent,
//                 child: Container(
//                   padding: isPortrait
//                       ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
//                       : const EdgeInsets.symmetric(
//                           horizontal: 16, vertical: 12),
//                   decoration: BoxDecoration(
//                     color: Colors.black.withOpacity(0.85),
//                     borderRadius: BorderRadius.circular(12),
//                     border: Border.all(
//                         color: Colors.white.withOpacity(0.2), width: 1),
//                   ),
//                   child: Column(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Icon(
//                         _currentVolume > 0.6
//                             ? Icons.volume_up_rounded
//                             : _currentVolume > 0.3
//                                 ? Icons.volume_down_rounded
//                                 : _currentVolume > 0
//                                     ? Icons.volume_mute_rounded
//                                     : Icons.volume_off_rounded,
//                         color: Colors.blue.shade300,
//                         size: isPortrait ? 24 : 28,
//                       ),
//                       SizedBox(height: isPortrait ? 8 : 10),
//                       GestureDetector(
//                         behavior: HitTestBehavior.opaque,
//                         onVerticalDragStart: (_) {
//                           _volumeTimer?.cancel();
//                         },
//                         onVerticalDragUpdate: (details) {
//                           final barHeight = isPortrait ? 70.0 : 100.0;
//                           final double relativeY = details.localPosition.dy;
//                           final clampedY = relativeY.clamp(0.0, barHeight);
//                           double newVolume = 1.0 - (clampedY / barHeight);
//                           newVolume = (newVolume * 50).round() / 50.0;
//                           newVolume = newVolume.clamp(0.0, 1.0);
//                           setState(() {
//                             _currentVolume = newVolume;
//                           });
//                           VolumeController.instance.setVolume(_currentVolume);
//                         },
//                         onVerticalDragEnd: (_) {
//                           _volumeTimer = Timer(const Duration(seconds: 5), () {
//                             if (mounted)
//                               setState(() => _showVolumeOverlay = false);
//                           });
//                         },
//                         child: Container(
//                           color: Colors.transparent,
//                           height: isPortrait ? 70.0 : 100.0,
//                           width: 40.0,
//                           alignment: Alignment.center,
//                           child: SizedBox(
//                             width: 6,
//                             child: Stack(
//                               alignment: Alignment.bottomCenter,
//                               children: [
//                                 Container(
//                                   decoration: BoxDecoration(
//                                     borderRadius: BorderRadius.circular(3),
//                                     color: Colors.white12,
//                                   ),
//                                 ),
//                                 FractionallySizedBox(
//                                   heightFactor: _currentVolume,
//                                   child: Container(
//                                     decoration: BoxDecoration(
//                                       borderRadius: BorderRadius.circular(3),
//                                       gradient: LinearGradient(
//                                         begin: Alignment.bottomCenter,
//                                         end: Alignment.topCenter,
//                                         colors: [
//                                           Colors.blue.shade700,
//                                           Colors.blue.shade300,
//                                         ],
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ),
//                       ),
//                       SizedBox(height: isPortrait ? 8 : 10),
//                       SizedBox(
//                         width: 36,
//                         child: Text(
//                           '${(_currentVolume * 100).toInt()}%',
//                           textAlign: TextAlign.center,
//                           style: TextStyle(
//                             color: Colors.white,
//                             fontSize: (_currentVolume * 100).toInt() >= 100
//                                 ? (isPortrait ? 11 : 13)
//                                 : (isPortrait ? 12 : 14),
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),

//           // Drag Seek Preview
//           if (_isDraggingSeeking && _seekPreviewPosition != null)
//             Center(
//               child: Container(
//                 padding:
//                     const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
//                 decoration: BoxDecoration(
//                   color: Colors.black.withOpacity(0.8),
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: Text(
//                   _formatDuration(_seekPreviewPosition!),
//                   style: const TextStyle(
//                     color: Colors.white,
//                     fontSize: 24,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ),
//             ),

//           // 2x Speed Overlay (while holding) - INDEPENDENT of controls, 70px gap
//           if (_isHolding2xSpeed && !_is2xSpeedLocked)
//             Positioned.fill(
//               child: Row(
//                 children: [
//                   // Left half overlay
//                   if (_holdingSide == 'left')
//                     Flexible(
//                       child: Container(
//                         decoration: BoxDecoration(
//                           gradient: LinearGradient(
//                             begin: Alignment.centerLeft,
//                             end: Alignment.centerRight,
//                             colors: [
//                               Colors.black.withOpacity(0.2),
//                               Colors.transparent,
//                             ],
//                           ),
//                         ),
//                         child: Stack(
//                           children: [
//                             // "2x" text - FIXED at 110px (70px gap from icon at 40px)
//                             Positioned(
//                               left: 110, // Increased from 80px - now 70px gap
//                               top: screenSize.height / 2 - 14,
//                               child: Text(
//                                 '2x',
//                                 style: TextStyle(
//                                   color: Colors.white.withOpacity(0.75),
//                                   fontSize: 26,
//                                   fontWeight: FontWeight.w600,
//                                   letterSpacing: 1,
//                                 ),
//                               ),
//                             ),
//                             // Animated lock icon on left edge - "<<" direction
//                             Positioned(
//                               left: 40,
//                               top: screenSize.height / 2 - 18,
//                               child: AnimatedContainer(
//                                 duration: const Duration(milliseconds: 250),
//                                 curve: Curves.easeInOut,
//                                 padding: const EdgeInsets.all(8),
//                                 decoration: BoxDecoration(
//                                   color: Color.lerp(
//                                     Colors.white.withOpacity(0.15),
//                                     Colors.orange.withOpacity(0.75),
//                                     _lockIconProgress,
//                                   ),
//                                   shape: BoxShape.circle,
//                                 ),
//                                 child: Icon(
//                                   Icons
//                                       .keyboard_double_arrow_left_rounded, // << direction
//                                   color: Colors.white.withOpacity(0.9),
//                                   size: 18,
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     )
//                   else
//                     const Spacer(),

//                   // Right half overlay
//                   if (_holdingSide == 'right')
//                     Flexible(
//                       child: Container(
//                         decoration: BoxDecoration(
//                           gradient: LinearGradient(
//                             begin: Alignment.centerRight,
//                             end: Alignment.centerLeft,
//                             colors: [
//                               Colors.black.withOpacity(0.2),
//                               Colors.transparent,
//                             ],
//                           ),
//                         ),
//                         child: Stack(
//                           children: [
//                             // "2x" text - FIXED at 110px (70px gap from icon at 40px)
//                             Positioned(
//                               right: 110, // Increased from 80px - now 70px gap
//                               top: screenSize.height / 2 - 14,
//                               child: Text(
//                                 '2x',
//                                 style: TextStyle(
//                                   color: Colors.white.withOpacity(0.75),
//                                   fontSize: 26,
//                                   fontWeight: FontWeight.w600,
//                                   letterSpacing: 1,
//                                 ),
//                               ),
//                             ),
//                             // Animated lock icon on right edge - ">>" direction
//                             Positioned(
//                               right: 40,
//                               top: screenSize.height / 2 - 18,
//                               child: AnimatedContainer(
//                                 duration: const Duration(milliseconds: 250),
//                                 curve: Curves.easeInOut,
//                                 padding: const EdgeInsets.all(8),
//                                 decoration: BoxDecoration(
//                                   color: Color.lerp(
//                                     Colors.white.withOpacity(0.15),
//                                     Colors.orange.withOpacity(0.75),
//                                     _lockIconProgress,
//                                   ),
//                                   shape: BoxShape.circle,
//                                 ),
//                                 child: Icon(
//                                   Icons
//                                       .keyboard_double_arrow_right_rounded, // >> direction
//                                   color: Colors.white.withOpacity(0.9),
//                                   size: 18,
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     )
//                   else
//                     const Spacer(),
//                 ],
//               ),
//             ),

//           // Lock Button
//           if (_controlsLocked)
//             Positioned(
//               top: 50,
//               right: 20,
//               child: GestureDetector(
//                 onTap: _toggleLock,
//                 child: Container(
//                   padding: const EdgeInsets.all(12),
//                   decoration: BoxDecoration(
//                     color: Colors.black.withOpacity(0.7),
//                     borderRadius: BorderRadius.circular(30),
//                   ),
//                   child: const Icon(
//                     Icons.lock,
//                     color: Colors.white,
//                     size: 28,
//                   ),
//                 ),
//               ),
//             ),

//           // Persistent 2x Speed Locked Icon (stays in same position, changed to locked icon)
//           if (_is2xSpeedLocked)
//             Positioned(
//               left:
//                   _holdingSide == 'right' ? null : 40, // Same padding as unlock
//               right: _holdingSide == 'right' ? 40 : null,
//               top: screenSize.height / 2 - 18,
//               child: GestureDetector(
//                 onTap: _unlock2xSpeed,
//                 child: AnimatedContainer(
//                   duration: const Duration(milliseconds: 300),
//                   padding: const EdgeInsets.all(8),
//                   decoration: BoxDecoration(
//                     color: Colors.orange.withOpacity(0.8),
//                     shape: BoxShape.circle,
//                     boxShadow: [
//                       BoxShadow(
//                         color: Colors.orange.withOpacity(0.3),
//                         blurRadius: 6,
//                         spreadRadius: 1,
//                       ),
//                     ],
//                   ),
//                   child: const Icon(
//                     Icons.lock_rounded, // Changed to locked icon
//                     color: Colors.white,
//                     size: 18,
//                   ),
//                 ),
//               ),
//             ),

//           // Layer 4: Control Buttons (dimmed when holding 2x speed OR brightness/volume active)
//           if (!_controlsLocked && _showControls)
//             AnimatedOpacity(
//               opacity: _isHolding2xSpeed
//                   ? 0.30 // 30% opacity when holding 2x speed (increased from 10%)
//                   : (_showBrightnessOverlay || _showVolumeOverlay)
//                       ? 0.15
//                       : 1.0,
//               duration: const Duration(milliseconds: 300),
//               child: _buildControlButtons(),
//             ),
//         ],
//       ),
//     );
//   }

//   Widget _buildControlButtons() {
//     return SafeArea(
//       // Wrap entire control layer with SafeArea
//       top: true,
//       bottom: true,
//       left: true,
//       right: true,
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           // Top Bar
//           Padding(
//             padding: const EdgeInsets.only(top: 8, left: 8, right: 8),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 // First line: Back button, Title, Menu
//                 Row(
//                   children: [
//                     IconButton(
//                       icon: const Icon(Icons.arrow_back, color: Colors.white),
//                       onPressed: () => Navigator.pop(context),
//                     ),
//                     Expanded(
//                       child: Text(
//                         widget.videoList[_currentIndex].title ?? 'Video',
//                         style: const TextStyle(
//                           color: Colors.white,
//                           fontSize: 16,
//                           fontWeight: FontWeight.w500,
//                         ),
//                         maxLines: 1,
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                     ),
//                     IconButton(
//                       icon: const Icon(Icons.more_vert, color: Colors.white),
//                       onPressed: () {},
//                     ),
//                   ],
//                 ),
//                 // Second line: Rotation button and Speed indicator with background
//                 Padding(
//                   padding: const EdgeInsets.only(left: 8, top: 4),
//                   child: Container(
//                     padding:
//                         const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
//                     decoration: BoxDecoration(
//                       color: Colors.black.withOpacity(0.3),
//                       borderRadius: BorderRadius.circular(20),
//                     ),
//                     child: Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         IconButton(
//                           icon: Icon(
//                             _isLandscape
//                                 ? Icons.screen_rotation_rounded
//                                 : Icons.stay_current_portrait_rounded,
//                             color: Colors.white.withOpacity(0.85),
//                             size: 19,
//                           ),
//                           onPressed: () {
//                             HapticFeedback.lightImpact();
//                             _toggleOrientation();
//                           },
//                         ),
//                         const SizedBox(width: 4),
//                         // Speed indicator
//                         Container(
//                           padding: const EdgeInsets.symmetric(
//                               horizontal: 8, vertical: 4),
//                           decoration: BoxDecoration(
//                             color: (_is2xSpeedActive || _is2xSpeedLocked)
//                                 ? Colors.orange.withOpacity(0.3)
//                                 : Colors.white.withOpacity(0.15),
//                             borderRadius: BorderRadius.circular(12),
//                             border: Border.all(
//                               color: (_is2xSpeedActive || _is2xSpeedLocked)
//                                   ? Colors.orange.withOpacity(0.6)
//                                   : Colors.white.withOpacity(0.4),
//                               width: 1,
//                             ),
//                           ),
//                           child: Text(
//                             (_is2xSpeedActive || _is2xSpeedLocked)
//                                 ? '2x'
//                                 : '1x',
//                             style: TextStyle(
//                               color: (_is2xSpeedActive || _is2xSpeedLocked)
//                                   ? Colors.orange
//                                   : Colors.white.withOpacity(0.85),
//                               fontSize: 11,
//                               fontWeight: FontWeight.w600,
//                             ),
//                           ),
//                         ),
//                         const SizedBox(width: 4),
//                       ],
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),

//           // Bottom Controls
//           Padding(
//             padding: const EdgeInsets.only(bottom: 20),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 // Progress Bar
//                 Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 24),
//                   child: AnimatedBuilder(
//                     animation: _videoPlayerController,
//                     builder: (context, child) {
//                       final position = _videoPlayerController.value.position;
//                       final duration = _videoPlayerController.value.duration;
//                       final validPosition = position.inSeconds.toDouble();
//                       final validDuration = duration.inSeconds > 0
//                           ? duration.inSeconds.toDouble()
//                           : 1.0;

//                       return Column(
//                         children: [
//                           SliderTheme(
//                             data: SliderThemeData(
//                               trackHeight: 3,
//                               thumbShape: const RoundSliderThumbShape(
//                                 enabledThumbRadius: 6,
//                               ),
//                               overlayShape: const RoundSliderOverlayShape(
//                                 overlayRadius: 12,
//                               ),
//                             ),
//                             child: Slider(
//                               value: validPosition.clamp(0.0, validDuration),
//                               max: validDuration,
//                               activeColor: Colors.red,
//                               inactiveColor: Colors.white.withOpacity(0.3),
//                               onChanged: (newValue) {
//                                 _videoPlayerController.seekTo(
//                                   Duration(seconds: newValue.toInt()),
//                                 );
//                               },
//                             ),
//                           ),
//                           Padding(
//                             padding: const EdgeInsets.symmetric(horizontal: 8),
//                             child: Row(
//                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                               children: [
//                                 Text(
//                                   _formatDuration(position),
//                                   style: const TextStyle(
//                                     color: Colors.white,
//                                     fontSize: 12,
//                                   ),
//                                 ),
//                                 Text(
//                                   _formatDuration(duration),
//                                   style: const TextStyle(
//                                     color: Colors.white,
//                                     fontSize: 12,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ],
//                       );
//                     },
//                   ),
//                 ),

//                 // Control Buttons
//                 Padding(
//                   padding: const EdgeInsets.only(top: 8),
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                     children: [
//                       IconButton(
//                         icon: const Icon(
//                           Icons.lock_open,
//                           color: Colors.white,
//                           size: 28,
//                         ),
//                         onPressed: _toggleLock,
//                       ),
//                       IconButton(
//                         icon: Icon(
//                           Icons.skip_previous_rounded,
//                           color: _currentIndex > 0
//                               ? Colors.white
//                               : Colors.white.withOpacity(0.3),
//                           size: 36,
//                         ),
//                         onPressed: _currentIndex > 0 ? _previousVideo : null,
//                       ),
//                       Container(
//                         decoration: BoxDecoration(
//                           shape: BoxShape.circle,
//                           color: Colors.white.withOpacity(0.2),
//                         ),
//                         child: IconButton(
//                           icon: Icon(
//                             _videoPlayerController.value.isPlaying
//                                 ? Icons.pause_rounded
//                                 : Icons.play_arrow_rounded,
//                             color: Colors.white,
//                             size: 40,
//                           ),
//                           onPressed: () {
//                             setState(() {
//                               if (_videoPlayerController.value.isPlaying) {
//                                 _chewieController.pause();
//                                 _hideControlsTimer?.cancel();
//                               } else {
//                                 _chewieController.play();
//                                 _startHideControlsTimer();
//                               }
//                             });
//                           },
//                         ),
//                       ),
//                       IconButton(
//                         icon: Icon(
//                           Icons.skip_next_rounded,
//                           color: _currentIndex < widget.videoList.length - 1
//                               ? Colors.white
//                               : Colors.white.withOpacity(0.3),
//                           size: 36,
//                         ),
//                         onPressed: _currentIndex < widget.videoList.length - 1
//                             ? _nextVideo
//                             : null,
//                       ),
//                       IconButton(
//                         icon: const Icon(
//                           Icons.aspect_ratio,
//                           color: Colors.white,
//                           size: 28,
//                         ),
//                         onPressed: _cycleAspectRatio,
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

////////////////////////////////////////////////////////////////////////////////////////////////-----------

// import 'dart:async';
// import 'dart:io';

// import 'package:chewie/chewie.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:nova_videoplayer/functions/history.dart';
// import 'package:photo_manager/photo_manager.dart';
// import 'package:screen_brightness/screen_brightness.dart';
// import 'package:video_player/video_player.dart';
// import 'package:volume_controller/volume_controller.dart';

// enum AspectRatioMode {
//   fit,
//   stretch,
//   crop,
//   original,
// }

// class VideoPLayerPage extends StatefulWidget {
//   final List<AssetEntity> videoList;
//   final int initialIndex;

//   const VideoPLayerPage({
//     super.key,
//     required this.videoList,
//     required this.initialIndex,
//   });

//   @override
//   State<VideoPLayerPage> createState() => _VideoPLayerPageState();
// }

// class _VideoPLayerPageState extends State<VideoPLayerPage> {
//   late VideoPlayerController _videoPlayerController;
//   late ChewieController _chewieController;
//   int _currentIndex = 0;
//   bool loaded = false;
//   bool _showControls = true;
//   bool _controlsLocked = false;
//   Timer? _hideControlsTimer;
//   Timer? _progressUpdateTimer;

//   bool _isLandscape = true;
//   AspectRatioMode _aspectRatioMode = AspectRatioMode.fit;

//   bool _showForwardOverlay = false;
//   bool _showBackwardOverlay = false;
//   int _seekSeconds = 10;

//   // Multi-speed playback (hold to activate with breakpoints)
//   bool _isSpeedChangeActive = false;
//   bool _isSpeedLocked = false;
//   bool _isHoldingSpeed = false;
//   String _holdingSide = ''; // 'left' or 'right'
//   double _lockIconProgress = 0.0; // 0.0 to 1.0 for animation
//   double _currentSpeed = 1.0; // Current playback speed
//   int _currentBreakpointIndex = 0; // Current breakpoint index
//   Timer? _speedLockGraceTimer; // Timer for grace period auto-lock

//   // Speed breakpoints
//   final List<double> _rightSpeedBreakpoints = [
//     1.0,
//     1.5,
//     2.0,
//     2.5,
//     3.0,
//     3.5,
//     4.0
//   ];
//   final List<double> _leftSpeedBreakpoints = [
//     1.0,
//     0.75,
//     0.5,
//     0.25
//   ]; // Start from 1x, go down when dragging left

//   // Brightness and Volume
//   double _currentBrightness = 0.5;
//   double _currentVolume = 0.5;
//   bool _showBrightnessOverlay = false;
//   bool _showVolumeOverlay = false;
//   Timer? _brightnessTimer;
//   Timer? _volumeTimer;

//   // Drag seeking
//   double? _dragStartPosition;
//   bool _isDraggingSeeking = false;
//   Duration? _seekPreviewPosition;

//   @override
//   void initState() {
//     super.initState();
//     _currentIndex = widget.initialIndex;
//     SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
//     _initializeBrightnessAndVolume();
//     _initializeVideoPlayer();
//   }

//   Future<void> _initializeBrightnessAndVolume() async {
//     try {
//       _currentBrightness = await ScreenBrightness().current;
//     } catch (e) {
//       _currentBrightness = 0.5;
//     }

//     try {
//       _currentVolume = await VolumeController.instance.getVolume();
//     } catch (e) {
//       _currentVolume = 0.5;
//     }

//     VolumeController.instance.showSystemUI = false;
//   }

//   @override
//   void dispose() {
//     _hideControlsTimer?.cancel();
//     _progressUpdateTimer?.cancel();
//     _brightnessTimer?.cancel();
//     _volumeTimer?.cancel();
//     _speedLockGraceTimer?.cancel();
//     _videoPlayerController.removeListener(_videoListener);
//     _videoPlayerController.dispose();
//     _chewieController.dispose();
//     SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
//     SystemChrome.setPreferredOrientations([
//       DeviceOrientation.portraitUp,
//       DeviceOrientation.portraitDown,
//       DeviceOrientation.landscapeLeft,
//       DeviceOrientation.landscapeRight,
//     ]);
//     super.dispose();
//   }

//   void _videoListener() {
//     if (mounted && _videoPlayerController.value.isInitialized) {
//       setState(() {});
//     }
//   }

//   void _startProgressTimer() {
//     _progressUpdateTimer?.cancel();
//     _progressUpdateTimer =
//         Timer.periodic(const Duration(milliseconds: 100), (timer) {
//       if (mounted && _videoPlayerController.value.isPlaying) {
//         setState(() {});
//       }
//     });
//   }

//   void _initializeVideoPlayer() async {
//     final file = await widget.videoList[_currentIndex].file;
//     _videoPlayerController = VideoPlayerController.file(File(file?.path ?? ''));
//     await _videoPlayerController.initialize();

//     final aspectRatio = _videoPlayerController.value.aspectRatio;
//     _isLandscape = aspectRatio > 1.0;

//     if (_isLandscape) {
//       SystemChrome.setPreferredOrientations([
//         DeviceOrientation.landscapeLeft,
//         DeviceOrientation.landscapeRight,
//       ]);
//     } else {
//       SystemChrome.setPreferredOrientations([
//         DeviceOrientation.portraitUp,
//         DeviceOrientation.portraitDown,
//       ]);
//     }

//     _chewieController = ChewieController(
//       videoPlayerController: _videoPlayerController,
//       autoPlay: true,
//       looping: false,
//       showControls: false,
//       autoInitialize: true,
//     );

//     _videoPlayerController.addListener(_videoListener);
//     _startProgressTimer();

//     setState(() {
//       loaded = true;
//     });

//     _startHideControlsTimer();
//   }

//   void _toggleOrientation() {
//     setState(() {
//       _isLandscape = !_isLandscape;
//     });

//     if (_isLandscape) {
//       SystemChrome.setPreferredOrientations([
//         DeviceOrientation.landscapeLeft,
//         DeviceOrientation.landscapeRight,
//       ]);
//     } else {
//       SystemChrome.setPreferredOrientations([
//         DeviceOrientation.portraitUp,
//         DeviceOrientation.portraitDown,
//       ]);
//     }
//   }

//   void _cycleAspectRatio() {
//     setState(() {
//       switch (_aspectRatioMode) {
//         case AspectRatioMode.fit:
//           _aspectRatioMode = AspectRatioMode.stretch;
//           break;
//         case AspectRatioMode.stretch:
//           _aspectRatioMode = AspectRatioMode.crop;
//           break;
//         case AspectRatioMode.crop:
//           _aspectRatioMode = AspectRatioMode.original;
//           break;
//         case AspectRatioMode.original:
//           _aspectRatioMode = AspectRatioMode.fit;
//           break;
//       }
//     });

//     _showAspectRatioChangeMessage();
//   }

//   void _showAspectRatioChangeMessage() {
//     String message = '';
//     switch (_aspectRatioMode) {
//       case AspectRatioMode.fit:
//         message = 'Fit to Screen';
//         break;
//       case AspectRatioMode.stretch:
//         message = 'Stretch';
//         break;
//       case AspectRatioMode.crop:
//         message = 'Crop';
//         break;
//       case AspectRatioMode.original:
//         message = '100% (Original)';
//         break;
//     }

//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         duration: const Duration(milliseconds: 800),
//         behavior: SnackBarBehavior.floating,
//         margin: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
//       ),
//     );
//   }

//   void _startHideControlsTimer() {
//     _hideControlsTimer?.cancel();
//     if (!_controlsLocked) {
//       _hideControlsTimer = Timer(const Duration(seconds: 3), () {
//         if (mounted &&
//             _videoPlayerController.value.isPlaying &&
//             !_controlsLocked &&
//             !_isDraggingSeeking) {
//           setState(() {
//             _showControls = false;
//           });
//         }
//       });
//     }
//   }

//   void _toggleControls() {
//     if (_controlsLocked) return;

//     // IMPORTANT: Don't toggle controls while holding speed change
//     if (_isHoldingSpeed && !_isSpeedLocked) return;

//     setState(() {
//       _showControls = !_showControls;
//     });

//     if (_showControls) {
//       _startHideControlsTimer();
//     } else {
//       _hideControlsTimer?.cancel();
//     }
//   }

//   void _toggleLock() {
//     setState(() {
//       _controlsLocked = !_controlsLocked;
//       if (_controlsLocked) {
//         _hideControlsTimer?.cancel();
//         _showControls = false;
//       } else {
//         _showControls = true;
//         _startHideControlsTimer();
//       }
//     });
//   }

//   Future<void> _seekForward() async {
//     if (_controlsLocked) return;

//     final currentPosition = await _videoPlayerController.position;
//     final duration = _videoPlayerController.value.duration;
//     final newPosition = currentPosition! + Duration(seconds: _seekSeconds);

//     if (newPosition < duration) {
//       await _videoPlayerController.seekTo(newPosition);
//     } else {
//       await _videoPlayerController.seekTo(duration);
//     }

//     setState(() {
//       _showForwardOverlay = true;
//     });

//     Future.delayed(const Duration(milliseconds: 600), () {
//       if (mounted) {
//         setState(() {
//           _showForwardOverlay = false;
//         });
//       }
//     });
//   }

//   Future<void> _seekBackward() async {
//     if (_controlsLocked) return;

//     final currentPosition = await _videoPlayerController.position;
//     final newPosition = currentPosition! - Duration(seconds: _seekSeconds);

//     if (newPosition > Duration.zero) {
//       await _videoPlayerController.seekTo(newPosition);
//     } else {
//       await _videoPlayerController.seekTo(Duration.zero);
//     }

//     setState(() {
//       _showBackwardOverlay = true;
//     });

//     Future.delayed(const Duration(milliseconds: 600), () {
//       if (mounted) {
//         setState(() {
//           _showBackwardOverlay = false;
//         });
//       }
//     });
//   }

//   void _startSpeedChange(String side) {
//     if (_controlsLocked || _isSpeedLocked) return;

//     // Cancel auto-hide timer so controls don't disappear while holding
//     _hideControlsTimer?.cancel();

//     // Always start at 1x which is index 0 for both sides now
//     // Left: [1.0, 0.75, 0.5, 0.25] - 1x is at index 0
//     // Right: [1.0, 1.5, 2.0...] - 1x is at index 0
//     int startingIndex = 0;

//     setState(() {
//       _isHoldingSpeed = true;
//       _isSpeedChangeActive = true;
//       _holdingSide = side;
//       _lockIconProgress = 0.0;
//       _currentSpeed = 1.0; // Always start at 1x
//       _currentBreakpointIndex = startingIndex; // Index 0 for both sides
//     });
//     _videoPlayerController.setPlaybackSpeed(1.0);
//   }

//   void _stopSpeedChange() {
//     if (_controlsLocked || _isSpeedLocked) return;

//     // Cancel grace timer
//     _speedLockGraceTimer?.cancel();

//     setState(() {
//       _isHoldingSpeed = false;
//       _isSpeedChangeActive = false;
//       _holdingSide = '';
//       _lockIconProgress = 0.0;
//       _currentSpeed = 1.0;
//       _currentBreakpointIndex = 0;
//     });
//     _videoPlayerController.setPlaybackSpeed(1.0);

//     // Restart auto-hide timer if controls are still visible
//     if (_showControls && !_controlsLocked) {
//       _startHideControlsTimer();
//     }
//   }

//   void _handleSpeedDrag(LongPressMoveUpdateDetails details, Size screenSize) {
//     if (!_isHoldingSpeed || _isSpeedLocked) return;

//     double progress = 0.0;
//     double newSpeed = 1.0;
//     int breakpointIndex = 0;
//     final startY = screenSize.height / 2;
//     final currentY = details.globalPosition.dy;
//     final draggedUp = currentY < (startY - 50); // Dragged up 50px from center

//     if (_holdingSide == 'left') {
//       // Left side - slower speeds [1x, 0.75x, 0.5x, 0.25x]
//       final currentX = details.globalPosition.dx;

//       // Ignore if dragging opposite direction (towards right)
//       if (currentX > screenSize.width / 2) {
//         return;
//       }

//       // Calculate progress from center to left edge
//       // As we drag LEFT (X decreases), progress should INCREASE (0 -> 1)
//       final halfScreen = screenSize.width / 2;
//       final centerPoint = halfScreen;
//       final edgePoint = 40.0;
//       final totalDistance = centerPoint - edgePoint;
//       final currentDistance = centerPoint - currentX; // Distance from center
//       progress = (currentDistance / totalDistance).clamp(0.0, 1.0);

//       // Smoother breakpoint calculation with threshold zones
//       final numBreakpoints = _leftSpeedBreakpoints.length;

//       // Create larger snap zones (15% dead zone around each breakpoint)
//       final snapThreshold = 0.15;

//       // Find which breakpoint we're closest to
//       int nearestIndex = 0;
//       double minDistance = 999.0;

//       for (int i = 0; i < numBreakpoints; i++) {
//         final targetProgress = i / (numBreakpoints - 1);
//         final distance = (progress - targetProgress).abs();

//         if (distance < snapThreshold && distance < minDistance) {
//           nearestIndex = i;
//           minDistance = distance;
//         }
//       }

//       // If we found a snap point, use it; otherwise calculate nearest
//       if (minDistance < snapThreshold) {
//         breakpointIndex = nearestIndex;
//       } else {
//         breakpointIndex = (progress * (numBreakpoints - 1))
//             .round()
//             .clamp(0, numBreakpoints - 1);
//       }

//       newSpeed = _leftSpeedBreakpoints[breakpointIndex];

//       // Check for drag-up-to-lock gesture
//       if (draggedUp &&
//           newSpeed != 1.0 &&
//           breakpointIndex == _currentBreakpointIndex) {
//         _lockSpeed();
//         return;
//       }

//       // Haptic feedback when crossing breakpoints
//       if (_currentBreakpointIndex != breakpointIndex) {
//         HapticFeedback.selectionClick();

//         // Cancel previous grace timer
//         _speedLockGraceTimer?.cancel();

//         // Don't start grace timer for 1x (default speed, no need to lock)
//         if (newSpeed != 1.0) {
//           // Start new grace timer (3 seconds to auto-lock at this breakpoint)
//           _speedLockGraceTimer = Timer(const Duration(seconds: 3), () {
//             if (mounted && _isHoldingSpeed && !_isSpeedLocked) {
//               _lockSpeed();
//             }
//           });
//         }
//       }
//     } else if (_holdingSide == 'right') {
//       // Right side - faster speeds [1x, 1.5x, 2x, 2.5x, 3x, 3.5x, 4x]
//       final currentX = details.globalPosition.dx;

//       // Ignore if dragging opposite direction (towards left)
//       if (currentX < screenSize.width / 2) {
//         return;
//       }

//       // Calculate progress from center to right edge
//       // As we drag RIGHT (X increases), progress should INCREASE (0 -> 1)
//       final halfScreen = screenSize.width / 2;
//       final centerPoint = halfScreen;
//       final edgePoint = screenSize.width - 40;
//       final totalDistance = edgePoint - centerPoint;
//       final currentDistance = currentX - centerPoint; // Distance from center
//       progress = (currentDistance / totalDistance).clamp(0.0, 1.0);

//       // Smoother breakpoint calculation with threshold zones
//       final numBreakpoints = _rightSpeedBreakpoints.length;

//       // Create larger snap zones (12% dead zone around each breakpoint)
//       final snapThreshold = 0.12;

//       // Find which breakpoint we're closest to
//       int nearestIndex = 0;
//       double minDistance = 999.0;

//       for (int i = 0; i < numBreakpoints; i++) {
//         final targetProgress = i / (numBreakpoints - 1);
//         final distance = (progress - targetProgress).abs();

//         if (distance < snapThreshold && distance < minDistance) {
//           nearestIndex = i;
//           minDistance = distance;
//         }
//       }

//       // If we found a snap point, use it; otherwise calculate nearest
//       if (minDistance < snapThreshold) {
//         breakpointIndex = nearestIndex;
//       } else {
//         breakpointIndex = (progress * (numBreakpoints - 1))
//             .round()
//             .clamp(0, numBreakpoints - 1);
//       }

//       newSpeed = _rightSpeedBreakpoints[breakpointIndex];

//       // Check for drag-up-to-lock gesture
//       if (draggedUp &&
//           newSpeed != 1.0 &&
//           breakpointIndex == _currentBreakpointIndex) {
//         _lockSpeed();
//         return;
//       }

//       // Haptic feedback when crossing breakpoints
//       if (_currentBreakpointIndex != breakpointIndex) {
//         HapticFeedback.selectionClick();

//         // Cancel previous grace timer
//         _speedLockGraceTimer?.cancel();

//         // Don't start grace timer for 1x (default speed, no need to lock)
//         if (newSpeed != 1.0) {
//           // Start new grace timer (3 seconds to auto-lock at this breakpoint)
//           _speedLockGraceTimer = Timer(const Duration(seconds: 3), () {
//             if (mounted && _isHoldingSpeed && !_isSpeedLocked) {
//               _lockSpeed();
//             }
//           });
//         }
//       }
//     }

//     setState(() {
//       _lockIconProgress = progress;
//       _currentSpeed = newSpeed;
//       _currentBreakpointIndex = breakpointIndex;
//     });

//     // Set playback speed
//     _videoPlayerController.setPlaybackSpeed(newSpeed);
//   }

//   void _lockSpeed() {
//     if (_controlsLocked) return;

//     HapticFeedback.mediumImpact(); // Haptic feedback when locked

//     setState(() {
//       _isSpeedLocked = true;
//       _isHoldingSpeed = false;
//       // Keep _holdingSide and _currentSpeed to remember which side and speed was locked
//     });
//     _videoPlayerController.setPlaybackSpeed(_currentSpeed);
//   }

//   void _unlockSpeed() {
//     if (_controlsLocked) return;

//     HapticFeedback.lightImpact(); // Haptic feedback when unlocked

//     setState(() {
//       _isSpeedLocked = false;
//       _isSpeedChangeActive = false;
//       _holdingSide = '';
//       _currentSpeed = 1.0;
//     });
//     _videoPlayerController.setPlaybackSpeed(1.0);
//   }

//   String _formatSpeed(double speed) {
//     if (speed == speed.roundToDouble()) {
//       return '${speed.toInt()}x';
//     } else {
//       return '${speed.toStringAsFixed(speed == 0.25 || speed == 0.75 ? 2 : 1)}x';
//     }
//   }

//   Widget _buildBreakpointCircles() {
//     final breakpoints =
//         _holdingSide == 'left' ? _leftSpeedBreakpoints : _rightSpeedBreakpoints;

//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: List.generate(breakpoints.length, (index) {
//         final isActive = index == _currentBreakpointIndex;
//         final speed = breakpoints[index];

//         return Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 4),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               // Circle indicator
//               AnimatedContainer(
//                 duration: const Duration(milliseconds: 200),
//                 width: isActive ? 12 : 8,
//                 height: isActive ? 12 : 8,
//                 decoration: BoxDecoration(
//                   shape: BoxShape.circle,
//                   color:
//                       isActive ? Colors.orange : Colors.white.withOpacity(0.4),
//                   border: Border.all(
//                     color: isActive
//                         ? Colors.orange
//                         : Colors.white.withOpacity(0.6),
//                     width: isActive ? 2 : 1,
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 4),
//               // Speed label
//               Text(
//                 _formatSpeed(speed),
//                 style: TextStyle(
//                   color:
//                       isActive ? Colors.orange : Colors.white.withOpacity(0.6),
//                   fontSize: isActive ? 11 : 10,
//                   fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
//                 ),
//               ),
//             ],
//           ),
//         );
//       }),
//     );
//   }

//   Future<void> _nextVideo() async {
//     final int nextIndex = _currentIndex + 1;
//     if (nextIndex < widget.videoList.length) {
//       setState(() {
//         loaded = false;
//       });

//       _hideControlsTimer?.cancel();
//       _progressUpdateTimer?.cancel();
//       _videoPlayerController.removeListener(_videoListener);
//       await _videoPlayerController.pause();
//       _chewieController.dispose();
//       await _videoPlayerController.dispose();

//       _currentIndex = nextIndex;
//       HistoryVideos.addToHistory(widget.videoList[nextIndex]);

//       _initializeVideoPlayer();
//     }
//   }

//   Future<void> _previousVideo() async {
//     final int previousIndex = _currentIndex - 1;
//     if (previousIndex >= 0) {
//       setState(() {
//         loaded = false;
//       });

//       _hideControlsTimer?.cancel();
//       _progressUpdateTimer?.cancel();
//       _videoPlayerController.removeListener(_videoListener);
//       await _videoPlayerController.pause();
//       _chewieController.dispose();
//       await _videoPlayerController.dispose();

//       _currentIndex = previousIndex;
//       HistoryVideos.addToHistory(widget.videoList[previousIndex]);

//       _initializeVideoPlayer();
//     }
//   }

//   String _formatDuration(Duration duration) {
//     String twoDigits(int n) => n.toString().padLeft(2, '0');
//     final hours = twoDigits(duration.inHours);
//     final minutes = twoDigits(duration.inMinutes.remainder(60));
//     final seconds = twoDigits(duration.inSeconds.remainder(60));

//     if (duration.inHours > 0) {
//       return '$hours:$minutes:$seconds';
//     }
//     return '$minutes:$seconds';
//   }

//   void _handleVerticalDragLeft(DragUpdateDetails details, Size screenSize) {
//     if (_controlsLocked) return;

//     final delta = -details.delta.dy / screenSize.height;
//     setState(() {
//       _currentBrightness = (_currentBrightness + delta).clamp(0.0, 1.0);
//       _showBrightnessOverlay = true;
//     });

//     ScreenBrightness().setScreenBrightness(_currentBrightness);

//     _brightnessTimer?.cancel();
//     _brightnessTimer = Timer(const Duration(seconds: 5), () {
//       if (mounted) {
//         setState(() {
//           _showBrightnessOverlay = false;
//         });
//       }
//     });
//   }

//   void _handleVerticalDragRight(DragUpdateDetails details, Size screenSize) {
//     if (_controlsLocked) return;

//     final delta = -details.delta.dy / screenSize.height;
//     setState(() {
//       _currentVolume = (_currentVolume + delta).clamp(0.0, 1.0);
//       _showVolumeOverlay = true;
//     });

//     VolumeController.instance.setVolume(_currentVolume);

//     _volumeTimer?.cancel();
//     _volumeTimer = Timer(const Duration(seconds: 5), () {
//       if (mounted) {
//         setState(() {
//           _showVolumeOverlay = false;
//         });
//       }
//     });
//   }

//   void _handleHorizontalDragSeek(DragUpdateDetails details, Size screenSize) {
//     if (_controlsLocked || _dragStartPosition == null) return;

//     final delta = details.globalPosition.dx - _dragStartPosition!;
//     final seekAmount = (delta / screenSize.width) *
//         _videoPlayerController.value.duration.inSeconds;

//     final currentPosition = _videoPlayerController.value.position;
//     final newPosition = currentPosition + Duration(seconds: seekAmount.toInt());

//     Duration clampedPosition;
//     if (newPosition < Duration.zero) {
//       clampedPosition = Duration.zero;
//     } else if (newPosition > _videoPlayerController.value.duration) {
//       clampedPosition = _videoPlayerController.value.duration;
//     } else {
//       clampedPosition = newPosition;
//     }

//     setState(() {
//       _isDraggingSeeking = true;
//       _seekPreviewPosition = clampedPosition;
//     });

//     if (_showControls) {
//       _hideControlsTimer?.cancel();
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (!loaded) {
//       return const Scaffold(
//         backgroundColor: Colors.black,
//         body: Center(
//           child: CircularProgressIndicator(color: Colors.white),
//         ),
//       );
//     }

//     final screenSize = MediaQuery.of(context).size;
//     final isPortrait = !_isLandscape;

//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: Stack(
//         children: [
//           // Layer 1: Video Player
//           Center(
//             child: _aspectRatioMode == AspectRatioMode.stretch
//                 ? SizedBox.expand(
//                     child: FittedBox(
//                       fit: BoxFit.fill,
//                       child: SizedBox(
//                         width: _videoPlayerController.value.size.width,
//                         height: _videoPlayerController.value.size.height,
//                         child: VideoPlayer(_videoPlayerController),
//                       ),
//                     ),
//                   )
//                 : _aspectRatioMode == AspectRatioMode.crop
//                     ? SizedBox.expand(
//                         child: FittedBox(
//                           fit: BoxFit.cover,
//                           child: SizedBox(
//                             width: _videoPlayerController.value.size.width,
//                             height: _videoPlayerController.value.size.height,
//                             child: VideoPlayer(_videoPlayerController),
//                           ),
//                         ),
//                       )
//                     : _aspectRatioMode == AspectRatioMode.original
//                         ? Center(
//                             child: SizedBox(
//                               width: _videoPlayerController.value.size.width,
//                               height: _videoPlayerController.value.size.height,
//                               child: VideoPlayer(_videoPlayerController),
//                             ),
//                           )
//                         : AspectRatio(
//                             aspectRatio:
//                                 _videoPlayerController.value.aspectRatio,
//                             child: VideoPlayer(_videoPlayerController),
//                           ),
//           ),

//           // Layer 2: Gradient Background (IgnorePointer)
//           if (!_controlsLocked && _showControls)
//             IgnorePointer(
//               child: AnimatedOpacity(
//                 opacity: _showControls ? 1.0 : 0.0,
//                 duration: const Duration(milliseconds: 300),
//                 child: Container(
//                   decoration: BoxDecoration(
//                     gradient: LinearGradient(
//                       begin: Alignment.topCenter,
//                       end: Alignment.bottomCenter,
//                       colors: [
//                         Colors.black.withOpacity(0.7),
//                         Colors.transparent,
//                         Colors.transparent,
//                         Colors.black.withOpacity(0.8),
//                       ],
//                       stops: const [0.0, 0.3, 0.7, 1.0],
//                     ),
//                   ),
//                 ),
//               ),
//             ),

//           // Layer 3: Touch Zones
//           Row(
//             children: [
//               // Left side
//               Expanded(
//                 child: GestureDetector(
//                   behavior: HitTestBehavior.translucent,
//                   onTap: () {
//                     if (!_controlsLocked) {
//                       if (_showBrightnessOverlay || _showVolumeOverlay) {
//                         setState(() {
//                           _showBrightnessOverlay = false;
//                           _showVolumeOverlay = false;
//                         });
//                         _brightnessTimer?.cancel();
//                         _volumeTimer?.cancel();
//                       }
//                       _toggleControls();
//                     }
//                   },
//                   onDoubleTap: !_controlsLocked ? _seekBackward : null,
//                   onLongPressStart: !_controlsLocked
//                       ? (_) => _startSpeedChange('left')
//                       : null,
//                   onLongPressMoveUpdate: !_controlsLocked
//                       ? (details) => _handleSpeedDrag(details, screenSize)
//                       : null,
//                   onLongPressEnd:
//                       !_controlsLocked ? (_) => _stopSpeedChange() : null,
//                   onVerticalDragUpdate: (details) =>
//                       _handleVerticalDragLeft(details, screenSize),
//                   onHorizontalDragStart: !_controlsLocked
//                       ? (details) {
//                           _dragStartPosition = details.globalPosition.dx;
//                         }
//                       : null,
//                   onHorizontalDragUpdate: (details) =>
//                       _handleHorizontalDragSeek(details, screenSize),
//                   onHorizontalDragEnd: !_controlsLocked
//                       ? (details) {
//                           if (_seekPreviewPosition != null) {
//                             _videoPlayerController
//                                 .seekTo(_seekPreviewPosition!);
//                           }
//                           setState(() {
//                             _dragStartPosition = null;
//                             _isDraggingSeeking = false;
//                             _seekPreviewPosition = null;
//                           });
//                           if (_showControls) {
//                             _startHideControlsTimer();
//                           }
//                         }
//                       : null,
//                   child: Container(
//                     color: Colors.transparent,
//                     child: AnimatedOpacity(
//                       opacity: _showBackwardOverlay ? 1.0 : 0.0,
//                       duration: const Duration(milliseconds: 200),
//                       child: Container(
//                         decoration: BoxDecoration(
//                           gradient: LinearGradient(
//                             begin: Alignment.centerLeft,
//                             end: Alignment.centerRight,
//                             colors: [
//                               Colors.black.withOpacity(0.6),
//                               Colors.transparent,
//                             ],
//                           ),
//                         ),
//                         child: Center(
//                           child: Column(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               const Icon(
//                                 Icons.fast_rewind_rounded,
//                                 color: Colors.white,
//                                 size: 50,
//                               ),
//                               const SizedBox(height: 8),
//                               Text(
//                                 '« $_seekSeconds seconds',
//                                 style: const TextStyle(
//                                   color: Colors.white,
//                                   fontSize: 16,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//               ),

//               // Right side
//               Expanded(
//                 child: GestureDetector(
//                   behavior: HitTestBehavior.translucent,
//                   onTap: () {
//                     if (!_controlsLocked) {
//                       if (_showBrightnessOverlay || _showVolumeOverlay) {
//                         setState(() {
//                           _showBrightnessOverlay = false;
//                           _showVolumeOverlay = false;
//                         });
//                         _brightnessTimer?.cancel();
//                         _volumeTimer?.cancel();
//                       }
//                       _toggleControls();
//                     }
//                   },
//                   onDoubleTap: !_controlsLocked ? _seekForward : null,
//                   onLongPressStart: !_controlsLocked
//                       ? (_) => _startSpeedChange('right')
//                       : null,
//                   onLongPressMoveUpdate: !_controlsLocked
//                       ? (details) => _handleSpeedDrag(details, screenSize)
//                       : null,
//                   onLongPressEnd:
//                       !_controlsLocked ? (_) => _stopSpeedChange() : null,
//                   onVerticalDragUpdate: (details) =>
//                       _handleVerticalDragRight(details, screenSize),
//                   onHorizontalDragStart: !_controlsLocked
//                       ? (details) {
//                           _dragStartPosition = details.globalPosition.dx;
//                         }
//                       : null,
//                   onHorizontalDragUpdate: (details) =>
//                       _handleHorizontalDragSeek(details, screenSize),
//                   onHorizontalDragEnd: !_controlsLocked
//                       ? (details) {
//                           if (_seekPreviewPosition != null) {
//                             _videoPlayerController
//                                 .seekTo(_seekPreviewPosition!);
//                           }
//                           setState(() {
//                             _dragStartPosition = null;
//                             _isDraggingSeeking = false;
//                             _seekPreviewPosition = null;
//                           });
//                           if (_showControls) {
//                             _startHideControlsTimer();
//                           }
//                         }
//                       : null,
//                   child: Container(
//                     color: Colors.transparent,
//                     child: AnimatedOpacity(
//                       opacity: _showForwardOverlay ? 1.0 : 0.0,
//                       duration: const Duration(milliseconds: 200),
//                       child: Container(
//                         decoration: BoxDecoration(
//                           gradient: LinearGradient(
//                             begin: Alignment.centerRight,
//                             end: Alignment.centerLeft,
//                             colors: [
//                               Colors.black.withOpacity(0.6),
//                               Colors.transparent,
//                             ],
//                           ),
//                         ),
//                         child: Center(
//                           child: Column(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               const Icon(
//                                 Icons.fast_forward_rounded,
//                                 color: Colors.white,
//                                 size: 50,
//                               ),
//                               const SizedBox(height: 8),
//                               Text(
//                                 '$_seekSeconds seconds »',
//                                 style: const TextStyle(
//                                   color: Colors.white,
//                                   fontSize: 16,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),

//           // Brightness Overlay
//           if (_showBrightnessOverlay)
//             Positioned(
//               left: 40,
//               top: isPortrait
//                   ? (screenSize.height / 2) - 70
//                   : (screenSize.height / 2) - 105,
//               child: Material(
//                 color: Colors.transparent,
//                 child: Container(
//                   padding: isPortrait
//                       ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
//                       : const EdgeInsets.symmetric(
//                           horizontal: 16, vertical: 12),
//                   decoration: BoxDecoration(
//                     color: Colors.black.withOpacity(0.85),
//                     borderRadius: BorderRadius.circular(12),
//                     border: Border.all(
//                         color: Colors.white.withOpacity(0.2), width: 1),
//                   ),
//                   child: Column(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Icon(
//                         Icons.brightness_6,
//                         color: Colors.yellow,
//                         size: isPortrait ? 24 : 28,
//                       ),
//                       SizedBox(height: isPortrait ? 8 : 10),
//                       GestureDetector(
//                         behavior: HitTestBehavior.opaque,
//                         onVerticalDragStart: (_) {
//                           _brightnessTimer?.cancel();
//                         },
//                         onVerticalDragUpdate: (details) {
//                           final barHeight = isPortrait ? 70.0 : 100.0;
//                           final double relativeY = details.localPosition.dy;
//                           final clampedY = relativeY.clamp(0.0, barHeight);
//                           double newBrightness = 1.0 - (clampedY / barHeight);
//                           newBrightness = (newBrightness * 50).round() / 50.0;
//                           newBrightness = newBrightness.clamp(0.0, 1.0);
//                           setState(() {
//                             _currentBrightness = newBrightness;
//                           });
//                           ScreenBrightness()
//                               .setScreenBrightness(_currentBrightness);
//                         },
//                         onVerticalDragEnd: (_) {
//                           _brightnessTimer =
//                               Timer(const Duration(seconds: 5), () {
//                             if (mounted)
//                               setState(() => _showBrightnessOverlay = false);
//                           });
//                         },
//                         child: Container(
//                           color: Colors.transparent,
//                           height: isPortrait ? 70.0 : 100.0,
//                           width: 40.0,
//                           alignment: Alignment.center,
//                           child: SizedBox(
//                             width: 6,
//                             child: Stack(
//                               alignment: Alignment.bottomCenter,
//                               children: [
//                                 Container(
//                                   decoration: BoxDecoration(
//                                     borderRadius: BorderRadius.circular(3),
//                                     color: Colors.white12,
//                                   ),
//                                 ),
//                                 FractionallySizedBox(
//                                   heightFactor: _currentBrightness,
//                                   child: Container(
//                                     decoration: BoxDecoration(
//                                       borderRadius: BorderRadius.circular(3),
//                                       gradient: LinearGradient(
//                                         begin: Alignment.bottomCenter,
//                                         end: Alignment.topCenter,
//                                         colors: [
//                                           Colors.yellow.shade700,
//                                           Colors.yellow.shade300,
//                                         ],
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ),
//                       ),
//                       SizedBox(height: isPortrait ? 8 : 10),
//                       SizedBox(
//                         width: 36,
//                         child: Text(
//                           '${(_currentBrightness * 100).toInt()}%',
//                           textAlign: TextAlign.center,
//                           style: TextStyle(
//                             color: Colors.white,
//                             fontSize: (_currentBrightness * 100).toInt() >= 100
//                                 ? (isPortrait ? 11 : 13)
//                                 : (isPortrait ? 12 : 14),
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),

//           // Volume Overlay
//           if (_showVolumeOverlay)
//             Positioned(
//               right: 40,
//               top: isPortrait
//                   ? (screenSize.height / 2) - 70
//                   : (screenSize.height / 2) - 105,
//               child: Material(
//                 color: Colors.transparent,
//                 child: Container(
//                   padding: isPortrait
//                       ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
//                       : const EdgeInsets.symmetric(
//                           horizontal: 16, vertical: 12),
//                   decoration: BoxDecoration(
//                     color: Colors.black.withOpacity(0.85),
//                     borderRadius: BorderRadius.circular(12),
//                     border: Border.all(
//                         color: Colors.white.withOpacity(0.2), width: 1),
//                   ),
//                   child: Column(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Icon(
//                         _currentVolume > 0.6
//                             ? Icons.volume_up_rounded
//                             : _currentVolume > 0.3
//                                 ? Icons.volume_down_rounded
//                                 : _currentVolume > 0
//                                     ? Icons.volume_mute_rounded
//                                     : Icons.volume_off_rounded,
//                         color: Colors.blue.shade300,
//                         size: isPortrait ? 24 : 28,
//                       ),
//                       SizedBox(height: isPortrait ? 8 : 10),
//                       GestureDetector(
//                         behavior: HitTestBehavior.opaque,
//                         onVerticalDragStart: (_) {
//                           _volumeTimer?.cancel();
//                         },
//                         onVerticalDragUpdate: (details) {
//                           final barHeight = isPortrait ? 70.0 : 100.0;
//                           final double relativeY = details.localPosition.dy;
//                           final clampedY = relativeY.clamp(0.0, barHeight);
//                           double newVolume = 1.0 - (clampedY / barHeight);
//                           newVolume = (newVolume * 50).round() / 50.0;
//                           newVolume = newVolume.clamp(0.0, 1.0);
//                           setState(() {
//                             _currentVolume = newVolume;
//                           });
//                           VolumeController.instance.setVolume(_currentVolume);
//                         },
//                         onVerticalDragEnd: (_) {
//                           _volumeTimer = Timer(const Duration(seconds: 5), () {
//                             if (mounted)
//                               setState(() => _showVolumeOverlay = false);
//                           });
//                         },
//                         child: Container(
//                           color: Colors.transparent,
//                           height: isPortrait ? 70.0 : 100.0,
//                           width: 40.0,
//                           alignment: Alignment.center,
//                           child: SizedBox(
//                             width: 6,
//                             child: Stack(
//                               alignment: Alignment.bottomCenter,
//                               children: [
//                                 Container(
//                                   decoration: BoxDecoration(
//                                     borderRadius: BorderRadius.circular(3),
//                                     color: Colors.white12,
//                                   ),
//                                 ),
//                                 FractionallySizedBox(
//                                   heightFactor: _currentVolume,
//                                   child: Container(
//                                     decoration: BoxDecoration(
//                                       borderRadius: BorderRadius.circular(3),
//                                       gradient: LinearGradient(
//                                         begin: Alignment.bottomCenter,
//                                         end: Alignment.topCenter,
//                                         colors: [
//                                           Colors.blue.shade700,
//                                           Colors.blue.shade300,
//                                         ],
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ),
//                       ),
//                       SizedBox(height: isPortrait ? 8 : 10),
//                       SizedBox(
//                         width: 36,
//                         child: Text(
//                           '${(_currentVolume * 100).toInt()}%',
//                           textAlign: TextAlign.center,
//                           style: TextStyle(
//                             color: Colors.white,
//                             fontSize: (_currentVolume * 100).toInt() >= 100
//                                 ? (isPortrait ? 11 : 13)
//                                 : (isPortrait ? 12 : 14),
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),

//           // Drag Seek Preview
//           if (_isDraggingSeeking && _seekPreviewPosition != null)
//             Center(
//               child: Container(
//                 padding:
//                     const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
//                 decoration: BoxDecoration(
//                   color: Colors.black.withOpacity(0.8),
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: Text(
//                   _formatDuration(_seekPreviewPosition!),
//                   style: const TextStyle(
//                     color: Colors.white,
//                     fontSize: 24,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ),
//             ),

//           // Multi-Speed Overlay (while holding) - INDEPENDENT of controls, 70px gap
//           if (_isHoldingSpeed && !_isSpeedLocked)
//             Positioned.fill(
//               child: Row(
//                 children: [
//                   // Left half overlay
//                   if (_holdingSide == 'left')
//                     Flexible(
//                       child: Container(
//                         decoration: BoxDecoration(
//                           gradient: LinearGradient(
//                             begin: Alignment.centerLeft,
//                             end: Alignment.centerRight,
//                             colors: [
//                               Colors.black.withOpacity(0.2),
//                               Colors.transparent,
//                             ],
//                           ),
//                         ),
//                         child: Stack(
//                           children: [
//                             // Breakpoint circles at top
//                             Positioned(
//                               left: 0,
//                               right: 0,
//                               top: 60,
//                               child: Center(
//                                 child: Container(
//                                   padding: const EdgeInsets.symmetric(
//                                       horizontal: 12, vertical: 8),
//                                   decoration: BoxDecoration(
//                                     color: Colors.black.withOpacity(0.7),
//                                     borderRadius: BorderRadius.circular(20),
//                                   ),
//                                   child: _buildBreakpointCircles(),
//                                 ),
//                               ),
//                             ),
//                             // Dynamic speed text - FIXED at 110px (70px gap from icon at 40px)
//                             Positioned(
//                               left: 110,
//                               top: screenSize.height / 2 - 14,
//                               child: Text(
//                                 _formatSpeed(_currentSpeed),
//                                 style: TextStyle(
//                                   color: Colors.white.withOpacity(0.75),
//                                   fontSize: 26,
//                                   fontWeight: FontWeight.w600,
//                                   letterSpacing: 1,
//                                 ),
//                               ),
//                             ),
//                             // Animated lock icon on left edge - "<<" direction
//                             Positioned(
//                               left: 40,
//                               top: screenSize.height / 2 - 18,
//                               child: AnimatedContainer(
//                                 duration: const Duration(milliseconds: 250),
//                                 curve: Curves.easeInOut,
//                                 padding: const EdgeInsets.all(8),
//                                 decoration: BoxDecoration(
//                                   color: Color.lerp(
//                                     Colors.white.withOpacity(0.15),
//                                     Colors.orange.withOpacity(0.75),
//                                     _lockIconProgress,
//                                   ),
//                                   shape: BoxShape.circle,
//                                 ),
//                                 child: Icon(
//                                   Icons
//                                       .keyboard_double_arrow_left_rounded, // << direction
//                                   color: Colors.white.withOpacity(0.9),
//                                   size: 18,
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     )
//                   else
//                     const Spacer(),

//                   // Right half overlay
//                   if (_holdingSide == 'right')
//                     Flexible(
//                       child: Container(
//                         decoration: BoxDecoration(
//                           gradient: LinearGradient(
//                             begin: Alignment.centerRight,
//                             end: Alignment.centerLeft,
//                             colors: [
//                               Colors.black.withOpacity(0.2),
//                               Colors.transparent,
//                             ],
//                           ),
//                         ),
//                         child: Stack(
//                           children: [
//                             // Breakpoint circles at top
//                             Positioned(
//                               left: 0,
//                               right: 0,
//                               top: 60,
//                               child: Center(
//                                 child: Container(
//                                   padding: const EdgeInsets.symmetric(
//                                       horizontal: 12, vertical: 8),
//                                   decoration: BoxDecoration(
//                                     color: Colors.black.withOpacity(0.7),
//                                     borderRadius: BorderRadius.circular(20),
//                                   ),
//                                   child: _buildBreakpointCircles(),
//                                 ),
//                               ),
//                             ),
//                             // Dynamic speed text - FIXED at 110px (70px gap from icon at 40px)
//                             Positioned(
//                               right: 110,
//                               top: screenSize.height / 2 - 14,
//                               child: Text(
//                                 _formatSpeed(_currentSpeed),
//                                 style: TextStyle(
//                                   color: Colors.white.withOpacity(0.75),
//                                   fontSize: 26,
//                                   fontWeight: FontWeight.w600,
//                                   letterSpacing: 1,
//                                 ),
//                               ),
//                             ),
//                             // Animated lock icon on right edge - ">>" direction
//                             Positioned(
//                               right: 40,
//                               top: screenSize.height / 2 - 18,
//                               child: AnimatedContainer(
//                                 duration: const Duration(milliseconds: 250),
//                                 curve: Curves.easeInOut,
//                                 padding: const EdgeInsets.all(8),
//                                 decoration: BoxDecoration(
//                                   color: Color.lerp(
//                                     Colors.white.withOpacity(0.15),
//                                     Colors.orange.withOpacity(0.75),
//                                     _lockIconProgress,
//                                   ),
//                                   shape: BoxShape.circle,
//                                 ),
//                                 child: Icon(
//                                   Icons
//                                       .keyboard_double_arrow_right_rounded, // >> direction
//                                   color: Colors.white.withOpacity(0.9),
//                                   size: 18,
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     )
//                   else
//                     const Spacer(),
//                 ],
//               ),
//             ),

//           // Lock Button
//           if (_controlsLocked)
//             Positioned(
//               top: 50,
//               right: 20,
//               child: GestureDetector(
//                 onTap: _toggleLock,
//                 child: Container(
//                   padding: const EdgeInsets.all(12),
//                   decoration: BoxDecoration(
//                     color: Colors.black.withOpacity(0.7),
//                     borderRadius: BorderRadius.circular(30),
//                   ),
//                   child: const Icon(
//                     Icons.lock,
//                     color: Colors.white,
//                     size: 28,
//                   ),
//                 ),
//               ),
//             ),

//           // Persistent Speed Locked Icon with speed display (stays in same position)
//           if (_isSpeedLocked)
//             Positioned(
//               left: _holdingSide == 'right' ? null : 40,
//               right: _holdingSide == 'right' ? 40 : null,
//               top: screenSize.height / 2 - 18,
//               child: GestureDetector(
//                 onTap: _unlockSpeed,
//                 child: Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     // Lock icon
//                     AnimatedContainer(
//                       duration: const Duration(milliseconds: 300),
//                       padding: const EdgeInsets.all(8),
//                       decoration: BoxDecoration(
//                         color: Colors.orange.withOpacity(0.8),
//                         shape: BoxShape.circle,
//                         boxShadow: [
//                           BoxShadow(
//                             color: Colors.orange.withOpacity(0.3),
//                             blurRadius: 6,
//                             spreadRadius: 1,
//                           ),
//                         ],
//                       ),
//                       child: const Icon(
//                         Icons.lock_rounded,
//                         color: Colors.white,
//                         size: 18,
//                       ),
//                     ),
//                     const SizedBox(width: 8),
//                     // Speed indicator next to lock
//                     Container(
//                       padding: const EdgeInsets.symmetric(
//                           horizontal: 8, vertical: 4),
//                       decoration: BoxDecoration(
//                         color: Colors.orange.withOpacity(0.2),
//                         borderRadius: BorderRadius.circular(12),
//                         border: Border.all(
//                           color: Colors.orange.withOpacity(0.6),
//                           width: 1,
//                         ),
//                       ),
//                       child: Text(
//                         _formatSpeed(_currentSpeed),
//                         style: const TextStyle(
//                           color: Colors.orange,
//                           fontSize: 12,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),

//           // Layer 4: Control Buttons (dimmed when holding speed OR brightness/volume active)
//           if (!_controlsLocked && _showControls)
//             AnimatedOpacity(
//               opacity: _isHoldingSpeed
//                   ? 0.30 // 30% opacity when holding speed
//                   : (_showBrightnessOverlay || _showVolumeOverlay)
//                       ? 0.15
//                       : 1.0,
//               duration: const Duration(milliseconds: 300),
//               child: _buildControlButtons(),
//             ),
//         ],
//       ),
//     );
//   }

//   Widget _buildControlButtons() {
//     return SafeArea(
//       // Wrap entire control layer with SafeArea
//       top: true,
//       bottom: true,
//       left: true,
//       right: true,
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           // Top Bar
//           Padding(
//             padding: const EdgeInsets.only(top: 8, left: 8, right: 8),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 // First line: Back button, Title, Menu
//                 Row(
//                   children: [
//                     IconButton(
//                       icon: const Icon(Icons.arrow_back, color: Colors.white),
//                       onPressed: () => Navigator.pop(context),
//                     ),
//                     Expanded(
//                       child: Text(
//                         widget.videoList[_currentIndex].title ?? 'Video',
//                         style: const TextStyle(
//                           color: Colors.white,
//                           fontSize: 16,
//                           fontWeight: FontWeight.w500,
//                         ),
//                         maxLines: 1,
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                     ),
//                     IconButton(
//                       icon: const Icon(Icons.more_vert, color: Colors.white),
//                       onPressed: () {},
//                     ),
//                   ],
//                 ),
//                 // Second line: Rotation button and Speed indicator with background
//                 Padding(
//                   padding: const EdgeInsets.only(left: 8, top: 4),
//                   child: Container(
//                     padding:
//                         const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
//                     decoration: BoxDecoration(
//                       color: Colors.black.withOpacity(0.3),
//                       borderRadius: BorderRadius.circular(20),
//                     ),
//                     child: Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         IconButton(
//                           icon: Icon(
//                             _isLandscape
//                                 ? Icons.screen_rotation_rounded
//                                 : Icons.stay_current_portrait_rounded,
//                             color: Colors.white.withOpacity(0.85),
//                             size: 19,
//                           ),
//                           onPressed: () {
//                             HapticFeedback.lightImpact();
//                             _toggleOrientation();
//                           },
//                         ),
//                         const SizedBox(width: 4),
//                         // Speed indicator
//                         Container(
//                           padding: const EdgeInsets.symmetric(
//                               horizontal: 8, vertical: 4),
//                           decoration: BoxDecoration(
//                             color: (_isSpeedChangeActive || _isSpeedLocked)
//                                 ? Colors.orange.withOpacity(0.3)
//                                 : Colors.white.withOpacity(0.15),
//                             borderRadius: BorderRadius.circular(12),
//                             border: Border.all(
//                               color: (_isSpeedChangeActive || _isSpeedLocked)
//                                   ? Colors.orange.withOpacity(0.6)
//                                   : Colors.white.withOpacity(0.4),
//                               width: 1,
//                             ),
//                           ),
//                           child: Text(
//                             _formatSpeed(_currentSpeed),
//                             style: TextStyle(
//                               color: (_isSpeedChangeActive || _isSpeedLocked)
//                                   ? Colors.orange
//                                   : Colors.white.withOpacity(0.85),
//                               fontSize: 11,
//                               fontWeight: FontWeight.w600,
//                             ),
//                           ),
//                         ),
//                         const SizedBox(width: 4),
//                       ],
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),

//           // Bottom Controls
//           Padding(
//             padding: const EdgeInsets.only(bottom: 20),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 // Progress Bar
//                 Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 24),
//                   child: AnimatedBuilder(
//                     animation: _videoPlayerController,
//                     builder: (context, child) {
//                       final position = _videoPlayerController.value.position;
//                       final duration = _videoPlayerController.value.duration;
//                       final validPosition = position.inSeconds.toDouble();
//                       final validDuration = duration.inSeconds > 0
//                           ? duration.inSeconds.toDouble()
//                           : 1.0;

//                       return Column(
//                         children: [
//                           SliderTheme(
//                             data: SliderThemeData(
//                               trackHeight: 3,
//                               thumbShape: const RoundSliderThumbShape(
//                                 enabledThumbRadius: 6,
//                               ),
//                               overlayShape: const RoundSliderOverlayShape(
//                                 overlayRadius: 12,
//                               ),
//                             ),
//                             child: Slider(
//                               value: validPosition.clamp(0.0, validDuration),
//                               max: validDuration,
//                               activeColor: Colors.red,
//                               inactiveColor: Colors.white.withOpacity(0.3),
//                               onChanged: (newValue) {
//                                 _videoPlayerController.seekTo(
//                                   Duration(seconds: newValue.toInt()),
//                                 );
//                               },
//                             ),
//                           ),
//                           Padding(
//                             padding: const EdgeInsets.symmetric(horizontal: 8),
//                             child: Row(
//                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                               children: [
//                                 Text(
//                                   _formatDuration(position),
//                                   style: const TextStyle(
//                                     color: Colors.white,
//                                     fontSize: 12,
//                                   ),
//                                 ),
//                                 Text(
//                                   _formatDuration(duration),
//                                   style: const TextStyle(
//                                     color: Colors.white,
//                                     fontSize: 12,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ],
//                       );
//                     },
//                   ),
//                 ),

//                 // Control Buttons
//                 Padding(
//                   padding: const EdgeInsets.only(top: 8),
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                     children: [
//                       IconButton(
//                         icon: const Icon(
//                           Icons.lock_open,
//                           color: Colors.white,
//                           size: 28,
//                         ),
//                         onPressed: _toggleLock,
//                       ),
//                       IconButton(
//                         icon: Icon(
//                           Icons.skip_previous_rounded,
//                           color: _currentIndex > 0
//                               ? Colors.white
//                               : Colors.white.withOpacity(0.3),
//                           size: 36,
//                         ),
//                         onPressed: _currentIndex > 0 ? _previousVideo : null,
//                       ),
//                       Container(
//                         decoration: BoxDecoration(
//                           shape: BoxShape.circle,
//                           color: Colors.white.withOpacity(0.2),
//                         ),
//                         child: IconButton(
//                           icon: Icon(
//                             _videoPlayerController.value.isPlaying
//                                 ? Icons.pause_rounded
//                                 : Icons.play_arrow_rounded,
//                             color: Colors.white,
//                             size: 40,
//                           ),
//                           onPressed: () {
//                             setState(() {
//                               if (_videoPlayerController.value.isPlaying) {
//                                 _chewieController.pause();
//                                 _hideControlsTimer?.cancel();
//                               } else {
//                                 _chewieController.play();
//                                 _startHideControlsTimer();
//                               }
//                             });
//                           },
//                         ),
//                       ),
//                       IconButton(
//                         icon: Icon(
//                           Icons.skip_next_rounded,
//                           color: _currentIndex < widget.videoList.length - 1
//                               ? Colors.white
//                               : Colors.white.withOpacity(0.3),
//                           size: 36,
//                         ),
//                         onPressed: _currentIndex < widget.videoList.length - 1
//                             ? _nextVideo
//                             : null,
//                       ),
//                       IconButton(
//                         icon: const Icon(
//                           Icons.aspect_ratio,
//                           color: Colors.white,
//                           size: 28,
//                         ),
//                         onPressed: _cycleAspectRatio,
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
import 'dart:async';
import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nova_videoplayer/functions/history.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:video_player/video_player.dart';
import 'package:volume_controller/volume_controller.dart';

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

class _VideoPLayerPageState extends State<VideoPLayerPage> {
  late VideoPlayerController _videoPlayerController;
  late ChewieController _chewieController;
  int _currentIndex = 0;
  bool loaded = false;
  bool _showControls = true;
  bool _controlsLocked = false;
  Timer? _hideControlsTimer;
  Timer? _progressUpdateTimer;

  bool _isLandscape = true;
  AspectRatioMode _aspectRatioMode = AspectRatioMode.fit;

  bool _showForwardOverlay = false;
  bool _showBackwardOverlay = false;
  int _seekSeconds = 10;

  // ── Hold-to-seek speed selector ─────────────────────────────
  // All speeds in one row. Left half = slower side (starts at current speed
  // going left towards 0.25x). Right half = faster side (going right to 4x).
  final List<double> _speedBreakpoints = [
    0.25,
    0.5,
    0.75,
    1.0,
    1.25,
    1.5,
    2.0,
    3.0,
    4.0
  ];
  double _currentSpeed = 1.0; // Saved speed - persists, used as starting point
  double _activeSpeed = 1.0; // Speed applied during hold
  bool _isHolding = false; // Long press active?
  bool _showSpeedWidget = false;
  String _holdSide = ''; // 'left' or 'right'
  double? _holdStartX; // Global X where long press began
  int _activeSpeedIndex = 3; // Index in _speedBreakpoints (1x = index 3)

  // ── Brightness & Volume ──────────────────────────────────────
  double _currentBrightness = 0.5;
  double _currentVolume = 0.5;
  bool _showBrightnessOverlay = false;
  bool _showVolumeOverlay = false;
  Timer? _brightnessTimer;
  Timer? _volumeTimer;

  // ── Drag seeking ─────────────────────────────────────────────
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
    _chewieController.dispose();
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
    if (mounted && _videoPlayerController.value.isInitialized) setState(() {});
  }

  void _startProgressTimer() {
    _progressUpdateTimer?.cancel();
    _progressUpdateTimer =
        Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted && _videoPlayerController.value.isPlaying) setState(() {});
    });
  }

  void _initializeVideoPlayer() async {
    final file = await widget.videoList[_currentIndex].file;
    _videoPlayerController = VideoPlayerController.file(File(file?.path ?? ''));
    await _videoPlayerController.initialize();
    final ar = _videoPlayerController.value.aspectRatio;
    _isLandscape = ar > 1.0;
    SystemChrome.setPreferredOrientations(_isLandscape
        ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
        : [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController,
      autoPlay: true,
      looping: false,
      showControls: false,
      autoInitialize: true,
    );
    _videoPlayerController.addListener(_videoListener);
    _startProgressTimer();
    setState(() => loaded = true);
    _startHideControlsTimer();
  }

  void _toggleOrientation() {
    setState(() => _isLandscape = !_isLandscape);
    SystemChrome.setPreferredOrientations(_isLandscape
        ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
        : [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  }

  void _cycleAspectRatio() {
    setState(() {
      switch (_aspectRatioMode) {
        case AspectRatioMode.fit:
          _aspectRatioMode = AspectRatioMode.stretch;
          break;
        case AspectRatioMode.stretch:
          _aspectRatioMode = AspectRatioMode.crop;
          break;
        case AspectRatioMode.crop:
          _aspectRatioMode = AspectRatioMode.original;
          break;
        case AspectRatioMode.original:
          _aspectRatioMode = AspectRatioMode.fit;
          break;
      }
    });
    final msgs = {
      AspectRatioMode.fit: 'Fit',
      AspectRatioMode.stretch: 'Stretch',
      AspectRatioMode.crop: 'Crop',
      AspectRatioMode.original: 'Original'
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msgs[_aspectRatioMode]!),
      duration: const Duration(milliseconds: 700),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
    ));
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    if (!_controlsLocked) {
      _hideControlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted &&
            _videoPlayerController.value.isPlaying &&
            !_controlsLocked &&
            !_isDraggingSeeking) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  void _toggleControls() {
    if (_controlsLocked || _isHolding) return;
    setState(() => _showControls = !_showControls);
    if (_showControls)
      _startHideControlsTimer();
    else
      _hideControlsTimer?.cancel();
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
  }

  Future<void> _seekBackward() async {
    if (_controlsLocked) return;
    final pos = await _videoPlayerController.position;
    final np = pos! - Duration(seconds: _seekSeconds);
    await _videoPlayerController
        .seekTo(np > Duration.zero ? np : Duration.zero);
    setState(() => _showBackwardOverlay = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _showBackwardOverlay = false);
    });
  }

  Future<void> _nextVideo() async {
    final next = _currentIndex + 1;
    if (next < widget.videoList.length) {
      setState(() => loaded = false);
      _hideControlsTimer?.cancel();
      _progressUpdateTimer?.cancel();
      _videoPlayerController.removeListener(_videoListener);
      await _videoPlayerController.pause();
      _chewieController.dispose();
      await _videoPlayerController.dispose();
      _currentIndex = next;
      HistoryVideos.addToHistory(widget.videoList[next]);
      _initializeVideoPlayer();
    }
  }

  Future<void> _previousVideo() async {
    final prev = _currentIndex - 1;
    if (prev >= 0) {
      setState(() => loaded = false);
      _hideControlsTimer?.cancel();
      _progressUpdateTimer?.cancel();
      _videoPlayerController.removeListener(_videoListener);
      await _videoPlayerController.pause();
      _chewieController.dispose();
      await _videoPlayerController.dispose();
      _currentIndex = prev;
      HistoryVideos.addToHistory(widget.videoList[prev]);
      _initializeVideoPlayer();
    }
  }

  String _formatDuration(Duration d) {
    String dd(int n) => n.toString().padLeft(2, '0');
    if (d.inHours > 0)
      return '${dd(d.inHours)}:${dd(d.inMinutes.remainder(60))}:${dd(d.inSeconds.remainder(60))}';
    return '${dd(d.inMinutes.remainder(60))}:${dd(d.inSeconds.remainder(60))}';
  }

  String _formatSpeed(double s) {
    if (s == s.roundToDouble()) return '${s.toInt()}x';
    return '${s.toStringAsFixed(2)}x';
  }

  // ── Hold-to-seek handlers ─────────────────────────────────────
  void _onLongPressStart(LongPressStartDetails details, String side) {
    // Only activate if video is playing
    if (_controlsLocked || !_videoPlayerController.value.isPlaying) return;

    _hideControlsTimer?.cancel();

    // Start from _currentSpeed (the persisted speed)
    final startIndex = _speedBreakpoints.indexOf(_currentSpeed);
    final safeIndex = startIndex == -1 ? 3 : startIndex; // fallback to 1x

    setState(() {
      _isHolding = true;
      _showSpeedWidget = true;
      _holdSide = side;
      _holdStartX = details.globalPosition.dx;
      _activeSpeedIndex = safeIndex;
      _activeSpeed = _speedBreakpoints[safeIndex];
    });

    HapticFeedback.mediumImpact();
    _videoPlayerController.setPlaybackSpeed(_activeSpeed);
  }

  void _onLongPressMoveUpdate(
      LongPressMoveUpdateDetails details, Size screenSize) {
    if (!_isHolding || _controlsLocked) return;

    // Map horizontal drag to speed index
    // Full screen width = full range of speeds
    final dx =
        details.globalPosition.dx - (_holdStartX ?? screenSize.width / 2);

    // Sensitivity: each ~40px of drag = one speed step
    const pxPerStep = 40.0;
    final startIndex = _speedBreakpoints.indexOf(_currentSpeed);
    final safeStart = startIndex == -1 ? 3 : startIndex;

    int newIndex = safeStart + (dx / pxPerStep).round();
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

    // Save the chosen speed as the new persisted speed
    setState(() {
      _currentSpeed = _activeSpeed;
      _isHolding = false;
      _showSpeedWidget = false;
      _holdSide = '';
      _holdStartX = null;
    });

    // Keep the chosen speed applied
    _videoPlayerController.setPlaybackSpeed(_currentSpeed);
    HapticFeedback.lightImpact();

    if (_showControls && !_controlsLocked) _startHideControlsTimer();
  }

  void _handleVerticalDragLeft(DragUpdateDetails d, Size s) {
    if (_controlsLocked) return;
    final delta = -d.delta.dy / s.height;
    setState(() {
      _currentBrightness = (_currentBrightness + delta).clamp(0.0, 1.0);
      _showBrightnessOverlay = true;
    });
    ScreenBrightness().setScreenBrightness(_currentBrightness);
    _brightnessTimer?.cancel();
    _brightnessTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _showBrightnessOverlay = false);
    });
  }

  void _handleVerticalDragRight(DragUpdateDetails d, Size s) {
    if (_controlsLocked) return;
    final delta = -d.delta.dy / s.height;
    setState(() {
      _currentVolume = (_currentVolume + delta).clamp(0.0, 1.0);
      _showVolumeOverlay = true;
    });
    VolumeController.instance.setVolume(_currentVolume);
    _volumeTimer?.cancel();
    _volumeTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _showVolumeOverlay = false);
    });
  }

  void _handleHorizontalDragSeek(DragUpdateDetails d, Size s) {
    if (_controlsLocked || _dragStartPosition == null) return;
    final delta = d.globalPosition.dx - _dragStartPosition!;
    final seekAmt =
        (delta / s.width) * _videoPlayerController.value.duration.inSeconds;
    final cur = _videoPlayerController.value.position;
    final np = cur + Duration(seconds: seekAmt.toInt());
    final dur = _videoPlayerController.value.duration;
    Duration clamped = np < Duration.zero
        ? Duration.zero
        : np > dur
            ? dur
            : np;
    setState(() {
      _isDraggingSeeking = true;
      _seekPreviewPosition = clamped;
    });
    if (_showControls) _hideControlsTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final screenSize = MediaQuery.of(context).size;
    final isPortrait = !_isLandscape;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Layer 1: Video ───────────────────────────────────
          Center(
            child: _aspectRatioMode == AspectRatioMode.stretch
                ? SizedBox.expand(
                    child: FittedBox(
                        fit: BoxFit.fill,
                        child: SizedBox(
                            width: _videoPlayerController.value.size.width,
                            height: _videoPlayerController.value.size.height,
                            child: VideoPlayer(_videoPlayerController))))
                : _aspectRatioMode == AspectRatioMode.crop
                    ? SizedBox.expand(
                        child: FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                                width: _videoPlayerController.value.size.width,
                                height:
                                    _videoPlayerController.value.size.height,
                                child: VideoPlayer(_videoPlayerController))))
                    : _aspectRatioMode == AspectRatioMode.original
                        ? SizedBox(
                            width: _videoPlayerController.value.size.width,
                            height: _videoPlayerController.value.size.height,
                            child: VideoPlayer(_videoPlayerController))
                        : AspectRatio(
                            aspectRatio:
                                _videoPlayerController.value.aspectRatio,
                            child: VideoPlayer(_videoPlayerController)),
          ),

          // ── Layer 2: Gradient ────────────────────────────────
          if (!_controlsLocked && _showControls)
            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.8)
                    ],
                    stops: const [0.0, 0.3, 0.7, 1.0],
                  ),
                ),
              ),
            ),

          // ── Layer 3: Touch Zones ─────────────────────────────
          Row(
            children: [
              // Left half
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    if (!_controlsLocked) {
                      if (_showBrightnessOverlay || _showVolumeOverlay) {
                        setState(() {
                          _showBrightnessOverlay = false;
                          _showVolumeOverlay = false;
                        });
                        _brightnessTimer?.cancel();
                        _volumeTimer?.cancel();
                      }
                      _toggleControls();
                    }
                  },
                  onDoubleTap: !_controlsLocked ? _seekBackward : null,
                  onLongPressStart: (d) => _onLongPressStart(d, 'left'),
                  onLongPressMoveUpdate: (d) =>
                      _onLongPressMoveUpdate(d, screenSize),
                  onLongPressEnd: _onLongPressEnd,
                  onVerticalDragUpdate: (d) =>
                      _handleVerticalDragLeft(d, screenSize),
                  onHorizontalDragStart: !_controlsLocked
                      ? (d) {
                          _dragStartPosition = d.globalPosition.dx;
                        }
                      : null,
                  onHorizontalDragUpdate: (d) =>
                      _handleHorizontalDragSeek(d, screenSize),
                  onHorizontalDragEnd: !_controlsLocked
                      ? (d) {
                          if (_seekPreviewPosition != null)
                            _videoPlayerController
                                .seekTo(_seekPreviewPosition!);
                          setState(() {
                            _dragStartPosition = null;
                            _isDraggingSeeking = false;
                            _seekPreviewPosition = null;
                          });
                          if (_showControls) _startHideControlsTimer();
                        }
                      : null,
                  child: Container(
                    color: Colors.transparent,
                    child: AnimatedOpacity(
                      opacity: _showBackwardOverlay ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        decoration: BoxDecoration(
                            gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                              Colors.black.withOpacity(0.6),
                              Colors.transparent
                            ])),
                        child: Center(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                              const Icon(Icons.fast_rewind_rounded,
                                  color: Colors.white, size: 50),
                              const SizedBox(height: 8),
                              Text('« $_seekSeconds seconds',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold))
                            ])),
                      ),
                    ),
                  ),
                ),
              ),
              // Right half
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    if (!_controlsLocked) {
                      if (_showBrightnessOverlay || _showVolumeOverlay) {
                        setState(() {
                          _showBrightnessOverlay = false;
                          _showVolumeOverlay = false;
                        });
                        _brightnessTimer?.cancel();
                        _volumeTimer?.cancel();
                      }
                      _toggleControls();
                    }
                  },
                  onDoubleTap: !_controlsLocked ? _seekForward : null,
                  onLongPressStart: (d) => _onLongPressStart(d, 'right'),
                  onLongPressMoveUpdate: (d) =>
                      _onLongPressMoveUpdate(d, screenSize),
                  onLongPressEnd: _onLongPressEnd,
                  onVerticalDragUpdate: (d) =>
                      _handleVerticalDragRight(d, screenSize),
                  onHorizontalDragStart: !_controlsLocked
                      ? (d) {
                          _dragStartPosition = d.globalPosition.dx;
                        }
                      : null,
                  onHorizontalDragUpdate: (d) =>
                      _handleHorizontalDragSeek(d, screenSize),
                  onHorizontalDragEnd: !_controlsLocked
                      ? (d) {
                          if (_seekPreviewPosition != null)
                            _videoPlayerController
                                .seekTo(_seekPreviewPosition!);
                          setState(() {
                            _dragStartPosition = null;
                            _isDraggingSeeking = false;
                            _seekPreviewPosition = null;
                          });
                          if (_showControls) _startHideControlsTimer();
                        }
                      : null,
                  child: Container(
                    color: Colors.transparent,
                    child: AnimatedOpacity(
                      opacity: _showForwardOverlay ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        decoration: BoxDecoration(
                            gradient: LinearGradient(
                                begin: Alignment.centerRight,
                                end: Alignment.centerLeft,
                                colors: [
                              Colors.black.withOpacity(0.6),
                              Colors.transparent
                            ])),
                        child: Center(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                              const Icon(Icons.fast_forward_rounded,
                                  color: Colors.white, size: 50),
                              const SizedBox(height: 8),
                              Text('$_seekSeconds seconds »',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold))
                            ])),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ── Brightness Overlay ───────────────────────────────
          if (_showBrightnessOverlay)
            Positioned(
              left: 40,
              top: isPortrait
                  ? (screenSize.height / 2) - 70
                  : (screenSize.height / 2) - 105,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: isPortrait
                      ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
                      : const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.2), width: 1)),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.brightness_6,
                        color: Colors.yellow, size: isPortrait ? 24 : 28),
                    SizedBox(height: isPortrait ? 8 : 10),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragStart: (_) => _brightnessTimer?.cancel(),
                      onVerticalDragUpdate: (d) {
                        final h = isPortrait ? 70.0 : 100.0;
                        double v = 1.0 - (d.localPosition.dy.clamp(0.0, h) / h);
                        v = (v * 50).round() / 50.0;
                        setState(() => _currentBrightness = v.clamp(0.0, 1.0));
                        ScreenBrightness()
                            .setScreenBrightness(_currentBrightness);
                      },
                      onVerticalDragEnd: (_) {
                        _brightnessTimer =
                            Timer(const Duration(seconds: 5), () {
                          if (mounted)
                            setState(() => _showBrightnessOverlay = false);
                        });
                      },
                      child: Container(
                        color: Colors.transparent,
                        height: isPortrait ? 70.0 : 100.0,
                        width: 40.0,
                        alignment: Alignment.center,
                        child: SizedBox(
                            width: 6,
                            child: Stack(
                                alignment: Alignment.bottomCenter,
                                children: [
                                  Container(
                                      decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(3),
                                          color: Colors.white12)),
                                  FractionallySizedBox(
                                      heightFactor: _currentBrightness,
                                      child: Container(
                                          decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(3),
                                              gradient: LinearGradient(
                                                  begin: Alignment.bottomCenter,
                                                  end: Alignment.topCenter,
                                                  colors: [
                                                    Colors.yellow.shade700,
                                                    Colors.yellow.shade300
                                                  ])))),
                                ])),
                      ),
                    ),
                    SizedBox(height: isPortrait ? 8 : 10),
                    SizedBox(
                        width: 36,
                        child: Text('${(_currentBrightness * 100).toInt()}%',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white,
                                fontSize:
                                    (_currentBrightness * 100).toInt() >= 100
                                        ? (isPortrait ? 11 : 13)
                                        : (isPortrait ? 12 : 14),
                                fontWeight: FontWeight.bold))),
                  ]),
                ),
              ),
            ),

          // ── Volume Overlay ───────────────────────────────────
          if (_showVolumeOverlay)
            Positioned(
              right: 40,
              top: isPortrait
                  ? (screenSize.height / 2) - 70
                  : (screenSize.height / 2) - 105,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: isPortrait
                      ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
                      : const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.2), width: 1)),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                        _currentVolume > 0.6
                            ? Icons.volume_up_rounded
                            : _currentVolume > 0.3
                                ? Icons.volume_down_rounded
                                : _currentVolume > 0
                                    ? Icons.volume_mute_rounded
                                    : Icons.volume_off_rounded,
                        color: Colors.blue.shade300,
                        size: isPortrait ? 24 : 28),
                    SizedBox(height: isPortrait ? 8 : 10),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragStart: (_) => _volumeTimer?.cancel(),
                      onVerticalDragUpdate: (d) {
                        final h = isPortrait ? 70.0 : 100.0;
                        double v = 1.0 - (d.localPosition.dy.clamp(0.0, h) / h);
                        v = (v * 50).round() / 50.0;
                        setState(() => _currentVolume = v.clamp(0.0, 1.0));
                        VolumeController.instance.setVolume(_currentVolume);
                      },
                      onVerticalDragEnd: (_) {
                        _volumeTimer = Timer(const Duration(seconds: 5), () {
                          if (mounted)
                            setState(() => _showVolumeOverlay = false);
                        });
                      },
                      child: Container(
                        color: Colors.transparent,
                        height: isPortrait ? 70.0 : 100.0,
                        width: 40.0,
                        alignment: Alignment.center,
                        child: SizedBox(
                            width: 6,
                            child: Stack(
                                alignment: Alignment.bottomCenter,
                                children: [
                                  Container(
                                      decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(3),
                                          color: Colors.white12)),
                                  FractionallySizedBox(
                                      heightFactor: _currentVolume,
                                      child: Container(
                                          decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(3),
                                              gradient: LinearGradient(
                                                  begin: Alignment.bottomCenter,
                                                  end: Alignment.topCenter,
                                                  colors: [
                                                    Colors.blue.shade700,
                                                    Colors.blue.shade300
                                                  ])))),
                                ])),
                      ),
                    ),
                    SizedBox(height: isPortrait ? 8 : 10),
                    SizedBox(
                        width: 36,
                        child: Text('${(_currentVolume * 100).toInt()}%',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: (_currentVolume * 100).toInt() >= 100
                                    ? (isPortrait ? 11 : 13)
                                    : (isPortrait ? 12 : 14),
                                fontWeight: FontWeight.bold))),
                  ]),
                ),
              ),
            ),

          // ── Seek Preview ─────────────────────────────────────
          if (_isDraggingSeeking && _seekPreviewPosition != null)
            Center(
                child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(_formatDuration(_seekPreviewPosition!),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
            )),

          // ── HOLD-TO-SEEK Speed Widget ─────────────────────────
          // Compact glassmorphism pill, all 9 speeds visible at once
          if (_showSpeedWidget && _isHolding)
            Positioned(
              top: 118, // Below the two-line top bar
              left: 0, right: 0,
              child: Center(
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.20), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.45),
                          blurRadius: 20,
                          spreadRadius: 2)
                    ],
                  ),
                  // Intrinsic width — fits all pills
                  child: IntrinsicWidth(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Stack(
                        children: [
                          // Glass shimmer
                          Positioned.fill(
                              child: Container(
                                  decoration: BoxDecoration(
                            gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withOpacity(0.10),
                                  Colors.white.withOpacity(0.02)
                                ]),
                            borderRadius: BorderRadius.circular(32),
                          ))),
                          // Pills row
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children:
                                List.generate(_speedBreakpoints.length, (i) {
                              final speed = _speedBreakpoints[i];
                              final isSel = i == _activeSpeedIndex;
                              final isCurrent = speed == _currentSpeed;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 3, vertical: 10),
                                padding: EdgeInsets.symmetric(
                                    horizontal: isSel ? 12 : 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? Colors.white.withOpacity(0.92)
                                      : isCurrent
                                          ? Colors.white.withOpacity(0.18)
                                          : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSel
                                        ? Colors.white
                                        : isCurrent
                                            ? Colors.white.withOpacity(0.5)
                                            : Colors.white.withOpacity(0.15),
                                    width: isSel ? 1.5 : 1,
                                  ),
                                ),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Dot
                                      AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 150),
                                        width: isSel ? 5 : 3,
                                        height: isSel ? 5 : 3,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isSel
                                              ? Colors.black87
                                              : Colors.white.withOpacity(0.4),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        _formatSpeed(speed),
                                        style: TextStyle(
                                          color: isSel
                                              ? Colors.black87
                                              : Colors.white.withOpacity(
                                                  isCurrent ? 0.9 : 0.65),
                                          fontSize: isSel ? 12 : 11,
                                          fontWeight: isSel
                                              ? FontWeight.bold
                                              : isCurrent
                                                  ? FontWeight.w600
                                                  : FontWeight.w400,
                                        ),
                                      ),
                                    ]),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // ── Lock Button ──────────────────────────────────────
          if (_controlsLocked)
            Positioned(
              top: 50,
              right: 20,
              child: GestureDetector(
                onTap: _toggleLock,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(30)),
                  child: const Icon(Icons.lock, color: Colors.white, size: 28),
                ),
              ),
            ),

          // ── Controls (dimmed during hold or brightness/volume) ─
          if (!_controlsLocked && _showControls)
            AnimatedOpacity(
              opacity: _isHolding
                  ? 0.15
                  : (_showBrightnessOverlay || _showVolumeOverlay)
                      ? 0.15
                      : 1.0,
              duration: const Duration(milliseconds: 300),
              child: _buildControlButtons(),
            ),
        ],
      ),
    );
  }

  Widget _buildControlButtons() {
    return SafeArea(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ── Top Bar ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 8, right: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Line 1: Back, Title, Menu
                Row(children: [
                  IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context)),
                  Expanded(
                      child: Text(
                          widget.videoList[_currentIndex].title ?? 'Video',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis)),
                  IconButton(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      onPressed: () {}),
                ]),
                // Line 2: Rotation + speed indicator
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 2),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      icon: Icon(
                          _isLandscape
                              ? Icons.screen_rotation_rounded
                              : Icons.stay_current_portrait_rounded,
                          color: Colors.white.withOpacity(0.7),
                          size: 19),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _toggleOrientation();
                      },
                    ),
                    // Speed display (read-only, shows current persisted speed)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: _currentSpeed != 1.0
                            ? Colors.white.withOpacity(0.20)
                            : Colors.white.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _currentSpeed != 1.0
                                ? Colors.white.withOpacity(0.6)
                                : Colors.white.withOpacity(0.25),
                            width: 1),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.speed_rounded,
                            color: Colors.white.withOpacity(0.7), size: 12),
                        const SizedBox(width: 4),
                        Text(_formatSpeed(_currentSpeed),
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ]),
                ),
              ],
            ),
          ),

          // ── Bottom Controls ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: AnimatedBuilder(
                  animation: _videoPlayerController,
                  builder: (context, _) {
                    final position = _videoPlayerController.value.position;
                    final duration = _videoPlayerController.value.duration;
                    final vp = position.inSeconds.toDouble();
                    final vd = duration.inSeconds > 0
                        ? duration.inSeconds.toDouble()
                        : 1.0;
                    return Column(children: [
                      SliderTheme(
                        data: SliderThemeData(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6),
                            overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 12)),
                        child: Slider(
                            value: vp.clamp(0.0, vd),
                            max: vd,
                            activeColor: Colors.red,
                            inactiveColor: Colors.white.withOpacity(0.3),
                            onChanged: (v) => _videoPlayerController
                                .seekTo(Duration(seconds: v.toInt()))),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_formatDuration(position),
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12)),
                              Text(_formatDuration(duration),
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12)),
                            ]),
                      ),
                    ]);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                          icon: const Icon(Icons.lock_open,
                              color: Colors.white, size: 28),
                          onPressed: _toggleLock),
                      IconButton(
                          icon: Icon(Icons.skip_previous_rounded,
                              color: _currentIndex > 0
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.3),
                              size: 36),
                          onPressed: _currentIndex > 0 ? _previousVideo : null),
                      Container(
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.2)),
                        child: IconButton(
                          icon: Icon(
                              _videoPlayerController.value.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 40),
                          onPressed: () {
                            setState(() {
                              if (_videoPlayerController.value.isPlaying) {
                                _chewieController.pause();
                                _hideControlsTimer?.cancel();
                              } else {
                                _chewieController.play();
                                _startHideControlsTimer();
                              }
                            });
                          },
                        ),
                      ),
                      IconButton(
                          icon: Icon(Icons.skip_next_rounded,
                              color: _currentIndex < widget.videoList.length - 1
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.3),
                              size: 36),
                          onPressed: _currentIndex < widget.videoList.length - 1
                              ? _nextVideo
                              : null),
                      IconButton(
                          icon: const Icon(Icons.aspect_ratio,
                              color: Colors.white, size: 28),
                          onPressed: _cycleAspectRatio),
                    ]),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
