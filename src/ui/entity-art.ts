import {
  entityIdleCanvas,
  obstaclePreviewCanvas,
  type BiomeId,
} from '../view/procedural-pixel-art';
import type { SpriteManifest } from '../view/sprite-types';

let manifest: SpriteManifest | null = null;
let manifestLoad: Promise<SpriteManifest | null> | null = null;

async function loadManifest(): Promise<SpriteManifest | null> {
  if (manifest) return manifest;
  if (!manifestLoad) {
    manifestLoad = (async () => {
      try {
        const res = await fetch('sprites/manifest.json');
        if (!res.ok) return null;
        const data: unknown = await res.json();
        if (!data || typeof data !== 'object' || !('entities' in data)) return null;
        return data as SpriteManifest;
      } catch {
        return null;
      }
    })();
  }
  manifest = await manifestLoad;
  return manifest;
}

function paintCanvas(
  canvas: HTMLCanvasElement,
  source: CanvasImageSource,
  sx = 0,
  sy = 0,
  sw?: number,
  sh?: number,
): void {
  const ctx = canvas.getContext('2d');
  if (!ctx) return;
  ctx.imageSmoothingEnabled = false;
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  if (sw !== undefined && sh !== undefined) {
    ctx.drawImage(source, sx, sy, sw, sh, 0, 0, canvas.width, canvas.height);
  } else {
    ctx.drawImage(source, 0, 0, canvas.width, canvas.height);
  }
}

function loadPng(src: string): Promise<HTMLImageElement | null> {
  return new Promise((resolve) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = () => resolve(null);
    img.src = src;
  });
}

function resolveSheetId(entityId: string, data: SpriteManifest): string {
  if (entityId in data.entities) return entityId;
  if (entityId === 'ember-chaser' && 'ember-warden' in data.entities) return 'ember-warden';
  if (entityId === 'ember-warden' && 'ember-chaser' in data.entities) return 'ember-chaser';
  if (entityId === 'frost-chaser' && 'frost-warden' in data.entities) return 'frost-warden';
  if (entityId === 'frost-warden' && 'frost-chaser' in data.entities) return 'frost-chaser';
  if ((entityId === 'ember-mite' || entityId === 'frost-mite') && 'mite' in data.entities) {
    return 'mite';
  }
  if ((entityId === 'ember-spitter' || entityId === 'frost-spitter') && 'spitter' in data.entities) {
    return 'spitter';
  }
  return entityId;
}

/**
 * Mounts a crisp pixel-art canvas for any catalog entity (fodder, elite, boss, or vessel),
 * upgrading to the authored spritesheet idle frame if present in `public/sprites/manifest.json`.
 */
export function mountEntityArt(
  parent: HTMLElement,
  entityId: string,
  className: string,
  label: string,
): HTMLCanvasElement {
  const fallback = entityIdleCanvas(entityId);
  const canvas = document.createElement('canvas');
  canvas.width = fallback.width;
  canvas.height = fallback.height;
  canvas.className = className;
  canvas.setAttribute('role', 'img');
  canvas.setAttribute('aria-label', label);
  paintCanvas(canvas, fallback);
  parent.appendChild(canvas);

  void loadManifest().then(async (data) => {
    if (!data || !canvas.isConnected) return;
    const sheetKey = resolveSheetId(entityId, data);
    const def = data.entities[sheetKey];
    if (!def) return;
    const img = await loadPng(def.src);
    if (!img || !canvas.isConnected) return;
    const idleFrame = def.anims.idle?.frames[0] ?? 0;
    const cols = Math.max(1, Math.floor(img.naturalWidth / def.frameWidth));
    const sx = (idleFrame % cols) * def.frameWidth;
    const sy = Math.floor(idleFrame / cols) * def.frameHeight;
    canvas.width = def.frameWidth;
    canvas.height = def.frameHeight;
    paintCanvas(canvas, img, sx, sy, def.frameWidth, def.frameHeight);
  });

  return canvas;
}

/**
 * Mounts a pixel-art preview canvas for a chamber obstacle (`pillar`, `hazard`, `volatile`).
 */
export function mountObstacleArt(
  parent: HTMLElement,
  kind: 'pillar' | 'hazard' | 'volatile',
  biome: BiomeId,
  className: string,
  label: string,
): HTMLCanvasElement {
  const fallback = obstaclePreviewCanvas(kind, biome);
  const canvas = document.createElement('canvas');
  canvas.width = fallback.width;
  canvas.height = fallback.height;
  canvas.className = className;
  canvas.setAttribute('role', 'img');
  canvas.setAttribute('aria-label', label);
  paintCanvas(canvas, fallback);
  parent.appendChild(canvas);

  const propSuffix = kind === 'hazard' ? 'hazard-0' : kind;
  const envKey = `${biome}-${propSuffix}`;
  void loadManifest().then(async (data) => {
    if (!data || !canvas.isConnected) return;
    const rect = data.envAtlas?.frames[envKey];
    if (rect && data.envAtlas?.src) {
      const atlasImg = await loadPng(data.envAtlas.src);
      if (atlasImg && canvas.isConnected) {
        canvas.width = rect.w;
        canvas.height = rect.h;
        paintCanvas(canvas, atlasImg, rect.x, rect.y, rect.w, rect.h);
        return;
      }
    }
    if (data.env?.includes(envKey)) {
      const standalone = await loadPng(`sprites/env/${envKey}.png`);
      if (standalone && canvas.isConnected) {
        canvas.width = standalone.naturalWidth;
        canvas.height = standalone.naturalHeight;
        paintCanvas(canvas, standalone);
      }
    }
  });

  return canvas;
}
