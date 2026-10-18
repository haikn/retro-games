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
/// game simply stays silent.
class AudioService {
  AudioService(this._player, {this._muted = false});

  static const rotor = 'rotor.wav';
  static const crashFile = 'crash.wav';
  static const bestFile = 'best.wav';
  static const clickFile = 'click.wav';

  final SoundPlayer _player;
  bool _available = false;
  bool _muted;
  bool _rotorOn = false;

  bool get available => _available;
  bool get muted => _muted;

  Future<void> load() async {
    try {
      await _player.configureAmbient();
      await _player.preload([rotor, crashFile, bestFile, clickFile]);
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

  Future<void> startRotor() async {
    if (!_canPlay || _rotorOn) return;
    _rotorOn = true;
    await _guard('rotor', () => _player.startLoop(rotor, 0.5));
  }

  Future<void> stopRotor() async {
    if (!_rotorOn) return;
    _rotorOn = false;
    await _guard('rotor stop', _player.stopLoop);
  }

  Future<void> crash() async {
    if (_canPlay) await _guard('crash', () => _player.play(crashFile, 0.9));
  }

  Future<void> newBest() async {
    if (_canPlay) await _guard('jingle', () => _player.play(bestFile, 0.9));
  }

  Future<void> click() async {
    if (_canPlay) await _guard('click', () => _player.play(clickFile, 0.6));
  }

  Future<void> setMuted(bool value) async {
    _muted = value;
    if (value) await stopRotor();
  }
}
