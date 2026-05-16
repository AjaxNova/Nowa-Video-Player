import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
          borderRadius: BorderRadius.circular(borderRadius.r),
          child: SizedBox(
            height: height.h,
            width: width.w,
            child: FutureBuilder<Uint8List?>(
              future: asset.thumbnailData,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
                  return Image.memory(snapshot.data!, fit: BoxFit.cover);
                }
                return Container(
                  color: Colors.grey[900],
                  child: Center(
                    child: Icon(Icons.movie_outlined, color: Colors.white24, size: 24.sp),
                  ),
                );
              },
            ),
          ),
        ),
        Positioned(
          bottom: 4.h,
          right: 4.w,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(4.r),
            ),
            child: Text(
              durationToString(asset.duration),
              style: TextStyle(
                color: Colors.white,
                fontSize: 10.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
