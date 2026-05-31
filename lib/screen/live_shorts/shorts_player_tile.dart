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
  bool isTurboMode = false;

  @override
  Widget build(BuildContext context) {
    // 1. Query the pool for the slot assigned to this tile's index
    final slot = widget.pool.getSlotForIndex(widget.index);

    if (slot == null) {
      // If no slot is assigned yet, render the static cached thumbnail + spinner
      return _buildThumbnailOnly(isPlayerReady: false, error: null);
    }

    // 2. Wrap layout in AnimatedBuilder listening to the slot's ChangeNotifier
    return AnimatedBuilder(
      animation: slot,
      builder: (context, _) {
        final hasFirstFrame = slot.hasFirstFrame;
        final isPlayerReady = slot.isReady;
        final error = slot.error;

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onLongPressStart: (details) {
            final screenWidth = MediaQuery.of(context).size.width;
            if (details.localPosition.dx > screenWidth / 2) {
              slot.player.setRate(2.0);
              setState(() => isTurboMode = true);
            }
          },
          onLongPressEnd: (details) {
            slot.player.setRate(1.0);
            setState(() => isTurboMode = false);
          },
          onTap: () {
            // Coordinate manual pause state with pool-wide lock
            if (slot.player.state.playing) {
              widget.pool.setUserPaused(true);
            } else {
              widget.pool.setUserPaused(false);
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
                      // Video always underneath
                      if (isPlayerReady)
                        Video(
                          controller: slot.controller,
                          controls: NoVideoControls,
                          fit: BoxFit.cover,
                        ),

                      // Thumbnail + spinner fades OUT only when the first frame renders
                      AnimatedOpacity(
                        opacity: hasFirstFrame ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 180),
                        child: _buildThumbnailOnly(isPlayerReady: isPlayerReady, error: error),
                      ),

                      // Retry Overlay if error occurs
                      if (error != null)
                        _buildErrorOverlay(error),
                    ],
                  ),
                ),

                if (isTurboMode)
                  _buildTurboIndicator(),

                // Centered Play/Pause visual feedback
                if (widget.pool.userPaused && !slot.player.state.playing && !isTurboMode)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow_rounded, size: 52, color: Colors.white70),
                    ),
                  ),

                _buildTitleOverlay(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildThumbnailOnly({required bool isPlayerReady, required String? error}) {
    return Stack(
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
    );
  }

  Widget _buildErrorOverlay(String errorText) {
    return Container(
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
                errorText,
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
                  widget.pool.updateActiveIndex(widget.index, [widget.videoData]);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTurboIndicator() {
    return Positioned(
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
    );
  }

  Widget _buildTitleOverlay() {
    return Positioned(
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
    );
  }
}
