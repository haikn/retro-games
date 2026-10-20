// Usage: node calendar.mjs 2026-12-01 > calendar.csv   (argument = launch date, YYYY-MM-DD)
const launch = new Date(`${process.argv[2] ?? ''}T00:00:00Z`);
if (Number.isNaN(launch.getTime())) {
  console.error('Usage: node calendar.mjs YYYY-MM-DD');
  process.exit(1);
}

const LINK = '[link]';
const hashtags = '#retrogames #pixelart #mobilegames #indiegame';

// day offset from launch, platform, theme, text
const posts = [
  [-28, 'X/Bluesky/Mastodon', 'Dev log', 'Building a phone-LCD style game collection. Every pixel is a 5x5 block on a hidden grid. #pixelart #gamedev'],
  [-21, 'Instagram/TikTok', 'Teaser', 'POV: your first phone, 2002. Something is coming. Waitlist: ' + LINK],
  [-14, 'X/Bluesky/Mastodon', 'Behind the scenes', 'How the square-wave sounds are made. Short thread. ' + LINK],
  [-7, 'All', 'Countdown', 'One week to launch. Four classic games, no ads, no sign-up. Waitlist: ' + LINK],
  [-1, 'All', 'Countdown', 'Tomorrow. Waitlist members get the link first.'],
  [0, 'All', 'Launch', `LCD Arcade is out. Classic phone-style games, pixel grid, beeps, no ads, no sign-up. Free on iOS and Android. ${LINK} ${hashtags}`],
  [0, 'Reddit', 'Story', 'I rebuilt the phone games from my childhood as one tiny app with a real LCD look. No ads, no accounts. Honest feedback welcome.'],
  [0, 'Email', 'Launch', 'Subject: LCD Arcade is live. Body: thanks for waiting, store links, a short rating request.'],
  [1, 'TikTok/Reels/Shorts', 'Clip', 'Satisfying Snake run with LCD sounds. "Free. No ads."'],
  [2, 'X/Bluesky/Mastodon', 'Game spotlight', 'Copter: fly as far as you can. Post your best distance. ' + LINK],
  [3, 'Instagram', 'Nostalgia', 'What was your first phone? Reply and we match you with a game.'],
  [4, 'X/Bluesky/Mastodon', 'Score challenge', 'This week: beat 120 in Snake. Best screenshot gets a shout-out Friday. #LCDArcadeChallenge'],
  [5, 'Facebook', 'Community', 'Remember waiting for the bus with Snake? We built that feeling again. ' + LINK],
  [6, 'TikTok/Reels/Shorts', 'Clip', 'Hop streak: how far can you cross?'],
  [8, 'X/Bluesky/Mastodon', 'Update', 'v1.1: thanks for the feedback. Smoother Copter, easier first Hop level.'],
  [10, 'Reddit r/FlutterDev', 'Technical', 'How I built a 1-bit LCD renderer in Flutter with a fixed-tick game core.'],
  [14, 'All', 'Community', 'Top 10 of the week: leaderboard shout-out.'],
  [21, 'Instagram/TikTok', 'Tips', 'Beat Copter in 5 steps.'],
  [28, 'All', 'Milestone', 'Thank you. First month numbers and what comes next. Vote: new game or new language?'],
];

const csvCell = (s) => `"${String(s).replaceAll('"', '""')}"`;
const lines = ['date,platform,theme,text'];
for (const [offset, platform, theme, text] of posts.sort((a, b) => a[0] - b[0])) {
  const d = new Date(launch.getTime() + offset * 86_400_000).toISOString().slice(0, 10);
  lines.push([d, platform, theme, text].map(csvCell).join(','));
}
console.log(lines.join('\n'));
