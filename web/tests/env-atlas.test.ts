import { describe, expect, it } from 'bun:test';
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { writeSpriteManifest } from '../scripts/sprite-manifest';
import {
  floorKey,
  isRuneCell,
  resolveAtlasBorderFrames,
  runeTileVariant,
  stageBiome,
  stageEnvTheme,
  tileVariant,
} from '../src/view/procedural-pixel-art';
import {
  applyEnvAtlasJson,
  applySpriteManifest,
  getEnvAtlasDef,
  getEnvFrame,
  hasEnvTexture,
  resolveEnvThemeProp,
} from '../src/view/sprites';

describe('Environment Atlas & Mapping', () => {
  it('public/sprites/env/atlas.json contains all required pre-filled keys with valid dimensions', () => {
    const raw = JSON.parse(readFileSync(join(process.cwd(), 'public/sprites/env/atlas.json'), 'utf8'));
    expect(raw.frames).toBeDefined();

    const expectedKeys = [
      // Cinder
      'cinder-tile-0', 'cinder-tile-1', 'cinder-tile-2', 'cinder-tile-3',
      'cinder-tile-rune-0', 'cinder-tile-rune-1', 'cinder-tile-rune-2', 'cinder-tile-rune-3',
      'cinder-border-h-0', 'cinder-border-h-1',
      'cinder-border-v-0', 'cinder-border-v-1',
      'cinder-border-corner-top', 'cinder-border-corner-bottom',
      'cinder-pillar', 'cinder-hazard-0', 'cinder-hazard-1',
      'cinder-volatile', 'cinder-circle', 'cinder-portal',

      // Rime
      'rime-tile-0', 'rime-tile-1', 'rime-tile-2', 'rime-tile-3',
      'rime-tile-rune-0', 'rime-tile-rune-1', 'rime-tile-rune-2', 'rime-tile-rune-3',
      'rime-border-h-0', 'rime-border-h-1',
      'rime-border-v-0', 'rime-border-v-1',
      'rime-border-corner-top', 'rime-border-corner-bottom',
      'rime-pillar', 'rime-hazard-0', 'rime-hazard-1',
      'rime-volatile', 'rime-circle', 'rime-portal',

      // Glacial
      'glacial-tile-0', 'glacial-tile-1', 'glacial-tile-2', 'glacial-tile-3',
      'glacial-tile-rune-0', 'glacial-tile-rune-1', 'glacial-tile-rune-2', 'glacial-tile-rune-3',
      'glacial-border-h-0', 'glacial-border-h-1',
      'glacial-border-v-0', 'glacial-border-v-1',
      'glacial-border-corner-top', 'glacial-border-corner-bottom',
      'glacial-pillar', 'glacial-hazard-0', 'glacial-hazard-1',
      'glacial-volatile', 'glacial-circle', 'glacial-portal',

      // Ambient
      'ambient-ash', 'ambient-ember', 'ambient-snow', 'ambient-mist',
    ];

    for (const key of expectedKeys) {
      const frame = raw.frames[key];
      expect(frame).toBeDefined();
      expect(typeof frame.x).toBe('number');
      expect(typeof frame.y).toBe('number');
      expect(typeof frame.w).toBe('number');
      expect(typeof frame.h).toBe('number');
      expect(frame.x).toBeGreaterThanOrEqual(0);
      expect(frame.y).toBeGreaterThanOrEqual(0);
      expect(frame.w).toBeGreaterThanOrEqual(0);
      expect(frame.h).toBeGreaterThanOrEqual(0);
    }
  });

  it('resolveAtlasBorderFrames resolves 6-piece borders, variations, and fallbacks', () => {
    // 1. Full 6-piece setup
    const fullFrames = {
      'cinder-border-h-0': { x: 0, y: 0, w: 64, h: 16 },
      'cinder-border-h-1': { x: 64, y: 0, w: 64, h: 16 },
      'cinder-border-v-0': { x: 128, y: 0, w: 16, h: 64 },
      'cinder-border-v-1': { x: 144, y: 0, w: 16, h: 64 },
      'cinder-border-corner-top': { x: 160, y: 0, w: 32, h: 32 },
      'cinder-border-corner-bottom': { x: 192, y: 0, w: 32, h: 32 },
    };
    const resolvedFull = resolveAtlasBorderFrames('cinder', fullFrames);
    expect(resolvedFull).toBeDefined();
    expect(resolvedFull?.h0).toEqual({ x: 0, y: 0, w: 64, h: 16 });
    expect(resolvedFull?.h1).toEqual({ x: 64, y: 0, w: 64, h: 16 });
    expect(resolvedFull?.v0).toEqual({ x: 128, y: 0, w: 16, h: 64 });
    expect(resolvedFull?.v1).toEqual({ x: 144, y: 0, w: 16, h: 64 });
    expect(resolvedFull?.cornerTop).toEqual({ x: 160, y: 0, w: 32, h: 32 });
    expect(resolvedFull?.cornerBottom).toEqual({ x: 192, y: 0, w: 32, h: 32 });

    // 2. Partial variation fallback: h1 and v1 omitted -> fallback to h0 and v0
    const partialFrames = {
      'cinder-border-h-0': { x: 0, y: 0, w: 64, h: 16 },
      'cinder-border-v-0': { x: 128, y: 0, w: 16, h: 64 },
      'cinder-border-corner-top': { x: 160, y: 0, w: 32, h: 32 },
    };
    const resolvedPartial = resolveAtlasBorderFrames('cinder', partialFrames);
    expect(resolvedPartial?.h0).toEqual({ x: 0, y: 0, w: 64, h: 16 });
    expect(resolvedPartial?.h1).toEqual({ x: 0, y: 0, w: 64, h: 16 });
    expect(resolvedPartial?.v0).toEqual({ x: 128, y: 0, w: 16, h: 64 });
    expect(resolvedPartial?.v1).toEqual({ x: 128, y: 0, w: 16, h: 64 });
    expect(resolvedPartial?.cornerTop).toEqual({ x: 160, y: 0, w: 32, h: 32 });
    expect(resolvedPartial?.cornerBottom).toBeUndefined();

    // 3. Glacial fallback to Rime borders
    const rimeFrames = {
      'rime-border-h-0': { x: 10, y: 10, w: 64, h: 16 },
      'rime-border-corner-bottom': { x: 50, y: 50, w: 32, h: 32 },
    };
    const resolvedGlacial = resolveAtlasBorderFrames('glacial', rimeFrames);
    expect(resolvedGlacial?.h0).toEqual({ x: 10, y: 10, w: 64, h: 16 });
    expect(resolvedGlacial?.h1).toEqual({ x: 10, y: 10, w: 64, h: 16 });
    expect(resolvedGlacial?.cornerBottom).toEqual({ x: 50, y: 50, w: 32, h: 32 });

    // 4. Legacy edge and corner fallback
    const legacyFrames = {
      'cinder-border-edge': { x: 5, y: 5, w: 64, h: 16 },
      'cinder-border-corner': { x: 20, y: 20, w: 16, h: 16 },
    };
    const resolvedLegacy = resolveAtlasBorderFrames('cinder', legacyFrames);
    expect(resolvedLegacy?.h0).toEqual({ x: 5, y: 5, w: 64, h: 16 });
    expect(resolvedLegacy?.h1).toEqual({ x: 5, y: 5, w: 64, h: 16 });
    expect(resolvedLegacy?.v0).toEqual({ x: 5, y: 5, w: 64, h: 16 });
    expect(resolvedLegacy?.v1).toEqual({ x: 5, y: 5, w: 64, h: 16 });
    expect(resolvedLegacy?.cornerTop).toEqual({ x: 20, y: 20, w: 16, h: 16 });
    expect(resolvedLegacy?.cornerBottom).toEqual({ x: 20, y: 20, w: 16, h: 16 });

    // 5. Completely empty or undefined returns null
    expect(resolveAtlasBorderFrames('cinder', undefined)).toBeNull();
    expect(resolveAtlasBorderFrames('cinder', {})).toBeNull();
  });

  it('writeSpriteManifest does not crash and safely handles atlas', () => {
    const path = writeSpriteManifest();
    expect(path).toBeDefined();
    const manifest = JSON.parse(readFileSync(path, 'utf8'));
    if (existsSync('public/sprites/env/atlas.png')) {
      expect(manifest.envAtlas).toBeDefined();
      expect(manifest.envAtlas.src).toBe('sprites/env/atlas.png');
    } else {
      expect(manifest.envAtlas).toBeUndefined();
    }
  });

  it('stageBiome and stageEnvTheme map correctly for all stages', () => {
    expect(stageBiome('cinder-yard')).toBe('cinder');
    expect(stageEnvTheme('cinder-yard')).toBe('cinder');

    expect(stageBiome('rime-dock')).toBe('rime');
    expect(stageEnvTheme('rime-dock')).toBe('rime');

    expect(stageBiome('glacial-tomb')).toBe('rime');
    expect(stageEnvTheme('glacial-tomb')).toBe('glacial');

    expect(floorKey('cinder')).toBe('px-floor-cinder');
    expect(floorKey('rime')).toBe('px-floor-rime');
    expect(floorKey('glacial')).toBe('px-floor-glacial');
  });

  it('manifest parsing registers envAtlas and filters zero-sized frames', () => {
    const mockManifest = {
      entities: {},
      items: [],
      skills: [],
      env: [],
      fx: [],
      envAtlas: {
        src: 'sprites/env/atlas.png',
        width: 1024,
        height: 1024,
        frames: {
          'cinder-pillar': { x: 10, y: 10, w: 64, h: 64 },
          'rime-pillar': { x: 80, y: 10, w: 64, h: 64 },
          'empty-slot': { x: 0, y: 0, w: 0, h: 0 },
        },
      },
    };

    applySpriteManifest(mockManifest);
    const atlasDef = getEnvAtlasDef();
    expect(atlasDef).toBeDefined();
    expect(atlasDef?.frames['cinder-pillar']).toEqual({ x: 10, y: 10, w: 64, h: 64 });
    expect(atlasDef?.frames['rime-pillar']).toEqual({ x: 80, y: 10, w: 64, h: 64 });
    expect(atlasDef?.frames['empty-slot']).toBeUndefined();
    expect(getEnvFrame('cinder-pillar')).toEqual({ x: 10, y: 10, w: 64, h: 64 });
  });

  it('resolveEnvThemeProp resolves direct key or falls back to rime for glacial', () => {
    // Mock scene with dummy textures manager
    const fakeScene = {
      textures: {
        exists: (key: string) => key === 'env-atlas',
        get: () => ({
          has: (frame: string) => frame === 'cinder-pillar' || frame === 'rime-pillar',
        }),
      },
    } as any;

    applySpriteManifest({
      entities: {},
      items: [],
      skills: [],
      env: [],
      fx: [],
      envAtlas: {
        src: 'sprites/env/atlas.png',
        width: 512,
        height: 512,
        frames: {
          'cinder-pillar': { x: 0, y: 0, w: 64, h: 64 },
          'rime-pillar': { x: 64, y: 0, w: 64, h: 64 },
        },
      },
    });

    expect(resolveEnvThemeProp('cinder', 'pillar', fakeScene)).toBe('cinder-pillar');
    expect(resolveEnvThemeProp('rime', 'pillar', fakeScene)).toBe('rime-pillar');
    // Glacial has no glacial-pillar in atlas -> falls back to rime-pillar!
    expect(resolveEnvThemeProp('glacial', 'pillar', fakeScene)).toBe('rime-pillar');
    // Volatiles are not in atlas -> null (uses procedural fallback)
    expect(resolveEnvThemeProp('cinder', 'volatile', fakeScene)).toBeNull();
    expect(resolveEnvThemeProp('glacial', 'volatile', fakeScene)).toBeNull();
  });

  it('tileVariant and isRuneCell generate rare runes and non-periodic organic patterns', () => {
    const maxTx = 40;
    const maxTy = 40;
    const totalTiles = maxTx * maxTy;
    let runeCount = 0;
    const runeCoords: [number, number][] = [];

    for (let ty = 0; ty < maxTy; ty++) {
      for (let tx = 0; tx < maxTx; tx++) {
        const isRune = isRuneCell(tx, ty, maxTx, maxTy, 1013);
        if (isRune) {
          runeCount++;
          runeCoords.push([tx, ty]);
          // Must not spawn directly on border edges
          expect(tx).toBeGreaterThan(1);
          expect(ty).toBeGreaterThan(1);
          expect(tx).toBeLessThan(maxTx - 2);
          expect(ty).toBeLessThan(maxTy - 2);

          const rVar = runeTileVariant(tx, ty, 1013);
          expect(rVar).toBeGreaterThanOrEqual(0);
          expect(rVar).toBeLessThanOrEqual(3);
        }
      }
    }

    // Runes should be truly rare: ~1.5% to 3% of tiles (around 20 to 45 across 1600 tiles)
    const runeDensity = runeCount / totalTiles;
    expect(runeDensity).toBeGreaterThan(0.01);
    expect(runeDensity).toBeLessThan(0.035);

    // No two runes should be adjacent (Chebyshev distance >= 2)
    for (let i = 0; i < runeCoords.length; i++) {
      for (let j = i + 1; j < runeCoords.length; j++) {
        const [x1, y1] = runeCoords[i];
        const [x2, y2] = runeCoords[j];
        const dist = Math.max(Math.abs(x1 - x2), Math.abs(y1 - y2));
        expect(dist).toBeGreaterThanOrEqual(2);
      }
    }

    // Base tiles: verify non-periodicity (unlike old 4x4 or 8x8 repeating patterns)
    const row0 = Array.from({ length: 16 }, (_, x) => tileVariant(x, 5, 1013));
    const block1 = row0.slice(0, 4);
    const block2 = row0.slice(4, 8);
    const block3 = row0.slice(8, 12);
    // Blocks should NOT be identical repetitions
    const periodic4 = block1.every((v, idx) => v === block2[idx] && v === block3[idx]);
    expect(periodic4).toBe(false);
  });

  it('cinder-pillar and rime-pillar have authored dimensions in atlas.json and manifest.json', () => {
    const raw = JSON.parse(readFileSync(join(process.cwd(), 'public/sprites/env/atlas.json'), 'utf8'));
    expect(raw.frames['cinder-pillar']).toEqual({ x: 485, y: 5, w: 58, h: 104 });
    expect(raw.frames['rime-pillar'].w).toBe(56);
    expect(raw.frames['rime-pillar'].h).toBe(104);

    const manifestRaw = JSON.parse(readFileSync(join(process.cwd(), 'public/sprites/manifest.json'), 'utf8'));
    expect(manifestRaw.envAtlas.frames['cinder-pillar']).toEqual({ x: 485, y: 5, w: 58, h: 104 });
    expect(manifestRaw.envAtlas.frames['rime-pillar'].w).toBe(56);
    expect(manifestRaw.envAtlas.frames['rime-pillar'].h).toBe(104);

    applySpriteManifest(manifestRaw);
    expect(getEnvFrame('cinder-pillar')).toEqual({ x: 485, y: 5, w: 58, h: 104 });
    expect(getEnvFrame('rime-pillar')?.w).toBe(56);
    expect(getEnvFrame('rime-pillar')?.h).toBe(104);

    // Test applyEnvAtlasJson direct update
    applyEnvAtlasJson({
      frames: {
        'test-pillar': { x: 10, y: 20, w: 52, h: 98 },
      },
    });
    expect(getEnvFrame('test-pillar')).toEqual({ x: 10, y: 20, w: 52, h: 98 });
    // Preserves existing frames
    expect(getEnvFrame('cinder-pillar')).toEqual({ x: 485, y: 5, w: 58, h: 104 });
    expect(getEnvFrame('rime-pillar')?.w).toBe(56);
    expect(getEnvFrame('rime-pillar')?.h).toBe(104);
  });
});
