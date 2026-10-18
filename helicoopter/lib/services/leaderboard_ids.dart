/// Platform leaderboard IDs (spec: "configured per platform in one constants
/// file").
abstract final class LeaderboardIds {
  /// Game Center leaderboard ID, chosen when creating the leaderboard in App
  /// Store Connect (Services › Game Center › Leaderboards, "Distance",
  /// integer, high to low).
  static const ios = 'cave_copter_distance';

  /// Play Games leaderboard ID from Play Console (Play Games Services ›
  /// Leaderboards; starts with "Cgk"). Placeholder until the leaderboard
  /// exists; see docs/leaderboards-setup.md for the Android manifest step.
  static const android = 'REPLACE_WITH_PLAY_CONSOLE_LEADERBOARD_ID';

  /// Play Games stays off until the real IDs exist: the SDK needs the
  /// project ID in the manifest, and a placeholder would fail at runtime.
  static const androidConfigured =
      android != 'REPLACE_WITH_PLAY_CONSOLE_LEADERBOARD_ID';
}
