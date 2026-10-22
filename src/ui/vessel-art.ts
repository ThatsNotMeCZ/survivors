import { resolveVessel, vesselIdleCanvas } from '../view/procedural-pixel-art';
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

/** Procedural idle, then swap in the entity sheet's idle frame if present. */
export function mountVesselArt(
  parent: HTMLElement,
  survivorId: string,
  className: string,
  label: string,
): HTMLCanvasElement {
  const src = vesselIdleCanvas(survivorId);
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
    const def = data?.entities[vessel];
    if (!def || !canvas.isConnected) return;
    const img = await loadPng(def.src);
    if (!img || !canvas.isConnected) return;
    const idle = def.anims.idle?.frames[0] ?? 0;
    const cols = Math.max(1, Math.floor(img.naturalWidth / def.frameWidth));
    const sx = (idle % cols) * def.frameWidth;
    const sy = Math.floor(idle / cols) * def.frameHeight;
    canvas.width = def.frameWidth;
    canvas.height = def.frameHeight;
    paintCanvas(canvas, img, sx, sy, def.frameWidth, def.frameHeight);
  });
  return canvas;
}
