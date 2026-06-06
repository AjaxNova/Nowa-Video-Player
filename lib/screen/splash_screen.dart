import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nova_videoplayer/functions/global_variables.dart';
import 'package:nova_videoplayer/provider/video_data_provider.dart';
import 'package:nova_videoplayer/screen/home_with_bottom.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import '../functions/app_logger.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  List<AssetPathEntity> allFolderswithVideos = [];
  List<AssetEntity> allVideosList = [];
  bool isLoading = false;
  String statusMessage = "Initializing...";

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // First, initialize database
      setState(() => statusMessage = "Starting...");
      await getAllPlayListFromDb();

      // Request permissions
      await _requestPermissionAndFetchVideos();
    } catch (e, stackTrace) {
      AppLogger.logError('SplashScreen: Error in _initializeApp', e, stackTrace);
      debugPrint('Error in _initializeApp: $e');
      setState(() => statusMessage = "Error: $e");
    }
  }

  Future<void> _requestPermissionAndFetchVideos() async {
    try {
      final PermissionState ps = await PhotoManager.requestPermissionExtend(
        requestOption: const PermissionRequestOption(
          androidPermission: AndroidPermission(
            type: RequestType.video,
            mediaLocation: false,
          ),
        ),
      );

      if (ps.isAuth || ps.isLimited || ps.hasAccess) {
        await fetchvideos();
      } else {
        if (mounted) _showPermissionDeniedDialog();
      }
    } catch (e, stackTrace) {
      AppLogger.logError('SplashScreen: Error requesting permissions', e, stackTrace);
      debugPrint('Error requesting permissions: $e');
      if (mounted) _showErrorDialog('Permission error: $e');
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Permission Required', style: TextStyle(color: Colors.white)),
        content: const Text(
          'NOWA PLAYER needs access to your videos to work.\n\nPlease allow access to Videos in Settings.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await PhotoManager.openSetting();
              await Future.delayed(const Duration(seconds: 2));
              _requestPermissionAndFetchVideos();
            },
            child: const Text('Open Settings'),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Exit', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Error', style: TextStyle(color: Colors.white)),
        content: Text(error, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 200.h,
              width: 250.w,
              decoration: const BoxDecoration(
                image: DecorationImage(image: AssetImage('assets/images/SplashLogo.png'), fit: BoxFit.contain),
              ),
            ),
            SizedBox(height: 20.h),
            if (isLoading)
              const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
            else if (globalYouTubeShorts.value.isEmpty)
              Padding(
                padding: EdgeInsets.only(top: 10.h),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () => fetchvideos(),
                  child: const Text('Retry Loading Feed'),
                ),
              ),
            SizedBox(height: 10.h),
            Text(statusMessage, style: TextStyle(fontFamily: "Inter", fontSize: 14.sp, color: Colors.white70)),
            SizedBox(height: 60.h),
            Text('NOWA PLAYER', style: TextStyle(fontFamily: "Inter", fontSize: 18.sp, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  // Fetch videos function using Provider
  Future<void> fetchvideos() async {
    setState(() {
      isLoading = true;
      statusMessage = "Discovering video library...";
    });

    try {
      final provider = context.read<VideoDataProvider>();
      
      // Await primary folder mapping
      await provider.initialize(context);
      
      if (mounted) {
        setState(() {
          allFolderswithVideos = provider.allFoldersList;
          allVideosList = provider.allVideosList;
          statusMessage = "Optimizing your Shorts Feed...";
        });

        // Await preparation of the global Shorts list *before* leaving the splash screen
        await fetchVideosForAddVideoPage(dummyAssets: allVideosList);

        setState(() {
          statusMessage = "Loading YouTube Shorts Feed...";
          isLoading = true;
        });
        
        // Start prefetching and await the result with a maximum 8s timeout
        await prefetchYouTubeShorts(limit: 10, timeout: const Duration(seconds: 8));

        if (globalYouTubeShorts.value.isNotEmpty) {
          setState(() {
            statusMessage = "Welcome to NOWA Player!";
            isLoading = false;
          });

          // Slight cinematic pause so the user sees the "Welcome!" message briefly
          await Future.delayed(const Duration(milliseconds: 600));
          
          if (mounted) {
            gotoHome();
          }
        } else {
          setState(() {
            statusMessage = "Could not load feed. Please check your connection.";
            isLoading = false;
          });
        }
      }

    } catch (e, stackTrace) {
      AppLogger.logError('SplashScreen: Error fetching videos', e, stackTrace);
      debugPrint('Error fetching videos: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          statusMessage = "Error loading videos";
        });
      }
    }
  }

  void gotoHome() {
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (context) => HomeScreen(
          assets: allVideosList, foldersWithVideos: allFolderswithVideos),
    ));
  }

  Future<void> fetchVideosForAddVideoPage(
      {required List<AssetEntity>? dummyAssets}) async {
    try {
      if (dummyAssets == null || dummyAssets.isEmpty) {
        theAllVideosListFortheSelectionPage = [];
        theAllShortVideos = [];
        return;
      }

      List<AssetEntity> myVideosData;
      dummyAssets.sort((a, b) => (a.title ?? '').compareTo(b.title ?? ''));
      myVideosData = dummyAssets;

      theAllVideosListFortheSelectionPage = myVideosData;
      theAllShortVideos =
          await getShortsVideos(theAllVideosListFortheSelectionPage);

      debugPrint(
          'Processed ${theAllVideosListFortheSelectionPage.length} videos');
      debugPrint('Found ${theAllShortVideos.length} short videos');
    } catch (e, stackTrace) {
      AppLogger.logError('fetchVideosForAddVideoPage failed', e, stackTrace);
      theAllVideosListFortheSelectionPage = [];
      theAllShortVideos = [];
    }
  }
}
