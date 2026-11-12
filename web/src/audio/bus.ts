import type { AudioMix } from './types';

export type AudioBus = {
  ctx: AudioContext;
  master: GainNode;
  music: GainNode;
  sfx: GainNode;
};

let bus: AudioBus | null = null;
let pendingMix: AudioMix | null = null;
let unlockBound = false;
let unlockListeners: Array<() => void> = [];
const mixHooks: Array<(mix: AudioMix) => void> = [];

export function onAudioMixApplied(hook: (mix: AudioMix) => void): void {
  mixHooks.push(hook);
}

export function getAudioBus(): AudioBus | null {
  return bus;
}

export function ensureAudioBus(): AudioBus {
  if (bus) return bus;
  const AC =
    window.AudioContext ||
    (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
  const ctx = new AC();
  const master = ctx.createGain();
  const music = ctx.createGain();
  const sfx = ctx.createGain();
  music.connect(master);
  sfx.connect(master);
  master.connect(ctx.destination);
  bus = { ctx, master, music, sfx };
  if (pendingMix) applyAudioSettings(pendingMix);
  return bus;
}

export function applyAudioSettings(mix: AudioMix): void {
  pendingMix = mix;
  if (!bus) {
    if (typeof window === 'undefined') return;
    ensureAudioBus();
  }
  if (!bus) return;
  resumeIfGestured(bus);
  const now = bus.ctx.currentTime;
  const mute = mix.muted ? 0 : 1;
  snap(bus.master.gain, mix.masterVolume * mute, now);
  snap(bus.music.gain, mix.musicVolume, now);
  snap(bus.sfx.gain, mix.sfxVolume, now);
  for (const hook of mixHooks) hook(mix);
}

export function bindAudioUnlock(onUnlock: () => void): void {
  unlockListeners.push(onUnlock);
  if (unlockBound) return;
  unlockBound = true;
  const kick = (): void => {
    const next = ensureAudioBus();
    tickSilent(next);
    void next.ctx.resume().then(() => {
      for (const listener of unlockListeners) listener();
    });
  };
  window.addEventListener('pointerdown', kick);
  window.addEventListener('keydown', kick);
}

function resumeIfGestured(next: AudioBus): void {
  if (next.ctx.state !== 'suspended') return;
  if (!navigator.userActivation?.isActive) return;
  void next.ctx.resume();
}

function snap(param: AudioParam, value: number, now: number): void {
  param.cancelScheduledValues(now);
  param.setValueAtTime(value, now);
}

function tickSilent(next: AudioBus): void {
  const buffer = next.ctx.createBuffer(1, 1, next.ctx.sampleRate);
  const src = next.ctx.createBufferSource();
  src.buffer = buffer;
  src.connect(next.ctx.destination);
  src.start();
}
