// Usage: node marketing/tools/capture.mjs [shots|clips|all]
// Renders store screenshots and clip frames from the real app (needs Flutter),
// then encodes 9:16 MP4 and GIF clips (needs ffmpeg on PATH).
import { spawnSync } from 'node:child_process';
import { existsSync, readdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..');
const what = process.argv[2] ?? 'all';
if (!['shots', 'clips', 'all'].includes(what)) {
  console.error('Usage: node capture.mjs [shots|clips|all]');
  process.exit(1);
}

const run = (cmd, args, cwd) => {
  const r = spawnSync(cmd, args, { cwd, stdio: 'inherit', shell: process.platform === 'win32' });
  if (r.status !== 0) {
    console.error(`${cmd} failed`);
    process.exit(r.status ?? 1);
  }
};

run('flutter', ['test', 'test_marketing', `--dart-define=CAPTURE=${what}`], join(root, 'app'));

if (what !== 'shots') {
  const clips = join(root, 'marketing', 'out', 'clips');
  for (const game of existsSync(clips) ? readdirSync(clips) : []) {
    const dir = join(clips, game);
    const input = ['-y', '-framerate', '30', '-i', join(dir, 'frame_%04d.png')];
    // Scale to 1080 wide and pad to 9:16 on the bezel colour (Copter is landscape).
    const fit = 'scale=1080:-2:flags=neighbor,pad=1080:1920:(ow-iw)/2:(oh-ih)/2:color=0x1E2219';
    run('ffmpeg', [...input, '-vf', fit, '-c:v', 'libx264', '-pix_fmt', 'yuv420p', join(clips, `${game}.mp4`)], root);
    run('ffmpeg', [...input, '-vf', `fps=15,scale=480:-2:flags=neighbor`, join(clips, `${game}.gif`)], root);
  }
}
console.log(`Output: ${join(root, 'marketing', 'out')}`);
