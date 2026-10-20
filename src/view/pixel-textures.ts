import Phaser from 'phaser';
import { catalog } from '../data/catalog';
import {
  generateAllEntityCanvases,
  generateFloor,
  type BiomeId,
} from './procedural-pixel-art';

let uploaded = false;

export function uploadPixelTextures(scene: Phaser.Scene): void {
  if (uploaded) return;
  const canvases = generateAllEntityCanvases();
  canvases.forEach((canvas, key) => addCanvasTexture(scene, key, canvas));
  const { width, height } = catalog.world;
  const biomes: BiomeId[] = ['cinder', 'rime'];
  for (const biome of biomes) {
    addCanvasTexture(scene, `px-floor-${biome}`, generateFloor(biome, width, height));
  }
  uploaded = true;
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
