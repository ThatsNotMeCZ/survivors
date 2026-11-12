import { existsSync, mkdirSync, readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { extname, join } from 'node:path';
import type {
  EntitySpriteDef,
  EnvAtlasDef,
  SpriteAnimDef,
  SpriteManifest,
  UiAtlasDef,
  UiNineSliceDef,
  UiNineSliceMargins,
  UiRect,
  UiSpriteEntry,
} from '../src/view/sprite-types';

export type {
  EntitySpriteDef,
  EnvAtlasDef,
  SpriteAnimDef,
  SpriteManifest,
  UiAtlasDef,
  UiNineSliceDef,
  UiNineSliceMargins,
  UiRect,
  UiSpriteEntry,
};

const FOLDERS = ['entities', 'items', 'skills', 'env', 'fx', 'ui'] as const;

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

  // Alias base stems (e.g. 'mite' -> 'ember-mite', 'frost-mite') if specific biome sheet is missing
  if (entities.mite) {
    if (!entities['ember-mite']) entities['ember-mite'] = { ...entities.mite };
    if (!entities['frost-mite']) entities['frost-mite'] = { ...entities.mite };
  }
  if (entities.spitter) {
    if (!entities['ember-spitter']) entities['ember-spitter'] = { ...entities.spitter };
    if (!entities['frost-spitter']) entities['frost-spitter'] = { ...entities.spitter };
  }
  if (entities['ember-warden'] && !entities['ember-chaser']) {
    entities['ember-chaser'] = { ...entities['ember-warden'] };
  } else if (entities['ember-chaser'] && !entities['ember-warden']) {
    entities['ember-warden'] = { ...entities['ember-chaser'] };
  }
  if (entities['frost-warden'] && !entities['frost-chaser']) {
    entities['frost-chaser'] = { ...entities['frost-warden'] };
  } else if (entities['frost-chaser'] && !entities['frost-warden']) {
    entities['frost-warden'] = { ...entities['frost-chaser'] };
  }

  const envDir = join(spritesDir, 'env');
  const envAtlas = readEnvAtlas(envDir);
  const envPngs = listPng(envDir)
    .map(stem)
    .filter((id) => id !== 'atlas');
  const envIds = Array.from(new Set([...envPngs, ...Object.keys(envAtlas?.frames ?? {})])).sort((a, b) =>
    a.localeCompare(b),
  );

  const uiDir = join(spritesDir, 'ui');
  const uiAtlas = readUiAtlas(uiDir);
  const uiPngs = listPng(uiDir)
    .map(stem)
    .filter((id) => id !== 'atlas');
  const uiIds = Array.from(new Set([...uiPngs, ...Object.keys(uiAtlas?.frames ?? {})])).sort((a, b) =>
    a.localeCompare(b),
  );

  const manifest: SpriteManifest = {
    entities,
    items: listPng(join(spritesDir, 'items')).map(stem),
    skills: listPng(join(spritesDir, 'skills')).map(stem),
    env: envIds,
    fx: listPng(join(spritesDir, 'fx')).map(stem),
    ui: uiIds,
    ...(uiAtlas ? { uiAtlas } : {}),
    ...(envAtlas ? { envAtlas } : {}),
  };

  const out = join(spritesDir, 'manifest.json');
  writeFileSync(out, `${JSON.stringify(manifest, null, 2)}\n`);
  return out;
}

function readEnvAtlas(envDir: string): EnvAtlasDef | undefined {
  const pngPath = join(envDir, 'atlas.png');
  const jsonPath = join(envDir, 'atlas.json');
  if (!existsSync(pngPath) || !existsSync(jsonPath)) return undefined;
  const size = pngSize(pngPath);
  if (!size) return undefined;
  try {
    const raw: unknown = JSON.parse(readFileSync(jsonPath, 'utf8'));
    if (!raw || typeof raw !== 'object') return undefined;
    const rec = raw as Record<string, unknown>;
    const framesSource =
      rec.frames && typeof rec.frames === 'object' && !Array.isArray(rec.frames)
        ? (rec.frames as Record<string, unknown>)
        : rec;
    const frames: Record<string, UiRect> = {};
    for (const [id, entryRaw] of Object.entries(framesSource)) {
      if (id === 'src' || id === 'width' || id === 'height' || id === 'meta') continue;
      const parsed = parseUiRect(entryRaw);
      if (parsed && parsed.w > 0 && parsed.h > 0) {
        frames[id] = parsed;
      }
    }
    return {
      src: 'sprites/env/atlas.png',
      width: size.width,
      height: size.height,
      frames,
    };
  } catch {
    return undefined;
  }
}

function readUiAtlas(uiDir: string): UiAtlasDef | undefined {
  const pngPath = join(uiDir, 'atlas.png');
  const jsonPath = join(uiDir, 'atlas.json');
  if (!existsSync(pngPath) || !existsSync(jsonPath)) return undefined;
  const size = pngSize(pngPath);
  if (!size) return undefined;
  try {
    const raw: unknown = JSON.parse(readFileSync(jsonPath, 'utf8'));
    if (!raw || typeof raw !== 'object') return undefined;
    const rec = raw as Record<string, unknown>;
    const framesSource =
      rec.frames && typeof rec.frames === 'object' && !Array.isArray(rec.frames)
        ? (rec.frames as Record<string, unknown>)
        : rec;
    const frames: Record<string, UiSpriteEntry> = {};
    for (const [id, entryRaw] of Object.entries(framesSource)) {
      if (id === 'src' || id === 'width' || id === 'height' || id === 'meta') continue;
      const parsed = parseUiSpriteEntry(entryRaw);
      if (parsed) frames[id] = parsed;
    }
    return {
      src: 'sprites/ui/atlas.png',
      width: size.width,
      height: size.height,
      frames,
    };
  } catch {
    return undefined;
  }
}

function parseUiSpriteEntry(raw: unknown): UiSpriteEntry | null {
  if (!raw || typeof raw !== 'object') return null;
  const rec = raw as Record<string, unknown>;
  const baseRect = parseUiRect(rec) ?? parseUiRect(rec.idle) ?? parseUiRect(rec.frame);
  if (!baseRect) return null;

  let idle = baseRect;
  let hover = baseRect;
  let active = baseRect;

  if (rec.states === 'strip-h' || rec.states === 'horizontal') {
    hover = { x: baseRect.x + baseRect.w, y: baseRect.y, w: baseRect.w, h: baseRect.h };
    active = { x: baseRect.x + baseRect.w * 2, y: baseRect.y, w: baseRect.w, h: baseRect.h };
  } else if (rec.states === 'strip-v' || rec.states === 'vertical') {
    hover = { x: baseRect.x, y: baseRect.y + baseRect.h, w: baseRect.w, h: baseRect.h };
    active = { x: baseRect.x, y: baseRect.y + baseRect.h * 2, w: baseRect.w, h: baseRect.h };
  } else if (rec.states && typeof rec.states === 'object') {
    const statesRec = rec.states as Record<string, unknown>;
    idle = parseUiRect(statesRec.idle) ?? baseRect;
    hover = parseUiRect(statesRec.hover) ?? idle;
    active = parseUiRect(statesRec.active) ?? hover;
  } else {
    hover = parseUiRect(rec.hover) ?? idle;
    active = parseUiRect(rec.active) ?? hover;
  }

  const nineSlice = parseUiNineSlice(rec.nineSlice ?? rec.slice, idle.w, idle.h);
  return {
    idle,
    hover,
    active,
    ...(nineSlice ? { nineSlice } : {}),
  };
}

function parseUiRect(raw: unknown): UiRect | null {
  if (!raw || typeof raw !== 'object') return null;
  const rec = raw as Record<string, unknown>;
  const x = nonNegativeInt(rec.x);
  const y = nonNegativeInt(rec.y);
  const w = positiveInt(rec.w ?? rec.width);
  const h = positiveInt(rec.h ?? rec.height);
  if (x === undefined || y === undefined || w === undefined || h === undefined) return null;
  return { x, y, w, h };
}

function parseUiNineSlice(raw: unknown, frameW: number, frameH: number): UiNineSliceDef | undefined {
  if (!raw || typeof raw !== 'object') return undefined;
  const rec = raw as Record<string, unknown>;

  const rawMargins =
    rec.margins && typeof rec.margins === 'object' ? (rec.margins as Record<string, unknown>) : rec;
  const explicitCenter = parseUiRect(
    rec.centerPiece ?? rec.pivot ?? (rec.expandable || rawMargins.top !== undefined ? rec.center : undefined),
  );
  const rawExpandable = parseUiRect(rec.expandable ?? (!explicitCenter ? rec.center : undefined));

  const mTop = nonNegativeInt(rawMargins.top);
  const mRight = nonNegativeInt(rawMargins.right);
  const mBottom = nonNegativeInt(rawMargins.bottom);
  const mLeft = nonNegativeInt(rawMargins.left);

  let margins: UiNineSliceMargins | null = null;
  let expandable: UiRect | null = null;

  if (mTop !== undefined && mRight !== undefined && mBottom !== undefined && mLeft !== undefined) {
    margins = { top: mTop, right: mRight, bottom: mBottom, left: mLeft };
    expandable = rawExpandable ?? {
      x: mLeft,
      y: mTop,
      w: Math.max(1, frameW - mLeft - mRight),
      h: Math.max(1, frameH - mTop - mBottom),
    };
  } else if (rawExpandable) {
    expandable = rawExpandable;
    margins = {
      left: rawExpandable.x,
      top: rawExpandable.y,
      right: Math.max(0, frameW - (rawExpandable.x + rawExpandable.w)),
      bottom: Math.max(0, frameH - (rawExpandable.y + rawExpandable.h)),
    };
  }

  if (!margins || !expandable) return undefined;

  const repeat =
    rec.repeat === 'repeat' || rec.repeat === 'round' || rec.repeat === 'stretch' ? rec.repeat : 'stretch';
  const scale = positiveNumber(rec.scale) ?? 1;

  return {
    margins,
    expandable,
    ...(explicitCenter ? { center: explicitCenter } : {}),
    repeat,
    scale,
  };
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
  const durationsMs = durations.map((d) => Math.round((d / Math.max(1, fps)) * 1000));
  const anims = parseTags(rec.tags, { oneIndexed: true, fps, durations, durationsMs });
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
  const durationsMs = sheetFrameDurationsMs(rec.frames);
  const anims = parseTags(metaRec.frameTags, { oneIndexed: false, fps, durations: [], durationsMs });
  if (!size && !anims) return null;
  return {
    frameWidth: size?.width,
    frameHeight: size?.height,
    anims,
  };
}

function isOneShotAnimName(name: string): boolean {
  return (
    name !== 'idle' &&
    name !== 'walk' &&
    !name.startsWith('idle-') &&
    !name.startsWith('walk-') &&
    !name.startsWith('channel')
  );
}

function parseTags(
  value: unknown,
  opts: { oneIndexed: boolean; fps: number; durations: number[]; durationsMs?: number[] },
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
    const perFrameMs =
      opts.durationsMs && frames.every((idx) => typeof opts.durationsMs![idx] === 'number' && opts.durationsMs![idx] > 0)
        ? frames.map((idx) => opts.durationsMs![idx])
        : undefined;
    const hasUnevenDurations =
      perFrameMs !== undefined && perFrameMs.some((ms) => ms !== perFrameMs[0]);
    const explicitRepeat = typeof rec.repeat === 'number' ? rec.repeat : undefined;
    out[name] = {
      frames,
      frameRate: tagFrameRate(frames, opts.fps, opts.durations, perFrameMs),
      repeat: explicitRepeat !== undefined ? explicitRepeat : isOneShotAnimName(name) ? 0 : -1,
      ...(hasUnevenDurations ? { durations: perFrameMs } : {}),
    };
  }
  if (!out.idle) out.idle = { frames: [0], frameRate: 1, repeat: -1 };
  return Object.keys(out).length > 0 ? out : undefined;
}

function tagFrameRate(
  frames: number[],
  fps: number,
  durations: number[],
  durationsMs?: number[],
): number {
  if (durationsMs && durationsMs.length > 0) {
    const avgMs = durationsMs.reduce((sum, ms) => sum + ms, 0) / durationsMs.length;
    if (avgMs > 0) return Math.round((1000 / avgMs) * 100) / 100;
  }
  const used = frames
    .map((index) => durations[index])
    .filter((value): value is number => value !== undefined && value > 0);
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

function sheetFrameDurationsMs(value: unknown): number[] {
  const entries = Array.isArray(value)
    ? value
    : value && typeof value === 'object'
      ? Object.values(value as Record<string, unknown>)
      : [];
  return entries.map((entry) => {
    if (!entry || typeof entry !== 'object') return 125;
    const duration = (entry as Record<string, unknown>).duration;
    return typeof duration === 'number' && duration > 0 ? duration : 125;
  });
}

function parseAnims(value: unknown): Record<string, SpriteAnimDef> | undefined {
  if (!value || typeof value !== 'object') return undefined;
  const out: Record<string, SpriteAnimDef> = {};
  for (const [rawName, spec] of Object.entries(value as Record<string, unknown>)) {
    if (!spec || typeof spec !== 'object') continue;
    const rec = spec as Record<string, unknown>;
    const name = rawName.trim().toLowerCase();
    let frames: number[] = [];
    if (Array.isArray(rec.frames) && rec.frames.every((frame) => typeof frame === 'number')) {
      frames = rec.frames as number[];
    } else if (integerValue(rec.from) !== undefined && integerValue(rec.to) !== undefined) {
      frames = frameRange(integerValue(rec.from)!, integerValue(rec.to)!);
    }
    if (frames.length === 0) continue;
    const durations =
      Array.isArray(rec.durations) &&
      rec.durations.length === frames.length &&
      rec.durations.every((d) => typeof d === 'number' && d > 0)
        ? (rec.durations as number[])
        : undefined;
    out[name] = {
      frames,
      frameRate: typeof rec.frameRate === 'number' && rec.frameRate > 0 ? rec.frameRate : 8,
      repeat: typeof rec.repeat === 'number' ? rec.repeat : isOneShotAnimName(name) ? 0 : -1,
      ...(durations ? { durations } : {}),
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

function nonNegativeInt(value: unknown): number | undefined {
  const n = integerValue(value);
  return n !== undefined && n >= 0 ? n : undefined;
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
