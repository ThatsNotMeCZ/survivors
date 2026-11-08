import { FX_CAP } from '../config';

export type FxPool = {
  cap: number;
  count: number;
  kind: Uint8Array;
  x: Float32Array;
  y: Float32Array;
  tint: Uint32Array;
  radius: Float32Array;
};

export function createFxPool(cap = FX_CAP): FxPool {
  return {
    cap,
    count: 0,
    kind: new Uint8Array(cap),
    x: new Float32Array(cap),
    y: new Float32Array(cap),
    tint: new Uint32Array(cap),
    radius: new Float32Array(cap),
  };
}

export function emitFx(
  pool: FxPool,
  kind: number,
  x: number,
  y: number,
  tint: number,
  radius = 0,
): void {
  if (pool.count >= pool.cap) return;
  const i = pool.count;
  pool.kind[i] = kind;
  pool.x[i] = x;
  pool.y[i] = y;
  pool.tint[i] = tint;
  pool.radius[i] = radius;
  pool.count += 1;
}

export function clearFx(pool: FxPool): void {
  pool.count = 0;
}
