import Phaser from 'phaser';
import { catalog } from '../data/catalog';
import {
  floorKey,
  generateAllEntityCanvases,
  generateFloor,
  generateProceduralSheets,
  type EnvThemeId,
} from './procedural-pixel-art';
import {
  createEnvFrames,
  createUiFrames,
  entityTextureKey,
  getEnvAtlasDef,
  getEnvAtlasSource,
  getSpriteManifest,
  registerFallbackSheet,
} from './sprites';
import type { UiRect } from './sprite-types';

const THEMES: EnvThemeId[] = ['cinder', 'rime', 'glacial'];

/** Uploads procedural canvases for any `px-*` / entity key not already loaded (PNG sheets win). */
export function uploadPixelTextures(scene: Phaser.Scene): void {
  createEnvFrames(scene);
  createUiFrames(scene);
  const canvases = generateAllEntityCanvases();
  canvases.forEach((canvas, key) => addCanvasTexture(scene, key, canvas));
  const { width, height } = catalog.world;
  const atlasSource = getEnvAtlasSource(scene);
  const atlasDef = getEnvAtlasDef();
  for (const theme of THEMES) {
    addCanvasTexture(
      scene,
      floorKey(theme),
      generateFloor(theme, width, height, atlasSource, atlasDef?.frames),
    );
  }
  uploadBlendedHazardTextures(scene, atlasSource, atlasDef?.frames);
  enhanceLoadedEntitySheets(scene);
  uploadEntitySheets(scene);
}

function uploadBlendedHazardTextures(
  scene: Phaser.Scene,
  atlasSource: HTMLImageElement | HTMLCanvasElement | null,
  atlasFrames?: Record<string, UiRect>,
): void {
  if (!atlasSource || !atlasFrames) return;
  const hazardKeys = ['cinder-hazard-0', 'rime-hazard-0'];
  for (const key of hazardKeys) {
    const frame = atlasFrames[key];
    if (!frame || frame.w === 0 || frame.h === 0) continue;
    const biome = key.startsWith('rime') ? 'rime' : 'cinder';
    const blended = createBlendedHazardCanvas(atlasSource, frame, biome);
    if (blended) {
      addCanvasTexture(scene, `env-blended-${key}`, blended);
      if (key === 'rime-hazard-0') {
        addCanvasTexture(scene, 'env-blended-glacial-hazard-0', blended);
      }
    }
  }
}

function createBlendedHazardCanvas(
  source: HTMLImageElement | HTMLCanvasElement,
  frame: UiRect,
  biome: 'cinder' | 'rime',
): HTMLCanvasElement | null {
  if (typeof document === 'undefined') return null;
  const canvas = document.createElement('canvas');
  canvas.width = frame.w;
  canvas.height = frame.h;
  const ctx = canvas.getContext('2d');
  if (!ctx) return null;
  ctx.imageSmoothingEnabled = false;
  ctx.drawImage(source, frame.x, frame.y, frame.w, frame.h, 0, 0, frame.w, frame.h);

  const imgData = ctx.getImageData(0, 0, frame.w, frame.h);
  const data = imgData.data;
  const halfW = frame.w * 0.5;
  const halfH = frame.h * 0.5;

  for (let y = 0; y < frame.h; y++) {
    for (let x = 0; x < frame.w; x++) {
      const idx = (y * frame.w + x) * 4;
      const alpha = data[idx + 3];
      if (alpha === 0) continue;

      const r = data[idx];
      const g = data[idx + 1];
      const b = data[idx + 2];

      const nx = (x - halfW + 0.5) / halfW;
      const ny = (y - halfH + 0.5) / halfH;
      const dist = Math.hypot(nx, ny);

      // Steam preservation on top edge for rime hazard
      const isSteam = biome === 'rime' && ny < -0.12 && g > 140 && (r > 120 || b > 140);
      const brightness = Math.max(r, g, b);
      const isDarkRock = brightness < 72;

      // Distance thresholds for feathering
      const inner = isDarkRock ? 0.50 : isSteam ? 0.72 : 0.62;
      const outer = isSteam ? 1.05 : 0.95;

      let edgeFade = 1.0;
      if (dist > inner) {
        const t = Math.min(1.0, (dist - inner) / Math.max(0.01, outer - inner));
        edgeFade = 1.0 - t * t * (3.0 - 2.0 * t);
      }

      data[idx + 3] = Math.round(alpha * edgeFade);
    }
  }

  ctx.putImageData(imgData, 0, 0);
  return canvas;
}

function uploadEntitySheets(scene: Phaser.Scene): void {
  for (const [id, sheet] of generateProceduralSheets()) {
    registerFallbackSheet(id, {
      frameWidth: sheet.frameWidth,
      frameHeight: sheet.frameHeight,
      anims: sheet.anims,
    });
    const key = entityTextureKey(id);
    if (scene.textures.exists(key)) continue;
    addSpriteSheet(scene, key, sheet.canvas, sheet.frameWidth, sheet.frameHeight);
  }
}

function addSpriteSheet(
  scene: Phaser.Scene,
  key: string,
  canvas: HTMLCanvasElement,
  frameWidth: number,
  frameHeight: number,
): void {
  if (scene.textures.exists(key)) return;
  const texture = scene.textures.createCanvas(key, canvas.width, canvas.height);
  if (!texture) throw new Error(`Failed to create texture ${key}`);
  const ctx = texture.getContext();
  ctx.imageSmoothingEnabled = false;
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  ctx.drawImage(canvas, 0, 0);
  texture.refresh();
  const cols = Math.max(1, Math.floor(canvas.width / frameWidth));
  const rows = Math.max(1, Math.floor(canvas.height / frameHeight));
  let index = 0;
  for (let row = 0; row < rows; row += 1) {
    for (let col = 0; col < cols; col += 1) {
      texture.add(index, 0, col * frameWidth, row * frameHeight, frameWidth, frameHeight);
      index += 1;
    }
  }
}

function addCanvasTexture(scene: Phaser.Scene, key: string, canvas: HTMLCanvasElement): void {
  if (scene.textures.exists(key)) return;
  const texture = scene.textures.createCanvas(key, canvas.width, canvas.height);
  if (!texture) throw new Error(`Failed to create texture ${key}`);
  const ctx = texture.getContext();
  ctx.imageSmoothingEnabled = false;
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  ctx.drawImage(canvas, 0, 0);
  texture.refresh();
}

function enhanceLoadedEntitySheets(scene: Phaser.Scene): void {
  if (typeof document === 'undefined') return;
  const manifest = getSpriteManifest();
  if (!manifest?.entities) return;

  for (const [id, def] of Object.entries(manifest.entities)) {
    const texKey = entityTextureKey(id);
    if (!scene.textures.exists(texKey)) continue;
    const texture = scene.textures.get(texKey);
    const source = texture.getSourceImage() as HTMLImageElement | HTMLCanvasElement;
    if (!source || !source.width || !source.height) continue;

    const fw = def.frameWidth || source.height;
    const fh = def.frameHeight || source.height;
    const w = source.width;
    const h = source.height;

    const canvas = document.createElement('canvas');
    canvas.width = w;
    canvas.height = h;
    const ctx = canvas.getContext('2d', { willReadFrequently: true });
    if (!ctx) continue;
    ctx.imageSmoothingEnabled = false;
    ctx.drawImage(source, 0, 0);

    const imgData = ctx.getImageData(0, 0, w, h);
    const data = imgData.data;

    const isPlayer = id === 'runner' || id === 'penitent';
    const isCinder = id.startsWith('cinder') || id.startsWith('ember');

    // Subtle 1px rim colors on transparent border adjacent to sprite outline
    const rimR = isPlayer ? 255 : isCinder ? 255 : 190;
    const rimG = isPlayer ? 236 : isCinder ? 175 : 230;
    const rimB = isPlayer ? 180 : isCinder ? 110 : 255;
    const rimA = isPlayer ? 115 : isCinder ? 90 : 80;

    const cols = Math.floor(w / fw);
    const rows = Math.floor(h / fh);

    for (let r = 0; r < rows; r++) {
      for (let c = 0; c < cols; c++) {
        const startX = c * fw;
        const startY = r * fh;

        for (let fy = 0; fy < fh; fy++) {
          for (let fx = 0; fx < fw; fx++) {
            const px = startX + fx;
            const py = startY + fy;
            const idx = (py * w + px) * 4;
            const a = data[idx + 3];

            if (a > 128) {
              // Check if pixel is internal (all 4 cardinal neighbors inside frame are opaque)
              const hasLeft = fx > 0 && data[(py * w + (px - 1)) * 4 + 3] > 128;
              const hasRight = fx < fw - 1 && data[(py * w + (px + 1)) * 4 + 3] > 128;
              const hasTop = fy > 0 && data[((py - 1) * w + px) * 4 + 3] > 128;
              const hasBot = fy < fh - 1 && data[((py + 1) * w + px) * 4 + 3] > 128;

              if (hasLeft && hasRight && hasTop && hasBot) {
                // Interior pixel: lift deep shadows so the character body doesn't crush against its 1px black outline
                const lum = 0.299 * data[idx] + 0.587 * data[idx + 1] + 0.114 * data[idx + 2];
                if (lum < 72) {
                  const lift = Math.round((72 - lum) * 0.35);
                  data[idx] = Math.min(255, data[idx] + lift);
                  data[idx + 1] = Math.min(255, data[idx + 1] + lift);
                  data[idx + 2] = Math.min(255, data[idx + 2] + lift);
                }
              }
            } else if (a < 32) {
              // Transparent pixel: check if adjacent to an opaque pixel within the frame margins
              if (fx > 0 && fx < fw - 1 && fy > 0 && fy < fh - 1) {
                const adjOpaque =
                  data[(py * w + (px - 1)) * 4 + 3] > 128 ||
                  data[(py * w + (px + 1)) * 4 + 3] > 128 ||
                  data[((py - 1) * w + px) * 4 + 3] > 128 ||
                  data[((py + 1) * w + px) * 4 + 3] > 128;

                if (adjOpaque) {
                  data[idx] = rimR;
                  data[idx + 1] = rimG;
                  data[idx + 2] = rimB;
                  data[idx + 3] = rimA;
                }
              }
            }
          }
        }
      }
    }

    ctx.putImageData(imgData, 0, 0);
    texture.setSource(canvas);
  }
}
