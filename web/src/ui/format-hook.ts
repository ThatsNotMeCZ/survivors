import type { ItemHook, StatId } from '../data/schema';

const STAT_LABEL: Record<StatId, string> = {
  speed: 'Speed',
  maxHp: 'Max HP',
  radius: 'Vessel Size',
  damage: 'Damage',
  cooldown: 'Cooldown',
  critChance: 'Crit Chance',
  critDamage: 'Crit Damage',
  armor: 'Armor',
  hazardResist: 'Hazard Ward',
  hpRegen: 'HP/s Regen',
  pickupRadius: 'Essence Magnet',
  xpGain: 'Essence XP',
  aoeRadius: 'Area Size',
  projSpeed: 'Projectile Speed',
  controlDuration: 'Rite Duration',
  eliteDamage: 'Elite & Boss Damage',
};

export function formatHookNumber(value: number): string {
  if (Number.isInteger(value) || Math.abs(value - Math.round(value)) < 1e-6) {
    return String(Math.round(value));
  }
  if (Math.abs(value * 10 - Math.round(value * 10)) < 1e-6) {
    return (Math.round(value * 10) / 10).toFixed(1);
  }
  return (Math.round(value * 100) / 100).toFixed(2);
}

export function formatHook(hook: ItemHook): { text: string; up: boolean } {
  const sign = hook.value > 0 ? '+' : '';
  const shown = formatHookNumber(hook.value);
  if (hook.op === 'on-kill') {
    return { text: `${sign}${shown} HP on kill`, up: hook.value > 0 };
  }
  if (hook.op === 'on-crit') {
    return { text: `-${shown}s CD on crit`, up: true };
  }
  const amount = hook.op === 'pct' ? `${sign}${Math.round(hook.value * 100)}%` : `${sign}${shown}`;
  const hurt = hook.stat === 'radius' || hook.stat === 'cooldown';
  const up = hook.value === 0 ? true : hurt ? hook.value < 0 : hook.value > 0;
  return { text: `${amount} ${STAT_LABEL[hook.stat]}`, up };
}
