import { clamp } from './collision';
import { countSnipers, spawnGroupAround } from './enemies';
import type { World } from './world';

export function currentEliteChance(world: World): number {
  const { eliteChanceBase, eliteChancePerCoeff, eliteChanceMax } = world.catalog.loop.director;
  const chance = eliteChanceBase + Math.max(0, world.coefficient - 1) * eliteChancePerCoeff;
  return clamp(chance, 0, eliteChanceMax);
}

export function stepDirector(world: World, dt: number): void {
  if (world.bossSpawned || world.bossDefeated) return;
  const { loop } = world.catalog;
  const stage = loop.stages[world.stageIndex];
  world.credits += loop.director.creditRate * world.coefficient * dt;

  tryFodder(world);
  trySniper(world);
  if (world.stageTime >= stage.firstEliteAt) {
    tryWarden(world);
  }
}

function tryFodder(world: World): void {
  const { loop } = world.catalog;
  const stage = loop.stages[world.stageIndex];
  if (world.stageTime - world.lastFodderAt < loop.director.fodderInterval) return;

  const rangedId = stage.ranged;
  const useRanged = Boolean(rangedId) && Math.random() < (stage.rangedChance ?? 0);
  const id = useRanged && rangedId ? rangedId : stage.fodder;
  const def = world.catalog.entity(id);

  if (trySpawnGroup(world, def, loop.director.fodderCost)) {
    world.lastFodderAt = world.stageTime;
  }
}

function trySniper(world: World): void {
  const { loop } = world.catalog;
  const stage = loop.stages[world.stageIndex];
  if (!stage.sniper) return;
  const activeSnipers = countSnipers(world);
  if (activeSnipers >= loop.director.maxSnipers) return;
  if (world.stageTime - world.lastSniperAt < loop.director.sniperInterval) return;

  const maxAllowed = loop.director.maxSnipers - activeSnipers;
  const def = world.catalog.entity(stage.sniper);
  if (trySpawnGroup(world, def, loop.director.sniperCost, maxAllowed)) {
    world.lastSniperAt = world.stageTime;
  }
}

function tryWarden(world: World): void {
  const { loop } = world.catalog;
  const stage = loop.stages[world.stageIndex];
  if (world.stageTime - world.lastEliteAt < loop.director.eliteInterval) return;

  const def = world.catalog.entity(stage.elite);
  if (trySpawnGroup(world, def, loop.director.eliteCost)) {
    world.lastEliteAt = world.stageTime;
  }
}

function trySpawnGroup(
  world: World,
  def: ReturnType<World['catalog']['entity']>,
  baseCost: number,
  hardCap?: number,
): boolean {
  const { loop } = world.catalog;
  const stage = loop.stages[world.stageIndex];
  const dir = loop.director;
  const eliteCap = world.teleporter.state === 'hidden' ? 1 : loop.maxElites;
  const eliteCost = baseCost * dir.eliteCostMul;
  const canBeElite =
    world.stageTime >= stage.firstEliteAt &&
    world.counts.elite < eliteCap &&
    world.credits >= eliteCost;
  const rollElite = canBeElite && Math.random() < currentEliteChance(world);

  if (rollElite) {
    const remainingCap = eliteCap - world.counts.elite;
    let targetCount = randomInt(dir.eliteGroupSizeMin, dir.eliteGroupSizeMax);
    if (hardCap !== undefined) targetCount = Math.min(targetCount, hardCap);
    targetCount = Math.min(targetCount, remainingCap);
    const affordableCount = Math.floor(world.credits / eliteCost);
    targetCount = Math.min(targetCount, affordableCount);
    if (targetCount <= 0) return false;

    const spawned = spawnGroupAround(world, def, targetCount, true);
    if (spawned <= 0) return false;

    world.credits -= spawned * eliteCost;
    return true;
  }

  // Normal group spawn
  if (world.counts.fodder >= loop.maxFodder) return false;
  if (world.credits < baseCost) return false;

  const remainingFodderCap = loop.maxFodder - world.counts.fodder;
  let targetCount = randomInt(dir.groupSizeMin, dir.groupSizeMax);
  if (hardCap !== undefined) targetCount = Math.min(targetCount, hardCap);
  targetCount = Math.min(targetCount, remainingFodderCap);
  const affordableCount = Math.floor(world.credits / baseCost);
  targetCount = Math.min(targetCount, affordableCount);
  if (targetCount <= 0) return false;

  const spawned = spawnGroupAround(world, def, targetCount, false);
  if (spawned <= 0) return false;

  world.credits -= spawned * baseCost;
  return true;
}

function randomInt(min: number, max: number): number {
  return min + Math.floor(Math.random() * (max - min + 1));
}
