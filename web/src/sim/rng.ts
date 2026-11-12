export function hashString(text: string): number {
  let h = 2166136261;
  for (let i = 0; i < text.length; i += 1) {
    h ^= text.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

export function mulberry32(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export function utcYmd(now = Date.now()): string {
  return new Date(now).toISOString().slice(0, 10);
}

export function dailySeed(date = utcYmd()): number {
  return hashString(`daily:${date}`);
}

export function randomRunSeed(): number {
  return (Math.random() * 0xffffffff) >>> 0;
}

export function formatSeedTag(seed: number): string {
  const hex = (seed >>> 0).toString(16).toUpperCase().padStart(4, '0');
  return `#${hex.slice(-4)}`;
}

export function cycleNumeral(cycleIndex: number): string {
  const values: [number, string][] = [
    [10, 'X'],
    [9, 'IX'],
    [5, 'V'],
    [4, 'IV'],
    [1, 'I'],
  ];
  let rest = Math.max(1, Math.floor(cycleIndex) + 1);
  let out = '';
  for (const [value, glyph] of values) {
    while (rest >= value) {
      out += glyph;
      rest -= value;
    }
  }
  return out;
}
