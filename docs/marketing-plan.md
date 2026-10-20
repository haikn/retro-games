# LCD Arcade — Marketing and Analytics Plan

Date: 2026-10-20 · Status: draft v1 · Owner: NHK

Working name "LCD Arcade" (decision C2 in the [collection spec](specs/2026-10-18-lcd-arcade-design.md)). All names, handles and claims below must be re-checked once the final name and app id are fixed.

## 1. Product snapshot (what we are marketing)

| Item | Fact |
|---|---|
| Product | One mobile app, four small monochrome-LCD games: Copter, Snake, Blocks, Hop |
| Look and feel | Two-tone pixel grid, Silkscreen font, Nokia-style menus, square-wave sounds |
| Platforms | iOS and Android (Flutter) |
| Price model | Free, no ads, no in-app purchases, no accounts (v1 scope) |
| Social hook | One leaderboard per game (Game Center / Play Games) |
| Language | English (DE, FR, ES, PT planned) |
| Session length | 1–5 minutes: fits queues, commutes, breaks |
| Constraint | Blocks is held back until the IP review (C4). Never use "Tetris", "Crossy Road", "Nokia", "Snake II" in copy, hashtags paid for, or ad keywords |

### Strengths to lead with
- Instant: no tutorial, no login, no ads, no pop-ups.
- Nostalgia with a clean, honest look (the "phone from 2002" feeling).
- Four games in one tiny install; light on low-end devices.
- Leaderboards give a reason to return and to brag.

### Weaknesses and risks
- Crowded category; generic genre names have weak search volume of their own.
- No monetization in v1, so paid acquisition has no payback. Budget must stay small and organic-first.
- Trademark exposure (C3, C4, C5): keyword and hashtag choices must stay generic.
- English only at launch.

## 2. Audience and positioning

### Positioning statement
> For anyone with a spare minute, LCD Arcade is a tiny collection of classic phone games with no ads and no sign-up. Open it, play, put it away.

Tagline candidates (A/B test in store screenshots and social):
1. "Your spare minute, 2002 style."
2. "Four classic games. Zero ads."
3. "Pocket-size. Pixel-perfect."
4. "Remember waiting for the bus? Play instead."

### Segments

| Segment | Who | Motivation | Where they are | Message |
|---|---|---|---|---|
| S1 Nostalgics (30–50) | Grew up with Nokia/early phones | Memory, comfort | Facebook, Reddit, YouTube, retro blogs | "The games you remember, without the ads." |
| S2 Casual spare-time players (18–65) | Commuters, parents, office workers | Kill 2 minutes | App store search, TikTok/Reels, Facebook | "One tap. One minute. Done." |
| S3 Retro/pixel-art fans (16–35) | Collectors, indie fans, designers | Aesthetic, craft | Reddit, Mastodon/Bluesky, itch.io, X, Instagram | "A pixel-grid LCD look, built carefully." |
| S4 Competitive score chasers | High-score hunters | Rank, bragging | Leaderboards, Discord, Reddit | "Top the board on Copter." |
| S5 Gifters/families | Parents with kids, grandparents | Safe, simple, no purchases | Facebook, parenting blogs | "No ads, no purchases, no accounts." |

Primary focus for the first 90 days: **S2 and S1** (largest, easiest to reach). S3 and S4 are the early advocates who generate content.

## 3. Goals and KPIs

North-star metric: **weekly active players who finish at least 3 sessions** (W3S).

| Phase | Window | Goal | Target (adjust after the first 4 weeks of real data) |
|---|---|---|---|
| Pre-launch | T-6 to T-0 weeks | Build an audience before release | 500 email/waitlist signups or 1 000 followers across channels; 100 beta testers |
| Launch | Weeks 1–4 | Installs and reviews | 5 000 installs; 4.5+ store rating; 100+ ratings |
| Growth | Months 2–3 | Retention and reach | D1 ≥ 35%, D7 ≥ 15%, D30 ≥ 6%; 20 000 cumulative installs |
| Sustain | Months 4–12 | Steady organic flow | 30% of installs from organic search; monthly content cadence |

Secondary KPIs: store page conversion (visit to install) ≥ 30%; crash-free sessions ≥ 99.5%; average sessions per user per day ≥ 2; share of players who open 2+ games ≥ 40%; leaderboard participation ≥ 25% of active players.

## 4. Analytics plan

Privacy first: the product promise is "no accounts, no ads". Use privacy-friendly tools, no advertising ID, no personal data, a plain consent/notice screen where required (GDPR/ePrivacy, ATT is not needed if nothing is tracked across apps). Update the store privacy labels to match.

### 4.1 Tooling

| Need | Tool (suggested) | Notes |
|---|---|---|
| Store funnel | App Store Connect Analytics, Google Play Console (Store listing experiments, vitals) | Free, no SDK |
| In-app events | Firebase Analytics (analytics-only, ad ID collection disabled) or PostHog/Aptabase for a stricter privacy stance | Choose one; disable IDFA/AAID |
| Crashes | Firebase Crashlytics or Sentry | Watch low-end Android |
| Web/landing | Plausible or Umami | Cookie-less |
| Attribution | UTM links on every post; one short link per channel (e.g. Bitly/own domain) | Store referrer parameters on Play; custom product pages on iOS |
| Reviews | Store consoles + a weekly manual read | Tag themes |
| Dashboard | Looker Studio or a simple spreadsheet | One tab per week |

### 4.2 Event taxonomy (keep it small)

| Event | Parameters | Why |
|---|---|---|
| `app_open` | first_open (bool) | DAU, retention |
| `game_start` | game, start_level | Game popularity |
| `game_over` | game, score, duration_s, level | Difficulty tuning, session length |
| `new_best` | game, score | Engagement, leaderboard fuel |
| `leaderboard_open` | game, result (ok/unavailable) | Feature use, setup health |
| `sound_toggle` | on/off | UX health |
| `share_tap` (if a share button is added) | game, score | Virality |
| `rate_prompt_shown` / `rate_prompt_result` | – | Review funnel |

### 4.3 Key analyses
1. **Retention cohorts** (D1/D7/D30) by install week and by first game played.
2. **Game mix**: which game has best retention. Promote it first in ads and social.
3. **Difficulty funnel**: score distribution and time-to-game-over per game; if median < 15 s the game is too hard for casual players.
4. **Session depth**: games per session; do players switch games?
5. **Store funnel**: impressions, page views, installs, by channel (UTM) and by screenshot set.
6. **Leaderboard health**: share of Android users with Play Games working (see [leaderboards setup](leaderboards-setup.md)); fix before launch, since a broken "Online scores" hurts reviews.

### 4.4 Experiments (one at a time, minimum 2 weeks or 1 000 visitors per variant)
- Store icon: inverted (dark on light) vs light on dark.
- First screenshot: gameplay vs nostalgic caption ("Remember this?").
- Title/subtitle keywords.
- Short video: with and without sound-on hook.
- Review prompt timing: after 3rd new best vs after 5th session.

### 4.5 Weekly report (Monday, 30 minutes)
Installs, D1/D7, rating, top review themes, best post, worst post, one decision for next week.

## 5. Pre-launch checklist (store readiness = marketing readiness)

- [ ] Final name, app id, handles checked on both stores and social platforms; trademark search done (C2, C3).
- [ ] Blocks decision (C4): launch with three games and "Blocks coming soon", or wait. Do not market Blocks until cleared.
- [ ] Leaderboards live on iOS and Android.
- [ ] Privacy policy URL, support email, and a one-page landing site.
- [ ] Store assets (section 6) done and localized where possible.
- [ ] Analytics events verified in a release build.
- [ ] In-app rating prompt (native API) after a positive moment, such as a new best.
- [ ] Press kit page: logo, icon, 6 screenshots, GIFs, 30 s video, fact sheet, founder bio.

## 6. App Store Optimization (ASO)

The cheapest and most durable channel for a free utility-like game.

**Name (30 chars):** `LCD Arcade: Retro Mini Games`
**Subtitle (iOS, 30 chars):** `Classic pixel games, no ads`
**Short description (Play, 80 chars):** `Classic LCD-style mini games. No ads, no sign-up. Play in your spare minute.`

**Keyword field (iOS, 100 chars, no spaces after commas):**
`retro,pixel,classic,offline,mini games,arcade,old school,lcd,snake,casual,quick,one hand`

Notes: "snake" is a generic genre word; avoid "tetris", "nokia", "crossy". Do not repeat words already in the name.

**Long description structure:**
1. Hook: "Remember the games on your first phone? They are back, without ads."
2. Four games, one line each (Copter, Snake, Hop, Blocks if cleared).
3. Features: offline, no ads, no sign-up, leaderboards, sound option.
4. Who it is for: "Perfect for a queue, a commute or a coffee."
5. Call to action.

**Screenshots (6, portrait; Copter shown in a rotated frame):**
1. Launcher grid: "Four classic games. One tiny app."
2. Snake: "Easy to learn. Hard to put down."
3. Copter: "Fly as far as you can."
4. Hop: "Cross the road. Again."
5. Leaderboard: "Beat the world's best."
6. "No ads. No sign-up. Offline."

**Preview video (15–30 s):** 3 s hook (a hand holding a phone, LCD boot sound), 4 s per game, end card with "Free. No ads."

**Ratings:** native prompt after the 3rd new best or 5th session, never after a game over with a bad score. Reply to every review in the first 3 months.

## 7. Channels

Principle: **organic and community first, small paid tests later**. No monetization means no payback from paid installs; use paid only to validate creatives.

| Priority | Channel | Segment | Role | Effort | Cost |
|---|---|---|---|---|---|
| 1 | App stores (ASO, featuring pitch) | S2, S1 | Conversion and discovery | Med | Free |
| 2 | Short video: TikTok, Instagram Reels, YouTube Shorts | S2, S1, S3 | Reach | High | Free |
| 3 | Reddit | S1, S3, S4 | Launch spike, feedback | Med | Free |
| 4 | Facebook (page + retro/nostalgia groups) | S1, S5 | Older nostalgics | Med | Free / small |
| 5 | Product Hunt, Hacker News (Show HN), Indie Hackers | S3 | Launch spike, backlinks | Low | Free |
| 6 | X, Bluesky, Mastodon (#pixelart, #gamedev) | S3 | Dev-in-public, press contacts | Low | Free |
| 7 | Press and blogs (retro, mobile, indie, Flutter) | S1, S3 | Credibility, backlinks | Med | Free |
| 8 | itch.io / web demo | S3 | Playable teaser, funnel to stores | Med | Free |
| 9 | Email list / waitlist | All | Launch-day push | Low | Free |
| 10 | Paid tests: Apple Search Ads, Google App Campaigns, Meta/TikTok | S2 | Validate creatives | Low | Small |
| 11 | Influencers/micro-creators (retro gaming, ASMR keyboard/phone, nostalgia) | S1, S3 | Social proof | Med | Free to low |
| 12 | Cross-promotion, newsletters, "free app of the day" lists | S2 | Burst | Low | Free / low |

### 7.1 Channel details

**Short video (core engine).** Formats that fit a silent, visual product:
- "POV: your first phone, 2002" with the LCD boot sound.
- Satisfying runs: perfect Snake loops, long Copter flights, Hop streaks.
- Close-up of the pixel grid and menus ("Nokia-style menus, built by hand").
- "Can you beat my score?" challenge with the leaderboard.
- Behind the scenes: how the pixel font and square-wave sounds are made.
Cadence: 4 per week at launch, 2 per week after. Reuse each clip on TikTok, Reels and Shorts.

**Reddit** (read each community's rules, no spam, disclose that you made it):
- r/WebGames-style and r/AndroidGaming, r/iosgaming (app-share threads), r/AndroidApps, r/playmygame, r/IndieGaming, r/gamedev (Feedback Friday / Screenshot Saturday), r/PixelArt, r/nostalgia, r/retrogaming, r/Flutter and r/FlutterDev (technical angle).
- Post a story, not an ad: "I rebuilt the phone games I loved as a kid. No ads, here is how I made the LCD look."

**Facebook:** a page plus posting in nostalgia groups ("Remember when…" posts), with a photo of an old phone next to the new game. Strong for 35+.

**Product Hunt:** tagline "Classic phone games, no ads". Prepare gallery, maker comment, and a list of supporters. Launch Tuesday–Thursday. Hacker News: "Show HN: four retro LCD games in Flutter" with a technical write-up (pixel buffer, fixed-tick core, seeded RNG).

**Press and blogs:** pitch 30 targets (retro gaming sites, "best offline games" lists, Android/iOS app roundups, Flutter showcases). One short email, a link to the press kit, a promo code is not needed since the app is free.

**Micro-creators:** 20 outreach messages per week for 4 weeks to creators with 5k–100k followers in retro/nostalgia/pixel art. Offer early access and a custom leaderboard challenge, not payment at first.

**Paid tests (month 2+):** budget cap 150–300 EUR total. Run 3 creatives, optimize for installs, stop at once if cost per install is above 1.00 EUR in Western markets. Learn which hooks win and reuse them organically. Apple Search Ads only on brand and generic terms like "retro games", "offline games".

## 8. Timeline

```
T-8w  Name/ID locked, landscape + portrait screenshots, handles registered
T-6w  Landing page + waitlist, start dev-in-public posts (2/week)
T-4w  Closed beta (TestFlight, Play internal/closed), 50–100 testers; fix retention issues
T-3w  Press kit finished, creators contacted, store listing drafted
T-2w  Teaser video, countdown posts, email list warm-up
T-1w  Final store submission, review replies prepared, PH page scheduled
T-0   LAUNCH (Tuesday or Wednesday)
T+1w  Daily posting, Reddit threads spread over the week, reply to everything
T+2w  First update ("v1.1: your feedback"), ASO review
T+4w  Retrospective, adjust plan, decide on paid tests
T+8w  Add Blocks (if cleared) or a new mode: a second "launch" moment
T+12w Language update (DE, FR, ES, PT): relaunch in those markets
```

### Launch day run sheet
| Time (local) | Action |
|---|---|
| 08:00 | Check store listing live, links work, analytics receiving events |
| 09:00 | Post on X/Bluesky/Mastodon, Facebook page, Instagram, TikTok, LinkedIn |
| 10:00 | Product Hunt live (post at 00:01 PT if aiming for a full day); share in communities |
| 12:00 | Reddit post 1 (story) |
| 15:00 | Email waitlist, message beta testers to rate |
| 18:00 | Show HN (if technical write-up is ready) |
| Evening | Reply to every comment and review; note bugs; post a thank-you with first numbers |

## 9. Content calendar (first 8 weeks after launch)

Themes: **Mon** Nostalgia, **Tue** Game spotlight, **Wed** Behind the scenes, **Thu** Score challenge, **Fri** Community, **Sat** Short clip, **Sun** Rest or reshare.

| Week | Focus | Key posts |
|---|---|---|
| 1 | Launch | Launch video, "why I built this", Reddit story, Product Hunt, thank-you with numbers |
| 2 | Games | Snake tips thread, Copter 60-second run, Hop streak, v1.1 notes |
| 3 | Craft | How the LCD pixel grid works, font and sound design, Flutter write-up |
| 4 | Community | Leaderboard challenge ("top 10 this week"), repost best player clips, review quotes |
| 5 | Nostalgia | "What was your first phone?" poll, then reply with the matching game clip |
| 6 | Tips | "Beat Copter in 5 steps", Hop lane patterns, Snake corner strategy |
| 7 | Milestone | Installs milestone, a player highlight, roadmap vote (next game or language) |
| 8 | Update | New content or Blocks announcement (if cleared), second wave of creator outreach |

### Ready-to-use post templates

**Launch (X/Bluesky/Mastodon)**
> LCD Arcade is out. Four classic phone-style games in one tiny app. Pixel grid, square-wave beeps, no ads, no sign-up. Free on iOS and Android. [link] #pixelart #retrogames #indiegame

**Launch (Facebook / Instagram caption)**
> Remember waiting for the bus with only a tiny screen and a game of Snake? We built that feeling again. LCD Arcade: classic mini games, no ads, no sign-up, free. Link in bio. Tag someone who still has a high score to beat.

**Reddit story post (title)**
> I rebuilt the phone games from my childhood as one tiny app with a real LCD pixel look. No ads, no accounts. Looking for honest feedback.

**TikTok/Reels script (15 s)**
1. 0–2 s: Hand drops an old phone, text "Your first phone had this".
2. 2–10 s: Fast cuts of Snake, Copter, Hop on screen with beeps.
3. 10–15 s: "LCD Arcade. Free. No ads." with the store badges.

**Score challenge**
> This week's challenge: beat 120 in Snake. Post your screenshot, best one gets a shout-out on Friday. #LCDArcadeChallenge

**Behind the scenes**
> Every "pixel" on screen is a 5×5 block on a hidden grid, drawn from a 1-bit buffer. That is why the menus feel like a real phone. Thread on how it works: [link]

**Update note**
> v1.1: you asked, we fixed. Smoother Copter turns, easier first Hop level, a quieter sound option. Thanks for the feedback.

**Review request (email/Discord)**
> If you enjoy LCD Arcade, a short store review helps small apps like ours a lot. Thank you.

**Press pitch (subject: "Free retro mini-game collection with no ads")**
> Hi [name], I'm [your name]. I built LCD Arcade, a free collection of classic phone-style games with a hand-built two-tone LCD look. No ads, no sign-up, works offline. It would suit your [list/section]. Press kit: [link]. Happy to give a quick interview or answer technical questions.

### Hashtags (generic only)
`#retrogames #pixelart #mobilegames #indiegame #gamedev #oldschoolgaming #nostalgia #offlinegames #flutterdev`
Avoid brand hashtags such as #nokia, #tetris, #crossyroad.

## 10. Community and retention

- **Leaderboard events:** weekly "top 10" shout-out on social using screenshots submitted by players.
- **Roadmap voting:** poll for the next game, language or theme (a green LCD palette is a nice request to test).
- **Discord or subreddit (optional, after 1 000 players):** feedback, score screenshots, bug reports.
- **In-app:** native rating prompt; a short "what's new" line; a share-score button (image of the LCD screen with the score and store link) is the best low-cost virality addition.
- **Updates:** a new content drop every 4–6 weeks keeps the store "recently updated" signal and gives a reason to post.

## 11. Budget (first 3 months)

| Item | Amount (EUR) | Note |
|---|---|---|
| Apple Developer Program | 99 / year | Required for Game Center |
| Google Play registration | 25 one-time | |
| Domain + landing page | 15–30 / year | |
| Tools (analytics, email, scheduler) | 0–20 / month | Free tiers first |
| Paid tests | 150–300 | Month 2+, only after organic validation |
| Optional: pixel-art/video freelancer | 0–300 | Trailer polish |
| **Total** | **~300–800** | |

## 12. Risks and responses

| Risk | Response |
|---|---|
| Trademark/IP complaint (Blocks, Hop) | Keep Blocks held back until C4; generic names and copy; no look-alike hashtags or keywords |
| Low discovery in a crowded category | Prioritize ASO and short video; niche-down copy ("no ads", "offline") |
| Low retention (no meta progress) | Use the difficulty funnel; add daily/weekly score challenges and a share button |
| Negative reviews about leaderboards not working | Verify Play Games setup before launch; clear in-app message |
| Burnout from daily posting | Batch-record content weekly; reuse clips across platforms |
| Platform policy rejection | Keep privacy labels accurate; no hidden tracking |
| No revenue | Decide by month 3: keep free as a portfolio/brand piece, or add an optional one-time "Support" purchase or a no-ads-ever tip jar. Do not add interruptive ads, since "no ads" is the core promise |

## 13. Next 10 actions

1. Lock name, app id and handles (C2); check trademarks.
2. Resolve Blocks (C4) and decide the launch line-up.
3. Finish leaderboard setup on both stores.
4. Add privacy-friendly analytics and the event taxonomy (section 4.2).
5. Add a native rating prompt and a share-score image.
6. Record 20 gameplay clips (5 per game) with sound on.
7. Build the landing page with waitlist and press kit.
8. Draft the store listing and 6 screenshots; set up store listing experiments.
9. Recruit 50–100 beta testers from friends, Reddit and Flutter communities.
10. Schedule the launch week using sections 8 and 9.
