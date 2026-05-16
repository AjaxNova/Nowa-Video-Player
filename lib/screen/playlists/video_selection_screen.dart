import 'package:flutter/material.dart';
import 'package:nova_videoplayer/functions/global_variables.dart';
import 'package:nova_videoplayer/functions/new_playlist_class.dart';
import 'package:nova_videoplayer/functions/new_playlist_db_functions.dart';
import 'package:photo_manager/photo_manager.dart';

class VideoSelectionPage extends StatefulWidget {
  const VideoSelectionPage({super.key, required this.playlist});

  // final List<String>selectedIds=[];
  final NovaPlaylist playlist;
  @override
  State<VideoSelectionPage> createState() => _VideoSelectionPageState();
}

class _VideoSelectionPageState extends State<VideoSelectionPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pop(context);
        },
        child: const Icon(Icons.save),
      ),
      body: ListView.builder(
        itemBuilder: (context, index) {
          final data = theAllVideosListFortheSelectionPage[index];
          return ListTile(
            title: Text(data.title!),
            subtitle: Text(data.relativePath.toString()),
            trailing: IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                setState(() {
                  videoAddPlaylist(data);
                  PlaylistDb.playlistNotifiier.notifyListeners();
                });
                // widget.selectedIds.add(data.id);
                // print(widget.selectedIds);
              },
            ),
          );
        },
        itemCount: theAllVideosListFortheSelectionPage.length,
      ),
    );
  }

  void videoAddPlaylist(AssetEntity data) {
    widget.playlist.add(data.id);

    const snackBar1 = SnackBar(
        content: Text(
      'Song added to Playlist',
      style: TextStyle(color: Colors.white, fontFamily: 'poppins'),
    ));
    ScaffoldMessenger.of(context).showSnackBar(snackBar1);
  }
}
