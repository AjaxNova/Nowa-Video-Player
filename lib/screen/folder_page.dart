import 'package:flutter/material.dart';
import 'package:nova_videoplayer/widgets/serach_delage_for_folder.dart';
import 'package:photo_manager/photo_manager.dart';
import '../functions/global_variables.dart';
import 'videos_from_folders.dart';

class FolderPage extends StatefulWidget {
  const FolderPage({super.key, required this.foldersWithVideos});
  final List<AssetPathEntity> foldersWithVideos;

  @override
  State<FolderPage> createState() => _FolderPageState();
}

class _FolderPageState extends State<FolderPage> {
  bool isGridViewForFolder = false;
  bool statusForFolder = false;
  void toggleView() {
    setState(() {
      isGridViewForFolder = !isGridViewForFolder;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: widget.foldersWithVideos.isEmpty
          ? const Center(
              child: Text("No videos found", style: TextStyle(color: Colors.white, fontSize: 18)),
            )
          : Padding(
              padding: const EdgeInsets.all(4.0),
              child: SafeArea(
                child: Column(
                  children: [
                    Container(
                      height: 58,
                      margin: const EdgeInsets.only(top: 7),
                      child: ListTile(
                        leading: Text(
                          'NOVA ',
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
                                toggleView();
                              },
                              child: Icon(
                                isGridViewForFolder
                                    ? Icons.list
                                    : Icons.grid_on,
                                color: colorWhite,
                                size: 22,
                              ),
                            ),
                            Container(
                              margin:
                                  const EdgeInsets.only(right: 13, left: 16),
                              child: Icon(
                                Icons.format_line_spacing_sharp,
                                color: colorWhite,
                                size: 23,
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                showSearch(
                                    context: context,
                                    delegate: FolderSearchDelegate(
                                        folders: widget.foldersWithVideos,
                                        context: context));
                              },
                              child: Icon(
                                Icons.search,
                                color: colorWhite,
                                size: 23,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: isGridViewForFolder
                          ? ListView.builder(
                              itemCount: widget.foldersWithVideos.length,
                              itemBuilder: (context, index) {
                                final folder = widget.foldersWithVideos[index];
                                return ListTile(
                                  title: Text(
                                    folder.name,
                                    style: const TextStyle(
                                        fontFamily: 'Inter',
                                        color: Colors.white),
                                  ),
                                  subtitle: FutureBuilder<int>(
                                    future: folder.assetCountAsync,
                                    builder: (context, snapshot) {
                                      if (snapshot.hasData) {
                                        return Text(
                                          '${snapshot.data!} videos',
                                          style: const TextStyle(
                                              color: Colors.white),
                                        );
                                      } else {
                                        return const Text('');
                                      }
                                    },
                                  ),
                                  onTap: () async {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              VideosFromFolder(
                                                folder: folder,
                                              )),
                                    );
                                  },
                                );
                              },
                            )
                          : GridView.builder(
                              itemCount: widget.foldersWithVideos.length,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 1,
                                mainAxisSpacing: 3,
                              ),
                              itemBuilder: (context, index) {
                                return GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              VideosFromFolder(
                                            folder:
                                                widget.foldersWithVideos[index],
                                          ),
                                        ),
                                      );
                                    },
                                    child: InkWell(
                                      child: ListView(
                                        children: [
                                          Icon(
                                            Icons.folder,
                                            color: colorWhite,
                                            size: 90,
                                          ),
                                          SizedBox(
                                            height: 45,
                                            width: double.infinity / 3,
                                            child: Container(
                                              margin: const EdgeInsets.only(
                                                  left: 30),
                                              child: Text(
                                                widget.foldersWithVideos[index]
                                                    .name,
                                                style: TextStyle(
                                                    color: colorWhite),
                                              ),
                                            ),
                                          )
                                        ],
                                      ),
                                    ));
                              },
                            ),
                    )
                  ],
                ),
              ),
            ),
    );
  }
}
