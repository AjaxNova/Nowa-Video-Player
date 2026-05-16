import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nova_videoplayer/functions/global_variables.dart';
import 'package:nova_videoplayer/functions/new_playlist_class.dart';
import 'package:nova_videoplayer/functions/new_playlist_db_functions.dart';
import 'package:nova_videoplayer/screen/video_player_page.dart';
import 'package:photo_manager/photo_manager.dart';

class PlaylistDetailsPage extends StatefulWidget {
  final NovaPlaylist playlist;
  final int playlistKey;

  const PlaylistDetailsPage(
      {super.key, required this.playlist, required this.playlistKey});

  @override
  State<PlaylistDetailsPage> createState() => _PlaylistDetailsPageState();
}

class _PlaylistDetailsPageState extends State<PlaylistDetailsPage> {
  late List<AssetEntity> _videos;
  late bool iconStatus;

  @override
  void initState() {
    super.initState();
    _fetchVideos();
  }

  void _fetchVideos() async {
    List<AssetEntity> videos = theAllVideosListFortheSelectionPage;

    setState(() {
      _videos = videos;
    });
  }

  void _showAddVideoDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Builder(
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: Colors.blueGrey,
              title: const Text(
                'Add videos',
                style: TextStyle(color: Colors.white),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  itemCount: _videos.length,
                  itemBuilder: (BuildContext context, int index) {
                    iconStatus = widget.playlist.isValueIn(_videos[index].id);
                    return Container(
                      decoration:
                          BoxDecoration(border: Border.all(color: colorWhite)),
                      child: ListTile(
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
                                      height: 40,
                                      width: 50,
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
                                          color: Colors.black,
                                        )));
                              }
                            },
                          ),
                          title: Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              _videos[index].title ?? 'Unnamed',
                              maxLines: 3,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          // onTap: () {
                          //     Navigator.push(
                          //     context,
                          //     MaterialPageRoute(
                          //       builder: (context) => VideoPLayerPage(
                          //         videoList: widget.assets,
                          //         initialIndex: index,
                          //       ),
                          //     ),
                          //   );
                          // },
                          // subtitle: Text(durationToString(_videos[index].duration,),
                          // style: const TextStyle(
                          //   color: Colors.black
                          // ),),
                          trailing: Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: Wrap(children: [
                              !widget.playlist.isValueIn(_videos[index].id)
                                  ? IconButton(
                                      onPressed: () {
                                        if (widget.playlist.videoIds
                                            .contains(_videos[index].id)) {}

                                        setState(() {
                                          videoAddPlaylist(_videos[index]);
                                          PlaylistDb.playlistNotifiier
                                              .notifyListeners();
                                        });
                                      },
                                      icon: const Icon(
                                        Icons.add,
                                        color: Colors.white,
                                      ))
                                  : IconButton(
                                      onPressed: () {
                                        setState(() {
                                          widget.playlist
                                              .deleteData(_videos[index].id);
                                        });
                                        const snackBar = SnackBar(
                                          content: Text(
                                            'Song deleted from playlist',
                                            style:
                                                TextStyle(color: Colors.white),
                                          ),
                                          duration: Duration(milliseconds: 450),
                                        );
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(snackBar);
                                      },
                                      icon: const Padding(
                                        padding: EdgeInsets.only(bottom: 25),
                                        child: Icon(
                                          Icons.minimize,
                                          color: Colors.white,
                                        ),
                                      ))
                            ]),
                          )

                          // InkWell(
                          //   onTap: () {
                          //     print('clicked');
                          //        final video=widget.assets[index];
                          //        FavoriteMenuButton(
                          //       favoriteVideo: video,
                          //        indexKey: index);
                          //        print('object');
                          //       // addToFavorites(video.id);
                          //       // getOneAssetById(video.id);
                          //    },
                          //   child: Container(
                          //     margin: const EdgeInsets.only(bottom: 16),
                          //     child: const Icon(Icons.more_vert,color: Colors.white,)),
                          // )
                          ),
                    );
                    // ListTile(
                    //   title: Text(_videos[index].title!),
                    //   trailing: IconButton(
                    //     icon: Icon(
                    //       // widget.playlist.videoIdNotifier.value.contains(_videos[index].id)
                    //       //     ? Icons.check_circle
                    //       //  :
                    //        Icons.add_circle,
                    //     ),
                    //     onPressed: () async{
                    //       // final playlistDB=await Hive.openBox<Playlist>('playlist_db');
                    //       // print('Box opened');
                    //       // final playlist = playlistDB.values.firstWhere((p) => p.name == widget.playlist.name);
                    //       // playlist.addOrRemoveVideo(_videos[index].id);
                    //       // print('id added');
                    //       // await playlistDB.put(playlist.uniqueId,playlist);
                    //       // print('db updated');

                    //       // await widget.playlist.addOrRemoveVideo(_videos[index].id);
                    //       // await widget.playlist.addToTheAssetPLaylist(id: _videos[index].id);
                    //       playListnotifier.notifyListeners();

                    //       Navigator.pop(context);
                    //     },
                    //   ),
                    // );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    late List<AssetEntity> videoPlaylist;
    return Scaffold(
      backgroundColor: colorBlack,
      appBar: AppBar(
        backgroundColor: colorBlack,
        title: Text(widget.playlist.name),
        actions: [
          IconButton(
              onPressed: () {
                _showAddVideoDialog();
                //  Navigator.of(context).push(MaterialPageRoute(builder: (context) => VideoSelectionPage(playlist:widget.playlist ),));
              },
              icon: const Icon(Icons.add))
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ValueListenableBuilder(
                valueListenable: Hive.box<NovaPlaylist>('playlistDb').listenable(),
                builder: (BuildContext context, Box<NovaPlaylist> allPlaylistsz,
                    Widget? child) {
                  final thePlaylist = allPlaylistsz.values
                      .toList()[widget.playlistKey]
                      .videoIds;
                  videoPlaylist = getAssetsFromIds(
                      theAllVideosListFortheSelectionPage, thePlaylist);
                  return videoPlaylist.isEmpty
                      ? Center(
                          child: Text(
                            'No Video',
                            style: TextStyle(color: colorWhite),
                          ),
                        )
                      : ListView.builder(
                          itemBuilder: (context, index) {
                            final theVideoList = videoPlaylist;
                            final theVideo = videoPlaylist[index];

                            return ListTile(
                              leading: FutureBuilder<Uint8List?>(
                                future: theVideo.thumbnailData,
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
                              title: Text(
                                theVideo.title!,
                                maxLines: 2,
                                style: TextStyle(color: colorWhite),
                              ),
                              subtitle: Text(
                                theVideo.relativePath.toString(),
                                maxLines: 1,
                                style: TextStyle(color: colorWhite),
                              ),
                              trailing: IconButton(
                                onPressed: () {
                                  widget.playlist
                                      .deleteData(videoPlaylist[index].id);
                                },
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                              ),
                              onTap: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (context) => VideoPLayerPage(
                                      videoList: theVideoList,
                                      initialIndex: index),
                                ));
                              },
                            );
                          },
                          itemCount: videoPlaylist.length,
                        );
                }
                //(BuildContext context, List<AssetEntity> allMyPlaylistVideos, Widget? child) {

                //    return ListView.builder(
                //     itemBuilder: (context, index) {
                //       final myvideo=allMyPlaylistVideos[index];
                //       return ListTile(
                //         title: Text(myvideo.title!),
                //         subtitle: Text(myvideo.relativePath.toString()),
                //       );
                //     },
                //     itemCount: allMyPlaylistVideos.length,
                //     );
                // } ,
                ),
            // child: ValueListenableBuilder(
            //   valueListenable: playlistVideosNotifier,
            //   builder: (BuildContext context, List<AssetEntity> playlistVideos, Widget? child){

            //     return ListView.builder(
            //       itemBuilder: (context, index) {
            //         final myvideos=playlistVideos[index];
            //         return ListTile(
            //           title: Text(myvideos.title!),
            //           subtitle: Text(myvideos.relativePath.toString()),
            //         );
            //       },
            //       itemCount: playlistVideos.length,
            //       );
            //   })
          ),
        ],
      ),
      // floatingActionButton: FloatingActionButton(
      //   child: Icon(Icons.add),
      //   onPressed: () {
      //      Navigator.of(context).push(MaterialPageRoute(builder: (context) => VideoSelectionPage(playlist:widget.playlist ),));
      //   },
      // ),
    );
  }

  void videoAddPlaylist(AssetEntity data) {
    widget.playlist.add(data.id);

    const snackBar1 = SnackBar(
        content: Text(
      'video added to Playlist',
      style: TextStyle(color: Colors.white),
    ));
    ScaffoldMessenger.of(context).showSnackBar(snackBar1);
  }
}
