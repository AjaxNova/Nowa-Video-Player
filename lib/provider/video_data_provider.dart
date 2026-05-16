import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../functions/app_logger.dart';

class VideoDataProvider with ChangeNotifier {
  List<AssetEntity> allVideosList = [];
  List<AssetPathEntity> allFoldersList = [];
  final Map<String, int> _fileSizeCache = {};
  
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  int _totalCount = 0;
  int get totalCount => _totalCount;
  
  String _currentSort = 'date_desc';
  String get currentSort => _currentSort;

  Future<void> initialize(BuildContext context) async {
    if (_isInitialized) return;
    await _fetchAllVideos();
  }

  Future<void> _fetchAllVideos() async {
    try {
      AppLogger.log("VideoDataProvider: Requesting video permissions...");
      final PermissionState ps = await PhotoManager.requestPermissionExtend(
        requestOption: const PermissionRequestOption(
          androidPermission: AndroidPermission(
            type: RequestType.video,
            mediaLocation: false,
          ),
        ),
      );
      
      AppLogger.log("VideoDataProvider: Permission state is $ps");
      if (!ps.isAuth && !ps.hasAccess && !ps.isLimited) {
        AppLogger.logWarning("VideoDataProvider: Permission denied. Aborting fetch.");
        return;
      }

      AppLogger.log("VideoDataProvider: Fetching video albums...");
      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.video,
        filterOption: FilterOptionGroup(
          orders: [const OrderOption(type: OrderOptionType.createDate, asc: false)],
        ),
      );

      if (albums.isEmpty) {
        AppLogger.logWarning("VideoDataProvider: No albums found.");
        allVideosList = [];
        allFoldersList = [];
        _isInitialized = true;
        notifyListeners();
        return;
      }

      allFoldersList = albums;
      final recentAlbum = albums.first;
      _totalCount = await recentAlbum.assetCountAsync;
      AppLogger.log("VideoDataProvider: Found ${_totalCount} videos in Recents album.");

      // Fetch THE ENTIRE library at once (metadata only)
      // This ensures global sorting is perfect from the start
      AppLogger.log("VideoDataProvider: Fetching all video metadata...");
      final allAssets = await recentAlbum.getAssetListRange(start: 0, end: _totalCount);
      allVideosList = allAssets.toList();
      
      _isInitialized = true;
      notifyListeners();

      // Start background hydration for file sizes for the whole library
      _hydrateAllMetadata();
    } catch (e, stackTrace) {
      AppLogger.logError("VideoDataProvider: Error in fetchAllVideos", e, stackTrace);
      debugPrint('Error in fetchAllVideos: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> _hydrateAllMetadata() async {
    // Hydrate in small chunks to avoid blocking anything
    for (var i = 0; i < allVideosList.length; i++) {
      final asset = allVideosList[i];
      if (!_fileSizeCache.containsKey(asset.id)) {
        final file = await asset.file;
        if (file != null) {
          _fileSizeCache[asset.id] = await file.length();
        }
      }
      // Periodically notify and re-sort during hydration if sorting by size
      if (i % 20 == 0 && _currentSort.startsWith('size')) {
        _applySort();
        notifyListeners();
      }
    }
    if (_currentSort.startsWith('size')) {
      _applySort();
    }
    notifyListeners();
  }

  int getCachedSize(String id) => _fileSizeCache[id] ?? 0;

  void setSort(String type) {
    _currentSort = type;
    _applySort();
    notifyListeners();
  }

  void _applySort() {
    switch (_currentSort) {
      case 'name_asc':
        allVideosList.sort((a, b) => (a.title ?? '').toLowerCase().compareTo((b.title ?? '').toLowerCase()));
        break;
      case 'name_desc':
        allVideosList.sort((a, b) => (b.title ?? '').toLowerCase().compareTo((a.title ?? '').toLowerCase()));
        break;
      case 'size_desc':
        // Size ↓ means Smallest first (Ascending)
        allVideosList.sort((a, b) => getCachedSize(a.id).compareTo(getCachedSize(b.id)));
        break;
      case 'size_asc':
        // Size ↑ means Largest first (Descending)
        allVideosList.sort((a, b) => getCachedSize(b.id).compareTo(getCachedSize(a.id)));
        break;
      case 'duration_desc':
        allVideosList.sort((a, b) => b.duration.compareTo(a.duration));
        break;
      case 'duration_asc':
        allVideosList.sort((a, b) => a.duration.compareTo(b.duration));
        break;
      case 'date_desc':
        // Handle actual date sorting explicitly
        allVideosList.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));
        break;
    }
  }

  // loadMore is no longer needed because we have everything!
  Future<void> loadMore() async {}
}
