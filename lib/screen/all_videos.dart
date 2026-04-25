import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nova_videoplayer/functions/favoritedb.dart';
import 'package:nova_videoplayer/provider/video_data_provider.dart';
// import 'package:nova_videoplayer/functions/global_variables.dart';
// import 'package:nova_videoplayer/functions/history.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';

import '../functions/global_variables.dart';
import '../functions/gobal_functions.dart';
import '../widgets/search_delegate_function.dart';
import 'newPlaylistPage/fav_and_playlist_dialogurbox.dart';
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
  bool status = false;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    startSong = widget.assets;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void toggleView() {
    setState(() {
      isGridView = !isGridView;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: colorBlack,
        body: SafeArea(
            child: Column(
          children: [
            Container(
              height: 58,
              margin: const EdgeInsets.only(top: 7),
              child: Consumer<VideoDataProvider>(
                builder: (context, value, child) {
                  return ListTile(
                    leading: Text(
                      "NOVA",
                      style: TextStyle(
                          color: colorWhite,
                          fontFamily: 'Inter',
                          fontSize: 26,
                          letterSpacing: 3),
                    ),
                    trailing: Wrap(
                      children: [
                        InkWell(
                          onTap: () {
                            // value.setValueToA();
                            //_scrollController.jumpTo(0.0);
                            //toggleView();
                          },
                          child: Icon(
                            isGridView ? Icons.list : Icons.grid_on,
                            color: colorWhite,
                            size: 22,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(right: 13, left: 16),
                          child: InkWell(
                            onTap: () async {
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: const Text('Sort by'),
                                    content: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SizedBox(
                                          height: 5,
                                        ),
                                        InkWell(
                                          onTap: () async {
                                            setState(() {
                                              startSong.sort((a, b) =>
                                                  a.title!.compareTo(b.title!));
                                            });

                                            Navigator.of(context)
                                                .pop('name_asc');
                                          },
                                          child: const Text('Name - Ascending'),
                                        ),
                                        const SizedBox(
                                          height: 5,
                                        ),
                                        InkWell(
                                          onTap: () async {
                                            setState(() {
                                              startSong.sort((a, b) =>
                                                  b.title!.compareTo(a.title!));
                                            });

                                            Navigator.of(context)
                                                .pop('name_desc');
                                          },
                                          child:
                                              const Text('Name - Descending'),
                                        ),
                                        const SizedBox(
                                          height: 5,
                                        ),
                                        InkWell(
                                          onTap: () async {
                                            final sortOption = startSong
                                              ..sort((a, b) => b.size
                                                  .toString()
                                                  .compareTo(
                                                      a.size.toString()));
                                            setState(() {
                                              startSong = sortOption;
                                            });
                                            Navigator.of(context)
                                                .pop('size_asc');
                                          },
                                          child: const Text('Size - Ascending'),
                                        ),
                                        const SizedBox(
                                          height: 5,
                                        ),
                                        InkWell(
                                          onTap: () {
                                            final sortOption = startSong
                                              ..sort((a, b) => a.size
                                                  .toString()
                                                  .compareTo(
                                                      b.size.toString()));
                                            setState(() {
                                              startSong = sortOption;
                                            });

                                            Navigator.of(context)
                                                .pop('size_desc');
                                          },
                                          child:
                                              const Text('Size - Descending'),
                                        ),
                                        const SizedBox(
                                          height: 5,
                                        ),
                                        InkWell(
                                          onTap: () {
                                            final sortOption = startSong
                                              ..sort((a, b) => a.duration
                                                  .compareTo(b.duration));
                                            setState(() {
                                              startSong = sortOption;
                                            });
                                            Navigator.of(context)
                                                .pop('duration_asc');
                                          },
                                          child: const Text(
                                              'Duration - Ascending'),
                                        ),
                                        const SizedBox(
                                          height: 5,
                                        ),
                                        InkWell(
                                          onTap: () {
                                            final sortOption = startSong
                                              ..sort((a, b) => b.duration
                                                  .compareTo(a.duration));
                                            setState(() {
                                              startSong = sortOption;
                                            });
                                            Navigator.of(context)
                                                .pop('duration_desc');
                                          },
                                          child: const Text(
                                              'Duration - Descending'),
                                        ),
                                        const SizedBox(
                                          height: 5,
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                            child: Icon(
                              Icons.format_line_spacing_sharp,
                              color: colorWhite,
                              size: 23,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            showSearch(
                                context: context,
                                delegate: VideoSearchDelegate(
                                    assets: startSong, isGridView: isGridView));
                          },
                          child: Icon(
                            Icons.search,
                            color: colorWhite,
                            size: 23,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Consumer<VideoDataProvider>(
              builder: (context, value, child) {
                return Expanded(
                  child: isGridView
                      ? ListView.separated(
                          separatorBuilder: (context, index) {
                            return const Divider(
                              color: Colors.grey,
                              height: 1,
                            );
                          },
                          controller: _scrollController,
                          itemCount: startSong.length,
                          itemBuilder: (context, index) {
                            return ListTile(
                                leading: FutureBuilder<Uint8List?>(
                                  future: startSong[index].thumbnailData,
                                  builder: (BuildContext context,
                                      AsyncSnapshot<Uint8List?> snapshot) {
                                    if (!FavoriteDb.isInitialized) {
                                      FavoriteDb.initialize(startSong);
                                    }
                                    if (snapshot.connectionState ==
                                            ConnectionState.done &&
                                        snapshot.data != null) {
                                      return Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(4.0),
                                            child: SizedBox(
                                                height: 80,
                                                width: 90,
                                                child: Image.memory(
                                                  snapshot.data!,
                                                  fit: BoxFit.cover,
                                                )),
                                          ),
                                          Positioned(
                                            top: 34,
                                            bottom: 1,
                                            right: 2,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.centerRight,
                                                  end: Alignment.centerLeft,
                                                  colors: [
                                                    Colors.transparent,
                                                    Colors.black
                                                        .withOpacity(0.6),
                                                  ],
                                                ),
                                              ),
                                              child: Text(
                                                durationToString(
                                                  startSong[index].duration,
                                                ),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          )
                                        ],
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
                                title: Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  child: Text(
                                    startSong[index].title ?? 'Unnamed',
                                    maxLines: 1,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => VideoPLayerPage(
                                        videoList: startSong,
                                        initialIndex: index,
                                      ),
                                    ),
                                  );
                                },
                                subtitle: Text(
                                  startSong[index].relativePath.toString(),
                                  maxLines: 1,
                                  style: const TextStyle(color: Colors.white30),
                                ),
                                trailing: FavoriteMenuButton(
                                    favoriteVideo: startSong[index],
                                    indexKey: index)

                                // InkWell(
                                //   onTap: () {
                                //     print('clicked');
                                //        final video=startSong[index];
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
                                );
                          },
                        )
                      : GridView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(8.0),
                          itemCount: startSong.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 8.0,
                            mainAxisSpacing: 8.0,
                          ),
                          itemBuilder: (context, index) {
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => VideoPLayerPage(
                                      videoList: startSong,
                                      initialIndex: index,
                                    ),
                                  ),
                                );
                              },
                              child: GestureDetector(
                                onLongPress: () {
                                  ///implement the video preview
                                },
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    FutureBuilder<Uint8List?>(
                                      future: value
                                          .allVideosList[index].thumbnailData,
                                      builder: (BuildContext context,
                                          AsyncSnapshot<Uint8List?> snapshot) {
                                        if (snapshot.connectionState ==
                                                ConnectionState.done &&
                                            snapshot.data != null) {
                                          return ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(8.0),
                                            child: SizedBox(
                                                height: 120,
                                                width: 150,
                                                child: Image.memory(
                                                  snapshot.data!,
                                                  fit: BoxFit.cover,
                                                )),
                                          );
                                        } else {
                                          return const CircularProgressIndicator(
                                            color: Colors.black,
                                          );
                                        }
                                      },
                                    ),
                                    Positioned(
                                      child: Container(
                                        margin: const EdgeInsets.only(top: 145),
                                        child: Text(
                                          startSong[index].title ?? 'Unnamed',
                                          maxLines: 1,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16.0,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                );
              },
            )
          ],
        )));
  }
}

List<AssetEntity> startSong = [];
