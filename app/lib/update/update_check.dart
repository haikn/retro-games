import '../remote/remote_settings.dart';

/// What the launcher asks of an outdated app.
enum UpdateNeed {
  none,

  /// A newer version exists: offer it once, `Later` dismisses it.
  optional,

  /// Older than the minimum version: the games stay locked until updated.
  required,
}

/// `1.2.3` (or `1.2.3+45`) → 1002003; null when not a version.
int? versionCode(String version) {
  final core = version.trim().split('+').first;
  final parts = core.split('.');
  if (parts.isEmpty || parts.length > 3) return null;
  final nums = [for (final p in parts) int.tryParse(p)];
  if (nums.any((n) => n == null || n < 0 || n > 999)) return null;
  final [major, minor, patch] = [...nums.cast<int>(), 0, 0].take(3).toList();
  return major * 1000000 + minor * 1000 + patch;
}

/// The update to ask for when running [current], given [settings] and the
/// version code of the last optional prompt the player dismissed.
UpdateNeed updateNeed(
  String current,
  RemoteSettings settings, {
  int dismissed = 0,
}) {
  final now = versionCode(current);
  if (now == null) return UpdateNeed.none;
  final min = versionCode(settings.minVersion);
  if (min != null && now < min) return UpdateNeed.required;
  final latest = versionCode(settings.latestVersion);
  if (latest != null && now < latest && latest != dismissed) {
    return UpdateNeed.optional;
  }
  return UpdateNeed.none;
}
