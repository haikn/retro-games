# Leaderboards setup (M5)

The app code is done: it signs in once on the title screen, submits only new bests, keeps a failed submission and retries it after the next successful sign-in, and shows a short message on the Top score screen when `Online scores` can't open. What remains is creating the leaderboards in the store consoles and pasting two IDs into the project.

Use the final app id from decision D1 before you create store records; the app id cannot be changed afterwards. The working id is `com.nhk.caveCopter` (iOS) / `com.nhk.cave_copter` (Android).

## iOS: Game Center

Needs a paid Apple Developer Program membership (a free Personal Team cannot sign the Game Center entitlement).

1. developer.apple.com › Identifiers › your App ID › enable **Game Center**.
2. App Store Connect › Apps › **New App** with that bundle id.
3. In the app › **Services › Game Center › Leaderboards** › add a **Classic** leaderboard:
   - Reference name `Distance`, **Leaderboard ID `cave_copter_distance`** (matches `LeaderboardIds.ios`)
   - Score format: Integer · Sort: High to Low
   - Score range (tamper limit): 0 – 1 000 000
4. Enable Game Center on the app version.

The entitlement is already in the project (`ios/Runner/Runner.entitlements`) for **Release and Profile** builds only, so Debug builds still install with a free Apple ID. Test Game Center with a Profile or Release build (e.g. `flutter run --profile`) on an iPhone signed into a Game Center sandbox account.

## Android: Google Play Games

1. Play Console › create the app with the package name.
2. **Grow › Play Games Services › Setup** › create a games project.
3. Add **Android credentials** for the package with the SHA-1 of **both** the upload key and the Play App Signing key (Play Console › Setup › App signing), plus your debug key for local testing (`cd android && ./gradlew signingReport`).
4. **Leaderboards** › create `Distance` (integer, higher is better, limits 0 – 1 000 000). Note the **Leaderboard ID** (starts with `Cgk`) and the numeric **project ID**.
5. Add yourself as a tester.

Then, in the project:

1. `lib/services/leaderboard_ids.dart`: set `android` to the leaderboard ID.
2. Create `android/app/src/main/res/values/games-ids.xml`:
   ```xml
   <?xml version="1.0" encoding="utf-8"?>
   <resources>
       <string name="game_services_project_id" translatable="false">YOUR_NUMERIC_PROJECT_ID</string>
   </resources>
   ```
3. In `android/app/src/main/AndroidManifest.xml`, inside `<application>`:
   ```xml
   <meta-data
       android:name="com.google.android.gms.games.APP_ID"
       android:value="@string/game_services_project_id" />
   ```
4. `flutter test` — `test/platform_config_test.dart` checks that the manifest entry and the leaderboard ID are set together.

Until then Android shows `Not available` for `Online scores`; new bests are kept as pending and sent once Play Games works.
