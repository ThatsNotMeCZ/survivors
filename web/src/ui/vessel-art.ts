import { resolveVessel, survivorPortrait, vesselIdleCanvas } from '../view/procedural-pixel-art';
import type { EntitySpriteDef, SpriteAnimDef, SpriteManifest } from '../view/sprite-types';

let manifest: SpriteManifest | null = null;
let manifestLoad: Promise<SpriteManifest | null> | null = null;

async function loadManifest(): Promise<SpriteManifest | null> {
  if (manifest) return manifest;
  if (!manifestLoad) {
    manifestLoad = (async () => {
      try {
        const res = await fetch('sprites/manifest.json', { cache: 'no-cache' });
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

async function loadJson(src: string): Promise<Record<string, unknown> | null> {
  try {
    const res = await fetch(src, { cache: 'no-cache' });
    if (!res.ok) return null;
    const data: unknown = await res.json();
    if (!data || typeof data !== 'object') return null;
    return data as Record<string, unknown>;
  } catch {
    return null;
  }
}

function paintCanvas(canvas: HTMLCanvasElement, source: CanvasImageSource, sx = 0, sy = 0, sw?: number, sh?: number): void {
  const ctx = canvas.getContext('2d');
  if (!ctx) throw new Error('2d context missing');
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

function parseIdleSpec(raw: Record<string, unknown> | null): SpriteAnimDef | null {
  if (!raw) return null;
  const anims = raw.anims;
  if (!anims || typeof anims !== 'object') return null;
  const idle = (anims as Record<string, unknown>).idle;
  if (!idle || typeof idle !== 'object') return null;
  const rec = idle as Record<string, unknown>;
  if (!Array.isArray(rec.frames) || !rec.frames.every((frame) => typeof frame === 'number')) return null;
  const frames = rec.frames as number[];
  if (frames.length === 0) return null;
  return {
    frames,
    frameRate: typeof rec.frameRate === 'number' && rec.frameRate > 0 ? rec.frameRate : 1,
    repeat: typeof rec.repeat === 'number' ? rec.repeat : -1,
  };
}

function paintSheetFrame(
  canvas: HTMLCanvasElement,
  img: HTMLImageElement,
  frameWidth: number,
  frameHeight: number,
  frame: number,
): void {
  const cols = Math.max(1, Math.floor(img.naturalWidth / frameWidth));
  const sx = (frame % cols) * frameWidth;
  const sy = Math.floor(frame / cols) * frameHeight;
  paintCanvas(canvas, img, sx, sy, frameWidth, frameHeight);
}

function playIdle(
  canvas: HTMLCanvasElement,
  img: HTMLImageElement,
  frameWidth: number,
  frameHeight: number,
  idle: SpriteAnimDef,
): void {
  canvas.width = frameWidth;
  canvas.height = frameHeight;
  const frames = idle.frames;
  const rate = idle.frameRate;
  const paintAt = (now: number): void => {
    const index = frames[Math.floor((now / 1000) * rate) % frames.length] ?? frames[0] ?? 0;
    paintSheetFrame(canvas, img, frameWidth, frameHeight, index);
  };
  paintAt(0);
  if (frames.length <= 1) return;
  const tick = (now: number): void => {
    if (!canvas.isConnected) return;
    paintAt(now);
    requestAnimationFrame(tick);
  };
  requestAnimationFrame(tick);
}

/** Procedural idle/portrait, then swap in authored art or entity sheet if present. */
export function mountVesselArt(
  parent: HTMLElement,
  survivorId: string,
  className: string,
  label: string,
): HTMLCanvasElement {
  const isPortrait = className.includes('portrait');
  const src = isPortrait ? survivorPortrait(survivorId) : vesselIdleCanvas(survivorId);
  const canvas = document.createElement('canvas');
  canvas.width = src.width;
  canvas.height = src.height;
  canvas.className = className;
  canvas.setAttribute('role', 'img');
  canvas.setAttribute('aria-label', label);
  paintCanvas(canvas, src);
  parent.appendChild(canvas);
  const vessel = resolveVessel(survivorId);
  void loadManifest().then(async (data) => {
    if (!canvas.isConnected) return;
    if (isPortrait) {
      const atlasEntry = data?.uiAtlas?.frames[`portrait-${survivorId}`];
      if (atlasEntry) {
        const atlasSrc = data?.uiAtlas?.src ?? 'sprites/ui/atlas.png';
        const atlasImg = await loadPng(atlasSrc);
        if (atlasImg && canvas.isConnected) {
          const rect = atlasEntry.idle;
          canvas.width = rect.w;
          canvas.height = rect.h;
          paintCanvas(canvas, atlasImg, rect.x, rect.y, rect.w, rect.h);
          return;
        }
      }
      if (data?.ui?.includes(`portrait-${survivorId}`)) {
        const portraitImg = await loadPng(`sprites/ui/portrait-${survivorId}.png`);
        if (portraitImg && canvas.isConnected) {
          canvas.width = portraitImg.naturalWidth;
          canvas.height = portraitImg.naturalHeight;
          paintCanvas(canvas, portraitImg);
          return;
        }
      }
      return;
    }
    const def: EntitySpriteDef | undefined = data?.entities[vessel];
    const sidecar = await loadJson(`sprites/entities/${vessel}.json`);
    const idle = parseIdleSpec(sidecar) ?? def?.anims.idle ?? null;
    const frameWidth =
      (typeof sidecar?.frameWidth === 'number' && sidecar.frameWidth > 0 ? sidecar.frameWidth : def?.frameWidth) ?? 0;
    const frameHeight =
      (typeof sidecar?.frameHeight === 'number' && sidecar.frameHeight > 0 ? sidecar.frameHeight : def?.frameHeight) ??
      0;
    const pngSrc = def?.src ?? `sprites/entities/${vessel}.png`;
    if (!idle || frameWidth <= 0 || frameHeight <= 0 || !canvas.isConnected) return;
    const img = await loadPng(pngSrc);
    if (!img || !canvas.isConnected) return;
    playIdle(canvas, img, frameWidth, frameHeight, idle);
  });
  return canvas;
}
