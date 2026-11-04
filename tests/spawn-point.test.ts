import { describe, expect, it } from 'bun:test';
import { pickSpawnPoint, spawnAround, spawnEnemy } from '../src/sim/enemies';
import { createWorld } from '../src/sim/world';

describe('Enemy Spawning & Safe Radius', () => {
  it('never spawns inside the player safe radius when player is centered', () => {
    const world = createWorld();
    world.player.x = 1280;
    world.player.y = 1280;

    const safeRadius = world.catalog.loop.director.spawnSafeRadius;
    expect(safeRadius).toBeGreaterThan(0);

    for (let i = 0; i < 200; i += 1) {
      const pt = pickSpawnPoint(world, 16);
      expect(pt).not.toBeNull();
      if (!pt) continue;

      const dist = Math.hypot(pt.x - world.player.x, pt.y - world.player.y);
      expect(dist).toBeGreaterThanOrEqual(safeRadius);

      // Verify it stays inside bounds
      const bounds = world.catalog.world;
      expect(pt.x).toBeGreaterThanOrEqual(16);
      expect(pt.x).toBeLessThanOrEqual(bounds.width - 16);
      expect(pt.y).toBeGreaterThanOrEqual(16);
      expect(pt.y).toBeLessThanOrEqual(bounds.height - 16);
    }
  });

  it('generates well-distributed spawn points when player is near a corner', () => {
    const world = createWorld();
    // Near top-left corner
    world.player.x = 50;
    world.player.y = 50;

    const safeRadius = world.catalog.loop.director.spawnSafeRadius;
    const sampledPoints: { x: number; y: number }[] = [];

    for (let i = 0; i < 100; i += 1) {
      const pt = pickSpawnPoint(world, 16);
      expect(pt).not.toBeNull();
      if (!pt) continue;

      const dist = Math.hypot(pt.x - world.player.x, pt.y - world.player.y);
      expect(dist).toBeGreaterThanOrEqual(safeRadius);

      sampledPoints.push(pt);
    }

    // Check that points are not clamped into the exact same spot
    const uniqueXs = new Set(sampledPoints.map((p) => Math.round(p.x)));
    expect(uniqueXs.size).toBeGreaterThan(40);
  });

  it('spawns relative to player even when teleporter is charging', () => {
    const world = createWorld();
    world.player.x = 2000;
    world.player.y = 2000;
    world.teleporter.state = 'charging';
    world.teleporter.x = 500;
    world.teleporter.y = 500;

    const safeRadius = world.catalog.loop.director.spawnSafeRadius;
    const def = world.catalog.entity('ember-mite');

    const idx = spawnAround(world, def);
    expect(idx).toBeGreaterThanOrEqual(0);

    const enemyX = world.enemies.x[idx];
    const enemyY = world.enemies.y[idx];

    // Must be outside player's safe radius, not necessarily teleporter's
    const distToPlayer = Math.hypot(enemyX - world.player.x, enemyY - world.player.y);
    expect(distToPlayer).toBeGreaterThanOrEqual(safeRadius);
  });

  it('allows direct spawnEnemy calls (boss / boss summons) near player without restriction', () => {
    const world = createWorld();
    world.player.x = 1000;
    world.player.y = 1000;

    const def = world.catalog.entity('cinder-heart');
    // Spawn right next to player (e.g. 20 units away)
    const idx = spawnEnemy(world, def, 1020, 1000);
    expect(idx).toBeGreaterThanOrEqual(0);
    expect(world.enemies.x[idx]).toBe(1020);
    expect(world.enemies.y[idx]).toBe(1000);
  });
});
