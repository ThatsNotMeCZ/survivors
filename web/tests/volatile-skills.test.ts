import { describe, expect, test } from 'bun:test';
import { emptyInput } from '../src/sim/input-frame';
import { createWorld, stepWorld } from '../src/sim/world';
import { spawnProjectile, TEAM_ENEMY } from '../src/sim/projectiles';

const DT = 1 / 60;

describe('Volatile skills damage and interaction', () => {
  test('Penitent Censer Lob damages, primes, and detonates environmental volatiles', () => {
    const world = createWorld('penitent');
    world.stats.critChance = 0;
    const input = emptyInput();

    let volatileIdx = -1;
    for (let i = 0; i < world.obstacles.cap; i += 1) {
      if (world.obstacles.alive[i] === 1 && world.obstacles.items[i].type === 'volatile') {
        volatileIdx = i;
        break;
      }
    }

    expect(volatileIdx).toBeGreaterThanOrEqual(0);
    const vol = world.obstacles.items[volatileIdx];
    const initialHp = vol.hp;
    expect(vol.state).toBe('intact');
    expect(initialHp).toBe(25);

    // Position player within lob range (100px away)
    world.player.x = vol.x - 100;
    world.player.y = vol.y;
    input.aimX = vol.x;
    input.aimY = vol.y;

    // Fire first censer lob by holding primary
    input.held.primary = true;
    stepWorld(world, input, DT);
    input.held.primary = false;

    // Step simulation until censer lands (~15 frames)
    let hit = false;
    for (let step = 0; step < 60; step += 1) {
      stepWorld(world, input, DT);
      if (vol.hp < initialHp) {
        hit = true;
        break;
      }
    }

    expect(hit).toBe(true);
    expect(vol.hp).toBe(11);
    expect(vol.state).toBe('intact');

    // Wait for cooldown to expire (0.42s)
    while (world.player.skillCd.primary > 0) {
      stepWorld(world, input, DT);
    }

    // Fire second censer lob to prime it
    input.held.primary = true;
    stepWorld(world, input, DT);
    input.held.primary = false;

    let primed = false;
    for (let step = 0; step < 60; step += 1) {
      stepWorld(world, input, DT);
      if (vol.state === 'primed') {
        primed = true;
        break;
      }
    }

    expect(primed).toBe(true);
    expect(vol.hp).toBe(0);

    // Step past prime timer (0.4s) to verify detonation
    for (let step = 0; step < 40; step += 1) {
      stepWorld(world, input, DT);
    }

    expect(vol.state).toBe('detonated');
    expect(world.obstacles.alive[volatileIdx]).toBe(0);
  });

  test('Enemy projectiles cannot damage environmental volatiles', () => {
    const world = createWorld('penitent');
    const input = emptyInput();

    let volatileIdx = -1;
    for (let i = 0; i < world.obstacles.cap; i += 1) {
      if (world.obstacles.alive[i] === 1 && world.obstacles.items[i].type === 'volatile') {
        volatileIdx = i;
        break;
      }
    }

    const vol = world.obstacles.items[volatileIdx];
    const initialHp = vol.hp;

    // Spawn enemy projectile aimed at volatile
    spawnProjectile(world.projectiles, {
      x: vol.x - 20,
      y: vol.y,
      dirX: 1,
      dirY: 0,
      speed: 300,
      lifetime: 1,
      radius: 6,
      damage: 20,
      team: TEAM_ENEMY,
    });

    for (let step = 0; step < 20; step += 1) {
      stepWorld(world, input, DT);
    }

    expect(vol.hp).toBe(initialHp);
    expect(vol.state).toBe('intact');
  });

  test('Homunculus Crucible Cull damages and primes environmental volatiles', () => {
    const world = createWorld('runner');
    world.stats.critChance = 0;
    const input = emptyInput();

    let volatileIdx = -1;
    for (let i = 0; i < world.obstacles.cap; i += 1) {
      if (world.obstacles.alive[i] === 1 && world.obstacles.items[i].type === 'volatile') {
        volatileIdx = i;
        break;
      }
    }

    const vol = world.obstacles.items[volatileIdx];
    world.player.x = vol.x - 50;
    world.player.y = vol.y;
    input.aimX = vol.x;
    input.aimY = vol.y;
    input.pressed.special = true;

    stepWorld(world, input, DT);
    input.pressed.special = false;

    // Crucible cull delay is 0.7s (~42 frames)
    let primed = false;
    for (let step = 0; step < 60; step += 1) {
      stepWorld(world, input, DT);
      if (vol.state === 'primed') {
        primed = true;
        break;
      }
    }

    expect(primed).toBe(true);
    expect(vol.hp).toBe(0);
  });

  test('Penitent Brimstone Line deals ticking damage to environmental volatiles', () => {
    const world = createWorld('penitent');
    const input = emptyInput();

    let volatileIdx = -1;
    for (let i = 0; i < world.obstacles.cap; i += 1) {
      if (world.obstacles.alive[i] === 1 && world.obstacles.items[i].type === 'volatile') {
        volatileIdx = i;
        break;
      }
    }

    const vol = world.obstacles.items[volatileIdx];
    const initialHp = vol.hp;

    world.player.x = vol.x - 56;
    world.player.y = vol.y;
    input.aimX = vol.x;
    input.aimY = vol.y;
    input.pressed.secondary = true;

    stepWorld(world, input, DT);
    input.pressed.secondary = false;

    // Step 30 frames
    for (let step = 0; step < 30; step += 1) {
      stepWorld(world, input, DT);
    }

    expect(vol.hp).toBeLessThan(initialHp);
  });
});
