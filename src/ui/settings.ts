import { applyAudioSettings, getAudioBus } from '../audio/bus';
import { retryMusicPlay } from '../audio/music';

export type GameSettings = {
  masterVolume: number;
  sfxVolume: number;
  musicVolume: number;
  muted: boolean;
  screenshake: boolean;
  reduceVfx: boolean;
  survivorId: string;
};

const STORAGE_KEY = 'survivors.settings.v1';

const DEFAULTS: GameSettings = {
  masterVolume: 0.7,
  sfxVolume: 0.8,
  musicVolume: 0.6,
  muted: false,
  screenshake: true,
  reduceVfx: false,
  survivorId: 'runner',
};

let cached: GameSettings | null = null;

export function getSettings(): GameSettings {
  if (cached) return cached;
  cached = { ...DEFAULTS, ...readStored() };
  cached.masterVolume = clamp01(cached.masterVolume);
  cached.sfxVolume = clamp01(cached.sfxVolume ?? DEFAULTS.sfxVolume);
  cached.musicVolume = clamp01(cached.musicVolume ?? DEFAULTS.musicVolume);
  return cached;
}

export function patchSettings(partial: Partial<GameSettings>): GameSettings {
  const next = { ...getSettings(), ...partial };
  next.masterVolume = clamp01(next.masterVolume);
  next.sfxVolume = clamp01(next.sfxVolume);
  next.musicVolume = clamp01(next.musicVolume);
  cached = next;
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(next));
  } catch {
    /* private mode / blocked storage */
  }
  applySettingsToDom(next);
  applyAudioSettings(next);
  void getAudioBus()?.ctx.resume().then(() => retryMusicPlay());
  return next;
}

export function applySettingsToDom(settings = getSettings()): void {
  if (typeof document === 'undefined') return;
  document.documentElement.dataset.muted = settings.muted ? '1' : '0';
  document.documentElement.dataset.reduceVfx = settings.reduceVfx ? '1' : '0';
  document.documentElement.dataset.screenshake = settings.screenshake ? '1' : '0';
  document.documentElement.style.setProperty('--master-volume', String(settings.masterVolume));
  document.documentElement.style.setProperty('--sfx-volume', String(settings.sfxVolume));
  document.documentElement.style.setProperty('--music-volume', String(settings.musicVolume));
}

export function hasQueryFlag(name: string): boolean {
  if (typeof window === 'undefined') return false;
  return new URLSearchParams(window.location.search).has(name);
}

/** GPU smoke (`?smoke=1`) and `?dev=1` skip the hall and auto-start. */
export function skipShell(): boolean {
  return hasQueryFlag('smoke') || hasQueryFlag('dev');
}

function readStored(): Partial<GameSettings> {
  if (typeof localStorage === 'undefined') return {};
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return {};
    const parsed = JSON.parse(raw) as Partial<GameSettings>;
    return parsed && typeof parsed === 'object' ? parsed : {};
  } catch {
    return {};
  }
}

function clamp01(value: number): number {
  if (!Number.isFinite(value)) return DEFAULTS.masterVolume;
  return Math.min(1, Math.max(0, value));
}
