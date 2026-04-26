import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:photo_manager/photo_manager.dart';

class FavoriteDb {
  static bool isInitialized = false;
  static final favoriteDB = Hive.box<String>('FavoriteDB');
  static ValueNotifier<List<AssetEntity>> favoriteVideos = ValueNotifier([]);

  static initialize(List<AssetEntity> videos) {
    if (isInitialized) return;
    favoriteVideos.value.clear();
    for (AssetEntity video in videos) {
      if (isFavor(video)) {
        favoriteVideos.value.add(video);
      }
    }
    isInitialized = true;
    // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
    favoriteVideos.notifyListeners();
  }

  static isFavor(AssetEntity video) {
    if (favoriteDB.values.contains(video.id)) {
      return true;
    }
    return false;
  }

  static add(AssetEntity video) async {
    favoriteDB.add(video.id);
    favoriteVideos.value.add(video);
    // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
    FavoriteDb.favoriteVideos.notifyListeners();
  }

  static delete(String id) async {
    int deletekey = 0;
    if (!favoriteDB.values.contains(id)) {
      return;
    }
    final Map<dynamic, String> favorMap = favoriteDB.toMap();
    favorMap.forEach((key, value) {
      if (value == id) {
        deletekey = key;
      }
    });
    favoriteDB.delete(deletekey);
    favoriteVideos.value.removeWhere((song) => song.id == id);
  }

  static clear() async {
    FavoriteDb.favoriteVideos.value.clear();
  }
}
