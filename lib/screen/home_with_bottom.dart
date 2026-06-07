import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:nova_videoplayer/functions/global_variables.dart';
import 'package:nova_videoplayer/screen/all_videos.dart';
import 'package:nova_videoplayer/screen/folder_page.dart';
import 'package:nova_videoplayer/screen/live_shorts/live_shorts_screen.dart';
import 'package:nova_videoplayer/screen/media_kit_video_player_page.dart';
import 'package:nova_videoplayer/screen/newPlaylistPage/fav_and_playlist_select_page.dart';
import 'package:nova_videoplayer/screen/newPlaylistPage/shorts_page/shorts_try_two.dart';
import 'package:nova_videoplayer/screen/live_shorts/shorts_container_screen.dart';
import 'package:nova_videoplayer/functions/file_operations.dart';
import 'package:photo_manager/photo_manager.dart';
import '../settings/settings_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.assets, required this.foldersWithVideos});
  final List<AssetPathEntity> foldersWithVideos;
  final List<AssetEntity> assets;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late List<Widget> _children;

  @override
  void initState() {
    super.initState();
    homeTabNotifier.addListener(() {
      setState(() {
        _currentIndex = homeTabNotifier.value;
        isShortsTabActive.value = (_currentIndex == 2);
      });
    });
    _children = [
      AllVideosPage(assets: widget.assets, foldersWithVideos: widget.foldersWithVideos),
      FolderPage(foldersWithVideos: widget.foldersWithVideos),
      const ShortsContainerScreen(),
      const PlaylistOrFavorite(),
      const SettingsScreen(),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      FileOperations.requestManageStoragePermission(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isShorts = _currentIndex == 2;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _children,
          ),
          _buildMorphingNavBar(isShorts),
          _buildPiPOverlay(),
          _buildMainPiPOverlay(),
        ],
      ),
    );
  }

  Widget _buildPiPOverlay() {
    return ValueListenableBuilder<bool>(
      valueListenable: isShortsPiPMode,
      builder: (context, isPiP, child) {
        if (!isPiP) return const SizedBox.shrink();
        return const PiPOverlayWidget();
      },
    );
  }

  Widget _buildMainPiPOverlay() {
    return ValueListenableBuilder<bool>(
      valueListenable: isMainPiPMode,
      builder: (context, isPiP, child) {
        if (!isPiP) return const SizedBox.shrink();
        return const MainPiPOverlayWidget();
      },
    );
  }

  Widget _buildMorphingNavBar(bool isShorts) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 350),
      curve: Curves.fastOutSlowIn,
      left: isShorts ? 0 : 16.w,
      right: isShorts ? 0 : 16.w,
      bottom: isShorts ? 0 : 20.h,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.fastOutSlowIn,
        height: isShorts ? 68.h : 58.h,
        padding: EdgeInsets.only(bottom: isShorts ? 8.h : 0),
        decoration: BoxDecoration(
          color: isShorts 
              ? Colors.black.withValues(alpha: 0.85) 
              : const Color(0xFF1A1A1A).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(isShorts ? 0 : 24.r),
          border: Border.all(
            color: isShorts ? Colors.transparent : Colors.white.withValues(alpha: 0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isShorts ? 0 : 0.5),
              blurRadius: isShorts ? 0 : 15,
              offset: Offset(0, isShorts ? 0 : 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isShorts) const ShortsProgressBar(),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _navItem(0, Icons.video_library_rounded, 'Videos', isShorts),
                  _navItem(1, Icons.folder_rounded, 'Folders', isShorts),
                  _navItem(2, Icons.tiktok_rounded, 'Shorts', isShorts, isHero: true),
                  _navItem(3, Icons.playlist_play_rounded, 'Library', isShorts),
                  _navItem(4, Icons.settings_rounded, 'Settings', isShorts),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label, bool isShorts, {bool isHero = false}) {
    final bool isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        if (_currentIndex == 2 && index == 2) {
          // They are already on the Shorts tab and tapped it again -> Trigger PiP!
          setState(() {
            isShortsPiPMode.value = true;
            _currentIndex = 0; // Send them to the main Videos tab
            homeTabNotifier.value = 0;
            isShortsTabActive.value = false;
          });
          return;
        }

        if (index == 2) {
          // Returning to full screen shorts, kill PiP
          isShortsPiPMode.value = false;
        }

        setState(() {
          _currentIndex = index;
          homeTabNotifier.value = index;
          isShortsTabActive.value = (_currentIndex == 2);
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 60.w,
        padding: EdgeInsets.symmetric(vertical: 4.h),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? colorGreen : Colors.white30,
              size: (isHero && !isShorts) ? 22.sp : 19.sp, 
            ),
            SizedBox(height: 2.h),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? colorGreen : Colors.white24,
                fontSize: 8.sp,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (isSelected && !isShorts)
              Container(
                margin: EdgeInsets.only(top: 2.h),
                height: 2.h,
                width: 4.w,
                decoration: BoxDecoration(
                  color: colorGreen,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ShortsProgressBar extends StatefulWidget {
  const ShortsProgressBar({super.key});
  @override
  State<ShortsProgressBar> createState() => _ShortsProgressBarState();
}

class _ShortsProgressBarState extends State<ShortsProgressBar> {
  double? _dragProgress;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isShortsScrolling,
      builder: (context, isScrolling, _) {
        return AnimatedOpacity(
          opacity: isScrolling ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: ValueListenableBuilder<Player?>(
            valueListenable: activeShortsPlayer,
            builder: (context, player, _) {
              if (player == null) return const SizedBox(height: 2);

              return StreamBuilder<Duration>(
                stream: player.stream.position,
                builder: (context, _) {
                  // Read directly from state — no lag
                  final durMs = player.state.duration.inMilliseconds;
                  final posMs = player.state.position.inMilliseconds;
                  final playbackProgress = durMs > 0 ? (posMs / durMs).clamp(0.0, 1.0) : 0.0;
                  final progress = _dragProgress ?? playbackProgress;

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart: (d) {
                      setState(() {
                        _isDragging = true;
                        _dragProgress = (d.localPosition.dx / MediaQuery.of(context).size.width).clamp(0.0, 1.0);
                      });
                    },
                    onHorizontalDragUpdate: (d) {
                      setState(() {
                        _dragProgress = (d.localPosition.dx / MediaQuery.of(context).size.width).clamp(0.0, 1.0);
                      });
                    },
                    onHorizontalDragEnd: (_) {
                      if (_dragProgress != null && durMs > 0) {
                        player.seek(Duration(milliseconds: (durMs * _dragProgress!).toInt()));
                      }
                      setState(() { _isDragging = false; _dragProgress = null; });
                    },
                    onHorizontalDragCancel: () {
                      setState(() { _isDragging = false; _dragProgress = null; });
                    },
                    onTapDown: (d) {
                      if (durMs > 0) {
                        final pct = (d.localPosition.dx / MediaQuery.of(context).size.width).clamp(0.0, 1.0);
                        player.seek(Duration(milliseconds: (durMs * pct).toInt()));
                      }
                    },
                    child: SizedBox(
                      height: _isDragging ? 20 : 10, // taller hit area when dragging
                      width: double.infinity,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: SizedBox(
                          height: _isDragging ? 3 : 2,
                          child: Stack(
                            children: [
                              // Track
                              Container(color: Colors.white12),
                              // Fill — NO AnimatedContainer, zero duration = no lag
                              FractionallySizedBox(
                                widthFactor: progress,
                                child: Container(color: colorGreen),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class PiPOverlayWidget extends StatefulWidget {
  const PiPOverlayWidget({super.key});

  @override
  State<PiPOverlayWidget> createState() => _PiPOverlayWidgetState();
}

class _PiPOverlayWidgetState extends State<PiPOverlayWidget> {
  double _width = 140.w;
  double _height = 240.h;
  double _top = 100.h;
  double _left = 200.w;
  
  double _baseWidth = 140.w;
  double _baseHeight = 240.h;

  bool _showControls = false;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: _top,
      left: _left,
      child: GestureDetector(
        onScaleStart: (details) {
          _baseWidth = _width;
          _baseHeight = _height;
        },
        onScaleUpdate: (details) {
          setState(() {
            // Dragging (Panning)
            _top += details.focalPointDelta.dy;
            _left += details.focalPointDelta.dx;

            // Pinch-to-Zoom (Strict YouTube-style limits)
            if (details.scale != 1.0) {
              _width = (_baseWidth * details.scale).clamp(100.w, 320.w);
              _height = (_baseHeight * details.scale).clamp(170.h, 550.h);
            }
          });
        },
        onTap: () {
          setState(() {
            _showControls = !_showControls;
          });
        },
        child: ValueListenableBuilder<Player?>(
          valueListenable: activeShortsPlayer,
          builder: (context, player, child) {
            return ValueListenableBuilder<VideoController?>(
              valueListenable: activeShortsVideoController,
              builder: (context, videoController, child) {
                return Container(
                  width: _width,
                  height: _height,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12.r),
                    boxShadow: const [
                      BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 5)),
                    ],
                    border: Border.all(color: Colors.white24, width: 1),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ValueListenableBuilder<bool>(
                        valueListenable: isShortsPiPError,
                        builder: (context, hasError, child) {
                          if (hasError) {
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.broken_image_rounded, color: Colors.white24, size: 32.sp),
                                  SizedBox(height: 8.h),
                                  Text("Error", style: TextStyle(color: Colors.white30, fontSize: 10.sp)),
                                ],
                              ),
                            );
                          }
                          if (player == null || videoController == null) {
                            return const Center(child: CircularProgressIndicator(color: Colors.white24));
                          }
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(10.r),
                            child: StreamBuilder<int?>(
                              stream: player.stream.width,
                              builder: (context, snapshot) {
                                final width = player.state.width ?? 1920;
                                final height = player.state.height ?? 1080;
                                final aspect = width > 0 && height > 0 ? width / height : 9/16;
                                return AspectRatio(
                                  aspectRatio: aspect,
                                  child: Video(controller: videoController, controls: NoVideoControls, key: ValueKey(videoController.hashCode)),
                                );
                              }
                            ),
                          );
                        },
                      ),
                  if (_showControls)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        setState(() {
                          _showControls = false;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Stack(
                          children: [
                            // Top Right: Close
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () {
                                  isShortsPiPMode.value = false;
                                  player?.pause();
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                            // Top Left: Expand
                            Positioned(
                              top: 4,
                              left: 4,
                              child: GestureDetector(
                                onTap: () {
                                  isShortsPiPMode.value = false;
                                  homeTabNotifier.value = 2; // Return to full Shorts tab
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                                  child: const Icon(Icons.open_in_full_rounded, color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                            // Center: Media Controls
                            Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      pipActionTrigger.value = 2; // Prev
                                    },
                                    child: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 28),
                                  ),
                                  if (player != null)
                                    GestureDetector(
                                      onTap: () {
                                        player.state.playing ? player.pause() : player.play();
                                      },
                                      child: StreamBuilder<bool>(
                                        stream: player.stream.playing,
                                        builder: (context, snapshot) {
                                          final isPlaying = player.state.playing;
                                          return Icon(
                                            isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                                            color: Colors.white,
                                            size: 44,
                                          );
                                        },
                                      ),
                                    )
                                  else
                                    const Icon(Icons.play_circle_fill_rounded, color: Colors.white38, size: 44),
                                  GestureDetector(
                                    onTap: () {
                                      pipActionTrigger.value = 1; // Next
                                    },
                                    child: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 28),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    ),
    ),
    );
  }
}

class MainPiPOverlayWidget extends StatefulWidget {
  const MainPiPOverlayWidget({super.key});

  @override
  State<MainPiPOverlayWidget> createState() => _MainPiPOverlayWidgetState();
}

class _MainPiPOverlayWidgetState extends State<MainPiPOverlayWidget> {
  double _width = 180.w;
  double _height = 320.h; // MediaKit handles aspect ratio internally, but we can start with a generic size
  double _top = 100.h;
  double _left = 20.w;

  bool _showControls = false;
  double _baseWidth = 180.w;
  double _baseHeight = 320.h;

  @override
  void initState() {
    super.initState();
    // Try to match the aspect ratio if available
    final player = activeMainPlayer.value;
    if (player != null && player.state.width != null && player.state.height != null) {
      final ar = player.state.width! / player.state.height!;
      _height = _width / ar;
    }
  }

  Future<void> _playNext() async {
    final list = mainPiPVideoList.value;
    if (mainPiPVideoIndex.value < list.length - 1) {
      mainPiPVideoIndex.value++;
      final file = await list[mainPiPVideoIndex.value].file;
      if (file != null) {
        activeMainPlayer.value?.open(Media(file.path));
      }
    }
  }

  Future<void> _playPrev() async {
    final list = mainPiPVideoList.value;
    if (mainPiPVideoIndex.value > 0) {
      mainPiPVideoIndex.value--;
      final file = await list[mainPiPVideoIndex.value].file;
      if (file != null) {
        activeMainPlayer.value?.open(Media(file.path));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoController?>(
      valueListenable: activeMainVideoController,
      builder: (context, controller, child) {
        if (controller == null || activeMainPlayer.value == null) return const SizedBox.shrink();

        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;

        return Positioned(
          top: _top,
          left: _left,
          child: GestureDetector(
            onScaleStart: (details) {
              _baseWidth = _width;
              _baseHeight = _height;
            },
            onScaleUpdate: (details) {
              setState(() {
                // Dragging (Panning)
                _top += details.focalPointDelta.dy;
                _left += details.focalPointDelta.dx;

                // Pinch-to-Zoom
                if (details.scale != 1.0) {
                  _width = (_baseWidth * details.scale).clamp(100.w, screenWidth);
                  _height = (_baseHeight * details.scale).clamp(100.w, screenHeight);
                }

                _top = _top.clamp(0.0, screenHeight - _height - 80.h);
                _left = _left.clamp(0.0, screenWidth - _width);
              });
            },
            onTap: () {
              setState(() {
                _showControls = !_showControls;
              });
            },
            child: Container(
              width: _width,
              height: _height,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(10.r),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 5)),
                ],
                border: Border.all(color: Colors.white24, width: 1),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10.r),
                    child: Video(
                      controller: controller,
                      controls: NoVideoControls,
                    ),
                  ),
                  if (_showControls)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        setState(() {
                          _showControls = false;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Stack(
                          children: [
                            // Top Right: Close
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () {
                                  isMainPiPMode.value = false;
                                  activeMainPlayer.value?.pause();
                                  activeMainPlayer.value?.dispose();
                                  activeMainPlayer.value = null;
                                  activeMainVideoController.value = null;
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                            // Top Left: Expand
                            Positioned(
                              top: 4,
                              left: 4,
                              child: GestureDetector(
                                onTap: () {
                                  isMainPiPMode.value = false;
                                  // Push the full screen player and resume!
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => MediaKitVideoPlayerPage(
                                        videoList: mainPiPVideoList.value,
                                        initialIndex: mainPiPVideoIndex.value,
                                        resumeFromPiP: true,
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                                  child: const Icon(Icons.open_in_full_rounded, color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                            // Center: Media Controls
                            Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  GestureDetector(
                                    onTap: _playPrev,
                                    child: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 28),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      final p = activeMainPlayer.value!;
                                      p.state.playing ? p.pause() : p.play();
                                      setState((){}); // refresh icon
                                    },
                                    child: StreamBuilder<bool>(
                                      stream: activeMainPlayer.value!.stream.playing,
                                      initialData: activeMainPlayer.value!.state.playing,
                                      builder: (context, snapshot) {
                                        final isPlaying = snapshot.data ?? false;
                                        return Icon(
                                          isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                                          color: Colors.white,
                                          size: 44,
                                        );
                                      },
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: _playNext,
                                    child: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 28),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

