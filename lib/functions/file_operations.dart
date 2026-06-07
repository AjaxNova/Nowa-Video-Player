import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:nova_videoplayer/functions/global_variables.dart';
import 'package:nova_videoplayer/functions/app_logger.dart';

class FileOperations {

  /// Delete a video. Uses direct file delete if MANAGE_EXTERNAL_STORAGE is granted, otherwise falls back to MediaStore confirmation dialog.
  static Future<bool> deleteVideo({
    required BuildContext context,
    required AssetEntity asset,
  }) async {
    try {
      // Check if we have MANAGE_EXTERNAL_STORAGE
      // If yes — delete directly and silently, no system dialog
      final hasManagePermission = await Permission.manageExternalStorage.isGranted;

      if (hasManagePermission) {
        // Silent delete — direct file deletion, bypasses MediaStore dialog
        final file = await asset.file;
        if (file == null) return false;
        if (await file.exists()) {
          await file.delete(); // actual file deletion
        }
        try {
          await PhotoManager.editor.deleteWithIds([asset.id]); // MediaStore sync — ignore if fails
        } catch (_) {} // file already gone, MediaStore cleanup is best-effort
        return true; // always return true if we got this far
      } else {
        // Fallback — MediaStore delete with system dialog
        final result = await PhotoManager.editor.deleteWithIds([asset.id]);
        return result.isNotEmpty;
      }
    } catch (e) {
      AppLogger.logError('FileOperations.deleteVideo failed', e, StackTrace.current);
      return false;
    }
  }

  /// Call this once before the first delete attempt.
  /// Shows a one-time explanation dialog then requests MANAGE_EXTERNAL_STORAGE.
  /// Returns true if permission granted.
  static Future<bool> requestManageStoragePermission(BuildContext context) async {
    // Already granted — nothing to do
    if (await Permission.manageExternalStorage.isGranted) return true;

    // Show explanation first — one time only
    final shouldRequest = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161616),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text(
          'Storage Access',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'To delete videos without extra confirmation steps, Nowa needs full storage access. This is a one-time request.',
          style: TextStyle(color: Colors.white60, fontSize: 12.sp, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Not now',
              style: TextStyle(color: Colors.white38, fontSize: 12.sp),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Allow',
              style: TextStyle(
                color: colorGreen,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldRequest != true) return false;

    // Request the permission — takes user to Android settings
    final status = await Permission.manageExternalStorage.request();
    return status.isGranted;
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
