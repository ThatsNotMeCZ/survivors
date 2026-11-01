import Phaser from 'phaser';
import type { EntitySpriteDef, SpriteAnimDef, SpriteManifest } from './sprite-types';

const emptyManifest = (): SpriteManifest => ({
  entities: {},
  items: [],
  skills: [],
  env: [],
  fx: [],
});

let manifest: SpriteManifest = emptyManifest();
const fallbacks = new Map<string, EntitySpriteDef>();
const fxIds = new Set<string>();

export function resolveEntitySheetId(id: string): string {
  if (id in manifest.entities || fallbacks.has(id)) return id;
  if ((id === 'ember-mite' || id === 'frost-mite') && ('mite' in manifest.entities || fallbacks.has('mite'))) {
    return 'mite';
  }
  if (
    (id === 'ember-spitter' || id === 'frost-spitter') &&
    ('spitter' in manifest.entities || fallbacks.has('spitter'))
  ) {
    return 'spitter';
  }
  return id;
}

export function entityTextureKey(id: string): string {
  return `entity-${resolveEntitySheetId(id)}`;
}

export function entityAnimKey(id: string, anim: string): string {
  return `entity-${resolveEntitySheetId(id)}-${anim}`;
}

export function itemSpriteSrc(id: string): string {
  return `sprites/items/${id}.png`;
}

export function skillSpriteSrc(id: string): string {
  return `sprites/skills/${id}.png`;
}

export function fxSpriteSrc(id: string): string {
  return `sprites/fx/${id}.png`;
}

export function fxTextureKey(id: string): string {
  return `fx-${id}`;
}

export function authoredEntity(id: string): boolean {
  const resolved = resolveEntitySheetId(id);
  return resolved in manifest.entities;
}

export function authoredFx(id: string): boolean {
  return fxIds.has(id);
}

export function entitySheet(id: string): EntitySpriteDef | undefined {
  const resolved = resolveEntitySheetId(id);
  return manifest.entities[resolved] ?? fallbacks.get(resolved);
}

export function registerFallbackSheet(
  id: string,
  def: { frameWidth: number; frameHeight: number; anims: Record<string, SpriteAnimDef> },
): void {
  if (authoredEntity(id) || fallbacks.has(id)) return;
  fallbacks.set(id, { src: '', ...def });
}

export function applySpriteManifest(data: unknown): SpriteManifest {
  manifest = parseManifest(data);
  fxIds.clear();
  for (const id of manifest.fx) fxIds.add(id);
  return manifest;
}

export function preloadSprites(scene: Phaser.Scene): void {
  scene.load.json('sprite-manifest', 'sprites/manifest.json');
  scene.load.once('filecomplete-json-sprite-manifest', (_key: string, _type: string, data: unknown) => {
    applySpriteManifest(data);
    for (const [id, def] of Object.entries(manifest.entities)) {
      scene.load.spritesheet(entityTextureKey(id), def.src, {
        frameWidth: def.frameWidth,
        frameHeight: def.frameHeight,
      });
    }
    for (const id of manifest.fx) {
      scene.load.image(fxTextureKey(id), fxSpriteSrc(id));
    }
  });
}

export function createEntityAnims(scene: Phaser.Scene): void {
  const ids = new Set([...Object.keys(manifest.entities), ...fallbacks.keys()]);
  for (const id of ids) {
    const def = entitySheet(id);
    const tex = entityTextureKey(id);
    if (!def || !scene.textures.exists(tex)) continue;
    for (const [anim, spec] of Object.entries(def.anims)) {
      const key = entityAnimKey(id, anim);
      if (scene.anims.exists(key)) continue;
      scene.anims.create({
        key,
        frames: scene.anims.generateFrameNumbers(tex, { frames: spec.frames }),
        frameRate: spec.frameRate,
        repeat: spec.repeat,
      });
    }
  }
}

export function playEntity(
  sprite: Phaser.GameObjects.Sprite,
  id: string,
  anim: 'idle' | 'walk' | 'attack',
  timeScale: number = 1,
): void {
  const tex = entityTextureKey(id);
  if (!sprite.scene.textures.exists(tex)) return;
  if (sprite.texture.key !== tex) sprite.setTexture(tex);
  const preferred = entityAnimKey(id, anim);
  const idle = entityAnimKey(id, 'idle');
  const key = sprite.anims.animationManager.exists(preferred)
    ? preferred
    : sprite.anims.animationManager.exists(idle)
      ? idle
      : '';
  if (key) {
    sprite.play(key, true);
    if (sprite.anims) {
      sprite.anims.timeScale = anim === 'walk' ? Math.max(0.1, timeScale) : 1;
    }
  }
}

export type GpuAnimSpec = {
  name: string;
  frames: string[];
  duration: number;
};

export function fodderGpuAnimations(id: string): GpuAnimSpec[] {
  const def = entitySheet(id);
  if (!def) return [];
  const list: GpuAnimSpec[] = [];
  for (const [name, spec] of Object.entries(def.anims)) {
    if (!spec.frames || spec.frames.length === 0) continue;
    list.push({
      name,
      frames: spec.frames.map(String),
      duration: (spec.frames.length / Math.max(1, spec.frameRate)) * 1000,
    });
  }
  return list;
}

export function fodderAnimSpec(id: string, animName: string): GpuAnimSpec | null {
  const def = entitySheet(id);
  const spec = def?.anims[animName];
  if (!spec || !spec.frames || spec.frames.length === 0) return null;
  return {
    name: animName,
    frames: spec.frames.map(String),
    duration: (spec.frames.length / Math.max(1, spec.frameRate)) * 1000,
  };
}

export function fodderGpuAnimation(
  id: string,
): GpuAnimSpec | null {
  return fodderAnimSpec(id, 'walk') ?? fodderAnimSpec(id, 'idle');
}

function parseManifest(data: unknown): SpriteManifest {
  const empty = emptyManifest();
  if (!data || typeof data !== 'object') return empty;
  const rec = data as Record<string, unknown>;
  const entities: Record<string, EntitySpriteDef> = {};
  if (rec.entities && typeof rec.entities === 'object') {
    for (const [id, raw] of Object.entries(rec.entities as Record<string, unknown>)) {
      const def = parseEntityDef(raw);
      if (def) entities[id] = def;
    }
  }
  return {
    entities,
    items: stringList(rec.items),
    skills: stringList(rec.skills),
    env: stringList(rec.env),
    fx: stringList(rec.fx),
  };
}

function parseEntityDef(raw: unknown): EntitySpriteDef | null {
  if (!raw || typeof raw !== 'object') return null;
  const rec = raw as Record<string, unknown>;
  if (typeof rec.src !== 'string' || typeof rec.frameWidth !== 'number' || typeof rec.frameHeight !== 'number') {
    return null;
  }
  const anims: Record<string, SpriteAnimDef> = {};
  if (rec.anims && typeof rec.anims === 'object') {
    for (const [name, spec] of Object.entries(rec.anims as Record<string, unknown>)) {
      if (!spec || typeof spec !== 'object') continue;
      const anim = spec as Record<string, unknown>;
      if (!Array.isArray(anim.frames) || anim.frames.some((frame) => typeof frame !== 'number')) continue;
      anims[name] = {
        frames: anim.frames as number[],
        frameRate: typeof anim.frameRate === 'number' && anim.frameRate > 0 ? anim.frameRate : 8,
        repeat: typeof anim.repeat === 'number' ? anim.repeat : -1,
      };
    }
  }
  if (!anims.idle) anims.idle = { frames: [0], frameRate: 1, repeat: -1 };
  return {
    src: rec.src,
    frameWidth: rec.frameWidth,
    frameHeight: rec.frameHeight,
    anims,
  };
}

function stringList(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value.filter((entry): entry is string => typeof entry === 'string' && entry.length > 0);
}
