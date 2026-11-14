import { existsSync, mkdirSync, readdirSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { spawn, spawnSync, type ChildProcess } from 'node:child_process';
import { chromium, type Page } from 'playwright';

const ROOT = process.cwd();
const BASE = process.env.ITCH_CAPTURE_URL ?? 'http://127.0.0.1:8080';
const VIEW_W = 1920;
const VIEW_H = 1080;
const GIF_FPS = 10;
const GIF_MS = 2000;
const MAX_GIF_MB = 3;
const WARMUP_MS = 1800;

export const PROMO_PACKS = ['itch', 'gx', 'kong'] as const;
export type PromoPack = (typeof PROMO_PACKS)[number];

type Shot = 'circle' | 'boss' | 'tablets' | 'archives' | 'cover' | 'banner' | 'hall';

type PackConfig = {
  label: string;
  outName: string;
  shots: Shot[];
  cover: { w: number; h: number; file: string; pack: PromoPack };
  gifs: boolean;
  banner: boolean;
};

const PACK: Record<PromoPack, PackConfig> = {
  itch: {
    label: 'itch.io',
    outName: 'itch',
    shots: ['circle', 'boss', 'tablets', 'archives', 'cover', 'banner'],
    cover: { w: 630, h: 500, file: 'cover.png', pack: 'itch' },
    gifs: true,
    banner: true,
  },
  gx: {
    label: 'GX.games',
    outName: 'gx-games',
    shots: ['circle', 'boss', 'tablets', 'archives', 'cover'],
    cover: { w: 1920, h: 1080, file: 'cover.png', pack: 'gx' },
    gifs: false,
    banner: false,
  },
  kong: {
    label: 'Kongregate',
    outName: 'kongregate',
    shots: ['circle', 'boss', 'tablets', 'archives', 'hall', 'cover'],
    cover: { w: 1000, h: 800, file: 'icon.png', pack: 'kong' },
    gifs: false,
    banner: false,
  },
};

const ALL_SHOTS: Shot[] = ['circle', 'boss', 'tablets', 'archives', 'cover', 'banner', 'hall'];

function parseArgs(argv: string[]): { pack: PromoPack; shots: Shot[] } {
  const tokens = argv.filter((arg) => !arg.startsWith('-'));
  const first = tokens[0];
  const pack: PromoPack =
    first && (PROMO_PACKS as readonly string[]).includes(first) ? (first as PromoPack) : 'itch';
  const rest = pack === first ? tokens.slice(1) : tokens;
  if (rest.length === 0) return { pack, shots: PACK[pack].shots };
  const shots: Shot[] = [];
  for (const arg of rest) {
    if (!(ALL_SHOTS as string[]).includes(arg)) {
      throw new Error(`Unknown shot "${arg}". Use: ${ALL_SHOTS.join(', ')}`);
    }
    shots.push(arg as Shot);
  }
  return { pack, shots };
}

export async function runCapture(argv: string[] = process.argv.slice(2)): Promise<void> {
  const { pack, shots } = parseArgs(argv);
  const cfg = PACK[pack];
  const outDir = join(ROOT, '..', 'promo', cfg.outName);
  const frameDir = join(outDir, '.frames');
  if (needsFfmpeg(cfg, shots)) requireFfmpeg();
  mkdirSync(outDir, { recursive: true });
  if (existsSync(frameDir)) rmSync(frameDir, { recursive: true, force: true });
  if (needsFfmpeg(cfg, shots)) mkdirSync(frameDir, { recursive: true });

  const started = ensureDevServer();
  try {
    await capturePack(started, cfg, shots, outDir, frameDir);
  } catch (err) {
    if (started) started.kill('SIGTERM');
    throw err;
  }
}

async function capturePack(
  started: ChildProcess | null,
  cfg: PackConfig,
  shots: Shot[],
  outDir: string,
  frameDir: string,
): Promise<void> {
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

  try {
    for (const shot of shots) {
      console.log(`📷 ${shot}`);
      if (shot === 'cover') {
        await page.setViewportSize({ width: cfg.cover.w, height: cfg.cover.h });
      } else {
        await page.setViewportSize({ width: VIEW_W, height: VIEW_H });
      }
      await openShot(page, shot, cfg);
      await warmup(shot);
      if (shot === 'circle') {
        await page.screenshot({ path: join(outDir, '01-circle.png'), type: 'png' });
        if (cfg.gifs) await dumpFrames(page, join(frameDir, 'circle'));
      } else if (shot === 'boss') {
        await page.screenshot({ path: join(outDir, '02-boss.png'), type: 'png' });
        if (cfg.gifs) await dumpFrames(page, join(frameDir, 'boss'));
      } else if (shot === 'tablets') {
        await page.screenshot({ path: join(outDir, '03-tablets.png'), type: 'png' });
      } else if (shot === 'archives') {
        await page.screenshot({ path: join(outDir, '04-archives.png'), type: 'png' });
      } else if (shot === 'hall') {
        await page.screenshot({ path: join(outDir, '05-hall.png'), type: 'png' });
      } else if (shot === 'cover') {
        await page.screenshot({ path: join(outDir, cfg.cover.file), type: 'png' });
        const gif = join(outDir, 'cover.gif');
        if (existsSync(gif)) rmSync(gif);
      } else if (shot === 'banner') {
        const raw = join(frameDir, 'banner-full.png');
        await page.screenshot({ path: raw, type: 'png' });
        encodeStill(raw, join(outDir, 'banner.png'), 'crop=1920:480:0:300,scale=960:240:flags=neighbor');
      }
    }

    if (cfg.gifs && shots.includes('circle')) {
      encodeGif(
        join(frameDir, 'circle'),
        join(outDir, 'gif-circle.gif'),
        'scale=1280:720:flags=neighbor',
      );
    }
    if (cfg.gifs && shots.includes('boss')) {
      encodeGif(
        join(frameDir, 'boss'),
        join(outDir, 'gif-boss.gif'),
        'scale=1280:720:flags=neighbor',
      );
    }
    writeManifest(cfg, outDir);
    console.log(`\n✅ ${cfg.label} pack written to ${outDir}`);
  } finally {
    await browser.close();
    if (started) started.kill('SIGTERM');
  }
}

async function openShot(page: Page, shot: Shot, cfg: PackConfig): Promise<void> {
  const packQ = shot === 'cover' ? `&pack=${cfg.cover.pack}` : '';
  await page.goto(`${BASE}/?promo=${shot}${packQ}`, { waitUntil: 'domcontentloaded', timeout: 60_000 });
  await page.waitForFunction(() => document.documentElement.dataset.promoReady === '1', null, {
    timeout: 30_000,
  });
  if (shot === 'tablets') {
    await page.waitForSelector('#levelup-view:not(.hidden) .aug-card', { timeout: 15_000 });
  }
  if (shot === 'archives') {
    await page.waitForSelector('.archives-entity-grid', { timeout: 15_000 });
  }
  if (shot === 'banner' || shot === 'hall') {
    await page.waitForSelector('#hall:not(.hidden)', { timeout: 15_000 });
  }
  if (shot === 'cover') {
    await page.waitForSelector('#cover-stage', { timeout: 15_000 });
  }
}

async function warmup(shot: Shot): Promise<void> {
  const extra = shot === 'boss' ? 2400 : shot === 'banner' || shot === 'hall' ? 1200 : shot === 'cover' ? 400 : WARMUP_MS;
  await sleep(extra);
}

async function dumpFrames(page: Page, dir: string): Promise<void> {
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

function writeManifest(cfg: PackConfig, outDir: string): void {
  const files = manifestFiles(cfg);
  const lines = files.map((name) => {
    const path = join(outDir, name);
    if (!existsSync(path)) return `${name}: MISSING`;
    const mb = (statSync(path).size / (1024 * 1024)).toFixed(2);
    return `${name}: ${mb} MB`;
  });
  writeFileSync(join(outDir, 'manifest.txt'), `${lines.join('\n')}\n`);
  console.log(lines.join('\n'));
}

function manifestFiles(cfg: PackConfig): string[] {
  const files: string[] = [];
  if (cfg.shots.includes('cover')) files.push(cfg.cover.file);
  if (cfg.banner) files.push('banner.png');
  if (cfg.shots.includes('circle')) files.push('01-circle.png');
  if (cfg.shots.includes('boss')) files.push('02-boss.png');
  if (cfg.shots.includes('tablets')) files.push('03-tablets.png');
  if (cfg.shots.includes('archives')) files.push('04-archives.png');
  if (cfg.shots.includes('hall')) files.push('05-hall.png');
  if (cfg.gifs) files.push('gif-circle.gif', 'gif-boss.gif');
  return files;
}

function needsFfmpeg(cfg: PackConfig, shots: Shot[]): boolean {
  if (cfg.banner && shots.includes('banner')) return true;
  if (cfg.gifs && shots.some((shot) => shot === 'circle' || shot === 'boss')) return true;
  return false;
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

if (import.meta.main) {
  void runCapture().catch((err) => {
    console.error(err);
    process.exit(1);
  });
}
