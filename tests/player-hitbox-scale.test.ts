import { describe, expect, it } from 'bun:test';
import { catalog } from '../src/data/catalog';
import { createWorld } from '../src/sim/world';
import { syncStats } from '../src/sim/level';
import { MAX_RADIUS_RATIO, MIN_RADIUS_RATIO, resolveStats } from '../src/sim/stats';

describe('Player hitbox stat & character scaling', () => {
  const baseStats = { speed: 280, maxHp: 100, radius: 14 };

  it('resolves default radius without items', () => {
    const stats = resolveStats(baseStats, [], catalog.item);
    expect(stats.radius).toBe(14);
  });

  it('grows hitbox with positive radius items', () => {
    const statsOne = resolveStats(baseStats, [{ id: 'hungry-clip', stacks: 1 }], catalog.item);
    // hungry-clip is +25% radius
    expect(statsOne.radius).toBeCloseTo(14 * 1.25, 4);

    const statsTwo = resolveStats(baseStats, [{ id: 'hungry-clip', stacks: 2 }], catalog.item);
    // 2 stacks = +50% radius
    expect(statsTwo.radius).toBeCloseTo(14 * 1.5, 4);
  });

  it('shrinks hitbox with negative radius items', () => {
    const statsOne = resolveStats(baseStats, [{ id: 'salt-ward', stacks: 1 }], catalog.item);
    // salt-ward is -12% radius
    expect(statsOne.radius).toBeCloseTo(14 * 0.88, 4);

    const statsTwo = resolveStats(baseStats, [{ id: 'salt-ward', stacks: 2 }], catalog.item);
    // 2 stacks = -24% radius
    expect(statsTwo.radius).toBeCloseTo(14 * 0.76, 4);
  });

  it('clamps to MAX_RADIUS_RATIO when stacking excessive enlargement items', () => {
    // 10 stacks of hungry-clip would be +250% (3.5x), but max is 2.0x
    const stats = resolveStats(baseStats, [{ id: 'hungry-clip', stacks: 10 }], catalog.item);
    expect(stats.radius).toBe(baseStats.radius * MAX_RADIUS_RATIO);
  });

  it('clamps to MIN_RADIUS_RATIO when stacking excessive shrinkage items', () => {
    // 10 stacks of salt-ward would be -120% (negative), but min is 0.5x
    const stats = resolveStats(baseStats, [{ id: 'salt-ward', stacks: 10 }], catalog.item);
    expect(stats.radius).toBe(baseStats.radius * MIN_RADIUS_RATIO);
  });

  it('updates world.player.radius through syncStats in gameplay loop', () => {
    const world = createWorld('runner');
    expect(world.player.radius).toBe(14);

    // Add hungry-clip and sync
    world.inventory.push({ id: 'hungry-clip', stacks: 1 });
    syncStats(world);
    expect(world.player.radius).toBeCloseTo(14 * 1.25, 4);
    expect(world.stats.radius).toBeCloseTo(14 * 1.25, 4);

    // Add 10 salt-wards
    world.inventory.push({ id: 'salt-ward', stacks: 10 });
    syncStats(world);
    // Expected to clamp at MIN_RADIUS_RATIO (7)
    expect(world.player.radius).toBe(14 * MIN_RADIUS_RATIO);
  });
});
