import { describe, expect, it } from 'bun:test';
import { clearEnemies, spawnEnemy, stepEnemies } from '../src/sim/enemies';
import { createWorld } from '../src/sim/world';

describe('Enemy facing and movement mirroring', () => {
  it('initializes facing toward the player on spawn', () => {
    const world = createWorld();
    world.player.x = 200;
    world.player.y = 200;

    const emberMite = world.catalog.entity('ember-mite');

    // Spawn to the right of player (x: 300) -> should face left (-1)
    const rightIndex = spawnEnemy(world, emberMite, 300, 200);
    expect(rightIndex).toBeGreaterThanOrEqual(0);
    expect(world.enemies.facing[rightIndex]).toBe(-1);

    // Spawn to the left of player (x: 100) -> should face right (1)
    const leftIndex = spawnEnemy(world, emberMite, 100, 200);
    expect(leftIndex).toBeGreaterThanOrEqual(0);
    expect(world.enemies.facing[leftIndex]).toBe(1);
  });

  it('updates facing when moving left and right', () => {
    const world = createWorld();
    world.player.x = 100;
    world.player.y = 200;

    const emberMite = world.catalog.entity('ember-mite');
    const idx = spawnEnemy(world, emberMite, 300, 200);
    expect(world.enemies.facing[idx]).toBe(-1);

    // Step world with enemy chasing player to the left
    stepEnemies(world, 0.1);
    expect(world.enemies.x[idx]).toBeLessThan(300);
    expect(world.enemies.facing[idx]).toBe(-1);

    // Teleport player to the right of the enemy (x: 500)
    world.player.x = 500;
    world.player.y = 200;

    // Step world with enemy chasing player to the right
    stepEnemies(world, 0.1);
    expect(world.enemies.facing[idx]).toBe(1);
  });

  it('preserves facing when moving purely vertically or stationary', () => {
    const world = createWorld();
    // Enemy is at (200, 100), player is directly below at (200, 300)
    world.player.x = 200;
    world.player.y = 300;

    const emberMite = world.catalog.entity('ember-mite');
    const idx = spawnEnemy(world, emberMite, 200, 100);

    // Set arbitrary facing (e.g. -1)
    world.enemies.facing[idx] = -1;

    // Move enemy down directly (dx = 0, dy > 0)
    stepEnemies(world, 0.1);

    // x position should not change significantly
    expect(Math.abs(world.enemies.x[idx] - 200)).toBeLessThan(0.01);
    // facing should remain preserved as -1
    expect(world.enemies.facing[idx]).toBe(-1);

    // Switch facing to 1 and step again
    world.enemies.facing[idx] = 1;
    stepEnemies(world, 0.1);
    expect(world.enemies.facing[idx]).toBe(1);
  });

  it('faces aim target during windup', () => {
    const world = createWorld();
    const spitter = world.catalog.entity('ember-spitter');
    const idx = spawnEnemy(world, spitter, 200, 200);

    world.enemies.facing[idx] = 1; // Facing right
    world.enemies.windup[idx] = 0.3;
    world.enemies.aimX[idx] = 50; // Aiming to the left
    world.enemies.aimY[idx] = 200;

    stepEnemies(world, 0.05);
    expect(world.enemies.facing[idx]).toBe(-1);
  });

  it('resets facing on clearEnemies', () => {
    const world = createWorld();
    world.enemies.facing[0] = -1;
    clearEnemies(world);
    expect(world.enemies.facing[0]).toBe(1);
  });
});
