import { existsSync, mkdirSync, readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { extname, join } from 'node:path';
import type { EntitySpriteDef, SpriteAnimDef, SpriteManifest } from '../src/view/sprite-types';

export type { EntitySpriteDef, SpriteAnimDef, SpriteManifest };

const FOLDERS = ['entities', 'items', 'skills', 'env', 'fx'] as const;

export function writeSpriteManifest(root = process.cwd()): string {
  const spritesDir = join(root, 'public', 'sprites');
  for (const folder of FOLDERS) {
    mkdirSync(join(spritesDir, folder), { recursive: true });
  }

  const entities: Record<string, EntitySpriteDef> = {};
  for (const name of listPng(join(spritesDir, 'entities'))) {
    const id = stem(name);
    const src = `sprites/entities/${name}`;
    const path = join(spritesDir, 'entities', name);
    const sidecar = readSidecar(join(spritesDir, 'entities', `${id}.json`));
    const size = pngSize(path);
    if (!size) continue;
    entities[id] = {
      src,
      frameWidth: sidecar?.frameWidth ?? inferFrameWidth(size.width, size.height),
      frameHeight: sidecar?.frameHeight ?? size.height,
      anims:
        sidecar?.anims ??
        defaultAnims(size.width, sidecar?.frameWidth ?? inferFrameWidth(size.width, size.height)),
    };
  }

  const manifest: SpriteManifest = {
    entities,
    items: listPng(join(spritesDir, 'items')).map(stem),
    skills: listPng(join(spritesDir, 'skills')).map(stem),
    env: listPng(join(spritesDir, 'env')).map(stem),
    fx: listPng(join(spritesDir, 'fx')).map(stem),
  };

  const out = join(spritesDir, 'manifest.json');
  writeFileSync(out, `${JSON.stringify(manifest, null, 2)}\n`);
  return out;
}

function defaultAnims(width: number, frameWidth: number): Record<string, SpriteAnimDef> {
  const count = Math.max(1, Math.floor(width / Math.max(1, frameWidth)));
  const frames = Array.from({ length: count }, (_, i) => i);
  const anims: Record<string, SpriteAnimDef> = {
    idle: { frames: [0], frameRate: 1, repeat: -1 },
  };
  if (count > 1) {
    anims.walk = { frames, frameRate: 8, repeat: -1 };
  }
  return anims;
}

function inferFrameWidth(width: number, height: number): number {
  if (height > 0 && width % height === 0) return height;
  return width;
}

type Sidecar = {
  frameWidth?: number;
  frameHeight?: number;
  anims?: Record<string, SpriteAnimDef>;
};

function readSidecar(path: string): Sidecar | null {
  if (!existsSync(path)) return null;
  try {
    const raw: unknown = JSON.parse(readFileSync(path, 'utf8'));
    if (!raw || typeof raw !== 'object') return null;
    const rec = raw as Record<string, unknown>;
    return parseCompactSidecar(rec) ?? parsePixeloramaProject(rec) ?? parseAsepriteSheet(rec);
  } catch {
    return null;
  }
}

function parseCompactSidecar(rec: Record<string, unknown>): Sidecar | null {
  const anims = parseAnims(rec.anims);
  const frameWidth = positiveInt(rec.frameWidth);
  const frameHeight = positiveInt(rec.frameHeight);
  if (!anims && !frameWidth && !frameHeight) return null;
  return { frameWidth, frameHeight, anims };
}

/** Pixelorama project JSON (`pxo` saved/exported as JSON). Tags are 1-based inclusive. */
function parsePixeloramaProject(rec: Record<string, unknown>): Sidecar | null {
  const isProject =
    typeof rec.pixelorama_version === 'string' ||
    typeof rec.pxo_version === 'number' ||
    (positiveInt(rec.size_x) !== undefined && Array.isArray(rec.tags) && Array.isArray(rec.frames));
  if (!isProject) return null;
  const frameWidth = positiveInt(rec.size_x);
  const frameHeight = positiveInt(rec.size_y);
  const fps = positiveNumber(rec.fps) ?? 8;
  const durations = frameDurations(rec.frames);
  const anims = parseTags(rec.tags, { oneIndexed: true, fps, durations });
  if (!frameWidth && !frameHeight && !anims) return null;
  return { frameWidth, frameHeight, anims };
}

/** Aseprite / Pixelorama spritesheet JSON Hash or Array (`meta.frameTags`, 0-based). */
function parseAsepriteSheet(rec: Record<string, unknown>): Sidecar | null {
  const meta = rec.meta;
  if (!meta || typeof meta !== 'object') return null;
  const metaRec = meta as Record<string, unknown>;
  const size = firstFrameSize(rec.frames) ?? sheetSize(metaRec.size);
  const fps = sheetFrameRate(rec.frames);
  const anims = parseTags(metaRec.frameTags, { oneIndexed: false, fps, durations: [] });
  if (!size && !anims) return null;
  return {
    frameWidth: size?.width,
    frameHeight: size?.height,
    anims,
  };
}

function parseTags(
  value: unknown,
  opts: { oneIndexed: boolean; fps: number; durations: number[] },
): Record<string, SpriteAnimDef> | undefined {
  if (!Array.isArray(value)) return undefined;
  const out: Record<string, SpriteAnimDef> = {};
  for (const entry of value) {
    if (!entry || typeof entry !== 'object') continue;
    const rec = entry as Record<string, unknown>;
    if (typeof rec.name !== 'string' || rec.name.length === 0) continue;
    const from = integerValue(rec.from);
    const to = integerValue(rec.to);
    if (from === undefined || to === undefined) continue;
    const start = opts.oneIndexed ? from - 1 : from;
    const end = opts.oneIndexed ? to - 1 : to;
    const frames = frameRange(start, end);
    if (frames.length === 0) continue;
    const name = rec.name.trim().toLowerCase();
    out[name] = {
      frames,
      frameRate: tagFrameRate(frames, opts.fps, opts.durations),
      repeat: -1,
    };
  }
  if (!out.idle) out.idle = { frames: [0], frameRate: 1, repeat: -1 };
  return Object.keys(out).length > 0 ? out : undefined;
}

function tagFrameRate(frames: number[], fps: number, durations: number[]): number {
  const used = frames.map((index) => durations[index]).filter((value): value is number => value !== undefined && value > 0);
  if (used.length === 0) return fps;
  const avg = used.reduce((sum, value) => sum + value, 0) / used.length;
  return fps / avg;
}

function frameDurations(value: unknown): number[] {
  if (!Array.isArray(value)) return [];
  return value.map((entry) => {
    if (!entry || typeof entry !== 'object') return 1;
    const duration = (entry as Record<string, unknown>).duration;
    return typeof duration === 'number' && duration > 0 ? duration : 1;
  });
}

function firstFrameSize(value: unknown): { width: number; height: number } | undefined {
  const entries = Array.isArray(value)
    ? value
    : value && typeof value === 'object'
      ? Object.values(value as Record<string, unknown>)
      : [];
  for (const entry of entries) {
    if (!entry || typeof entry !== 'object') continue;
    const frame = (entry as Record<string, unknown>).frame;
    if (!frame || typeof frame !== 'object') continue;
    const rec = frame as Record<string, unknown>;
    const width = positiveInt(rec.w);
    const height = positiveInt(rec.h);
    if (width && height) return { width, height };
  }
  return undefined;
}

function sheetSize(value: unknown): { width: number; height: number } | undefined {
  if (!value || typeof value !== 'object') return undefined;
  const rec = value as Record<string, unknown>;
  const width = positiveInt(rec.w);
  const height = positiveInt(rec.h);
  if (!width || !height) return undefined;
  return { width, height };
}

function sheetFrameRate(value: unknown): number {
  const entries = Array.isArray(value)
    ? value
    : value && typeof value === 'object'
      ? Object.values(value as Record<string, unknown>)
      : [];
  for (const entry of entries) {
    if (!entry || typeof entry !== 'object') continue;
    const duration = (entry as Record<string, unknown>).duration;
    if (typeof duration === 'number' && duration > 0) return 1000 / duration;
  }
  return 8;
}

function parseAnims(value: unknown): Record<string, SpriteAnimDef> | undefined {
  if (!value || typeof value !== 'object') return undefined;
  const out: Record<string, SpriteAnimDef> = {};
  for (const [name, spec] of Object.entries(value as Record<string, unknown>)) {
    if (!spec || typeof spec !== 'object') continue;
    const rec = spec as Record<string, unknown>;
    if (!Array.isArray(rec.frames) || rec.frames.some((frame) => typeof frame !== 'number')) continue;
    out[name] = {
      frames: rec.frames as number[],
      frameRate: typeof rec.frameRate === 'number' && rec.frameRate > 0 ? rec.frameRate : 8,
      repeat: typeof rec.repeat === 'number' ? rec.repeat : -1,
    };
  }
  return Object.keys(out).length > 0 ? out : undefined;
}

function frameRange(from: number, to: number): number[] {
  const start = Math.min(from, to);
  const end = Math.max(from, to);
  if (!Number.isInteger(start) || !Number.isInteger(end) || start < 0) return [];
  return Array.from({ length: end - start + 1 }, (_, i) => start + i);
}

function integerValue(value: unknown): number | undefined {
  return typeof value === 'number' && Number.isInteger(value) ? value : undefined;
}

function positiveInt(value: unknown): number | undefined {
  const n = integerValue(value);
  return n !== undefined && n > 0 ? n : undefined;
}

function positiveNumber(value: unknown): number | undefined {
  return typeof value === 'number' && Number.isFinite(value) && value > 0 ? value : undefined;
}

function pngSize(path: string): { width: number; height: number } | null {
  const buf = readFileSync(path);
  if (buf.length < 24 || buf.toString('ascii', 1, 4) !== 'PNG') return null;
  return { width: buf.readUInt32BE(16), height: buf.readUInt32BE(20) };
}

function listPng(dir: string): string[] {
  if (!existsSync(dir)) return [];
  return readdirSync(dir)
    .filter((name) => !name.startsWith('.') && extname(name).toLowerCase() === '.png')
    .sort((a, b) => a.localeCompare(b));
}

function stem(name: string): string {
  return name.slice(0, -extname(name).length);
}

if (import.meta.main) {
  const out = writeSpriteManifest();
  console.log(`wrote ${out}`);
}
