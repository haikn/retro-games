# Leaderboards setup

The app code is done for all four games: it signs in once at launch (on the launcher), submits only new bests per game, keeps a failed submission and retries it after the next successful sign-in, and shows a short message on a game's Top score screen when `Online scores` can't open. What remains is creating the leaderboards in the store consoles and pasting the Play Games IDs into the project.

The app is **Retro LCD Games** with the app id `com.nhk.retrolcdgames` on both platforms (decision C2). The app id cannot be changed once store records exist.

| Game | Game Center leaderboard ID | Play Games ID set in |
|---|---|---|
| Copter | `cave_copter_distance` ("Distance") | `packages/games/copter/lib/copter_leaderboard.dart` |
| Snake | `lcd_arcade_snake` ("Snake") | `packages/games/snake/lib/snake.dart` |
| Blocks | `lcd_arcade_blocks` ("Blocks") — only once decision C4 clears it | `packages/games/blocks/lib/blocks.dart` |
| Hop | `lcd_arcade_hop` ("Hop") | `packages/games/hop/lib/hop.dart` |

## iOS: Game Center

Needs a paid Apple Developer Program membership (a free Personal Team cannot sign the Game Center entitlement).

1. developer.apple.com › Identifiers › your App ID › enable **Game Center**.
2. App Store Connect › Apps › **New App** with that bundle id.
3. In the app › **Services › Game Center › Leaderboards** › add one **Classic** leaderboard per game, with the IDs from the table above:
   - Score format: Integer · Sort: High to Low
   - Score range (tamper limit): 0 – 1 000 000
4. Enable Game Center on the app version.

The entitlement is already in the project (`app/ios/Runner/Runner.entitlements`) for **Release and Profile** builds only, so Debug builds still install with a free Apple ID. Test Game Center with a Profile or Release build (e.g. `flutter run --profile`) on an iPhone signed into a Game Center sandbox account.

## Android: Google Play Games

1. Play Console › create the app with the package name.
2. **Grow › Play Games Services › Setup** › create a games project.
3. Add **Android credentials** for the package with the SHA-1 of **both** the upload key and the Play App Signing key (Play Console › Setup › App signing), plus your debug key for local testing (`cd android && ./gradlew signingReport`).
4. **Leaderboards** › create one per game (integer, higher is better, limits 0 – 1 000 000). Note each **Leaderboard ID** (starts with `Cgk`) and the numeric **project ID**.
5. Add yourself as a tester.

Then, in the project:

1. Set each game's `android` leaderboard ID in the file listed in the table above.
2. Create `app/android/app/src/main/res/values/games-ids.xml`:
   ```xml
   <?xml version="1.0" encoding="utf-8"?>
   <resources>
       <string name="game_services_project_id" translatable="false">YOUR_NUMERIC_PROJECT_ID</string>
   </resources>
   ```
3. In `app/android/app/src/main/AndroidManifest.xml`, inside `<application>`:
   ```xml
   <meta-data
       android:name="com.google.android.gms.games.APP_ID"
       android:value="@string/game_services_project_id" />
   ```
4. `cd app && flutter test` — `test/platform_config_test.dart` checks that the manifest entry and the leaderboard IDs are set together.

Until then Android shows `Not available` for `Online scores`; new bests are kept as pending and sent once Play Games works.
