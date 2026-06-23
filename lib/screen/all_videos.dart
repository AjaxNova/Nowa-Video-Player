import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nova_videoplayer/functions/favoritedb.dart';
import 'package:nova_videoplayer/provider/video_data_provider.dart';
import 'package:nova_videoplayer/widgets/video_thumbnail.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';

import '../functions/global_variables.dart';
import '../functions/gobal_functions.dart';
import '../widgets/search_delegate_function.dart';
import 'newPlaylistPage/fav_and_playlist_dialogurbox.dart';
import 'media_kit_video_player_page.dart';

class AllVideosPage extends StatefulWidget {
  const AllVideosPage({
    super.key,
    required this.assets,
    required this.foldersWithVideos,
  });

  final List<AssetPathEntity> foldersWithVideos;
  final List<AssetEntity> assets;

  @override
  State<AllVideosPage> createState() => _AllVideosPageState();
}

class _AllVideosPageState extends State<AllVideosPage> with SingleTickerProviderStateMixin {
  bool isGridView = true;
  late ScrollController _scrollController;
  late AnimationController _spinController;
  bool _isGlowing = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _spinController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _isGlowing = false);
        _spinController.reset();
      }
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<VideoDataProvider>();
      if (!FavoriteDb.isInitialized && provider.allVideosList.isNotEmpty) {
        FavoriteDb.initialize(provider.allVideosList);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _spinController.dispose();
    super.dispose();
  }

  void _toggleView() {
    setState(() => isGridView = !isGridView);
  }

  void _sortVideos(String type) {
    context.read<VideoDataProvider>().setSort(type);
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  String _getResolution(AssetEntity asset) {
    if (asset.width == 0 || asset.height == 0) return "";
    final minSide = asset.width < asset.height ? asset.width : asset.height;
    if (minSide >= 2160) return "4K";
    if (minSide >= 1080) return "1080p";
    if (minSide >= 720) return "720p";
    if (minSide >= 480) return "480p";
    return "${minSide}p";
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return "0 B";
    if (bytes < 1024) return "${bytes} B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    if (bytes < 1024 * 1024 * 1024) return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
    return "${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB";
  }

  String _getTimeAgo(DateTime date) {
    final duration = DateTime.now().difference(date);
    if (duration.inDays > 365) return "${(duration.inDays / 365).floor()}y ago";
    if (duration.inDays > 30) return "${(duration.inDays / 30).floor()}mo ago";
    if (duration.inDays > 0) return "${duration.inDays}d ago";
    if (duration.inHours > 0) return "${duration.inHours}h ago";
    if (duration.inMinutes > 0) return "${duration.inMinutes}m ago";
    return "Just now";
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VideoDataProvider>(
      builder: (context, provider, child) {
        final displayVideos = provider.allVideosList;
        return Scaffold(
          backgroundColor: colorBlack,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(context, displayVideos),
                Expanded(
                  child: displayVideos.isEmpty 
                      ? const Center(child: Text("No videos found", style: TextStyle(color: Colors.white, fontSize: 18)))
                      : isGridView 
                          ? _buildListView(displayVideos, provider) 
                          : _buildGridView(displayVideos, provider),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, List<AssetEntity> videos) {
    return Container(
      height: 64.h,
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        children: [
          GestureDetector(
            onLongPress: () {
              setState(() => _isGlowing = true);
              _spinController.forward();
            },
            child: RotationTransition(
              turns: Tween(begin: 0.0, end: 1.0).animate(
                CurvedAnimation(parent: _spinController, curve: Curves.easeInOut),
              ),
              child: Text(
                "NOVA",
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Inter',
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  shadows: _isGlowing
                      ? [
                          Shadow(color: Colors.blueAccent.withOpacity(0.8), blurRadius: 20),
                          Shadow(color: Colors.white.withOpacity(0.6), blurRadius: 10),
                        ]
                      : null,
                ),
              ),
            ),
          ),
          const Spacer(),
          IconButton(icon: Icon(isGridView ? Icons.grid_view_rounded : Icons.list_rounded, color: colorWhite, size: 22.sp), onPressed: _toggleView),
          IconButton(icon: Icon(Icons.sort_rounded, color: colorWhite, size: 22.sp), onPressed: () => _showSortBottomSheet(context)),
          IconButton(icon: Icon(Icons.search_rounded, color: colorWhite, size: 22.sp), onPressed: () {
            showSearch(context: context, delegate: VideoSearchDelegate(assets: videos, isGridView: isGridView));
          }),
        ],
      ),
    );
  }

  Widget _buildListView(List<AssetEntity> displayVideos, VideoDataProvider provider) {
    return ListView.separated(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      controller: _scrollController,
      itemCount: displayVideos.length,
      separatorBuilder: (context, index) => Divider(color: Colors.white.withOpacity(0.05), height: 1.h),
      itemBuilder: (context, index) {
        final video = displayVideos[index];
        final resolution = _getResolution(video);
        final size = _formatSize(provider.getCachedSize(video.id));
        final timeAgo = _getTimeAgo(video.createDateTime);
        
        return ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          leading: VideoThumbnail(asset: video),
          title: Text(video.title ?? 'Unnamed', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.bold)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 2.h),
              Text(video.relativePath ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10.sp)),
              SizedBox(height: 2.h),
              Row(
                children: [
                  if (resolution.isNotEmpty)
                    Container(
                      margin: EdgeInsets.only(right: 6.w),
                      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                      decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(4.r)),
                      child: Text(resolution, style: TextStyle(color: Colors.white38, fontSize: 8.sp, fontWeight: FontWeight.bold)),
                    ),
                  Text("$size • $timeAgo", style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 10.sp)),
                ],
              ),
            ],
          ),
          trailing: FavoriteMenuButton(favoriteVideo: video, indexKey: index),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => MediaKitVideoPlayerPage(videoList: displayVideos, initialIndex: index)));
          },
        );
      },
    );
  }

  Widget _buildGridView(List<AssetEntity> displayVideos, VideoDataProvider provider) {
    return GridView.builder(
      padding: EdgeInsets.all(12.r),
      controller: _scrollController,
      itemCount: displayVideos.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12.w, mainAxisSpacing: 16.h, childAspectRatio: 0.85),
      itemBuilder: (context, index) {
        final video = displayVideos[index];
        final size = _formatSize(provider.getCachedSize(video.id));
        final timeAgo = _getTimeAgo(video.createDateTime);
        final resolution = _getResolution(video);
        
        return GestureDetector(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => MediaKitVideoPlayerPage(videoList: displayVideos, initialIndex: index)));
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: VideoThumbnail(asset: video, width: double.infinity, borderRadius: 10.r)),
              SizedBox(height: 8.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(video.title ?? 'Unnamed', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.bold)),
                    SizedBox(height: 2.h),
                    Text(video.relativePath ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white24, fontSize: 9.sp)),
                    SizedBox(height: 2.h),
                    Row(
                      children: [
                        if (resolution.isNotEmpty)
                          Text("$resolution • ", style: TextStyle(color: Colors.white10, fontSize: 8.sp, fontWeight: FontWeight.bold)),
                        Text("$size • $timeAgo", style: TextStyle(color: Colors.white.withOpacity(0.08), fontSize: 8.sp)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSortBottomSheet(BuildContext context) {
    final currentSort = context.read<VideoDataProvider>().currentSort;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: EdgeInsets.only(top: 12.h, bottom: 8.h),
                height: 4.h,
                width: 40.w,
                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(2.r)),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                child: Text("Sort Videos By", style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.bold)),
              ),
              const Divider(color: Colors.white10, height: 1),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                child: Wrap(
                  spacing: 12.w,
                  runSpacing: 12.h,
                  children: [
                    _sortChip(context, 'Name A-Z', Icons.sort_by_alpha_rounded, 'name_asc', currentSort),
                    _sortChip(context, 'Name Z-A', Icons.sort_by_alpha_rounded, 'name_desc', currentSort),
                    _sortChip(context, 'Size ↓', Icons.sd_card_rounded, 'size_desc', currentSort),
                    _sortChip(context, 'Size ↑', Icons.sd_card_rounded, 'size_asc', currentSort),
                    _sortChip(context, 'Longest', Icons.timer_rounded, 'duration_desc', currentSort),
                    _sortChip(context, 'Shortest', Icons.timer_rounded, 'duration_asc', currentSort),
                    _sortChip(context, 'Newest', Icons.calendar_today_rounded, 'date_desc', currentSort),
                  ],
                ),
              ),
              SizedBox(height: 20.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sortChip(BuildContext context, String title, IconData icon, String type, String currentSort) {
    final bool isSelected = currentSort == type;
    
    return InkWell(
      onTap: () {
        _sortVideos(type);
        Navigator.pop(context);
      },
      child: Container(
        width: (MediaQuery.of(context).size.width - 60.w) / 3,
        padding: EdgeInsets.symmetric(vertical: 12.h),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: isSelected ? Colors.white30 : Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.white54, size: 24.sp),
            SizedBox(height: 6.h),
            Text(
              title, 
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70, 
                fontSize: 11.sp,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ), 
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
