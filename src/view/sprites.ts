import Phaser from 'phaser';
import type {
  EntitySpriteDef,
  EnvAtlasDef,
  SpriteAnimDef,
  SpriteManifest,
  UiAtlasDef,
  UiRect,
  UiSpriteEntry,
} from './sprite-types';

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
  if (id in manifest.entities) return id;
  if (id === 'ember-chaser' && 'ember-warden' in manifest.entities) return 'ember-warden';
  if (id === 'ember-warden' && 'ember-chaser' in manifest.entities) return 'ember-chaser';
  if (id === 'frost-chaser' && 'frost-warden' in manifest.entities) return 'frost-warden';
  if (id === 'frost-warden' && 'frost-chaser' in manifest.entities) return 'frost-chaser';
  if ((id === 'ember-mite' || id === 'frost-mite') && 'mite' in manifest.entities) {
    return 'mite';
  }
  if (
    (id === 'ember-spitter' || id === 'frost-spitter') &&
    'spitter' in manifest.entities
  ) {
    return 'spitter';
  }

  if (fallbacks.has(id)) return id;
  if (id === 'ember-chaser' && fallbacks.has('ember-warden')) return 'ember-warden';
  if (id === 'ember-warden' && fallbacks.has('ember-chaser')) return 'ember-chaser';
  if (id === 'frost-chaser' && fallbacks.has('frost-warden')) return 'frost-warden';
  if (id === 'frost-warden' && fallbacks.has('frost-chaser')) return 'frost-chaser';
  if ((id === 'ember-mite' || id === 'frost-mite') && fallbacks.has('mite')) {
    return 'mite';
  }
  if (
    (id === 'ember-spitter' || id === 'frost-spitter') &&
    fallbacks.has('spitter')
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
    const loadedEntityTextures = new Set<string>();
    for (const [id, def] of Object.entries(manifest.entities)) {
      const tex = entityTextureKey(id);
      if (loadedEntityTextures.has(tex)) continue;
      loadedEntityTextures.add(tex);
      scene.load.spritesheet(tex, def.src, {
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
    if (manifest.uiAtlas && Object.keys(manifest.uiAtlas.frames).length > 0) {
      scene.load.image('ui-atlas', manifest.uiAtlas.src);
    }
    for (const id of manifest.ui ?? []) {
      if (!manifest.uiAtlas?.frames[id]) {
        scene.load.image(`ui-${id}`, `sprites/ui/${id}.png`);
      }
    }
  });
}

export function createUiFrames(scene: Phaser.Scene): void {
  if (!manifest.uiAtlas || !scene.textures.exists('ui-atlas')) return;
  const texture = scene.textures.get('ui-atlas');
  for (const [frameId, entry] of Object.entries(manifest.uiAtlas.frames)) {
    if (!texture.has(frameId)) {
      const rect = entry.idle ?? entry;
      texture.add(frameId, 0, rect.x, rect.y, rect.w, rect.h);
    }
  }
}

export function hasUiTexture(scene: Phaser.Scene, id: string): boolean {
  if (manifest.uiAtlas?.frames[id] && scene.textures.exists('ui-atlas')) {
    const tex = scene.textures.get('ui-atlas');
    if (tex.has(id)) return true;
  }
  return scene.textures.exists(`ui-${id}`);
}

export function applyUiTexture(
  image: Phaser.GameObjects.Image | Phaser.GameObjects.Sprite,
  id: string,
  fallbackKey?: string,
): boolean {
  const scene = image.scene;
  if (manifest.uiAtlas?.frames[id] && scene.textures.exists('ui-atlas')) {
    const tex = scene.textures.get('ui-atlas');
    if (!tex.has(id)) {
      const entry = manifest.uiAtlas.frames[id];
      const rect = entry.idle ?? entry;
      tex.add(id, 0, rect.x, rect.y, rect.w, rect.h);
    }
    if (tex.has(id)) {
      image.setTexture('ui-atlas', id);
      return true;
    }
  }
  const standalone = `ui-${id}`;
  if (scene.textures.exists(standalone)) {
    image.setTexture(standalone);
    return true;
  }
  if (fallbackKey && scene.textures.exists(fallbackKey)) {
    image.setTexture(fallbackKey);
  }
  return false;
}

export function getUiAtlasDef(): UiAtlasDef | undefined {
  return manifest.uiAtlas;
}

export function getUiFrame(id: string): UiRect | undefined {
  const entry = manifest.uiAtlas?.frames[id];
  return entry ? (entry.idle ?? entry) : undefined;
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
      const isOneShot =
        anim !== 'idle' &&
        anim !== 'walk' &&
        !anim.startsWith('idle-') &&
        !anim.startsWith('walk-') &&
        !anim.startsWith('channel');
      const hasCustomDurations =
        Array.isArray(spec.durations) && spec.durations.length === spec.frames.length;
      const frames = hasCustomDurations
        ? spec.frames.map((frame, idx) => ({
            key: tex,
            frame,
            duration: spec.durations![idx],
          }))
        : scene.anims.generateFrameNumbers(tex, { frames: spec.frames });
      scene.anims.create({
        key,
        frames,
        frameRate: spec.frameRate,
        repeat: typeof spec.repeat === 'number' ? spec.repeat : isOneShot ? 0 : -1,
      });
    }
  }
}

export function playEntity(
  sprite: Phaser.GameObjects.Sprite,
  id: string,
  anim: string,
  timeScale: number = 1,
): void {
  const tex = entityTextureKey(id);
  if (!sprite.scene.textures.exists(tex)) return;
  if (sprite.texture.key !== tex) sprite.setTexture(tex);
  const preferred = entityAnimKey(id, anim);
  const idle = entityAnimKey(id, 'idle');
  const walk = entityAnimKey(id, 'walk');
  const genericAttack = entityAnimKey(id, 'attack');

  const isAttackRequest = anim !== 'idle' && anim !== 'walk';
  const resolvedAttackKey = sprite.anims.animationManager.exists(preferred)
    ? preferred
    : sprite.anims.animationManager.exists(genericAttack)
      ? genericAttack
      : '';
  const prevAttackKey = (sprite.getData('activeAttackKey') as string | undefined) ?? '';
  const currentKey = sprite.anims.currentAnim?.key ?? '';
  const isPlayingAttack =
    sprite.anims.isPlaying &&
    currentKey !== '' &&
    currentKey !== idle &&
    currentKey !== walk;
  const attackDone = sprite.getData('attackDone') === true;

  if (isAttackRequest) {
    if (resolvedAttackKey) {
      if (prevAttackKey !== resolvedAttackKey) {
        sprite.setData('activeAttackKey', resolvedAttackKey);
        sprite.setData('attackDone', false);
        sprite.play(resolvedAttackKey);
        if (sprite.anims) sprite.anims.timeScale = 1;
        return;
      }
      if (isPlayingAttack) {
        return;
      }
      if (attackDone) {
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
      if (!sprite.anims.isPlaying && currentKey === resolvedAttackKey) {
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
      sprite.setData('activeAttackKey', resolvedAttackKey);
      sprite.setData('attackDone', false);
      sprite.play(resolvedAttackKey);
      if (sprite.anims) sprite.anims.timeScale = 1;
      return;
    }
  } else {
    sprite.setData('attackDone', false);
    sprite.setData('activeAttackKey', '');
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
  const uiAtlas = parseUiAtlas(rec.uiAtlas);
  return {
    entities,
    items: stringList(rec.items),
    skills: stringList(rec.skills),
    env: stringList(rec.env),
    fx: stringList(rec.fx),
    ui: stringList(rec.ui),
    ...(envAtlas ? { envAtlas } : {}),
    ...(uiAtlas ? { uiAtlas } : {}),
  };
}

function parseUiRect(raw: unknown): UiRect | null {
  if (!raw || typeof raw !== 'object') return null;
  const r = raw as Record<string, unknown>;
  if (
    typeof r.x === 'number' &&
    typeof r.y === 'number' &&
    typeof r.w === 'number' &&
    typeof r.h === 'number' &&
    r.w > 0 &&
    r.h > 0
  ) {
    return { x: r.x, y: r.y, w: r.w, h: r.h };
  }
  return null;
}

function parseUiAtlas(data: unknown): UiAtlasDef | undefined {
  if (!data || typeof data !== 'object') return undefined;
  const rec = data as Record<string, unknown>;
  if (typeof rec.src !== 'string' || typeof rec.width !== 'number' || typeof rec.height !== 'number') {
    return undefined;
  }
  const frames: Record<string, UiSpriteEntry> = {};
  if (rec.frames && typeof rec.frames === 'object') {
    for (const [id, frameRaw] of Object.entries(rec.frames as Record<string, unknown>)) {
      if (!frameRaw || typeof frameRaw !== 'object') continue;
      const f = frameRaw as Record<string, unknown>;
      const rawIdle = f.idle && typeof f.idle === 'object' ? f.idle : f;
      const idle = parseUiRect(rawIdle);
      if (!idle) continue;
      const hover = (f.hover && typeof f.hover === 'object' ? parseUiRect(f.hover) : null) ?? idle;
      const active = (f.active && typeof f.active === 'object' ? parseUiRect(f.active) : null) ?? idle;
      frames[id] = { idle, hover, active };
    }
  }
  return {
    src: rec.src,
    width: rec.width,
    height: rec.height,
    frames,
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
      const rect = parseUiRect(frameRaw);
      if (rect) frames[id] = rect;
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
