import { describe, expect, it } from 'bun:test';
import { catalog } from '../src/data/catalog';
import { createWorld } from '../src/sim/world';
import { spawnGem, spawnLoreDrop, stepGems, stepLores } from '../src/sim/gems';

describe('XP Gem and Lore Drop Pull Distance & Magnetism', () => {
  it('configures loop.json with default pull distance = 0 and gemMagnetBonus = 88', () => {
    expect(catalog.loop.gemMagnet).toBe(0);
    expect(catalog.loop.gemMagnetBonus).toBe(88);
    expect(catalog.loop.gemPickup).toBe(36);
  });

  it('keeps gems stationary when player has no magnetism item (default pull distance = 0)', () => {
    const world = createWorld('runner');
    expect(world.stats.pickupRadiusMul).toBe(1.0);

    // Spawn gem 60px to the right of player (beyond pickup of 36px, within former 88px magnet)
    const gemX = world.player.x + 60;
    const gemY = world.player.y;
    const spawned = spawnGem(world.gems, gemX, gemY, 10);
    expect(spawned).toBe(true);

    const initialGemsCollected = world.gemsCollected;
    const initialXp = world.xp;

    // Step gems for 0.1s
    stepGems(world, 0.1);

    // Gem must NOT have moved and must still be alive
    expect(world.gems.alive[0]).toBe(1);
    expect(world.gems.x[0]).toBe(gemX);
    expect(world.gems.y[0]).toBe(gemY);
    expect(world.gemsCollected).toBe(initialGemsCollected);
    expect(world.xp).toBe(initialXp);
  });

  it('collects gems when player touches them (dist <= gemPickup)', () => {
    const world = createWorld('runner');
    const gemX = world.player.x + 20; // 20px <= gemPickup (36px)
    const gemY = world.player.y;
    spawnGem(world.gems, gemX, gemY, 15);

    stepGems(world, 0.1);

    // Gem collected upon contact
    expect(world.gems.alive[0]).toBe(0);
    expect(world.gemsCollected).toBe(1);
    expect(world.xp).toBe(15);
  });

  it('pulls gems from a distance when player has magnetism item (mercury-vial)', () => {
    const world = createWorld('runner');
    // Simulate equipping Quicksilver Draught (+35% pickupRadius)
    world.stats.pickupRadiusMul = 1.35;

    const gemX = world.player.x + 60;
    const gemY = world.player.y;
    spawnGem(world.gems, gemX, gemY, 10);

    // Step gems for 0.05s
    stepGems(world, 0.05);

    // Gem must still be alive and must have moved toward the player
    expect(world.gems.alive[0]).toBe(1);
    expect(world.gems.x[0]).toBeLessThan(gemX);
    expect(world.gems.y[0]).toBe(gemY);
  });

  it('leaves lore drops stationary at default, but pulls them when player has magnetism', () => {
    const world = createWorld('runner');
    const loreX = world.player.x + 60;
    const loreY = world.player.y;
    spawnLoreDrop(world.lores, loreX, loreY, 'test-lore');

    // Default state: no movement
    stepLores(world, 0.1);
    expect(world.lores.alive[0]).toBe(1);
    expect(world.lores.x[0]).toBe(loreX);

    // With magnetism item
    world.stats.pickupRadiusMul = 1.35;
    stepLores(world, 0.05);
    expect(world.lores.x[0]).toBeLessThan(loreX);
  });
});
