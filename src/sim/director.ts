import { countSnipers, spawnAround } from './enemies';
import type { World } from './world';

export function stepDirector(world: World, dt: number): void {
  const { loop } = world.catalog;
  const stage = loop.stages[world.stageIndex];
  world.credits += loop.director.creditRate * world.coefficient * dt;

  tryFodder(world);
  trySniper(world);
  if (world.bossSpawned) return;
  if (world.stageTime >= stage.firstEliteAt) {
    tryElite(world);
  }
}

function tryFodder(world: World): void {
  const { loop } = world.catalog;
  const stage = loop.stages[world.stageIndex];
  if (world.counts.fodder >= loop.maxFodder) return;
  if (world.credits < loop.director.fodderCost) return;
  if (world.stageTime - world.lastFodderAt < loop.director.fodderInterval) return;
  const rangedId = stage.ranged;
  const useRanged = Boolean(rangedId) && Math.random() < (stage.rangedChance ?? 0);
  const id = useRanged && rangedId ? rangedId : stage.fodder;
  const spawned = spawnAround(world, world.catalog.entity(id));
  if (spawned < 0) return;
  world.credits -= loop.director.fodderCost;
  world.lastFodderAt = world.stageTime;
}

function trySniper(world: World): void {
  const { loop } = world.catalog;
  const stage = loop.stages[world.stageIndex];
  if (!stage.sniper) return;
  if (world.counts.fodder >= loop.maxFodder) return;
  if (countSnipers(world) >= loop.director.maxSnipers) return;
  if (world.credits < loop.director.sniperCost) return;
  if (world.stageTime - world.lastSniperAt < loop.director.sniperInterval) return;
  const spawned = spawnAround(world, world.catalog.entity(stage.sniper));
  if (spawned < 0) return;
  world.credits -= loop.director.sniperCost;
  world.lastSniperAt = world.stageTime;
}

function tryElite(world: World): void {
  const { loop } = world.catalog;
  const stage = loop.stages[world.stageIndex];
  const cap = world.teleporter.state === 'hidden' ? 1 : loop.maxElites;
  if (world.counts.elite >= cap) return;
  if (world.credits < loop.director.eliteCost) return;
  if (world.stageTime - world.lastEliteAt < loop.director.eliteInterval) return;
  const spawned = spawnAround(world, world.catalog.entity(stage.elite));
  if (spawned < 0) return;
  world.credits -= loop.director.eliteCost;
  world.lastEliteAt = world.stageTime;
}
