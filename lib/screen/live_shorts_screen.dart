import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:nova_videoplayer/functions/global_variables.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;

class ShortsFeedScreen extends StatefulWidget {
  const ShortsFeedScreen({super.key});

  @override
  State<ShortsFeedScreen> createState() => _ShortsFeedScreenState();
}

class _ShortsFeedScreenState extends State<ShortsFeedScreen> {
  List<Map<String, dynamic>> _videos = [];
  bool _isLoading = true;
  String? _errorMessage;
  late PageController _pageController;
  int _focusedIndex = 0;
  
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  
  String _currentSort = 'Default';
  List<Map<String, dynamic>> _originalVideos = [];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    
    // Listen to changes in pre-fetched shorts list
    globalYouTubeShorts.addListener(_onGlobalShortsChanged);
    
    if (globalYouTubeShorts.value.isNotEmpty) {
      _videos = globalYouTubeShorts.value;
      _originalVideos = List.from(globalYouTubeShorts.value);
      _isLoading = false;
      prefetchYouTubeShorts(limit: 10, append: true);
    } else {
      _fetchShorts();
    }
  }

  void _onGlobalShortsChanged() {
    if (mounted) {
      setState(() {
        _videos = globalYouTubeShorts.value;
        if (_currentSort == 'Default') {
          _originalVideos = List.from(_videos);
        }
      });
    }
  }

  Future<void> _fetchShorts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    await prefetchYouTubeShorts(limit: 10);
    if (mounted) {
      setState(() {
        _videos = globalYouTubeShorts.value;
        _isLoading = globalYouTubeShorts.value.isEmpty; // stay loading if empty!
        _errorMessage = youtubeShortsError;
      });

    }
  }

  Future<void> _triggerNewSearch(String query) async {
    setState(() {
      _isSearching = false;
      _isLoading = true;
      _videos = [];
      _errorMessage = null;
      _focusedIndex = 0;
    });
    globalYouTubeShorts.value = [];
    
    // Use force:true to cancel any running background fetch
    await prefetchYouTubeShorts(limit: 10, query: query, append: false, force: true);
    if (mounted) {
      setState(() {
        _videos = globalYouTubeShorts.value;
        _isLoading = globalYouTubeShorts.value.isEmpty;
        _errorMessage = youtubeShortsError;
      });

    }
  }

  /// Reset back to default feed (e.g. from an error screen)
  Future<void> _resetToDefaultFeed() async {
    _searchController.clear();
    setState(() {
      _isSearching = false;
      _isLoading = true;
      _videos = [];
      _errorMessage = null;
      _focusedIndex = 0;
    });
    globalYouTubeShorts.value = [];
    await prefetchYouTubeShorts(limit: 10, query: 'malayalam shorts', append: false, force: true);
    if (mounted) {
      setState(() {
        _videos = globalYouTubeShorts.value;
        _isLoading = globalYouTubeShorts.value.isEmpty;
        _errorMessage = youtubeShortsError;
      });

    }
  }

  @override
  void dispose() {
    globalYouTubeShorts.removeListener(_onGlobalShortsChanged);
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _videos.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                "Loading YouTube Shorts...",
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    if (_videos.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage ?? "No videos found.",
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() { _isSearching = true; });
                          },
                          icon: const Icon(Icons.search, size: 18),
                          label: const Text("Search"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorGreen,
                            foregroundColor: Colors.black,
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: _resetToDefaultFeed,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text("Default Feed"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white24),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            _buildSearchOverlay(),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: 68.h),
          child: Stack(
            fit: StackFit.expand,
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollStartNotification) {
                    isShortsScrolling.value = true;
                  } else if (notification is ScrollEndNotification) {
                    isShortsScrolling.value = false;
                  }
                  return true;
                },
                child: PageView.builder(
                  controller: _pageController,
                  scrollDirection: Axis.vertical,
                  physics: const PageScrollPhysics(parent: ClampingScrollPhysics()),
                  itemCount: _videos.length,
                  onPageChanged: (index) {
                    setState(() {
                      _focusedIndex = index;
                    });
                    
                    // Trigger prefetch when getting close to the end
                    if (index >= _videos.length - 5) {
                      prefetchYouTubeShorts(limit: 10, append: true);
                    }


                  },
                  itemBuilder: (context, index) {
                    return SingleShortPlayer(
                      key: ValueKey(_videos[index]['stream_url']),
                      videoData: _videos[index],
                      isActive: index == _focusedIndex,
                    );
                  },
                ),
              ),
              _buildActionButtons(),
              _buildSearchOverlay(),
              if (isYouTubeShortsLoading) _buildSubtleBottomLoader(),
            ],
          ),
        ),
      ),
    );
  }

  void _applySort(String sortType) {
    if (_videos.isEmpty) return;
    
    if (_originalVideos.isEmpty) {
      _originalVideos = List.from(globalYouTubeShorts.value);
    }

    List<Map<String, dynamic>> sortedList = List.from(globalYouTubeShorts.value);

    switch (sortType) {
      case 'Newest':
        sortedList.sort((a, b) {
          final aDateStr = a['publish_date'] as String?;
          final bDateStr = b['publish_date'] as String?;
          if (aDateStr == null) return 1;
          if (bDateStr == null) return -1;
          return bDateStr.compareTo(aDateStr); // Descending
        });
        break;
      case 'Oldest':
        sortedList.sort((a, b) {
          final aDateStr = a['publish_date'] as String?;
          final bDateStr = b['publish_date'] as String?;
          if (aDateStr == null) return 1;
          if (bDateStr == null) return -1;
          return aDateStr.compareTo(bDateStr); // Ascending
        });
        break;
      case 'Shortest':
        sortedList.sort((a, b) {
          final aDur = a['duration'] as num? ?? 0;
          final bDur = b['duration'] as num? ?? 0;
          return aDur.compareTo(bDur); // Ascending
        });
        break;
      case 'Longest':
        sortedList.sort((a, b) {
          final aDur = a['duration'] as num? ?? 0;
          final bDur = b['duration'] as num? ?? 0;
          return bDur.compareTo(aDur); // Descending
        });
        break;
      case 'Default':
      default:
        if (_originalVideos.length == sortedList.length) {
          sortedList = List.from(_originalVideos);
        }
        break;
    }

    setState(() {
      _currentSort = sortType;
      globalYouTubeShorts.value = sortedList;
      _focusedIndex = 0;
    });
    
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
  }

  void _showSortOptionsBottomSheet() {
    activeShortsPlayer.value?.pause();
    isShortsPlaying.value = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF161616),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
            border: Border.all(color: Colors.white10),
          ),
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  margin: EdgeInsets.only(bottom: 20.h),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              Text(
                "Sort Feed By",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 16.h),
              _buildSortOptionItem(
                title: "Default (Relevance)",
                icon: Icons.sort_rounded,
                value: "Default",
              ),
              _buildSortOptionItem(
                title: "Newest First",
                icon: Icons.calendar_today_rounded,
                value: "Newest",
              ),
              _buildSortOptionItem(
                title: "Oldest First",
                icon: Icons.history_rounded,
                value: "Oldest",
              ),
              _buildSortOptionItem(
                title: "Shortest Duration",
                icon: Icons.hourglass_top_rounded,
                value: "Shortest",
              ),
              _buildSortOptionItem(
                title: "Longest Duration",
                icon: Icons.hourglass_bottom_rounded,
                value: "Longest",
              ),
              SizedBox(height: 12.h),
            ],
          ),
        );
      },
    ).then((_) {
      if (mounted) {
        activeShortsPlayer.value?.play();
        isShortsPlaying.value = true;
      }
    });
  }

  Widget _buildSortOptionItem({
    required String title,
    required IconData icon,
    required String value,
  }) {
    final isSelected = _currentSort == value;
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        _applySort(value);
      },
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 12.w),
        margin: EdgeInsets.symmetric(vertical: 4.h),
        decoration: BoxDecoration(
          color: isSelected ? colorGreen.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSelected ? colorGreen.withValues(alpha: 0.3) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? colorGreen : Colors.white60,
              size: 20.sp,
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isSelected ? colorGreen : Colors.white70,
                  fontSize: 14.sp,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: colorGreen,
                size: 18.sp,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_isSearching) return const SizedBox.shrink();
    return Positioned(
      top: 16.h,
      right: 16.w,
      child: ValueListenableBuilder<bool>(
        valueListenable: isShortsPlaying,
        builder: (context, playing, _) {
          return AnimatedOpacity(
            opacity: playing ? 0.05 : 1.0, // Transparent when video playing, visible when paused
            duration: const Duration(milliseconds: 300),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white10),
                  ),
                  child: IconButton(
                    icon: Icon(
                      _currentSort == 'Default' ? Icons.filter_list_rounded : Icons.filter_list_off_rounded,
                      color: _currentSort == 'Default' ? Colors.white : colorGreen,
                      size: 24.sp,
                    ),
                    onPressed: _showSortOptionsBottomSheet,
                  ),
                ),
                SizedBox(width: 12.w),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white10),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.search_rounded, color: Colors.white, size: 24),
                    onPressed: () {
                      // Pause the video first before opening search overlay
                      activeShortsPlayer.value?.pause();
                      isShortsPlaying.value = false;
                      setState(() {
                        _isSearching = true;
                      });
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSubtleBottomLoader() {
    return Positioned(
      bottom: 24.h,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14.sp,
                height: 14.sp,
                child: CircularProgressIndicator(
                  color: colorGreen,
                  strokeWidth: 2,
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                "Loading more shorts...",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchOverlay() {
    if (!_isSearching) return const SizedBox.shrink();
    return Positioned(
      top: 16.h,
      left: 16.w,
      right: 16.w,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(30.r),
          border: Border.all(color: colorGreen.withValues(alpha: 0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: colorGreen.withValues(alpha: 0.2),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: "Search YouTube Shorts...",
                  hintStyle: TextStyle(color: Colors.white30),
                  border: InputBorder.none,
                ),
                onSubmitted: (val) {
                  if (val.trim().isNotEmpty) {
                    _triggerNewSearch(val.trim());
                  }
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.search, color: Colors.white),
              onPressed: () {
                if (_searchController.text.trim().isNotEmpty) {
                  _triggerNewSearch(_searchController.text.trim());
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white54),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchController.clear();
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Sub-widget that handles playing/pausing a single video clip inside the list feed
class SingleShortPlayer extends StatefulWidget {
  final Map<String, dynamic> videoData;
  final bool isActive;

  const SingleShortPlayer({super.key, required this.videoData, required this.isActive});

  @override
  State<SingleShortPlayer> createState() => _SingleShortPlayerState();
}

class _SingleShortPlayerState extends State<SingleShortPlayer> with WidgetsBindingObserver {
  late final Player _player;
  late final VideoController _videoController;
  bool _isPlayerReady = false;
  bool _isManuallyPaused = false;
  bool isTurboMode = false;
  StreamSubscription? _playingSub;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _videoController = VideoController(_player);
    WidgetsBinding.instance.addObserver(this);

    // Listen to global changes (like tab switching, PiP mode changes)
    isShortsTabActive.addListener(_syncPlayback);
    isShortsPiPMode.addListener(_syncPlayback);

    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      String? streamUrl = widget.videoData['stream_url'];
      debugPrint("🤖 [Player] Initializing video ID: ${widget.videoData['id']}");

      if (streamUrl == null) {
        debugPrint("🤖 [Player] Lazy fetching stream manifest for video: ${widget.videoData['title']}");
        final ytClient = yt.YoutubeExplode();
        try {
          final manifest = await ytClient.videos.streams.getManifest(
            widget.videoData['id'],
            ytClients: [yt.YoutubeApiClient.androidVr],
          );
          final muxed = manifest.muxed.sortByVideoQuality();
          if (muxed.isNotEmpty) {
            streamUrl = muxed.first.url.toString();
            // Cache it back in global state so next time it loads instantly
            final updated = globalYouTubeShorts.value.map((v) {
              if (v['id'] == widget.videoData['id']) {
                return {...v, 'stream_url': streamUrl};
              }
              return v;
            }).toList();
            globalYouTubeShorts.value = updated;
          }
        } catch (e) {
          debugPrint("❌ [Player] Manifest fetch failed: $e");
        } finally {
          ytClient.close();
        }
      }

      if (streamUrl != null) {
        debugPrint("🤖 [Player] Opening stream URL: $streamUrl");
        await _player.open(Media(streamUrl), play: widget.isActive && isShortsTabActive.value);
        await _player.setPlaylistMode(PlaylistMode.loop);

        _playingSub = _player.stream.playing.listen((playing) {
          if (widget.isActive && mounted) {
            isShortsPlaying.value = playing;
          }
        });

        if (mounted) {
          setState(() {
            _isPlayerReady = true;
          });
          if (widget.isActive) {
            _syncPlayback();
          }
        }
      }
    } catch (e) {
      debugPrint("❌ [Player] Error initializing video stream: $e");
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
        } else {
          isShortsPlaying.value = false;
        }
        activeShortsPlayer.value = _player;
        activeShortsVideoController.value = _videoController;
      } else {
        _player.pause();
        _player.setRate(1.0);
        setState(() {
          isTurboMode = false;
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant SingleShortPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    isShortsTabActive.removeListener(_syncPlayback);
    isShortsPiPMode.removeListener(_syncPlayback);
    _playingSub?.cancel();

    if (activeShortsPlayer.value == _player) {
      activeShortsPlayer.value = null;
      activeShortsVideoController.value = null;
    }

    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent, // Allow instant recognition during snaps
      onLongPressStart: (details) {
        // Activate 2x speed only on the right half of the screen
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
            // 1. The Video Component Surface
            Positioned.fill(
              child: _isPlayerReady
                  ? Video(
                      controller: _videoController,
                      controls: NoVideoControls,
                      fit: BoxFit.cover,
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        if (widget.videoData['thumbnail'] != null)
                          Image.network(
                            widget.videoData['thumbnail'],
                            fit: BoxFit.cover,
                            errorBuilder: (c, o, s) => Container(color: Colors.black),
                          )
                        else
                          Container(color: Colors.black),
                        Container(
                          color: Colors.black38, // Dim the placeholder slightly
                        ),
                        const Center(
                          child: CircularProgressIndicator(color: Colors.white70),
                        ),
                      ],
                    ),
            ),

            // Instagram-style 2X Speed Hint
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

            // Centered Play Indicator when paused
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

            // 2. Video Title Text Overlay UI Layout
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
