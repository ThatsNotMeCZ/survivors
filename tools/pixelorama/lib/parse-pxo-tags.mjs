/**
 * Pixelorama project JSON → compact anim sidecar.
 * Rules match web/scripts/sprite-manifest.ts (tags are 1-based inclusive).
 */

function integerValue(value) {
  return typeof value === 'number' && Number.isInteger(value) ? value : undefined;
}

function positiveInt(value) {
  const n = integerValue(value);
  return n !== undefined && n > 0 ? n : undefined;
}

function positiveNumber(value) {
  return typeof value === 'number' && Number.isFinite(value) && value > 0 ? value : undefined;
}

function frameRange(from, to) {
  const start = Math.min(from, to);
  const end = Math.max(from, to);
  if (!Number.isInteger(start) || !Number.isInteger(end) || start < 0) return [];
  return Array.from({ length: end - start + 1 }, (_, i) => start + i);
}

function isOneShotAnimName(name) {
  return (
    name !== 'idle' &&
    name !== 'walk' &&
    !name.startsWith('idle-') &&
    !name.startsWith('walk-') &&
    !name.startsWith('channel')
  );
}

function frameDurations(value) {
  if (!Array.isArray(value)) return [];
  return value.map((entry) => {
    if (!entry || typeof entry !== 'object') return 1;
    const duration = entry.duration;
    return typeof duration === 'number' && duration > 0 ? duration : 1;
  });
}

function tagFrameRate(frames, fps, durations, durationsMs) {
  const used = frames
    .map((index) => durations[index])
    .filter((value) => value !== undefined && value > 0);
  if (used.length === 0) return fps;
  const uniform = used.every((d) => d === used[0]);
  if (uniform) return fps / used[0];
  if (durationsMs && durationsMs.length > 0) {
    const avgMs = durationsMs.reduce((sum, ms) => sum + ms, 0) / durationsMs.length;
    if (avgMs > 0) return Math.round((1000 / avgMs) * 100) / 100;
  }
  const avg = used.reduce((sum, value) => sum + value, 0) / used.length;
  return fps / avg;
}

function parseTags(value, opts) {
  if (!Array.isArray(value)) return undefined;
  const out = {};
  for (const entry of value) {
    if (!entry || typeof entry !== 'object') continue;
    if (typeof entry.name !== 'string' || entry.name.length === 0) continue;
    const from = integerValue(entry.from);
    const to = integerValue(entry.to);
    if (from === undefined || to === undefined) continue;
    const start = opts.oneIndexed ? from - 1 : from;
    const end = opts.oneIndexed ? to - 1 : to;
    const frames = frameRange(start, end);
    if (frames.length === 0) continue;
    const name = entry.name.trim().toLowerCase();
    const perFrameMs =
      opts.durationsMs &&
      frames.every((idx) => typeof opts.durationsMs[idx] === 'number' && opts.durationsMs[idx] > 0)
        ? frames.map((idx) => opts.durationsMs[idx])
        : undefined;
    const hasUnevenDurations = perFrameMs !== undefined && perFrameMs.some((ms) => ms !== perFrameMs[0]);
    const explicitRepeat = typeof entry.repeat === 'number' ? entry.repeat : undefined;
    out[name] = {
      frames,
      frameRate: tagFrameRate(frames, opts.fps, opts.durations, perFrameMs),
      repeat: explicitRepeat !== undefined ? explicitRepeat : isOneShotAnimName(name) ? 0 : -1,
      ...(hasUnevenDurations ? { durations: perFrameMs } : {}),
    };
  }
  if (!out.idle) out.idle = { frames: [0], frameRate: 1, repeat: -1 };
  return Object.keys(out).length > 0 ? out : undefined;
}

export function isPixeloramaProject(rec) {
  if (!rec || typeof rec !== 'object') return false;
  return (
    typeof rec.pixelorama_version === 'string' ||
    typeof rec.pxo_version === 'number' ||
    (positiveInt(rec.size_x) !== undefined && Array.isArray(rec.tags) && Array.isArray(rec.frames))
  );
}

export function isCompactSidecar(rec) {
  if (!rec || typeof rec !== 'object') return false;
  if (isPixeloramaProject(rec)) return false;
  const hasSize = positiveInt(rec.frameWidth) !== undefined || positiveInt(rec.frameHeight) !== undefined;
  const hasAnims = rec.anims && typeof rec.anims === 'object';
  return hasSize || hasAnims;
}

export function parsePixeloramaProject(rec) {
  if (!isPixeloramaProject(rec)) return null;
  const frameWidth = positiveInt(rec.size_x);
  const frameHeight = positiveInt(rec.size_y);
  const fps = positiveNumber(rec.fps) ?? 8;
  const durations = frameDurations(rec.frames);
  const durationsMs = durations.map((d) => Math.round((d / Math.max(1, fps)) * 1000));
  const anims = parseTags(rec.tags, { oneIndexed: true, fps, durations, durationsMs });
  if (!frameWidth && !frameHeight && !anims) return null;
  return { frameWidth, frameHeight, anims };
}

function orderAnims(anims) {
  if (!anims || typeof anims !== 'object') return anims;
  const out = {};
  for (const key of ['idle', 'walk']) {
    if (anims[key]) out[key] = anims[key];
  }
  for (const key of Object.keys(anims)) {
    if (key !== 'idle' && key !== 'walk') out[key] = anims[key];
  }
  return out;
}

export function formatCompactSidecar(sidecar) {
  const ordered = sidecar.anims ? { ...sidecar, anims: orderAnims(sidecar.anims) } : sidecar;
  return `${JSON.stringify(ordered, null, 2).replace(
    /\[\n\s+(\d+(?:,\n\s+\d+)*)\n\s+\]/g,
    (_m, inner) => `[${inner.split(',').map((s) => s.trim()).join(', ')}]`,
  )}\n`;
}

export function toCompactSidecar(rec) {
  if (isCompactSidecar(rec)) {
    return {
      ...(positiveInt(rec.frameWidth) ? { frameWidth: rec.frameWidth } : {}),
      ...(positiveInt(rec.frameHeight) ? { frameHeight: rec.frameHeight } : {}),
      ...(rec.anims && typeof rec.anims === 'object' ? { anims: orderAnims(rec.anims) } : {}),
    };
  }
  const parsed = parsePixeloramaProject(rec);
  if (!parsed) return null;
  const out = {};
  if (parsed.frameWidth) out.frameWidth = parsed.frameWidth;
  if (parsed.frameHeight) out.frameHeight = parsed.frameHeight;
  if (parsed.anims) out.anims = orderAnims(parsed.anims);
  return Object.keys(out).length > 0 ? out : null;
}
