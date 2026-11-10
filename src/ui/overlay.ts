import { playSfx, setMusicOverlay, setMusicScene, type SfxId } from '../audio';
import { catalog } from '../data/catalog';
import type { ItemDef, ItemHook, SkillDef, SkillSlot, StatId, SurvivorDef } from '../data/schema';
import { renderArchivesView, type ArchiveTab } from './archives';
import { formatTime, getHudItems, getHudSummary, hideHud, type HudItem } from './hud';
import { ITEM_CHOICE_PX, makeItemChip, makeItemIcon } from './item-art';
import { checkUnlockCondition, getRecords, isSurvivorUnlocked, type RunOutcome } from './records';
import { SKILL_SLOT_PX, makeSkillIcon } from './skill-art';
import { hydrateUiSprites } from './ui-art';
import { mountVesselArt } from './vessel-art';
import { mountMenuCinderCircle, type CinderCircleController } from './cinder-circle';
import { mountHallBackdrop, type HallBackdropController } from './hall-backdrop';
import { applySettingsToDom, getSettings, patchSettings, skipShell, type GameSettings } from './settings';

export type OverlayMode =
  | 'hidden'
  | 'menu'
  | 'lobby'
  | 'survivor'
  | 'howto'
  | 'settings'
  | 'pause'
  | 'abandon'
  | 'levelup'
  | 'runend';

export type OverlayHandlers = {
  onStart: () => void;
  onResume: () => void;
  onQuit: () => void;
  onAbandon: () => void;
  onPause: () => void;
  onPick: (index: number) => void;
  onRestart: () => void;
};

export type RunRecapItem = {
  id: string;
  name: string;
  stacks: number;
  rarity: string;
  lore?: string;
  hooks?: string[];
};

export type RunRecapUnlock = {
  kind: 'item' | 'survivor';
  id: string;
  name: string;
  rarity?: string;
  desc: string;
};

export type RunRecap = {
  stage: string;
  time: number;
  level: number;
  coefficient: number;
  bosses: number;
  kills?: number;
  damageDealt?: number;
  damageTaken?: number;
  healingDone?: number;
  gemsCollected?: number;
  items: RunRecapItem[];
  survivor: string;
  survivorId?: string;
  newUnlocks?: RunRecapUnlock[];
  unlockProgress?: {
    itemsUnlocked: number;
    totalItems: number;
    survivorsUnlocked: number;
    totalSurvivors: number;
  };
};

const STAT_LABEL: Record<StatId, string> = {
  speed: 'Speed',
  maxHp: 'Max HP',
  radius: 'Vessel Size',
  damage: 'Damage',
  cooldown: 'Cooldown',
  critChance: 'Crit Chance',
  critDamage: 'Crit Damage',
  armor: 'Armor',
  hazardResist: 'Hazard Ward',
  hpRegen: 'HP/s Regen',
  pickupRadius: 'Essence Magnet',
  xpGain: 'Essence XP',
  aoeRadius: 'Area Size',
  projSpeed: 'Projectile Speed',
  controlDuration: 'Rite Duration',
  eliteDamage: 'Elite & Boss Damage',
};

let handlers: OverlayHandlers = {
  onStart: () => undefined,
  onResume: () => undefined,
  onQuit: () => undefined,
  onAbandon: () => undefined,
  onPause: () => undefined,
  onPick: () => undefined,
  onRestart: () => undefined,
};
let keysBound = false;
let menuBound = false;
let hallBound = false;
let pauseBound = false;
let mode: OverlayMode = 'hidden';
let origin: 'menu' | 'lobby' | 'pause' = 'menu';
let runPaused = false;
let stingTimer = 0;
let stingUntil = 0;
let cinderCircleCtrl: CinderCircleController | null = null;
let hallBackdropCtrl: HallBackdropController | null = null;
let lastSfxPreview = 0;
let hallInspectedId = '';
let currentRunRecap: RunRecap | undefined = undefined;
let currentRunOutcome: RunOutcome | undefined = undefined;

async function copyTextToClipboard(text: string): Promise<boolean> {
  if (typeof navigator !== 'undefined' && navigator.clipboard && typeof navigator.clipboard.writeText === 'function') {
    try {
      await navigator.clipboard.writeText(text);
      return true;
    } catch {
      // Fallback for iframe restrictions
    }
  }
  try {
    const ta = document.createElement('textarea');
    ta.value = text;
    ta.style.position = 'fixed';
    ta.style.left = '-9999px';
    ta.style.top = '-9999px';
    ta.style.opacity = '0';
    document.body.appendChild(ta);
    ta.focus();
    ta.select();
    const ok = document.execCommand('copy');
    ta.remove();
    return ok;
  } catch {
    return false;
  }
}

export function formatRunSummaryText(kind: RunOutcome = currentRunOutcome ?? 'defeat', recap: RunRecap | undefined = currentRunRecap): string {
  const outcomeTitle = kind === 'victory'
    ? 'TRANSMUTATION COMPLETE 🜂'
    : kind === 'defeat'
      ? 'VESSEL SHATTERED 🜍'
      : 'VESSEL DISSOLVED ☿';

  if (!recap) {
    return `⚗️ HERMETIC RIFTS — ${outcomeTitle}`;
  }

  const itemsStr = recap.items.length > 0
    ? recap.items.map((i) => `${i.name}${i.stacks > 1 ? ` ×${i.stacks}` : ''}`).join(', ')
    : 'None';

  return [
    `⚗️ HERMETIC RIFTS — ${outcomeTitle}`,
    `Vessel: ${recap.survivor} · Chamber: ${recap.stage}`,
    `Time: ${formatTime(recap.time)} · Lv ${recap.level} · Coeff: ×${recap.coefficient.toFixed(2)}`,
    `Dross Slain: ${(recap.kills ?? 0).toLocaleString()} · Bosses Slain: ${recap.bosses}`,
    `Damage Dealt: ${Math.round(recap.damageDealt ?? 0).toLocaleString()} · Essence: ${recap.gemsCollected ?? 0}`,
    `Relics: ${itemsStr}`,
  ].join('\n');
}

export function copyRunSummary(): void {
  const text = formatRunSummaryText();
  const copyBtn = document.getElementById('runend-copy');
  const label = copyBtn?.querySelector('.plaque-label');
  void copyTextToClipboard(text).then((success) => {
    if (success) {
      playSfx('confirm');
      if (label) {
        const orig = label.textContent;
        label.textContent = 'COPIED TO LEDGER ✓';
        window.setTimeout(() => {
          if (label && label.textContent === 'COPIED TO LEDGER ✓') {
            label.textContent = orig;
          }
        }, 2200);
      }
    } else {
      playSfx('error');
    }
  });
}

export function toggleFullscreen(): void {
  if (typeof document === 'undefined') return;
  if (!document.fullscreenElement) {
    document.documentElement.requestFullscreen().catch(() => undefined);
  } else {
    document.exitFullscreen().catch(() => undefined);
  }
}

export function bindOverlay(next: Partial<OverlayHandlers>): void {
  handlers = { ...handlers, ...next };
  if (!keysBound) {
    keysBound = true;
    window.addEventListener('keydown', onOverlayKey, true);
    window.addEventListener('blur', () => {
      if (mode === 'hidden' && !runPaused) {
        handlers.onPause();
      }
    });
    document.addEventListener('visibilitychange', () => {
      if (document.hidden && mode === 'hidden' && !runPaused) {
        handlers.onPause();
      }
    });
    window.addEventListener('pointerdown', () => {
      if (typeof window !== 'undefined' && document.activeElement !== document.body) {
        window.focus();
      }
    });
    document.getElementById('settings-close')?.addEventListener('click', () => settingsDialog()?.close());
    applySettingsToDom();
    hydrateUiSprites(document);
  }
  syncOverlayAttr();
}

export function getOverlayMode(): OverlayMode {
  return mode;
}

export function isSimPaused(): boolean {
  return runPaused;
}

export function isModalOpen(): boolean {
  return mode !== 'hidden';
}

export function hideOverlay(): void {
  const wasPause = mode === 'pause';
  const root = overlayEl();
  cinderCircleCtrl?.stop();
  hallBackdropCtrl?.stop();
  mode = 'hidden';
  runPaused = false;
  origin = 'menu';
  syncOverlayAttr();
  syncChill();
  if (wasPause) playSfx('close');
  if (!root) return;
  blurOverlay(root);
  settingsDialog()?.close();
  root.classList.add('hidden');
  root.setAttribute('aria-hidden', 'true');
  root.removeAttribute('data-screen');
}

export function showMainMenu(): void {
  runPaused = false;
  origin = 'menu';
  renderMainMenu();
}

export function showLobby(): void {
  runPaused = false;
  origin = 'lobby';
  renderHall();
}

export function showSurvivorSelect(): void {
  showLobby();
}

export function showArchives(from: 'menu' | 'lobby' | 'pause' = origin, tab?: ArchiveTab): void {
  origin = from;
  runPaused = from === 'pause';
  const root = overlayEl();
  const archives = archivesEl();
  if (!root || !archives) return;
  mode = 'howto';
  syncOverlayAttr();
  root.dataset.screen = 'archives';
  root.setAttribute('aria-labelledby', 'archives-brand');
  hideAllViews();
  archives.classList.remove('hidden');
  renderArchivesView(goBack, tab);
  showRoot(root);
  syncChill();
}

export function showHowTo(from: 'menu' | 'lobby' | 'pause' = origin, tab?: ArchiveTab): void {
  showArchives(from, tab);
}

export function showSettings(from: 'menu' | 'lobby' | 'pause' = origin): void {
  origin = from;
  const dialog = settingsDialog();
  const body = document.getElementById('settings-body');
  if (!dialog || !body) return;
  body.replaceChildren(settingsForm(getSettings()));
  hydrateUiSprites(dialog);
  if (!dialog.open) dialog.showModal();
}

export function showPause(): void {
  const alreadyChill = origin === 'pause' && (mode === 'abandon' || mode === 'howto' || mode === 'pause');
  runPaused = true;
  origin = 'pause';
  if (!alreadyChill) playSfx('open');
  renderPauseScreen();
}

export function showAbandon(): void {
  runPaused = true;
  origin = 'pause';
  renderScreen({
    screen: 'abandon',
    kicker: 'Break the vessel?',
    title: 'Abandon run',
    sub: 'The vessel shatters. Progress in this working will be committed to the Great Ledger.',
    actions: [
      {
        label: 'Abandon Vessel',
        onClick: () => {
          handlers.onAbandon();
        },
        primary: true,
        sfx: 'error',
      },
      { label: 'Keep working', onClick: showPause, sfx: null },
    ],
  });
}

export function showLevelUp(items: ItemDef[]): void {
  runPaused = true;
  playSfx('open');
  const root = overlayEl();
  const levelupView = levelupViewEl();
  const choicesRoot = document.getElementById('levelup-choices');
  if (!root || !levelupView || !choicesRoot) return;

  mode = 'levelup';
  syncOverlayAttr();
  root.dataset.screen = 'levelup';
  root.setAttribute('aria-labelledby', 'levelup-title');
  hideAllViews();
  levelupView.classList.remove('hidden');

  choicesRoot.replaceChildren();
  items.forEach((item, index) => {
    const col = document.createElement('div');
    col.className = 'aug-card-col';

    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = `choice aug-card rarity-${item.rarity}`;
    btn.dataset.uiSprite = `card-${item.rarity}`;

    const name = document.createElement('span');
    name.className = 'aug-card-name';
    name.textContent = item.name;

    const artWrap = document.createElement('div');
    artWrap.className = 'aug-card-art';
    const icon = makeItemIcon(item.id, item.name, 'choice-icon', ITEM_CHOICE_PX);
    icon.addEventListener('error', () => {
      icon.remove();
      const fb = document.createElement('span');
      fb.className = 'aug-card-fallback';
      fb.textContent = item.name.slice(0, 1).toUpperCase();
      artWrap.appendChild(fb);
    });
    artWrap.appendChild(icon);

    const rarity = document.createElement('span');
    rarity.className = `aug-card-rarity rarity-text-${item.rarity}`;
    rarity.textContent = capitalize(item.rarity);

    const hooks = document.createElement('div');
    hooks.className = 'aug-card-hooks';
    hooks.append(...hookLines(item, true));

    const divider = document.createElement('hr');
    divider.className = 'aug-card-divider';

    const lore = document.createElement('p');
    lore.className = 'aug-card-lore';
    lore.textContent = item.lore;

    const desc = document.createElement('div');
    desc.className = 'aug-card-desc';
    desc.append(hooks, divider, lore);

    btn.append(name, artWrap, rarity, desc);
    btn.addEventListener('click', () => {
      playSfx('confirm');
      handlers.onPick(index);
    });
    btn.addEventListener('mouseenter', () => btn.focus({ preventScroll: true }));

    const key = document.createElement('span');
    key.className = 'aug-card-key';
    key.textContent = `[${index + 1}]`;

    col.append(btn, key);
    choicesRoot.appendChild(col);
  });

  hydrateUiSprites(levelupView);
  showRoot(root);
  syncChill();
}

export function showRunEnd(kind: RunOutcome, detail: string, recap?: RunRecap): void {
  hideHud();
  runPaused = true;
  playSfx(kind === 'victory' ? 'victory' : 'defeat');
  renderRunEnd(kind, detail, recap);
}

export function showSting(copy: { kicker: string; title: string; sub: string }, durationMs = 2000): void {
  if (skipShell()) return;
  const root = stingEl();
  const kicker = document.getElementById('sting-kicker');
  const title = document.getElementById('sting-title');
  const sub = document.getElementById('sting-sub');
  if (!root || !kicker || !title || !sub) return;
  kicker.textContent = copy.kicker;
  title.textContent = copy.title;
  sub.textContent = copy.sub;
  root.classList.remove('hidden');
  root.classList.add('visible');
  stingTimer += 1;
  const token = stingTimer;
  stingUntil = performance.now() + durationMs;
  window.setTimeout(() => {
    if (token === stingTimer) hideSting();
  }, durationMs);
}

export function hideSting(): void {
  stingTimer += 1;
  stingUntil = 0;
  const root = stingEl();
  if (!root) return;
  root.classList.remove('visible');
  window.setTimeout(() => {
    if (!root.classList.contains('visible')) root.classList.add('hidden');
  }, 200);
}

export function stingActive(): boolean {
  return stingUntil > performance.now();
}

export function setHoldPrompt(state: {
  visible: boolean;
  title: string;
  detail: string;
  pct: number;
  outside: boolean;
}): void {
  const root = promptEl();
  const title = document.getElementById('prompt-title');
  const detail = document.getElementById('prompt-detail');
  const fill = document.getElementById('prompt-fill');
  if (!root || !title || !detail || !fill) return;
  if (!state.visible) {
    root.classList.add('hidden');
    return;
  }
  root.classList.remove('hidden');
  root.dataset.state = state.outside ? 'out' : 'in';
  title.textContent = state.title;
  detail.textContent = state.detail;
  fill.style.width = `${Math.round(Math.min(1, Math.max(0, state.pct)) * 100)}%`;
}

export function describeHooks(item: ItemDef): string {
  return item.hooks.map((hook) => formatHook(hook).text).join(' · ');
}

function focusLevelUpChoice(delta: number): void {
  const root = document.getElementById('levelup-choices');
  if (!root) return;
  const buttons = [...root.querySelectorAll<HTMLButtonElement>('button.choice')];
  if (buttons.length === 0) return;
  const active = document.activeElement;
  const index = buttons.findIndex((btn) => btn === active);
  const from = index < 0 ? (delta > 0 ? -1 : 0) : index;
  const next = (from + delta + buttons.length) % buttons.length;
  buttons[next]?.focus();
}

function hookLines(item: ItemDef, uppercase = false): HTMLElement[] {
  return item.hooks.map((hook) => {
    const line = document.createElement('span');
    const formatted = formatHook(hook);
    line.className = formatted.up ? 'hook-up' : 'hook-down';
    line.textContent = uppercase ? formatted.text.toUpperCase() : formatted.text;
    return line;
  });
}

function formatHook(hook: ItemHook): { text: string; up: boolean } {
  const sign = hook.value > 0 ? '+' : '';
  if (hook.op === 'on-kill') {
    return { text: `${sign}${hook.value} HP on kill`, up: hook.value > 0 };
  }
  if (hook.op === 'on-crit') {
    return { text: `-${hook.value}s CD on crit`, up: true };
  }
  const amount =
    hook.op === 'pct' ? `${sign}${Math.round(hook.value * 100)}%` : `${sign}${hook.value}`;
  const hurt = hook.stat === 'radius' || hook.stat === 'cooldown';
  const up = hook.value === 0 ? true : hurt ? hook.value < 0 : hook.value > 0;
  return { text: `${amount} ${STAT_LABEL[hook.stat]}`, up };
}

function capitalize(str: string): string {
  return str.length > 0 ? str[0].toUpperCase() + str.slice(1) : str;
}

function isEscape(event: KeyboardEvent): boolean {
  return event.code === 'Escape' || event.key === 'Escape' || event.key === 'Esc' || event.keyCode === 27;
}

function isPauseKey(event: KeyboardEvent): boolean {
  return event.code === 'KeyP' || event.key === 'p' || event.key === 'P';
}

function onOverlayKey(event: KeyboardEvent): void {
  // Prevent page scroll inside itch iframe during gameplay
  if (mode === 'hidden' && (event.code === 'Space' || event.key === ' ' || event.key.startsWith('Arrow'))) {
    event.preventDefault();
  }

  if (isEscape(event) || isPauseKey(event)) {
    if (isPauseKey(event) && (mode === 'menu' || mode === 'lobby' || mode === 'levelup')) {
      // Don't intercept P in menu, vessel selection, or levelup
    } else {
      event.preventDefault();
      if (event.repeat) return;
      const dialog = settingsDialog();
      if (dialog?.open) {
        dialog.close();
        return;
      }
      if (mode === 'pause') {
        handlers.onResume();
      } else if (mode === 'lobby') {
        playSfx('close');
        showMainMenu();
      } else if (mode === 'howto' || mode === 'survivor' || mode === 'abandon') {
        goBack();
      } else if (mode === 'runend') {
        playSfx('close');
        handlers.onQuit();
      } else if (mode === 'hidden') {
        handlers.onPause();
      }
      return;
    }
  }
  if (event.key === 'Enter') {
    if (settingsDialog()?.open) return;
    if (mode === 'menu') {
      event.preventDefault();
      playSfx('confirm');
      showLobby();
    } else if (mode === 'lobby') {
      event.preventDefault();
      const inspected = hallSurvivor();
      if (!isSurvivorUnlocked(inspected)) {
        playSfx('error');
        return;
      }
      playSfx('confirm');
      handlers.onStart();
    } else if (mode === 'pause') {
      event.preventDefault();
      handlers.onResume();
    } else if (mode === 'abandon') {
      event.preventDefault();
      playSfx('defeat');
      handlers.onAbandon();
    } else if (mode === 'survivor') {
      event.preventDefault();
      goBack();
    } else if (mode === 'runend') {
      event.preventDefault();
      handlers.onRestart();
    }
    return;
  }
  if (mode === 'runend' && (event.key === 'c' || event.key === 'C')) {
    event.preventDefault();
    copyRunSummary();
    return;
  }
  if (mode !== 'levelup') return;
  if (event.key === '1' || event.key === '2' || event.key === '3') {
    event.preventDefault();
    playSfx('confirm');
    handlers.onPick(Number(event.key) - 1);
    return;
  }
  if (event.key === 'ArrowLeft' || event.key === 'ArrowRight') {
    event.preventDefault();
    focusLevelUpChoice(event.key === 'ArrowRight' ? 1 : -1);
  }
}

function goBack(): void {
  if (origin === 'pause' || mode === 'abandon') showPause();
  else if (origin === 'lobby') showLobby();
  else showMainMenu();
}

type ActionSpec = { label: string; onClick: () => void; primary?: boolean; sfx?: SfxId | null };

function hideAllViews(): void {
  cinderCircleCtrl?.stop();
  hallBackdropCtrl?.stop();
  mainMenuEl()?.classList.add('hidden');
  hallEl()?.classList.add('hidden');
  archivesEl()?.classList.add('hidden');
  levelupViewEl()?.classList.add('hidden');
  pauseViewEl()?.classList.add('hidden');
  runEndViewEl()?.classList.add('hidden');
  cardEl()?.classList.add('hidden');
}

function renderScreen(spec: {
  screen: OverlayMode;
  kicker: string;
  title: string;
  sub: string;
  body?: HTMLElement;
  choices?: HTMLElement;
  actions?: ActionSpec[];
}): void {
  const root = overlayEl();
  const card = cardEl();
  const kicker = kickerEl();
  const title = titleEl();
  const sub = subEl();
  const body = bodyEl();
  const choices = choicesEl();
  const actions = actionsEl();
  if (!root || !card || !kicker || !title || !sub || !body || !choices || !actions) return;
  mode = spec.screen;
  syncOverlayAttr();
  root.dataset.screen = spec.screen;
  root.setAttribute('aria-labelledby', 'overlay-title');
  hideAllViews();
  card.classList.remove('hidden');
  kicker.textContent = spec.kicker;
  title.textContent = spec.title;
  sub.textContent = spec.sub;
  body.replaceChildren();
  if (spec.body) body.appendChild(spec.body);
  choices.replaceChildren();
  if (spec.choices) {
    while (spec.choices.firstChild) choices.appendChild(spec.choices.firstChild);
  }
  actions.replaceChildren();
  for (const action of spec.actions ?? []) {
    actions.appendChild(actionButton(action.label, action.onClick, action.primary, action.sfx));
  }
  hydrateUiSprites(card);
  showRoot(root);
  syncChill();
}

/* --- 1. MAIN MENU --- */

function renderMainMenu(): void {
  const root = overlayEl();
  const menu = mainMenuEl();
  if (!root || !menu) return;
  mode = 'menu';
  syncOverlayAttr();
  root.dataset.screen = 'menu';
  root.setAttribute('aria-labelledby', 'menu-brand');
  hideAllViews();
  menu.classList.remove('hidden');
  bindMainMenu();
  fillMenuPreview();
  const sealEl = document.getElementById('menu-cinder-circle');
  if (sealEl) {
    if (!cinderCircleCtrl) {
      cinderCircleCtrl = mountMenuCinderCircle(sealEl);
    }
    cinderCircleCtrl.start();
  }
  hydrateUiSprites(menu);
  showRoot(root);
  setMusicScene({ kind: 'menu' });
  syncChill();
}

function bindMainMenu(): void {
  if (menuBound) return;
  menuBound = true;
  document.getElementById('menu-archives')?.addEventListener('click', () => {
    playSfx('click');
    showArchives('menu', 'howto');
  });
  document.getElementById('menu-desk')?.addEventListener('click', () => {
    playSfx('click');
    showSettings('menu');
  });
  document.getElementById('menu-commence')?.addEventListener('click', () => {
    playSfx('confirm');
    showLobby();
  });
}

function fillMenuPreview(): void {
  const root = document.getElementById('menu-preview');
  if (!root) return;
  const survivor = selectedSurvivor();
  root.replaceChildren();
  mountVesselArt(root, survivor.id, 'menu-vessel', survivor.name);
}

/* --- 2. LOBBY / THE HALL --- */

function hallSurvivor(): SurvivorDef {
  if (hallInspectedId) {
    const hit = catalog.survivors.find((entry) => entry.id === hallInspectedId);
    if (hit) return hit;
  }
  return selectedSurvivor();
}

function renderHall(): void {
  const root = overlayEl();
  const hall = hallEl();
  if (!root || !hall) return;
  if (!hallInspectedId) {
    hallInspectedId = selectedSurvivor().id;
  }
  mode = 'lobby';
  syncOverlayAttr();
  root.dataset.screen = 'lobby';
  root.setAttribute('aria-labelledby', 'hall-brand');
  hideAllViews();
  hall.classList.remove('hidden');
  const backdropEl = document.getElementById('hall-backdrop');
  if (backdropEl) {
    if (!hallBackdropCtrl) {
      hallBackdropCtrl = mountHallBackdrop(backdropEl);
    }
    hallBackdropCtrl.start();
  }
  bindHall();
  fillHallNav();
  fillHallPreview();
  fillHallDossier();
  syncHallCommence();
  hydrateUiSprites(hall);
  showRoot(root);
  setMusicScene({ kind: 'menu' });
  syncChill();
}

function bindHall(): void {
  if (hallBound) return;
  hallBound = true;
  document.getElementById('hall-back')?.addEventListener('click', () => {
    playSfx('close');
    showMainMenu();
  });
  document.getElementById('hall-commence')?.addEventListener('click', () => {
    const surv = hallSurvivor();
    if (!isSurvivorUnlocked(surv)) {
      playSfx('error');
      return;
    }
    playSfx('confirm');
    handlers.onStart();
  });
}

function syncHallCommence(): void {
  const btn = document.getElementById('hall-commence') as HTMLButtonElement | null;
  if (!btn) return;
  const unlocked = isSurvivorUnlocked(hallSurvivor());
  btn.disabled = !unlocked;
  btn.dataset.locked = unlocked ? '0' : '1';
  const label = btn.querySelector<HTMLElement>('.plaque-label');
  if (label) {
    label.textContent = unlocked ? 'COMMENCE WORKING' : 'VESSEL SEALED';
  }
}

function fillHallNav(): void {
  const nav = document.getElementById('hall-nav');
  if (!nav) return;
  nav.replaceChildren();
  const rec = getRecords();
  const current = hallSurvivor().id;
  for (const survivor of catalog.survivors) {
    const unlocked = isSurvivorUnlocked(survivor, rec);
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'vessel-pick';
    btn.dataset.active = survivor.id === current ? '1' : '0';
    btn.dataset.locked = unlocked ? '0' : '1';

    const portraitBox = document.createElement('div');
    portraitBox.className = 'vessel-portrait-box';
    mountVesselArt(
      portraitBox,
      survivor.id,
      'vessel-art portrait-art',
      unlocked ? survivor.name : 'Sealed Vessel',
    );

    const nameplate = document.createElement('span');
    nameplate.className = 'vessel-nameplate';
    nameplate.textContent = unlocked ? survivor.name.toUpperCase() : '??? · SEALED';

    const arrow = document.createElement('span');
    arrow.className = 'vessel-active-arrow';
    arrow.setAttribute('aria-hidden', 'true');

    btn.append(portraitBox, nameplate, arrow);
    btn.addEventListener('click', () => {
      playSfx('click');
      hallInspectedId = survivor.id;
      if (unlocked) {
        patchSettings({ survivorId: survivor.id });
      }
      renderHall();
    });
    nav.appendChild(btn);
  }
}

function fillHallPreview(): void {
  const root = document.getElementById('hall-preview');
  if (!root) return;
  const survivor = hallSurvivor();
  const unlocked = isSurvivorUnlocked(survivor);
  root.dataset.locked = unlocked ? '0' : '1';
  root.replaceChildren();
  mountVesselArt(root, survivor.id, 'hall-vessel', unlocked ? survivor.name : 'Sealed Vessel');
  hallBackdropCtrl?.updateStage(root, !unlocked);
}

function fillHallDossier(): void {
  const root = document.getElementById('hall-dossier');
  if (!root) return;
  const rec = getRecords();
  const survivor = hallSurvivor();
  const unlockState = checkUnlockCondition(survivor.unlock, rec);
  const unlocked = unlockState.unlocked;

  const header = document.createElement('p');
  header.className = 'dossier-header';
  header.textContent = unlocked ? 'VESSEL DOSSIER' : 'SEALED VESSEL';

  const name = document.createElement('h2');
  name.className = 'hall-name';
  name.textContent = unlocked ? survivor.name.toUpperCase() : '???';

  const lore = document.createElement('p');
  lore.className = unlocked ? 'hall-lore' : 'hall-lore is-locked-lore';
  lore.textContent = unlocked
    ? survivor.lore ?? ''
    : `Rite of Unsealing: ${unlockState.label} (${unlockState.progress}).`;

  const statsGrid = document.createElement('div');
  statsGrid.className = 'hall-stats-grid';
  const statItems: { icon: string; text: string }[] = unlocked
    ? [
        { icon: '♥', text: `VITALITY: ${survivor.stats.maxHp}` },
        { icon: '⚔', text: (survivor.title ?? 'The Vessel').toUpperCase() },
        { icon: '🥾', text: `STRIDE: ${survivor.stats.speed >= 260 ? 'SWIFT' : 'MEASURED'}` },
        { icon: '🛡', text: 'FRAME: COMPACT' },
      ]
    : [
        { icon: '♥', text: 'VITALITY: ???' },
        { icon: '⚔', text: 'ROLE: ???' },
        { icon: '🥾', text: 'STRIDE: ???' },
        { icon: '🛡', text: `SEAL: ${unlockState.progress}` },
      ];
  for (const st of statItems) {
    const cell = document.createElement('div');
    cell.className = 'hall-stat-cell';
    const ic = document.createElement('span');
    ic.className = 'hall-stat-icon';
    ic.textContent = st.icon;
    const tx = document.createElement('span');
    tx.className = 'hall-stat-text';
    tx.textContent = st.text;
    cell.append(ic, tx);
    statsGrid.appendChild(cell);
  }

  const skills = document.createElement('div');
  skills.className = 'hall-skills';
  const slots: SkillSlot[] = ['primary', 'secondary', 'utility', 'special'];
  const glyphs = ['I', 'II', 'III', 'IV'];
  slots.forEach((slot, index) => {
    const skill = skillFor(survivor, slot);
    const unit = document.createElement('div');
    unit.className = 'hall-skill-unit';

    const cell = document.createElement('button');
    cell.type = 'button';
    cell.className = 'hall-skill';
    if (!unlocked || !skill) {
      cell.textContent = unlocked ? '—' : '?';
      cell.dataset.locked = unlocked ? '0' : '1';
      const skillLabel = document.createElement('span');
      skillLabel.className = 'hall-skill-label';
      skillLabel.textContent = unlocked ? '—' : '???';
      unit.append(cell, skillLabel);
      skills.appendChild(unit);
      return;
    }
    const glyph = document.createElement('span');
    glyph.className = 'hall-skill-glyph';
    glyph.textContent = glyphs[index];
    const icon = makeSkillIcon(skill.id, skill.name, 'hall-skill-icon', SKILL_SLOT_PX);
    icon.addEventListener('error', () => {
      icon.remove();
      cell.dataset.hasIcon = '0';
    });
    icon.addEventListener('load', () => {
      cell.dataset.hasIcon = '1';
    });
    const tip = document.createElement('span');
    tip.className = 'tip';
    const strong = document.createElement('strong');
    strong.textContent = skill.name;
    const hook = document.createElement('span');
    hook.textContent = skill.hook ?? skill.slot;
    const flavor = document.createElement('em');
    flavor.textContent = skill.lore ?? '';
    tip.append(strong, hook, flavor);
    cell.append(glyph, icon, tip);

    const skillLabel = document.createElement('span');
    skillLabel.className = 'hall-skill-label';
    skillLabel.textContent = skill.name;

    unit.append(cell, skillLabel);
    skills.appendChild(unit);
  });

  root.replaceChildren(header, name, lore, statsGrid, skills);
}

/* --- 4. PAUSE SCREEN --- */

function renderPauseScreen(): void {
  const root = overlayEl();
  const pauseView = pauseViewEl();
  if (!root || !pauseView) return;

  mode = 'pause';
  syncOverlayAttr();
  root.dataset.screen = 'pause';
  root.setAttribute('aria-labelledby', 'pause-title');
  hideAllViews();
  pauseView.classList.remove('hidden');

  bindPauseActions();
  fillPauseSummary();
  fillPauseInventory(getHudItems());
  hydrateUiSprites(pauseView);
  showRoot(root);
  syncChill();
}

function bindPauseActions(): void {
  if (pauseBound) return;
  pauseBound = true;
  document.getElementById('pause-resume')?.addEventListener('click', () => {
    handlers.onResume();
  });
  document.getElementById('pause-archives')?.addEventListener('click', () => {
    playSfx('click');
    showArchives('pause', 'howto');
  });
  document.getElementById('pause-settings')?.addEventListener('click', () => {
    playSfx('click');
    showSettings('pause');
  });
  document.getElementById('pause-abandon')?.addEventListener('click', () => {
    playSfx('click');
    showAbandon();
  });
}

function fillPauseSummary(): void {
  const rowsEl = document.getElementById('pause-summary-rows');
  if (!rowsEl) return;
  const summary = getHudSummary();
  const rows: [string, string][] = [
    ['Run Time:', formatTime(summary.runTime)],
    ['Level:', String(summary.level)],
    ['Dross Slain:', String(summary.kills)],
    ['Bosses Slain:', String(summary.bosses)],
    ['Damage Dealt:', summary.damageDealt.toLocaleString('en-US')],
    ['Total Augmentations:', String(summary.totalItems)],
  ];
  rowsEl.replaceChildren();
  for (const [label, val] of rows) {
    const row = document.createElement('div');
    row.className = 'summary-row';
    const k = document.createElement('span');
    k.className = 'summary-k';
    k.textContent = label;
    const v = document.createElement('span');
    v.className = 'summary-v';
    v.textContent = val;
    row.append(k, v);
    rowsEl.appendChild(row);
  }
}

function fillPauseInventory(items: HudItem[]): void {
  const listEl = document.getElementById('pause-inv-list');
  const tooltipEl = document.getElementById('pause-item-tooltip');
  if (!listEl || !tooltipEl) return;

  const cols = Math.max(4, Math.ceil(Math.sqrt(Math.max(1, items.length))));
  listEl.style.setProperty('--inv-cols', String(cols));
  listEl.replaceChildren();
  tooltipEl.classList.add('hidden');

  const isEmpty = items.length === 0;
  listEl.classList.toggle('is-empty', isEmpty);
  if (isEmpty) {
    const empty = document.createElement('p');
    empty.className = 'pause-inv-empty';
    empty.textContent = 'No augmentations bound yet.';
    listEl.appendChild(empty);
    return;
  }

  const showItemTooltip = (hudItem: HudItem): void => {
    let def: ItemDef;
    try {
      def = catalog.item(hudItem.id);
    } catch {
      return;
    }
    tooltipEl.classList.remove('hidden');
    const artWrap = document.createElement('div');
    artWrap.className = 'tooltip-art-wrap';
    const icon = makeItemIcon(def.id, def.name, 'tooltip-item-icon', 64);
    icon.addEventListener('error', () => icon.remove());
    artWrap.appendChild(icon);

    const name = document.createElement('h4');
    name.className = 'tooltip-item-name';
    name.textContent = hudItem.stacks > 1 ? `${def.name.toUpperCase()} ×${hudItem.stacks}` : def.name.toUpperCase();

    const hooks = document.createElement('div');
    hooks.className = 'tooltip-item-hooks';
    hooks.append(...hookLines(def, false));

    const lore = document.createElement('p');
    lore.className = 'tooltip-item-lore';
    lore.textContent = def.lore;

    tooltipEl.replaceChildren(artWrap, name, hooks, lore);
  };

  const positionItemTooltip = (clientX: number, clientY: number): void => {
    const offset = 16;
    const pad = 12;
    const rect = tooltipEl.getBoundingClientRect();
    const w = rect.width || 280;
    const h = rect.height || 220;
    let x = clientX + offset;
    let y = clientY + offset;
    if (x + w + pad > window.innerWidth) {
      x = Math.max(pad, clientX - w - offset);
    }
    if (y + h + pad > window.innerHeight) {
      y = Math.max(pad, clientY - h - offset);
    }
    tooltipEl.style.left = `${Math.round(x)}px`;
    tooltipEl.style.top = `${Math.round(y)}px`;
  };

  const hideItemTooltip = (): void => {
    tooltipEl.classList.add('hidden');
  };

  for (const item of items) {
    const chip = makeItemChip(item, 'item-chip pause-chip');
    chip.removeAttribute('title');
    chip.tabIndex = 0;
    chip.addEventListener('mouseenter', (e: MouseEvent) => {
      showItemTooltip(item);
      positionItemTooltip(e.clientX, e.clientY);
    });
    chip.addEventListener('mousemove', (e: MouseEvent) => {
      positionItemTooltip(e.clientX, e.clientY);
    });
    chip.addEventListener('mouseleave', hideItemTooltip);
    chip.addEventListener('focus', () => {
      showItemTooltip(item);
      const r = chip.getBoundingClientRect();
      positionItemTooltip(r.right, r.top);
    });
    chip.addEventListener('blur', hideItemTooltip);
    listEl.appendChild(chip);
  }
}

/* --- SETTINGS, CONTROLS, RECAP --- */

function settingsForm(settings: GameSettings): HTMLElement {
  const wrap = document.createElement('div');
  wrap.appendChild(
    actionRow('Fullscreen Chamber', 'Expand working to fill the entire monitor.', () => {
      toggleFullscreen();
    }),
  );
  wrap.appendChild(
    rangeRow('Master Volume', 'Overall resonance of the chamber.', settings.masterVolume, (value) => {
      patchSettings({ masterVolume: value });
    }),
  );
  wrap.appendChild(
    rangeRow('Sound Effects', 'Strikes, footsteps, and the chime of brass.', settings.sfxVolume, (value) => {
      patchSettings({ sfxVolume: value });
      const now = performance.now();
      if (now - lastSfxPreview < 120) return;
      lastSfxPreview = now;
      playSfx('click');
    }),
  );
  wrap.appendChild(
    rangeRow('Music', 'Ritual hymns and the chamber’s drone.', settings.musicVolume, (value) => {
      patchSettings({ musicVolume: value });
    }),
  );
  wrap.appendChild(
    checkRow('Mute All', 'Silences the entire working.', settings.muted, (value) => {
      patchSettings({ muted: value });
      if (!value) playSfx('click');
    }),
  );
  wrap.appendChild(
    checkRow('Screenshake', 'Tremor of the chamber upon heavy impacts.', settings.screenshake, (value) => {
      patchSettings({ screenshake: value });
    }),
  );
  wrap.appendChild(
    checkRow('Reduce Effects', 'Dims sparks and flashes for clearer sight.', settings.reduceVfx, (value) => {
      patchSettings({ reduceVfx: value });
    }),
  );
  return wrap;
}

function rangeRow(label: string, hint: string, value: number, onChange: (value: number) => void): HTMLElement {
  const row = document.createElement('label');
  row.className = 'setting-row';
  const copy = document.createElement('span');
  const title = document.createElement('span');
  title.textContent = label;
  const note = document.createElement('span');
  note.className = 'hint';
  note.textContent = hint;
  copy.append(title, note);
  const control = document.createElement('span');
  control.className = 'setting-control';
  const input = document.createElement('input');
  input.type = 'range';
  input.min = '0';
  input.max = '1';
  input.step = '0.05';
  input.value = String(value);
  input.setAttribute('aria-label', label);
  const readout = document.createElement('span');
  readout.className = 'setting-value';
  readout.textContent = pct(value);
  const apply = (): void => {
    const next = Number(input.value);
    readout.textContent = pct(next);
    onChange(next);
  };
  input.addEventListener('input', apply);
  input.addEventListener('change', apply);
  control.append(input, readout);
  row.append(copy, control);
  return row;
}

function checkRow(label: string, hint: string, value: boolean, onChange: (value: boolean) => void): HTMLElement {
  const row = document.createElement('label');
  row.className = 'setting-row';
  const copy = document.createElement('span');
  const title = document.createElement('span');
  title.textContent = label;
  const note = document.createElement('span');
  note.className = 'hint';
  note.textContent = hint;
  copy.append(title, note);
  const input = document.createElement('input');
  input.type = 'checkbox';
  input.checked = value;
  input.setAttribute('aria-label', label);
  input.addEventListener('change', () => onChange(input.checked));
  row.append(copy, input);
  return row;
}

function actionRow(label: string, hint: string, onClick: () => void): HTMLElement {
  const row = document.createElement('div');
  row.className = 'setting-row';
  const copy = document.createElement('span');
  const title = document.createElement('span');
  title.textContent = label;
  const note = document.createElement('span');
  note.className = 'hint';
  note.textContent = hint;
  copy.append(title, note);
  const control = document.createElement('span');
  control.className = 'setting-control';
  const btn = document.createElement('button');
  btn.type = 'button';
  btn.className = 'plaque-btn';
  btn.dataset.uiSprite = 'btn-plaque';
  btn.style.padding = '4px 12px';
  const span = document.createElement('span');
  span.className = 'plaque-label';
  span.textContent = 'Toggle Fullscreen';
  btn.appendChild(span);
  btn.addEventListener('click', () => {
    playSfx('click');
    onClick();
  });
  control.appendChild(btn);
  row.append(copy, control);
  return row;
}

function pct(value: number): string {
  return `${Math.round(value * 100)}%`;
}

function renderRunEnd(kind: RunOutcome, detail: string, recap?: RunRecap): void {
  const root = overlayEl();
  const view = runEndViewEl();
  const kicker = document.getElementById('runend-kicker');
  const title = document.getElementById('runend-title');
  const sub = document.getElementById('runend-sub');
  const statsRows = document.getElementById('runend-stats-rows');
  const unlocksList = document.getElementById('runend-unlocks-list');
  const invList = document.getElementById('runend-inv-list');
  const tooltip = document.getElementById('runend-item-tooltip');
  const restartBtn = document.getElementById('runend-restart');
  const copyBtn = document.getElementById('runend-copy');
  const quitBtn = document.getElementById('runend-quit');

  currentRunRecap = recap;
  currentRunOutcome = kind;

  if (
    !root ||
    !view ||
    !kicker ||
    !title ||
    !sub ||
    !statsRows ||
    !unlocksList ||
    !invList ||
    !restartBtn ||
    !quitBtn
  ) {
    return;
  }

  mode = 'runend';
  syncOverlayAttr();
  root.dataset.screen = 'runend';
  view.dataset.outcome = kind;
  hideAllViews();
  view.classList.remove('hidden');

  if (kind === 'victory') {
    kicker.textContent = 'The Great Work Holds';
    title.textContent = 'TRANSMUTATION COMPLETE';
  } else if (kind === 'defeat') {
    kicker.textContent = 'The Clay Splits';
    title.textContent = 'VESSEL SHATTERED';
  } else {
    kicker.textContent = 'The Crucible Cools';
    title.textContent = 'VESSEL DISSOLVED';
  }
  sub.textContent = detail;

  // Run stats
  statsRows.replaceChildren();
  if (recap) {
    const stats: [string, string][] = [
      ['Vessel', recap.survivor],
      ['Chamber Reached', recap.stage],
      ['Rift Duration', formatTime(recap.time)],
      ['Level Attained', String(recap.level)],
      ['Dross Slain', String(recap.kills ?? 0)],
      ['Bosses Slain', String(recap.bosses)],
      ['Damage Dealt', Math.round(recap.damageDealt ?? 0).toLocaleString('en-US')],
      ['Damage Taken', Math.round(recap.damageTaken ?? 0).toLocaleString('en-US')],
      ['Healing Done', Math.round(recap.healingDone ?? 0).toLocaleString('en-US')],
      ['Essence Gathered', String(recap.gemsCollected ?? 0)],
    ];
    for (const [k, v] of stats) {
      const row = document.createElement('div');
      row.className = 'summary-row';
      const kEl = document.createElement('span');
      kEl.textContent = k;
      const vEl = document.createElement('span');
      vEl.className = 'summary-v';
      vEl.textContent = v;
      row.append(kEl, vEl);
      statsRows.appendChild(row);
    }
  }

  // Unlocks & Discoveries
  unlocksList.replaceChildren();
  if (recap?.newUnlocks && recap.newUnlocks.length > 0) {
    for (const u of recap.newUnlocks) {
      const card = document.createElement('div');
      card.className = 'runend-unlock-card';
      if (u.kind === 'item') {
        const icon = makeItemIcon(u.id, u.name, 'runend-unlock-icon', 32);
        icon.addEventListener('error', () => icon.remove());
        card.appendChild(icon);
      }
      const info = document.createElement('div');
      info.className = 'runend-unlock-info';
      const name = document.createElement('span');
      name.className = 'runend-unlock-name';
      name.textContent = `${u.name} (Unlocked)`;
      const desc = document.createElement('span');
      desc.className = 'runend-unlock-desc';
      desc.textContent = u.desc;
      info.append(name, desc);
      card.appendChild(info);
      unlocksList.appendChild(card);
    }
  } else {
    const empty = document.createElement('div');
    empty.className = 'runend-unlock-empty';
    const msg = document.createElement('span');
    msg.textContent = 'No new relics unsealed in this working.';
    empty.appendChild(msg);
    if (recap?.unlockProgress) {
      const prog = document.createElement('span');
      prog.className = 'runend-unlock-progress';
      empty.appendChild(prog);
    }
    unlocksList.appendChild(empty);
  }

  // Inventory items
  invList.replaceChildren();
  if (tooltip) tooltip.classList.add('hidden');

  const showTooltip = (item: RunRecapItem) => {
    if (!tooltip) return;
    let def: ItemDef;
    try {
      def = catalog.item(item.id);
    } catch {
      return;
    }
    tooltip.classList.remove('hidden');
    const artWrap = document.createElement('div');
    artWrap.className = 'tooltip-art-wrap';
    const icon = makeItemIcon(def.id, def.name, 'tooltip-item-icon', 64);
    icon.addEventListener('error', () => icon.remove());
    artWrap.appendChild(icon);

    const name = document.createElement('h4');
    name.className = 'tooltip-item-name';
    name.textContent = item.stacks > 1 ? `${def.name.toUpperCase()} ×${item.stacks}` : def.name.toUpperCase();

    const hooks = document.createElement('div');
    hooks.className = 'tooltip-item-hooks';
    hooks.append(...hookLines(def, false));

    const lore = document.createElement('p');
    lore.className = 'tooltip-item-lore';
    lore.textContent = def.lore;

    tooltip.replaceChildren(artWrap, name, hooks, lore);
  };

  const positionTooltip = (clientX: number, clientY: number): void => {
    if (!tooltip) return;
    const offset = 16;
    const pad = 12;
    const rect = tooltip.getBoundingClientRect();
    const w = rect.width || 300;
    const h = rect.height || 220;
    let x = clientX + offset;
    let y = clientY + offset;
    if (x + w + pad > window.innerWidth) {
      x = Math.max(pad, clientX - w - offset);
    }
    if (y + h + pad > window.innerHeight) {
      y = Math.max(pad, clientY - h - offset);
    }
    tooltip.style.left = `${Math.round(x)}px`;
    tooltip.style.top = `${Math.round(y)}px`;
  };

  const hideTooltip = (): void => {
    if (tooltip) tooltip.classList.add('hidden');
  };

  if (!recap || recap.items.length === 0) {
    const empty = document.createElement('p');
    empty.className = 'pause-inv-empty';
    empty.textContent = 'No relics bound in this cycle.';
    invList.appendChild(empty);
  } else {
    for (const item of recap.items) {
      const chip = makeItemChip(
        { id: item.id, name: item.name, stacks: item.stacks, rarity: item.rarity },
        'item-chip runend-chip',
      );
      chip.removeAttribute('title');
      chip.tabIndex = 0;
      chip.addEventListener('mouseenter', (e: MouseEvent) => {
        showTooltip(item);
        positionTooltip(e.clientX, e.clientY);
      });
      chip.addEventListener('mousemove', (e: MouseEvent) => {
        positionTooltip(e.clientX, e.clientY);
      });
      chip.addEventListener('mouseleave', hideTooltip);
      chip.addEventListener('focus', () => {
        showTooltip(item);
        const r = chip.getBoundingClientRect();
        positionTooltip(r.right, r.top);
      });
      chip.addEventListener('blur', hideTooltip);
      invList.appendChild(chip);
    }
  }

  restartBtn.onclick = () => {
    playSfx('confirm');
    handlers.onRestart();
  };
  if (copyBtn) {
    copyBtn.onclick = () => {
      copyRunSummary();
    };
  }
  quitBtn.onclick = () => {
    playSfx('close');
    handlers.onQuit();
  };

  hydrateUiSprites(view);
  showRoot(root);
  syncChill();
}

function selectedSurvivor(): SurvivorDef {
  const id = getSettings().survivorId;
  const hit = catalog.survivors.find((entry) => entry.id === id);
  if (hit && isSurvivorUnlocked(hit)) return hit;
  return catalog.survivor(catalog.world.defaultSurvivor);
}

function skillFor(survivor: SurvivorDef, slot: SkillSlot): SkillDef | null {
  const id = survivor.skills[slot];
  return id ? catalog.skill(id) : null;
}

function actionButton(
  label: string,
  onClick: () => void,
  primary = false,
  sfx: SfxId | null = 'click',
): HTMLButtonElement {
  const btn = document.createElement('button');
  btn.type = 'button';
  btn.className = primary ? 'plaque-btn action-primary' : 'plaque-btn';
  btn.dataset.uiSprite = 'btn-plaque';
  const span = document.createElement('span');
  span.className = 'plaque-label';
  span.textContent = label;
  btn.appendChild(span);
  btn.addEventListener('click', () => {
    if (sfx) playSfx(sfx);
    onClick();
  });
  return btn;
}

function syncChill(): void {
  const chill =
    mode === 'pause' || mode === 'abandon' || (mode === 'howto' && origin === 'pause');
  setMusicOverlay(chill);
}

function showRoot(root: HTMLElement): void {
  root.classList.remove('hidden');
  root.setAttribute('aria-hidden', 'false');
  const focusable = root.querySelector<HTMLButtonElement>(
    '#overlay > :not(.hidden) button, #overlay > :not(.hidden) input',
  );
  focusable?.focus({ preventScroll: true });
}

function overlayEl(): HTMLElement | null {
  return document.getElementById('overlay');
}

function mainMenuEl(): HTMLElement | null {
  return document.getElementById('main-menu');
}

function hallEl(): HTMLElement | null {
  return document.getElementById('hall');
}

function archivesEl(): HTMLElement | null {
  return document.getElementById('archives');
}

function levelupViewEl(): HTMLElement | null {
  return document.getElementById('levelup-view');
}

function pauseViewEl(): HTMLElement | null {
  return document.getElementById('pause-view');
}

function runEndViewEl(): HTMLElement | null {
  return document.getElementById('runend-view');
}

function cardEl(): HTMLElement | null {
  return document.querySelector<HTMLElement>('#overlay .overlay-card');
}

function settingsDialog(): HTMLDialogElement | null {
  return document.getElementById('settings-dialog') as HTMLDialogElement | null;
}

function syncOverlayAttr(): void {
  if (typeof document === 'undefined') return;
  document.documentElement.dataset.overlay = mode;
}

function blurOverlay(root: HTMLElement): void {
  const active = document.activeElement;
  if (active instanceof HTMLElement && root.contains(active)) {
    active.blur();
  }
}

function kickerEl(): HTMLElement | null {
  return document.getElementById('overlay-kicker');
}

function titleEl(): HTMLElement | null {
  return document.getElementById('overlay-title');
}

function subEl(): HTMLElement | null {
  return document.getElementById('overlay-sub');
}

function bodyEl(): HTMLElement | null {
  return document.getElementById('overlay-body');
}

function choicesEl(): HTMLElement | null {
  return document.getElementById('overlay-choices');
}

function actionsEl(): HTMLElement | null {
  return document.getElementById('overlay-actions');
}

function stingEl(): HTMLElement | null {
  return document.getElementById('sting');
}

function promptEl(): HTMLElement | null {
  return document.getElementById('prompt');
}
