import Phaser from 'phaser';

export function parseHex(color: string): number {
  return Number.parseInt(color.replace('#', ''), 16);
}

export function makeDotTexture(
  scene: Phaser.Scene,
  key: string,
  size: number,
  inner: string,
  mid: string,
): void {
  if (scene.textures.exists(key)) return;
  const texture = scene.textures.createCanvas(key, size, size);
  if (!texture) throw new Error(`Failed to create texture ${key}`);
  const ctx = texture.getContext();
  const r = size / 2;
  ctx.clearRect(0, 0, size, size);
  const glow = ctx.createRadialGradient(r, r, 1, r, r, r - 1);
  glow.addColorStop(0, inner);
  glow.addColorStop(0.55, mid);
  glow.addColorStop(1, 'rgba(0, 0, 0, 0)');
  ctx.fillStyle = glow;
  ctx.beginPath();
  ctx.arc(r, r, r - 1, 0, Math.PI * 2);
  ctx.fill();
  texture.refresh();
}

export function makeChevronTexture(
  scene: Phaser.Scene,
  key: string,
  inner = '#dff6ff',
  mid = '#5ad4ff',
): void {
  if (scene.textures.exists(key)) return;
  const size = 32;
  const texture = scene.textures.createCanvas(key, size, size);
  if (!texture) throw new Error(`Failed to create texture ${key}`);
  const ctx = texture.getContext();
  ctx.clearRect(0, 0, size, size);
  ctx.fillStyle = inner;
  ctx.beginPath();
  ctx.moveTo(30, 16);
  ctx.lineTo(4, 5);
  ctx.lineTo(10, 16);
  ctx.lineTo(4, 27);
  ctx.closePath();
  ctx.fill();
  ctx.fillStyle = mid;
  ctx.beginPath();
  ctx.moveTo(22, 16);
  ctx.lineTo(8, 10);
  ctx.lineTo(11, 16);
  ctx.lineTo(8, 22);
  ctx.closePath();
  ctx.fill();
  texture.refresh();
}
