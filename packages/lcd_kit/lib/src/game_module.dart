import 'package:flutter/widgets.dart';

import 'leaderboard_service.dart';
import 'local_store.dart';

enum GameOrientation { portrait, landscape }

/// App-wide sound on/off, persisted; shared by every game.
class SoundSetting extends ChangeNotifier {
  SoundSetting(this._store) : _on = !_store.muted;

  final LocalStore _store;
  bool _on;

  bool get on => _on;

  Future<void> set(bool on) async {
    if (on == _on) return;
    _on = on;
    notifyListeners();
    await _store.setMuted(!on);
  }
}

/// What the collection gives a game: its own storage namespace, the shared
/// sound setting, its leaderboard and a way back to the launcher.
class GameHost {
  GameHost({
    required this.store,
    required this.sound,
    required this.leaderboard,
    required this.exitToLauncher,
  });

  /// Scoped to the game ([LocalStore.scoped]).
  final LocalStore store;
  final SoundSetting sound;
  final LeaderboardService leaderboard;
  final VoidCallback exitToLauncher;
}

/// One game in the collection.
abstract class GameModule {
  const GameModule();

  /// Storage namespace and stable identifier (`copter`).
  String get id;

  /// Name on the launcher tile.
  String get title;

  /// 12×12 launcher icon as rows of `#` (ink) and `.` (off).
  List<String> get icon;

  GameOrientation get orientation;

  LeaderboardIds get leaderboard;

  /// The game's own screens, starting at its menu.
  Widget build(BuildContext context, GameHost host);
}
