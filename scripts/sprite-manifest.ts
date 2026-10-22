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
      anims: sidecar?.anims ?? defaultAnims(size.width, sidecar?.frameWidth ?? inferFrameWidth(size.width, size.height), size.height),
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

function defaultAnims(width: number, frameWidth: number, frameHeight: number): Record<string, SpriteAnimDef> {
  const count = Math.max(1, Math.floor(width / Math.max(1, frameWidth)));
  const frames = Array.from({ length: count }, (_, i) => i);
  const anims: Record<string, SpriteAnimDef> = {
    idle: { frames: [0], frameRate: 1, repeat: -1 },
  };
  if (count > 1 && frameWidth === frameHeight) {
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
    const anims = parseAnims(rec.anims);
    return {
      frameWidth: positiveInt(rec.frameWidth),
      frameHeight: positiveInt(rec.frameHeight),
      anims,
    };
  } catch {
    return null;
  }
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

function positiveInt(value: unknown): number | undefined {
  return typeof value === 'number' && Number.isInteger(value) && value > 0 ? value : undefined;
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
