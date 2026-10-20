import { catalog } from '../data/catalog';
import type { ItemDef, ItemHook, SkillDef, StatId, SurvivorDef } from '../data/schema';
import { formatTime } from './hud';
import { applySettingsToDom, getSettings, patchSettings, skipShell, type GameSettings } from './settings';

export type OverlayMode =
  | 'hidden'
  | 'menu'
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
  items: { name: string; stacks: number }[];
  survivor: string;
};

const STAT_LABEL: Record<StatId, string> = {
  speed: 'speed',
  maxHp: 'max HP',
  radius: 'hurtbox',
  damage: 'damage',
  cooldown: 'cooldown',
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
let mode: OverlayMode = 'hidden';
let origin: 'menu' | 'pause' = 'menu';
let runPaused = false;
let stingTimer = 0;
let stingUntil = 0;

export function bindOverlay(next: Partial<OverlayHandlers>): void {
  handlers = { ...handlers, ...next };
  if (!keysBound) {
    keysBound = true;
    window.addEventListener('keydown', onOverlayKey, true);
    applySettingsToDom();
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
  const root = overlayEl();
  mode = 'hidden';
  runPaused = false;
  origin = 'menu';
  syncOverlayAttr();
  if (!root) return;
  blurOverlay(root);
  root.classList.add('hidden');
  root.setAttribute('aria-hidden', 'true');
  root.removeAttribute('data-screen');
}

export function showMainMenu(): void {
  runPaused = false;
  origin = 'menu';
  const survivor = selectedSurvivor();
  renderScreen({
    screen: 'menu',
    kicker: 'A sealed chamber',
    title: 'survivors',
    sub: 'Aimed Ignis Bolt · channel the circle · descend the Rift. Cinder Yard to Rime Dock.',
    body: dossierCard(survivor, true),
    actions: [
      { label: 'Start run', onClick: () => handlers.onStart(), primary: true },
      { label: 'The Vessel', onClick: showSurvivorSelect },
      { label: 'How to play', onClick: () => showHowTo('menu') },
      { label: 'Settings', onClick: () => showSettings('menu') },
    ],
  });
}

export function showSurvivorSelect(): void {
  const list = catalog.survivors;
  const current = getSettings().survivorId;
  const body = document.createElement('div');
  if (list.length <= 1) {
    body.appendChild(dossierCard(selectedSurvivor(), false));
  } else {
    list.forEach((survivor) => {
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = survivor.id === current ? 'choice action-primary' : 'choice';
      btn.appendChild(dossierCard(survivor, false));
      btn.addEventListener('click', () => {
        patchSettings({ survivorId: survivor.id });
        showSurvivorSelect();
      });
      body.appendChild(btn);
    });
  }
  renderScreen({
    screen: 'survivor',
    kicker: 'The Vessel',
    title: 'The Vessel',
    sub:
      list.length <= 1
        ? 'One Homunculus is bound to this working.'
        : 'Choose who walks the yard.',
    body,
    actions: [
      { label: 'Confirm', onClick: () => showMainMenu(), primary: true },
      { label: 'Back', onClick: () => showMainMenu() },
    ],
  });
}

export function showHowTo(from: 'menu' | 'pause' = origin): void {
  origin = from;
  renderScreen({
    screen: 'howto',
    kicker: 'Rites of motion',
    title: 'How to play',
    sub: 'Kite the dross. Aim the bolt. Hold the seal. Do not stand still.',
    body: controlsTable(),
    actions: [{ label: 'Back', onClick: goBack, primary: true }],
  });
}

export function showSettings(from: 'menu' | 'pause' = origin): void {
  origin = from;
  const settings = getSettings();
  renderScreen({
    screen: 'settings',
    kicker: 'The choir is unbound',
    title: 'Settings',
    sub: 'Volume is stored for when the chamber learns to sing. It will not crash the working.',
    body: settingsForm(settings),
    actions: [{ label: 'Back', onClick: goBack, primary: true }],
  });
}

export function showPause(): void {
  runPaused = true;
  origin = 'pause';
  renderScreen({
    screen: 'pause',
    kicker: 'The working stills',
    title: 'Paused',
    sub: 'Esc or Enter to resume. The horde waits.',
    actions: [
      { label: 'Resume', onClick: () => handlers.onResume(), primary: true },
      { label: 'Settings', onClick: () => showSettings('pause') },
      { label: 'How to play', onClick: () => showHowTo('pause') },
      { label: 'Abandon run', onClick: showAbandon },
    ],
  });
}

export function showAbandon(): void {
  runPaused = true;
  origin = 'pause';
  renderScreen({
    screen: 'abandon',
    kicker: 'Break the vessel?',
    title: 'Abandon run',
    sub: 'The Homunculus shatters. Progress in this working is lost.',
    actions: [
      { label: 'Shatter and return', onClick: () => handlers.onQuit(), primary: true },
      { label: 'Keep working', onClick: showPause },
    ],
  });
}

export function showLevelUp(items: ItemDef[]): void {
  runPaused = true;
  const choices = document.createElement('div');
  items.forEach((item, index) => {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = `choice rarity-${item.rarity}`;
    const key = document.createElement('span');
    key.className = 'choice-key';
    key.textContent = String(index + 1);
    const name = document.createElement('span');
    name.className = 'choice-name';
    name.textContent = item.name;
    const hooks = document.createElement('span');
    hooks.className = 'choice-hooks';
    hooks.textContent = describeHooks(item);
    const lore = document.createElement('span');
    lore.className = 'choice-lore';
    lore.textContent = item.lore;
    btn.append(key, name, hooks, lore);
    btn.addEventListener('click', () => handlers.onPick(index));
    choices.appendChild(btn);
  });
  renderScreen({
    screen: 'levelup',
    kicker: 'A tablet unseals',
    title: 'Level up',
    sub: 'Pick 1 of 3. Keys 1 / 2 / 3.',
    choices,
  });
}

export function showRunEnd(kind: 'victory' | 'defeat', detail: string, recap?: RunRecap): void {
  runPaused = true;
  renderScreen({
    screen: 'runend',
    kicker: kind === 'victory' ? 'The Great Work holds' : 'The clay splits',
    title: kind === 'victory' ? 'Transmutation Complete' : 'Vessel Shattered',
    sub: detail,
    body: recap ? recapBody(recap) : undefined,
    actions: [
      { label: 'Run again', onClick: () => handlers.onRestart(), primary: true },
      { label: 'Return to hall', onClick: () => handlers.onQuit() },
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
  return item.hooks.map(formatHook).join(' · ');
}

function formatHook(hook: ItemHook): string {
  const sign = hook.value > 0 ? '+' : '';
  const amount =
    hook.op === 'pct' ? `${sign}${Math.round(hook.value * 100)}%` : `${sign}${hook.value}`;
  return `${amount} ${STAT_LABEL[hook.stat]}`;
}

function isEscape(event: KeyboardEvent): boolean {
  return event.code === 'Escape' || event.key === 'Escape' || event.key === 'Esc' || event.keyCode === 27;
}

function onOverlayKey(event: KeyboardEvent): void {
  if (isEscape(event)) {
    event.preventDefault();
    if (event.repeat) return;
    if (mode === 'pause') {
      handlers.onResume();
    } else if (mode === 'settings' || mode === 'howto' || mode === 'survivor' || mode === 'abandon') {
      goBack();
    } else if (mode === 'hidden') {
      handlers.onPause();
    }
    return;
  }
  if (event.key === 'Enter') {
    if (mode === 'menu') {
      event.preventDefault();
      handlers.onStart();
    } else if (mode === 'pause') {
      event.preventDefault();
      handlers.onResume();
    } else if (mode === 'abandon') {
      event.preventDefault();
      handlers.onQuit();
    } else if (mode === 'survivor' || mode === 'howto' || mode === 'settings') {
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
    handlers.onPick(Number(event.key) - 1);
  }
}

function goBack(): void {
  if (origin === 'pause' || mode === 'abandon') showPause();
  else showMainMenu();
}

type ActionSpec = { label: string; onClick: () => void; primary?: boolean };

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
  const kicker = kickerEl();
  const title = titleEl();
  const sub = subEl();
  const body = bodyEl();
  const choices = choicesEl();
  const actions = actionsEl();
  if (!root || !kicker || !title || !sub || !body || !choices || !actions) return;
  mode = spec.screen;
  syncOverlayAttr();
  root.dataset.screen = spec.screen;
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
    actions.appendChild(actionButton(action.label, action.onClick, action.primary));
  }
  showRoot(root);
}

function settingsForm(settings: GameSettings): HTMLElement {
  const wrap = document.createElement('div');
  wrap.appendChild(
    rangeRow('Master volume', 'Silent until audio is bound. Stored anyway.', settings.masterVolume, (value) => {
      patchSettings({ masterVolume: value });
    }),
  );
  wrap.appendChild(
    checkRow('Mute', 'Keeps the choir dark.', settings.muted, (value) => {
      patchSettings({ muted: value });
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
  const row = document.createElement('div');
  row.className = 'setting-row';
  const text = document.createElement('label');
  const title = document.createElement('span');
  title.textContent = label;
  const note = document.createElement('span');
  note.className = 'hint';
  note.textContent = hint;
  text.append(title, note);
  const input = document.createElement('input');
  input.type = 'range';
  input.min = '0';
  input.max = '1';
  input.step = '0.05';
  input.value = String(value);
  input.setAttribute('aria-label', label);
  input.addEventListener('input', () => onChange(Number(input.value)));
  row.append(text, input);
  return row;
}

function checkRow(label: string, hint: string, value: boolean, onChange: (value: boolean) => void): HTMLElement {
  const row = document.createElement('div');
  row.className = 'setting-row';
  const text = document.createElement('label');
  const title = document.createElement('span');
  title.textContent = label;
  const note = document.createElement('span');
  note.className = 'hint';
  note.textContent = hint;
  text.append(title, note);
  const input = document.createElement('input');
  input.type = 'checkbox';
  input.checked = value;
  input.setAttribute('aria-label', label);
  input.addEventListener('change', () => onChange(input.checked));
  row.append(text, input);
  return row;
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
    ['Shift / Space', dashLine],
    ['1 / 2 / 3', 'Choose a tablet when you level.'],
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

function dossierCard(survivor: SurvivorDef, compact: boolean): HTMLElement {
  const card = document.createElement('div');
  card.className = 'dossier';
  const name = document.createElement('p');
  name.className = 'dossier-name';
  name.textContent = survivor.name;
  const role = document.createElement('p');
  role.className = 'dossier-role';
  role.textContent = 'The Vessel';
  const lore = document.createElement('p');
  lore.className = 'dossier-lore';
  lore.textContent = survivor.lore ?? 'A stolen vessel of clay and quicksilver.';
  const skills = document.createElement('p');
  skills.className = 'dossier-skills';
  const primary = skillFor(survivor, 'primary');
  const utility = skillFor(survivor, 'utility');
  skills.textContent = compact
    ? `${primary?.name ?? 'Ignis Bolt'} · ${utility?.name ?? 'Phase Step'}`
    : `Primary ${primary?.name ?? 'Ignis Bolt'} · Utility ${utility?.name ?? 'Phase Step'}`;
  card.append(name, role, lore, skills);
  return card;
}

function recapBody(recap: RunRecap): HTMLElement {
  const list = document.createElement('div');
  list.className = 'recap-list';
  const rows: [string, string][] = [
    ['Vessel', recap.survivor],
    ['Stage', recap.stage],
    ['Time', formatTime(recap.time)],
    ['Level', String(recap.level)],
    ['Difficulty', `×${recap.coefficient.toFixed(2)}`],
    [
      'Tablets',
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

function skillFor(survivor: SurvivorDef, slot: 'primary' | 'utility'): SkillDef | null {
  const id = survivor.skills[slot];
  return id ? catalog.skill(id) : null;
}

function actionButton(label: string, onClick: () => void, primary = false): HTMLButtonElement {
  const btn = document.createElement('button');
  btn.type = 'button';
  btn.className = primary ? 'seal-btn action-primary' : 'seal-btn';
  btn.textContent = label;
  btn.addEventListener('click', onClick);
  return btn;
}

function showRoot(root: HTMLElement): void {
  root.classList.remove('hidden');
  root.setAttribute('aria-hidden', 'false');
  const focusable = root.querySelector<HTMLButtonElement>('button, input');
  focusable?.focus();
}

function overlayEl(): HTMLElement | null {
  return document.getElementById('overlay');
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
