import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nova_videoplayer/functions/new_playlist_db_functions.dart';
import 'package:nova_videoplayer/screen/newPlaylistPage/plaaylist_new.dart';

import '../../functions/global_variables.dart';
import '../../functions/new_playlist_class.dart';

class PlaylistPage extends StatefulWidget {
  const PlaylistPage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _PlaylistPageState createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  final TextEditingController _playlistNameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colorBlack,
      appBar: AppBar(
        backgroundColor: colorBlack,
        title: const Text('Playlists'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 20),
            child: IconButton(
                icon: Icon(color: colorWhite, Icons.add),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text('New Playlist'),
                        content: TextField(
                          controller: _playlistNameController,
                          decoration: const InputDecoration(
                            hintText: 'Enter playlist name',
                          ),
                        ),
                        actions: <Widget>[
                          TextButton(
                            onPressed: () {
                              String name = _playlistNameController.text.trim();
                              final newPlaylist =
                                  NovaPlaylist(name: name, videoIds: []);
                              final datas = PlaylistDb.playlistDb.values
                                  .map((e) => e.name.trim())
                                  .toList();
                              if (name.isNotEmpty) {
                                if (datas.contains(newPlaylist.name)) {
                                } else {
                                  PlaylistDb.addPlaylist(newPlaylist);
                                }
                                //  playListnotifier.value.add(playlist);
                                //  playListnotifier.notifyListeners();
                                _playlistNameController.clear();
                              }
                              Navigator.pop(context);
                            },
                            child: const Text('Create'),
                          ),
                          TextButton(
                            onPressed: () {
                              _playlistNameController.clear();
                              Navigator.pop(context);
                            },
                            child: const Text('Cancel'),
                          ),
                        ],
                      );
                    },
                  );
                }),
          )
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: Hive.box<NovaPlaylist>('playlistDb').listenable(),
        builder: (BuildContext ctx, Box<NovaPlaylist> playlists, Widget? child) {
          return Hive.box<NovaPlaylist>('playlistDb').isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'No playlist Found',
                        style: TextStyle(color: colorWhite),
                      ),
                      ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: colorGreen),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: const Text('New Playlist'),
                                  content: TextField(
                                    controller: _playlistNameController,
                                    decoration: const InputDecoration(
                                      hintText: 'Enter playlist name',
                                    ),
                                  ),
                                  actions: <Widget>[
                                    TextButton(
                                      onPressed: () {
                                        String name =
                                            _playlistNameController.text.trim();
                                        final newPlaylist =
                                            NovaPlaylist(name: name, videoIds: []);
                                        final datas = PlaylistDb
                                            .playlistDb.values
                                            .map((e) => e.name.trim())
                                            .toList();
                                        if (name.isNotEmpty) {
                                          if (datas
                                              .contains(newPlaylist.name)) {
                                          } else {
                                            PlaylistDb.addPlaylist(newPlaylist);
                                          }
                                          //  playListnotifier.value.add(playlist);
                                          //  playListnotifier.notifyListeners();
                                          _playlistNameController.clear();
                                        }
                                        Navigator.pop(context);
                                      },
                                      child: const Text('Create'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        _playlistNameController.clear();
                                        Navigator.pop(context);
                                      },
                                      child: const Text('Cancel'),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                          child: const Text('Add new playlist')),
                    ],
                  ),
                )
              : ListView.builder(
                  itemBuilder: (context, index) {
                    final allPLaylists = playlists.values.toList()[index];
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ListTile(
                        onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => PlaylistDetailsPage(
                                playlist: allPLaylists, playlistKey: index),
                          ));
                        },
                        title: Text(
                          allPLaylists.name,
                          style: TextStyle(color: colorWhite),
                        ),
                        subtitle: SizedBox(
                            height: 30,
                            child: Text(
                                '${allPLaylists.videoIds.length.toString()} videos',
                                style: TextStyle(color: colorWhite))),
                        trailing: PopupMenuButton(
                          color: colorWhite,
                          icon: const Icon(
                            Icons.more_vert,
                            color: Colors.white,
                          ),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 1,
                              child: Text(
                                'Edit',
                                style: TextStyle(
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            const PopupMenuItem(
                              value: 2,
                              child: Text(
                                'delete',
                                style: TextStyle(color: Colors.black),
                              ),
                            )
                          ],
                          onSelected: (value) {
                            if (value == 1) {
                              editPlaylistName(context, allPLaylists, index);
                            } else if (value == 2) {
                              deletePlaylist(context, playlists, index);
                            }
                          },
                        ),
                      ),
                    );
                  },
                  itemCount: playlists.length,
                );
        },
      ),
    );
  }
}

TextEditingController nameController = TextEditingController();
final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

Future<dynamic> editPlaylistName(
    BuildContext context, NovaPlaylist data, int index) {
  nameController = TextEditingController(text: data.name);
  return showDialog(
    context: context,
    builder: (ctx) => SimpleDialog(
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10))),
      // backgroundColor: Color.fromARGB(255, 52, 6, 105),
      backgroundColor: Colors.indigoAccent.shade100,
      children: [
        SimpleDialogOption(
          child: Text(
            "Edit Playlist ${data.name}",
            style: TextStyle(
                color: colorBlack, fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(
          height: 8,
        ),
        SimpleDialogOption(
          child: Form(
            key: _formKey,
            child: TextFormField(
              textAlign: TextAlign.center,
              controller: nameController,
              maxLength: 15,
              decoration: InputDecoration(
                  counterStyle: const TextStyle(color: Colors.white),
                  fillColor: Colors.white.withOpacity(0.7),
                  filled: true,
                  border: OutlineInputBorder(
                      borderSide: BorderSide.none,
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.only(left: 15, top: 5)),
              style: const TextStyle(
                  color: Color.fromARGB(255, 0, 0, 0),
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return "Enter your playlist name";
                } else {
                  return null;
                }
              },
            ),
          ),
        ),
        const SizedBox(
          height: 8,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SimpleDialogOption(
              onPressed: () {
                Navigator.of(context).pop();
                nameController.clear();
              },
              child: const Text(
                'Cancel',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            SimpleDialogOption(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  final name = nameController.text.trim();
                  if (name.isEmpty) {
                    return;
                  } else {
                    final playlistName = NovaPlaylist(name: name, videoIds: data.videoIds);
                    PlaylistDb.editList(index, playlistName);
                  }
                  nameController.clear();
                  Navigator.pop(context);
                }
              },
              child: const Text(
                'Update',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Future<dynamic> deletePlaylist(
    BuildContext context, Box<NovaPlaylist> musicList, int index) {
  return showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: Colors.indigoAccent.shade100,
        title: const Text(
          'Delete Playlist',
          style: TextStyle(
            color: Colors.white,
          ),
        ),
        content: const Text('Are you sure you want to delete this playlist?',
            style: TextStyle(
              color: Colors.white,
            )),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(
              'No',
              style: TextStyle(color: colorWhite),
            ),
          ),
          TextButton(
            onPressed: () {
              musicList.deleteAt(index);
              Navigator.pop(context);
              const snackBar = SnackBar(
                backgroundColor: Colors.black,
                content: Text(
                  'Playlist is deleted',
                  style: TextStyle(color: Colors.white),
                ),
                duration: Duration(milliseconds: 350),
              );
              ScaffoldMessenger.of(context).showSnackBar(snackBar);
            },
            child: Text('Yes', style: TextStyle(color: colorWhite)),
          ),
        ],
      );
    },
  );
}
