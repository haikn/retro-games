import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';

/// Minimal playback backend, so [AudioService] can be faked in tests.
abstract interface class SoundPlayer {
  Future<void> configureAmbient();
  Future<void> preload(List<String> files);
  Future<void> play(String file, double volume);
  Future<void> startLoop(String file, double volume);
  Future<void> stopLoop();

  /// Releases every native player; the player is unusable afterwards.
  Future<void> dispose();
}

/// audioplayers backend that loads each game's sounds from its own package
/// (`packages/<game>/assets/audio/`).
///
/// Every file gets [voices] players up front, reused round-robin: creating a
/// player per sound costs several platform round trips (the sound lags the
/// game), and in low-latency mode a player never reports completion, so
/// players created per sound were never freed and piled up until the app
/// slowed down and was killed. Position polling is off (it ran every frame
/// for every "playing" player, and low-latency players never stop playing).
class FlameSoundPlayer implements SoundPlayer {
  FlameSoundPlayer({String prefix = 'assets/audio/'})
    : _cache = _caches.putIfAbsent(prefix, () => AudioCache(prefix: prefix));

  /// Sounds bundled in package [package] under `assets/audio/`.
  FlameSoundPlayer.forPackage(String package)
    : this(prefix: 'packages/$package/assets/audio/');

  /// How many times one sound can overlap itself.
  static const voices = 3;

  /// One cache per folder for the whole app (it copies each file once).
  static final _caches = <String, AudioCache>{};

  /// iOS: ambient category (respects the silent switch, mixes with the
  /// player's music). Android: game usage without audio focus, so music
  /// apps keep playing.
  static final _context = AudioContext(
    iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
    android: const AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.game,
      audioFocus: AndroidAudioFocus.none,
    ),
  );

  final AudioCache _cache;
  final _voices = <String, List<AudioPlayer>>{};
  final _next = <String, int>{};
  final _all = <AudioPlayer>[];
  AudioPlayer? _loop;
  String? _wantLoop;
  bool _disposed = false;

  @override
  Future<void> configureAmbient() =>
      AudioPlayer.global.setAudioContext(_context);

  @override
  Future<void> preload(List<String> files) async {
    await _cache.loadAll(files);
    for (final file in files) {
      final players = <AudioPlayer>[];
      for (var i = 0; i < voices; i++) {
        final p = await _create(file);
        if (p == null) return;
        players.add(p);
      }
      _voices[file] = players;
    }
  }

  /// A ready player for [file], or null once disposed.
  Future<AudioPlayer?> _create(String file) async {
    if (_disposed) return null;
    final player = AudioPlayer()
      ..audioCache = _cache
      ..positionUpdater = null;
    _all.add(player);
    await player.setPlayerMode(PlayerMode.lowLatency);
    await player.setAudioContext(_context);
    await player.setReleaseMode(ReleaseMode.stop);
    await player.setSource(AssetSource(file));
    return _disposed ? null : player;
  }

  @override
  Future<void> play(String file, double volume) async {
    final players = _voices[file];
    if (players == null || _disposed) return; // not loaded yet
    final i = _next[file] ?? 0;
    _next[file] = (i + 1) % players.length;
    final p = players[i];
    // A low-latency player only restarts after stop().
    await p.stop();
    if (p.volume != volume) await p.setVolume(volume);
    await p.resume();
  }

  /// Loops on the file's first preloaded player (already loaded, so it
  /// starts at once); a [stopLoop] during the start wins.
  @override
  Future<void> startLoop(String file, double volume) async {
    final p = _voices[file]?.first;
    if (p == null || _disposed) return;
    _wantLoop = file;
    await p.stop();
    await p.setReleaseMode(ReleaseMode.loop);
    await p.setVolume(volume);
    if (_wantLoop != file || _disposed) return;
    _loop = p;
    await p.resume();
  }

  @override
  Future<void> stopLoop() async {
    _wantLoop = null;
    final loop = _loop;
    _loop = null;
    if (loop == null) return;
    await loop.stop();
    await loop.setReleaseMode(ReleaseMode.stop);
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _loop = null;
    _wantLoop = null;
    final players = List.of(_all);
    _all.clear();
    _voices.clear();
    for (final p in players) {
      await p.dispose();
    }
  }
}

/// Game sounds. Failures are logged and never thrown; if loading fails the
/// game simply stays silent. Every game ships `click.wav` (menu keys) and
/// `best.wav` (new-best jingle) next to its own sounds.
class AudioService {
  AudioService(this._player, {required List<String> files, this._muted = false})
    : files = {clickFile, bestFile, ...files}.toList();

  static const clickFile = 'click.wav';
  static const bestFile = 'best.wav';

  /// Files preloaded by [load].
  final List<String> files;

  final SoundPlayer _player;
  bool _available = false;
  bool _muted;
  String? _loop;

  bool get available => _available;
  bool get muted => _muted;

  /// The looping sound, if one is playing.
  String? get looping => _loop;

  Future<void> load() async {
    try {
      await _player.configureAmbient();
      await _player.preload(files);
      _available = true;
    } catch (e) {
      debugPrint('Audio disabled: $e');
    }
  }

  bool get _canPlay => _available && !_muted;

  Future<void> _guard(String what, Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      debugPrint('Audio $what failed: $e');
    }
  }

  /// Plays [file] once (ignored when muted or unavailable).
  Future<void> play(String file, {double volume = 0.8}) async {
    if (_canPlay) await _guard(file, () => _player.play(file, volume));
  }

  /// Loops [file] until [stopLoop]; one loop at a time.
  Future<void> startLoop(String file, {double volume = 0.5}) async {
    if (!_canPlay || _loop != null) return;
    _loop = file;
    await _guard('$file loop', () => _player.startLoop(file, volume));
  }

  Future<void> stopLoop() async {
    if (_loop == null) return;
    _loop = null;
    await _guard('loop stop', _player.stopLoop);
  }

  Future<void> click() => play(clickFile, volume: 0.6);

  Future<void> newBest() => play(bestFile, volume: 0.9);

  /// Stops all sound and frees the players (when leaving a game).
  Future<void> dispose() async {
    _available = false;
    _loop = null;
    await _guard('dispose', _player.dispose);
  }

  Future<void> setMuted(bool value) async {
    _muted = value;
    if (value) await stopLoop();
  }
}
