import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';

class CachedThumbnailImage extends StatefulWidget {
  final AssetEntity asset;
  final int width;
  final int height;
  final BoxFit fit;

  // Simple in-memory cache to prevent duplicate loads of same asset thumbnails
  static final Map<String, Uint8List> _memoryCache = {};

  // Push-based pre-caching: background job to warm up the cache for the first N assets
  static void preCacheThumbnails(
    List<AssetEntity> assets, {
    int limit = 150,
    int size = 200,
  }) async {
    final targetLimit = assets.length < limit ? assets.length : limit;
    for (int i = 0; i < targetLimit; i++) {
      final asset = assets[i];
      final cacheKey = "${asset.id}_${size}_${size}"; // Warm up cache keys matching target size
      
      if (_memoryCache.containsKey(cacheKey)) continue;

      try {
        final data = await asset.thumbnailDataWithSize(ThumbnailSize(size, size));
        if (data != null) {
          _memoryCache[cacheKey] = data;
        }
      } catch (_) {
        // Quietly continue on failure
      }
      
      // Yield to the event loop between iterations to keep the UI buttery smooth
      await Future.delayed(Duration.zero);
    }
  }

  const CachedThumbnailImage({
    super.key,
    required this.asset,
    this.width = 200,
    this.height = 200,
    this.fit = BoxFit.cover,
  });

  @override
  State<CachedThumbnailImage> createState() => _CachedThumbnailImageState();
}

class _CachedThumbnailImageState extends State<CachedThumbnailImage> {
  Uint8List? _thumbnailData;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(CachedThumbnailImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset != widget.asset || oldWidget.width != widget.width || oldWidget.height != widget.height) {
      _loadThumbnail();
    }
  }

  Future<void> _loadThumbnail() async {
    final cacheKey = "${widget.asset.id}_${widget.width}_${widget.height}";
    
    if (CachedThumbnailImage._memoryCache.containsKey(cacheKey)) {
      if (mounted) {
        setState(() {
          _thumbnailData = CachedThumbnailImage._memoryCache[cacheKey];
        });
      }
      return;
    }

    try {
      final data = await widget.asset.thumbnailDataWithSize(
        ThumbnailSize(widget.width, widget.height),
      );
      if (data != null) {
        CachedThumbnailImage._memoryCache[cacheKey] = data;
      }
      if (mounted) {
        setState(() {
          _thumbnailData = data;
        });
      }
    } catch (e) {
      // Quietly catch and fail
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_thumbnailData != null) {
      return Image.memory(
        _thumbnailData!,
        fit: widget.fit,
      );
    }
    
    // Fallback/loading state - a plain grey box feels much cleaner than a busy spinner
    return Container(
      color: Colors.grey[900],
      child: const Center(
        child: Icon(Icons.movie_outlined, color: Colors.white24, size: 24),
      ),
    );
  }
}
