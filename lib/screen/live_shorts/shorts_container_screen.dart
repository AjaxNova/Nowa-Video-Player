import 'package:flutter/material.dart';
import 'package:nova_videoplayer/functions/global_variables.dart';
import 'package:nova_videoplayer/screen/newPlaylistPage/shorts_page/shorts_try_two.dart';

class ShortsContainerScreen extends StatefulWidget {
  const ShortsContainerScreen({super.key});

  @override
  State<ShortsContainerScreen> createState() => _ShortsContainerScreenState();
}

class _ShortsContainerScreenState extends State<ShortsContainerScreen> {
  @override
  void initState() {
    super.initState();
    isShortsTabActive.addListener(_onGlobalTabActiveChanged);
    _updateActiveStates();
  }

  @override
  void dispose() {
    isShortsTabActive.removeListener(_onGlobalTabActiveChanged);
    super.dispose();
  }

  void _onGlobalTabActiveChanged() {
    if (mounted) {
      _updateActiveStates();
    }
  }

  void _updateActiveStates() {
    isLocalShortsTabActive.value = isShortsTabActive.value;
    isLiveShortsTabActive.value = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: ShortsPageTry(shortVideos: theAllShortVideos),
    );
  }
}

