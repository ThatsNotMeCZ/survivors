import { describe, expect, it } from 'bun:test';
import { applyEnemyDamage, clearEnemies, spawnAround, spawnEnemy, stepEnemies } from '../src/sim/enemies';
import { countObstacles } from '../src/sim/obstacles';
import { createWorld } from '../src/sim/world';

describe('Elite Affixes Separation & Mechanics', () => {
  it('splits elites exclusively into either Shielder or Noxious (never both, never neither)', () => {
    const world = createWorld();
    const def = world.catalog.entity('ember-chaser');

    let shielderCount = 0;
    let noxiousCount = 0;

    for (let i = 0; i < 100; i += 1) {
      clearEnemies(world);
      const idx = spawnEnemy(world, def, 100, 100, true);
      expect(idx).not.toBeNull();
      if (idx === null) continue;

      const isShielder = world.enemies.shielder[idx] === 1;
      const isNoxious = world.enemies.noxious[idx] === 1;

      // Exclusive: either one or the other, strictly
      expect(isShielder !== isNoxious).toBe(true);

      if (isShielder) {
        shielderCount += 1;
        expect(world.enemies.shieldHp[idx]).toBeGreaterThan(0);
      } else {
        noxiousCount += 1;
        expect(world.enemies.shieldHp[idx]).toBe(0);
      }
    }

    // Both affixes should have spawned across 100 iterations (50/50 split)
    expect(shielderCount).toBeGreaterThan(20);
    expect(noxiousCount).toBeGreaterThan(20);
  });

  it('respects explicit eliteAffix parameter on spawnAround', () => {
    const world = createWorld();
    const def = world.catalog.entity('ember-chaser');

    // Force Shielder
    for (let i = 0; i < 5; i += 1) {
      spawnAround(world, def, true, 'shielder');
    }
    for (let i = 0; i < world.enemies.cap; i += 1) {
      if (world.enemies.alive[i] === 0) continue;
      expect(world.enemies.shielder[i]).toBe(1);
      expect(world.enemies.noxious[i]).toBe(0);
      expect(world.enemies.shieldHp[i]).toBeGreaterThan(0);
    }

    // Clear and force Noxious
    clearEnemies(world);

    for (let i = 0; i < 5; i += 1) {
      spawnAround(world, def, true, 'noxious');
    }
    for (let i = 0; i < world.enemies.cap; i += 1) {
      if (world.enemies.alive[i] === 0) continue;
      expect(world.enemies.shielder[i]).toBe(0);
      expect(world.enemies.noxious[i]).toBe(1);
      expect(world.enemies.shieldHp[i]).toBe(0);
    }
  });

  it('only regenerates shields for Shielder elites after damage', () => {
    const world = createWorld();
    const def = world.catalog.entity('ember-chaser');

    // Spawn shielder
    const sIdx = spawnEnemy(world, def, 500, 500, true, 'shielder')!;
    expect(sIdx).not.toBeNull();
    const initialShield = world.enemies.shieldHp[sIdx];
    expect(initialShield).toBeGreaterThan(0);

    // Apply damage to shield
    applyEnemyDamage(world, sIdx, 10, false, 0);
    expect(world.enemies.shieldHp[sIdx]).toBe(initialShield - 10);
    expect(world.enemies.shieldDelayRemain[sIdx]).toBe(world.catalog.loop.shielder.delay);

    // Advance time before delay expires
    stepEnemies(world, 1.0);
    expect(world.enemies.shieldHp[sIdx]).toBe(initialShield - 10);

    // Advance time past remaining delay (delay total is 5.0s, so step 4.5s more)
    stepEnemies(world, 4.5);
    expect(world.enemies.shieldHp[sIdx]).toBeGreaterThan(initialShield - 10);
  });

  it('noxious elites detonate into acid hazards upon corpse timer expiration', () => {
    const world = createWorld();
    const def = world.catalog.entity('ember-chaser');

    const initialHazards = countObstacles(world.obstacles, 'hazard');

    // Spawn noxious elite
    const nIdx = spawnEnemy(world, def, 600, 600, true, 'noxious')!;
    expect(nIdx).not.toBeNull();
    expect(world.enemies.noxious[nIdx]).toBe(1);

    // Deal lethal damage
    applyEnemyDamage(world, nIdx, 999999, false, 0);
    // Entity becomes a corpse waiting to explode
    expect(world.enemies.alive[nIdx]).toBe(1);
    expect(world.enemies.corpseRemain[nIdx]).toBeGreaterThan(0);

    // Step until corpse timer expires (corpseDelay is 1.5s)
    stepEnemies(world, 2.0);

    // Enemy is now fully dead and spawned an acid puddle
    expect(world.enemies.alive[nIdx]).toBe(0);
    expect(countObstacles(world.obstacles, 'hazard')).toBe(initialHazards + 1);
  });
});
