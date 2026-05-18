import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

class FileOperations {

  /// Delete a video. Uses MediaStore on API 30+, direct delete on API 21-29.
  /// Returns true on success, false on failure or user cancellation.
  static Future<bool> deleteVideo({
    required BuildContext context,
    required AssetEntity asset,
  }) async {
    try {
      final result = await PhotoManager.editor.deleteWithIds([asset.id]);
      return result.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Copy a video file to a destination folder path.
  /// Returns the new File on success, null on failure.
  static Future<File?> copyVideo({
    required AssetEntity asset,
    required String destinationFolderPath,
  }) async {
    try {
      final file = await asset.file;
      if (file == null) return null;
      final destDir = Directory(destinationFolderPath);
      if (!await destDir.exists()) await destDir.create(recursive: true);
      final destPath = '$destinationFolderPath/${asset.title ?? asset.id}';
      return await file.copy(destPath);
    } catch (e) {
      return null;
    }
  }

  /// Move a video — copy then delete original.
  /// Returns true on full success.
  static Future<bool> moveVideo({
    required BuildContext context,
    required AssetEntity asset,
    required String destinationFolderPath,
  }) async {
    final copied = await copyVideo(
      asset: asset,
      destinationFolderPath: destinationFolderPath,
    );
    if (copied == null) return false;
    return await deleteVideo(context: context, asset: asset);
  }

  /// Fetch all folders that contain videos from MediaStore.
  /// Returns list of maps with: path, name, videoCount, totalSizeBytes.
  static Future<List<Map<String, dynamic>>> getVideoFolders() async {
    final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: RequestType.video,
      filterOption: FilterOptionGroup(
        orders: [const OrderOption(type: OrderOptionType.createDate, asc: false)],
      ),
    );

    final folders = <Map<String, dynamic>>[];
    for (final album in albums) {
      if (album.isAll) continue; // skip the "All" virtual album
      final count = await album.assetCountAsync;
      if (count == 0) continue;
      folders.add({
        'name': album.name,
        'path': album.id, // use album.id as the reference
        'album': album,
        'videoCount': count,
        'totalSizeBytes': 0, // hydrated lazily if needed
      });
    }
    return folders;
  }

  /// Format bytes into human readable string
  static String formatSize(int bytes) {
    if (bytes <= 0) return '—';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Format duration in seconds to mm:ss
  static String formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
