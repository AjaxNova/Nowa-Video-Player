import 'package:flutter/material.dart';
import 'package:nova_videoplayer/functions/global_variables.dart';
import 'shorts_stream_cache.dart';
import 'shorts_player_pool.dart';

class ShortsFeedController extends ChangeNotifier {
  List<Map<String, dynamic>> _videos = [];
  int _focusedIndex = 0;
  String _currentSort = 'Default';
  bool _isLoading = true;
  String? _errorMessage;

  final PageController pageController = PageController();
  late final ShortsPlayerPool pool;
  bool _isSorting = false;

  List<Map<String, dynamic>> get videos => _videos;
  int get focusedIndex => _focusedIndex;
  String get currentSort => _currentSort;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  ShortsFeedController() {
    pool = ShortsPlayerPool();
    globalYouTubeShorts.addListener(_onGlobalShortsChanged);
    _initializeFeed();
  }

  void _initializeFeed() {
    if (globalYouTubeShorts.value.isNotEmpty) {
      _videos = List.from(globalYouTubeShorts.value);
      _isLoading = false;
      // Pre-warm the cache and pool players
      ShortsStreamCache.instance.warmUpAround(0, _videos);
      pool.updateActiveIndex(0, _videos);
      prefetchYouTubeShorts(limit: 10, append: true);
    } else {
      fetchShorts();
    }
  }

  void _onGlobalShortsChanged() {
    if (_isSorting) return; // don't overwrite while sort is in progress
    final savedIndex = _focusedIndex;
    _videos = List.from(globalYouTubeShorts.value);
    if (_currentSort != 'Default') {
      _applySortLocal(_currentSort);
    }
    notifyListeners();

    // Restores index/page scroll positions after rebuilds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (pageController.hasClients) {
        pageController.jumpToPage(savedIndex);
      }
      ShortsStreamCache.instance.warmUpAround(savedIndex, _videos);
      pool.updateActiveIndex(savedIndex, _videos);
    });
  }

  void setFocusedIndex(int index) {
    if (index < 0 || index >= _videos.length) return;
    if (_focusedIndex == index) return;
    _focusedIndex = index;
    notifyListeners();

    // Trigger pre-warming and pool updates around active settled index
    ShortsStreamCache.instance.warmUpAround(index, _videos);
    pool.updateActiveIndex(index, _videos);

    // Dynamic refilling before reaching the absolute end of scroll view
    if (index >= _videos.length - 5) {
      prefetchYouTubeShorts(limit: 10, append: true);
    }
  }

  Future<void> fetchShorts() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    await prefetchYouTubeShorts(limit: 10);
    
    _videos = List.from(globalYouTubeShorts.value);
    if (_currentSort != 'Default') {
      _applySortLocal(_currentSort);
    }
    _isLoading = globalYouTubeShorts.value.isEmpty;
    _errorMessage = youtubeShortsError;
    
    notifyListeners();

    if (_videos.isNotEmpty) {
      ShortsStreamCache.instance.warmUpAround(_focusedIndex, _videos);
      pool.updateActiveIndex(_focusedIndex, _videos);
    }
  }

  Future<void> setSort(String sortType) async {
    _isSorting = true; // block _onGlobalShortsChanged from overwriting
    _currentSort = sortType;

    if (sortType == 'Default') {
      _videos = List.from(globalYouTubeShorts.value);
    } else {
      _videos = List.from(globalYouTubeShorts.value);
      _applySortLocal(sortType);
    }

    // Reset to index 0
    _focusedIndex = 0;
    notifyListeners();

    // Reset PageView and pool to new index 0
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (pageController.hasClients) {
        pageController.jumpToPage(0);
      }
      // Reset pool to load new index 0
      pool.clear();
      if (_videos.isNotEmpty) {
        ShortsStreamCache.instance.warmUpAround(0, _videos);
        pool.updateActiveIndex(0, _videos);
      }
      _isSorting = false; // unblock after pool reset
    });
  }

  void _applySortLocal(String sortType) {
    _videos.sort((a, b) {
      switch (sortType) {
        case 'Newest':
          final aDate = DateTime.tryParse(a['publish_date'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = DateTime.tryParse(b['publish_date'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        case 'Oldest':
          final aDate = DateTime.tryParse(a['publish_date'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = DateTime.tryParse(b['publish_date'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          return aDate.compareTo(bDate);
        case 'Shortest':
          final aDur = a['duration'] as num? ?? 0;
          final bDur = b['duration'] as num? ?? 0;
          return aDur.compareTo(bDur);
        case 'Longest':
          final aDur = a['duration'] as num? ?? 0;
          final bDur = b['duration'] as num? ?? 0;
          return bDur.compareTo(aDur);
        default:
          return 0;
      }
    });
  }

  Future<void> triggerNewSearch(String query) async {
    _isLoading = true;
    _videos = [];
    _errorMessage = null;
    _focusedIndex = 0;
    notifyListeners();

    await prefetchYouTubeShorts(limit: 10, query: query, force: true);

    _videos = List.from(globalYouTubeShorts.value);
    _isLoading = globalYouTubeShorts.value.isEmpty;
    _errorMessage = youtubeShortsError;
    notifyListeners();

    if (_videos.isNotEmpty) {
      ShortsStreamCache.instance.warmUpAround(0, _videos);
      pool.updateActiveIndex(0, _videos);
    }
  }

  @override
  void dispose() {
    globalYouTubeShorts.removeListener(_onGlobalShortsChanged);
    pageController.dispose();
    pool.dispose();
    super.dispose();
  }
}
