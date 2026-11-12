import { describe, expect, it } from 'bun:test';
import { catalog } from '../src/data/catalog';
import { createWorld, damagePlayer, healPlayer, stepWorld, triggerOnCrit } from '../src/sim/world';
import { onCritCooldownRefund, onKillHeal, resolveStats } from '../src/sim/stats';
import { applyEnemyDamage, ROLE_ELITE, ROLE_FODDER } from '../src/sim/enemies';
import { emptyInput } from '../src/sim/input-frame';

describe('Overhauled Item Mechanics & Catalog Uniqueness', () => {
  it('ensures all positive stat hooks and trade-offs in items.json are unique', () => {
    const positiveStats = new Set<string>();
    for (const item of catalog.items) {
      for (const hook of item.hooks) {
        if (hook.op === 'on-kill') {
          expect(positiveStats.has('on-kill:hp')).toBe(false);
          positiveStats.add('on-kill:hp');
        } else if (hook.op === 'on-crit') {
          expect(positiveStats.has('on-crit:cooldown')).toBe(false);
          positiveStats.add('on-crit:cooldown');
        } else {
          const isPositive =
            hook.stat === 'radius' || hook.stat === 'cooldown' ? hook.value < 0 : hook.value > 0;
          if (isPositive) {
            expect(positiveStats.has(hook.stat)).toBe(false);
            positiveStats.add(hook.stat);
          }
        }
      }
    }
  });

  it('correctly resolves new stats in resolveStats', () => {
    const baseStats = { speed: 280, maxHp: 100, radius: 14 };
    const items = [
      { id: 'brittle-plate', stacks: 1 }, // +12% armor
      { id: 'wax-wings', stacks: 1 }, // +35% hazardResist
      { id: 'hungry-clip', stacks: 1 }, // +2.5 hpRegen, +35% controlDuration, +25% radius
      { id: 'mercury-vial', stacks: 1 }, // +35% pickupRadius, +15% xpGain
      { id: 'overclock', stacks: 1 }, // +22% aoeRadius, +20% projSpeed
      { id: 'lunar-tithe', stacks: 1 }, // +60% eliteDamage, +75% critDamage, -25% armor, -25% xpGain
    ];
    const stats = resolveStats(baseStats, items, catalog.item);

    expect(stats.armor).toBeCloseTo(0.12 - 0.25, 4);
    expect(stats.hazardResist).toBeCloseTo(0.35, 4);
    expect(stats.hpRegen).toBeCloseTo(2.5, 4);
    expect(stats.controlDurationMul).toBeCloseTo(1.35, 4);
    expect(stats.pickupRadiusMul).toBeCloseTo(1.35, 4);
    expect(stats.xpMul).toBeCloseTo(1 + 0.15 - 0.25, 4);
    expect(stats.aoeRadiusMul).toBeCloseTo(1.22, 4);
    expect(stats.projSpeedMul).toBeCloseTo(1.2, 4);
    expect(stats.eliteDamageMul).toBeCloseTo(1.6, 4);
  });

  it('applies armor reduction and hazard resistance to damagePlayer', () => {
    const world = createWorld('runner');
    world.stats.armor = 0.2; // 20% damage reduction
    world.stats.hazardResist = 0.5; // 50% hazard reduction

    const initialHp = world.player.hp;
    // Normal damage 10 -> after 20% armor = 8 damage
    damagePlayer(world, 10, false);
    expect(world.player.hp).toBeCloseTo(initialHp - 8, 4);

    // Hazard damage 10 -> after 20% armor (8) and 50% hazard resist = 4 damage
    damagePlayer(world, 10, true);
    expect(world.player.hp).toBeCloseTo(initialHp - 12, 4);
  });

  it('regenerates HP when hpRegen > 0 in stepWorld', () => {
    const world = createWorld('runner');
    world.player.hp = 50;
    world.stats.hpRegen = 10; // 10 HP/s
    const input = emptyInput();
    stepWorld(world, input, 0.5); // 0.5s -> +5 HP
    expect(world.player.hp).toBeCloseTo(55, 3);
  });

  it('applies on-crit cooldown refund and on-kill heal', () => {
    const world = createWorld('runner');
    world.inventory = [
      { id: 'calcined-lens', stacks: 1 }, // 0.25s refund
      { id: 'cinnabar-leech', stacks: 2 }, // 0.6 HP heal
    ];
    world.player.skillCd.primary = 1.0;
    world.player.skillCd.special = 2.0;

    triggerOnCrit(world);
    expect(world.player.skillCd.primary).toBeCloseTo(0.75, 4);
    expect(world.player.skillCd.special).toBeCloseTo(1.75, 4);

    expect(onKillHeal(world.inventory, catalog.item)).toBeCloseTo(0.6, 4);
    expect(onCritCooldownRefund(world.inventory, catalog.item)).toBeCloseTo(0.25, 4);
  });

  it('applies eliteDamageMul to elite and boss targets', () => {
    const world = createWorld('runner');
    world.stats.eliteDamageMul = 1.6; // +60% dmg

    // Fodder enemy
    world.enemies.alive[0] = 1;
    world.enemies.role[0] = ROLE_FODDER;
    world.enemies.hp[0] = 100;
    world.enemies.maxHp[0] = 100;
    applyEnemyDamage(world, 0, 10);
    expect(world.enemies.hp[0]).toBeCloseTo(90, 4);

    // Elite enemy
    world.enemies.alive[1] = 1;
    world.enemies.role[1] = ROLE_ELITE;
    world.enemies.hp[1] = 100;
    world.enemies.maxHp[1] = 100;
    applyEnemyDamage(world, 1, 10);
    expect(world.enemies.hp[1]).toBeCloseTo(100 - 16, 4);
  });
});
