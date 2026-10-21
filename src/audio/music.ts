import { ensureAudioBus, getAudioBus, onAudioMixApplied } from './bus';
import type { AudioManifest, MusicScene } from './types';

const CROSSFADE = 1.2;
const OVERLAY_FADE = 0.5;
const DUCK = 0.35;

type Deck = {
  el: HTMLAudioElement;
  gain: GainNode;
};

let manifest: AudioManifest | null = null;
let bedA: Deck | null = null;
let bedB: Deck | null = null;
let front: 'a' | 'b' = 'a';
let bedBus: GainNode | null = null;
let overlay: Deck | null = null;
let overlayOn = false;
let bedKey = '';
let bedPlaylist: string[] = [];
let bedBag: string[] = [];
let bedUrl = '';
let overlayPlaylist: string[] = [];
let overlayBag: string[] = [];
let overlayUrl = '';
let mixBound = false;

export function initMusic(next: AudioManifest): void {
  manifest = next;
  const bus = ensureAudioBus();
  if (!mixBound) {
    mixBound = true;
    onAudioMixApplied((mix) => setMusicMuted(mix.muted));
  }
  if (bedA) return;
  bedBus = bus.ctx.createGain();
  bedBus.gain.value = 1;
  bedBus.connect(bus.music);
  bedA = makeDeck(bus.ctx, bedBus, onBedEnded('a'), 'bed-a');
  bedB = makeDeck(bus.ctx, bedBus, onBedEnded('b'), 'bed-b');
  overlay = makeDeck(bus.ctx, bus.music, onOverlayEnded, 'overlay');
  overlay.gain.gain.value = 0;
}

export function setMusicScene(next: MusicScene): void {
  if (!manifest || !bedA) return;
  if (next.kind === 'none' || next.kind === 'menu') {
    resetOverlay();
    setMusicOverlay(false);
  }
  if (next.kind === 'none') {
    bedKey = '';
    bedPlaylist = [];
    stopBed();
    return;
  }
  const key = next.kind === 'menu' ? 'menu' : `map:${next.stageId}`;
  const tracks =
    next.kind === 'menu' ? manifest.music.menu : (manifest.music.maps[next.stageId] ?? []);
  if (key === bedKey && bedUrl) {
    retryBedPlay();
    return;
  }
  bedKey = key;
  bedPlaylist = tracks;
  bedBag = shuffleBag(tracks, null);
  const url = takeNext(bedBag, tracks, null);
  if (!url) {
    stopBed();
    return;
  }
  playBed(url, Boolean(bedUrl));
}

export function setMusicOverlay(on: boolean): void {
  overlayOn = on;
  if (!manifest || !overlay || !bedBus) return;
  overlayPlaylist = manifest.music.overlay;
  const bus = getAudioBus();
  if (!bus) return;
  const now = bus.ctx.currentTime;
  ramp(bedBus.gain, on ? DUCK : 1, now, OVERLAY_FADE);
  ramp(overlay.gain.gain, on ? 1 : 0, now, OVERLAY_FADE);
  if (on) {
    if (!overlayUrl) {
      overlayBag = shuffleBag(overlayPlaylist, null);
      overlayUrl = takeNext(overlayBag, overlayPlaylist, null);
      if (overlayUrl) {
        load(overlay.el, overlayUrl, overlayPlaylist.length <= 1);
      }
    }
    void playEl(overlay.el);
    return;
  }
  window.setTimeout(() => {
    if (!overlayOn) overlay?.el.pause();
  }, OVERLAY_FADE * 1000);
}

export function retryMusicPlay(): void {
  retryBedPlay();
  if (overlayOn) void overlay?.el.play().catch(() => undefined);
}

export function setMusicMuted(muted: boolean): void {
  if (bedA) bedA.el.muted = muted;
  if (bedB) bedB.el.muted = muted;
  if (overlay) overlay.el.muted = muted;
}

function retryBedPlay(): void {
  const deck = frontDeck();
  if (!deck || !bedUrl) return;
  void playEl(deck.el);
}

function playBed(url: string, fade: boolean): void {
  if (!bedA || !bedB) return;
  const bus = getAudioBus();
  if (!bus) return;
  const nextFront: 'a' | 'b' = front === 'a' ? 'b' : 'a';
  const incoming = nextFront === 'a' ? bedA : bedB;
  const outgoing = nextFront === 'a' ? bedB : bedA;
  load(incoming.el, url, bedPlaylist.length <= 1);
  void playEl(incoming.el);
  const now = bus.ctx.currentTime;
  if (!fade) {
    incoming.gain.gain.cancelScheduledValues(now);
    incoming.gain.gain.setValueAtTime(1, now);
    outgoing.gain.gain.cancelScheduledValues(now);
    outgoing.gain.gain.setValueAtTime(0, now);
    outgoing.el.pause();
  } else {
    ramp(incoming.gain.gain, 1, now, CROSSFADE);
    ramp(outgoing.gain.gain, 0, now, CROSSFADE);
    window.setTimeout(() => {
      if (frontDeck() !== outgoing) outgoing.el.pause();
    }, CROSSFADE * 1000);
  }
  front = nextFront;
  bedUrl = url;
}

function stopBed(): void {
  bedUrl = '';
  bedA?.el.pause();
  bedB?.el.pause();
}

function onBedEnded(which: 'a' | 'b'): () => void {
  return () => {
    if (which !== front) return;
    if (bedPlaylist.length <= 1) return;
    const url = takeNext(bedBag, bedPlaylist, bedUrl);
    if (url) playBed(url, true);
  };
}

function onOverlayEnded(): void {
  if (!overlayOn || overlayPlaylist.length <= 1 || !overlay) return;
  const url = takeNext(overlayBag, overlayPlaylist, overlayUrl);
  if (!url) return;
  overlayUrl = url;
  load(overlay.el, url, false);
  void playEl(overlay.el);
}

function frontDeck(): Deck | null {
  if (!bedA || !bedB) return null;
  return front === 'a' ? bedA : bedB;
}

function makeDeck(ctx: AudioContext, dest: AudioNode, onEnded: () => void, role: string): Deck {
  const el = document.createElement('audio');
  el.preload = 'auto';
  el.crossOrigin = 'anonymous';
  el.hidden = true;
  el.dataset.role = role;
  el.setAttribute('playsinline', '');
  el.addEventListener('ended', onEnded);
  document.body.appendChild(el);
  const gain = ctx.createGain();
  gain.gain.value = 0;
  const src = ctx.createMediaElementSource(el);
  src.connect(gain);
  gain.connect(dest);
  return { el, gain };
}

function load(el: HTMLAudioElement, url: string, loop: boolean): void {
  if (el.dataset.rel !== url) {
    el.dataset.rel = url;
    el.src = assetUrl(url);
  }
  el.loop = loop;
}

function resetOverlay(): void {
  overlayUrl = '';
  overlayBag = [];
  if (!overlay) return;
  overlay.el.pause();
  overlay.el.removeAttribute('src');
  overlay.el.dataset.rel = '';
}

function playEl(el: HTMLAudioElement): Promise<void> {
  return el.play().then(() => undefined).catch(() => undefined);
}

function shuffleBag(tracks: string[], last: string | null): string[] {
  const bag = [...tracks];
  for (let i = bag.length - 1; i > 0; i -= 1) {
    const j = Math.floor(Math.random() * (i + 1));
    const cur = bag[i];
    const swap = bag[j];
    if (cur === undefined || swap === undefined) continue;
    bag[i] = swap;
    bag[j] = cur;
  }
  if (last && bag.length > 1 && bag[0] === last) {
    const swapAt = 1 + Math.floor(Math.random() * (bag.length - 1));
    const first = bag[0];
    const other = bag[swapAt];
    if (first !== undefined && other !== undefined) {
      bag[0] = other;
      bag[swapAt] = first;
    }
  }
  return bag;
}

function takeNext(bag: string[], tracks: string[], last: string | null): string {
  if (tracks.length === 0) return '';
  if (bag.length === 0) {
    const reshuffle = shuffleBag(tracks, last);
    bag.push(...reshuffle);
  }
  return bag.shift() ?? '';
}

function ramp(param: AudioParam, value: number, now: number, seconds: number): void {
  param.cancelScheduledValues(now);
  param.setValueAtTime(param.value, now);
  param.linearRampToValueAtTime(value, now + seconds);
}

function assetUrl(rel: string): string {
  return new URL(encodeURI(rel), document.baseURI).href;
}
