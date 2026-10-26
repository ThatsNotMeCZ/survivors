import Phaser from 'phaser';
import {
  FX_DASH,
  FX_DEATH,
  FX_GEM,
  FX_HIT,
  FX_HURT,
  FX_MUZZLE,
  FX_STRIKE,
} from '../config';
import { FLAG_IMPACT, FLAG_PIERCE, FLAG_TETHER, TEAM_ENEMY, type ProjectilePool } from '../sim/projectiles';
import { ZONE_LINE, ZONE_STRIKE, type ZonePool } from '../sim/zones';
import { getSettings } from '../ui/settings';
import type { BiomeId } from './procedural-pixel-art';
import { authoredFx, fxTextureKey } from './sprites';

export const FX_STILL_CAP = 48;
export const FX_STILL_LIFE = 0.2;
const STRIKE_TELEGRAPH = 0.7;
const NOXIOUS_DEATH_TINT = 0x66ff88;

export type FxStillPool = {
  sprites: Phaser.GameObjects.Image[];
  life: Float32Array;
  max: Float32Array;
};

export function resolveFxKey(scene: Phaser.Scene, id: string): string | null {
  if (!authoredFx(id)) return null;
  const key = fxTextureKey(id);
  return scene.textures.exists(key) ? key : null;
}

export function shotFxId(team: number, flags: number, biome: BiomeId): string {
  if (team === TEAM_ENEMY) return biome === 'cinder' ? 'cinder-spit' : 'frost-spit';
  if ((flags & FLAG_TETHER) !== 0) return 'skill-condemn-tether';
  if ((flags & FLAG_PIERCE) !== 0) return 'skill-aether-pierce';
  if ((flags & FLAG_IMPACT) !== 0) return 'skill-censer-lob';
  return 'bolt';
}

export function zoneFxId(kind: number): string | null {
  if (kind === ZONE_LINE) return 'skill-brimstone-line';
  if (kind === ZONE_STRIKE) return 'skill-crucible-cull';
  return null;
}

export function eventFxId(kind: number, tint: number, utilitySkillId: string): string | null {
  if (kind === FX_HIT) return 'hit';
  if (kind === FX_HURT) return 'hurt';
  if (kind === FX_DEATH) return tint === NOXIOUS_DEATH_TINT ? 'noxious-pop' : 'death';
  if (kind === FX_MUZZLE) return 'muzzle';
  if (kind === FX_DASH) return authoredFx(utilitySkillId) ? utilitySkillId : 'dash';
  if (kind === FX_STRIKE) return 'skill-crucible-cull';
  if (kind === FX_GEM) return 'gem';
  return null;
}

export function createFxStillPool(scene: Phaser.Scene, cap = FX_STILL_CAP): FxStillPool {
  const sprites: Phaser.GameObjects.Image[] = [];
  for (let i = 0; i < cap; i += 1) {
    sprites.push(scene.add.image(0, 0, 'px-spark').setVisible(false).setDepth(6).setAlpha(0));
  }
  return { sprites, life: new Float32Array(cap), max: new Float32Array(cap) };
}

export function spawnFxStill(
  scene: Phaser.Scene,
  pool: FxStillPool,
  id: string,
  x: number,
  y: number,
  rotation: number,
): boolean {
  if (getSettings().reduceVfx) return false;
  const key = resolveFxKey(scene, id);
  if (!key) return false;
  for (let i = 0; i < pool.sprites.length; i += 1) {
    if (pool.life[i] > 0) continue;
    const sprite = pool.sprites[i];
    if (sprite.texture.key !== key) sprite.setTexture(key);
    fitFxNative(sprite);
    sprite.setPosition(Math.round(x), Math.round(y));
    sprite.setRotation(rotation);
    sprite.setAlpha(1);
    sprite.setVisible(true);
    pool.life[i] = FX_STILL_LIFE;
    pool.max[i] = FX_STILL_LIFE;
    return true;
  }
  return false;
}

export function stepFxStills(pool: FxStillPool, dt: number): void {
  for (let i = 0; i < pool.sprites.length; i += 1) {
    if (pool.life[i] <= 0) {
      if (pool.sprites[i].visible) pool.sprites[i].setVisible(false);
      continue;
    }
    pool.life[i] -= dt;
    const t = pool.max[i] > 0 ? Math.max(0, pool.life[i] / pool.max[i]) : 0;
    pool.sprites[i].setAlpha(t);
    if (pool.life[i] <= 0) pool.sprites[i].setVisible(false);
  }
}

export function applyShotVisual(
  scene: Phaser.Scene,
  sprite: Phaser.GameObjects.Image,
  pool: ProjectilePool,
  index: number,
  biome: BiomeId,
): void {
  const fxId = shotFxId(pool.team[index], pool.flags[index], biome);
  const key = resolveFxKey(scene, fxId);
  if (key) {
    if (sprite.texture.key !== key) sprite.setTexture(key);
    sprite.clearTint();
    fitFxNative(sprite);
    sprite.setRotation(Math.atan2(pool.vy[index], pool.vx[index]));
    sprite.setVisible(true);
    sprite.setPosition(Math.round(pool.x[index]), Math.round(pool.y[index]));
    return;
  }
  const fallback = fallbackBoltKey(pool.team[index], biome);
  if (sprite.texture.key !== fallback) sprite.setTexture(fallback);
  sprite.setRotation(0);
  applyProceduralShotStyle(sprite, pool.team[index], pool.flags[index]);
  sprite.setVisible(true);
  sprite.setPosition(Math.round(pool.x[index]), Math.round(pool.y[index]));
}

export function syncZoneFx(scene: Phaser.Scene, sprites: Phaser.GameObjects.Image[], zones: ZonePool): void {
  for (let i = 0; i < sprites.length; i += 1) {
    const sprite = sprites[i];
    if (zones.alive[i] === 0) {
      sprite.setVisible(false);
      continue;
    }
    const id = zoneFxId(zones.kind[i]);
    const key = id ? resolveFxKey(scene, id) : null;
    if (!id || !key) {
      sprite.setVisible(false);
      continue;
    }
    if (sprite.texture.key !== key) sprite.setTexture(key);
    sprite.clearTint();
    sprite.setVisible(true);
    sprite.setPosition(Math.round(zones.x[i]), Math.round(zones.y[i]));
    if (zones.kind[i] === ZONE_STRIKE) {
      const grow = Math.max(0.25, 1 - zones.remain[i] / STRIKE_TELEGRAPH);
      fitFxNative(sprite, grow);
      sprite.setRotation(0);
    } else {
      fitFxNative(sprite);
      sprite.setRotation(Math.atan2(zones.dirY[i], zones.dirX[i]));
    }
  }
}

function fitFxNative(image: Phaser.GameObjects.Image, extra = 1): void {
  const fw = image.frame?.width ?? 32;
  const fh = image.frame?.height ?? 29;
  image.setDisplaySize(fw * extra, fh * extra);
}

function fallbackBoltKey(team: number, biome: BiomeId): string {
  if (team === TEAM_ENEMY) return biome === 'cinder' ? 'px-bolt-enemy-cinder' : 'px-bolt-enemy-rime';
  return 'px-bolt-player';
}

function applyProceduralShotStyle(sprite: Phaser.GameObjects.Image, team: number, flags: number): void {
  const fw = sprite.frame?.width ?? 8;
  const fh = sprite.frame?.height ?? 8;
  if (team === TEAM_ENEMY) {
    sprite.clearTint();
    sprite.setDisplaySize(fw, fh);
    return;
  }
  if ((flags & FLAG_TETHER) !== 0) {
    sprite.setTint(0xc4a05a);
    sprite.setDisplaySize(fw * 1.6, fh * 1.6);
    return;
  }
  if ((flags & FLAG_PIERCE) !== 0) {
    sprite.setTint(0x88ffff);
    sprite.setDisplaySize(fw * 1.5, fh * 0.7);
    return;
  }
  if ((flags & FLAG_IMPACT) !== 0) {
    sprite.setTint(0xffaa55);
    sprite.setDisplaySize(fw * 1.3, fh * 1.3);
    return;
  }
  sprite.clearTint();
  sprite.setDisplaySize(fw, fh);
}
