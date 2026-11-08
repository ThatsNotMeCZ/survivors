import type { ItemDef, ItemInstance, ResolvedStats, StatId, SurvivorStats } from '../data/schema';

export const MIN_RADIUS_RATIO = 0.5;
export const MAX_RADIUS_RATIO = 2.0;

const ZERO: Record<StatId, number> = {
  speed: 0,
  maxHp: 0,
  radius: 0,
  damage: 0,
  cooldown: 0,
  critChance: 0,
  critDamage: 0,
  armor: 0,
  hazardResist: 0,
  hpRegen: 0,
  pickupRadius: 0,
  xpGain: 0,
  aoeRadius: 0,
  projSpeed: 0,
  controlDuration: 0,
  eliteDamage: 0,
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
      if (hook.op === 'on-kill' || hook.op === 'on-crit') continue;
      const amount = hook.value * stacks;
      if (hook.op === 'add') add[hook.stat] += amount;
      else pct[hook.stat] += amount;
    }
  }

  const baseRadius = base.radius || 14;
  const rawRadius = (base.radius + add.radius) * (1 + pct.radius);
  const minRadius = Math.max(1, baseRadius * MIN_RADIUS_RATIO);
  const maxRadius = Math.max(minRadius, baseRadius * MAX_RADIUS_RATIO);
  const radius = Math.max(minRadius, Math.min(maxRadius, rawRadius));

  return {
    speed: (base.speed + add.speed) * (1 + pct.speed),
    maxHp: (base.maxHp + add.maxHp) * (1 + pct.maxHp),
    radius,
    damageMul: (1 + add.damage) * (1 + pct.damage),
    cooldownMul: (1 + add.cooldown) * (1 + pct.cooldown),
    critChance: Math.max(0, Math.min(1, (base.critChance ?? 0.05) + add.critChance + pct.critChance)),
    critMul: Math.max(1, (base.critDamage ?? 2.0) + add.critDamage + pct.critDamage),
    armor: Math.max(-1.0, Math.min(0.75, add.armor + pct.armor)),
    hazardResist: Math.max(0, Math.min(0.85, add.hazardResist + pct.hazardResist)),
    hpRegen: Math.max(0, add.hpRegen * (1 + pct.hpRegen)),
    pickupRadiusMul: Math.max(0.25, (1 + add.pickupRadius) * (1 + pct.pickupRadius)),
    xpMul: Math.max(0.1, (1 + add.xpGain) * (1 + pct.xpGain)),
    aoeRadiusMul: Math.max(0.25, (1 + add.aoeRadius) * (1 + pct.aoeRadius)),
    projSpeedMul: Math.max(0.25, (1 + add.projSpeed) * (1 + pct.projSpeed)),
    controlDurationMul: Math.max(0.25, (1 + add.controlDuration) * (1 + pct.controlDuration)),
    eliteDamageMul: Math.max(0.25, (1 + add.eliteDamage) * (1 + pct.eliteDamage)),
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

export function onCritCooldownRefund(
  inventory: ItemInstance[],
  itemOf: (id: string) => ItemDef,
): number {
  let refund = 0;
  for (const inst of inventory) {
    const def = itemOf(inst.id);
    const stacks = def.stack === 'none' ? 1 : Math.max(1, inst.stacks);
    for (const hook of def.hooks) {
      if (hook.op === 'on-crit' && hook.stat === 'cooldown') refund += hook.value * stacks;
    }
  }
  return refund;
}
