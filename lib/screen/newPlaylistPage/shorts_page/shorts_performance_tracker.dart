import '../../../functions/app_logger.dart';

class ShortsPerformanceTracker {
  static int _totalSwipes = 0;
  static int _preloadHits = 0;
  static int _preloadMisses = 0;
  
  static final List<int> _startupTimesMs = [];
  static final List<int> _firstFrameTimesMs = [];
  static final List<int> _reassignmentTimesMs = [];

  static DateTime? _lastSwipeTime;
  static final List<double> _scrollVelocities = []; // Swipes per second

  /// Record when a user initiates a swipe
  static void recordSwipe() {
    _totalSwipes++;
    final now = DateTime.now();
    if (_lastSwipeTime != null) {
      final diffSeconds = now.difference(_lastSwipeTime!).inMilliseconds / 1000.0;
      if (diffSeconds > 0) {
        final velocity = 1.0 / diffSeconds; // swipes per second
        _scrollVelocities.add(velocity);
      }
    }
    _lastSwipeTime = now;
  }

  /// Record a completed video play session (hits vs misses)
  static void recordPlaybackStart({
    required String videoId,
    required bool wasPreloaded,
    required int startupTimeMs,
  }) {
    if (wasPreloaded) {
      _preloadHits++;
    } else {
      _preloadMisses++;
    }
    _startupTimesMs.add(startupTimeMs);
    
    _logTelemetryReport();
  }

  /// Record time between preparing start and first frame decoded
  static void recordFirstFrameTime(String videoId, int firstFrameTimeMs) {
    _firstFrameTimesMs.add(firstFrameTimeMs);
  }

  /// Record player pool reassignment latency
  static void recordPlayerReassignment(int reassignmentTimeMs) {
    _reassignmentTimesMs.add(reassignmentTimeMs);
  }

  /// Outputs current telemetry stats to logs
  static void _logTelemetryReport() {
    final totalPlays = _preloadHits + _preloadMisses;
    final hitRate = totalPlays > 0 ? (_preloadHits / totalPlays) * 100 : 0.0;
    
    final avgStartup = _startupTimesMs.isEmpty 
        ? 0 
        : (_startupTimesMs.reduce((a, b) => a + b) / _startupTimesMs.length).round();
        
    final avgFirstFrame = _firstFrameTimesMs.isEmpty 
        ? 0 
        : (_firstFrameTimesMs.reduce((a, b) => a + b) / _firstFrameTimesMs.length).round();

    final avgVelocity = _scrollVelocities.isEmpty 
        ? 0.0 
        : _scrollVelocities.reduce((a, b) => a + b) / _scrollVelocities.length;

    AppLogger.log(
      'Shorts Telemetry | '
      'Total Swipes: $_totalSwipes | '
      'Hit Rate: ${hitRate.toStringAsFixed(1)}% ($_preloadHits/${_preloadHits + _preloadMisses}) | '
      'Avg Startup Time: ${avgStartup}ms | '
      'Avg First Frame Decoded: ${avgFirstFrame}ms | '
      'Avg Swipe Velocity: ${avgVelocity.toStringAsFixed(2)} swipes/sec'
    );
  }

  /// Resets all counters
  static void reset() {
    _totalSwipes = 0;
    _preloadHits = 0;
    _preloadMisses = 0;
    _startupTimesMs.clear();
    _firstFrameTimesMs.clear();
    _reassignmentTimesMs.clear();
    _scrollVelocities.clear();
    _lastSwipeTime = null;
  }
}
