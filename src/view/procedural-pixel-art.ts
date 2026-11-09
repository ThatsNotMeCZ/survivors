import type { UiRect } from './sprite-types';

export type BiomeId = 'cinder' | 'rime';
export type EnvThemeId = 'cinder' | 'rime' | 'glacial';
export type VesselId = 'runner' | 'penitent';

const cache = new Map<string, HTMLCanvasElement>();
const VESSELS: VesselId[] = ['runner', 'penitent'];

export const OUTLINE: Record<BiomeId, string> = {
  cinder: '#120a0d',
  rime: '#08101a',
};

type PixelArtOpts = {
  /** Fill enclosed transparent pixels before outline so hall previews stay opaque. */
  seal?: string;
  dither?: boolean;
};

export function stageBiome(stageId: string): BiomeId {
  return stageId === 'rime-dock' || stageId === 'glacial-tomb' ? 'rime' : 'cinder';
}

export function stageEnvTheme(stageId: string): EnvThemeId {
  if (stageId === 'glacial-tomb') return 'glacial';
  if (stageId === 'rime-dock') return 'rime';
  return 'cinder';
}

export function cachedPixel(
  key: string,
  size: number,
  biome: BiomeId,
  draw: (px: PixelBuf) => void,
  opts?: PixelArtOpts,
): HTMLCanvasElement {
  const hit = cache.get(key);
  if (hit) return hit;
  const canvas = renderPixelArt(size, OUTLINE[biome], draw, opts);
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

export function resolveVessel(id: string): VesselId {
  return id === 'penitent' || id === 'consecrated' ? 'penitent' : 'runner';
}

export const PLAYER_WALK_DIRS = ['front', 'left', 'right', 'down', 'up'] as const;
export type PlayerFacing = (typeof PLAYER_WALK_DIRS)[number];
export type HorizontalFacing = 'left' | 'right';

export function playerIdleKey(vesselId = 'runner'): string {
  return `px-player-${resolveVessel(vesselId)}`;
}

export function moveFacing(moveX: number, moveY: number): PlayerFacing | null {
  if (moveX === 0 && moveY === 0) return null;
  if (Math.abs(moveX) >= Math.abs(moveY) && moveX !== 0) return moveX < 0 ? 'left' : 'right';
  return moveY < 0 ? 'up' : 'down';
}

export function spriteFacing(move: PlayerFacing | null, last: HorizontalFacing): HorizontalFacing {
  if (move === 'left' || move === 'right') return move;
  return last;
}
export function playerEyesKey(biome: BiomeId, vesselId = 'runner'): string {
  return `px-player-eyes-${resolveVessel(vesselId)}-${biome}`;
}
export function crosshairKey(vesselId = 'runner'): string {
  return `px-crosshair-${resolveVessel(vesselId)}`;
}
export const playerCrosshairKey = crosshairKey;
export function eliteGlyphKey(): string {
  return 'px-elite-glyph';
}

export function survivorPortrait(id: string): HTMLCanvasElement {
  return resolveVessel(id) === 'penitent' ? makePenitentPortrait() : makeHomunculusPortrait();
}

export function vesselIdleCanvas(id: string): HTMLCanvasElement {
  return makeIdleBody('cinder', resolveVessel(id));
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
export function floorKey(theme: EnvThemeId | BiomeId): string {
  return `px-floor-${theme}`;
}

export type PixelBuf = {
  size: number;
  fill: (x: number, y: number, w: number, h: number, color: string) => void;
  dot: (x: number, y: number, color: string) => void;
};

export function renderPixelArt(
  size: number,
  outline: string,
  draw: (px: PixelBuf) => void,
  opts?: PixelArtOpts,
): HTMLCanvasElement {
  const canvas = makeCanvas(size, size);
  const ctx = canvas.getContext('2d', { willReadFrequently: true });
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
  if (opts?.seal) fillInteriorHoles(ctx, size, size, opts.seal);
  outlinePass(ctx, size, size, outline, opts?.dither !== false);
  return canvas;
}

export type ProceduralSheet = {
  canvas: HTMLCanvasElement;
  frameWidth: number;
  frameHeight: number;
  anims: Record<string, { frames: number[]; frameRate: number; repeat: number }>;
};

export function generateProceduralSheets(): Map<string, ProceduralSheet> {
  const out = new Map<string, ProceduralSheet>();
  out.set('runner', singleFrame(makeIdleBody('cinder', 'runner')));
  out.set('penitent', singleFrame(makeIdleBody('cinder', 'penitent')));
  out.set(
    'ember-mite',
    miteSheet([makeMite('cinder', 0), makeMite('cinder', 1)], [makeMiteAttack('cinder')], 7),
  );
  out.set(
    'frost-mite',
    miteSheet([makeMite('rime', 0), makeMite('rime', 1)], [makeMiteAttack('rime')], 7),
  );
  out.set('ember-spitter', singleFrame(makeSpitter('cinder')));
  out.set('frost-spitter', singleFrame(makeSpitter('rime')));
  out.set('ember-chaser', singleFrame(makeElite('cinder')));
  out.set('frost-warden', singleFrame(makeElite('rime')));
  out.set('cinder-heart', singleFrame(makeCinderHeart()));
  out.set('frost-sovereign', singleFrame(makeFrostSovereign()));
  out.set('frost-emperor', singleFrame(makeFrostEmperor()));
  out.set('enemy-astral-sniper', singleFrame(makeAstralWatcher()));
  return out;
}

export function entityIdleCanvas(entityId: string): HTMLCanvasElement {
  switch (entityId) {
    case 'runner':
      return makeIdleBody('cinder', 'runner');
    case 'penitent':
      return makeIdleBody('cinder', 'penitent');
    case 'ember-mite':
      return makeMite('cinder', 0);
    case 'frost-mite':
      return makeMite('rime', 0);
    case 'ember-spitter':
      return makeSpitter('cinder');
    case 'frost-spitter':
      return makeSpitter('rime');
    case 'ember-chaser':
      return makeElite('cinder');
    case 'frost-warden':
      return makeElite('rime');
    case 'cinder-heart':
      return makeCinderHeart();
    case 'frost-sovereign':
      return makeFrostSovereign();
    case 'frost-emperor':
      return makeFrostEmperor();
    case 'enemy-astral-sniper':
      return makeAstralWatcher();
    default:
      return makeMite('cinder', 0);
  }
}

export function obstaclePreviewCanvas(
  kind: 'pillar' | 'hazard' | 'volatile',
  biome: BiomeId = 'cinder',
): HTMLCanvasElement {
  if (kind === 'pillar') return makePillar(biome);
  if (kind === 'hazard') return makeHazard(biome, 0);
  return makeVolatile(biome);
}

export function generateAllEntityCanvases(): Map<string, HTMLCanvasElement> {
  const out = new Map<string, HTMLCanvasElement>();
  const biomes: BiomeId[] = ['cinder', 'rime'];
  for (const biome of biomes) {
    for (const vessel of VESSELS) {
      put(out, playerEyesKey(biome, vessel), makePlayerEyes(biome, vessel));
    }
    put(out, pillarKey(biome), makePillar(biome));
    put(out, hazardKey(biome, 0), makeHazard(biome, 0));
    put(out, hazardKey(biome, 1), makeHazard(biome, 1));
    put(out, volatileKey(biome), makeVolatile(biome));
  }
  put(out, eliteGlyphKey(), makeEliteGlyph());
  put(out, 'px-bolt-player', makeBolt('#fff4c8', '#ffd35a', 'cinder'));
  put(out, 'px-bolt-enemy-cinder', makeBolt('#ffcc88', '#ff5522', 'cinder'));
  put(out, 'px-bolt-enemy-rime', makeBolt('#dff6ff', '#44ddff', 'rime'));
  put(out, 'px-gem', makeGem());
  put(out, 'px-lore', makeLoreScroll());
  put(out, 'px-spark', makeSpark());
  for (const vessel of VESSELS) {
    put(out, crosshairKey(vessel), makePlayerCrosshair(vessel));
  }
  put(out, 'px-crosshair', makePlayerCrosshair('runner'));
  put(out, 'px-waypoint', makeWaypoint());
  put(out, 'px-glow', makeGlow());
  put(out, 'px-player-halo', makePlayerHalo());
  put(out, 'px-ash', makeSpeck('#9a8a80', 2));
  put(out, 'px-ember', makeSpeck('#ff7722', 1));
  put(out, 'px-snow', makeSpeck('#d8eef8', 2));
  put(out, 'px-mist', makeSpeck('#1a3048', 3));
  return out;
}

export interface AtlasBorderFrames {
  h0?: UiRect;
  h1?: UiRect;
  v0?: UiRect;
  v1?: UiRect;
  cornerTop?: UiRect;
  cornerBottom?: UiRect;
}

function prepareCinderTileStamp(
  source: HTMLImageElement | HTMLCanvasElement,
  rect: UiRect,
): HTMLCanvasElement {
  const canvas = makeCanvas(rect.w, rect.h);
  const ctx = canvas.getContext('2d', { willReadFrequently: true });
  if (!ctx) return canvas;
  ctx.imageSmoothingEnabled = false;
  ctx.drawImage(source, rect.x, rect.y, rect.w, rect.h, 0, 0, rect.w, rect.h);
  const img = ctx.getImageData(0, 0, rect.w, rect.h);
  const { data } = img;
  for (let i = 0; i < data.length; i += 4) {
    if (data[i + 3] < 16) continue;
    let r = data[i];
    let g = data[i + 1];
    let b = data[i + 2];
    const isEmber = r > 110 && r > b * 1.65;
    if (isEmber) {
      // Tlumení jasných lávových žil v podlaze, aby nekonkurovaly oranžovým entitám
      r = Math.round(58 + (r - 58) * 0.68);
      g = Math.round(42 + (g - 42) * 0.65);
      b = Math.round(40 + (b - 40) * 0.75);
    } else {
      // Posun tmavého fialovo-uhlového kamene a černých spár do světlejšího popelavého odstínu
      r = Math.min(255, Math.round(44 + r * 0.72));
      g = Math.min(255, Math.round(35 + g * 0.70));
      b = Math.min(255, Math.round(38 + b * 0.70));
    }
    data[i] = r;
    data[i + 1] = g;
    data[i + 2] = b;
  }
  ctx.putImageData(img, 0, 0);
  return canvas;
}

export function resolveAtlasBorderFrames(
  theme: EnvThemeId | BiomeId,
  atlasFrames?: Record<string, UiRect>,
): AtlasBorderFrames | null {
  if (!atlasFrames) return null;
  const get = (key: string): UiRect | undefined => {
    let f = atlasFrames[`${theme}-${key}`];
    if ((!f || f.w === 0 || f.h === 0) && theme === 'glacial') {
      f = atlasFrames[`rime-${key}`];
    }
    return f && f.w > 0 && f.h > 0 ? f : undefined;
  };

  const legacyEdge = get('border-edge');
  const legacyCorner = get('border-corner');

  const h0 = get('border-h-0') ?? legacyEdge;
  const h1 = get('border-h-1') ?? h0;
  const v0 = get('border-v-0') ?? legacyEdge;
  const v1 = get('border-v-1') ?? v0;
  const cornerTop = get('border-corner-top') ?? legacyCorner;
  const cornerBottom = get('border-corner-bottom') ?? legacyCorner;

  if (!h0 && !h1 && !v0 && !v1 && !cornerTop && !cornerBottom) {
    return null;
  }
  return { h0, h1, v0, v1, cornerTop, cornerBottom };
}

export function generateFloor(
  theme: EnvThemeId | BiomeId,
  width: number,
  height: number,
  atlasSource?: HTMLImageElement | HTMLCanvasElement | null,
  atlasFrames?: Record<string, UiRect>,
): HTMLCanvasElement {
  const biome: BiomeId = theme === 'cinder' ? 'cinder' : 'rime';
  return cachedRaw(floorKey(theme), () => {
    const canvas = makeCanvas(width, height);
    const ctx = canvas.getContext('2d');
    if (!ctx) throw new Error('2d context missing');
    ctx.imageSmoothingEnabled = false;

    const tileRects: (UiRect | null)[] = [0, 1, 2, 3].map((v) => {
      if (!atlasFrames) return null;
      let frame = atlasFrames[`${theme}-tile-${v}`];
      if ((!frame || frame.w === 0 || frame.h === 0) && theme === 'glacial') frame = atlasFrames[`rime-tile-${v}`];
      if (!frame || frame.w === 0 || frame.h === 0) frame = atlasFrames[`${theme}-tile-0`];
      if ((!frame || frame.w === 0 || frame.h === 0) && theme === 'glacial') frame = atlasFrames['rime-tile-0'];
      return frame && frame.w > 0 && frame.h > 0 ? frame : null;
    });

    const runeRects: (UiRect | null)[] = [0, 1, 2, 3].map((v) => {
      if (!atlasFrames) return null;
      let frame = atlasFrames[`${theme}-tile-rune-${v}`];
      if ((!frame || frame.w === 0 || frame.h === 0) && theme === 'glacial') frame = atlasFrames[`rime-tile-rune-${v}`];
      if (!frame || frame.w === 0 || frame.h === 0) frame = atlasFrames[`${theme}-tile-rune-0`];
      if ((!frame || frame.w === 0 || frame.h === 0) && theme === 'glacial') frame = atlasFrames['rime-tile-rune-0'];
      return frame && frame.w > 0 && frame.h > 0 ? frame : null;
    });

    const hasAtlasTiles = !!atlasSource && tileRects.some((r) => r !== null);
    const tileStamps: (HTMLCanvasElement | null)[] = [0, 1, 2, 3].map((v) => {
      const r = tileRects[v];
      if (!hasAtlasTiles || !atlasSource || !r) return null;
      return theme === 'cinder' ? prepareCinderTileStamp(atlasSource, r) : null;
    });
    const runeStamps: (HTMLCanvasElement | null)[] = [0, 1, 2, 3].map((v) => {
      const r = runeRects[v];
      if (!hasAtlasTiles || !atlasSource || !r) return null;
      return theme === 'cinder' ? prepareCinderTileStamp(atlasSource, r) : null;
    });
    const baseTiles = [0, 1, 2, 3].map((v) => makeFloorTile(biome, v));
    const runeTiles = [0, 1, 2, 3].map((v) => makeRuneTile(biome, v));
    const tile = 64;
    const maxTx = Math.floor(width / tile);
    const maxTy = Math.floor(height / tile);
    const seed = theme === 'cinder' ? 1013 : theme === 'rime' ? 2027 : 3049;

    for (let ty = 0; ty < maxTy; ty += 1) {
      for (let tx = 0; tx < maxTx; tx += 1) {
        const isRune = isRuneCell(tx, ty, maxTx, maxTy, seed);
        if (isRune) {
          const rVar = runeTileVariant(tx, ty, seed);
          const rStamp = runeStamps[rVar] ?? runeStamps[0];
          const rRect = runeRects[rVar] ?? runeRects[0];
          if (rStamp) {
            ctx.drawImage(rStamp, 0, 0, rStamp.width, rStamp.height, tx * tile, ty * tile, tile, tile);
          } else if (hasAtlasTiles && atlasSource && rRect) {
            ctx.drawImage(atlasSource, rRect.x, rRect.y, rRect.w, rRect.h, tx * tile, ty * tile, tile, tile);
          } else if (hasAtlasTiles && atlasSource) {
            const bStamp = tileStamps[tileVariant(tx, ty, seed)] ?? tileStamps[0];
            const bRect = tileRects[tileVariant(tx, ty, seed)] ?? tileRects[0];
            if (bStamp) {
              ctx.drawImage(bStamp, 0, 0, bStamp.width, bStamp.height, tx * tile, ty * tile, tile, tile);
            } else if (bRect) {
              ctx.drawImage(atlasSource, bRect.x, bRect.y, bRect.w, bRect.h, tx * tile, ty * tile, tile, tile);
            } else {
              ctx.drawImage(runeTiles[rVar], tx * tile, ty * tile, tile, tile);
            }
          } else {
            ctx.drawImage(runeTiles[rVar], tx * tile, ty * tile, tile, tile);
          }
        } else {
          const bVar = tileVariant(tx, ty, seed);
          const bStamp = tileStamps[bVar] ?? tileStamps[0];
          const rect = tileRects[bVar] ?? tileRects[0];
          if (bStamp) {
            ctx.drawImage(bStamp, 0, 0, bStamp.width, bStamp.height, tx * tile, ty * tile, tile, tile);
          } else if (hasAtlasTiles && atlasSource && rect) {
            ctx.drawImage(atlasSource, rect.x, rect.y, rect.w, rect.h, tx * tile, ty * tile, tile, tile);
          } else {
            ctx.drawImage(baseTiles[bVar], tx * tile, ty * tile, tile, tile);
          }
        }
      }
    }

    const borders = resolveAtlasBorderFrames(theme, atlasFrames);
    if (atlasSource && borders) {
      drawAtlasBoundary(ctx, width, height, atlasSource, borders);
    } else {
      drawBoundary(ctx, width, height, biome);
    }
    return canvas;
  });
}

function drawAtlasBoundary(
  ctx: CanvasRenderingContext2D,
  width: number,
  height: number,
  source: HTMLImageElement | HTMLCanvasElement,
  borders: AtlasBorderFrames,
): void {
  const { h0, h1, v0, v1, cornerTop, cornerBottom } = borders;

  // 1. Horizontal top and bottom edges (mixing h0 and h1)
  const hPrimary = h0 ?? h1;
  if (hPrimary) {
    const edgeW = hPrimary.w;
    const edgeH = hPrimary.h;
    for (let x = 0; x < width; x += edgeW) {
      const drawW = Math.min(edgeW, width - x);
      // Top edge
      const topPick = ((x * 2654435761) >>> 0) % 2 === 0 ? (h0 ?? hPrimary) : (h1 ?? hPrimary);
      ctx.drawImage(source, topPick.x, topPick.y, drawW, edgeH, x, 0, drawW, edgeH);

      // Bottom edge
      const botPick = (((x + 1337) * 2654435761) >>> 0) % 2 === 0 ? (h0 ?? hPrimary) : (h1 ?? hPrimary);
      ctx.drawImage(source, botPick.x, botPick.y, drawW, edgeH, x, height - edgeH, drawW, edgeH);
    }
  }

  // 2. Vertical left and right edges (mixing v0 and v1)
  const vPrimary = v0 ?? v1 ?? hPrimary;
  if (vPrimary) {
    const edgeW = vPrimary.w;
    const edgeH = vPrimary.h;
    for (let y = 0; y < height; y += edgeH) {
      const drawH = Math.min(edgeH, height - y);
      // Left edge
      const leftPick = ((y * 1597334677) >>> 0) % 2 === 0 ? (v0 ?? vPrimary) : (v1 ?? vPrimary);
      ctx.drawImage(source, leftPick.x, leftPick.y, edgeW, drawH, 0, y, edgeW, drawH);

      // Right edge
      const rightPick = (((y + 7919) * 1597334677) >>> 0) % 2 === 0 ? (v0 ?? vPrimary) : (v1 ?? vPrimary);
      ctx.drawImage(source, rightPick.x, rightPick.y, edgeW, drawH, width - edgeW, y, edgeW, drawH);
    }
  }

  // 3. Corners
  // Top-Left & Top-Right (cornerTop)
  if (cornerTop && cornerTop.w > 0 && cornerTop.h > 0) {
    const cw = cornerTop.w;
    const ch = cornerTop.h;
    ctx.drawImage(source, cornerTop.x, cornerTop.y, cw, ch, 0, 0, cw, ch);
    ctx.save();
    ctx.translate(width, 0);
    ctx.scale(-1, 1);
    ctx.drawImage(source, cornerTop.x, cornerTop.y, cw, ch, 0, 0, cw, ch);
    ctx.restore();
  }

  // Bottom-Left & Bottom-Right (cornerBottom)
  if (cornerBottom && cornerBottom.w > 0 && cornerBottom.h > 0) {
    const cw = cornerBottom.w;
    const ch = cornerBottom.h;
    ctx.drawImage(source, cornerBottom.x, cornerBottom.y, cw, ch, 0, height - ch, cw, ch);
    ctx.save();
    ctx.translate(width, height - ch);
    ctx.scale(-1, 1);
    ctx.drawImage(source, cornerBottom.x, cornerBottom.y, cw, ch, 0, 0, cw, ch);
    ctx.restore();
  }
}

function put(out: Map<string, HTMLCanvasElement>, key: string, canvas: HTMLCanvasElement): void {
  cache.set(key, canvas);
  out.set(key, canvas);
}

function packRow(frames: HTMLCanvasElement[]): HTMLCanvasElement {
  const frameWidth = frames[0].width;
  const frameHeight = frames[0].height;
  const canvas = makeCanvas(frameWidth * frames.length, frameHeight);
  const ctx = canvas.getContext('2d');
  if (!ctx) throw new Error('2d context missing');
  ctx.imageSmoothingEnabled = false;
  frames.forEach((frame, i) => ctx.drawImage(frame, i * frameWidth, 0));
  return canvas;
}

function singleFrame(canvas: HTMLCanvasElement): ProceduralSheet {
  return {
    canvas,
    frameWidth: canvas.width,
    frameHeight: canvas.height,
    anims: { idle: { frames: [0], frameRate: 1, repeat: -1 } },
  };
}

export function walkSheet(frames: HTMLCanvasElement[], frameRate: number): ProceduralSheet {
  return {
    canvas: packRow(frames),
    frameWidth: frames[0].width,
    frameHeight: frames[0].height,
    anims: {
      idle: { frames: [0], frameRate: 1, repeat: -1 },
      walk: { frames: frames.map((_, i) => i), frameRate, repeat: -1 },
    },
  };
}

function miteSheet(
  walkFrames: HTMLCanvasElement[],
  attackFrames: HTMLCanvasElement[],
  frameRate: number,
): ProceduralSheet {
  const all = [...walkFrames, ...attackFrames];
  const walkIdx = walkFrames.map((_, i) => i);
  const atkIdx = attackFrames.map((_, i) => walkFrames.length + i);
  return {
    canvas: packRow(all),
    frameWidth: all[0].width,
    frameHeight: all[0].height,
    anims: {
      idle: { frames: [0], frameRate: 1, repeat: -1 },
      walk: { frames: walkIdx, frameRate, repeat: -1 },
      attack: { frames: atkIdx, frameRate: frameRate * 1.5, repeat: 0 },
    },
  };
}

function makeIdleBody(biome: BiomeId, vessel: VesselId): HTMLCanvasElement {
  return cachedPixel(playerIdleKey(vessel), 32, biome, (px) => {
    if (vessel === 'penitent') drawPenitentBody(px, biome);
    else drawHomunculusBody(px, biome);
  });
}

function makePlayerEyes(biome: BiomeId, vessel: VesselId): HTMLCanvasElement {
  const glow = vessel === 'penitent' ? (biome === 'rime' ? '#ffe8a0' : '#ffdd66') : biome === 'cinder' ? '#b8fff8' : '#77ffff';
  return cachedPixel(playerEyesKey(biome, vessel), 8, biome, (px) => {
    px.fill(1, 3, 2, 1, glow);
    px.fill(5, 3, 2, 1, glow);
  });
}

function drawHomunculusBody(px: PixelBuf, biome: BiomeId, step = 0): void {
  const trim = biome === 'cinder' ? '#c94a4a' : '#5ad4ff';
  px.fill(10, 6, 12, 4, '#3a3244');
  px.fill(8, 8, 16, 5, '#52465c');
  px.fill(7, 12, 18, 14, '#2a2430');
  px.fill(8, 24, 16, 3, '#2a2430');
  px.fill(9 + step, 26, 5, 4, '#2a2430');
  px.fill(18 - step, 26, 5, 4, '#2a2430');
  px.fill(8, 12, 16, 2, trim);
  px.fill(11, 4, 10, 5, '#1c1822');
  px.fill(12, 3, 8, 3, '#1c1822');
}

function drawPenitentBody(px: PixelBuf, biome: BiomeId, step = 0): void {
  const sash = biome === 'cinder' ? '#c4783a' : '#88d0e8';
  const robe = biome === 'cinder' ? '#3a2418' : '#243040';
  const hood = biome === 'cinder' ? '#2a1810' : '#1a2430';
  px.fill(8, 4, 16, 6, hood);
  px.fill(6, 10, 20, 16, robe);
  px.fill(8, 24, 16, 6, hood);
  px.fill(12, 6, 8, 5, '#1a100c');
  px.fill(7, 8, 18, 3, biome === 'cinder' ? '#8a6a32' : '#6a8898');
  px.fill(10, 12, 12, 3, sash);
  px.fill(14, 18, 4, 6, biome === 'cinder' ? '#5c4520' : '#3a5060');
  px.fill(9 + step, 26, 5, 4, hood);
  px.fill(18 - step, 26, 5, 4, hood);
}

function makeMite(biome: BiomeId, frame: 0 | 1): HTMLCanvasElement {
  const core = biome === 'cinder' ? '#ff5522' : '#44ddff';
  const shell = biome === 'cinder' ? '#5a2018' : '#1a3a52';
  const jag = biome === 'cinder' ? '#3a1410' : '#0e2438';
  return cachedPixel(`px-mite-${biome}-${frame}`, 24, biome, (px) => {
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

function makeMiteAttack(biome: BiomeId): HTMLCanvasElement {
  const core = biome === 'cinder' ? '#ffffff' : '#e0ffff';
  const shell = biome === 'cinder' ? '#7a2b20' : '#225070';
  const jag = biome === 'cinder' ? '#ff3311' : '#00ffff';
  return cachedPixel(`px-mite-atk-${biome}`, 24, biome, (px) => {
    px.fill(3, 7, 18, 11, shell);
    px.fill(5, 5, 14, 5, shell);
    px.fill(7, 9, 10, 8, core);
    px.fill(9, 11, 6, 4, '#fff8e0');
    px.fill(1, 6, 5, 4, jag);
    px.fill(18, 6, 5, 4, jag);
    px.fill(2, 16, 4, 4, jag);
    px.fill(18, 16, 4, 4, jag);
  });
}

function makeSpitter(biome: BiomeId): HTMLCanvasElement {
  const body = biome === 'cinder' ? '#4a2818' : '#163044';
  const maw = biome === 'cinder' ? '#ff7a3a' : '#7ad4ff';
  return cachedPixel(`px-spitter-${biome}`, 28, biome, (px) => {
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
  return cachedPixel(`px-elite-${biome}`, 40, biome, (px) => {
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
    const c = '#ffffff'; // White so tinting works properly
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

function makeHomunculusPortrait(): HTMLCanvasElement {
  return cachedPixel(
    'px-portrait-runner',
    32,
    'rime',
    (px) => {
      drawHomunculusBody(px, 'rime');
      px.fill(13, 9, 2, 2, '#77ffff');
      px.fill(17, 9, 2, 2, '#77ffff');
      px.fill(12, 16, 8, 6, '#3a90b8');
    },
    { seal: '#2a2430', dither: false },
  );
}

function makePenitentPortrait(): HTMLCanvasElement {
  return cachedPixel(
    'px-portrait-penitent',
    32,
    'cinder',
    (px) => {
      drawPenitentBody(px, 'cinder');
      px.fill(13, 14, 2, 2, '#ffdd66');
      px.fill(17, 14, 2, 2, '#ffdd66');
    },
    { seal: '#3a2418', dither: false },
  );
}

function makeCinderHeart(): HTMLCanvasElement {
  return cachedPixel('px-boss-cinder-heart', 64, 'cinder', (px) => {
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
  return cachedPixel('px-boss-frost-sovereign', 64, 'rime', (px) => {
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

function makeFrostEmperor(): HTMLCanvasElement {
  return cachedPixel('px-boss-frost-emperor', 64, 'rime', (px) => {
    px.fill(18, 14, 28, 40, '#102238');
    px.fill(14, 20, 36, 28, '#183654');
    px.fill(16, 6, 32, 12, '#3d8ad4');
    px.fill(12, 4, 6, 14, '#dff6ff');
    px.fill(46, 4, 6, 14, '#dff6ff');
    px.fill(22, 2, 6, 10, '#ffffff');
    px.fill(36, 2, 6, 10, '#ffffff');
    px.fill(29, 1, 6, 12, '#77ffff');
    px.fill(26, 24, 12, 14, '#77ffff');
    px.fill(29, 27, 6, 8, '#ffffff');
    px.fill(10, 26, 8, 4, '#7ad4ff');
    px.fill(46, 26, 8, 4, '#7ad4ff');
  });
}

function makeAstralWatcher(): HTMLCanvasElement {
  return cachedPixel('px-astral-watcher', 28, 'rime', (px) => {
    px.fill(8, 8, 12, 12, '#2a1844');
    px.fill(6, 10, 16, 8, '#4a2878');
    px.fill(10, 6, 8, 16, '#4a2878');
    px.fill(10, 10, 8, 8, '#b47aff');
    px.fill(12, 12, 4, 4, '#f0e8ff');
    px.fill(13, 13, 2, 2, '#44ddff');
    px.fill(4, 13, 3, 2, '#c4a35a');
    px.fill(21, 13, 3, 2, '#c4a35a');
    px.fill(13, 3, 2, 3, '#c4a35a');
    px.fill(13, 22, 2, 3, '#c4a35a');
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
    px.fill(6, 2, 4, 12, '#4aa0d4');
    px.fill(4, 4, 8, 8, '#ffffff');
    px.fill(7, 6, 2, 4, '#88ddff');
  });
}

function makeLoreScroll(): HTMLCanvasElement {
  return cachedPixel('px-lore', 16, 'cinder', (px) => {
    // Wooden/brass scroll rollers top & bottom
    px.fill(2, 2, 12, 2, '#c49a45');
    px.fill(2, 12, 12, 2, '#c49a45');
    // Aged parchment body
    px.fill(3, 4, 10, 8, '#e8d8b8');
    px.fill(4, 5, 8, 6, '#f6ebd4');
    // Dark ink lines
    px.fill(5, 5, 6, 1, '#4a3423');
    px.fill(5, 7, 4, 1, '#4a3423');
    // Crimson wax seal with gold highlight
    px.fill(6, 8, 4, 3, '#c93b3b');
    px.fill(7, 9, 2, 1, '#ffd35a');
  });
}

function makeSpark(): HTMLCanvasElement {
  return cachedPixel('px-spark', 8, 'cinder', (px) => {
    px.fill(3, 2, 2, 4, '#ffffff');
    px.fill(2, 3, 4, 2, '#ffd35a');
  });
}

function makeHomunculusCrosshair(): HTMLCanvasElement {
  return cachedPixel('px-crosshair-runner', 16, 'cinder', (px) => {
    // Top tine
    px.fill(7, 1, 2, 3, '#5ad4ff');
    px.fill(7, 4, 2, 1, '#ffffff');
    // Bottom tine
    px.fill(7, 11, 2, 1, '#ffffff');
    px.fill(7, 12, 2, 3, '#5ad4ff');
    // Left tine
    px.fill(1, 7, 3, 2, '#5ad4ff');
    px.fill(4, 7, 1, 2, '#ffffff');
    // Right tine
    px.fill(11, 7, 1, 2, '#ffffff');
    px.fill(12, 7, 3, 2, '#5ad4ff');
    // Precision corner ticks
    px.dot(3, 3, '#dff6ff');
    px.dot(12, 3, '#dff6ff');
    px.dot(3, 12, '#dff6ff');
    px.dot(12, 12, '#dff6ff');
  });
}

function makePenitentCrosshair(): HTMLCanvasElement {
  return cachedPixel('px-crosshair-penitent', 16, 'cinder', (px) => {
    // Cardinal flame tips
    px.fill(7, 1, 2, 2, '#ffe8a0');
    px.fill(7, 13, 2, 2, '#ffe8a0');
    px.fill(1, 7, 2, 2, '#ffe8a0');
    px.fill(13, 7, 2, 2, '#ffe8a0');
    // Consecrated ring
    px.fill(6, 3, 4, 1, '#c4783a');
    px.fill(6, 12, 4, 1, '#c4783a');
    px.fill(3, 6, 1, 4, '#c4783a');
    px.fill(12, 6, 1, 4, '#c4783a');
    // Diagonal ring corners
    px.dot(4, 4, '#c4783a');
    px.dot(11, 4, '#c4783a');
    px.dot(4, 11, '#c4783a');
    px.dot(11, 11, '#c4783a');
    // Center consecrated ember
    px.fill(7, 7, 2, 2, '#fff4c8');
  });
}

function makePlayerCrosshair(vessel: string): HTMLCanvasElement {
  const resolved = resolveVessel(vessel);
  if (resolved === 'penitent') return makePenitentCrosshair();
  return makeHomunculusCrosshair();
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

function makePlayerHalo(): HTMLCanvasElement {
  const canvas = makeCanvas(48, 48);
  const ctx = canvas.getContext('2d');
  if (!ctx) throw new Error('2d context missing');
  const g = ctx.createRadialGradient(24, 24, 2, 24, 24, 23);
  g.addColorStop(0, 'rgba(255, 244, 200, 0.95)');
  g.addColorStop(0.35, 'rgba(255, 215, 120, 0.65)');
  g.addColorStop(0.70, 'rgba(255, 160, 60, 0.30)');
  g.addColorStop(1, 'rgba(255, 120, 30, 0)');
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, 48, 48);
  cache.set('px-player-halo', canvas);
  return canvas;
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
      ? ['#3c3034', '#46383c', '#342a2d', '#4a3c40']
      : ['#0e1722', '#121e2b', '#0a111a', '#162030'];
  const mark = biome === 'cinder' ? '#78523c' : '#3a5a70';
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

function makeRuneTile(biome: BiomeId, variant: number): HTMLCanvasElement {
  const key = `px-tile-rune-${biome}-${variant}`;
  const pal =
    biome === 'cinder'
      ? ['#1c1113', '#231517', '#170d0f', '#2a1814']
      : ['#0e1722', '#121e2b', '#0a111a', '#162030'];
  const glow = biome === 'cinder' ? '#ff9933' : '#55ffff';
  const runeBase = biome === 'cinder' ? '#b44a24' : '#2888aa';
  return cachedPixel(key, 64, biome, (px) => {
    px.fill(0, 0, 64, 64, pal[variant % 3]);
    px.fill(2, 2, 28, 28, pal[(variant + 1) % 3]);
    px.fill(34, 6, 26, 22, pal[(variant + 2) % 3]);
    px.fill(8, 36, 40, 20, pal[variant % 3]);
    // Inner circular recess for the rune engraving
    px.fill(20, 20, 24, 24, '#100a0d');
    px.fill(22, 22, 20, 20, pal[(variant + 1) % 3]);

    if (variant === 0) {
      // Hexagram / Star shard
      px.fill(26, 31, 12, 2, runeBase);
      px.fill(31, 26, 2, 12, runeBase);
      px.dot(31, 31, glow);
      px.dot(32, 32, glow);
      px.dot(26, 31, glow);
      px.dot(37, 31, glow);
    } else if (variant === 1) {
      // Flame / Alchemical sulfur triangle
      px.fill(28, 26, 8, 2, runeBase);
      px.fill(26, 28, 2, 8, runeBase);
      px.fill(36, 28, 2, 8, runeBase);
      px.fill(28, 36, 8, 2, runeBase);
      px.fill(31, 24, 2, 16, glow);
    } else if (variant === 2) {
      // Sol / Circular seal with eye
      px.fill(26, 26, 12, 2, runeBase);
      px.fill(26, 36, 12, 2, runeBase);
      px.fill(24, 28, 2, 8, runeBase);
      px.fill(38, 28, 2, 8, runeBase);
      px.fill(30, 30, 4, 4, glow);
    } else {
      // Dual crescent / crucible rune
      px.fill(27, 25, 10, 2, runeBase);
      px.fill(27, 37, 10, 2, runeBase);
      px.fill(25, 27, 2, 10, glow);
      px.fill(37, 27, 2, 10, glow);
      px.dot(31, 31, glow);
    }
  });
}

function hash2d(x: number, y: number, seed = 1337): number {
  let h = (seed + Math.imul(x, 0x9e3779b1) + Math.imul(y, 0x85ebca77)) >>> 0;
  h = Math.imul(h ^ (h >>> 16), 0x85ebca6b);
  h = Math.imul(h ^ (h >>> 13), 0xc2b2ae35);
  return (h ^ (h >>> 16)) >>> 0;
}

function patchNoise(tx: number, ty: number, seed = 42): number {
  const fx = tx * 0.12;
  const fy = ty * 0.12;
  const ix = Math.floor(fx);
  const iy = Math.floor(fy);
  const sx = fx - ix;
  const sy = fy - iy;
  const ux = sx * sx * (3 - 2 * sx);
  const uy = sy * sy * (3 - 2 * sy);

  const n00 = (hash2d(ix, iy, seed) & 0xffff) / 0xffff;
  const n10 = (hash2d(ix + 1, iy, seed) & 0xffff) / 0xffff;
  const n01 = (hash2d(ix, iy + 1, seed) & 0xffff) / 0xffff;
  const n11 = (hash2d(ix + 1, iy + 1, seed) & 0xffff) / 0xffff;

  const nx0 = n00 * (1 - ux) + n10 * ux;
  const nx1 = n01 * (1 - ux) + n11 * ux;
  return nx0 * (1 - uy) + nx1 * uy;
}

export function isRuneCell(tx: number, ty: number, maxTx: number, maxTy: number, seed = 1337): boolean {
  if (tx <= 1 || ty <= 1 || tx >= maxTx - 2 || ty >= maxTy - 2) return false;
  const selfH = hash2d(tx, ty, seed + 8888);
  // Rare candidate threshold (~3.9% of cells)
  if (selfH < 0xf6000000) return false;

  // Local peak in Chebyshev neighborhood (distance <= 2) to ensure runes are isolated and well-spaced
  for (let dy = -2; dy <= 2; dy++) {
    for (let dx = -2; dx <= 2; dx++) {
      if (dx === 0 && dy === 0) continue;
      if (hash2d(tx + dx, ty + dy, seed + 8888) >= selfH) {
        return false;
      }
    }
  }
  return true;
}

export function runeTileVariant(tx: number, ty: number, seed = 1337): number {
  return (hash2d(tx, ty, seed + 4444) >>> 16) & 3;
}

export function tileVariant(tx: number, ty: number, seed = 1337): number {
  const patch = patchNoise(tx, ty, seed + 101);
  const micro = (hash2d(tx, ty, seed + 202) & 0xffff) / 0xffff;

  // Dominant base paver (variant 0), with natural organic patches of wear and ash (variant 2)
  // Variant 1 (cracked lava) is kept as a rare accent (~11%) so it does not compete with enemy silhouettes
  if (patch > 0.70) {
    if (micro < 0.35) return 1;
    if (micro < 0.80) return 2;
    return 0;
  }
  if (patch < 0.25) {
    if (micro < 0.75) return 2;
    if (micro < 0.90) return 1;
    return 0;
  }
  if (micro < 0.76) return 0;
  if (micro < 0.87) return 2;
  if (micro < 0.95) return 1;
  return 3;
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

function fillInteriorHoles(
  ctx: CanvasRenderingContext2D,
  width: number,
  height: number,
  fill: string,
): void {
  const img = ctx.getImageData(0, 0, width, height);
  const { data } = img;
  const exterior = new Uint8Array(width * height);
  const stack: number[] = [];
  const push = (x: number, y: number) => {
    if (x < 0 || y < 0 || x >= width || y >= height) return;
    const p = y * width + x;
    if (exterior[p] === 1) return;
    if (data[p * 4 + 3] > 16) return;
    exterior[p] = 1;
    stack.push(p);
  };
  for (let x = 0; x < width; x += 1) {
    push(x, 0);
    push(x, height - 1);
  }
  for (let y = 0; y < height; y += 1) {
    push(0, y);
    push(width - 1, y);
  }
  while (stack.length > 0) {
    const p = stack.pop() ?? 0;
    const x = p % width;
    const y = (p / width) | 0;
    push(x - 1, y);
    push(x + 1, y);
    push(x, y - 1);
    push(x, y + 1);
  }
  const rgb = hexRgb(fill);
  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      const p = y * width + x;
      if (exterior[p] === 1) continue;
      const i = p * 4;
      if (data[i + 3] > 16) continue;
      data[i] = rgb[0];
      data[i + 1] = rgb[1];
      data[i + 2] = rgb[2];
      data[i + 3] = 255;
    }
  }
  ctx.putImageData(img, 0, 0);
}

function outlinePass(
  ctx: CanvasRenderingContext2D,
  width: number,
  height: number,
  outline: string,
  dither = true,
): void {
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
        const checker = dither && ((x ^ y) & 1) === 0;
        if (checker && y < height * 0.4) {
          r = Math.min(255, r + 22);
          g = Math.min(255, g + 18);
          b = Math.min(255, b + 16);
        } else if (checker && y > height * 0.62) {
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
  if (typeof document !== 'undefined') {
    const canvas = document.createElement('canvas');
    canvas.width = width;
    canvas.height = height;
    return canvas;
  }
  const mockCtx = new Proxy(
    {
      createImageData: () => ({ data: new Uint8ClampedArray(width * height * 4) }),
      getImageData: () => ({ data: new Uint8ClampedArray(width * height * 4) }),
    },
    {
      get: (target, prop) => (prop in target ? (target as any)[prop] : () => {}),
      set: () => true,
    },
  );
  return {
    width,
    height,
    getContext: () => mockCtx,
  } as unknown as HTMLCanvasElement;
}
