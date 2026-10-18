import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';

/// Minimal playback backend, so [AudioService] can be faked in tests.
abstract interface class SoundPlayer {
  Future<void> configureAmbient();
  Future<void> preload(List<String> files);
  Future<void> play(String file, double volume);
  Future<void> startLoop(String file, double volume);
  Future<void> stopLoop();
}

/// audioplayers backend with its own asset cache, so each game can load its
/// sounds from its own package (`packages/<game>/assets/audio/`).
class FlameSoundPlayer implements SoundPlayer {
  FlameSoundPlayer({String prefix = 'assets/audio/'})
    : _cache = AudioCache(prefix: prefix);

  /// Sounds bundled in package [package] under `assets/audio/`.
  FlameSoundPlayer.forPackage(String package)
    : this(prefix: 'packages/$package/assets/audio/');

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
  AudioPlayer? _loop;

  @override
  Future<void> configureAmbient() =>
      AudioPlayer.global.setAudioContext(_context);

  @override
  Future<void> preload(List<String> files) => _cache.loadAll(files);

  Future<AudioPlayer> _start(
    String file,
    double volume,
    ReleaseMode mode,
  ) async {
    final player = AudioPlayer()..audioCache = _cache;
    await player.setAudioContext(_context);
    await player.setReleaseMode(mode);
    await player.play(
      AssetSource(file),
      volume: volume,
      mode: PlayerMode.lowLatency,
    );
    return player;
  }

  @override
  Future<void> play(String file, double volume) async {
    final player = await _start(file, volume, ReleaseMode.release);
    player.onPlayerComplete.first.then((_) => player.dispose());
  }

  @override
  Future<void> startLoop(String file, double volume) async {
    _loop = await _start(file, volume, ReleaseMode.loop);
  }

  @override
  Future<void> stopLoop() async {
    final loop = _loop;
    _loop = null;
    if (loop == null) return;
    await loop.stop();
    await loop.dispose();
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

  Future<void> setMuted(bool value) async {
    _muted = value;
    if (value) await stopLoop();
  }
}
