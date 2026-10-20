export type SpatialHash = {
  cell: number;
  buckets: Map<number, number[]>;
  pool: number[][];
  poolUsed: number;
};

export function createHash(cell: number): SpatialHash {
  return { cell, buckets: new Map(), pool: [], poolUsed: 0 };
}

export function hashClear(hash: SpatialHash): void {
  hash.buckets.clear();
  hash.poolUsed = 0;
}

export function hashInsert(hash: SpatialHash, x: number, y: number, index: number): void {
  const cx = Math.floor(x / hash.cell);
  const cy = Math.floor(y / hash.cell);
  const key = cellKey(cx, cy);
  let bucket = hash.buckets.get(key);
  if (!bucket) {
    bucket = hash.pool[hash.poolUsed];
    if (!bucket) {
      bucket = [];
      hash.pool[hash.poolUsed] = bucket;
    } else {
      bucket.length = 0;
    }
    hash.poolUsed += 1;
    hash.buckets.set(key, bucket);
  }
  bucket.push(index);
}

export function hashQuery(
  hash: SpatialHash,
  x: number,
  y: number,
  radius: number,
  out: number[],
): number {
  const { cell } = hash;
  const minCx = Math.floor((x - radius) / cell);
  const maxCx = Math.floor((x + radius) / cell);
  const minCy = Math.floor((y - radius) / cell);
  const maxCy = Math.floor((y + radius) / cell);
  let n = 0;
  for (let cy = minCy; cy <= maxCy; cy += 1) {
    for (let cx = minCx; cx <= maxCx; cx += 1) {
      const bucket = hash.buckets.get(cellKey(cx, cy));
      if (!bucket) continue;
      for (let i = 0; i < bucket.length; i += 1) {
        if (n >= out.length) return n;
        out[n] = bucket[i];
        n += 1;
      }
    }
  }
  return n;
}

function cellKey(cx: number, cy: number): number {
  return ((cx + 4096) & 8191) | (((cy + 4096) & 8191) << 13);
}
