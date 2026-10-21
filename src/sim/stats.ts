import type { ItemDef, ItemInstance, ResolvedStats, StatId, SurvivorStats } from '../data/schema';

const ZERO: Record<StatId, number> = {
  speed: 0,
  maxHp: 0,
  radius: 0,
  damage: 0,
  cooldown: 0,
};

export function resolveStats(
  base: SurvivorStats,
  inventory: ItemInstance[],
  itemOf: (id: string) => ItemDef,
): ResolvedStats {
  const add = { ...ZERO };
  const pct = { ...ZERO };

  for (const inst of inventory) {
    const def = itemOf(inst.id);
    const stacks = def.stack === 'none' ? 1 : Math.max(1, inst.stacks);
    for (const hook of def.hooks) {
      if (hook.op === 'on-kill') continue;
      const amount = hook.value * stacks;
      if (hook.op === 'add') add[hook.stat] += amount;
      else pct[hook.stat] += amount;
    }
  }

  return {
    speed: (base.speed + add.speed) * (1 + pct.speed),
    maxHp: (base.maxHp + add.maxHp) * (1 + pct.maxHp),
    radius: (base.radius + add.radius) * (1 + pct.radius),
    damageMul: (1 + add.damage) * (1 + pct.damage),
    cooldownMul: (1 + add.cooldown) * (1 + pct.cooldown),
  };
}

export function onKillHeal(
  inventory: ItemInstance[],
  itemOf: (id: string) => ItemDef,
): number {
  let heal = 0;
  for (const inst of inventory) {
    const def = itemOf(inst.id);
    const stacks = def.stack === 'none' ? 1 : Math.max(1, inst.stacks);
    for (const hook of def.hooks) {
      if (hook.op === 'on-kill' && hook.stat === 'hp') heal += hook.value * stacks;
    }
  }
  return heal;
}
