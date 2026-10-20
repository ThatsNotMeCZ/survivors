export function circlesOverlap(
  ax: number,
  ay: number,
  ar: number,
  bx: number,
  by: number,
  br: number,
): boolean {
  const dx = ax - bx;
  const dy = ay - by;
  const r = ar + br;
  return dx * dx + dy * dy <= r * r;
}

/** Square AABB from center + half-extent (`radius`). */
export function aabbOverlap(
  ax: number,
  ay: number,
  ar: number,
  bx: number,
  by: number,
  br: number,
): boolean {
  return Math.abs(ax - bx) <= ar + br && Math.abs(ay - by) <= ar + br;
}

export function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}

/** Push two circles apart along their shared normal. weightB=0 keeps B static. */
export function pushCircles(
  ax: number,
  ay: number,
  ar: number,
  bx: number,
  by: number,
  br: number,
  weightA: number,
  weightB: number,
): { ax: number; ay: number; bx: number; by: number } {
  const dx = ax - bx;
  const dy = ay - by;
  let dist = Math.hypot(dx, dy);
  const minDist = ar + br;
  if (dist >= minDist) return { ax, ay, bx, by };
  if (dist < 0.0001) {
    return {
      ax: ax + minDist * weightA,
      ay,
      bx: bx - minDist * weightB,
      by,
    };
  }
  const overlap = minDist - dist;
  const nx = dx / dist;
  const ny = dy / dist;
  return {
    ax: ax + nx * overlap * weightA,
    ay: ay + ny * overlap * weightA,
    bx: bx - nx * overlap * weightB,
    by: by - ny * overlap * weightB,
  };
}
