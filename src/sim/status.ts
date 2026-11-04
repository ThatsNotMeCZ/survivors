import type { EnemyPool } from './enemies';

export type SlowState = {
  slowRemain: number;
  slowMul: number;
  rootRemain?: number;
};

export function applyRoot(state: { rootRemain: number }, duration: number): void {
  if (duration <= 0) return;
  state.rootRemain = Math.max(state.rootRemain, duration);
}

export function tickRoot(state: { rootRemain: number }, dt: number): void {
  if (state.rootRemain > 0) {
    state.rootRemain = Math.max(0, state.rootRemain - dt);
  }
}

export function applySlow(state: SlowState, mul: number, duration: number): void {
  if (duration <= 0 || mul >= 1) return;
  if (state.slowRemain <= 0 || mul <= state.slowMul) {
    state.slowMul = mul;
    state.slowRemain = Math.max(state.slowRemain, duration);
  }
}

export function tickSlow(state: SlowState, dt: number): void {
  if (state.slowRemain <= 0) {
    state.slowMul = 1;
    return;
  }
  state.slowRemain = Math.max(0, state.slowRemain - dt);
  if (state.slowRemain <= 0) state.slowMul = 1;
}

export function applyEnemySlow(enemies: EnemyPool, index: number, mul: number, duration: number): void {
  if (duration <= 0 || mul >= 1) return;
  if (enemies.slowRemain[index] <= 0 || mul <= enemies.slowMul[index]) {
    enemies.slowMul[index] = mul;
    enemies.slowRemain[index] = Math.max(enemies.slowRemain[index], duration);
  }
}

export function tickEnemySlow(enemies: EnemyPool, index: number, dt: number): void {
  if (enemies.slowRemain[index] <= 0) {
    enemies.slowMul[index] = 1;
    return;
  }
  enemies.slowRemain[index] = Math.max(0, enemies.slowRemain[index] - dt);
  if (enemies.slowRemain[index] <= 0) enemies.slowMul[index] = 1;
}
