import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';

import '../functions/gobal_functions.dart';
import 'video_player_page.dart';

class VideosFromFolder extends StatefulWidget {
  final AssetPathEntity folder;
  const VideosFromFolder({super.key, required this.folder});

  @override
  State<VideosFromFolder> createState() => _VideosFromFolderState();
}

class _VideosFromFolderState extends State<VideosFromFolder> {
  List<AssetEntity> _videos = [];
  void _loadVideosInFolder() async {
    List<AssetEntity> videos =
        await widget.folder.getAssetListRange(start: 0, end: 10000);
    setState(() {
      _videos = videos;
    });
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
          title: Text(widget.folder.name),
        ),
        body: _videos.isEmpty
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : ListView.builder(
                itemCount: _videos.length,
                itemBuilder: (context, index) {
                  return ListTile(
                      leading: FutureBuilder<Uint8List?>(
                        future: _videos[index].thumbnailData,
                        builder: (BuildContext context,
                            AsyncSnapshot<Uint8List?> snapshot) {
                          if (snapshot.connectionState ==
                                  ConnectionState.done &&
                              snapshot.data != null) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(8.0),
                              child: SizedBox(
                                  height: 50,
                                  width: 70,
                                  child: Image.memory(
                                    snapshot.data!,
                                    fit: BoxFit.cover,
                                  )),
                            );
                          } else {
                            return ClipRRect(
                                borderRadius: BorderRadius.circular(8.0),
                                child: const SizedBox(
                                    height: 50,
                                    width: 70,
                                    child: Icon(
                                      Icons.movie,
                                      color: Colors.white,
                                    )));
                          }
                        },
                      ),
                      title: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          _videos[index].title ?? 'Unnamed',
                          maxLines: 1,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VideoPLayerPage(
                              videoList: _videos,
                              initialIndex: index,
                            ),
                          ),
                        );
                      },
                      subtitle: Wrap(
                        children: [
                          Text(
                            durationToString(
                              _videos[index].duration,
                            ),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                      trailing: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: const Icon(
                            Icons.more_vert,
                            color: Colors.white,
                          )));
                },
              ));
  }
}
