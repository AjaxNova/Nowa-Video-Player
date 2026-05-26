import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

class ShortsFeedScreen extends StatefulWidget {
  const ShortsFeedScreen({super.key});

  @override
  State<ShortsFeedScreen> createState() => _ShortsFeedScreenState();
}

class _ShortsFeedScreenState extends State<ShortsFeedScreen> {
  List<dynamic> _videos = [];
  bool _isLoading = true;
  late PageController _pageController;
  int _focusedIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _fetchShorts();
  }
  Future<void> _fetchShorts() async {
    // 1. Log target configuration
    final String targetUrl = 'https://nowashorts.loca.lt/api/feed';
    print("🤖 [Shorts API] Initiating connection sequence...");
    print("🤖 [Shorts API] Target URL Configuration: $targetUrl");
    
    final url = Uri.parse(targetUrl);
    
    try {
      final response = await http.get(
        url,
        headers: {
          'Bypass-Tunnel-Reminder': 'true',
        },
      ).timeout(const Duration(seconds: 30));
      
      print("🤖 [Shorts API] Response received! HTTP Status Code: ${response.statusCode}");
      
      if (response.statusCode == 200) {
        print("🤖 [Shorts API] Network payload payload parsing started...");
        final data = jsonDecode(response.body);
        
        setState(() {
          _videos = data['videos'];
          _isLoading = false;
        });
        print("🤖 [Shorts API] UI Data updated successfully. Render count: ${_videos.length} clips.");
      } else {
        print("🚨 [Shorts API] Server error! Status Code: ${response.statusCode}");
        print("🚨 [Shorts API] Raw Server Response Body: ${response.body}");
        setState(() => _isLoading = false);
      }
    } catch (e, stackTrace) {
      print("❌ [Shorts API] CRITICAL CONNECTION FAILURE DETECTED!");
      print("❌ [Shorts API] Error Message details: $e");
      print("❌ [Shorts API] Technical StackTrace:\n$stackTrace");
      
      // Let's decode the error type for you automatically
      if (e.toString().contains('SocketException')) {
        print("💡 [Diagnosis] SocketException: Your phone/emulator physically cannot see your Mac. "
              "Check if Android cleartext traffic is enabled or if your Mac firewall is blocking port 4000.");
      } else if (e.toString().contains('TimeoutException')) {
        print("💡 [Diagnosis] TimeoutException: The server ip was reached, but it took too long to respond.");
      }
      
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_videos.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Text("No videos found. Check backend terminal.", style: TextStyle(color: Colors.white))),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical, // TikTok style vertical scrolling!
        itemCount: _videos.length,
        onPageChanged: (index) {
          setState(() {
            _focusedIndex = index;
          });
        },
        itemBuilder: (context, index) {
          return SingleShortPlayer(
            videoData: _videos[index],
            isActive: index == _focusedIndex,
          );
        },
      ),
    );
  }
}

// Sub-widget that handles playing/pausing a single video clip inside the list feed
class SingleShortPlayer extends StatefulWidget {
  final Map<String, dynamic> videoData;
  final bool isActive;

  const SingleShortPlayer({Key? key, required this.videoData, required this.isActive}) : super(key: key);

  @override
  State<SingleShortPlayer> createState() => _SingleShortPlayerState();
}

class _SingleShortPlayerState extends State<SingleShortPlayer> {
  late final Player _player;
  late final VideoController _videoController;
  bool _isPlayerReady = false;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _videoController = VideoController(_player);

    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      final String streamUrl = widget.videoData['stream_url'];
      print("🤖 [Player] Opening stream URL: $streamUrl");
      
      // Open the raw live video stream URL from your Node backend
      await _player.open(Media(streamUrl), play: widget.isActive);
      // Loop the video automatically when it finishes playing
      await _player.setPlaylistMode(PlaylistMode.loop);

      if (mounted) {
        setState(() {
          _isPlayerReady = true;
        });
      }
    } catch (e, stackTrace) {
      print("❌ [Player] Error initializing video stream: $e");
      print("❌ [Player] StackTrace:\n$stackTrace");
    }
  }

  @override
  void didUpdateWidget(covariant SingleShortPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      if (widget.isActive) {
        _player.play();
      } else {
        _player.pause();
      }
    }
  }

  @override
  void dispose() {
    _player.dispose(); // Critical: frees up hardware RAM memory when user scrolls away
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. The Video Component Surface
        Positioned.fill(
          child: _isPlayerReady
              ? Video(
                  controller: _videoController,
                  controls: NoVideoControls,
                  fit: BoxFit.cover,
                )
              : const Center(child: CircularProgressIndicator(color: Colors.red)),
        ),
        
        // 2. Video Title Text Overlay UI Layout
        Positioned(
          bottom: 30,
          left: 20,
          right: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.videoData['title'] ?? 'Short Video Clip',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
