import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent settings and scores. Every read falls back to a default and
/// every write failure is logged, so storage problems never reach gameplay.
class LocalStore {
  LocalStore._(this._prefs);

  /// Works without persistence (storage unavailable, or tests).
  LocalStore.memory() : _prefs = null;

  static const bestKey = 'best_score';
  static const pendingKey = 'pending_leaderboard_score';
  static const mutedKey = 'muted';

  static Future<LocalStore> open() async {
    try {
      return LocalStore._(await SharedPreferences.getInstance());
    } catch (e) {
      debugPrint('LocalStore unavailable, using memory: $e');
      return LocalStore.memory();
    }
  }

  final SharedPreferences? _prefs;
  final Map<String, Object> _memory = {};

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

  int get best => _read<int>(bestKey) ?? 0;

  /// Stores [score] if it beats [best]; returns whether it did.
  Future<bool> recordBest(int score) async {
    if (score <= best) return false;
    await _write(bestKey, score);
    return true;
  }

  /// Best score not yet accepted by the platform leaderboard.
  int? get pendingScore => _read<int>(pendingKey);
  Future<void> setPendingScore(int? score) => _write(pendingKey, score);

  bool get muted => _read<bool>(mutedKey) ?? false;
  Future<void> setMuted(bool value) => _write(mutedKey, value);
}
