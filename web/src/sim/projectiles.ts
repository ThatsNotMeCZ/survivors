export const TEAM_PLAYER = 0;
export const TEAM_ENEMY = 1;

export const FLAG_PIERCE = 1;
export const FLAG_FLYOVER = 2;
export const FLAG_TETHER = 4;
export const FLAG_IMPACT = 8;

export type ProjectilePool = {
  alive: Uint8Array;
  team: Uint8Array;
  flags: Uint8Array;
  x: Float32Array;
  y: Float32Array;
  vx: Float32Array;
  vy: Float32Array;
  life: Float32Array;
  radius: Float32Array;
  damage: Float32Array;
  destX: Float32Array;
  destY: Float32Array;
  impactRadius: Float32Array;
  rootDuration: Float32Array;
  tetherDps: Float32Array;
  pierceHit0: Uint32Array;
  pierceHit1: Uint32Array;
};

export type ProjectileSpawn = {
  x: number;
  y: number;
  dirX: number;
  dirY: number;
  speed: number;
  lifetime: number;
  radius: number;
  damage: number;
  team: number;
  flags?: number;
  destX?: number;
  destY?: number;
  impactRadius?: number;
  rootDuration?: number;
  tetherDps?: number;
};

export function createProjectilePool(size: number): ProjectilePool {
  return {
    alive: new Uint8Array(size),
    team: new Uint8Array(size),
    flags: new Uint8Array(size),
    x: new Float32Array(size),
    y: new Float32Array(size),
    vx: new Float32Array(size),
    vy: new Float32Array(size),
    life: new Float32Array(size),
    radius: new Float32Array(size),
    damage: new Float32Array(size),
    destX: new Float32Array(size),
    destY: new Float32Array(size),
    impactRadius: new Float32Array(size),
    rootDuration: new Float32Array(size),
    tetherDps: new Float32Array(size),
    pierceHit0: new Uint32Array(size),
    pierceHit1: new Uint32Array(size),
  };
}

export function spawnProjectile(pool: ProjectilePool, spawn: ProjectileSpawn): boolean {
  for (let i = 0; i < pool.alive.length; i += 1) {
    if (pool.alive[i] !== 0) continue;
    pool.alive[i] = 1;
    pool.team[i] = spawn.team;
    pool.flags[i] = spawn.flags ?? 0;
    pool.x[i] = spawn.x;
    pool.y[i] = spawn.y;
    pool.vx[i] = spawn.dirX * spawn.speed;
    pool.vy[i] = spawn.dirY * spawn.speed;
    pool.life[i] = spawn.lifetime;
    pool.radius[i] = spawn.radius;
    pool.damage[i] = spawn.damage;
    pool.destX[i] = spawn.destX ?? spawn.x;
    pool.destY[i] = spawn.destY ?? spawn.y;
    pool.impactRadius[i] = spawn.impactRadius ?? 0;
    pool.rootDuration[i] = spawn.rootDuration ?? 0;
    pool.tetherDps[i] = spawn.tetherDps ?? 0;
    pool.pierceHit0[i] = 0;
    pool.pierceHit1[i] = 0;
    return true;
  }
  return false;
}

export function stepProjectiles(pool: ProjectilePool, dt: number): void {
  for (let i = 0; i < pool.alive.length; i += 1) {
    if (pool.alive[i] === 0) continue;
    pool.x[i] += pool.vx[i] * dt;
    pool.y[i] += pool.vy[i] * dt;
    pool.life[i] -= dt;
    if (pool.life[i] > 0) continue;
    if ((pool.flags[i] & FLAG_IMPACT) !== 0) continue;
    pool.alive[i] = 0;
  }
}

export function projectileHasHit(pool: ProjectilePool, index: number, enemyIndex: number): boolean {
  const bit = 1 << (enemyIndex & 31);
  if (enemyIndex < 32) return (pool.pierceHit0[index] & bit) !== 0;
  return (pool.pierceHit1[index] & bit) !== 0;
}

export function markProjectileHit(pool: ProjectilePool, index: number, enemyIndex: number): void {
  const bit = 1 << (enemyIndex & 31);
  if (enemyIndex < 32) pool.pierceHit0[index] |= bit;
  else pool.pierceHit1[index] |= bit;
}

export function killProjectile(pool: ProjectilePool, index: number): void {
  pool.alive[index] = 0;
}

export function clearProjectiles(pool: ProjectilePool): void {
  pool.alive.fill(0);
}
