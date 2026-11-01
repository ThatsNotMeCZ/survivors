import { playSfx, setMusicOverlay, setMusicScene, type SfxId } from '../audio';
import { catalog } from '../data/catalog';
import type { ItemDef, ItemHook, SkillDef, SkillSlot, StatId, SurvivorDef } from '../data/schema';
import { formatTime, getHudItems, getHudSummary, type HudItem } from './hud';
import { ITEM_CHOICE_PX, makeItemChip, makeItemIcon } from './item-art';
import { SKILL_SLOT_PX, makeSkillIcon } from './skill-art';
import { hydrateUiSprites } from './ui-art';
import { mountVesselArt } from './vessel-art';
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
  onPause: () => void;
  onPick: (index: number) => void;
  onRestart: () => void;
};

export type RunRecap = {
  stage: string;
  time: number;
  level: number;
  coefficient: number;
  bosses: number;
  items: { name: string; stacks: number }[];
  survivor: string;
};

const STAT_LABEL: Record<StatId, string> = {
  speed: 'Speed',
  maxHp: 'Max HP',
  radius: 'Hurtbox',
  damage: 'Damage',
  cooldown: 'Cooldown',
  critChance: 'Crit Chance',
  critDamage: 'Crit Damage',
};

let handlers: OverlayHandlers = {
  onStart: () => undefined,
  onResume: () => undefined,
  onQuit: () => undefined,
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
let lastSfxPreview = 0;

export function bindOverlay(next: Partial<OverlayHandlers>): void {
  handlers = { ...handlers, ...next };
  if (!keysBound) {
    keysBound = true;
    window.addEventListener('keydown', onOverlayKey, true);
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

export function showHowTo(from: 'menu' | 'lobby' | 'pause' = origin): void {
  origin = from;
  renderScreen({
    screen: 'howto',
    kicker: 'Rites of motion',
    title: 'The Archives',
    sub: 'Kite the dross. Aim the bolt. Hold the seal. Do not stand still.',
    body: controlsTable(),
    actions: [{ label: 'Back', onClick: goBack, primary: true, sfx: 'close' }],
  });
}

export function showSettings(from: 'menu' | 'lobby' | 'pause' = origin): void {
  origin = from;
  const dialog = settingsDialog();
  const body = document.getElementById('settings-body');
  if (!dialog || !body) return;
  body.replaceChildren(settingsForm(getSettings()));
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
    sub: 'The vessel shatters. Progress in this working is lost.',
    actions: [
      { label: 'Abandon Vessel', onClick: () => handlers.onQuit(), primary: true, sfx: 'error' },
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

export function showRunEnd(kind: 'victory' | 'defeat', detail: string, recap?: RunRecap): void {
  runPaused = true;
  playSfx(kind === 'victory' ? 'victory' : 'defeat');
  renderScreen({
    screen: 'runend',
    kicker: kind === 'victory' ? 'The Great Work holds' : 'The clay splits',
    title: kind === 'victory' ? 'Transmutation Complete' : 'Vessel Shattered',
    sub: detail,
    body: recap ? recapBody(recap) : undefined,
    actions: [
      { label: 'Run again', onClick: () => handlers.onRestart(), primary: true, sfx: 'confirm' },
      { label: 'Return to hall', onClick: () => handlers.onQuit(), sfx: 'close' },
    ],
  });
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

function onOverlayKey(event: KeyboardEvent): void {
  if (isEscape(event)) {
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
    } else if (mode === 'hidden') {
      handlers.onPause();
    }
    return;
  }
  if (event.key === 'Enter') {
    if (settingsDialog()?.open) return;
    if (mode === 'menu') {
      event.preventDefault();
      playSfx('confirm');
      showLobby();
    } else if (mode === 'lobby') {
      event.preventDefault();
      playSfx('confirm');
      handlers.onStart();
    } else if (mode === 'pause') {
      event.preventDefault();
      handlers.onResume();
    } else if (mode === 'abandon') {
      event.preventDefault();
      playSfx('error');
      handlers.onQuit();
    } else if (mode === 'survivor' || mode === 'howto') {
      event.preventDefault();
      goBack();
    } else if (mode === 'runend') {
      event.preventDefault();
      handlers.onRestart();
    }
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
  mainMenuEl()?.classList.add('hidden');
  hallEl()?.classList.add('hidden');
  levelupViewEl()?.classList.add('hidden');
  pauseViewEl()?.classList.add('hidden');
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
    showHowTo('menu');
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
  const ash = document.createElement('div');
  ash.className = 'hall-particles';
  root.replaceChildren(ash);
  mountVesselArt(root, survivor.id, 'menu-vessel', survivor.name);
}

/* --- 2. LOBBY / THE HALL --- */

function renderHall(): void {
  const root = overlayEl();
  const hall = hallEl();
  if (!root || !hall) return;
  mode = 'lobby';
  syncOverlayAttr();
  root.dataset.screen = 'lobby';
  root.setAttribute('aria-labelledby', 'hall-brand');
  hideAllViews();
  hall.classList.remove('hidden');
  bindHall();
  fillHallNav();
  fillHallPreview();
  fillHallDossier();
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
    playSfx('confirm');
    handlers.onStart();
  });
}

function fillHallNav(): void {
  const nav = document.getElementById('hall-nav');
  if (!nav) return;
  nav.replaceChildren();
  const current = selectedSurvivor().id;
  for (const survivor of catalog.survivors) {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'vessel-pick';
    btn.dataset.active = survivor.id === current ? '1' : '0';

    const portraitBox = document.createElement('div');
    portraitBox.className = 'vessel-portrait-box';
    mountVesselArt(portraitBox, survivor.id, 'vessel-art portrait-art', survivor.name);

    const nameplate = document.createElement('span');
    nameplate.className = 'vessel-nameplate';
    nameplate.textContent = survivor.name.toUpperCase();

    const arrow = document.createElement('span');
    arrow.className = 'vessel-active-arrow';
    arrow.setAttribute('aria-hidden', 'true');

    btn.append(portraitBox, nameplate, arrow);
    btn.addEventListener('click', () => {
      playSfx('click');
      patchSettings({ survivorId: survivor.id });
      renderHall();
    });
    nav.appendChild(btn);
  }
}

function fillHallPreview(): void {
  const root = document.getElementById('hall-preview');
  if (!root) return;
  const survivor = selectedSurvivor();
  const circle = document.createElement('div');
  circle.className = 'hall-stage-circle';
  circle.setAttribute('aria-hidden', 'true');
  const ash = document.createElement('div');
  ash.className = 'hall-particles';
  circle.setAttribute('aria-hidden', 'true');
  const pedestal = document.createElement('div');
  pedestal.className = 'hall-pedestal';
  pedestal.setAttribute('aria-hidden', 'true');
  root.replaceChildren(circle, ash, pedestal);
  mountVesselArt(root, survivor.id, 'hall-vessel', survivor.name);
}

function fillHallDossier(): void {
  const root = document.getElementById('hall-dossier');
  if (!root) return;
  const survivor = selectedSurvivor();

  const header = document.createElement('p');
  header.className = 'dossier-header';
  header.textContent = 'VESSEL DOSSIER';

  const name = document.createElement('h2');
  name.className = 'hall-name';
  name.textContent = survivor.name.toUpperCase();

  const lore = document.createElement('p');
  lore.className = 'hall-lore';
  lore.textContent = survivor.lore ?? '';

  const statsGrid = document.createElement('div');
  statsGrid.className = 'hall-stats-grid';
  const statItems: { icon: string; text: string }[] = [
    { icon: '⚔', text: `HP: ${survivor.stats.maxHp}` },
    { icon: '♥', text: survivor.title ?? 'The Vessel' },
    { icon: '🥾', text: `SPEED: ${survivor.stats.speed}` },
    { icon: '🛡', text: `HURTBOX: ${survivor.stats.radius}` },
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
    if (!skill) {
      cell.textContent = '—';
      unit.appendChild(cell);
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
    ['Bosses Slain:', String(summary.bosses)],
    ['Total Augmentations:', `${summary.totalItems} (×${summary.coefficient.toFixed(2)})`],
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

  if (items.length === 0) {
    tooltipEl.classList.add('hidden');
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

  for (const item of items) {
    const chip = makeItemChip(item, 'item-chip pause-chip');
    chip.tabIndex = 0;
    chip.addEventListener('mouseenter', () => showItemTooltip(item));
    chip.addEventListener('focus', () => showItemTooltip(item));
    listEl.appendChild(chip);
  }

  showItemTooltip(items[0]);
}

/* --- SETTINGS, CONTROLS, RECAP --- */

function settingsForm(settings: GameSettings): HTMLElement {
  const wrap = document.createElement('div');
  wrap.appendChild(
    rangeRow('Master volume', 'Chamber, choir, and the working’s drone.', settings.masterVolume, (value) => {
      patchSettings({ masterVolume: value });
    }),
  );
  wrap.appendChild(
    rangeRow('SFX', 'Hits, dashes, and the choir of brass.', settings.sfxVolume, (value) => {
      patchSettings({ sfxVolume: value });
      const now = performance.now();
      if (now - lastSfxPreview < 120) return;
      lastSfxPreview = now;
      playSfx('click');
    }),
  );
  wrap.appendChild(
    rangeRow('Music', 'The working’s drone, when it learns to sing.', settings.musicVolume, (value) => {
      patchSettings({ musicVolume: value });
    }),
  );
  wrap.appendChild(
    checkRow('Mute', 'Keeps the choir dark.', settings.muted, (value) => {
      patchSettings({ muted: value });
      if (!value) playSfx('click');
    }),
  );
  wrap.appendChild(
    checkRow('Screenshake', 'Camera tremor when the chamber learns it.', settings.screenshake, (value) => {
      patchSettings({ screenshake: value });
    }),
  );
  wrap.appendChild(
    checkRow('Reduce VFX', 'Fewer sparks. The working stays readable.', settings.reduceVfx, (value) => {
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

function pct(value: number): string {
  return `${Math.round(value * 100)}%`;
}

function controlsTable(): HTMLElement {
  const survivor = selectedSurvivor();
  const dash = skillFor(survivor, 'utility');
  const primary = skillFor(survivor, 'primary');
  const dashLine = dashEffectLine(dash);
  const table = document.createElement('table');
  table.className = 'controls-table';
  const head = document.createElement('thead');
  const hr = document.createElement('tr');
  const h1 = document.createElement('th');
  h1.textContent = 'Rite';
  const h2 = document.createElement('th');
  h2.textContent = 'Binding';
  hr.append(h1, h2);
  head.appendChild(hr);
  const body = document.createElement('tbody');
  const rows: [string, string][] = [
    ['WASD', 'Walk the vessel.'],
    ['Mouse', `Aim ${primary?.name ?? 'Ignis Bolt'}.`],
    ['Hold LMB', 'Cast along the aim. Never auto-fires.'],
    ['RMB', 'Secondary. Aimed press.'],
    ['Shift / Space', dashLine],
    ['Q', 'Ultimate. Aimed press.'],
    ['1 / 2 / 3', 'Choose an augmentation when you level.'],
    ['Hold in the circle', 'Channel the Transmutation Circle. Step out and the seal cools.'],
    ['Esc', 'Pause the working.'],
  ];
  for (const [key, value] of rows) {
    const tr = document.createElement('tr');
    const k = document.createElement('td');
    k.textContent = key;
    const v = document.createElement('td');
    v.textContent = value;
    tr.append(k, v);
    body.appendChild(tr);
  }
  table.append(head, body);
  return table;
}

function dashEffectLine(skill: SkillDef | null): string {
  if (!skill) return 'Phase Step.';
  const dash = skill.effects.find((effect) => effect.type === 'dash');
  if (!dash || dash.type !== 'dash') return skill.name;
  return `${skill.name} — ${dash.distance} pace, ${dash.duration}s glide, ${dash.iframe}s between-worlds.`;
}

function recapBody(recap: RunRecap): HTMLElement {
  const list = document.createElement('div');
  list.className = 'recap-list';
  const rows: [string, string][] = [
    ['Vessel', recap.survivor],
    ['Stage', recap.stage],
    ['Total Time', formatTime(recap.time)],
    ['Level Reached', String(recap.level)],
    ['Bosses Defeated', String(recap.bosses)],
    [
      'Final Inventory',
      recap.items.length > 0 ? recap.items.map((item) => `${item.name} ×${item.stacks}`).join(', ') : 'None',
    ],
  ];
  for (const [key, value] of rows) {
    const row = document.createElement('div');
    const k = document.createElement('span');
    k.className = 'recap-k';
    k.textContent = key;
    const v = document.createElement('span');
    v.className = 'recap-v';
    v.textContent = value;
    row.append(k, v);
    list.appendChild(row);
  }
  return list;
}

function selectedSurvivor(): SurvivorDef {
  const id = getSettings().survivorId;
  const hit = catalog.survivors.find((entry) => entry.id === id);
  return hit ?? catalog.survivor(catalog.world.defaultSurvivor);
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
  btn.className = primary ? 'seal-btn action-primary' : 'seal-btn';
  btn.textContent = label;
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

function levelupViewEl(): HTMLElement | null {
  return document.getElementById('levelup-view');
}

function pauseViewEl(): HTMLElement | null {
  return document.getElementById('pause-view');
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
