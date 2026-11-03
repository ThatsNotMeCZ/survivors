import Phaser from 'phaser';
import type { EntitySpriteDef, EnvAtlasDef, SpriteAnimDef, SpriteManifest, UiRect } from './sprite-types';

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
    if (manifest.envAtlas && Object.keys(manifest.envAtlas.frames).length > 0) {
      scene.load.image('env-atlas', manifest.envAtlas.src);
    }
    for (const id of manifest.env) {
      if (!manifest.envAtlas?.frames[id]) {
        scene.load.image(`env-${id}`, `sprites/env/${id}.png`);
      }
    }
  });
}

export function createEnvFrames(scene: Phaser.Scene): void {
  if (!manifest.envAtlas || !scene.textures.exists('env-atlas')) return;
  const texture = scene.textures.get('env-atlas');
  for (const [frameId, rect] of Object.entries(manifest.envAtlas.frames)) {
    if (!texture.has(frameId)) {
      texture.add(frameId, 0, rect.x, rect.y, rect.w, rect.h);
    }
  }
}

export function hasEnvTexture(scene: Phaser.Scene, id: string): boolean {
  if (manifest.envAtlas?.frames[id] && scene.textures.exists('env-atlas')) {
    const tex = scene.textures.get('env-atlas');
    if (tex.has(id)) return true;
  }
  return scene.textures.exists(`env-${id}`);
}

export function applyEnvTexture(
  image: Phaser.GameObjects.Image | Phaser.GameObjects.Sprite,
  id: string,
  fallbackKey?: string,
): boolean {
  const scene = image.scene;
  if (manifest.envAtlas?.frames[id] && scene.textures.exists('env-atlas')) {
    const tex = scene.textures.get('env-atlas');
    if (tex.has(id)) {
      image.setTexture('env-atlas', id);
      return true;
    }
  }
  const standalone = `env-${id}`;
  if (scene.textures.exists(standalone)) {
    image.setTexture(standalone);
    return true;
  }
  if (fallbackKey && scene.textures.exists(fallbackKey)) {
    image.setTexture(fallbackKey);
  }
  return false;
}

export function resolveEnvThemeProp(
  theme: string,
  propSuffix: string,
  scene: Phaser.Scene,
): string | null {
  const direct = `${theme}-${propSuffix}`;
  if (hasEnvTexture(scene, direct)) return direct;
  if (theme === 'glacial') {
    const rime = `rime-${propSuffix}`;
    if (hasEnvTexture(scene, rime)) return rime;
  }
  return null;
}

export function getEnvAtlasDef(): EnvAtlasDef | undefined {
  return manifest.envAtlas;
}

export function getEnvFrame(id: string): UiRect | undefined {
  return manifest.envAtlas?.frames[id];
}

export function getEnvAtlasSource(scene: Phaser.Scene): HTMLImageElement | HTMLCanvasElement | null {
  if (!scene.textures.exists('env-atlas')) return null;
  const tex = scene.textures.get('env-atlas');
  const source = tex.getSourceImage();
  return (source as HTMLImageElement | HTMLCanvasElement) || null;
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
        repeat: anim === 'attack' ? 0 : spec.repeat,
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
  const walk = entityAnimKey(id, 'walk');
  const attack = entityAnimKey(id, 'attack');

  const attackExists = sprite.anims.animationManager.exists(attack);
  const isPlayingAttack = sprite.anims.isPlaying && sprite.anims.currentAnim?.key === attack;
  const attackDone = sprite.getData('attackDone') === true;

  if (anim === 'attack') {
    if (attackExists) {
      if (isPlayingAttack) {
        // Still playing its single attack pass - keep playing uninterrupted
        return;
      }
      if (attackDone) {
        // Already played once for this attack - show walk if moving, else idle
        const fallback = timeScale > 0 && sprite.anims.animationManager.exists(walk)
          ? walk
          : sprite.anims.animationManager.exists(idle)
            ? idle
            : '';
        if (fallback) {
          sprite.play(fallback, true);
          if (sprite.anims) sprite.anims.timeScale = fallback === walk ? Math.max(0.1, timeScale) : 1;
        }
        return;
      }
      if (!sprite.anims.isPlaying && sprite.anims.currentAnim?.key === attack) {
        sprite.setData('attackDone', true);
        const fallback = timeScale > 0 && sprite.anims.animationManager.exists(walk)
          ? walk
          : sprite.anims.animationManager.exists(idle)
            ? idle
            : '';
        if (fallback) {
          sprite.play(fallback, true);
          if (sprite.anims) sprite.anims.timeScale = fallback === walk ? Math.max(0.1, timeScale) : 1;
        }
        return;
      }
      // New attack: start playing attack animation
      sprite.setData('attackDone', false);
      sprite.play(attack);
      return;
    }
  } else {
    sprite.setData('attackDone', false);
    if (isPlayingAttack) {
      return;
    }
  }

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
  const envAtlas = parseEnvAtlas(rec.envAtlas);
  return {
    entities,
    items: stringList(rec.items),
    skills: stringList(rec.skills),
    env: stringList(rec.env),
    fx: stringList(rec.fx),
    ...(envAtlas ? { envAtlas } : {}),
  };
}

function parseEnvAtlas(data: unknown): EnvAtlasDef | undefined {
  if (!data || typeof data !== 'object') return undefined;
  const rec = data as Record<string, unknown>;
  if (typeof rec.src !== 'string' || typeof rec.width !== 'number' || typeof rec.height !== 'number') {
    return undefined;
  }
  const frames: Record<string, UiRect> = {};
  if (rec.frames && typeof rec.frames === 'object') {
    for (const [id, frameRaw] of Object.entries(rec.frames as Record<string, unknown>)) {
      if (!frameRaw || typeof frameRaw !== 'object') continue;
      const f = frameRaw as Record<string, unknown>;
      if (
        typeof f.x === 'number' &&
        typeof f.y === 'number' &&
        typeof f.w === 'number' &&
        typeof f.h === 'number' &&
        f.w > 0 &&
        f.h > 0
      ) {
        frames[id] = { x: f.x, y: f.y, w: f.w, h: f.h };
      }
    }
  }
  return {
    src: rec.src,
    width: rec.width,
    height: rec.height,
    frames,
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
