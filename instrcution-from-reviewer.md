Developer Instructions — Shorts Menu Sheet Redesign
Context
Replace the current _openSettingsMenu() bottom sheet in shorts_try_two.dart with a fully redesigned sheet. Same entry point (the ⋮ button), same showModalBottomSheet call, but completely new content. No new files needed — everything goes inside _openSettingsMenu(). A new file_operations.dart handles the actual delete/copy/move logic.

File 1 — lib/functions/file_operations.dart (new file)
Create this file. It handles all file operations with correct Android API level handling.
dartimport 'dart:io';
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

File 2 — shorts_try_two.dart — replace _openSettingsMenu()
Replace the entire _openSettingsMenu() method with this:
dartvoid _openSettingsMenu() {
  final video = widget.video;

  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF111111),
    isScrollControlled: true, // allows sheet to size to content
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 32.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── DRAG HANDLE ──
                Center(
                  child: Container(
                    width: 36.w,
                    height: 3.5.h,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),
                SizedBox(height: 20.h),

                // ── VIDEO INFO STRIP ──
                Container(
                  padding: EdgeInsets.all(12.r),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06), width: 0.5),
                  ),
                  child: Row(
                    children: [
                      // Thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8.r),
                        child: _cachedThumbnail != null
                            ? Image.memory(
                                _cachedThumbnail!,
                                width: 52.w,
                                height: 52.w,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: 52.w,
                                height: 52.w,
                                color: Colors.white.withValues(alpha: 0.05),
                                child: Icon(Icons.movie_rounded, color: Colors.white12, size: 20.sp),
                              ),
                      ),
                      SizedBox(width: 12.w),

                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Filename
                            Text(
                              video.title ?? 'Unknown',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 6.h),

                            // Meta pills row
                            Wrap(
                              spacing: 6.w,
                              children: [
                                _MetaPill(label: FileOperations.formatSize(video.size)),
                                _MetaPill(label: FileOperations.formatDuration(video.duration)),
                                if (video.orientatedWidth > 0)
                                  _MetaPill(label: '${video.orientatedHeight}p'),
                              ],
                            ),
                            SizedBox(height: 6.h),

                            // Location
                            Row(
                              children: [
                                Icon(Icons.folder_outlined, size: 11.sp, color: Colors.white24),
                                SizedBox(width: 4.w),
                                Expanded(
                                  child: Text(
                                    video.relativePath ?? '—',
                                    style: TextStyle(color: Colors.white24, fontSize: 10.sp),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20.h),

                // ── ORGANIZE LABEL ──
                Padding(
                  padding: EdgeInsets.only(left: 4.w, bottom: 10.h),
                  child: Text(
                    'ORGANIZE',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.2),
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),

                // ── COPY ROW ──
                _ActionRow(
                  iconBg: const Color(0xFF0A1A0E),
                  icon: Icons.copy_all_rounded,
                  iconColor: const Color(0xFF1D9E75),
                  label: 'Copy to folder',
                  subtitle: 'Keep original in place',
                  onTap: () {
                    Navigator.pop(ctx);
                    _openFolderPicker(mode: 'copy');
                  },
                ),
                SizedBox(height: 8.h),

                // ── MOVE ROW ──
                _ActionRow(
                  iconBg: const Color(0xFF0A0E1A),
                  icon: Icons.drive_file_move_outline_rounded,
                  iconColor: const Color(0xFF378ADD),
                  label: 'Move to folder',
                  subtitle: 'Remove from current location',
                  onTap: () {
                    Navigator.pop(ctx);
                    _openFolderPicker(mode: 'move');
                  },
                ),
                SizedBox(height: 8.h),

                // ── DELETE ROW ──
                _ActionRow(
                  iconBg: const Color(0xFF1A0505),
                  icon: Icons.delete_outline_rounded,
                  iconColor: const Color(0xFFE24B4A),
                  label: 'Delete video',
                  subtitle: 'Permanently remove this file',
                  labelColor: const Color(0xFFE24B4A),
                  rowBg: const Color(0xFF160A0A),
                  rowBorder: const Color(0xFF2A1010),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openDeleteConfirmation();
                  },
                ),
                SizedBox(height: 24.h),

                // ── DIVIDER WITH PLAYBACK LABEL ──
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.06), thickness: 0.5)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12.w),
                      child: Text(
                        'PLAYBACK',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.2),
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.06), thickness: 0.5)),
                  ],
                ),
                SizedBox(height: 16.h),

                // ── AUTOPLAY ROW ──
                ValueListenableBuilder<bool>(
                  valueListenable: isShortsAutoPlay,
                  builder: (context, autoPlay, _) {
                    return _ActionRow(
                      iconBg: const Color(0xFF0E1A0E),
                      icon: Icons.play_circle_outline_rounded,
                      iconColor: colorGreen,
                      label: 'Auto play',
                      subtitle: 'Swipe automatically',
                      trailing: Switch(
                        value: autoPlay,
                        onChanged: (val) => isShortsAutoPlay.value = val,
                        activeColor: colorGreen,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onTap: () => isShortsAutoPlay.value = !autoPlay,
                    );
                  },
                ),
                SizedBox(height: 8.h),

                // ── PiP ROW ──
                _ActionRow(
                  iconBg: const Color(0xFF0E1A0E),
                  icon: Icons.picture_in_picture_alt_rounded,
                  iconColor: colorGreen,
                  label: 'Picture in picture',
                  subtitle: 'Watch while browsing',
                  onTap: () {
                    Navigator.pop(ctx);
                    isShortsPiPMode.value = true;
                    homeTabNotifier.value = 0;
                  },
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

New private widgets — add at the bottom of shorts_try_two.dart (outside all classes)
dart// ── Reusable meta pill ──
class _MetaPill extends StatelessWidget {
  final String label;
  const _MetaPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(4.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 0.5),
      ),
      child: Text(label, style: TextStyle(color: Colors.white38, fontSize: 9.sp)),
    );
  }
}

// ── Reusable action row ──
class _ActionRow extends StatelessWidget {
  final Color iconBg;
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final Color? labelColor;
  final Color? rowBg;
  final Color? rowBorder;
  final Widget? trailing;
  final VoidCallback onTap;

  const _ActionRow({
    required this.iconBg,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.labelColor,
    this.rowBg,
    this.rowBorder,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: rowBg ?? Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color: rowBorder ?? Colors.white.withValues(alpha: 0.06),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            // Icon circle
            Container(
              width: 34.w,
              height: 34.w,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 16.sp),
            ),
            SizedBox(width: 12.w),

            // Labels
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: labelColor ?? Colors.white.withValues(alpha: 0.85),
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: labelColor != null
                          ? labelColor!.withValues(alpha: 0.4)
                          : Colors.white.withValues(alpha: 0.22),
                      fontSize: 10.sp,
                    ),
                  ),
                ],
              ),
            ),

            // Trailing widget or chevron
            trailing ??
                Icon(Icons.chevron_right_rounded,
                    color: Colors.white.withValues(alpha: 0.15), size: 18.sp),
          ],
        ),
      ),
    );
  }
}

Delete confirmation — _openDeleteConfirmation()
Add this method to _VideoPLayerPageForShortsState:
dartvoid _openDeleteConfirmation() {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF111111),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 32.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // drag handle
          Container(
            width: 36.w, height: 3.5.h,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(height: 24.h),

          // thumbnail + info row (same as main sheet)
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8.r),
                child: _cachedThumbnail != null
                    ? Image.memory(_cachedThumbnail!, width: 48.w, height: 48.w, fit: BoxFit.cover)
                    : Container(width: 48.w, height: 48.w, color: Colors.white.withValues(alpha: 0.05)),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.video.title ?? 'Unknown',
                      style: TextStyle(color: Colors.white70, fontSize: 12.sp, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      FileOperations.formatSize(widget.video.size),
                      style: TextStyle(color: Colors.white24, fontSize: 10.sp),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),

          // Warning
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: const Color(0xFF1A0505),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: const Color(0xFF2A1010), width: 0.5),
            ),
            child: Column(
              children: [
                Text(
                  'Permanently delete this video?',
                  style: TextStyle(color: const Color(0xFFE24B4A), fontSize: 13.sp, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 4.h),
                Text(
                  'This cannot be undone.',
                  style: TextStyle(color: Colors.red.withValues(alpha: 0.4), fontSize: 10.sp),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),

          // Buttons row
          Row(
            children: [
              // Cancel
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    height: 44.h,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 0.5),
                    ),
                    child: Center(
                      child: Text('Cancel', style: TextStyle(color: Colors.white38, fontSize: 13.sp, fontWeight: FontWeight.w500)),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10.w),

              // Delete
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    Navigator.pop(ctx);
                    final success = await FileOperations.deleteVideo(
                      context: context,
                      asset: widget.video,
                    );
                    if (success && mounted) {
                      widget.onVideoDeleted?.call(widget.video);
                    } else if (!success && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Could not delete video', style: TextStyle(fontSize: 12.sp)),
                          backgroundColor: const Color(0xFF1A0505),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  child: Container(
                    height: 44.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A0505),
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(color: const Color(0xFF7F1F1F), width: 0.5),
                    ),
                    child: Center(
                      child: Text('Delete', style: TextStyle(color: const Color(0xFFE24B4A), fontSize: 13.sp, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Folder picker — _openFolderPicker()
Add this method to _VideoPLayerPageForShortsState:
dartvoid _openFolderPicker({required String mode}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF111111),
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
    ),
    builder: (ctx) => _FolderPickerSheet(
      video: widget.video,
      mode: mode,
      onComplete: (success) {
        if (success && mode == 'move' && mounted) {
          widget.onVideoDeleted?.call(widget.video);
        }
      },
    ),
  );
}
Then create _FolderPickerSheet as a private StatefulWidget at the bottom of the file:
dartclass _FolderPickerSheet extends StatefulWidget {
  final AssetEntity video;
  final String mode; // 'copy' or 'move'
  final Function(bool success) onComplete;

  const _FolderPickerSheet({
    required this.video,
    required this.mode,
    required this.onComplete,
  });

  @override
  State<_FolderPickerSheet> createState() => _FolderPickerSheetState();
}

class _FolderPickerSheetState extends State<_FolderPickerSheet> {
  List<Map<String, dynamic>> _folders = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  bool _operating = false;
  String _search = '';
  Map<String, dynamic>? _selected;

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    final folders = await FileOperations.getVideoFolders();
    if (mounted) setState(() { _folders = folders; _filtered = folders; _loading = false; });
  }

  void _onSearch(String q) {
    setState(() {
      _search = q;
      _filtered = q.isEmpty
          ? _folders
          : _folders.where((f) => (f['name'] as String).toLowerCase().contains(q.toLowerCase())).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.mode == 'copy' ? 'Copy' : 'Move';
    final buttonLabel = widget.mode == 'copy' ? 'Copy here' : 'Move here';

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollController) => Column(
        children: [
          // Fixed header
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 0),
            child: Column(
              children: [
                // drag handle
                Container(
                  width: 36.w, height: 3.5.h,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                SizedBox(height: 16.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$label to',
                      style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w600),
                    ),
                    // New folder button
                    GestureDetector(
                      onTap: _showNewFolderDialog,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A1A0E),
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(color: const Color(0xFF0F6E56), width: 0.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.create_new_folder_outlined, color: const Color(0xFF1D9E75), size: 13.sp),
                            SizedBox(width: 5.w),
                            Text('New folder', style: TextStyle(color: const Color(0xFF1D9E75), fontSize: 11.sp)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                // Search
                Container(
                  height: 36.h,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.07), width: 0.5),
                  ),
                  child: TextField(
                    onChanged: _onSearch,
                    style: TextStyle(color: Colors.white70, fontSize: 12.sp),
                    decoration: InputDecoration(
                      hintText: 'Search folders...',
                      hintStyle: TextStyle(color: Colors.white24, fontSize: 12.sp),
                      prefixIcon: Icon(Icons.search_rounded, color: Colors.white24, size: 16.sp),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 8.h),
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
              ],
            ),
          ),

          // Folder list
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: colorGreen, strokeWidth: 1.5))
                : ListView.separated(
                    controller: scrollController,
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => SizedBox(height: 6.h),
                    itemBuilder: (ctx, i) {
                      final folder = _filtered[i];
                      final name = folder['name'] as String;
                      final count = folder['videoCount'] as int;
                      final isCurrentFolder = widget.video.relativePath?.contains(name) ?? false;
                      final isSelected = _selected == folder;

                      return GestureDetector(
                        onTap: () => setState(() => _selected = isSelected ? null : folder),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF0A1A0E)
                                : Colors.white.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(10.r),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF0F6E56)
                                  : Colors.white.withValues(alpha: 0.06),
                              width: isSelected ? 1 : 0.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32.w, height: 32.w,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(6.r),
                                ),
                                child: Icon(Icons.folder_outlined,
                                    color: isSelected ? const Color(0xFF1D9E75) : Colors.white24,
                                    size: 16.sp),
                              ),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name,
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.85),
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w500,
                                        )),
                                    Text('$count videos',
                                        style: TextStyle(color: Colors.white24, fontSize: 9.sp)),
                                  ],
                                ),
                              ),
                              if (isCurrentFolder)
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1A1A0A),
                                    borderRadius: BorderRadius.circular(4.r),
                                    border: Border.all(color: const Color(0xFF63480A), width: 0.5),
                                  ),
                                  child: Text('current',
                                      style: TextStyle(color: const Color(0xFFBA7517), fontSize: 8.sp)),
                                )
                              else if (isSelected)
                                Icon(Icons.check_circle_rounded, color: const Color(0xFF1D9E75), size: 16.sp),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Confirm button
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 32.h),
            child: GestureDetector(
              onTap: _selected == null || _operating ? null : _executeOperation,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 48.h,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _selected != null ? colorGreen : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Center(
                  child: _operating
                      ? SizedBox(
                          width: 18.w, height: 18.w,
                          child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                        )
                      : Text(
                          buttonLabel,
                          style: TextStyle(
                            color: _selected != null ? Colors.black : Colors.white24,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _executeOperation() async {
    if (_selected == null) return;
    setState(() => _operating = true);

    // Get real path from album
    final album = _selected!['album'] as AssetPathEntity;
    final assets = await album.getAssetListRange(start: 0, end: 1);
    if (assets.isEmpty) { setState(() => _operating = false); return; }
    final sampleFile = await assets.first.file;
    if (sampleFile == null) { setState(() => _operating = false); return; }
    final destPath = sampleFile.parent.path;

    bool success = false;
    if (widget.mode == 'copy') {
      final result = await FileOperations.copyVideo(asset: widget.video, destinationFolderPath: destPath);
      success = result != null;
    } else {
      success = await FileOperations.moveVideo(context: context, asset: widget.video, destinationFolderPath: destPath);
    }

    if (mounted) {
      Navigator.pop(context);
      widget.onComplete(success);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? '${widget.mode == 'copy' ? 'Copied' : 'Moved'} successfully' : 'Operation failed',
            style: TextStyle(fontSize: 12.sp),
          ),
          backgroundColor: success ? const Color(0xFF0A1A0E) : const Color(0xFF1A0505),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
        ),
      );
    }
  }

  void _showNewFolderDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161616),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text('New folder', style: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.w600)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: Colors.white, fontSize: 13.sp),
          decoration: InputDecoration(
            hintText: 'Folder name',
            hintStyle: TextStyle(color: Colors.white24, fontSize: 13.sp),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: colorGreen)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: Colors.white38, fontSize: 12.sp)),
          ),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              // Create under DCIM
              final dir = Directory('/storage/emulated/0/DCIM/$name');
              await dir.create(recursive: true);
              await _loadFolders(); // refresh list
            },
            child: Text('Create', style: TextStyle(color: colorGreen, fontSize: 12.sp, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

Wire up onVideoDeleted callback
In shorts_try_two.dart, VideoPLayerPageForShorts widget needs one new parameter:
dart// Add to widget constructor:
final VoidCallback? Function(AssetEntity)? onVideoDeleted;

// In ShortsPageTry's itemBuilder, pass it:
VideoPLayerPageForShorts(
  ...
  onVideoDeleted: (asset) {
    setState(() {
      shortVideos.removeWhere((v) => v.id == asset.id);
    });
  },
)
When delete or move succeeds, the video smoothly disappears from the list and the PageView moves to the next video automatically.

Summary
FileChangelib/functions/file_operations.dartNew file — delete, copy, move, folder fetch, format helpersshorts_try_two.dartReplace _openSettingsMenu(), add _openDeleteConfirmation(), _openFolderPicker(), _FolderPickerSheet, _MetaPill, _ActionRow, wire onVideoDeleted