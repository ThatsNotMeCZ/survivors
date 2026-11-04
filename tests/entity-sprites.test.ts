import { describe, expect, it } from 'bun:test';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { writeSpriteManifest } from '../scripts/sprite-manifest';
import {
  applySpriteManifest,
  authoredEntity,
  entityAnimKey,
  entitySheet,
  entityTextureKey,
  resolveEntitySheetId,
} from '../src/view/sprites';

describe('Entity Sprites Resolution & Warden Aliasing', () => {
  it('writeSpriteManifest generates both ember-warden and ember-chaser aliases', () => {
    writeSpriteManifest();
    const manifestRaw = readFileSync(join(process.cwd(), 'public/sprites/manifest.json'), 'utf-8');
    const manifest = JSON.parse(manifestRaw);

    expect(manifest.entities['ember-warden']).toBeDefined();
    expect(manifest.entities['ember-chaser']).toBeDefined();
    expect(manifest.entities['ember-warden'].src).toBe('sprites/entities/ember-warden.png');
    expect(manifest.entities['ember-chaser'].src).toBe('sprites/entities/ember-warden.png');
    expect(manifest.entities['ember-warden'].frameWidth).toBe(56);
    expect(manifest.entities['ember-warden'].frameHeight).toBe(56);
  });

  it('resolveEntitySheetId resolves ember-chaser to ember-warden when only warden exists in manifest', () => {
    applySpriteManifest({
      entities: {
        'ember-warden': {
          src: 'sprites/entities/ember-warden.png',
          frameWidth: 56,
          frameHeight: 56,
          anims: {
            idle: { frames: [0], frameRate: 4, repeat: -1 },
            walk: { frames: [1, 2, 3], frameRate: 4, repeat: -1 },
            attack: { frames: [4, 5], frameRate: 4, repeat: 0 },
          },
        },
      },
      items: [],
      skills: [],
      env: [],
      fx: [],
    });

    expect(resolveEntitySheetId('ember-chaser')).toBe('ember-warden');
    expect(authoredEntity('ember-chaser')).toBe(true);
    expect(entityTextureKey('ember-chaser')).toBe('entity-ember-warden');
    expect(entityAnimKey('ember-chaser', 'walk')).toBe('entity-ember-warden-walk');
    expect(entityAnimKey('ember-chaser', 'attack')).toBe('entity-ember-warden-attack');

    const sheet = entitySheet('ember-chaser');
    expect(sheet).toBeDefined();
    expect(sheet?.frameWidth).toBe(56);
  });

  it('resolveEntitySheetId resolves ember-warden to ember-chaser when only chaser exists in manifest', () => {
    applySpriteManifest({
      entities: {
        'ember-chaser': {
          src: 'sprites/entities/ember-chaser.png',
          frameWidth: 56,
          frameHeight: 56,
          anims: {
            idle: { frames: [0], frameRate: 4, repeat: -1 },
            walk: { frames: [1, 2, 3], frameRate: 4, repeat: -1 },
            attack: { frames: [4, 5], frameRate: 4, repeat: 0 },
          },
        },
      },
      items: [],
      skills: [],
      env: [],
      fx: [],
    });

    expect(resolveEntitySheetId('ember-warden')).toBe('ember-chaser');
    expect(authoredEntity('ember-warden')).toBe(true);
    expect(entityTextureKey('ember-warden')).toBe('entity-ember-chaser');
    expect(entityAnimKey('ember-warden', 'idle')).toBe('entity-ember-chaser-idle');
  });

  it('resolveEntitySheetId handles frost-chaser and frost-warden aliases', () => {
    applySpriteManifest({
      entities: {
        'frost-warden': {
          src: 'sprites/entities/frost-warden.png',
          frameWidth: 52,
          frameHeight: 52,
          anims: {
            idle: { frames: [0], frameRate: 4, repeat: -1 },
            walk: { frames: [1, 2, 3], frameRate: 4, repeat: -1 },
          },
        },
      },
      items: [],
      skills: [],
      env: [],
      fx: [],
    });

    expect(resolveEntitySheetId('frost-chaser')).toBe('frost-warden');
    expect(authoredEntity('frost-chaser')).toBe(true);
    expect(entityTextureKey('frost-chaser')).toBe('entity-frost-warden');
  });
});
