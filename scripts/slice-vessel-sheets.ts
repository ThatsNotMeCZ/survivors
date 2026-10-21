import { mkdir, unlink } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { PNG } from 'pngjs';

type SheetJob = {
  file: string;
  keys: string[];
  keep: number[];
};

const ROOT = join(import.meta.dir, '..');
const IN_DIR = join(ROOT, 'public/sprites/_in');
const RAW_DIR = join(ROOT, 'public/sprites/_raw');
const REF_DIR = join(ROOT, 'public/sprites/_ref');
const SPRITES_DIR = join(ROOT, 'public/sprites');
const REF_PX = 1024;
const GAME_PX = 40;
const WHITE = 245;
const GAP_PX = 24;
const MIN_COL_W = 40;
const CROP_PAD = 16;

const JOBS: SheetJob[] = [
  {
    file: 'runner_idle.jpeg',
    keep: [0],
    keys: ['px-player-body-runner-cinder-side'],
  },
  {
    file: 'runner_walk.jpeg',
    keep: [0, 1, 2],
    keys: [
      'px-player-body-runner-cinder-walk-side-0',
      'px-player-body-runner-cinder-walk-side-1',
      'px-player-body-runner-cinder-walk-side-2',
    ],
  },
];

function isWhitePx(data: Buffer, off: number): boolean {
  return data[off] >= WHITE && data[off + 1] >= WHITE && data[off + 2] >= WHITE;
}

function figureBoxes(png: PNG): { x: number; y: number; w: number; h: number }[] {
  const { width, height, data } = png;
  const has = new Array<boolean>(width).fill(false);
  for (let x = 0; x < width; x += 1) {
    for (let y = 0; y < height; y += 1) {
      if (!isWhitePx(data, (y * width + x) << 2)) {
        has[x] = true;
        break;
      }
    }
  }
  const runs: { x0: number; x1: number }[] = [];
  let i = 0;
  while (i < width) {
    if (!has[i]) {
      i += 1;
      continue;
    }
    let j = i;
    while (j < width && has[j]) j += 1;
    const last = runs[runs.length - 1];
    if (last && i - last.x1 < GAP_PX) last.x1 = j;
    else runs.push({ x0: i, x1: j });
    i = j;
  }
  const boxes: { x: number; y: number; w: number; h: number }[] = [];
  for (const run of runs) {
    if (run.x1 - run.x0 < MIN_COL_W) continue;
    let minX = run.x1;
    let maxX = run.x0;
    let minY = height;
    let maxY = -1;
    for (let x = run.x0; x < run.x1; x += 1) {
      for (let y = 0; y < height; y += 1) {
        if (isWhitePx(data, (y * width + x) << 2)) continue;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
    if (maxY < 0) continue;
    boxes.push({ x: minX, y: minY, w: maxX - minX + 1, h: maxY - minY + 1 });
  }
  return boxes;
}

function cropRect(src: PNG, box: { x: number; y: number; w: number; h: number }, pad: number): PNG {
  const x0 = Math.max(0, box.x - pad);
  const y0 = Math.max(0, box.y - pad);
  const x1 = Math.min(src.width, box.x + box.w + pad);
  const y1 = Math.min(src.height, box.y + box.h + pad);
  const w = Math.max(1, x1 - x0);
  const h = Math.max(1, y1 - y0);
  const dst = new PNG({ width: w, height: h });
  for (let y = 0; y < h; y += 1) {
    const srcOff = ((y0 + y) * src.width + x0) << 2;
    const dstOff = (y * w) << 2;
    dst.data.set(src.data.subarray(srcOff, srcOff + (w << 2)), dstOff);
  }
  return dst;
}

function chromaKeyWhite(png: PNG): void {
  const { width, height, data } = png;
  const seen = new Uint8Array(width * height);
  const stack: number[] = [];
  const push = (x: number, y: number): void => {
    if (x < 0 || y < 0 || x >= width || y >= height) return;
    const p = y * width + x;
    if (seen[p]) return;
    seen[p] = 1;
    if (!isWhitePx(data, p << 2) && data[(p << 2) + 3] !== 0) return;
    stack.push(p);
  };
  for (let x = 0; x < width; x += 1) {
    push(x, 0);
    push(x, height - 1);
  }
  for (let y = 0; y < height; y += 1) {
    push(0, y);
    push(width - 1, y);
  }
  while (stack.length > 0) {
    const p = stack.pop();
    if (p === undefined) break;
    data[(p << 2) + 3] = 0;
    const x = p % width;
    const y = (p / width) | 0;
    push(x - 1, y);
    push(x + 1, y);
    push(x, y - 1);
    push(x, y + 1);
  }
}

function opaqueBounds(png: PNG): { x: number; y: number; w: number; h: number } | null {
  const { width, height, data } = png;
  let minX = width;
  let minY = height;
  let maxX = -1;
  let maxY = -1;
  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      if (data[((y * width + x) << 2) + 3] < 16) continue;
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
    }
  }
  if (maxX < 0) return null;
  return { x: minX, y: minY, w: maxX - minX + 1, h: maxY - minY + 1 };
}

function cropToFit(src: PNG, size: number): PNG {
  const box = opaqueBounds(src);
  const dst = new PNG({ width: size, height: size });
  if (!box) return dst;
  const pad = 2;
  const sx0 = Math.max(0, box.x - pad);
  const sy0 = Math.max(0, box.y - pad);
  const sx1 = Math.min(src.width, box.x + box.w + pad);
  const sy1 = Math.min(src.height, box.y + box.h + pad);
  const sw = Math.max(1, sx1 - sx0);
  const sh = Math.max(1, sy1 - sy0);
  const scale = Math.min(size / sw, size / sh);
  const dw = Math.max(1, Math.round(sw * scale));
  const dh = Math.max(1, Math.round(sh * scale));
  const ox = Math.floor((size - dw) / 2);
  const oy = Math.floor((size - dh) / 2);
  for (let y = 0; y < dh; y += 1) {
    const sy = Math.min(sh - 1, Math.floor(((y + 0.5) * sh) / dh));
    for (let x = 0; x < dw; x += 1) {
      const sx = Math.min(sw - 1, Math.floor(((x + 0.5) * sw) / dw));
      const si = ((sy0 + sy) * src.width + (sx0 + sx)) << 2;
      const di = ((oy + y) * size + (ox + x)) << 2;
      dst.data[di] = src.data[si];
      dst.data[di + 1] = src.data[si + 1];
      dst.data[di + 2] = src.data[si + 2];
      dst.data[di + 3] = src.data[si + 3];
    }
  }
  return dst;
}

function flattenOnWhite(png: PNG): Buffer {
  const out = new PNG({ width: png.width, height: png.height });
  for (let i = 0; i < png.data.length; i += 4) {
    const a = png.data[i + 3] / 255;
    out.data[i] = Math.round(png.data[i] * a + 255 * (1 - a));
    out.data[i + 1] = Math.round(png.data[i + 1] * a + 255 * (1 - a));
    out.data[i + 2] = Math.round(png.data[i + 2] * a + 255 * (1 - a));
    out.data[i + 3] = 255;
  }
  return PNG.sync.write(out);
}

async function jpegToPng(src: string): Promise<PNG> {
  const dest = join(tmpdir(), `slice-${Bun.hash(src).toString(16)}.png`);
  const proc = Bun.spawn(
    ['python3', '-c', 'from PIL import Image; import sys; Image.open(sys.argv[1]).convert("RGBA").save(sys.argv[2])', src, dest],
    { stdout: 'inherit', stderr: 'inherit' },
  );
  const code = await proc.exited;
  if (code !== 0) throw new Error(`jpeg decode failed: ${src}`);
  const png = PNG.sync.read(Buffer.from(await Bun.file(dest).arrayBuffer()));
  await unlink(dest);
  return png;
}

async function writeManifest(): Promise<void> {
  const glob = new Bun.Glob('*.png');
  const keys: string[] = [];
  for await (const file of glob.scan({ cwd: SPRITES_DIR })) {
    if (file.startsWith('_') || file.includes('/')) continue;
    keys.push(file.replace(/\.png$/, ''));
  }
  keys.sort();
  await Bun.write(join(SPRITES_DIR, 'manifest.json'), `${JSON.stringify({ keys }, null, 2)}\n`);
}

async function sliceJob(job: SheetJob): Promise<number> {
  const srcPath = join(IN_DIR, job.file);
  const png = await jpegToPng(srcPath);
  const boxes = figureBoxes(png);
  if (boxes.length === 0) throw new Error(`${job.file}: no figures`);
  console.log(`${job.file} ${png.width}x${png.height} figures=${boxes.length}`);
  let wrote = 0;
  for (let i = 0; i < job.keep.length; i += 1) {
    const idx = job.keep[i];
    const key = job.keys[i];
    const box = boxes[idx];
    if (!key || !box) throw new Error(`${job.file}: missing figure ${idx}`);
    const crop = cropRect(png, box, CROP_PAD);
    chromaKeyWhite(crop);
    const rawDest = join(RAW_DIR, `${key}.png`);
    const refDest = join(REF_DIR, `${key}.png`);
    const gameDest = join(SPRITES_DIR, `${key}.png`);
    await Bun.write(rawDest, flattenOnWhite(crop));
    await Bun.write(refDest, flattenOnWhite(cropToFit(crop, REF_PX)));
    await Bun.write(gameDest, PNG.sync.write(cropToFit(crop, GAME_PX)));
    console.log(`  [${idx}] ${box.w}x${box.h} → ${key}`);
    wrote += 1;
  }
  return wrote;
}

if (import.meta.main) {
  await mkdir(RAW_DIR, { recursive: true });
  await mkdir(REF_DIR, { recursive: true });
  let total = 0;
  for (const job of JOBS) total += await sliceJob(job);
  await writeManifest();
  console.log(`${total} frame(s) → _raw + _ref/${REF_PX}px + ${GAME_PX}px game`);
}
