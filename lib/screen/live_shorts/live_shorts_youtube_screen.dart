import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/gestures.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:nova_videoplayer/functions/global_variables.dart';
import 'package:nova_videoplayer/functions/app_logger.dart';
import 'shorts_feed_controller.dart';

class YoutubeShortsFeedScreen extends StatefulWidget {
  const YoutubeShortsFeedScreen({super.key});

  @override
  State<YoutubeShortsFeedScreen> createState() => _YoutubeShortsFeedScreenState();
}

class _YoutubeShortsFeedScreenState extends State<YoutubeShortsFeedScreen> {
  late final ShortsFeedController _controller;
  int _pendingSettledIndex = 0;
  bool _showSortOverlay = false;
  String _sortOverlayLabel = '';

  @override
  void initState() {
    super.initState();
    _controller = ShortsFeedController();
    _controller.addListener(_onControllerChanged);
    isLiveShortsTabActive.addListener(_onTabActiveChanged);
  }

  @override
  void dispose() {
    isLiveShortsTabActive.removeListener(_onTabActiveChanged);
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTabActiveChanged() {
    if (mounted) setState(() {});
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _showSortOptionsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 32.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 36.w, height: 3.5.h,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(2.r))),
              SizedBox(height: 16.h),
              _buildSortOptionItem(title: "Default", icon: Icons.auto_awesome_rounded, value: "Default"),
              _buildSortOptionItem(title: "Newest First", icon: Icons.arrow_downward_rounded, value: "Newest"),
              _buildSortOptionItem(title: "Oldest First", icon: Icons.arrow_upward_rounded, value: "Oldest"),
              _buildSortOptionItem(title: "Shortest First", icon: Icons.hourglass_top_rounded, value: "Shortest"),
              _buildSortOptionItem(title: "Longest First", icon: Icons.hourglass_bottom_rounded, value: "Longest"),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortOptionItem({required String title, required IconData icon, required String value}) {
    final isSelected = _controller.currentSort == value;
    return ListTile(
      leading: Icon(icon, color: isSelected ? colorGreen : Colors.white54, size: 20.sp),
      title: Text(title, style: TextStyle(color: isSelected ? colorGreen : Colors.white70, fontSize: 13.sp)),
      trailing: isSelected ? Icon(Icons.check_rounded, color: colorGreen, size: 18.sp) : null,
      onTap: () async {
        Navigator.pop(context);
        setState(() { _sortOverlayLabel = title; _showSortOverlay = true; });
        await Future.delayed(const Duration(milliseconds: 120));
        await _controller.setSort(value);
        await Future.delayed(const Duration(milliseconds: 700));
        if (mounted) setState(() => _showSortOverlay = false);
      },
    );
  }

  Widget _buildActionButtons() {
    return Positioned(
      right: 12.w,
      bottom: 80.h,
      child: Column(
        children: [
          // Play/pause
          ValueListenableBuilder<bool>(
            valueListenable: isLiveShortsTabActive,
            builder: (context, active, _) {
              return IconButton(
                icon: Icon(active ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white, size: 28.sp),
                onPressed: () => isLiveShortsTabActive.value = !isLiveShortsTabActive.value,
              );
            },
          ),
          SizedBox(height: 16.h),
          // Sort
          Container(
            decoration: BoxDecoration(
              color: _controller.currentSort == 'Default'
                  ? Colors.black45
                  : colorGreen.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: _controller.currentSort == 'Default'
                    ? Colors.white10
                    : colorGreen.withValues(alpha: 0.5),
              ),
            ),
            child: IconButton(
              icon: Icon(Icons.tune_rounded,
                  color: _controller.currentSort == 'Default' ? Colors.white : colorGreen,
                  size: 24.sp),
              onPressed: _showSortOptionsBottomSheet,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !_showSortOverlay,
        child: Visibility(
          visible: _showSortOverlay,
          child: Container(
            color: Colors.black.withValues(alpha: 0.92),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(20.r),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                    border: Border.all(color: colorGreen.withValues(alpha: 0.3), width: 1),
                  ),
                  child: Icon(Icons.tune_rounded, color: colorGreen, size: 36.sp),
                ),
                SizedBox(height: 20.h),
                Text('Sorting by', style: TextStyle(color: Colors.white38, fontSize: 12.sp, letterSpacing: 1.2, fontWeight: FontWeight.w500)),
                SizedBox(height: 6.h),
                Text(_sortOverlayLabel, style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.w700)),
                SizedBox(height: 24.h),
                SizedBox(width: 24.w, height: 24.w,
                  child: CircularProgressIndicator(color: colorGreen, strokeWidth: 2)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final videos = _controller.videos;

    if (videos.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white24, strokeWidth: 1.5)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollStartNotification) {
                isShortsScrolling.value = true;
              } else if (notification is ScrollEndNotification) {
                isShortsScrolling.value = false;
                _controller.setFocusedIndex(_pendingSettledIndex);
              }
              return true;
            },
            child: PageView.builder(
              controller: _controller.pageController,
              scrollDirection: Axis.vertical,
              physics: const FastShortsPagePhysics(parent: ClampingScrollPhysics()),
              itemCount: videos.length,
              onPageChanged: (index) {
                _pendingSettledIndex = index;
                if (index >= videos.length - 5) {
                  prefetchYouTubeShorts(limit: 10, append: true);
                }
              },
              itemBuilder: (context, index) {
                return _YoutubeShortsTile(
                  videoData: videos[index],
                  isActive: index == _controller.focusedIndex,
                );
              },
            ),
          ),
          _buildActionButtons(),
          _buildSortOverlay(),
        ],
      ),
    );
  }
}

class _YoutubeShortsTile extends StatefulWidget {
  final Map<String, dynamic> videoData;
  final bool isActive;

  const _YoutubeShortsTile({
    required this.videoData,
    required this.isActive,
  });

  @override
  State<_YoutubeShortsTile> createState() => _YoutubeShortsTileState();
}

class _YoutubeShortsTileState extends State<_YoutubeShortsTile> {
  YoutubePlayerController? _ytController;
  bool _isReady = false;
  bool isTurboMode = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  @override
  void didUpdateWidget(_YoutubeShortsTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      if (widget.isActive) {
        _ytController?.play();
      } else {
        _ytController?.pause();
      }
    }
    if (oldWidget.videoData['id'] != widget.videoData['id']) {
      _ytController?.dispose();
      _ytController = null;
      _isReady = false;
      _initController();
    }
  }

  void _initController() {
    final videoId = widget.videoData['id'] as String?;
    if (videoId == null) return;

    _ytController = YoutubePlayerController(
      initialVideoId: videoId,
      flags: YoutubePlayerFlags(
        autoPlay: widget.isActive,
        mute: false,
        disableDragSeek: true,
        loop: true,
        hideControls: true,
        controlsVisibleAtStart: false,
        enableCaption: false,
      ),
    )..addListener(_onPlayerStateChanged);
  }

  void _onPlayerStateChanged() {
    if (_ytController?.value.isReady == true && !_isReady) {
      if (mounted) setState(() => _isReady = true);
    }
  }

  @override
  void dispose() {
    _ytController?.removeListener(_onPlayerStateChanged);
    _ytController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl = 'https://img.youtube.com/vi/${widget.videoData['id']}/hqdefault.jpg';

    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: {
        _StationaryLongPressRecognizer: GestureRecognizerFactoryWithHandlers<_StationaryLongPressRecognizer>(
          () => _StationaryLongPressRecognizer(),
          (instance) {
            instance.onLongPressStart = (details) {
              final screenWidth = MediaQuery.of(context).size.width;
              final screenHeight = MediaQuery.of(context).size.height;
              final inRightZone = details.localPosition.dx > screenWidth * 0.70;
              final inVerticalCentre = details.localPosition.dy > screenHeight * 0.30 &&
                                       details.localPosition.dy < screenHeight * 0.70;
              if (inRightZone && inVerticalCentre) {
                _ytController?.setPlaybackRate(2.0);
                setState(() => isTurboMode = true);
              }
            };
            instance.onLongPressEnd = (_) {
              _ytController?.setPlaybackRate(1.0);
              setState(() => isTurboMode = false);
            };
          },
        ),
        TapGestureRecognizer: GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
          () => TapGestureRecognizer(),
          (instance) {
            instance.onTap = () {
              if (_ytController?.value.isPlaying == true) {
                _ytController?.pause();
              } else {
                _ytController?.play();
              }
            };
          },
        ),
      },
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_ytController != null)
              YoutubePlayer(
                controller: _ytController!,
                showVideoProgressIndicator: false,
              ),

            AnimatedOpacity(
              opacity: _isReady ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 300),
              child: Image.network(
                thumbnailUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                gaplessPlayback: true,
                errorBuilder: (c, o, s) => Container(color: Colors.black87),
              ),
            ),

            if (!_isReady)
              Container(
                color: Colors.black38,
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 2),
                ),
              ),

            if (isTurboMode)
              Positioned(
                top: 48.h, left: 0, right: 0,
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

            Positioned(
              bottom: 30.h, left: 20.w, right: 80.w,
              child: Text(
                widget.videoData['title'] ?? 'Short Video',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  shadows: const [Shadow(blurRadius: 4, color: Colors.black)],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FastShortsPagePhysics extends PageScrollPhysics {
  const FastShortsPagePhysics({super.parent});

  @override
  FastShortsPagePhysics applyTo(ScrollPhysics? ancestor) {
    return FastShortsPagePhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => const SpringDescription(
    mass: 0.45,
    stiffness: 420,
    damping: 32,
  );
}

class _StationaryLongPressRecognizer extends LongPressGestureRecognizer {
  Offset? _downPosition;

  _StationaryLongPressRecognizer() : super(duration: const Duration(milliseconds: 500));

  @override
  void addPointer(PointerDownEvent event) {
    _downPosition = event.position;
    super.addPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (_downPosition != null && event is PointerMoveEvent) {
      final distance = (event.position - _downPosition!).distance;
      if (distance > 18.0) {
        resolve(GestureDisposition.rejected);
        _downPosition = null;
        return;
      }
    }
    super.handleEvent(event);
  }
}
