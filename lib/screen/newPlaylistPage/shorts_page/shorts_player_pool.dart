import 'package:media_kit/media_kit.dart';

class ShortsPlayerPool {
  final int poolSize;
  final List<Player> _allPlayers;
  final List<Player> _availablePlayers = [];

  ShortsPlayerPool({required this.poolSize})
      : _allPlayers = List.generate(poolSize, (_) => Player()) {
    _availablePlayers.addAll(_allPlayers);
  }

  /// Acquires an idle player from the pool. Returns null if all players are currently in use.
  Player? acquire() {
    if (_availablePlayers.isEmpty) {
      return null;
    }
    return _availablePlayers.removeAt(0);
  }

  /// Releases a player back into the pool. Stops playback to free hardware resources.
  void release(Player player) {
    if (!_allPlayers.contains(player)) return;
    
    // Stop playback immediately to free native decoder resources
    player.stop();
    
    if (!_availablePlayers.contains(player)) {
      _availablePlayers.add(player);
    }
  }

  /// Disposes all player instances on app shutdown/exit
  void dispose() {
    for (final player in _allPlayers) {
      player.dispose();
    }
    _allPlayers.clear();
    _availablePlayers.clear();
  }
}
