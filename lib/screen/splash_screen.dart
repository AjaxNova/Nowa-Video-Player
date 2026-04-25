import 'package:flutter/material.dart';
import 'package:nova_videoplayer/functions/global_variables.dart';
import 'package:nova_videoplayer/screen/home_with_bottom.dart';
import 'package:photo_manager/photo_manager.dart';

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
      setState(() => statusMessage = "Loading database...");
      await getAllPlayListFromDb();

      // Small delay to show splash
      await Future.delayed(const Duration(seconds: 1));

      // Request permissions
      setState(() => statusMessage = "Requesting permissions...");
      await _requestPermissionAndFetchVideos();
    } catch (e) {
      debugPrint('Error in _initializeApp: $e');
      setState(() => statusMessage = "Error: $e");
    }
  }

  Future<void> _requestPermissionAndFetchVideos() async {
    try {
      // Request permission with videos only
      final PermissionState ps = await PhotoManager.requestPermissionExtend(
        requestOption: const PermissionRequestOption(
          androidPermission: AndroidPermission(
            type: RequestType.video, // Only request video permission
            mediaLocation: false,
          ),
        ),
      );

      debugPrint(
          'Permission state: isAuth=${ps.isAuth}, hasAccess=${ps.hasAccess}, hasLimited=${ps.isLimited}');

      if (ps.isAuth) {
        // Full permission granted
        debugPrint('Full permission granted');
        setState(() => statusMessage = "Loading videos...");
        await fetchvideos();
      } else if (ps.isLimited) {
        // Limited permission (some photos selected)
        debugPrint('Limited permission granted');
        setState(() => statusMessage = "Loading selected videos...");
        await fetchvideos();
      } else {
        // Permission denied or not determined
        debugPrint('Permission denied or not determined');
        if (mounted) {
          _showPermissionDeniedDialog();
        }
      }
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
      if (mounted) {
        _showErrorDialog('Permission error: $e');
      }
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Permission Required',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'NOWA PLAYER needs access to your videos to work.\n\n'
          'Please tap "Open Settings" and allow access to Videos.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await PhotoManager.openSetting();
              debugPrint('Settings opened');
              // Wait a bit for user to grant permission
              await Future.delayed(const Duration(seconds: 2));
              // Retry permission check
              _requestPermissionAndFetchVideos();
            },
            child: const Text('Open Settings',
                style: TextStyle(color: Colors.blue)),
          ),
          TextButton(
            onPressed: () {
              // Exit app if permission denied
              Navigator.pop(context);
            },
            child: const Text('Exit', style: TextStyle(color: Colors.red)),
          ),
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
        content: Text(
          'An error occurred: $error',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('OK', style: TextStyle(color: Colors.blue)),
          ),
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
                height: MediaQuery.of(context).size.height * .30,
                width: MediaQuery.of(context).size.width * .7,
                decoration: const BoxDecoration(
                    image: DecorationImage(
                        image: AssetImage('assets/images/SplashLogo.png'),
                        fit: BoxFit.fitWidth)),
              ),
              const SizedBox(height: 20),
              if (isLoading)
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              const SizedBox(height: 10),
              Text(
                statusMessage,
                style: const TextStyle(
                    fontFamily: "Inter", fontSize: 14, color: Colors.white70),
              ),
              const SizedBox(height: 60),
              const Text(
                'NOWA PLAYER',
                style: TextStyle(
                    fontFamily: "Inter", fontSize: 18, color: Colors.white),
              )
            ],
          ),
        ));
  }

  // Fetch videos function
  Future<void> fetchvideos() async {
    setState(() => isLoading = true);

    try {
      debugPrint('Starting to fetch videos...');

      final albums =
          await PhotoManager.getAssetPathList(type: RequestType.video);
      debugPrint('Found ${albums.length} albums');

      if (albums.isEmpty) {
        setState(() {
          isLoading = false;
          statusMessage = "No video albums found";
        });

        // Navigate to home anyway with empty list
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) gotoHome();
        });
        return;
      }

      final recentAlbum = albums.first;
      final assetCount = await recentAlbum.assetCountAsync;
      debugPrint('Asset count: $assetCount');

      if (assetCount == 0) {
        setState(() {
          isLoading = false;
          statusMessage = "No videos found";
        });

        // Navigate to home anyway with empty list
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) gotoHome();
        });
        return;
      }

      final recentAssets =
          await recentAlbum.getAssetListRange(start: 0, end: assetCount);
      debugPrint('Got ${recentAssets.length} videos');

      setState(() {
        allFolderswithVideos = albums;
        allVideosList = recentAssets.toList();
        isLoading = false;
        statusMessage = "Videos loaded!";
      });

      // Process videos for add page
      final dummyAssets = recentAssets;
      await fetchVideosForAddVideoPage(dummyAssets: dummyAssets);

      // Navigate to home
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) gotoHome();
      });
    } catch (e) {
      debugPrint('Error fetching videos: $e');
      setState(() {
        isLoading = false;
        statusMessage = "Error loading videos";
      });

      if (mounted) {
        _showErrorDialog('Failed to load videos: $e');
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
      dummyAssets.sort((a, b) => a.title!.compareTo(b.title!));
      myVideosData = dummyAssets;

      theAllVideosListFortheSelectionPage = myVideosData;
      theAllShortVideos =
          await getLandscapeVideos(theAllVideosListFortheSelectionPage);

      debugPrint(
          'Processed ${theAllVideosListFortheSelectionPage.length} videos');
      debugPrint('Found ${theAllShortVideos.length} short videos');
    } catch (e) {
      debugPrint('Error in fetchVideosForAddVideoPage: $e');
      theAllVideosListFortheSelectionPage = [];
      theAllShortVideos = [];
    }
  }
}
