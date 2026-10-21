import Phaser from 'phaser';
import { catalog } from '../data/catalog';
import {
  generateAllEntityCanvases,
  generateFloor,
  playerIdleKey,
  playerWalkKey,
  type BiomeId,
  type WalkFrame,
} from './procedural-pixel-art';

const VESSELS = ['runner', 'penitent'] as const;
const BIOMES: BiomeId[] = ['cinder', 'rime'];

/** Uploads procedural canvases for any `px-*` key not already loaded (PNG preload wins). */
export function uploadPixelTextures(scene: Phaser.Scene): void {
  const canvases = generateAllEntityCanvases();
  canvases.forEach((canvas, key) => addCanvasTexture(scene, key, canvas));
  const { width, height } = catalog.world;
  for (const biome of BIOMES) {
    addCanvasTexture(scene, `px-floor-${biome}`, generateFloor(biome, width, height));
  }
  overlayWalkFromIdle(scene);
}

/** Walk PNGs win. Otherwise copy the front idle so moving is not a missing texture. */
function overlayWalkFromIdle(scene: Phaser.Scene): void {
  for (const biome of BIOMES) {
    for (const vessel of VESSELS) {
      const idleKey = playerIdleKey(biome, vessel);
      if (!scene.textures.exists(idleKey)) continue;
      const src = copyTexture(scene, idleKey);
      for (const frame of [0, 1, 2] as WalkFrame[]) {
        const walkKey = playerWalkKey(biome, vessel, frame);
        if (scene.textures.exists(walkKey)) continue;
        addCanvasTexture(scene, walkKey, src);
      }
    }
  }
}

function copyTexture(scene: Phaser.Scene, key: string): HTMLCanvasElement {
  const texture = scene.textures.get(key);
  const frame = texture.get();
  const src = texture.getSourceImage() as CanvasImageSource;
  const canvas = document.createElement('canvas');
  canvas.width = frame.width;
  canvas.height = frame.height;
  const ctx = canvas.getContext('2d');
  if (!ctx) throw new Error('2d context missing');
  ctx.imageSmoothingEnabled = false;
  ctx.drawImage(src, 0, 0);
  return canvas;
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
