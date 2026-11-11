import { existsSync, mkdirSync, readdirSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { spawn, spawnSync, type ChildProcess } from 'node:child_process';
import { chromium, type Page } from 'playwright';

const ROOT = process.cwd();
const OUT_DIR = join(ROOT, 'promo', 'itch');
const FRAME_DIR = join(OUT_DIR, '.frames');
const BASE = process.env.ITCH_CAPTURE_URL ?? 'http://127.0.0.1:8080';
const VIEW_W = 1920;
const VIEW_H = 1080;
const GIF_FPS = 10;
const GIF_MS = 2000;
const MAX_GIF_MB = 3;
const WARMUP_MS = 1800;

type Shot = 'circle' | 'boss' | 'tablets' | 'archives' | 'cover' | 'banner';

const ALL_SHOTS: Shot[] = ['circle', 'boss', 'tablets', 'archives', 'cover', 'banner'];

function selectedShots(): Shot[] {
  const args = process.argv.slice(2).filter((arg) => !arg.startsWith('-'));
  if (args.length === 0) return ALL_SHOTS;
  const shots: Shot[] = [];
  for (const arg of args) {
    if (!(ALL_SHOTS as string[]).includes(arg)) {
      throw new Error(`Unknown shot "${arg}". Use: ${ALL_SHOTS.join(', ')}`);
    }
    shots.push(arg as Shot);
  }
  return shots;
}

async function main(): Promise<void> {
  requireFfmpeg();
  mkdirSync(OUT_DIR, { recursive: true });
  if (existsSync(FRAME_DIR)) rmSync(FRAME_DIR, { recursive: true, force: true });
  mkdirSync(FRAME_DIR, { recursive: true });

  const started = ensureDevServer();
  try {
    await awaitCapture(started);
  } catch (err) {
    if (started) started.kill('SIGTERM');
    throw err;
  }
}

async function awaitCapture(started: ChildProcess | null): Promise<void> {
  const browser = await chromium.launch({
    headless: true,
    args: ['--ignore-gpu-blocklist', '--use-gl=angle', '--enable-webgl', '--mute-audio'],
  });
  const page = await browser.newPage({
    viewport: { width: VIEW_W, height: VIEW_H },
    deviceScaleFactor: 1,
    colorScheme: 'dark',
  });
  await page.addInitScript(() => {
    try {
      localStorage.setItem(
        'survivors.settings.v1',
        JSON.stringify({
          masterVolume: 0,
          sfxVolume: 0,
          musicVolume: 0,
          muted: true,
          screenshake: true,
          reduceVfx: false,
          survivorId: 'runner',
        }),
      );
    } catch {
      /* ignore */
    }
  });

  const shots = selectedShots();
  try {
    for (const shot of shots) {
      console.log(`📷 ${shot}`);
      await openShot(page, shot);
      await warmup(shot);
      if (shot === 'circle') {
        await page.screenshot({ path: join(OUT_DIR, '01-circle.png'), type: 'png' });
        await dumpFrames(page, 'circle');
      } else if (shot === 'boss') {
        await page.screenshot({ path: join(OUT_DIR, '02-boss.png'), type: 'png' });
        await dumpFrames(page, 'boss');
      } else if (shot === 'tablets') {
        await page.screenshot({ path: join(OUT_DIR, '03-tablets.png'), type: 'png' });
      } else if (shot === 'archives') {
        await page.screenshot({ path: join(OUT_DIR, '04-archives.png'), type: 'png' });
      } else if (shot === 'cover') {
        await dumpFrames(page, 'cover');
      } else if (shot === 'banner') {
        const raw = join(FRAME_DIR, 'banner-full.png');
        await page.screenshot({ path: raw, type: 'png' });
        encodeStill(raw, join(OUT_DIR, 'banner.png'), 'crop=1920:480:0:300,scale=960:240:flags=neighbor');
      }
    }

    if (shots.includes('circle')) {
      encodeGif(
        join(FRAME_DIR, 'circle'),
        join(OUT_DIR, 'gif-circle.gif'),
        'scale=1280:720:flags=neighbor',
      );
    }
    if (shots.includes('boss')) {
      encodeGif(
        join(FRAME_DIR, 'boss'),
        join(OUT_DIR, 'gif-boss.gif'),
        'scale=1280:720:flags=neighbor',
      );
    }
    if (shots.includes('cover')) {
      encodeGif(
        join(FRAME_DIR, 'cover'),
        join(OUT_DIR, 'cover.gif'),
        'crop=788:625:(in_w-788)/2:(in_h-625)/2,scale=630:500:flags=neighbor',
      );
      const coverStill = firstFrame(join(FRAME_DIR, 'cover'));
      if (coverStill) {
        encodeStill(
          coverStill,
          join(OUT_DIR, 'cover.png'),
          'crop=788:625:(in_w-788)/2:(in_h-625)/2,scale=630:500:flags=neighbor',
        );
      }
    }
    writeManifest();
    console.log(`\n✅ itch.io pack written to ${OUT_DIR}`);
  } finally {
    await browser.close();
    if (started) started.kill('SIGTERM');
  }
}

async function openShot(page: Page, shot: Shot): Promise<void> {
  await page.goto(`${BASE}/?promo=${shot}`, { waitUntil: 'domcontentloaded', timeout: 60_000 });
  await page.waitForFunction(() => document.documentElement.dataset.promoReady === '1', null, {
    timeout: 30_000,
  });
  if (shot === 'tablets') {
    await page.waitForSelector('#levelup-view:not(.hidden) .aug-card', { timeout: 15_000 });
  }
  if (shot === 'archives') {
    await page.waitForSelector('.archives-entity-grid', { timeout: 15_000 });
  }
  if (shot === 'banner') {
    await page.waitForSelector('#hall:not(.hidden)', { timeout: 15_000 });
  }
}

async function warmup(shot: Shot): Promise<void> {
  const extra =
    shot === 'boss' ? 2400 : shot === 'banner' || shot === 'cover' ? 1200 : WARMUP_MS;
  await sleep(extra);
}

async function dumpFrames(page: Page, name: string): Promise<void> {
  const dir = join(FRAME_DIR, name);
  mkdirSync(dir, { recursive: true });
  const interval = 1000 / GIF_FPS;
  const count = Math.round(GIF_MS / interval);
  for (let i = 0; i < count; i += 1) {
    const file = join(dir, `frame-${String(i).padStart(4, '0')}.png`);
    await page.screenshot({ path: file, type: 'png' });
    await sleep(interval);
  }
}

function encodeGif(framesDir: string, outFile: string, vf: string): void {
  const frames = listFrames(framesDir);
  if (frames.length === 0) {
    throw new Error(`No frames in ${framesDir}`);
  }
  const attempts: { fps: number; colors: number; vf: string }[] = [
    { fps: GIF_FPS, colors: 96, vf },
    { fps: 8, colors: 64, vf },
    { fps: 8, colors: 48, vf: vf.replace('scale=1280:720', 'scale=960:540') },
    { fps: 6, colors: 32, vf: vf.replace('scale=1280:720', 'scale=960:540') },
  ];
  for (const attempt of attempts) {
    runGifPass(framesDir, outFile, attempt.vf, attempt.fps, attempt.colors);
    const mb = statSync(outFile).size / (1024 * 1024);
    console.log(`   ${outFile.split('/').pop()} ${mb.toFixed(2)} MB @ ${attempt.fps}fps ${attempt.colors}c`);
    if (mb <= MAX_GIF_MB) return;
  }
  throw new Error(`${outFile} stayed over ${MAX_GIF_MB} MB`);
}

function runGifPass(framesDir: string, outFile: string, vf: string, fps: number, colors: number): void {
  const palette = join(framesDir, `palette-${colors}.png`);
  const input = join(framesDir, 'frame-%04d.png');
  const chain = `fps=${fps},${vf},palettegen=max_colors=${colors}:stats_mode=full`;
  const gen = spawnSync(
    'ffmpeg',
    ['-y', '-framerate', String(GIF_FPS), '-i', input, '-vf', chain, '-frames:v', '1', '-update', '1', palette],
    { stdio: 'pipe' },
  );
  if (gen.status !== 0) {
    throw new Error(`ffmpeg palettegen failed: ${gen.stderr.toString()}`);
  }
  const use = spawnSync(
    'ffmpeg',
    [
      '-y',
      '-framerate',
      String(GIF_FPS),
      '-i',
      input,
      '-i',
      palette,
      '-lavfi',
      `fps=${fps},${vf}[x];[x][1:v]paletteuse=dither=none:diff_mode=rectangle`,
      '-loop',
      '0',
      outFile,
    ],
    { stdio: 'pipe' },
  );
  if (use.status !== 0) {
    throw new Error(`ffmpeg paletteuse failed: ${use.stderr.toString()}`);
  }
}

function encodeStill(input: string, outFile: string, vf: string): void {
  const res = spawnSync(
    'ffmpeg',
    ['-y', '-i', input, '-vf', vf, '-frames:v', '1', outFile],
    { stdio: 'pipe' },
  );
  if (res.status !== 0) {
    throw new Error(`ffmpeg still failed: ${res.stderr.toString()}`);
  }
}

function listFrames(dir: string): string[] {
  if (!existsSync(dir)) return [];
  return readdirSync(dir)
    .filter((name) => name.startsWith('frame-') && name.endsWith('.png'))
    .sort();
}

function firstFrame(dir: string): string | null {
  const frames = listFrames(dir);
  return frames[0] ? join(dir, frames[0]) : null;
}

function writeManifest(): void {
  const files = [
    'cover.gif',
    'cover.png',
    'banner.png',
    '01-circle.png',
    '02-boss.png',
    '03-tablets.png',
    '04-archives.png',
    'gif-circle.gif',
    'gif-boss.gif',
  ];
  const lines = files.map((name) => {
    const path = join(OUT_DIR, name);
    if (!existsSync(path)) return `${name}: MISSING`;
    const mb = (statSync(path).size / (1024 * 1024)).toFixed(2);
    return `${name}: ${mb} MB`;
  });
  writeFileSync(join(OUT_DIR, 'manifest.txt'), `${lines.join('\n')}\n`);
  console.log(lines.join('\n'));
}

function requireFfmpeg(): void {
  const res = spawnSync('ffmpeg', ['-version'], { stdio: 'pipe' });
  if (res.status !== 0) {
    throw new Error('ffmpeg is required. Install it (e.g. sudo apt install ffmpeg) and re-run bun run capture:itch.');
  }
}

function ensureDevServer(): ChildProcess | null {
  if (serverUp()) {
    console.log(`🔌 using existing ${BASE}`);
    return null;
  }
  console.log('🚀 starting bun run dev');
  const child = spawn('bun', ['run', 'dev'], {
    cwd: ROOT,
    stdio: 'pipe',
    env: { ...process.env, BROWSER: 'none' },
  });
  const deadline = Date.now() + 40_000;
  while (Date.now() < deadline) {
    if (serverUp()) return child;
    spawnSync('sleep', ['0.4']);
  }
  child.kill('SIGTERM');
  throw new Error(`Dev server did not start on ${BASE}`);
}

function serverUp(): boolean {
  const res = spawnSync('curl', ['-sf', '-o', '/dev/null', '-m', '1', BASE], { stdio: 'pipe' });
  return res.status === 0;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}

void main().catch((err) => {
  console.error(err);
  process.exit(1);
});
