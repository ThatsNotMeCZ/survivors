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
  entityTextureKey,
  getEnvAtlasDef,
  getEnvAtlasSource,
  registerFallbackSheet,
} from './sprites';

const THEMES: EnvThemeId[] = ['cinder', 'rime', 'glacial'];

/** Uploads procedural canvases for any `px-*` / entity key not already loaded (PNG sheets win). */
export function uploadPixelTextures(scene: Phaser.Scene): void {
  createEnvFrames(scene);
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
  uploadEntitySheets(scene);
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
