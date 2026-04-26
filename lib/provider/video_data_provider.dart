import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

class VideoDataProvider with ChangeNotifier {
  List<AssetEntity> allVideosList = [];
  List<AssetPathEntity>? allFoldersList;
  final Map<String, Uint8List> _thumbnailCache = {};

  // Get thumbnail with caching
  Future<Uint8List?> getThumbnail(AssetEntity asset) async {
    if (_thumbnailCache.containsKey(asset.id)) {
      return _thumbnailCache[asset.id];
    }
    final data = await asset.thumbnailData;
    if (data != null) {
      _thumbnailCache[asset.id] = data;
    }
    return data;
  }

  // Clear cache if memory is low
  void clearCache() {
    _thumbnailCache.clear();
    notifyListeners();
  }

  Future<void> initialize(BuildContext context) async {
    try {
      final PermissionState ps = await PhotoManager.requestPermissionExtend(
        requestOption: const PermissionRequestOption(
          androidPermission: AndroidPermission(
            type: RequestType.video,
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
        allVideosList = [];
        allFoldersList = [];
        notifyListeners();
        return;
      }

      final recentAlbum = albums.first;
      final assetCount = await recentAlbum.assetCountAsync;

      if (assetCount == 0) {
        allVideosList = [];
        allFoldersList = albums;
        notifyListeners();
        return;
      }

      // Still fetching all for now to keep global lists working, 
      // but paged loading would be better for massive libraries.
      final recentAssets =
          await recentAlbum.getAssetListRange(start: 0, end: assetCount);

      allVideosList = recentAssets.toList();
      allFoldersList = albums;
      notifyListeners();

      debugPrint('✅ Loaded ${allVideosList.length} videos');
    } catch (e) {
      debugPrint('Error in initialize: $e');
      allVideosList = [];
      allFoldersList = [];
      notifyListeners();
    }
  }

  // Deprecated: used by old screens
  Future<void> fetchvideos(BuildContext context) async {
    await initialize(context);
    // Navigation should be handled by the screen, not the provider
  }
}
