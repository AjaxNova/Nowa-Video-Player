import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

part 'new_playlist_class.g.dart';

@HiveType(typeId: 1)
class NovaPlaylist extends HiveObject {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final List<String> videoIds;

  NovaPlaylist({required this.name, required this.videoIds});

  bool isValueIn(String id) {
    return videoIds.contains(id);
  }

  void add(String id) {
    if (!videoIds.contains(id)) {
      videoIds.add(id);
      save();
    }
  }

  void deleteData(String id) {
    videoIds.remove(id);
    save();
  }
}
