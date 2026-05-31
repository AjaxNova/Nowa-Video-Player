import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:nova_videoplayer/functions/global_variables.dart';
import 'shorts_player_pool.dart';

class ShortsPlayerTile extends StatefulWidget {
  final int index;
  final Map<String, dynamic> videoData;
  final ShortsPlayerPool pool;

  const ShortsPlayerTile({
    super.key,
    required this.index,
    required this.videoData,
    required this.pool,
  });

  @override
  State<ShortsPlayerTile> createState() => _ShortsPlayerTileState();
}

class _ShortsPlayerTileState extends State<ShortsPlayerTile> {
  ShortsPoolSlot? _activeSlot;
  bool _isManuallyPaused = false;
  bool isTurboMode = false;

  @override
  void initState() {
    super.initState();
    _bindToSlot();
  }

  @override
  void didUpdateWidget(covariant ShortsPlayerTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != oldWidget.index || widget.pool != oldWidget.pool) {
      _unbindFromSlot();
      _bindToSlot();
    }
  }

  @override
  void dispose() {
    _unbindFromSlot();
    super.dispose();
  }

  void _bindToSlot() {
    _activeSlot = widget.pool.getSlotForIndex(widget.index);
    if (_activeSlot != null) {
      _activeSlot!.onStateChanged = _onSlotStateChanged;
    }
  }

  void _unbindFromSlot() {
    if (_activeSlot != null && _activeSlot!.onStateChanged == _onSlotStateChanged) {
      _activeSlot!.onStateChanged = null;
    }
    _activeSlot = null;
  }

  void _onSlotStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dynamically retrieve the preloaded/active slot for this page tile's index
    final slot = widget.pool.getSlotForIndex(widget.index);
    final hasFirstFrame = slot?.hasFirstFrame ?? false;
    final isPlayerReady = slot?.isReady ?? false;
    final error = slot?.error;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPressStart: (details) {
        if (slot != null) {
          final screenWidth = MediaQuery.of(context).size.width;
          if (details.localPosition.dx > screenWidth / 2) {
            slot.player.setRate(2.0);
            setState(() => isTurboMode = true);
          }
        }
      },
      onLongPressEnd: (details) {
        if (slot != null) {
          slot.player.setRate(1.0);
          setState(() => isTurboMode = false);
        }
      },
      onTap: () {
        if (slot != null) {
          setState(() {
            if (slot.player.state.playing) {
              slot.player.pause();
              _isManuallyPaused = true;
              isShortsPlaying.value = false;
            } else {
              slot.player.play();
              _isManuallyPaused = false;
              isShortsPlaying.value = true;
            }
          });
        }
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
                  // Video layer always underneath the overlay
                  if (slot != null && isPlayerReady)
                    Video(
                      controller: slot.controller,
                      controls: NoVideoControls,
                      fit: BoxFit.cover,
                    ),

                  // Precached high-speed CDN thumbnail + loading indicator overlay
                  AnimatedOpacity(
                    opacity: hasFirstFrame ? 0.0 : 1.0,
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
                        if (!isPlayerReady && error == null)
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

                  // Friendly connection/error recovery layout overlay
                  if (error != null)
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
                                error,
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
                                  // Re-initiate stream resolution on retry command
                                  widget.pool.updateActiveIndex(widget.index, [widget.videoData]);
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

            if (_isManuallyPaused && slot != null && !slot.player.state.playing && !isTurboMode)
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
