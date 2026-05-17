import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';

class CachedThumbnailImage extends StatefulWidget {
  final AssetEntity asset;
  final int width;
  final int height;
  final BoxFit fit;

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
  bool _isLoading = true;

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
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await widget.asset.thumbnailDataWithSize(
        ThumbnailSize(widget.width, widget.height),
      );
      if (mounted) {
        setState(() {
          _thumbnailData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
    
    // Fallback/loading state
    return Container(
      color: Colors.grey[900],
      child: Center(
        child: _isLoading 
            ? const SizedBox(
                width: 20, 
                height: 20, 
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24)
              )
            : const Icon(Icons.movie_outlined, color: Colors.white24, size: 24),
      ),
    );
  }
}
