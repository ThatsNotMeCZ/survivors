import { SMOKE_DOTS, SMOKE_PASS_FPS } from '../config';
import { ITEM_CHIP_PX, makeItemChip } from './item-art';
import { hasQueryFlag } from './settings';

export type HudStatus = 'boot' | 'warmup' | 'pass' | 'fail' | 'arena';

export type HudItem = {
  id: string;
  name: string;
  stacks: number;
  rarity: string;
};

export type HudSkill = {
  slot: string;
  name: string;
  glyph: string;
  cd: number;
  max: number;
  empty: boolean;
  iframe: boolean;
};

const statusEl = () => document.getElementById('hud-status');
const fpsEl = () => document.getElementById('hud-fps');
const dotsEl = () => document.getElementById('hud-dots');
const rendererEl = () => document.getElementById('hud-renderer');
const hudEl = () => document.getElementById('hud');
const titleEl = () => document.getElementById('hud-title');
const hpEl = () => document.getElementById('hud-hp');
const lvEl = () => document.getElementById('hud-lv');
const timeEl = () => document.getElementById('hud-time');
const stageEl = () => document.getElementById('hud-stage');
const xpFillEl = () => document.getElementById('xp-fill');
const hpFillEl = () => document.getElementById('hp-fill');
const coeffEl = () => document.getElementById('hud-coeff');
const objectiveLabelEl = () => document.getElementById('hud-objective-label');
const objectiveDetailEl = () => document.getElementById('hud-objective-detail');
const objectiveFillEl = () => document.getElementById('hud-objective-fill');
const itemListEl = () => document.getElementById('hud-item-list');
const itemsRootEl = () => document.getElementById('hud-items');

let debugOn = hasQueryFlag('debug');
let keysBound = false;
let playMode = false;
let lastItemKey = '';
let lastItems: HudItem[] = [];

export function getHudItems(): HudItem[] {
  return lastItems;
}

export function hideHud(): void {
  playMode = false;
  lastItemKey = '';
  lastItems = [];
  syncPlayAttr();
  hudEl()?.classList.add('hidden');
  document.getElementById('hud-play')?.classList.add('hidden');
}

export function initHud(rendererName: string): void {
  playMode = false;
  syncPlayAttr();
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
  syncPlayAttr();
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
  biome: string;
  playerHp: number;
  playerMax: number;
  level: number;
  xp: number;
  xpNeed: number;
  runTime: number;
  coefficient: number;
  iframe: boolean;
  objective: string;
  objectiveDetail: string;
  objectivePct: number;
  holding: boolean;
  boss: boolean;
  skills: HudSkill[];
  items: HudItem[];
}): void {
  const stage = stageEl();
  const hp = hpEl();
  const lv = lvEl();
  const time = timeEl();
  const fill = xpFillEl();
  const hpFill = hpFillEl();
  const coeff = coeffEl();
  const objective = objectiveLabelEl();
  const detail = objectiveDetailEl();
  const objFill = objectiveFillEl();
  if (stage) stage.textContent = state.stage;
  if (hp) hp.textContent = `${Math.max(0, state.playerHp).toFixed(0)} / ${state.playerMax.toFixed(0)}`;
  if (lv) lv.textContent = `Lv ${state.level}`;
  if (time) time.textContent = formatTime(state.runTime);
  if (objective) objective.textContent = state.objective;
  if (detail) {
    detail.textContent = state.objectiveDetail;
    detail.classList.toggle('hidden', state.objectiveDetail.length === 0);
  }
  if (objFill) {
    objFill.style.width = `${Math.round(Math.min(1, Math.max(0, state.objectivePct)) * 100)}%`;
  }
  if (fill) {
    const pct = state.xpNeed > 0 ? Math.min(1, state.xp / state.xpNeed) : 0;
    fill.style.width = `${Math.round(pct * 100)}%`;
  }
  if (hpFill) {
    const pct = state.playerMax > 0 ? Math.min(1, Math.max(0, state.playerHp) / state.playerMax) : 0;
    hpFill.style.height = `${Math.round(pct * 100)}%`;
  }
  if (coeff) coeff.textContent = `×${state.coefficient.toFixed(2)}`;
  renderSkills(state.skills);
  renderItems(state.items);
  document.documentElement.dataset.biome = state.biome;
  const hud = hudEl();
  hud?.setAttribute('data-holding', state.holding ? '1' : '0');
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

function renderSkills(skills: HudSkill[]): void {
  for (const skill of skills) {
    const slot = document.querySelector<HTMLElement>(`.skill-slot[data-slot="${skill.slot}"]`);
    if (!slot) continue;
    const glyph = slot.querySelector('.skill-glyph');
    const cd = slot.querySelector('.skill-cd');
    if (glyph) glyph.textContent = skill.empty ? '—' : skill.glyph;
    const ready = !skill.empty && skill.cd <= 0;
    const cdPct = skill.empty || skill.max <= 0 || skill.cd <= 0 ? 0 : Math.min(1, skill.cd / skill.max);
    slot.style.setProperty('--cd', String(cdPct));
    slot.dataset.ready = ready ? '1' : '0';
    slot.dataset.empty = skill.empty ? '1' : '0';
    slot.dataset.iframe = skill.iframe ? '1' : '0';
    slot.title = skill.empty ? '' : skill.name;
    if (cd) cd.textContent = !skill.empty && skill.cd > 0.05 ? skill.cd.toFixed(1) : '';
  }
}

function renderItems(items: HudItem[]): void {
  lastItems = items;
  const list = itemListEl();
  const root = itemsRootEl();
  if (!list || !root) return;
  root.classList.toggle('hidden', items.length === 0);
  const key = items.map((item) => `${item.id}:${item.stacks}:${item.rarity}`).join('|');
  if (key === lastItemKey && list.childElementCount === items.length) return;
  lastItemKey = key;
  list.replaceChildren();
  for (const item of items) {
    list.appendChild(makeItemChip(item, 'item-chip', ITEM_CHIP_PX));
  }
}

function showHud(): void {
  hudEl()?.classList.remove('hidden');
}

function syncPlayAttr(): void {
  if (typeof document === 'undefined') return;
  document.documentElement.dataset.play = playMode ? '1' : '0';
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
