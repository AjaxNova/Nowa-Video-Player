import 'package:flutter/material.dart';
import 'package:nova_videoplayer/screen/all_videos.dart';
import 'package:photo_manager/photo_manager.dart';

class VideoDataProvider with ChangeNotifier {
  List<AssetEntity> allVideosList = [];
  List<AssetPathEntity>? allFoldersList;

  Future<void> fetchvideos(BuildContext context) async {
    try {
      // Check permission first - REQUEST VIDEOS ONLY
      final PermissionState ps = await PhotoManager.requestPermissionExtend(
        requestOption: const PermissionRequestOption(
          androidPermission: AndroidPermission(
            type: RequestType.video, // Only videos
            mediaLocation: false,
          ),
        ),
      );

      if (!ps.isAuth && !ps.hasAccess && !ps.isLimited) {
        debugPrint('Permission denied');
        return;
      }

      final albums =
          await PhotoManager.getAssetPathList(type: RequestType.video);

      if (albums.isEmpty) {
        debugPrint('No video albums found');
        allVideosList = [];
        allFoldersList = [];
        notifyListeners();
        return;
      }

      final recentAlbum = albums.first;
      final assetCount = await recentAlbum.assetCountAsync;

      if (assetCount == 0) {
        debugPrint('No videos in recent album');
        allVideosList = [];
        allFoldersList = albums;
        notifyListeners();
        return;
      }

      final recentAssets =
          await recentAlbum.getAssetListRange(start: 0, end: assetCount);

      allVideosList = recentAssets.toList();
      allFoldersList = albums;
      notifyListeners();

      debugPrint(
          '✅ Loaded ${allVideosList.length} videos from ${allFoldersList?.length} folders');

      // Navigate to AllVideosPage with ACTUAL data
      Future.delayed(
        const Duration(seconds: 1),
        () {
          if (context.mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => AllVideosPage(
                  assets: allVideosList, // ✅ Pass actual videos!
                  foldersWithVideos:
                      allFoldersList ?? [], // ✅ Pass actual folders!
                ),
              ),
            );
          }
        },
      );
    } catch (e) {
      debugPrint('Error in fetchvideos: $e');
      allVideosList = [];
      allFoldersList = [];
      notifyListeners();
    }
  }
}
