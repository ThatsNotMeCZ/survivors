import { resolveVessel, vesselIdleCanvas } from '../view/procedural-pixel-art';

let manifestKeys: string[] | null = null;
let manifestLoad: Promise<string[]> | null = null;

async function loadManifestKeys(): Promise<string[]> {
  if (manifestKeys) return manifestKeys;
  if (!manifestLoad) {
    manifestLoad = (async () => {
      try {
        const res = await fetch('sprites/manifest.json');
        if (!res.ok) return [];
        const data: unknown = await res.json();
        if (!data || typeof data !== 'object' || !('keys' in data)) return [];
        const keys = data.keys;
        if (!Array.isArray(keys)) return [];
        return keys.filter((key): key is string => typeof key === 'string' && key.length > 0);
      } catch {
        return [];
      }
    })();
  }
  manifestKeys = await manifestLoad;
  return manifestKeys;
}

function paintCanvas(canvas: HTMLCanvasElement, source: CanvasImageSource): void {
  const ctx = canvas.getContext('2d');
  if (!ctx) throw new Error('2d context missing');
  ctx.imageSmoothingEnabled = false;
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  ctx.drawImage(source, 0, 0, canvas.width, canvas.height);
}

function loadPng(src: string): Promise<HTMLImageElement | null> {
  return new Promise((resolve) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = () => resolve(null);
    img.src = src;
  });
}

/** Procedural idle, then swap in a generated PNG if the manifest lists one. */
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
  const candidates = [
    `px-player-body-${vessel}-cinder-side`,
    `px-player-body-${vessel}-cinder-front`,
    `px-portrait-${vessel}`,
  ];
  void loadManifestKeys().then(async (keys) => {
    const hit = candidates.find((key) => keys.includes(key));
    if (!hit || !canvas.isConnected) return;
    const img = await loadPng(`sprites/${hit}.png`);
    if (!img || !canvas.isConnected) return;
    canvas.width = img.naturalWidth || src.width;
    canvas.height = img.naturalHeight || src.height;
    paintCanvas(canvas, img);
  });
  return canvas;
}
