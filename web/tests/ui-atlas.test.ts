import { describe, expect, it } from 'bun:test';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import {
  applySpriteManifest,
  applyUiTexture,
  getUiAtlasDef,
  getUiFrame,
  hasUiTexture,
} from '../src/view/sprites';

describe('UI Atlas & Waypoint Navigation Arrow', () => {
  it('public/sprites/ui/atlas.json contains nav-arrow with valid dimensions', () => {
    const raw = JSON.parse(readFileSync(join(process.cwd(), 'public/sprites/ui/atlas.json'), 'utf8'));
    const frame = raw['nav-arrow'] ?? raw.frames?.['nav-arrow'];
    expect(frame).toBeDefined();
    expect(typeof frame.x).toBe('number');
    expect(typeof frame.y).toBe('number');
    expect(typeof frame.w).toBe('number');
    expect(typeof frame.h).toBe('number');
    expect(frame.w).toBeGreaterThan(0);
    expect(frame.h).toBeGreaterThan(0);
  });

  it('public/sprites/manifest.json registers uiAtlas with nav-arrow', () => {
    const manifest = JSON.parse(readFileSync(join(process.cwd(), 'public/sprites/manifest.json'), 'utf8'));
    expect(manifest.uiAtlas).toBeDefined();
    expect(manifest.uiAtlas.src).toBe('sprites/ui/atlas.png');
    const entry = manifest.uiAtlas.frames?.['nav-arrow'];
    expect(entry).toBeDefined();
    const rect = entry.idle ?? entry;
    expect(rect.w).toBeGreaterThan(0);
    expect(rect.h).toBeGreaterThan(0);
  });

  it('applySpriteManifest parses uiAtlas and getUiFrame resolves nav-arrow', () => {
    applySpriteManifest({
      entities: {},
      items: [],
      skills: [],
      env: [],
      fx: [],
      uiAtlas: {
        src: 'sprites/ui/atlas.png',
        width: 1295,
        height: 1844,
        frames: {
          'nav-arrow': {
            idle: { x: 900, y: 620, w: 32, h: 32 },
            hover: { x: 900, y: 620, w: 32, h: 32 },
            active: { x: 900, y: 620, w: 32, h: 32 },
          },
        },
      },
    });

    const atlasDef = getUiAtlasDef();
    expect(atlasDef).toBeDefined();
    expect(atlasDef?.frames['nav-arrow']).toBeDefined();
    expect(getUiFrame('nav-arrow')).toEqual({ x: 900, y: 620, w: 32, h: 32 });
  });

  it('hasUiTexture and applyUiTexture apply nav-arrow to Phaser image', () => {
    const fakeTexture = {
      frames: new Set<string>(['nav-arrow']),
      has(frame: string) {
        return this.frames.has(frame);
      },
      add(frame: string) {
        this.frames.add(frame);
      },
    };

    const fakeScene = {
      textures: {
        exists: (key: string) => key === 'ui-atlas',
        get: () => fakeTexture,
      },
    } as any;

    const dummyImage = {
      scene: fakeScene,
      texture: { key: 'px-waypoint' },
      frame: { name: '__BASE' },
      setTexture(key: string, frame?: string) {
        this.texture = { key };
        this.frame = { name: frame ?? '__BASE' };
        return this;
      },
    } as any;

    expect(hasUiTexture(fakeScene, 'nav-arrow')).toBe(true);
    const applied = applyUiTexture(dummyImage, 'nav-arrow', 'px-waypoint');
    expect(applied).toBe(true);
    expect(dummyImage.texture.key).toBe('ui-atlas');
    expect(dummyImage.frame.name).toBe('nav-arrow');
  });

  it('waypoint rotation with -Math.PI / 2 offset orients downward-pointing sprite toward target', () => {
    // A sprite authored pointing DOWN (vector [0, 1]) rotated by theta produces:
    // x' = -sin(theta), y' = cos(theta)
    const computeDir = (dx: number, dy: number) => {
      const angle = Math.atan2(dy, dx) - Math.PI / 2;
      return {
        x: Math.round(-Math.sin(angle)) + 0,
        y: Math.round(Math.cos(angle)) + 0,
      };
    };

    // Right: dx > 0, dy = 0 -> should point (1, 0)
    expect(computeDir(100, 0)).toEqual({ x: 1, y: 0 });

    // Down: dx = 0, dy > 0 -> should point (0, 1)
    expect(computeDir(0, 100)).toEqual({ x: 0, y: 1 });

    // Left: dx < 0, dy = 0 -> should point (-1, 0)
    expect(computeDir(-100, 0)).toEqual({ x: -1, y: 0 });

    // Up: dx = 0, dy < 0 -> should point (0, -1)
    expect(computeDir(0, -100)).toEqual({ x: 0, y: -1 });
  });
});
