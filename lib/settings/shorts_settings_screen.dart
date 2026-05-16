import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nova_videoplayer/functions/global_variables.dart';
import 'package:nova_videoplayer/screen/splash_screen.dart';

class ShortsSettingsScreen extends StatefulWidget {
  const ShortsSettingsScreen({super.key});

  @override
  State<ShortsSettingsScreen> createState() => _ShortsSettingsScreenState();
}

class _ShortsSettingsScreenState extends State<ShortsSettingsScreen> {
  late Box<dynamic> _settingsBox;
  late double _minDuration;
  late double _maxDuration;
  late bool _includeHorizontal;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _settingsBox = Hive.box<dynamic>('appSettings');
    _minDuration = _settingsBox.get('shortsMinDuration', defaultValue: 2.0) as double;
    _maxDuration = _settingsBox.get('shortsMaxDuration', defaultValue: 180.0) as double;
    _includeHorizontal = _settingsBox.get('shortsIncludeHorizontal', defaultValue: false) as bool;
  }

  void _saveSettings() async {
    _settingsBox.put('shortsMinDuration', _minDuration);
    _settingsBox.put('shortsMaxDuration', _maxDuration);
    _settingsBox.put('shortsIncludeHorizontal', _includeHorizontal);
    setState(() {
      _hasChanges = true;
    });

    // Dynamically update the global shorts list so it's ready on next visit
    if (theAllVideosListFortheSelectionPage.isNotEmpty) {
      theAllShortVideos = await getShortsVideos(theAllVideosListFortheSelectionPage);
    }
  }

  String _formatDuration(double seconds) {
    if (seconds < 60) return "${seconds.toInt()}s";
    int mins = seconds ~/ 60;
    int secs = (seconds % 60).toInt();
    if (secs == 0) return "${mins}m";
    return "${mins}m ${secs}s";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colorBlack,
      appBar: AppBar(
        backgroundColor: colorBlack,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Shorts Feed Settings', style: TextStyle(color: Colors.white, fontFamily: 'poppins')),
      ),
      body: WillPopScope(
        onWillPop: () async {
          if (_hasChanges) {
            bool shouldRestart = await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: Colors.grey[900],
                title: Text("Apply Changes?", style: TextStyle(color: Colors.white, fontSize: 18.sp)),
                content: Text("To apply the new Shorts settings, the app needs to reload.", style: TextStyle(color: Colors.white70, fontSize: 14.sp)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text("Later", style: TextStyle(color: Colors.white54, fontSize: 14.sp)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text("Reload Now", style: TextStyle(color: colorGreen, fontSize: 14.sp, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ) ?? false;

            if (shouldRestart) {
              if (context.mounted) {
                // Navigate back to the Splash Screen to cleanly reload everything
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const SplashScreen()),
                  (route) => false,
                );
              }
              return false; // We handled the navigation manually
            }
          }
          return true;
        },
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Video Filters", style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold)),
                SizedBox(height: 8.h),
                Text("Customize which videos appear in your Shorts feed.", style: TextStyle(color: Colors.white54, fontSize: 12.sp)),
                SizedBox(height: 32.h),

                // Min Duration
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Minimum Length", style: TextStyle(color: Colors.white, fontSize: 14.sp)),
                    Text(_formatDuration(_minDuration), style: TextStyle(color: colorGreen, fontSize: 14.sp, fontWeight: FontWeight.bold)),
                  ],
                ),
                Slider(
                  value: _minDuration,
                  min: 1.0,
                  max: 60.0,
                  divisions: 59,
                  activeColor: colorGreen,
                  inactiveColor: Colors.white24,
                  onChanged: (val) {
                    if (val < _maxDuration) {
                      setState(() => _minDuration = val);
                      _saveSettings();
                    }
                  },
                ),
                SizedBox(height: 24.h),

                // Max Duration
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Maximum Length", style: TextStyle(color: Colors.white, fontSize: 14.sp)),
                    Text(_formatDuration(_maxDuration), style: TextStyle(color: colorGreen, fontSize: 14.sp, fontWeight: FontWeight.bold)),
                  ],
                ),
                Slider(
                  value: _maxDuration,
                  min: 10.0,
                  max: 600.0, // Up to 10 minutes
                  divisions: 59,
                  activeColor: colorGreen,
                  inactiveColor: Colors.white24,
                  onChanged: (val) {
                    if (val > _minDuration) {
                      setState(() => _maxDuration = val);
                      _saveSettings();
                    }
                  },
                ),
                SizedBox(height: 32.h),

                // Horizontal Videos Toggle
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: SwitchListTile(
                    title: Text("Include Horizontal Videos", style: TextStyle(color: Colors.white, fontSize: 14.sp)),
                    subtitle: Text("Allow standard landscape videos in the feed.", style: TextStyle(color: Colors.white54, fontSize: 11.sp)),
                    value: _includeHorizontal,
                    activeColor: colorGreen,
                    onChanged: (val) {
                      setState(() => _includeHorizontal = val);
                      _saveSettings();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
