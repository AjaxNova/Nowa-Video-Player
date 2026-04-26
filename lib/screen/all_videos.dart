import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'video_player_page.dart';

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

class _AllVideosPageState extends State<AllVideosPage> {
  bool isGridView = true;
  late ScrollController _scrollController;
  late List<AssetEntity> displayVideos;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    displayVideos = widget.assets;
    
    // Initialize FavoriteDb once
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!FavoriteDb.isInitialized) {
        FavoriteDb.initialize(widget.assets);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleView() {
    setState(() {
      isGridView = !isGridView;
    });
  }

  void _sortVideos(String type) {
    setState(() {
      switch (type) {
        case 'name_asc':
          displayVideos.sort((a, b) => (a.title ?? '').compareTo(b.title ?? ''));
          break;
        case 'name_desc':
          displayVideos.sort((a, b) => (b.title ?? '').compareTo(a.title ?? ''));
          break;
        case 'size_desc':
          displayVideos.sort((a, b) => (b.width * b.height).compareTo(a.width * a.height));
          break;
        case 'size_asc':
          displayVideos.sort((a, b) => (a.width * a.height).compareTo(b.width * b.height));
          break;
        case 'duration_asc':
          displayVideos.sort((a, b) => a.duration.compareTo(b.duration));
          break;
        case 'duration_desc':
          displayVideos.sort((a, b) => b.duration.compareTo(a.duration));
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colorBlack,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: isGridView ? _buildListView() : _buildGridView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Text(
            "NOVA",
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Inter',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(isGridView ? Icons.grid_view_rounded : Icons.list_rounded, color: colorWhite, size: 22),
            onPressed: _toggleView,
          ),
          IconButton(
            icon: Icon(Icons.sort_rounded, color: colorWhite, size: 22),
            onPressed: () => _showSortDialog(context),
          ),
          IconButton(
            icon: Icon(Icons.search_rounded, color: colorWhite, size: 22),
            onPressed: () {
              showSearch(
                context: context,
                delegate: VideoSearchDelegate(assets: displayVideos, isGridView: isGridView),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showSortDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Sort by', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sortOption('Name - Ascending', 'name_asc'),
            _sortOption('Name - Descending', 'name_desc'),
            _sortOption('Size - Large to Small', 'size_desc'),
            _sortOption('Size - Small to Large', 'size_asc'),
            _sortOption('Duration - Longest', 'duration_desc'),
            _sortOption('Duration - Shortest', 'duration_asc'),
          ],
        ),
      ),
    );
  }

  Widget _sortOption(String title, String type) {
    return ListTile(
      title: Text(title, style: const TextStyle(color: Colors.white70)),
      onTap: () {
        _sortVideos(type);
        Navigator.pop(context);
      },
    );
  }

  Widget _buildListView() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      controller: _scrollController,
      itemCount: displayVideos.length,
      separatorBuilder: (context, index) => Divider(color: Colors.white.withOpacity(0.05), height: 1),
      itemBuilder: (context, index) {
        final video = displayVideos[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: VideoThumbnail(asset: video),
          title: Text(
            video.title ?? 'Unnamed',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            video.relativePath ?? '',
            maxLines: 1,
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
          ),
          trailing: FavoriteMenuButton(favoriteVideo: video, indexKey: index),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MediaKitVideoPlayerPage(
                  videoList: displayVideos,
                  initialIndex: index,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      controller: _scrollController,
      itemCount: displayVideos.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemBuilder: (context, index) {
        final video = displayVideos[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MediaKitVideoPlayerPage(
                  videoList: displayVideos,
                  initialIndex: index,
                ),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: VideoThumbnail(
                  asset: video,
                  width: double.infinity,
                  borderRadius: 8,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  video.title ?? 'Unnamed',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
