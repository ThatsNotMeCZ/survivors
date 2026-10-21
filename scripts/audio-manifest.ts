import { existsSync, mkdirSync, readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { extname, join } from 'node:path';
import type { AudioManifest, SfxClip } from '../src/audio/types';

const DEFAULT_VOLUME = 1;
const MAX_VOLUME = 2;

export function writeAudioManifest(root = process.cwd()): string {
  const publicDir = join(root, 'public');
  const audioDir = join(publicDir, 'audio');
  mkdirSync(join(audioDir, 'music', 'menu'), { recursive: true });
  mkdirSync(join(audioDir, 'music', 'overlay'), { recursive: true });
  mkdirSync(join(audioDir, 'music', 'maps'), { recursive: true });
  mkdirSync(join(audioDir, 'sfx', 'ui'), { recursive: true });
  mkdirSync(join(audioDir, 'sfx', 'combat'), { recursive: true });
  mkdirSync(join(audioDir, 'sfx', 'world'), { recursive: true });

  const maps: Record<string, string[]> = {};
  const mapsDir = join(audioDir, 'music', 'maps');
  const mapIds = readdirSync(mapsDir, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .sort((a, b) => a.localeCompare(b));
  for (const id of mapIds) {
    maps[id] = listAudio(join(mapsDir, id)).map((name) => `audio/music/maps/${id}/${name}`);
  }

  const out = join(audioDir, 'manifest.json');
  const previous = readPreviousSfx(out);
  const sfx: Record<string, SfxClip> = {};
  const sfxDir = join(audioDir, 'sfx');
  for (const folder of ['ui', 'combat', 'world']) {
    for (const name of listAudio(join(sfxDir, folder))) {
      const id = name.slice(0, -extname(name).length);
      sfx[id] = {
        src: `audio/sfx/${folder}/${name}`,
        volume: previous[id] ?? DEFAULT_VOLUME,
      };
    }
  }

  const manifest: AudioManifest = {
    music: {
      menu: listAudio(join(audioDir, 'music', 'menu')).map((name) => `audio/music/menu/${name}`),
      maps,
      overlay: listAudio(join(audioDir, 'music', 'overlay')).map(
        (name) => `audio/music/overlay/${name}`,
      ),
    },
    sfx,
  };

  writeFileSync(out, `${JSON.stringify(manifest, null, 2)}\n`);
  return out;
}

function readPreviousSfx(path: string): Record<string, number> {
  if (!existsSync(path)) return {};
  try {
    const raw = JSON.parse(readFileSync(path, 'utf8')) as { sfx?: Record<string, unknown> };
    const volumes: Record<string, number> = {};
    for (const [id, entry] of Object.entries(raw.sfx ?? {})) {
      const volume = clipVolume(entry);
      if (volume !== undefined) volumes[id] = volume;
    }
    return volumes;
  } catch {
    return {};
  }
}

function clipVolume(entry: unknown): number | undefined {
  if (!entry || typeof entry !== 'object' || !('volume' in entry)) return undefined;
  return clampVolume(entry.volume);
}

function clampVolume(value: unknown): number | undefined {
  if (typeof value !== 'number' || !Number.isFinite(value)) return undefined;
  return Math.min(MAX_VOLUME, Math.max(0, value));
}

function listAudio(dir: string): string[] {
  if (!existsSync(dir)) return [];
  const byStem = new Map<string, string>();
  for (const name of readdirSync(dir)) {
    if (name.startsWith('.')) continue;
    const ext = extname(name).toLowerCase();
    if (ext !== '.ogg' && ext !== '.mp3') continue;
    const stem = name.slice(0, -ext.length);
    const prev = byStem.get(stem);
    if (!prev || ext === '.ogg') byStem.set(stem, name);
  }
  return [...byStem.values()].sort((a, b) => a.localeCompare(b));
}

if (import.meta.main) {
  const out = writeAudioManifest();
  console.log(`wrote ${out}`);
}
