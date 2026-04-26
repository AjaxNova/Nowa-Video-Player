import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nova_videoplayer/functions/global_variables.dart';
import 'package:nova_videoplayer/screen/media_kit_video_player_page.dart';
import 'package:nova_videoplayer/screen/video_player_page.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../functions/favoritedb.dart';
import '../../functions/history.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({
    Key? key,
  }) : super(key: key);

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  // final OnAudioQuery _audioQuery = OnAudioQuery();
  static List<AssetEntity> history = [];

  @override
  void initState() {
    super.initState();
    init();
    setState(() {});
  }

  Future init() async {
    await HistoryVideos.getHistoryVideos();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    FavoriteDb.favoriteVideos;
    return Scaffold(
      backgroundColor: colorBlack,
      appBar: AppBar(
        backgroundColor: colorBlack,
        title: const Text('My History'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 20),
            child: IconButton(
              onPressed: () {
                HistoryVideos.clearHistory();
              },
              icon: const Icon(Icons.delete_forever_sharp),
              color: colorWhite,
            ),
          )
        ],
      ),
      body: FutureBuilder(
        future: HistoryVideos.getHistoryVideos(),
        builder: (context, items) {
          return ValueListenableBuilder(
            valueListenable: HistoryVideos.historyVideoNotifier,
            builder:
                (BuildContext context, List<AssetEntity> value, Widget? child) {
              if (value.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Center(
                    child: Text(
                      'No Videos In History',
                      style: TextStyle(color: Colors.white, fontSize: 20),
                    ),
                  ),
                );
              } else {
                final temp = value.reversed.toList();
                history = temp.toSet().toList();
                return FutureBuilder(
                  future: HistoryVideos.displayHistory(),
                  builder: (context, items) {
                    if (items.data == null) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (items.data!.isEmpty) {
                      return const Center(
                        child: Text(
                          'No videos Availbale',
                          style: TextStyle(color: Colors.white),
                        ),
                      );
                    }
                    return ListView.builder(
                      itemBuilder: ((context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(left: 6, right: 6),
                          child: Card(
                            color: colorBlack,
                            child: ListTile(
                                onTap: () {
                                  Navigator.of(context).push(MaterialPageRoute(
                                    builder: (context) => MediaKitVideoPlayerPage(
                                        videoList: history,
                                        initialIndex: index),
                                  ));
                                },
                                leading: FutureBuilder<Uint8List?>(
                                  future: history[index].thumbnailData,
                                  builder: (BuildContext context,
                                      AsyncSnapshot<Uint8List?> snapshot) {
                                    if (snapshot.connectionState ==
                                            ConnectionState.done &&
                                        snapshot.data != null) {
                                      return ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(8.0),
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
                                          borderRadius:
                                              BorderRadius.circular(8.0),
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
                                // QueryArtworkWidget(
                                //     id: recentSong[index].id,
                                //     type: ArtworkType.AUDIO,
                                //     nullArtworkWidget: const CircleAvatar(
                                //         radius: 27,
                                //         backgroundImage: AssetImage(
                                //             'assets/images/playlist.png'))),

                                title: Text(
                                  history[index].title!,
                                  maxLines: 1,
                                  style: const TextStyle(
                                      overflow: TextOverflow.ellipsis,
                                      color: Colors.white),
                                ),
                                subtitle: Text(
                                  history[index].relativePath.toString(),
                                  maxLines: 1,
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.blueGrey),
                                ),
                                trailing: IconButton(
                                  onPressed: () {
                                    HistoryVideos.removeFromHistory(
                                        history[index]);
                                  },
                                  icon: Icon(
                                    size: 18,
                                    Icons.remove_circle,
                                    color: colorWhite,
                                  ),
                                )),
                          ),
                        );
                      }),
                      itemCount: history.length,
                    );
                  },
                );
              }
            },
          );
        },
      ),
    );
  }
}
