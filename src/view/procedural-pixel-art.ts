export type BiomeId = 'cinder' | 'rime';

const cache = new Map<string, HTMLCanvasElement>();

export const OUTLINE: Record<BiomeId, string> = {
  cinder: '#120a0d',
  rime: '#08101a',
};

export function stageBiome(stageId: string): BiomeId {
  return stageId === 'rime-dock' ? 'rime' : 'cinder';
}

export function cachedPixel(key: string, size: number, biome: BiomeId, draw: (px: PixelBuf) => void): HTMLCanvasElement {
  const hit = cache.get(key);
  if (hit) return hit;
  const canvas = renderPixelArt(size, OUTLINE[biome], draw);
  cache.set(key, canvas);
  return canvas;
}

export function cachedRaw(key: string, build: () => HTMLCanvasElement): HTMLCanvasElement {
  const hit = cache.get(key);
  if (hit) return hit;
  const canvas = build();
  cache.set(key, canvas);
  return canvas;
}

export function playerBodyKey(biome: BiomeId): string {
  return `px-player-body-${biome}`;
}
export function playerEyesKey(biome: BiomeId): string {
  return `px-player-eyes-${biome}`;
}
export function playerCatalystKey(biome: BiomeId): string {
  return `px-player-catalyst-${biome}`;
}
export function miteKey(biome: BiomeId, frame: 0 | 1): string {
  return `px-mite-${biome}-${frame}`;
}
export function spitterKey(biome: BiomeId): string {
  return `px-spitter-${biome}`;
}
export function eliteKey(biome: BiomeId): string {
  return `px-elite-${biome}`;
}
export function eliteGlyphKey(): string {
  return 'px-elite-glyph';
}
export function bossKey(id: 'cinder-heart' | 'frost-sovereign'): string {
  return `px-boss-${id}`;
}
export function pillarKey(biome: BiomeId): string {
  return `px-pillar-${biome}`;
}
export function hazardKey(biome: BiomeId, frame: 0 | 1): string {
  return `px-hazard-${biome}-${frame}`;
}
export function volatileKey(biome: BiomeId): string {
  return `px-volatile-${biome}`;
}
export function floorKey(biome: BiomeId): string {
  return `px-floor-${biome}`;
}

export type PixelBuf = {
  size: number;
  fill: (x: number, y: number, w: number, h: number, color: string) => void;
  dot: (x: number, y: number, color: string) => void;
};

export function renderPixelArt(size: number, outline: string, draw: (px: PixelBuf) => void): HTMLCanvasElement {
  const canvas = makeCanvas(size, size);
  const ctx = canvas.getContext('2d');
  if (!ctx) throw new Error('2d context missing');
  ctx.imageSmoothingEnabled = false;
  ctx.clearRect(0, 0, size, size);
  const px: PixelBuf = {
    size,
    fill: (x, y, w, h, color) => {
      ctx.fillStyle = color;
      ctx.fillRect(Math.floor(x), Math.floor(y), Math.max(1, Math.floor(w)), Math.max(1, Math.floor(h)));
    },
    dot: (x, y, color) => {
      ctx.fillStyle = color;
      ctx.fillRect(Math.floor(x), Math.floor(y), 1, 1);
    },
  };
  draw(px);
  outlinePass(ctx, size, size, outline);
  return canvas;
}

export function generateAllEntityCanvases(): Map<string, HTMLCanvasElement> {
  const out = new Map<string, HTMLCanvasElement>();
  const biomes: BiomeId[] = ['cinder', 'rime'];
  for (const biome of biomes) {
    put(out, playerBodyKey(biome), makePlayerBody(biome));
    put(out, playerEyesKey(biome), makePlayerEyes(biome));
    put(out, playerCatalystKey(biome), makePlayerCatalyst(biome));
    put(out, miteKey(biome, 0), makeMite(biome, 0));
    put(out, miteKey(biome, 1), makeMite(biome, 1));
    put(out, spitterKey(biome), makeSpitter(biome));
    put(out, eliteKey(biome), makeElite(biome));
    put(out, pillarKey(biome), makePillar(biome));
    put(out, hazardKey(biome, 0), makeHazard(biome, 0));
    put(out, hazardKey(biome, 1), makeHazard(biome, 1));
    put(out, volatileKey(biome), makeVolatile(biome));
  }
  put(out, eliteGlyphKey(), makeEliteGlyph());
  put(out, bossKey('cinder-heart'), makeCinderHeart());
  put(out, bossKey('frost-sovereign'), makeFrostSovereign());
  put(out, 'px-bolt-player', makeBolt('#fff4c8', '#ffd35a', 'cinder'));
  put(out, 'px-bolt-enemy-cinder', makeBolt('#ffcc88', '#ff5522', 'cinder'));
  put(out, 'px-bolt-enemy-rime', makeBolt('#dff6ff', '#44ddff', 'rime'));
  put(out, 'px-gem', makeGem());
  put(out, 'px-spark', makeSpark());
  put(out, 'px-crosshair', makeCrosshair());
  put(out, 'px-waypoint', makeWaypoint());
  put(out, 'px-glow', makeGlow());
  put(out, 'px-orbit-cinder', makeOrbitShard('cinder'));
  put(out, 'px-ash', makeSpeck('#9a8a80', 2));
  put(out, 'px-ember', makeSpeck('#ff7722', 1));
  put(out, 'px-snow', makeSpeck('#d8eef8', 2));
  put(out, 'px-mist', makeSpeck('#1a3048', 3));
  return out;
}

export function generateFloor(biome: BiomeId, width: number, height: number): HTMLCanvasElement {
  return cachedRaw(floorKey(biome), () => {
    const canvas = makeCanvas(width, height);
    const ctx = canvas.getContext('2d');
    if (!ctx) throw new Error('2d context missing');
    ctx.imageSmoothingEnabled = false;
    const tiles = [0, 1, 2, 3].map((v) => makeFloorTile(biome, v));
    const tile = 64;
    for (let ty = 0; ty < height / tile; ty += 1) {
      for (let tx = 0; tx < width / tile; tx += 1) {
        const variant = tileVariant(tx, ty);
        ctx.drawImage(tiles[variant], tx * tile, ty * tile);
      }
    }
    drawBoundary(ctx, width, height, biome);
    return canvas;
  });
}

function put(out: Map<string, HTMLCanvasElement>, key: string, canvas: HTMLCanvasElement): void {
  cache.set(key, canvas);
  out.set(key, canvas);
}

function makePlayerBody(biome: BiomeId): HTMLCanvasElement {
  const trim = biome === 'cinder' ? '#c94a4a' : '#5ad4ff';
  return cachedPixel(playerBodyKey(biome), 32, biome, (px) => {
    px.fill(10, 6, 12, 4, '#3a3244');
    px.fill(8, 8, 16, 5, '#52465c');
    px.fill(7, 12, 18, 14, '#2a2430');
    px.fill(9, 24, 5, 6, '#2a2430');
    px.fill(18, 24, 5, 6, '#2a2430');
    px.fill(8, 12, 16, 2, trim);
    px.fill(11, 4, 10, 5, '#1c1822');
    px.fill(12, 3, 8, 3, '#1c1822');
  });
}

function makePlayerEyes(biome: BiomeId): HTMLCanvasElement {
  const glow = biome === 'cinder' ? '#ffdd66' : '#77ffff';
  return cachedPixel(playerEyesKey(biome), 8, biome, (px) => {
    px.fill(1, 3, 2, 1, glow);
    px.fill(5, 3, 2, 1, glow);
  });
}

function makePlayerCatalyst(biome: BiomeId): HTMLCanvasElement {
  const core = biome === 'cinder' ? '#ffaa33' : '#55ffff';
  return cachedPixel(playerCatalystKey(biome), 16, biome, (px) => {
    px.fill(4, 5, 8, 7, '#8a6a3a');
    px.fill(5, 6, 6, 5, '#c4a05a');
    px.fill(6, 7, 4, 3, core);
    px.fill(7, 8, 2, 1, '#fff4c8');
    px.fill(3, 8, 2, 2, '#6a5030');
  });
}

function makeMite(biome: BiomeId, frame: 0 | 1): HTMLCanvasElement {
  const core = biome === 'cinder' ? '#ff5522' : '#44ddff';
  const shell = biome === 'cinder' ? '#5a2018' : '#1a3a52';
  const jag = biome === 'cinder' ? '#3a1410' : '#0e2438';
  return cachedPixel(miteKey(biome, frame), 24, biome, (px) => {
    px.fill(4, 8, 16, 10, shell);
    px.fill(6, 6, 12, 4, shell);
    px.fill(8, 10, 8, 6, core);
    px.fill(10, 12, 4, 2, '#fff0c8');
    const legY = frame === 0 ? 18 : 17;
    px.fill(3, legY, 4, 3, jag);
    px.fill(17, frame === 0 ? 17 : 18, 4, 3, jag);
    px.fill(2, 10, 3, 3, jag);
    px.fill(19, 10, 3, 3, jag);
  });
}

function makeSpitter(biome: BiomeId): HTMLCanvasElement {
  const body = biome === 'cinder' ? '#4a2818' : '#163044';
  const maw = biome === 'cinder' ? '#ff7a3a' : '#7ad4ff';
  return cachedPixel(spitterKey(biome), 28, biome, (px) => {
    px.fill(12, 18, 4, 8, body);
    px.fill(6, 20, 4, 6, body);
    px.fill(18, 20, 4, 6, body);
    px.fill(8, 8, 12, 12, body);
    px.fill(10, 4, 8, 6, '#2a1810');
    px.fill(12, 6, 4, 5, maw);
    px.fill(13, 8, 2, 2, '#fff4c8');
  });
}

function makeElite(biome: BiomeId): HTMLCanvasElement {
  const metal = biome === 'cinder' ? '#6a3a32' : '#2a4a66';
  const crown = biome === 'cinder' ? '#c45a3a' : '#7ad4ff';
  return cachedPixel(eliteKey(biome), 40, biome, (px) => {
    px.fill(12, 10, 16, 22, metal);
    px.fill(8, 14, 8, 10, metal);
    px.fill(24, 14, 8, 10, metal);
    px.fill(10, 6, 20, 6, crown);
    px.fill(14, 2, 4, 6, crown);
    px.fill(22, 2, 4, 6, crown);
    px.fill(16, 16, 8, 8, biome === 'cinder' ? '#ff5522' : '#44ddff');
    px.fill(6, 12, 4, 4, '#9aa0a8');
    px.fill(30, 12, 4, 4, '#9aa0a8');
    px.fill(14, 32, 5, 6, metal);
    px.fill(22, 32, 5, 6, metal);
  });
}

function makeEliteGlyph(): HTMLCanvasElement {
  return cachedPixel(eliteGlyphKey(), 48, 'cinder', (px) => {
    const c = '#c4a05a';
    for (let i = 8; i < 40; i += 2) {
      px.dot(i, 8, c);
      px.dot(i, 39, c);
      px.dot(8, i, c);
      px.dot(39, i, c);
    }
    px.fill(22, 14, 4, 20, c);
    px.fill(14, 22, 20, 4, c);
    px.fill(18, 18, 12, 12, '#00000000');
  });
}

function makeCinderHeart(): HTMLCanvasElement {
  return cachedPixel(bossKey('cinder-heart'), 64, 'cinder', (px) => {
    px.fill(18, 14, 28, 36, '#2a1814');
    px.fill(16, 18, 32, 28, '#3a2018');
    px.fill(22, 12, 6, 8, '#1a0c0a');
    px.fill(36, 12, 6, 8, '#1a0c0a');
    px.fill(24, 22, 16, 16, '#ff7722');
    px.fill(28, 26, 8, 8, '#fff0c8');
    px.fill(20, 20, 4, 20, '#1a0c0a');
    px.fill(40, 20, 4, 20, '#1a0c0a');
    px.dot(26, 18, '#5a3020');
    px.dot(38, 40, '#5a3020');
  });
}

function makeFrostSovereign(): HTMLCanvasElement {
  return cachedPixel(bossKey('frost-sovereign'), 64, 'rime', (px) => {
    px.fill(22, 16, 20, 36, '#1a3048');
    px.fill(18, 22, 28, 24, '#163044');
    px.fill(20, 6, 24, 12, '#7ad4ff');
    px.fill(16, 8, 6, 10, '#dff6ff');
    px.fill(42, 8, 6, 10, '#dff6ff');
    px.fill(28, 4, 8, 8, '#f4fbff');
    px.fill(28, 26, 8, 10, '#55ffff');
    px.fill(14, 28, 8, 3, '#88c8e8');
    px.fill(42, 32, 8, 3, '#88c8e8');
  });
}

function makePillar(biome: BiomeId): HTMLCanvasElement {
  const stone = biome === 'cinder' ? '#3a2428' : '#1c3044';
  const rune = biome === 'cinder' ? '#c45a3a' : '#55ffff';
  return cachedPixel(pillarKey(biome), 64, biome, (px) => {
    px.fill(18, 48, 28, 10, '#120a0d');
    px.fill(20, 8, 24, 46, stone);
    px.fill(16, 12, 32, 38, stone);
    px.fill(22, 6, 20, 6, biome === 'cinder' ? '#4a3030' : '#2a4860');
    px.fill(28, 18, 8, 2, rune);
    px.fill(30, 24, 4, 10, rune);
    px.fill(26, 36, 12, 2, rune);
    px.fill(18, 20, 4, 20, '#221418');
  });
}

function makeHazard(biome: BiomeId, frame: 0 | 1): HTMLCanvasElement {
  const rim = biome === 'cinder' ? '#3a2018' : '#1a3040';
  const innerA = biome === 'cinder' ? '#ff5522' : '#1a6888';
  const innerB = biome === 'cinder' ? '#cc3300' : '#44ddff';
  const inner = frame === 0 ? innerA : innerB;
  return cachedPixel(hazardKey(biome, frame), 64, biome, (px) => {
    px.fill(8, 16, 48, 32, rim);
    px.fill(12, 12, 40, 40, rim);
    px.fill(16, 18, 32, 28, inner);
    px.fill(20, 22, 24, 20, frame === 0 ? '#ffaa33' : biome === 'cinder' ? '#ff7722' : '#88f0ff');
    if (biome === 'rime') {
      px.fill(18, 20, 6, 4, '#dff6ff');
      px.fill(40, 36, 8, 5, '#c8e8f8');
    } else {
      px.fill(24, 24, 3, 3, '#fff0c8');
      px.fill(36, 32, 2, 2, '#ffcc66');
    }
  });
}

function makeVolatile(biome: BiomeId): HTMLCanvasElement {
  const band = biome === 'cinder' ? '#b87333' : '#8aa4b8';
  const body = biome === 'cinder' ? '#4a2018' : '#1a3a52';
  return cachedPixel(volatileKey(biome), 24, biome, (px) => {
    px.fill(7, 4, 10, 16, body);
    px.fill(6, 6, 12, 3, band);
    px.fill(6, 12, 12, 3, band);
    px.fill(8, 2, 8, 3, biome === 'cinder' ? '#8a4a28' : '#c8e4f4');
    px.fill(10, 8, 4, 4, biome === 'cinder' ? '#ff5522' : '#55ffff');
  });
}

function makeBolt(inner: string, mid: string, biome: BiomeId): HTMLCanvasElement {
  return cachedPixel(`px-bolt-${inner}-${mid}`, 8, biome, (px) => {
    px.fill(2, 2, 4, 4, mid);
    px.fill(3, 3, 2, 2, inner);
  });
}

function makeGem(): HTMLCanvasElement {
  return cachedPixel('px-gem', 16, 'cinder', (px) => {
    px.fill(6, 2, 4, 12, '#ffd35a');
    px.fill(4, 4, 8, 8, '#fff4c8');
    px.fill(7, 6, 2, 4, '#ffe88a');
  });
}

function makeSpark(): HTMLCanvasElement {
  return cachedPixel('px-spark', 8, 'cinder', (px) => {
    px.fill(3, 2, 2, 4, '#ffffff');
    px.fill(2, 3, 4, 2, '#ffd35a');
  });
}

function makeCrosshair(): HTMLCanvasElement {
  return cachedPixel('px-crosshair', 16, 'cinder', (px) => {
    px.fill(7, 1, 2, 4, '#ffffff');
    px.fill(7, 11, 2, 4, '#ffffff');
    px.fill(1, 7, 4, 2, '#9ad4ff');
    px.fill(11, 7, 4, 2, '#9ad4ff');
  });
}

function makeWaypoint(): HTMLCanvasElement {
  return cachedPixel('px-waypoint', 16, 'cinder', (px) => {
    px.fill(12, 6, 3, 4, '#fff4c8');
    px.fill(8, 4, 5, 8, '#5ad4ff');
    px.fill(4, 2, 5, 12, '#9ad4ff');
  });
}

function makeGlow(): HTMLCanvasElement {
  const canvas = makeCanvas(32, 32);
  const ctx = canvas.getContext('2d');
  if (!ctx) throw new Error('2d context missing');
  const g = ctx.createRadialGradient(16, 16, 2, 16, 16, 15);
  g.addColorStop(0, 'rgba(255, 220, 140, 0.55)');
  g.addColorStop(1, 'rgba(255, 220, 140, 0)');
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, 32, 32);
  cache.set('px-glow', canvas);
  return canvas;
}

function makeOrbitShard(biome: BiomeId): HTMLCanvasElement {
  return cachedPixel('px-orbit-cinder', 16, biome, (px) => {
    px.fill(5, 2, 6, 12, '#3a2018');
    px.fill(6, 4, 4, 8, '#ff7722');
  });
}

function makeSpeck(color: string, size: number): HTMLCanvasElement {
  const canvas = makeCanvas(4, 4);
  const ctx = canvas.getContext('2d');
  if (!ctx) throw new Error('2d context missing');
  ctx.imageSmoothingEnabled = false;
  ctx.fillStyle = color;
  ctx.fillRect(0, 0, size, size);
  return canvas;
}

function makeFloorTile(biome: BiomeId, variant: number): HTMLCanvasElement {
  const key = `px-tile-${biome}-${variant}`;
  const pal =
    biome === 'cinder'
      ? ['#1c1113', '#231517', '#170d0f', '#2a1814']
      : ['#0e1722', '#121e2b', '#0a111a', '#162030'];
  const mark = biome === 'cinder' ? '#5a3a20' : '#3a5a70';
  return cachedPixel(key, 64, biome, (px) => {
    px.fill(0, 0, 64, 64, pal[variant % 3]);
    px.fill(2, 2, 28, 28, pal[(variant + 1) % 3]);
    px.fill(34, 6, 26, 22, pal[(variant + 2) % 3]);
    px.fill(8, 36, 40, 20, pal[variant % 3]);
    if (variant === 0) {
      px.fill(12, 12, 8, 1, mark);
      px.fill(16, 10, 1, 8, mark);
    } else if (variant === 1) {
      for (let i = 8; i < 50; i += 7) px.dot(i, 40 + (i % 3), mark);
    } else if (variant === 2) {
      px.fill(40, 18, 10, 1, mark);
      px.fill(44, 16, 1, 8, mark);
    } else {
      px.fill(20, 48, 18, 1, mark);
    }
  });
}

function tileVariant(tx: number, ty: number): number {
  return ((tx * 73856093) ^ (ty * 19349663)) >>> 0 & 3;
}

function drawBoundary(ctx: CanvasRenderingContext2D, width: number, height: number, biome: BiomeId): void {
  const outer = biome === 'cinder' ? '#5a3020' : '#3a5a7a';
  const inner = biome === 'cinder' ? '#c45a3a' : '#55ffff';
  ctx.imageSmoothingEnabled = false;
  ctx.fillStyle = outer;
  ctx.fillRect(0, 0, width, 8);
  ctx.fillRect(0, height - 8, width, 8);
  ctx.fillRect(0, 0, 8, height);
  ctx.fillRect(width - 8, 0, 8, height);
  ctx.fillStyle = inner;
  ctx.fillRect(8, 8, width - 16, 2);
  ctx.fillRect(8, height - 10, width - 16, 2);
  ctx.fillRect(8, 8, 2, height - 16);
  ctx.fillRect(width - 10, 8, 2, height - 16);
  ctx.fillStyle = biome === 'cinder' ? '#ffaa33' : '#88f0ff';
  for (let i = 32; i < width; i += 64) {
    ctx.fillRect(i, 4, 4, 4);
    ctx.fillRect(i, height - 8, 4, 4);
    ctx.fillRect(4, i, 4, 4);
    ctx.fillRect(width - 8, i, 4, 4);
  }
}

function outlinePass(ctx: CanvasRenderingContext2D, width: number, height: number, outline: string): void {
  const img = ctx.getImageData(0, 0, width, height);
  const { data } = img;
  const src = new Uint8ClampedArray(data);
  const rgb = hexRgb(outline);
  const idx = (x: number, y: number) => (y * width + x) * 4;
  const solid = (x: number, y: number) => {
    if (x < 0 || y < 0 || x >= width || y >= height) return false;
    return src[idx(x, y) + 3] > 16;
  };
  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      const i = idx(x, y);
      if (src[i + 3] > 16) {
        let r = src[i];
        let g = src[i + 1];
        let b = src[i + 2];
        const dither = ((x ^ y) & 1) === 0;
        if (dither && y < height * 0.4) {
          r = Math.min(255, r + 22);
          g = Math.min(255, g + 18);
          b = Math.min(255, b + 16);
        } else if (dither && y > height * 0.62) {
          r = Math.floor(r * 0.78);
          g = Math.floor(g * 0.78);
          b = Math.floor(b * 0.82);
        }
        data[i] = r;
        data[i + 1] = g;
        data[i + 2] = b;
        data[i + 3] = 255;
      } else if (solid(x - 1, y) || solid(x + 1, y) || solid(x, y - 1) || solid(x, y + 1)) {
        data[i] = rgb[0];
        data[i + 1] = rgb[1];
        data[i + 2] = rgb[2];
        data[i + 3] = 255;
      } else {
        data[i + 3] = 0;
      }
    }
  }
  ctx.putImageData(img, 0, 0);
}

function hexRgb(color: string): [number, number, number] {
  const n = Number.parseInt(color.replace('#', ''), 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}

function makeCanvas(width: number, height: number): HTMLCanvasElement {
  const canvas = document.createElement('canvas');
  canvas.width = width;
  canvas.height = height;
  return canvas;
}
