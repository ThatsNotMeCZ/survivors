import { ensureAudioBus, getAudioBus } from './bus';
import type { AudioManifest, SfxClip, SfxId } from './types';

const VOICE_CAP = 12;
const WINDOW_MS = 1000;
const DEFAULT_VOLUME = 1;
const MAX_VOLUME = 2;
const RATE: Partial<Record<SfxId, number>> = {
  hit: 8,
  death: 6,
  gem: 10,
  muzzle: 12,
};

const buffers = new Map<string, AudioBuffer>();
const recent = new Map<SfxId, number[]>();
let voices = 0;
let clips: Record<string, SfxClip> = {};

export function initSfx(manifest: AudioManifest): void {
  clips = {};
  for (const [id, clip] of Object.entries(manifest.sfx)) {
    clips[id] = { src: clip.src, volume: clampVolume(clip.volume) };
  }
  const bus = ensureAudioBus();
  for (const [id, clip] of Object.entries(clips)) {
    void loadBuffer(bus.ctx, id, clip.src);
  }
}

export function playSfx(id: SfxId): void {
  const bus = getAudioBus();
  const buffer = buffers.get(id);
  const clip = clips[id];
  if (!bus || !buffer || !clip) return;
  if (voices >= VOICE_CAP) return;
  if (!allowed(id)) return;
  const src = bus.ctx.createBufferSource();
  src.buffer = buffer;
  const gain = bus.ctx.createGain();
  gain.gain.value = clip.volume;
  src.connect(gain);
  gain.connect(bus.sfx);
  voices += 1;
  src.onended = () => {
    voices = Math.max(0, voices - 1);
  };
  src.start();
}

function clampVolume(value: number | undefined): number {
  if (typeof value !== 'number' || !Number.isFinite(value)) return DEFAULT_VOLUME;
  return Math.min(MAX_VOLUME, Math.max(0, value));
}

function allowed(id: SfxId): boolean {
  const cap = RATE[id];
  if (!cap) return true;
  const now = performance.now();
  const times = (recent.get(id) ?? []).filter((stamp) => now - stamp < WINDOW_MS);
  if (times.length >= cap) {
    recent.set(id, times);
    return false;
  }
  times.push(now);
  recent.set(id, times);
  return true;
}

async function loadBuffer(ctx: AudioContext, id: string, rel: string): Promise<void> {
  try {
    const href = new URL(encodeURI(rel), document.baseURI).href;
    const res = await fetch(href);
    if (!res.ok) return;
    const raw = await res.arrayBuffer();
    const buffer = await ctx.decodeAudioData(raw);
    buffers.set(id, buffer);
  } catch {
    /* missing / decode error — stay silent */
  }
}
