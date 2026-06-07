import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nova_videoplayer/functions/global_variables.dart';
import 'package:nova_videoplayer/screen/live_shorts/live_shorts_screen.dart';
import 'package:nova_videoplayer/screen/newPlaylistPage/shorts_page/shorts_try_two.dart';

class ShortsContainerScreen extends StatefulWidget {
  const ShortsContainerScreen({super.key});

  @override
  State<ShortsContainerScreen> createState() => _ShortsContainerScreenState();
}

class _ShortsContainerScreenState extends State<ShortsContainerScreen> {
  late final PageController _pageController;
  int _activeSubIndex = 0; // 0 for Local, 1 for Live
  final List<bool> _visited = [false, false];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _activeSubIndex);
    _visited[_activeSubIndex] = true;

    isShortsTabActive.addListener(_onGlobalTabActiveChanged);
    _updateSubTabActiveStates();
  }

  @override
  void dispose() {
    isShortsTabActive.removeListener(_onGlobalTabActiveChanged);
    _pageController.dispose();
    super.dispose();
  }

  void _onGlobalTabActiveChanged() {
    if (mounted) {
      _updateSubTabActiveStates();
    }
  }

  void _updateSubTabActiveStates() {
    if (isShortsTabActive.value) {
      isLocalShortsTabActive.value = (_activeSubIndex == 0);
      isLiveShortsTabActive.value = (_activeSubIndex == 1);
    } else {
      isLocalShortsTabActive.value = false;
      isLiveShortsTabActive.value = false;
    }
  }

  void _onTabTap(int index) {
    if (index == _activeSubIndex) return;
    setState(() {
      _activeSubIndex = index;
      _visited[index] = true;
    });
    _pageController.jumpToPage(index);
    _updateSubTabActiveStates();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 2,
            itemBuilder: (context, index) {
              if (!_visited[index]) {
                return const SizedBox.shrink();
              }
              if (index == 0) {
                return ShortsPageTry(shortVideos: theAllShortVideos);
              } else {
                return const ShortsFeedScreen();
              }
            },
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Container(
                height: 50.h,
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildTabButton("Local", 0),
                    SizedBox(width: 20.w),
                    _buildTabButton("Live", 1),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index) {
    final isSelected = _activeSubIndex == index;
    return GestureDetector(
      onTap: () => _onTabTap(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white38,
              fontSize: 16.sp,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontFamily: 'Inter',
            ),
          ),
          SizedBox(height: 4.h),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 3.h,
            width: isSelected ? 24.w : 0,
            decoration: BoxDecoration(
              color: colorGreen,
              borderRadius: BorderRadius.circular(1.5.r),
            ),
          ),
        ],
      ),
    );
  }
}
