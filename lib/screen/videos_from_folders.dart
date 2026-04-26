import 'package:flutter/material.dart';
import 'package:nova_videoplayer/functions/gobal_functions.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:nova_videoplayer/widgets/video_thumbnail.dart';

import 'media_kit_video_player_page.dart';
import 'video_player_page.dart';

class VideosFromFolder extends StatefulWidget {
  final AssetPathEntity folder;
  const VideosFromFolder({super.key, required this.folder});

  @override
  State<VideosFromFolder> createState() => _VideosFromFolderState();
}

class _VideosFromFolderState extends State<VideosFromFolder> {
  List<AssetEntity> _videos = [];
  bool _isLoading = true;

  void _loadVideosInFolder() async {
    // Still fetching all for simplicity, but pagination could be added later
    List<AssetEntity> videos =
        await widget.folder.getAssetListRange(start: 0, end: 5000);
    if (mounted) {
      setState(() {
        _videos = videos;
        _isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadVideosInFolder();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(widget.folder.name, style: const TextStyle(color: Colors.white, fontSize: 18)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _videos.isEmpty
              ? const Center(child: Text("No videos found", style: TextStyle(color: Colors.white)))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _videos.length,
                  separatorBuilder: (context, index) => Divider(color: Colors.white.withOpacity(0.05), height: 1),
                  itemBuilder: (context, index) {
                    final video = _videos[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: VideoThumbnail(asset: video),
                      title: Text(
                        video.title ?? 'Unnamed',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                      ),
                      subtitle: Text(
                        "${video.width}x${video.height} • ${durationToString(video.duration)}",
                        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MediaKitVideoPlayerPage(
                              videoList: _videos,
                              initialIndex: index,
                            ),
                          ),
                        );
                      },
                      trailing: Icon(
                        Icons.more_vert_rounded,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    );
                  },
                ),
    );
  }
}
