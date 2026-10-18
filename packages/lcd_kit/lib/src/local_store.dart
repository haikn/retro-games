import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent settings and scores. Every read falls back to a default and
/// every write failure is logged, so storage problems never reach gameplay.
///
/// Scores (best, pending leaderboard score) live in a per-game [namespace]
/// (`copter.best_score`); the sound setting is app-wide.
class LocalStore {
  LocalStore._(this._prefs, this._memory, this.namespace);

  /// Works without persistence (storage unavailable, or tests).
  LocalStore.memory() : this._(null, {}, '');

  static const bestKey = 'best_score';
  static const pendingKey = 'pending_leaderboard_score';
  static const mutedKey = 'muted';

  static Future<LocalStore> open() async {
    try {
      return LocalStore._(await SharedPreferences.getInstance(), {}, '');
    } catch (e) {
      debugPrint('LocalStore unavailable, using memory: $e');
      return LocalStore.memory();
    }
  }

  final SharedPreferences? _prefs;
  final Map<String, Object> _memory;

  /// Key prefix for this game's scores; empty for the app-level store.
  final String namespace;

  /// The same storage, with scores kept under [game]'s namespace.
  LocalStore scoped(String game) => LocalStore._(_prefs, _memory, game);

  String _scoped(String key) => namespace.isEmpty ? key : '$namespace.$key';

  /// One-time move of pre-collection, unprefixed scores (Cave Copter 1.x)
  /// into [game]'s namespace. Existing namespaced values are never replaced.
  Future<void> migrateLegacyScores(String game) async {
    final target = scoped(game);
    for (final key in [bestKey, pendingKey]) {
      final legacy = _read<int>(key);
      if (legacy == null) continue;
      if (target._read<int>(target._scoped(key)) == null) {
        await target._write(target._scoped(key), legacy);
      }
      await _write(key, null);
    }
  }

  T? _read<T>(String key) {
    try {
      final v = _prefs != null ? _prefs.get(key) : _memory[key];
      return v is T ? v : null;
    } catch (e) {
      debugPrint('LocalStore read $key failed: $e');
      return null;
    }
  }

  Future<void> _write(String key, Object? value) async {
    try {
      final prefs = _prefs;
      if (prefs == null) {
        value == null ? _memory.remove(key) : _memory[key] = value;
      } else if (value == null) {
        await prefs.remove(key);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is bool) {
        await prefs.setBool(key, value);
      }
    } catch (e) {
      debugPrint('LocalStore write $key failed: $e');
    }
  }

  int get best => _read<int>(_scoped(bestKey)) ?? 0;

  /// Stores [score] if it beats [best]; returns whether it did.
  Future<bool> recordBest(int score) async {
    if (score <= best) return false;
    await _write(_scoped(bestKey), score);
    return true;
  }

  /// Best score not yet accepted by the platform leaderboard.
  int? get pendingScore => _read<int>(_scoped(pendingKey));
  Future<void> setPendingScore(int? score) =>
      _write(_scoped(pendingKey), score);

  /// A per-game integer setting (e.g. `level`), or [fallback].
  int intSetting(String key, int fallback) =>
      _read<int>(_scoped(key)) ?? fallback;
  Future<void> setIntSetting(String key, int value) =>
      _write(_scoped(key), value);

  bool get muted => _read<bool>(mutedKey) ?? false;
  Future<void> setMuted(bool value) => _write(mutedKey, value);
}
