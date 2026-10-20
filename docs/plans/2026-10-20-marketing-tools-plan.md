# Marketing tools plan (all free)

Companion to [marketing-plan.md](marketing-plan.md). Tools live in `marketing/` (Node, no paid services) or in the app.

Related docs: [channels](../marketing-channels.md) · [social posts](../marketing-social-posts.md)

| # | Tool | Where | Status | Free stack |
|---|---|---|---|---|
| 1 | Landing page + waitlist | `marketing/site/` | Built (placeholders to fill) | Static HTML; host on Cloudflare Pages or GitLab Pages; Web3Forms free tier for the email form |
| 2 | Content calendar generator | `marketing/tools/calendar.mjs` | Built, tested | `node marketing/tools/calendar.mjs <launch-date> > calendar.csv`; import into Google Sheets or Buffer free plan |
| 3 | Store screenshot generator | `app/test_marketing/capture_test.dart` | Written, **not yet run** | Renders the real app in a Flutter test, adds caption and frame, writes 1290x2796 PNGs to `marketing/out/screenshots/` |
| 4 | Gameplay clip recorder | same test + `marketing/tools/capture.mjs` | Written, **not yet run** | 10 s scripted runs of Copter, Snake, Hop dumped as frames, encoded to 9:16 MP4 and GIF with free `ffmpeg` |
| 5 | Share-score image | `packages/lcd_kit` game-over screen | Design only | `RepaintBoundary` to PNG, `share_plus` (free) |

## Remaining work (for later)

- [ ] Fill the landing page placeholders (Web3Forms key, contact email) and deploy it.
- [ ] Install Flutter and ffmpeg, run `node marketing/tools/capture.mjs`, fix any first-run errors in `capture_test.dart`.
- [ ] Improve the scripted play in `_play` so runs last the full 10 s.
- [ ] Review the screenshots and clips; adjust captions.
- [ ] Build the share-score image (see the design section below).
- [ ] Add Blocks captures once the IP review (C4) clears it.
- [ ] Add privacy-friendly analytics events (see [marketing-plan.md](../marketing-plan.md), section 4).

## Running 3 and 4

Needs the Flutter SDK and, for clips, `ffmpeg` on PATH (neither was installed on the machine where these were written).

```
node marketing/tools/capture.mjs shots   # screenshots only
node marketing/tools/capture.mjs clips   # frames + mp4 + gif
node marketing/tools/capture.mjs         # both
```

Or directly: `cd app && flutter test test_marketing --dart-define=CAPTURE=shots`.

Known limits: the scripted play is simple (Snake swipes in a loop, Copter taps, Hop swipes up), so runs may end early; adjust `_play` in the test. Blocks is not captured (IP review C4). The test lives in `test_marketing/` so `flutter test` does not run it by default.

## Before using the site

- In `marketing/site/index.html`: set the Web3Forms `access_key` and the contact email; same email in `privacy.html`.
- Preview locally: `cd marketing/site && npx serve`.
- Deploy: push `marketing/site` to Cloudflare Pages or GitLab Pages (publish directory `marketing/site`).

## Share-score image (design, to decide later)

- Where: a `Share` soft key on the game-over screen in `packages/lcd_kit/lib/src/arcade/arcade_view.dart`.
- What: render the LCD buffer plus score and "LCD Arcade" with the store link to a PNG, hand it to the OS share sheet.
- Cost of the change: new dependency (`share_plus`), a new string in `LcdStrings` that must pass the width test, and a store privacy-label check. Touches all arcade games, so implement and test it on a machine with Flutter.
