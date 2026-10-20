import type { ItemDef, ItemHook, StatId } from '../data/schema';

export type OverlayMode = 'hidden' | 'menu' | 'pause' | 'levelup' | 'runend';

export type OverlayHandlers = {
  onStart: () => void;
  onResume: () => void;
  onQuit: () => void;
  onPause: () => void;
  onPick: (index: number) => void;
  onRestart: () => void;
};

const STAT_LABEL: Record<StatId, string> = {
  speed: 'speed',
  maxHp: 'HP',
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

export function bindOverlay(next: Partial<OverlayHandlers>): void {
  handlers = { ...handlers, ...next };
  if (!keysBound) {
    keysBound = true;
    window.addEventListener('keydown', onOverlayKey);
  }
}

export function getOverlayMode(): OverlayMode {
  return mode;
}

export function hideOverlay(): void {
  const root = overlayEl();
  if (!root) return;
  mode = 'hidden';
  root.classList.add('hidden');
  root.setAttribute('aria-hidden', 'true');
}

export function showMainMenu(): void {
  const root = overlayEl();
  const title = titleEl();
  const sub = subEl();
  const choices = choicesEl();
  const actions = actionsEl();
  if (!root || !title || !sub || !choices || !actions) return;
  mode = 'menu';
  title.textContent = 'survivors';
  sub.textContent = 'Aimed primary · hold the teleporter · enter the portal. WASD move · mouse aim · hold LMB fire · Shift/Space dash.';
  choices.replaceChildren();
  actions.replaceChildren();
  actions.appendChild(actionButton('Start run', () => handlers.onStart(), true));
  showRoot(root);
}

export function showPause(): void {
  const root = overlayEl();
  const title = titleEl();
  const sub = subEl();
  const choices = choicesEl();
  const actions = actionsEl();
  if (!root || !title || !sub || !choices || !actions) return;
  mode = 'pause';
  title.textContent = 'Paused';
  sub.textContent = 'Esc to resume.';
  choices.replaceChildren();
  actions.replaceChildren();
  actions.appendChild(actionButton('Resume', () => handlers.onResume(), true));
  actions.appendChild(actionButton('Quit to menu', () => handlers.onQuit()));
  showRoot(root);
}

export function showLevelUp(items: ItemDef[]): void {
  const root = overlayEl();
  const title = titleEl();
  const sub = subEl();
  const choices = choicesEl();
  const actions = actionsEl();
  if (!root || !title || !sub || !choices || !actions) return;
  mode = 'levelup';
  title.textContent = 'Level up';
  sub.textContent = 'Pick 1 of 3. Keys 1 / 2 / 3.';
  choices.replaceChildren();
  items.forEach((item, index) => {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = `choice rarity-${item.rarity}`;
    btn.innerHTML = `<span class="choice-key">${index + 1}</span><span class="choice-name">${item.name}</span><span class="choice-hooks">${describeHooks(item)}</span>`;
    btn.addEventListener('click', () => handlers.onPick(index));
    choices.appendChild(btn);
  });
  actions.replaceChildren();
  showRoot(root);
}

export function showRunEnd(kind: 'victory' | 'defeat', detail: string): void {
  const root = overlayEl();
  const title = titleEl();
  const sub = subEl();
  const choices = choicesEl();
  const actions = actionsEl();
  if (!root || !title || !sub || !choices || !actions) return;
  mode = 'runend';
  title.textContent = kind === 'victory' ? 'Stage clear' : 'Downed';
  sub.textContent = detail;
  choices.replaceChildren();
  actions.replaceChildren();
  actions.appendChild(actionButton('Run again', () => handlers.onRestart(), true));
  actions.appendChild(actionButton('Menu', () => handlers.onQuit()));
  showRoot(root);
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

function onOverlayKey(event: KeyboardEvent): void {
  if (event.key === 'Escape') {
    if (mode === 'pause') {
      event.preventDefault();
      handlers.onResume();
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
    }
    return;
  }
  if (mode !== 'levelup') return;
  if (event.key === '1' || event.key === '2' || event.key === '3') {
    handlers.onPick(Number(event.key) - 1);
  }
}

function actionButton(label: string, onClick: () => void, primary = false): HTMLButtonElement {
  const btn = document.createElement('button');
  btn.type = 'button';
  btn.className = primary ? 'choice action-primary' : 'choice';
  btn.textContent = label;
  btn.addEventListener('click', onClick);
  return btn;
}

function showRoot(root: HTMLElement): void {
  root.classList.remove('hidden');
  root.setAttribute('aria-hidden', 'false');
}

function overlayEl(): HTMLElement | null {
  return document.getElementById('overlay');
}

function titleEl(): HTMLElement | null {
  return document.getElementById('overlay-title');
}

function subEl(): HTMLElement | null {
  return document.getElementById('overlay-sub');
}

function choicesEl(): HTMLElement | null {
  return document.getElementById('overlay-choices');
}

function actionsEl(): HTMLElement | null {
  return document.getElementById('overlay-actions');
}
