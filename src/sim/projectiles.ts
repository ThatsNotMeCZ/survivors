export const TEAM_PLAYER = 0;
export const TEAM_ENEMY = 1;

export type ProjectilePool = {
  alive: Uint8Array;
  team: Uint8Array;
  x: Float32Array;
  y: Float32Array;
  vx: Float32Array;
  vy: Float32Array;
  life: Float32Array;
  radius: Float32Array;
  damage: Float32Array;
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
};

export function createProjectilePool(size: number): ProjectilePool {
  return {
    alive: new Uint8Array(size),
    team: new Uint8Array(size),
    x: new Float32Array(size),
    y: new Float32Array(size),
    vx: new Float32Array(size),
    vy: new Float32Array(size),
    life: new Float32Array(size),
    radius: new Float32Array(size),
    damage: new Float32Array(size),
  };
}

export function spawnProjectile(pool: ProjectilePool, spawn: ProjectileSpawn): boolean {
  for (let i = 0; i < pool.alive.length; i += 1) {
    if (pool.alive[i] !== 0) continue;
    pool.alive[i] = 1;
    pool.team[i] = spawn.team;
    pool.x[i] = spawn.x;
    pool.y[i] = spawn.y;
    pool.vx[i] = spawn.dirX * spawn.speed;
    pool.vy[i] = spawn.dirY * spawn.speed;
    pool.life[i] = spawn.lifetime;
    pool.radius[i] = spawn.radius;
    pool.damage[i] = spawn.damage;
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
    if (pool.life[i] <= 0) pool.alive[i] = 0;
  }
}

export function killProjectile(pool: ProjectilePool, index: number): void {
  pool.alive[index] = 0;
}

export function clearProjectiles(pool: ProjectilePool): void {
  pool.alive.fill(0);
}
