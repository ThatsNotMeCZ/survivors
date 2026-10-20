import { SMOKE_DOTS, SMOKE_PASS_FPS } from '../config';

export type HudStatus = 'boot' | 'warmup' | 'pass' | 'fail' | 'arena';

const statusEl = () => document.getElementById('hud-status');
const fpsEl = () => document.getElementById('hud-fps');
const dotsEl = () => document.getElementById('hud-dots');
const rendererEl = () => document.getElementById('hud-renderer');
const hudEl = () => document.getElementById('hud');
const titleEl = () => document.getElementById('hud-title');
const hpEl = () => document.getElementById('hud-hp');
const dashEl = () => document.getElementById('hud-dash');
const lvEl = () => document.getElementById('hud-lv');
const timeEl = () => document.getElementById('hud-time');
const stageEl = () => document.getElementById('hud-stage');
const xpFillEl = () => document.getElementById('xp-fill');
const hpFillEl = () => document.getElementById('hp-fill');
const coeffEl = () => document.getElementById('hud-coeff');
const objectiveLabelEl = () => document.getElementById('hud-objective-label');
const objectiveDetailEl = () => document.getElementById('hud-objective-detail');

let debugOn =
  typeof window !== 'undefined' && new URLSearchParams(window.location.search).has('debug');
let keysBound = false;
let playMode = false;

export function hideHud(): void {
  playMode = false;
  hudEl()?.classList.add('hidden');
  document.getElementById('hud-play')?.classList.add('hidden');
}

export function initHud(rendererName: string): void {
  playMode = false;
  showHud();
  document.getElementById('hud-play')?.classList.add('hidden');
  document.getElementById('hud-debug')?.classList.remove('hidden');
  document.getElementById('row-dots')?.classList.remove('hidden');
  document.getElementById('row-coeff')?.classList.add('hidden');
  const dots = dotsEl();
  const renderer = rendererEl();
  const title = titleEl();
  if (title) title.textContent = 'GPU smoke';
  if (dots) dots.textContent = String(SMOKE_DOTS);
  if (renderer) renderer.textContent = rendererName;
  setHudStatus('warmup');
}

export function initArenaHud(rendererName: string): void {
  playMode = true;
  bindDebugToggle();
  showHud();
  document.getElementById('hud-play')?.classList.remove('hidden');
  document.getElementById('row-dots')?.classList.add('hidden');
  document.getElementById('row-coeff')?.classList.remove('hidden');
  const renderer = rendererEl();
  if (renderer) renderer.textContent = rendererName;
  setHudStatus('arena');
  syncDebugVisibility();
}

export function setHudStatus(status: HudStatus): void {
  const el = statusEl();
  const hud = hudEl();
  if (el) el.textContent = status;
  hud?.setAttribute('data-status', status);
}

export function setHudFps(fps: number): void {
  const el = fpsEl();
  if (el) el.textContent = fps.toFixed(0);
}

export function setHudCombat(state: {
  stage: string;
  playerHp: number;
  playerMax: number;
  level: number;
  xp: number;
  xpNeed: number;
  runTime: number;
  coefficient: number;
  dashCd: number;
  iframe: boolean;
  objective: string;
  objectiveDetail: string;
  holding: boolean;
  boss: boolean;
}): void {
  const stage = stageEl();
  const hp = hpEl();
  const dash = dashEl();
  const lv = lvEl();
  const time = timeEl();
  const fill = xpFillEl();
  const hpFill = hpFillEl();
  const coeff = coeffEl();
  const objective = objectiveLabelEl();
  const detail = objectiveDetailEl();
  if (stage) stage.textContent = state.stage;
  if (hp) hp.textContent = `${Math.max(0, state.playerHp).toFixed(0)}/${state.playerMax.toFixed(0)}`;
  if (lv) lv.textContent = `Lv ${state.level}`;
  if (time) time.textContent = formatTime(state.runTime);
  if (dash) {
    dash.textContent = state.iframe ? 'dash iframe' : state.dashCd > 0 ? `dash ${state.dashCd.toFixed(1)}s` : 'dash ready';
  }
  if (objective) objective.textContent = state.objective;
  if (detail) {
    detail.textContent = state.objectiveDetail;
    detail.classList.toggle('hidden', state.objectiveDetail.length === 0);
  }
  if (fill) {
    const pct = state.xpNeed > 0 ? Math.min(1, state.xp / state.xpNeed) : 0;
    fill.style.width = `${Math.round(pct * 100)}%`;
  }
  if (hpFill) {
    const pct = state.playerMax > 0 ? Math.min(1, Math.max(0, state.playerHp) / state.playerMax) : 0;
    hpFill.style.width = `${Math.round(pct * 100)}%`;
  }
  if (coeff) coeff.textContent = `×${state.coefficient.toFixed(2)}`;
  const hud = hudEl();
  if (state.iframe || state.holding) hud?.setAttribute('data-status', 'pass');
  else if (state.playerHp < state.playerMax * 0.35) hud?.setAttribute('data-status', 'fail');
  else if (state.boss) hud?.setAttribute('data-status', 'warmup');
  else hud?.setAttribute('data-status', 'arena');
}

export function judgeFps(fps: number): HudStatus {
  return fps >= SMOKE_PASS_FPS ? 'pass' : 'fail';
}

export function formatTime(seconds: number): string {
  const m = Math.floor(seconds / 60);
  const s = Math.floor(seconds % 60);
  return `${m}:${s.toString().padStart(2, '0')}`;
}

function showHud(): void {
  hudEl()?.classList.remove('hidden');
}

function bindDebugToggle(): void {
  if (keysBound) return;
  keysBound = true;
  window.addEventListener('keydown', (event) => {
    if (event.key !== 'F3' || !playMode) return;
    event.preventDefault();
    debugOn = !debugOn;
    syncDebugVisibility();
  });
}

function syncDebugVisibility(): void {
  document.getElementById('hud-debug')?.classList.toggle('hidden', !debugOn);
}
