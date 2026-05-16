import 'package:flutter/cupertino.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:nova_videoplayer/functions/new_playlist_class.dart';

class PlaylistDb {
  static ValueNotifier<List<NovaPlaylist>> playlistNotifiier = ValueNotifier([]);
  static Box<NovaPlaylist> get playlistDb => Hive.box<NovaPlaylist>('playlistDb');

  static Future<void> addPlaylist(NovaPlaylist value) async {
    final playlistDb = Hive.box<NovaPlaylist>('playlistDb');
    await playlistDb.add(value);
    playlistNotifiier.value.add(value);
  }

  static Future<void> getAllPlaylist() async {
    final playlistDb = Hive.box<NovaPlaylist>('playlistDb');
    playlistNotifiier.value.clear();
    playlistNotifiier.value.addAll(playlistDb.values);
    // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
    playlistNotifiier.notifyListeners();
  }

  static Future<void> deletePlaylist(int index) async {
    final playlistDb = Hive.box<NovaPlaylist>('playlistDb');
    await playlistDb.deleteAt(index);
    getAllPlaylist();
  }

  static Future<void> editList(int index, NovaPlaylist value) async {
    final playlistDb = Hive.box<NovaPlaylist>('playlistDb');
    await playlistDb.putAt(index, value);
    getAllPlaylist();
  }
}
