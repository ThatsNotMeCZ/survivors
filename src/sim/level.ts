import type { ItemDef, ItemRarity } from '../data/schema';
import { resolveStats } from './stats';
import type { World } from './world';

export function xpForLevel(xpBase: number, xpGrowth: number, level: number): number {
  return Math.round(xpBase * xpGrowth ** (level - 1));
}

export function grantXp(world: World, amount: number): void {
  if (amount <= 0) return;
  const { loop } = world.catalog;
  world.xp += amount;
  while (world.xp >= world.xpNeed) {
    world.xp -= world.xpNeed;
    world.level += 1;
    world.pendingLevels += 1;
    world.xpNeed = xpForLevel(loop.xpBase, loop.xpGrowth, world.level);
  }
  if (world.pendingLevels > 0 && world.phase === 'play') {
    world.phase = 'levelup';
    world.offer = rollChoices(world);
  }
}

export function rollChoices(world: World): ItemDef[] {
  const count = world.catalog.loop.levelChoices;
  const noneOwned = new Set(
    world.inventory.filter((inst) => world.catalog.item(inst.id).stack === 'none').map((inst) => inst.id),
  );
  const pool = world.catalog.items.filter((item) => !noneOwned.has(item.id));
  const picked: ItemDef[] = [];
  const used = new Set<string>();
  for (let n = 0; n < count; n += 1) {
    const item = weightedPick(
      pool.filter((entry) => !used.has(entry.id)),
      world.catalog.loop.rarityWeight,
    );
    if (!item) break;
    used.add(item.id);
    picked.push(item);
  }
  return picked;
}

export function applyLevelChoice(world: World, index: number): boolean {
  if (world.phase !== 'levelup' || !world.offer) return false;
  const pick = world.offer[index];
  if (!pick) return false;
  addItem(world, pick.id);
  syncStats(world);
  world.pendingLevels = Math.max(0, world.pendingLevels - 1);
  if (world.pendingLevels > 0) {
    world.offer = rollChoices(world);
    return true;
  }
  world.offer = null;
  world.phase = world.won ? 'victory' : 'play';
  return true;
}

export function syncStats(world: World): void {
  const prevMax = world.player.maxHp;
  world.stats = resolveStats(world.survivor.stats, world.inventory, world.catalog.item);
  const nextMax = world.stats.maxHp;
  world.player.maxHp = nextMax;
  world.player.radius = world.stats.radius;
  world.player.speed = world.stats.speed;
  world.player.hp = Math.min(nextMax, Math.max(1, world.player.hp + (nextMax - prevMax)));
}

function addItem(world: World, id: string): void {
  const def = world.catalog.item(id);
  const existing = world.inventory.find((inst) => inst.id === id);
  if (existing && def.stack === 'linear') {
    existing.stacks += 1;
    return;
  }
  if (!existing) {
    world.inventory.push({ id, stacks: 1 });
  }
}

function weightedPick(pool: ItemDef[], weights: Record<ItemRarity, number>): ItemDef | null {
  if (pool.length === 0) return null;
  let total = 0;
  for (const item of pool) total += weights[item.rarity] ?? 1;
  let roll = Math.random() * total;
  for (const item of pool) {
    roll -= weights[item.rarity] ?? 1;
    if (roll <= 0) return item;
  }
  return pool[pool.length - 1];
}
