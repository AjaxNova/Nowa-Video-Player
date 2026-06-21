import 'package:flutter/widgets.dart';
import 'shorts_playback_engine.dart';

class ShortsSnapController {
  final ShortsPlaybackEngine engine;
  int _lastPreloadedDirectionIndex = -1;

  ShortsSnapController({required this.engine});

  /// Tracks dragging displacements. If the user drags >= 30% of the viewport height
  /// towards the next or previous video, we predictively prepare that item.
  void onScrollUpdate(ScrollNotification notification, int currentIndex) {
    if (notification.metrics.axis != Axis.vertical) return;
    
    final double pixels = notification.metrics.pixels;
    final double viewportHeight = notification.metrics.viewportDimension;
    if (viewportHeight <= 0) return;

    // Calculate fractional page displacement: e.g., 0.3 means we dragged 30% towards next page
    final double currentPageFloat = pixels / viewportHeight;
    final double delta = currentPageFloat - currentIndex;

    // If drag progress passes 30% (0.3) in the positive (scrolling down to next video)
    if (delta >= 0.30) {
      final targetIndex = currentIndex + 1;
      if (targetIndex != _lastPreloadedDirectionIndex) {
        _lastPreloadedDirectionIndex = targetIndex;
        if (targetIndex < engine.videos.length) {
          engine.prepare(engine.videos[targetIndex].id);
        }
      }
    } 
    // If drag progress passes 30% (-0.3) in the negative (scrolling up to previous video)
    else if (delta <= -0.30) {
      final targetIndex = currentIndex - 1;
      if (targetIndex != _lastPreloadedDirectionIndex) {
        _lastPreloadedDirectionIndex = targetIndex;
        if (targetIndex >= 0) {
          engine.prepare(engine.videos[targetIndex].id);
        }
      }
    }
  }

  /// Resets direction memory when the page snapping completes and active page settles
  void onPageSettled(int settledIndex) {
    _lastPreloadedDirectionIndex = -1;
    engine.updateActiveIndex(settledIndex);
  }
}
