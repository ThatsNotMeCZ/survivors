import { applyAudioSettings, bindAudioUnlock, ensureAudioBus } from './bus';
import { initMusic, retryMusicPlay, setMusicOverlay, setMusicScene as applyMusicScene } from './music';
import { initSfx } from './sfx';
import type { AudioManifest, MusicScene } from './types';
import { getSettings } from '../ui/settings';

export type { MusicScene, SfxId } from './types';
export { applyAudioSettings } from './bus';
export { playSfx } from './sfx';
export { setMusicOverlay } from './music';

let booted = false;
let queued: MusicScene = { kind: 'none' };

export function bootAudio(): void {
  if (booted) return;
  booted = true;
  ensureAudioBus();
  applyAudioSettings(getSettings());
  bindAudioUnlock(() => {
    retryMusicPlay();
  });
  void loadManifest();
}

export function setMusicScene(scene: MusicScene): void {
  queued = scene;
  applyMusicScene(scene);
}

export function silenceAudio(): void {
  queued = { kind: 'none' };
  applyMusicScene({ kind: 'none' });
  setMusicOverlay(false);
}

async function loadManifest(): Promise<void> {
  try {
    const res = await fetch(new URL('audio/manifest.json', document.baseURI).href);
    if (!res.ok) return;
    const manifest = (await res.json()) as AudioManifest;
    initMusic(manifest);
    initSfx(manifest);
    applyAudioSettings(getSettings());
    applyMusicScene(queued);
  } catch {
    /* hall still works without sound */
  }
}
