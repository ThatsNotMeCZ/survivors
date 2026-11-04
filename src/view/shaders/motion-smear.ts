import Phaser from 'phaser';
import type { BiomeId } from '../procedural-pixel-art';

export interface MotionSmearHandle {
  sprite: Phaser.GameObjects.Sprite;
  filter: any;
}

/**
 * Attaches a directional motion smear filter to a Phaser Sprite.
 * Uses Phaser 4's internal Shadow filter pass along (-vx, -vy) to create
 * a decayed motion tail directly from the sprite's silhouette.
 */
export function createMotionSmear(sprite: Phaser.GameObjects.Sprite, color = 0x181016): MotionSmearHandle | null {
  try {
    if (typeof sprite.enableFilters !== 'function') return null;
    sprite.enableFilters();
    if (!sprite.filters || !sprite.filters.internal) return null;

    // FilterShadow: (camera, x, y, decay, power, color, samples, intensity)
    const shadow = sprite.filters.internal.addShadow(0, 0, 0.22, 1.0, color, 8, 1.2);
    if (!shadow) return null;
    shadow.setActive(false);
    return { sprite, filter: shadow };
  } catch (err) {
    console.warn('Motion smear filter setup failed:', err);
    return null;
  }
}

/**
 * Updates the motion smear direction and intensity based on movement vector.
 */
export function updateMotionSmear(
  handle: MotionSmearHandle | null | undefined,
  vx: number,
  vy: number,
  speed: number,
  biome: BiomeId,
  enabled: boolean,
): void {
  if (!handle || !handle.filter) return;
  if (!enabled || speed < 12) {
    if (handle.filter.active) handle.filter.setActive(false);
    return;
  }

  // Smear points opposite to movement direction (-vx, -vy)
  const norm = speed > 0 ? 1 / speed : 0;
  const dirX = vx * norm;
  const dirY = vy * norm;

  // Scale smear offset from 2.5px up to 7.5px in world space
  const dist = Math.min(8.0, Math.max(2.0, (speed / 150) * 4.5));

  handle.filter.x = -dirX * dist;
  handle.filter.y = -dirY * dist;
  handle.filter.color = biome === 'cinder' ? 0x221210 : 0x101a26;
  handle.filter.decay = 0.24;
  handle.filter.intensity = Math.min(1.4, 0.6 + (speed / 180) * 0.7);
  if (!handle.filter.active) handle.filter.setActive(true);
}
