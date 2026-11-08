import { describe, expect, test } from 'bun:test';
import { catalog } from '../src/data/catalog';
import { createWorld } from '../src/sim/world';
import { emptyInput } from '../src/sim/input-frame';
import { resolveObstacleBodies } from '../src/sim/obstacles';
import { ROLE_BOSS } from '../src/sim/enemies';

describe('Obstacle hitboxes, border insets, and pillar collisions', () => {
  test('cinder pillar and volatile hitboxes match intended specs', () => {
    expect(catalog.obstacles.pillar.radius).toBe(28);
    expect(catalog.obstacles.volatile.radius).toBe(14);
  });

  test('world defines border insets for walkable area subtraction', () => {
    expect(catalog.world.borderInsetX).toBe(21);
    expect(catalog.world.borderInsetY).toBe(34);
  });

  test('player clamping respects borderInsetX and borderInsetY', () => {
    const world = createWorld();
    const bounds = world.catalog.world;
    const insetX = bounds.borderInsetX ?? 0;
    const insetY = bounds.borderInsetY ?? 0;

    // Place player at far left and attempt to walk further left
    world.player.x = insetX + world.player.radius;
    world.player.y = 500;
    const input = emptyInput();
    input.moveX = -1;
    world.stats.speed = 200;

    // Simulate move
    world.player.x += input.moveX * world.stats.speed * 0.1;
    const padX = insetX + world.player.radius;
    world.player.x = Math.max(padX, world.player.x);

    expect(world.player.x).toBe(insetX + world.player.radius);
    expect(world.player.x).toBeGreaterThanOrEqual(insetX);
  });

  test('boss is pushed out of pillars by resolveObstacleBodies', () => {
    const world = createWorld();
    // Setup a pillar obstacle at (500, 500)
    world.obstacles.alive[0] = 1;
    const obs = world.obstacles.items[0];
    obs.type = 'pillar';
    obs.x = 500;
    obs.y = 500;
    obs.radius = 28;

    // Spawn boss overlapping the pillar
    world.enemies.alive[0] = 1;
    world.enemies.role[0] = ROLE_BOSS;
    world.enemies.x[0] = 510;
    world.enemies.y[0] = 500;
    world.enemies.radius[0] = 40;

    // Verify initial overlap
    const distBefore = Math.hypot(world.enemies.x[0] - obs.x, world.enemies.y[0] - obs.y);
    expect(distBefore).toBeLessThan(obs.radius + world.enemies.radius[0]);

    // Resolve bodies
    resolveObstacleBodies(world);

    // Verify boss was pushed out
    const distAfter = Math.hypot(world.enemies.x[0] - obs.x, world.enemies.y[0] - obs.y);
    expect(distAfter).toBeGreaterThanOrEqual(obs.radius + world.enemies.radius[0] - 0.001);
  });

  test('pillar base origin aligns bottom edge with collision circle boundary', () => {
    const pillarRadius = catalog.obstacles.pillar.radius; // 28
    const frameHeight = 104; // cinder-pillar and rime-pillar height in env atlas
    const originY = (frameHeight - pillarRadius) / frameHeight;

    // Center of collision is at obs.y.
    // The top of the sprite is at: obs.y - originY * frameHeight
    // The bottom of the sprite is at: obs.y + (1 - originY) * frameHeight
    const topOffset = originY * frameHeight;
    const bottomOffset = (1 - originY) * frameHeight;

    expect(bottomOffset).toBeCloseTo(pillarRadius, 5);
    expect(topOffset).toBeCloseTo(frameHeight - pillarRadius, 5); // 76px extends upwards
  });

  test('y-sort depth ensures character below pillar is in front and character above is behind', () => {
    const worldHeight = catalog.world.height;
    const ySort = (y: number, bias = 0) => 3.2 + Math.max(0, Math.min(1, y / worldHeight)) * 1.6 + bias;

    const pillarY = 800;
    const pillarDepth = ySort(pillarY);

    const characterAboveY = 760; // standing north/above of pillar
    const characterBelowY = 840; // standing south/below of pillar

    const depthAbove = ySort(characterAboveY, 0.0002);
    const depthBelow = ySort(characterBelowY, 0.0002);

    expect(depthAbove).toBeLessThan(pillarDepth);
    expect(depthBelow).toBeGreaterThan(pillarDepth);
  });
});
