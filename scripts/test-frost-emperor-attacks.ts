import { emptyInput } from '../src/sim/input-frame';
import { createWorld, stepWorld } from '../src/sim/world';
import { spawnEnemy, ROLE_BOSS, ROLE_FODDER } from '../src/sim/enemies';
import { spawnObstacle } from '../src/sim/obstacles';
import { stepBoss } from '../src/sim/boss';
import { spawnBossPulse } from '../src/sim/boss-hazards';
import { resolveBodyOverlaps } from '../src/sim/separation';

function runTests() {
  console.log('--- Testing Frost Emperor Attack Mechanics ---');

  // Test 1: Laser starts at boss muzzle and travels outward, player is not hit at t=0
  {
    const world = createWorld();
    world.stageIndex = 2; // Glacial Tomb
    const bossDef = world.catalog.entity('frost-emperor');
    const bossIdx = spawnEnemy(world, bossDef, 400, 400);
    if (bossIdx < 0) throw new Error('Failed to spawn Frost Emperor');

    // Place player at keep distance (e.g. 400, 680 - 280px away)
    world.player.x = 400;
    world.player.y = 680;
    world.player.hp = 100;
    world.player.iframeRemain = 0;

    const laserAtkIndex = bossDef.ai.type === 'boss'
      ? bossDef.ai.attacks.findIndex((a) => a.type === 'laser')
      : -1;
    if (laserAtkIndex < 0) throw new Error('Laser attack not found on Frost Emperor');

    // Force boss cooldowns so laser is ready
    world.boss.enemyIndex = bossIdx;
    world.boss.cooldowns.fill(999);
    world.boss.cooldowns[laserAtkIndex] = 0;

    const dt = 1 / 60;
    const input = emptyInput();

    // Step boss until windup completes
    const laserAtk = bossDef.ai.type === 'boss' ? bossDef.ai.attacks[laserAtkIndex] : null;
    const windup = laserAtk?.windup ?? 0.8;

    const stepBossFrame = () => {
      const dx = world.player.x - world.enemies.x[bossIdx];
      const dy = world.player.y - world.enemies.y[bossIdx];
      const len = Math.hypot(dx, dy);
      stepBoss(world, bossIdx, bossDef.ai, dx, dy, len, dt, bossDef.stats.speed);
    };

    // Trigger windup
    stepBossFrame();
    if (world.boss.phase !== 'windup') throw new Error(`Expected windup, got ${world.boss.phase}`);

    // Advance through windup
    const windupFrames = Math.ceil(windup / dt) + 2;
    for (let f = 0; f < windupFrames; f++) {
      stepBossFrame();
    }

    if (world.boss.phase !== 'channel') {
      throw new Error(`Expected channel phase, got ${world.boss.phase}`);
    }

    // Verify aimX and aimY started near boss (not at player 400, 680!)
    const muzzleDistFromBoss = Math.hypot(world.boss.aimX - 400, world.boss.aimY - 400);
    console.log(`Laser channel start: aim distance from boss = ${muzzleDistFromBoss.toFixed(1)}px (expected ~55px muzzle)`);
    if (muzzleDistFromBoss > 80) {
      throw new Error(`Laser spawned too far from boss: ${muzzleDistFromBoss}px!`);
    }

    // Verify player has taken 0 damage at frame 0 of channel
    if (world.player.hp < 100) {
      throw new Error(`Player took damage on laser spawn: hp=${world.player.hp}`);
    }

    // Step 20 frames of channel: verify laser progresses towards player
    const prevDist = Math.hypot(world.player.x - world.boss.aimX, world.player.y - world.boss.aimY);
    for (let f = 0; f < 20; f++) {
      stepBossFrame();
    }
    const newDist = Math.hypot(world.player.x - world.boss.aimX, world.player.y - world.boss.aimY);
    console.log(`Laser progression: dist to player before=${prevDist.toFixed(1)}px, after 20 frames=${newDist.toFixed(1)}px`);
    if (newDist >= prevDist) {
      throw new Error('Laser did not progress towards player during channel!');
    }
    console.log('✓ Test 1 Passed: Laser starts at boss muzzle and smoothly tracks player');
  }

  // Test 2: Absolute Zero Pulse is blocked behind pillar
  {
    const world = createWorld();
    world.stageIndex = 2;
    // Clear obstacles
    world.obstacles.alive.fill(0);

    // Place a pillar at (400, 400)
    spawnObstacle(world, 'pillar', 400, 400, 'Glacial Monolith');

    // Boss pulse center at (400, 200) - 200px North of pillar
    // Player at (400, 442) - directly behind pillar (South)
    world.player.x = 400;
    world.player.y = 442;
    world.player.hp = 100;
    world.player.iframeRemain = 0;

    spawnBossPulse(world.bossHazards, {
      x: 400,
      y: 200,
      radius: 600,
      windup: 0.1,
      damage: 48,
      slowMul: 0.35,
      slowDuration: 2.5,
    });

    const dt = 0.05;
    const input = emptyInput();
    // Step until pulse detonates
    stepWorld(world, input, dt);
    stepWorld(world, input, dt);
    stepWorld(world, input, dt);

    if (world.player.hp < 100) {
      throw new Error(`Pulse dealt damage through pillar! hp=${world.player.hp}`);
    }
    console.log('✓ Test 2 Passed: Pulse completely blocked directly behind pillar');

    // Test 2b: Player slightly off-center (offset 25px sideways, still visually behind 64px pillar)
    world.player.x = 425; // 25px sideways
    world.player.y = 442;
    world.player.hp = 100;

    spawnBossPulse(world.bossHazards, {
      x: 400,
      y: 200,
      radius: 600,
      windup: 0.1,
      damage: 48,
      slowMul: 0.35,
      slowDuration: 2.5,
    });

    stepWorld(world, input, dt);
    stepWorld(world, input, dt);
    stepWorld(world, input, dt);

    if (world.player.hp < 100) {
      throw new Error(`Pulse dealt damage when player was in visual cover behind pillar! hp=${world.player.hp}`);
    }
    console.log('✓ Test 2b Passed: Pulse blocked with generous cover tolerance behind pillar');
  }

  // Test 3: Absolute Zero Pulse deals damage when player is in the open
  {
    const world = createWorld();
    world.stageIndex = 2;
    world.obstacles.alive.fill(0);

    world.player.x = 400;
    world.player.y = 500;
    world.player.hp = 100;
    world.player.iframeRemain = 0;

    spawnBossPulse(world.bossHazards, {
      x: 400,
      y: 200,
      radius: 600,
      windup: 0.1,
      damage: 48,
      slowMul: 0.35,
      slowDuration: 2.5,
    });

    const dt = 0.05;
    const input = emptyInput();
    stepWorld(world, input, dt);
    stepWorld(world, input, dt);
    stepWorld(world, input, dt);

    if (world.player.hp >= 100) {
      throw new Error('Pulse failed to damage player in the open!');
    }
    console.log(`✓ Test 3 Passed: Pulse damages player in open arena (hp reduced to ${world.player.hp.toFixed(1)})`);
  }

  // Test 4: Boss separation immunity from minions
  {
    const world = createWorld();
    const bossDef = world.catalog.entity('frost-emperor');
    const bossIdx = spawnEnemy(world, bossDef, 500, 500);

    const miteDef = world.catalog.entity('frost-mite');
    const miteIdx = spawnEnemy(world, miteDef, 505, 500); // overlapping with boss

    resolveBodyOverlaps(world);

    if (Math.abs(world.enemies.x[bossIdx] - 500) > 0.001 || Math.abs(world.enemies.y[bossIdx] - 500) > 0.001) {
      throw new Error(`Boss was pushed by mite! boss.x=${world.enemies.x[bossIdx]}`);
    }
    if (world.enemies.x[miteIdx] <= 505) {
      throw new Error('Mite was not pushed away from boss!');
    }
    console.log('✓ Test 4 Passed: Boss has infinite inertia and is not displaced by minions');
  }

  console.log('ALL TESTS PASSED!');
}

runTests();
