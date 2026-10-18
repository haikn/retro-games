import 'package:lcd_kit/lcd_kit.dart';

/// Copter's leaderboards (see docs/leaderboards-setup.md).
///
/// Game Center ID chosen when creating the leaderboard in App Store Connect
/// ("Distance", integer, high to low). The Play Games ID comes from Play
/// Console and stays a placeholder until the leaderboard exists.
const copterLeaderboard = LeaderboardIds(
  ios: 'cave_copter_distance',
  android: 'REPLACE_WITH_PLAY_CONSOLE_LEADERBOARD_ID',
);
