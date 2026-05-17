// ignore_for_file: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:photo_manager/photo_manager.dart';

import 'new_playlist_class.dart';
import 'package:nova_videoplayer/functions/app_logger.dart';

Color colorBlack = Colors.black;
Color colorWhite = Colors.white;
Color colorGreen = const Color(0xFF4FEC68);

List<String> allTheFavoriteVideosList = [];

ValueNotifier<List<NovaPlaylist>> playListnotifier = ValueNotifier([]);

// Shorts PiP State
ValueNotifier<Player?> activeShortsPlayer = ValueNotifier(null);
ValueNotifier<VideoController?> activeShortsVideoController = ValueNotifier(null);
ValueNotifier<bool> isShortsScrolling = ValueNotifier(false);
ValueNotifier<bool> isShortsTabActive = ValueNotifier(false);
ValueNotifier<bool> isShortsAutoPlay = ValueNotifier(false);
ValueNotifier<bool> isShortsPiPMode = ValueNotifier(false);
ValueNotifier<bool> isShortsPiPError = ValueNotifier(false);

// Main Video PiP State
ValueNotifier<bool> isMainPiPMode = ValueNotifier(false);
ValueNotifier<Player?> activeMainPlayer = ValueNotifier(null);
ValueNotifier<VideoController?> activeMainVideoController = ValueNotifier(null);
ValueNotifier<List<AssetEntity>> mainPiPVideoList = ValueNotifier([]);
ValueNotifier<int> mainPiPVideoIndex = ValueNotifier(0);
ValueNotifier<int> mainPipActionTrigger = ValueNotifier(0); // 1 for next, 2 for prev

ValueNotifier<int> homeTabNotifier = ValueNotifier(0);
ValueNotifier<int> pipActionTrigger = ValueNotifier(0);


// Hardware Capability State
enum DeviceTier { lowEnd, midRange, flagship }
DeviceTier deviceTier = DeviceTier.midRange;
double totalRamGb = 0.0;

// Alias — keeps all existing isLowEndDevice usages compiling:
bool get isLowEndDevice => deviceTier == DeviceTier.lowEnd;

Future<void> checkHardwareCapability() async {
  try {
    const platform = MethodChannel('com.thenowavideoplayer.app/hardware');
    final String ramStr = await platform.invokeMethod('getTotalRAM');
    final int totalRamInBytes = int.parse(ramStr);
    final double totalRamInGB = totalRamInBytes / (1024 * 1024 * 1024);
    debugPrint("Total System RAM: ${totalRamInGB.toStringAsFixed(2)} GB");
    
    totalRamGb = totalRamInGB; // store before the check

    if (totalRamInGB <= 2.0) {
      deviceTier = DeviceTier.lowEnd;
      debugPrint("Device classified as LOW END. Enforcing strict video decoder limits.");
    } else if (totalRamInGB <= 4.0) {
      deviceTier = DeviceTier.midRange;
      debugPrint("Device classified as MID RANGE. Enabling moderate background preloading.");
    } else {
      deviceTier = DeviceTier.flagship;
      debugPrint("Device classified as FLAGSHIP. Enabling full layout preloading.");
    }
  } catch (e) {
    debugPrint("Failed to get RAM: $e");
    // Default to strict lowEnd if we can't tell, to be safe
    deviceTier = DeviceTier.lowEnd;
  }
}

// void addPlaylist(String playlistName,Playlist playlist)async {

//   final playlistDB=await Hive.openBox<Playlist>('playlist_db');
//     if (playlistDB.values.any((Playlist) => Playlist.name==playlistName)) {
//      print('allready exist');
//     }else{
//           final id = await playlistDB.add(playlist);
//           playlist.uniqueId=id;

//     }

//   if (playListnotifier.value.any((playlist) => playlist.name == playlistName)) {
//      print('already exist');
//     return;
//   }  else{
//       final newPlaylist = Playlist(name: playlistName);
//   playListnotifier.value.add(newPlaylist);
//   playListnotifier.notifyListeners();
//   }

// }
   

late List<AssetEntity> theAllVideosListFortheSelectionPage;

late List<AssetEntity> theAllShortVideos;

Future<List<AssetEntity>> getShortsVideos(List<AssetEntity> videos) async {
  final result = <AssetEntity>[];

  final settingsBox = Hive.box<dynamic>('appSettings');
  final minDuration = settingsBox.get('shortsMinDuration', defaultValue: 2.0) as double;
  final maxDuration = settingsBox.get('shortsMaxDuration', defaultValue: 180.0) as double;
  final includeHorizontal = settingsBox.get('shortsIncludeHorizontal', defaultValue: false) as bool;

  for (final video in videos) {
    final int durationSecs = video.videoDuration.inSeconds > 0
        ? video.videoDuration.inSeconds
        : video.duration;

    // Use orientatedWidth/Height — photo_manager applies rotation metadata
    // so these reflect actual display dimensions, not raw sensor dimensions
    final int displayWidth = video.orientatedWidth;
    final int displayHeight = video.orientatedHeight;

    final bool isPortrait;
    if (displayWidth == 0 || displayHeight == 0) {
      isPortrait = true; // unknown — assume portrait
    } else {
      isPortrait = displayHeight > displayWidth;
    }

    if (!includeHorizontal && !isPortrait) {
      continue;
    }

    if (durationSecs == 0 || (durationSecs >= minDuration && durationSecs <= maxDuration)) {
      result.add(video);
    }
  }

  AppLogger.log('getShortsVideos: ${videos.length} checked, ${result.length} found');
  result.shuffle();
  return result;
}

// void addToPlaylist(PlayListModel value)async{

//    playListnotifier.value.add(value);
//     playListnotifier.notifyListeners();
//     print('added');

// }
getAllPlayListFromDb() async {
  final playlistDB = await Hive.openBox<NovaPlaylist>('playlist_db');
  playListnotifier.value.clear();
  playListnotifier.value.addAll(playlistDB.values);
  playListnotifier.notifyListeners();
}

// List<AssetEntity> getAssetsFromIds(List<String> ids) {
//   final List<AssetEntity> assets = [];
//   for (String id in ids) {
//     final AssetEntity asset = AssetEntity.fromId(id) as AssetEntity;
//     assets.add(asset);
//   }
//   return assets;
// }
List<AssetEntity> getAssetsFromIds(
    List<AssetEntity> allVideos, List<String> ids) {
  List<AssetEntity> playlistVideos = [];

  for (String id in ids) {
    AssetEntity? video = allVideos.firstWhere((video) => video.id == id);
    playlistVideos.add(video);
  }

  return playlistVideos;
}
