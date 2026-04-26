import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import '../provider/video_data_provider.dart';
import '../functions/gobal_functions.dart';

class VideoThumbnail extends StatelessWidget {
  final AssetEntity asset;
  final double height;
  final double width;
  final double borderRadius;

  const VideoThumbnail({
    super.key,
    required this.asset,
    this.height = 80,
    this.width = 90,
    this.borderRadius = 4.0,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: SizedBox(
            height: height,
            width: width,
            child: Consumer<VideoDataProvider>(
              builder: (context, provider, child) {
                return FutureBuilder<Uint8List?>(
                  future: provider.getThumbnail(asset),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done &&
                        snapshot.data != null) {
                      return Image.memory(
                        snapshot.data!,
                        fit: BoxFit.cover,
                      );
                    }
                    return Container(
                      color: Colors.grey[900],
                      child: const Center(
                        child: Icon(
                          Icons.movie_outlined,
                          color: Colors.white24,
                          size: 24,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
        Positioned(
          bottom: 4,
          right: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              durationToString(asset.duration),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
