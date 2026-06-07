import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nova_videoplayer/functions/global_variables.dart';
import 'shorts_feed_controller.dart';
import 'shorts_player_tile.dart';
import 'shorts_stream_cache.dart';

class ShortsFeedScreen extends StatefulWidget {
  const ShortsFeedScreen({super.key});

  @override
  State<ShortsFeedScreen> createState() => _ShortsFeedScreenState();
}

class _ShortsFeedScreenState extends State<ShortsFeedScreen> {
  late final ShortsFeedController _controller;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  int _pendingSettledIndex = 0;
  bool _showSortOverlay = false;
  String _sortOverlayLabel = '';

  @override
  void initState() {
    super.initState();
    _controller = ShortsFeedController();
    _controller.addListener(_onControllerChanged);

    // Bind to the global tab listener to synchronize visibility
    isLiveShortsTabActive.addListener(_onTabActiveChanged);
    // Sync initial state
    _controller.pool.setVisible(isLiveShortsTabActive.value);
  }

  void _onTabActiveChanged() {
    if (mounted) {
      _controller.pool.setVisible(isLiveShortsTabActive.value);
    }
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    isLiveShortsTabActive.removeListener(_onTabActiveChanged);
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _triggerNewSearch(String query) async {
    setState(() {
      _isSearching = false;
    });
    // Pause active video during search loads
    activeShortsPlayer.value?.pause();
    isShortsPlaying.value = false;
    
    await _controller.triggerNewSearch(query);
  }

  Future<void> _resetToDefaultFeed() async {
    _searchController.clear();
    setState(() {
      _isSearching = false;
    });
    activeShortsPlayer.value?.pause();
    isShortsPlaying.value = false;
    
    await _controller.triggerNewSearch('malayalam shorts');
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
          child: SingleChildScrollView(
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
                  icon: Icons.auto_awesome_rounded,
                  value: "Default",
                ),
                _buildSortOptionItem(
                  title: "Newest First",
                  icon: Icons.arrow_downward_rounded,
                  value: "Newest",
                ),
                _buildSortOptionItem(
                  title: "Oldest First",
                  icon: Icons.arrow_upward_rounded,
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
                _buildSortOptionItem(
                  title: "Most Viewed",
                  icon: Icons.visibility_rounded,
                  value: "Most Viewed",
                ),
                _buildSortOptionItem(
                  title: "Most Liked",
                  icon: Icons.favorite_rounded,
                  value: "Most Liked",
                ),
                _buildSortOptionItem(
                  title: "Most Commented",
                  icon: Icons.comment_rounded,
                  value: "Most Commented",
                ),
                SizedBox(height: 12.h),
              ],
            ),
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
    final isSelected = _controller.currentSort == value;
    return InkWell(
      onTap: () async {
        Navigator.pop(context);
        // Show overlay first
        setState(() {
          _sortOverlayLabel = title; // e.g. "Newest First"
          _showSortOverlay = true;
        });
        // Let overlay appear
        await Future.delayed(const Duration(milliseconds: 120));
        // Apply sort (resets pool + jumps to 0)
        await _controller.setSort(value);
        // Hold briefly then fade out
        await Future.delayed(const Duration(milliseconds: 700));
        if (mounted) setState(() => _showSortOverlay = false);
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

  void _showVideoInfoDialog() {
    activeShortsPlayer.value?.pause();
    isShortsPlaying.value = false;

    if (_controller.focusedIndex >= _controller.videos.length) return;
    final currentVideo = _controller.videos[_controller.focusedIndex];

    final title = currentVideo['title'] ?? 'N/A';
    final id = currentVideo['id'] ?? 'N/A';
    final publishDateStr = currentVideo['publish_date'] as String?;
    final publishDate = publishDateStr != null ? DateTime.tryParse(publishDateStr) : null;
    final formattedDate = publishDate != null
        ? "${publishDate.day}/${publishDate.month}/${publishDate.year}"
        : 'N/A';
    final durationSecs = currentVideo['duration'] as num? ?? 0;
    final minutes = durationSecs ~/ 60;
    final seconds = durationSecs % 60;
    final durationText = durationSecs > 0 ? "$minutes:${seconds.toString().padLeft(2, '0')}" : 'N/A';

    final author = currentVideo['author'] ?? 'N/A';
    final viewCount = currentVideo['view_count'];
    final likeCount = currentVideo['like_count'];
    final viewsText = viewCount != null ? viewCount.toString() : 'N/A';
    final likesText = likeCount != null ? likeCount.toString() : 'N/A';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161616),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
            side: const BorderSide(color: Colors.white10),
          ),
          title: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: colorGreen),
              SizedBox(width: 8.w),
              const Text("Video Information", style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow("Title:", title),
              _infoRow("ID:", id),
              _infoRow("Author:", author),
              _infoRow("Duration:", durationText),
              _infoRow("Upload Date:", formattedDate),
              _infoRow("Views:", viewsText),
              _infoRow("Likes:", likesText),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Close", style: TextStyle(color: colorGreen)),
            ),
          ],
        );
      },
    ).then((_) {
      if (mounted) {
        activeShortsPlayer.value?.play();
        isShortsPlaying.value = true;
      }
    });
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: RichText(
        text: TextSpan(
          style: TextStyle(color: Colors.white70, fontSize: 13.sp),
          children: [
            TextSpan(text: "$label ", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            TextSpan(text: value),
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
            opacity: playing ? 0.05 : 1.0,
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
                    icon: const Icon(Icons.info_outline_rounded, color: Colors.white, size: 24),
                    onPressed: _showVideoInfoDialog,
                  ),
                ),
                SizedBox(width: 12.w),
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
                    icon: Icon(
                      Icons.tune_rounded, // same icon always, colour changes
                      color: _controller.currentSort == 'Default'
                          ? Colors.white
                          : colorGreen,
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
            color: Colors.black.withOpacity(0.7),
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
          color: Colors.black.withOpacity(0.9),
          borderRadius: BorderRadius.circular(30.r),
          border: Border.all(color: colorGreen.withOpacity(0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: colorGreen.withOpacity(0.2),
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

  @override
  Widget build(BuildContext context) {
    if (_controller.isLoading && _controller.videos.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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

    if (_controller.videos.isEmpty) {
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
                      _controller.errorMessage ?? "No videos found.",
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _isSearching = true;
                            });
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
                  } else if (notification is ScrollUpdateNotification) {
                    // Prewarm nearest index while user drags
                    final page = _controller.pageController.page;
                    if (page != null) {
                      final nearestIndex = page.round();
                      ShortsStreamCache.instance.warmUpAround(nearestIndex, _controller.videos);
                    }
                  } else if (notification is ScrollEndNotification) {
                    isShortsScrolling.value = false;
                    // Commit active index only when scroll ends (settles)
                    _controller.setFocusedIndex(_pendingSettledIndex);
                  }
                  return true;
                },
                child: PageView.builder(
                  key: const PageStorageKey('shorts_feed'),
                  controller: _controller.pageController,
                  scrollDirection: Axis.vertical,
                  physics: const FastShortsPagePhysics(parent: ClampingScrollPhysics()),
                  itemCount: _controller.videos.length,
                  onPageChanged: (index) {
                    _pendingSettledIndex = index;
                    // Trigger prefetch refill when getting close to end
                    if (index >= _controller.videos.length - 5) {
                      prefetchYouTubeShorts(limit: 10, append: true);
                    }
                  },
                  itemBuilder: (context, index) {
                    final videoData = _controller.videos[index];
                    return ShortsPlayerTile(
                      key: ValueKey(videoData['id']),
                      index: index,
                      videoData: videoData,
                      pool: _controller.pool,
                    );
                  },
                ),
              ),
              _buildActionButtons(),
              _buildSearchOverlay(),
              if (isYouTubeShortsLoading) _buildSubtleBottomLoader(),
              // Sort overlay — full screen, sits above everything
              Positioned.fill(
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
                              border: Border.all(
                                color: colorGreen.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Icon(Icons.tune_rounded, color: colorGreen, size: 36.sp),
                          ),
                          SizedBox(height: 20.h),
                          Text(
                            'Sorting by',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 12.sp,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Text(
                            _sortOverlayLabel,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20.sp,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                          SizedBox(height: 24.h),
                          SizedBox(
                            width: 24.w,
                            height: 24.w,
                            child: CircularProgressIndicator(
                              color: colorGreen,
                              strokeWidth: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
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

  @override
  Tolerance get tolerance => const Tolerance(
        velocity: 1.0,
        distance: 0.5,
      );
}
