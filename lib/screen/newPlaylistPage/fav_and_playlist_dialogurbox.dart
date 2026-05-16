import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nova_videoplayer/functions/global_variables.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../functions/favoritedb.dart';
import '../../functions/gobal_functions.dart';
import '../../functions/new_playlist_class.dart';
import '../../functions/new_playlist_db_functions.dart';

class FavoriteMenuButton extends StatefulWidget {
  const FavoriteMenuButton({super.key, required this.favoriteVideo, required this.indexKey});
  final AssetEntity favoriteVideo;
  final int indexKey;
  @override
  State<FavoriteMenuButton> createState() => _FavoriteMenuButtonState();
}

class _FavoriteMenuButtonState extends State<FavoriteMenuButton> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: FavoriteDb.favoriteVideos,
      builder: (BuildContext ctx, List<AssetEntity> favoriteVideos, Widget? child) {
        final isFavorited = FavoriteDb.isFavor(widget.favoriteVideo);
        
        return PopupMenuButton<int>(
          icon: Icon(Icons.more_vert_rounded, color: Colors.white70, size: 22.sp),
          color: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r), side: const BorderSide(color: Colors.white10)),
          offset: const Offset(0, 40),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 1,
              child: Row(
                children: [
                  Icon(isFavorited ? Icons.favorite_rounded : Icons.favorite_outline_rounded, color: isFavorited ? Colors.redAccent : Colors.white70, size: 18.sp),
                  SizedBox(width: 12.w),
                  Text(isFavorited ? 'Remove Favorite' : 'Add to Favorite', style: TextStyle(color: Colors.white, fontSize: 13.sp)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 2,
              child: Row(
                children: [
                  Icon(Icons.playlist_add_rounded, color: Colors.white70, size: 18.sp),
                  SizedBox(width: 12.w),
                  Text('Add to Playlist', style: TextStyle(color: Colors.white, fontSize: 13.sp)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 3,
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Colors.white70, size: 18.sp),
                  SizedBox(width: 12.w),
                  Text('Video Details', style: TextStyle(color: Colors.white, fontSize: 13.sp)),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 1) _handleFavorite(context, isFavorited);
            if (value == 2) _showPlaylistDialog(context);
            if (value == 3) _showDetailsDialog(context);
          },
        );
      },
    );
  }

  void _handleFavorite(BuildContext context, bool isFavorited) {
    if (isFavorited) {
      FavoriteDb.delete(widget.favoriteVideo.id);
      _showSnack(context, 'Removed from Favorites');
    } else {
      FavoriteDb.add(widget.favoriteVideo);
      _showSnack(context, 'Added to Favorites');
    }
    FavoriteDb.favoriteVideos.notifyListeners();
  }

  void _showSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: TextStyle(color: Colors.white, fontSize: 13.sp)),
      duration: const Duration(seconds: 1),
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF1A1A1A),
      margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.r),
        side: const BorderSide(color: Colors.white12),
      ),
    ));
  }

  void _showPlaylistDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r), side: const BorderSide(color: Colors.white10)),
        title: Text("Add to Playlist", style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold)),
        content: SizedBox(
          height: 300.h,
          width: double.maxFinite,
          child: ValueListenableBuilder(
            valueListenable: PlaylistDb.playlistDb.listenable(),
            builder: (context, Box<NovaPlaylist> box, child) {
              if (box.isEmpty) {
                return Center(child: Text('No Playlists Found', style: TextStyle(color: Colors.white24, fontSize: 14.sp)));
              }
              return ListView.builder(
                itemCount: box.length,
                itemBuilder: (context, index) {
                  final data = box.getAt(index);
                  if (data == null) return const SizedBox.shrink();
                  return Card(
                    color: Colors.white.withOpacity(0.03),
                    margin: EdgeInsets.only(bottom: 8.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r), side: const BorderSide(color: Colors.white10)),
                    child: ListTile(
                      title: Text(data.name, style: TextStyle(color: Colors.white70, fontSize: 14.sp, fontWeight: FontWeight.bold)),
                      subtitle: Text("${data.videoIds.length} videos", style: TextStyle(color: Colors.white24, fontSize: 10.sp)),
                      trailing: Icon(Icons.add_circle_outline_rounded, color: Colors.white24, size: 20.sp),
                      onTap: () async {
                        await _addToPlaylist(data, data.name);
                        Navigator.pop(context);
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: Colors.white30, fontSize: 14.sp))),
          TextButton(
            onPressed: () => _showNewPlaylistDialog(context),
            child: Text('New Playlist', style: TextStyle(color: Colors.blueAccent, fontSize: 14.sp, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _addToPlaylist(NovaPlaylist datas, String name) async {
    if (!datas.isValueIn(widget.favoriteVideo.id)) {
      datas.add(widget.favoriteVideo.id);
      _showSnack(context, 'Added to $name');
    } else {
      _showSnack(context, 'Already there');
    }
  }

  void _showNewPlaylistDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r), side: const BorderSide(color: Colors.white10)),
        title: Text('New Playlist', style: TextStyle(color: Colors.white, fontSize: 18.sp)),
        content: Form(
          key: _formKey,
          child: TextFormField(
            controller: nameController,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter name',
              hintStyle: const TextStyle(color: Colors.white24),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: const BorderSide(color: Colors.white10)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: const BorderSide(color: Colors.white10)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: const BorderSide(color: Colors.white30)),
            ),
            validator: (v) => (v == null || v.isEmpty) ? 'Name is required' : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                final name = nameController.text.trim();
                final newPlaylist = NovaPlaylist(name: name, videoIds: []);
                PlaylistDb.addPlaylist(newPlaylist);
                nameController.clear();
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showDetailsDialog(BuildContext context) {
    final video = widget.favoriteVideo;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r), side: const BorderSide(color: Colors.white10)),
        title: Text("Video Details", style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _detailRow(Icons.title_rounded, "Title", video.title ?? "Unknown"),
            _detailRow(Icons.folder_open_rounded, "Path", video.relativePath ?? "Unknown"),
            _detailRow(Icons.timer_rounded, "Duration", durationToString(video.duration)),
            _detailRow(Icons.aspect_ratio_rounded, "Resolution", "${video.width}x${video.height}"),
            _detailRow(Icons.sd_card_rounded, "Size", "${(video.width * video.height / 1000000).toStringAsFixed(1)} MB (approx)"),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close', style: TextStyle(color: Colors.blueAccent))),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white24, size: 18.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.white38, fontSize: 10.sp)),
                Text(value, style: TextStyle(color: Colors.white, fontSize: 12.sp)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
