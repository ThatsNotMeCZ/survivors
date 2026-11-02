import { describe, expect, it } from 'bun:test';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { writeSpriteManifest } from '../scripts/sprite-manifest';
import {
  floorKey,
  stageBiome,
  stageEnvTheme,
} from '../src/view/procedural-pixel-art';
import {
  applySpriteManifest,
  getEnvAtlasDef,
  getEnvFrame,
  hasEnvTexture,
  resolveEnvThemeProp,
} from '../src/view/sprites';

describe('Environment Atlas & Mapping', () => {
  it('public/sprites/env/atlas.json contains all required pre-filled keys with 0x0 dims', () => {
    const raw = JSON.parse(readFileSync(join(process.cwd(), 'public/sprites/env/atlas.json'), 'utf8'));
    expect(raw.frames).toBeDefined();

    const expectedKeys = [
      // Cinder
      'cinder-tile-0', 'cinder-tile-1', 'cinder-tile-2', 'cinder-tile-3',
      'cinder-border-edge', 'cinder-border-corner',
      'cinder-pillar', 'cinder-hazard-0', 'cinder-hazard-1',
      'cinder-volatile', 'cinder-circle', 'cinder-portal',

      // Rime
      'rime-tile-0', 'rime-tile-1', 'rime-tile-2', 'rime-tile-3',
      'rime-border-edge', 'rime-border-corner',
      'rime-pillar', 'rime-hazard-0', 'rime-hazard-1',
      'rime-volatile', 'rime-circle', 'rime-portal',

      // Glacial
      'glacial-tile-0', 'glacial-tile-1', 'glacial-tile-2', 'glacial-tile-3',
      'glacial-border-edge', 'glacial-border-corner',
      'glacial-pillar', 'glacial-hazard-0', 'glacial-hazard-1',
      'glacial-volatile', 'glacial-circle', 'glacial-portal',

      // Ambient
      'ambient-ash', 'ambient-ember', 'ambient-snow', 'ambient-mist',
    ];

    for (const key of expectedKeys) {
      expect(raw.frames[key]).toBeDefined();
      expect(raw.frames[key]).toEqual({ x: 0, y: 0, w: 0, h: 0 });
    }
  });

  it('writeSpriteManifest does not crash and safely handles empty atlas', () => {
    const path = writeSpriteManifest();
    expect(path).toBeDefined();
    const manifest = JSON.parse(readFileSync(path, 'utf8'));
    // Since atlas.png is not yet present, envAtlas is omitted or has empty frames
    expect(manifest.envAtlas).toBeUndefined();
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
});
