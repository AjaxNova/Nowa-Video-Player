import 'package:flutter/material.dart';
import 'package:nova_videoplayer/functions/global_variables.dart';
import 'package:photo_manager/photo_manager.dart';

import '../functions/gobal_functions.dart';
import '../screen/media_kit_video_player_page.dart';
import 'cached_thumbnail_image.dart';

class VideoSearchDelegate extends SearchDelegate<AssetEntity> {
  final List<AssetEntity> assets;
  bool isGridView;
  VideoSearchDelegate({required this.assets, required this.isGridView});

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: Colors.grey,
        iconTheme: theme.iconTheme.copyWith(color: Colors.white),
        actionsIconTheme: theme.iconTheme.copyWith(color: Colors.white),
        toolbarTextStyle: TextTheme(
          titleLarge: TextStyle(
            color: colorWhite,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ).bodyMedium,
        titleTextStyle: const TextTheme(
          titleLarge: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ).titleLarge,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        fillColor: Colors.grey,
        hintStyle: TextStyle(
          color: Colors.white,
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white),
        ),
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(
          Icons.clear,
          color: Colors.white,
        ),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, assets.first);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final searchResults = assets
        .where((asset) =>
            asset.title != null &&
            asset.title!.toLowerCase().contains(query.toLowerCase()))
        .toList();

    return buildSearchResults(context, searchResults);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final searchResults = assets
        .where(
            (asset) => asset.title!.toLowerCase().contains(query.toLowerCase()))
        .toList();

    return buildSearchResults(context, searchResults);
  }

  Widget buildSearchResults(BuildContext context, List<AssetEntity> results) {
    if (results.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'No results found for "$query".',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    return Scaffold(
        backgroundColor: Colors.black,
        body: isGridView
            ? ListView.builder(
                itemCount: results.length,
                itemBuilder: (context, index) {
                  return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: SizedBox(
                          height: 50,
                          width: 70,
                          child: CachedThumbnailImage(
                            asset: results[index],
                            width: 200,
                            height: 200,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      title: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          results[index].title ?? 'Unnamed',
                          maxLines: 1,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MediaKitVideoPlayerPage(
                              videoList: assets,
                              initialIndex: index,
                            ),
                          ),
                        );
                      },
                      subtitle: Wrap(
                        children: [
                          Text(
                            durationToString(
                              results[index].duration,
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
              )
            : GridView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: results.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8.0,
                  mainAxisSpacing: 8.0,
                ),
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      // Navigator.push(
                      //   context,
                      //   MaterialPageRoute(
                      //     builder: (context) => VideoPLayerPage(
                      //       videoList: results,
                      //       initialIndex: index,
                      //     ),
                      //   ),
                      // );
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: SizedBox(
                            height: 120,
                            width: 150,
                            child: CachedThumbnailImage(
                              asset: results[index],
                              width: 300,
                              height: 300,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          child: Container(
                            margin: const EdgeInsets.only(top: 145),
                            child: Text(
                              results[index].title ?? 'Unnamed',
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
                  );
                },
              ));
  }
}
