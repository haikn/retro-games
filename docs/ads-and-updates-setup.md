# Ads and update prompts: setup

The app code is done. Until the steps below are finished, every build behaves as before: no ads, no update prompts. That's because Firebase isn't set up yet, and the app falls back to its defaults whenever Firebase can't be reached.

What the code does:

- **Banner** (AdMob) under the four tiles on the home screen only, never inside a game. It takes no space until an ad has loaded.
- **On/off without a new release:** Firebase Remote Config switches the banner, sets the ad unit IDs, and sets the update versions. Running apps pick up a change within seconds through real-time updates. Otherwise they pick it up at the next launch.
- **Consent first:** the ads SDK starts only when ads are switched on, and only after Google's consent form. That form appears only where the law requires it (EEA, UK, Switzerland). Where players must be able to change their choice, the home screen shows an `Ads` soft key next to `Select`.
- **Update prompt:** if the store has a newer version, the home screen shows `New version` with `Update` and `Later`. `Later` hides it until the next release. Below the minimum version it shows `Must update` with only `Update`, and the games stay locked.
- **Test ads in test builds:** debug and playtest builds always show Google's test ads, never real ones. Tapping your own real ads can get the AdMob account suspended.

## 1. Firebase project (≈ 15 min)

Use the final app ID from decision C2 if it's decided. Firebase apps are registered per app ID.

1. https://console.firebase.google.com → **Add project** (Google Analytics can stay off).
2. Install the tools once: `dart pub global activate flutterfire_cli` and `npm install -g firebase-tools`. Then run `firebase login`.
3. From `app/`, run `flutterfire configure` and pick the project and the Android and iOS platforms. It writes `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist` and `lib/firebase_options.dart`, and adds the Google Services Gradle plugin.
4. No code change is needed: `Firebase.initializeApp()` reads the two native files. Rebuild, then check the Android log for `Firebase not set up`. It should no longer appear.

## 2. Remote Config parameters

Firebase console → **Remote Config** → add these parameters, then **Publish changes**. The defaults (in-app value in brackets) mean nothing changes until you set a value.

| Parameter | Type | Default | Meaning |
|---|---|---|---|
| `ads_enabled` | Boolean | `false` | Show the home-screen banner |
| `ads_banner_android` | String | `""` | AdMob banner unit ID for Android |
| `ads_banner_ios` | String | `""` | AdMob banner unit ID for iOS |
| `update_latest_version` | String | `""` | Newest store version, e.g. `1.1.0`. Older apps offer it once |
| `update_min_version` | String | `""` | Oldest version still allowed to play. Use only for a serious bug |
| `ios_app_store_id` | String | `""` | Digits of the App Store ID (from App Store Connect), for the iPhone `Update` link |

Turning ads off: set `ads_enabled` to `false` and publish. Running apps remove the banner, and new launches never show it.

Releasing a new version: once it's live in **both** stores, set `update_latest_version` to it. If one store is still reviewing, wait, or players there get a prompt for a version they can't download yet.

## 3. AdMob (≈ 20 min, and up to a few days for approval)

1. https://admob.google.com → sign up and link it to the same Google account.
2. **Apps → Add app**, once for Android and once for iOS. Each gets an **App ID** (`ca-app-pub-…~…`).
3. In each app, **Ad units → Banner**. Each gets a **unit ID** (`ca-app-pub-…/…`). Put these in `ads_banner_android` and `ads_banner_ios`.
4. Replace Google's **test** App IDs in the project with the real ones. Unlike the unit IDs, these live inside the app:
   - `app/android/app/src/main/AndroidManifest.xml`: `com.google.android.gms.ads.APPLICATION_ID`
   - `app/ios/Runner/Info.plist`: `GADApplicationIdentifier`
5. **Privacy & messaging → GDPR → Create message** for both apps and publish it. This is the consent form the app shows in Europe. Without it, ads in the EEA are limited.
6. Add an `app-ads.txt` file to the developer website listed in the stores. AdMob shows the exact line to put in it.

## 4. Store forms (before the release with ads)

Ads change what you declare in both stores:

- **Play Console:** **App content → Ads → "Yes, my app contains ads"**. **Data safety**: the AdMob SDK collects device or other IDs, app interactions, diagnostics and approximate location, for advertising and analytics, shared with Google. Google lists exact answers at https://developers.google.com/admob/android/privacy/play-data-disclosure
- **App Store Connect:** in **App Privacy**, add the AdMob data types per Google's guide at https://developers.google.com/admob/ios/privacy/data-disclosure. Data used for tracking: none, as long as the app doesn't ask for App Tracking Transparency permission (it doesn't, so iPhone ads are non-personalised).
- **Age rating:** answer "contains ads" in both questionnaires. Keep the target age 13+ (Copter decision D3). Declaring under-13 players brings the Families and Kids rules, which need different ad settings.
- **Privacy policy:** add a paragraph on AdMob and the consent form.

## Testing on a phone before all this exists

- `flutter build apk --release --dart-define=PLAYTEST=true --dart-define=ADS_PREVIEW=true` shows Google's test banner without Firebase. It goes through the same consent and banner code.
- `PLAYTEST=true` on its own opens Blocks in a release build. Store builds never use either switch.

## iOS builds on this Mac

Firebase and AdMob come to iOS as Swift packages. This Mac's git setup has `safe.bareRepository = explicit`, which stops Xcode from reading its package cache ("Couldn't get the list of tags … cannot use bare repository"). To relax it for one command only:

```sh
GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.bareRepository GIT_CONFIG_VALUE_0=all flutter build ios
```
