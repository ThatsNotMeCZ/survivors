import { playSfx } from '../audio';
import { catalog } from '../data/catalog';
import type {
  EntityDef,
  EntityRole,
  ItemDef,
  ItemHook,
  ItemRarity,
  SkillDef,
  SkillSlot,
  StatId,
  SurvivorDef,
} from '../data/schema';
import { mountEntityArt, mountObstacleArt } from './entity-art';
import { formatTime } from './hud';
import { ITEM_CHOICE_PX, makeItemChip, makeItemIcon } from './item-art';
import {
  checkUnlockCondition,
  getRecords,
  isSurvivorUnlocked,
  resetRecords,
  type ArchiveRecords,
} from './records';
import { getSettings } from './settings';
import { SKILL_SLOT_PX, makeSkillIcon } from './skill-art';
import { hydrateUiSprites } from './ui-art';
import { mountVesselArt } from './vessel-art';

export type ArchiveTab = 'howto' | 'lore' | 'entities' | 'reliquary' | 'stats';

type LoreSubTab = 'work' | 'vessels' | 'chambers' | 'exchange';

const TAB_SPECS: { id: ArchiveTab; label: string; sub: string; glyph: string }[] = [
  { id: 'howto', label: 'RITES OF MOTION', sub: 'Controls & Mechanics', glyph: '⚶' },
  { id: 'lore', label: 'CHRONICLES', sub: 'World, Vessels & Chambers', glyph: '☉' },
  { id: 'entities', label: 'BESTIARY', sub: 'Dross, Elites & Guardians', glyph: '🜂' },
  { id: 'reliquary', label: 'RELIQUARY', sub: 'Augmentations & Relics', glyph: '🜍' },
  { id: 'stats', label: 'LEDGER', sub: 'Records & Run History', glyph: '☿' },
];

const STAT_LABEL: Record<StatId, string> = {
  speed: 'Speed',
  maxHp: 'Max HP',
  radius: 'Vessel Size',
  damage: 'Damage',
  cooldown: 'Cooldown',
  critChance: 'Crit Chance',
  critDamage: 'Crit Damage',
};

const ROLE_LABEL: Record<EntityRole, string> = {
  fodder: 'Lesser Dross',
  elite: 'Noxious Elite',
  boss: 'Seal Guardian',
};

let activeTab: ArchiveTab = 'howto';
let activeLoreSub: LoreSubTab = 'work';
let activeEntityRole: 'all' | EntityRole = 'all';
let selectedEntityId: string = catalog.entities[0]?.id ?? 'ember-mite';
let activeItemRarity: 'all' | ItemRarity = 'all';
let selectedItemId: string = catalog.items[0]?.id ?? 'glass-cannon';
let howtoVesselId: string = '';
let confirmPurge = false;
let backBound = false;
let onBackHandler: () => void = () => undefined;

export function renderArchivesView(onBack: () => void, initialTab?: ArchiveTab): void {
  onBackHandler = onBack;
  if (initialTab) activeTab = initialTab;
  const rec = getRecords();
  if (!howtoVesselId) {
    howtoVesselId = getSettings().survivorId || catalog.world.defaultSurvivor;
  }
  const howtoSurv = catalog.survivors.find((s) => s.id === howtoVesselId);
  if (!howtoSurv || !isSurvivorUnlocked(howtoSurv, rec)) {
    howtoVesselId = catalog.world.defaultSurvivor;
  }
  confirmPurge = false;

  const root = document.getElementById('archives');
  if (!root) return;

  if (!backBound) {
    backBound = true;
    document.getElementById('archives-back')?.addEventListener('click', () => {
      playSfx('close');
      onBackHandler();
    });
  }

  renderRibbon();
  renderSidebar();
  renderStage();
  hydrateUiSprites(root);
}

function renderRibbon(): void {
  const ribbon = document.getElementById('archives-ribbon');
  if (!ribbon) return;
  const rec = getRecords();
  const discoveredEntities = catalog.entities.filter(
    (e) => (rec.entityEncounters[e.id] ?? 0) > 0 || (rec.entityKills[e.id] ?? 0) > 0,
  ).length;
  const collectedLores = catalog.entities.filter((e) => (rec.entityLores[e.id] ?? 0) > 0).length;
  const boundRelics = catalog.items.filter((i) => (rec.itemPicks[i.id] ?? 0) > 0).length;

  const pills: [string, string][] = [
    ['Workings', String(rec.totalRuns)],
    ['Transmutations', String(rec.victories)],
    ['Dross Slain', rec.totalKills.toLocaleString()],
    ['Bestiary', `${discoveredEntities} / ${catalog.entities.length}`],
    ['Treatises', `${collectedLores} / ${catalog.entities.length}`],
    ['Reliquary', `${boundRelics} / ${catalog.items.length}`],
  ];

  ribbon.replaceChildren();
  for (const [k, v] of pills) {
    const item = document.createElement('div');
    item.className = 'archives-ribbon-pill';
    const label = document.createElement('span');
    label.className = 'ribbon-k';
    label.textContent = k;
    const val = document.createElement('span');
    val.className = 'ribbon-v';
    val.textContent = v;
    item.append(label, val);
    ribbon.appendChild(item);
  }
}

function renderSidebar(): void {
  const nav = document.getElementById('archives-nav');
  if (!nav) return;
  nav.replaceChildren();

  for (const spec of TAB_SPECS) {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'archives-tab-btn';
    btn.setAttribute('role', 'tab');
    btn.setAttribute('aria-selected', spec.id === activeTab ? 'true' : 'false');
    btn.dataset.active = spec.id === activeTab ? '1' : '0';

    const glyph = document.createElement('span');
    glyph.className = 'archives-tab-glyph';
    glyph.setAttribute('aria-hidden', 'true');
    glyph.textContent = spec.glyph;

    const copy = document.createElement('span');
    copy.className = 'archives-tab-copy';
    const title = document.createElement('span');
    title.className = 'archives-tab-label';
    title.textContent = spec.label;
    const sub = document.createElement('span');
    sub.className = 'archives-tab-sub';
    sub.textContent = spec.sub;
    copy.append(title, sub);

    const arrow = document.createElement('span');
    arrow.className = 'vessel-active-arrow';
    arrow.setAttribute('aria-hidden', 'true');

    btn.append(glyph, copy, arrow);
    btn.addEventListener('click', () => {
      if (activeTab === spec.id) return;
      playSfx('click');
      activeTab = spec.id;
      confirmPurge = false;
      renderSidebar();
      renderStage();
    });
    nav.appendChild(btn);
  }
}

function renderStage(): void {
  const stage = document.getElementById('archives-stage');
  if (!stage) return;
  stage.replaceChildren();
  stage.dataset.tab = activeTab;

  if (activeTab === 'howto') {
    stage.appendChild(buildHowToView());
  } else if (activeTab === 'lore') {
    stage.appendChild(buildLoreView());
  } else if (activeTab === 'entities') {
    stage.appendChild(buildBestiaryView());
  } else if (activeTab === 'reliquary') {
    stage.appendChild(buildReliquaryView());
  } else {
    stage.appendChild(buildLedgerView());
  }
  hydrateUiSprites(stage);
}

/* ==========================================================================
   TAB 1: RITES OF MOTION (HOW TO PLAY)
   ========================================================================== */

function buildHowToView(): HTMLElement {
  const wrap = document.createElement('div');
  wrap.className = 'archives-scroll-pane';

  const intro = sectionBanner(
    'Rites of Motion',
    'HOW TO SURVIVE THE GREAT WORK',
    'Kite the dross. Aim your primary art. Charge the Transmutation Circle. Standing still is death.',
  );
  wrap.appendChild(intro);

  // 1. Controls & Vessel Bindings
  const controlsSec = document.createElement('section');
  controlsSec.className = 'archives-panel';

  const controlsHead = document.createElement('div');
  controlsHead.className = 'archives-panel-head';
  const h3 = document.createElement('h3');
  h3.className = 'archives-section-title';
  h3.textContent = 'I. VESSEL CONTROLS & RITE BINDINGS';

  const rec = getRecords();
  const switcher = document.createElement('div');
  switcher.className = 'archives-filter-bar';
  for (const surv of catalog.survivors) {
    const unlocked = isSurvivorUnlocked(surv, rec);
    const pill = document.createElement('button');
    pill.type = 'button';
    pill.className = 'archives-filter-pill';
    pill.dataset.active = surv.id === howtoVesselId ? '1' : '0';
    pill.disabled = !unlocked;
    pill.textContent = unlocked ? surv.name : '🔒 ???';
    if (unlocked) {
      pill.addEventListener('click', () => {
        playSfx('click');
        howtoVesselId = surv.id;
        renderStage();
      });
    }
    switcher.appendChild(pill);
  }
  controlsHead.append(h3, switcher);
  controlsSec.appendChild(controlsHead);

  const survivor =
    catalog.survivors.find((s) => s.id === howtoVesselId) ??
    catalog.survivor(catalog.world.defaultSurvivor);
  controlsSec.appendChild(buildControlsTable(survivor));
  wrap.appendChild(controlsSec);

  // 2. Four Beats of a Working
  const loopSec = document.createElement('section');
  loopSec.className = 'archives-panel';
  const loopTitle = document.createElement('h3');
  loopTitle.className = 'archives-section-title';
  loopTitle.textContent = 'II. THE FOUR STAGES OF A WORKING';
  loopSec.appendChild(loopTitle);

  const beatsGrid = document.createElement('div');
  beatsGrid.className = 'archives-cards-grid cols-2';
  const beats: { step: string; title: string; body: string }[] = [
    {
      step: '01 · DISTILLATION',
      title: 'Harvest Mercury Drops & Ascend',
      body: `Slay lesser dross to release Mercury Drops (Essence). Every ascension pauses the chamber and offers 1 of ${catalog.loop.levelChoices} alchemical augmentations. Common and Uncommon relics fortify your baseline; Rare and Lunar covenants demand a severe trade-off.`,
    },
    {
      step: '02 · CONVERGENCE',
      title: 'Channel the Transmutation Circle',
      body: 'Once the chamber clock expires, the Transmutation Circle manifests. An off-screen chevron guides you to the ring. The seal only charges while you stand within its perimeter—leaving cools the seal until you return.',
    },
    {
      step: '03 · THE GUARDIAN',
      title: 'Shatter the Seal Guardian & Descend',
      body: 'Completing the hold summons the chamber’s Seal Guardian. Slaying the Guardian tears open the Rift at the point of its death (or completes the Great Work in the final chamber). Stand in the Rift for 1.4s to descend.',
    },
    {
      step: '04 · RISING PRESSURE',
      title: 'Outpace the Stage Director',
      body: 'The chamber’s Difficulty Coefficient rises relentlessly with time and stage depth. The Director spends its growing credit budget on shielded Noxious Elites and Astral Watchers rather than mindless fodder.',
    },
  ];
  for (const beat of beats) {
    const card = document.createElement('article');
    card.className = 'archives-info-card';
    const kicker = document.createElement('p');
    kicker.className = 'info-card-kicker';
    kicker.textContent = beat.step;
    const title = document.createElement('h4');
    title.className = 'info-card-title';
    title.textContent = beat.title;
    const p = document.createElement('p');
    p.className = 'info-card-body';
    p.textContent = beat.body;
    card.append(kicker, title, p);
    beatsGrid.appendChild(card);
  }
  loopSec.appendChild(beatsGrid);
  wrap.appendChild(loopSec);

  // 3. Chamber Props, Hazards & Elite Modifiers
  const mechSec = document.createElement('section');
  mechSec.className = 'archives-panel';
  const mechTitle = document.createElement('h3');
  mechTitle.className = 'archives-section-title';
  mechTitle.textContent = 'III. CHAMBER PROPS, HAZARDS & ELITE WARDS';
  mechSec.appendChild(mechTitle);

  const obsCfg = catalog.obstacles;
  const noxCfg = catalog.loop.noxious;
  const shieldCfg = catalog.loop.shielder;

  const mechGrid = document.createElement('div');
  mechGrid.className = 'archives-cards-grid cols-2';

  const propCards: {
    kind: 'pillar' | 'hazard' | 'volatile' | 'elite';
    kicker: string;
    title: string;
    body: string;
  }[] = [
    {
      kind: 'pillar',
      kicker: 'SOLID COVER · 14 PER CHAMBER',
      title: 'Kilns, Bollards & Monoliths',
      body: 'Impassable stone and iron structures. Use them to break enemy sightlines, intercept ranged spitters, and block the lethal laser beams of Astral Watchers.',
    },
    {
      kind: 'hazard',
      kicker: 'GROUND HAZARD · 8 + ACID POOLS',
      title: 'Slag Fissures & Brine Pools',
      body: `Corrosive ground zones that reduce vessel stride to ${Math.round(obsCfg.hazard.playerSpeedMul * 100)}% (enemies to ${Math.round(obsCfg.hazard.enemySpeedMul * 100)}%) and sear for ${obsCfg.hazard.dps} base DPS. Use Phase Step or Ash Step to cross unscathed.`,
    },
    {
      kind: 'volatile',
      kicker: 'VOLATILE VESSELS · 9 PER CHAMBER',
      title: 'Brimstone Urns & Rime Casks',
      body: `Strike with ${obsCfg.volatile.hp} base damage to prime a ${obsCfg.volatile.prime}s fuse. Detonates in a ${obsCfg.volatile.explosionRadius}px blast dealing ${obsCfg.volatile.enemyDamage}× damage to foes (${obsCfg.volatile.playerDamage} to you). Rime Casks also chill caught targets.`,
    },
    {
      kind: 'elite',
      kicker: 'ELITE AFFLICTION · NOXIOUS & SHIELDED',
      title: 'Aether Wards & Caustic Corpses',
      body: `Every Elite carries a +${Math.round(shieldCfg.percentHp * 100)}% regenerating Aether Shield (recharges after ${shieldCfg.delay}s unharmed), slows your stride by ${Math.round((1 - noxCfg.contactSlowMul) * 100)}% on contact, and detonates ${noxCfg.corpseDelay}s after death into a permanent acid pool.`,
    },
  ];

  for (const item of propCards) {
    const card = document.createElement('article');
    card.className = 'archives-info-card with-art';

    const artBox = document.createElement('div');
    artBox.className = 'info-card-art';
    if (item.kind === 'elite') {
      mountEntityArt(artBox, 'ember-chaser', 'archives-prop-canvas', item.title);
    } else {
      mountObstacleArt(artBox, item.kind, 'cinder', 'archives-prop-canvas', item.title);
    }

    const copy = document.createElement('div');
    copy.className = 'info-card-copy';
    const kicker = document.createElement('p');
    kicker.className = 'info-card-kicker';
    kicker.textContent = item.kicker;
    const title = document.createElement('h4');
    title.className = 'info-card-title';
    title.textContent = item.title;
    const p = document.createElement('p');
    p.className = 'info-card-body';
    p.textContent = item.body;
    copy.append(kicker, title, p);

    card.append(artBox, copy);
    mechGrid.appendChild(card);
  }

  mechSec.appendChild(mechGrid);
  wrap.appendChild(mechSec);
  return wrap;
}

function buildControlsTable(survivor: SurvivorDef): HTMLElement {
  const primary = skillFor(survivor, 'primary');
  const secondary = skillFor(survivor, 'secondary');
  const utility = skillFor(survivor, 'utility');
  const special = skillFor(survivor, 'special');

  const table = document.createElement('table');
  table.className = 'archives-table';
  const head = document.createElement('thead');
  const hr = document.createElement('tr');
  for (const col of ['Input', 'Rite / Action', 'Effect in the Chamber']) {
    const th = document.createElement('th');
    th.textContent = col;
    hr.appendChild(th);
  }
  head.appendChild(hr);

  const body = document.createElement('tbody');
  const rows: [string, string, string][] = [
    ['WASD / Arrows', 'Stride', 'Move the vessel continuously across the chamber floor.'],
    ['Mouse Cursor', 'Sightline', 'Aim your primary, secondary, and ultimate arts.'],
    [
      'Hold LMB',
      primary ? `${primary.name} (I)` : 'Primary Art (I)',
      primary?.hook ?? 'Channel your primary weapon toward the cursor.',
    ],
    [
      'Press RMB',
      secondary ? `${secondary.name} (II · ${secondary.cooldown}s)` : 'Secondary Art (II)',
      secondary?.hook ?? 'Unleash your secondary tactical art.',
    ],
    [
      'Shift / Space',
      utility ? `${utility.name} (III · ${utility.cooldown}s)` : 'Utility Dash (III)',
      utility?.hook ?? 'Dash with brief invulnerability frames through foes and hazards.',
    ],
    [
      'Press Q',
      special ? `${special.name} (IV · ${special.cooldown}s)` : 'Ultimate Rite (IV)',
      special?.hook ?? 'Invoke your high-impact ultimate rite.',
    ],
    ['1 / 2 / 3', 'Bind Augmentation', 'Select a tablet during vessel ascension (or use Arrow keys + Enter).'],
    ['Stand in Ring', 'Channel / Descend', 'Hold inside the Transmutation Circle or Rift portal until charged.'],
    ['Esc', 'Pause Working', 'Pause simulation, inspect inventory, or open The Archives.'],
  ];

  for (const [k, rite, desc] of rows) {
    const tr = document.createElement('tr');
    const tdKey = document.createElement('td');
    tdKey.className = 'key-cell';
    tdKey.textContent = k;
    const tdRite = document.createElement('td');
    tdRite.className = 'rite-cell';
    tdRite.textContent = rite;
    const tdDesc = document.createElement('td');
    tdDesc.textContent = desc;
    tr.append(tdKey, tdRite, tdDesc);
    body.appendChild(tr);
  }

  table.append(head, body);
  return table;
}

/* ==========================================================================
   TAB 2: HERMETIC CHRONICLES (WORLD, VESSELS & CHAMBERS LORE)
   ========================================================================== */

function buildLoreView(): HTMLElement {
  const wrap = document.createElement('div');
  wrap.className = 'archives-scroll-pane';

  const header = sectionBanner(
    'Hermetic Chronicles',
    'APOCRYPHA OF THE GREAT WORK',
    'Treatises recovered from the outer foundry, the frozen sea-locks, and the sealed glacial vault.',
  );
  wrap.appendChild(header);

  const subBar = document.createElement('div');
  subBar.className = 'archives-filter-bar';
  const subs: { id: LoreSubTab; label: string }[] = [
    { id: 'work', label: 'I. The Great Work' },
    { id: 'vessels', label: 'II. Vessels & Arts' },
    { id: 'chambers', label: 'III. The Three Chambers' },
    { id: 'exchange', label: 'IV. Law of Exchange' },
  ];
  for (const s of subs) {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'archives-filter-pill';
    btn.dataset.active = s.id === activeLoreSub ? '1' : '0';
    btn.textContent = s.label;
    btn.addEventListener('click', () => {
      playSfx('click');
      activeLoreSub = s.id;
      renderStage();
    });
    subBar.appendChild(btn);
  }
  wrap.appendChild(subBar);

  if (activeLoreSub === 'work') {
    wrap.appendChild(buildGreatWorkLore());
  } else if (activeLoreSub === 'vessels') {
    wrap.appendChild(buildVesselsLore());
  } else if (activeLoreSub === 'chambers') {
    wrap.appendChild(buildChambersLore());
  } else {
    wrap.appendChild(buildExchangeLore());
  }

  return wrap;
}

function buildGreatWorkLore(): HTMLElement {
  const grid = document.createElement('div');
  grid.className = 'archives-cards-grid cols-2';

  const treatises: { kicker: string; title: string; paragraphs: string[] }[] = [
    {
      kicker: 'FOLIO I · THE SHATTERED CRUCIBLE',
      title: 'When the Magisterium Burned',
      paragraphs: [
        'The Great Work was meant to distill immortal quintessence from base lead, sulfur, and sea-salt. Instead, the Grand Crucible cracked at the midnight conjunction, flooding the subterranean vaults with volatile humors.',
        'The alchemists were consumed in the first flash of calcination. What remained in the ash were the failed transmutations—skittering clots of slag, brine-swollen husks, and the colossal furnace cores that now guard the lower seals.',
      ],
    },
    {
      kicker: 'FOLIO II · ESSENCE & MERCURY',
      title: 'The Circulation of Quicksilver',
      paragraphs: [
        'No natural flesh can breathe the fumes of the Rifts. Only constructed or consecrated Vessels—animated by refined quicksilver—can walk the flagstones without dissolving into dross.',
        'Every fallen abomination releases a bead of stolen Mercury (Essence). By drawing these beads back into its core, a Vessel ascends in potency, binding fractured hermetic tablets directly into its frame.',
      ],
    },
    {
      kicker: 'FOLIO III · TRANSMUTATION CIRCLES',
      title: 'Seals of Passage',
      paragraphs: [
        'Each chamber is locked by a heavy Transmutation Circle etched into the stone. Only when the chamber’s temporal alignment arrives can a Vessel stand inside the hexagram and channel its own vital heat into the ring.',
        'The channeling acts as a beacon: the chamber’s hordes converge on the circle, and the Seal Guardian awakens to crush the intruder before the Rift can tear open.',
      ],
    },
    {
      kicker: 'FOLIO IV · THE THREE OPERATIONS',
      title: 'Nigredo, Albedo, Rubedo',
      paragraphs: [
        'The descent follows the three classical stages of hermetic transmutation: first Nigredo in the blackened ash of the Cinder Yard; second Albedo in the white salt-frost of the Rime Dock; and finally Rubedo in the deep Glacial Tomb.',
        'Only by slaying the Frost Emperor at the bottom of the third seal is the Great Work stabilized and the transmutation made whole.',
      ],
    },
  ];

  for (const entry of treatises) {
    const card = document.createElement('article');
    card.className = 'archives-lore-parchment parchment-box';
    card.dataset.uiSprite = 'parchment-panel';
    const kicker = document.createElement('p');
    kicker.className = 'overlay-kicker';
    kicker.textContent = entry.kicker;
    const h4 = document.createElement('h4');
    h4.className = 'lore-parchment-title';
    h4.textContent = entry.title;
    card.append(kicker, h4);
    for (const text of entry.paragraphs) {
      const p = document.createElement('p');
      p.className = 'lore-parchment-text';
      p.textContent = text;
      card.appendChild(p);
    }
    grid.appendChild(card);
  }

  return grid;
}

function buildVesselsLore(): HTMLElement {
  const wrap = document.createElement('div');
  wrap.className = 'archives-stack';
  const rec = getRecords();

  for (const survivor of catalog.survivors) {
    const sRec = rec.bySurvivor[survivor.id];
    const unlockState = checkUnlockCondition(survivor.unlock, rec);
    const unlocked = unlockState.unlocked;
    const panel = document.createElement('section');
    panel.className = unlocked ? 'archives-panel vessel-lore-card' : 'archives-panel vessel-lore-card is-locked';
    panel.dataset.seen = unlocked ? '1' : '0';

    const top = document.createElement('div');
    top.className = 'vessel-lore-top';

    const artWrap = document.createElement('div');
    artWrap.className = 'vessel-lore-art';
    artWrap.dataset.seen = unlocked ? '1' : '0';
    mountVesselArt(artWrap, survivor.id, 'vessel-lore-canvas', unlocked ? survivor.name : 'Sealed Vessel');

    const meta = document.createElement('div');
    meta.className = 'vessel-lore-meta';
    const kicker = document.createElement('p');
    kicker.className = 'info-card-kicker';
    kicker.textContent = unlocked
      ? `${(survivor.title ?? 'The Vessel').toUpperCase()} · VESSEL DOSSIER`
      : 'SEALED VESSEL · UNCONSECRATED FRAME';
    const name = document.createElement('h3');
    name.className = 'vessel-lore-name';
    name.textContent = unlocked ? survivor.name.toUpperCase() : '???';
    const lore = document.createElement('p');
    lore.className = unlocked ? 'vessel-lore-text' : 'vessel-lore-text hall-lore is-locked-lore';
    lore.textContent = unlocked
      ? survivor.lore ?? ''
      : `Vessel Sealed — Requirement: ${survivor.unlock?.label ?? 'Complete required rite'} (${unlockState.progress}).`;

    const statPills = document.createElement('div');
    statPills.className = 'archives-stat-chips';
    const pills: [string, string][] = unlocked
      ? [
          ['Vitality', `${survivor.stats.maxHp} HP`],
          ['Stride', `${survivor.stats.speed} px/s`],
          ['Radius', `${survivor.stats.radius} px`],
          ['Workings', String(sRec?.runs ?? 0)],
          ['Victories', String(sRec?.victories ?? 0)],
        ]
      : [
          ['Vitality', '???'],
          ['Stride', '???'],
          ['Status', `SEALED (${unlockState.progress})`],
        ];
    for (const [k, v] of pills) {
      statPills.appendChild(makeStatChip(k, v));
    }

    meta.append(kicker, name, lore, statPills);
    top.append(artWrap, meta);
    panel.appendChild(top);

    if (unlocked) {
      const skillsGrid = document.createElement('div');
      skillsGrid.className = 'vessel-skills-codex';
      const slots: SkillSlot[] = ['primary', 'secondary', 'utility', 'special'];
      const slotKeys: Record<SkillSlot, string> = {
        primary: 'I · LMB',
        secondary: 'II · RMB',
        utility: 'III · Shift / Space',
        special: 'IV · Q',
      };

      for (const slot of slots) {
        const skill = skillFor(survivor, slot);
        if (!skill) continue;
        const sCard = document.createElement('div');
        sCard.className = 'codex-skill-card';

        const iconWrap = document.createElement('div');
        iconWrap.className = 'codex-skill-icon-wrap';
        const icon = makeSkillIcon(skill.id, skill.name, 'codex-skill-icon', SKILL_SLOT_PX);
        icon.addEventListener('error', () => icon.remove());
        iconWrap.appendChild(icon);

        const sBody = document.createElement('div');
        sBody.className = 'codex-skill-body';
        const sHead = document.createElement('div');
        sHead.className = 'codex-skill-head';
        const sName = document.createElement('strong');
        sName.textContent = skill.name;
        const sMeta = document.createElement('span');
        sMeta.className = 'codex-skill-meta';
        sMeta.textContent = `${slotKeys[slot]} · ${skill.cooldown}s CD`;
        sHead.append(sName, sMeta);

        const sHook = document.createElement('p');
        sHook.className = 'codex-skill-hook';
        sHook.textContent = skill.hook ?? '';

        const sLore = document.createElement('p');
        sLore.className = 'codex-skill-lore';
        sLore.textContent = skill.lore ? `"${skill.lore}"` : '';

        sBody.append(sHead, sHook, sLore);
        sCard.append(iconWrap, sBody);
        skillsGrid.appendChild(sCard);
      }

      panel.appendChild(skillsGrid);
    }
    wrap.appendChild(panel);
  }

  return wrap;
}

function buildChambersLore(): HTMLElement {
  const wrap = document.createElement('div');
  wrap.className = 'archives-stack';
  const rec = getRecords();

  catalog.loop.stages.forEach((stage, index) => {
    const visits = rec.stageVisits[stage.id] ?? 0;
    const clears = rec.stageClears[stage.id] ?? 0;
    const visited = visits > 0 || clears > 0;

    const card = document.createElement('section');
    card.className = visited ? 'archives-panel chamber-lore-card' : 'archives-panel chamber-lore-card is-unseen';
    card.dataset.seen = visited ? '1' : '0';

    const head = document.createElement('div');
    head.className = 'chamber-lore-head';
    const left = document.createElement('div');
    const kicker = document.createElement('p');
    kicker.className = 'info-card-kicker';
    kicker.textContent = visited
      ? (stage.kicker ?? `Chamber ${index + 1}`)
      : `CHAMBER ${index + 1} · UNCHARTERED SEAL`;
    const title = document.createElement('h3');
    title.className = 'vessel-lore-name';
    title.textContent = visited ? `${index + 1}. ${stage.name.toUpperCase()}` : `${index + 1}. ???`;
    left.append(kicker, title);

    const chips = document.createElement('div');
    chips.className = 'archives-stat-chips';
    if (visited) {
      chips.append(
        makeStatChip('Visited', String(visits)),
        makeStatChip('Cleared', String(clears)),
        makeStatChip('Seal At', formatTime(stage.teleporterAt)),
        makeStatChip('Hold Duration', `${stage.teleporterHold}s`),
      );
    } else {
      chips.append(makeStatChip('Status', 'UNENCOUNTERED'));
    }
    head.append(left, chips);

    const lore = document.createElement('p');
    lore.className = visited ? 'vessel-lore-text' : 'vessel-lore-text hall-lore is-locked-lore';
    lore.textContent = visited
      ? stage.lore ?? ''
      : 'Uncharted Chamber — Descend through the Rifts to unseal this chamber’s chronicle and survey its hazards.';

    const details = document.createElement('div');
    details.className = 'archives-cards-grid cols-2';

    const denizens = document.createElement('div');
    denizens.className = 'archives-info-card';
    denizens.dataset.seen = visited ? '1' : '0';
    const dKick = document.createElement('p');
    dKick.className = 'info-card-kicker';
    dKick.textContent = 'NATIVE DENIZENS';
    const dList = document.createElement('p');
    dList.className = 'info-card-body';
    if (visited) {
      const fodderName = catalog.entity(stage.fodder).name;
      const rangedName = stage.ranged ? catalog.entity(stage.ranged).name : 'None';
      const sniperName = stage.sniper ? catalog.entity(stage.sniper).name : 'None';
      const eliteName = catalog.entity(stage.elite).name;
      const bossName = catalog.entity(stage.boss).name;
      dList.textContent = `Swarm: ${fodderName} & ${rangedName} · Sightline: ${sniperName} · First Elite (${eliteName}) at ${stage.firstEliteAt}s · Seal Guardian: ${bossName}.`;
    } else {
      dList.textContent = 'Swarm: ??? · Sightline: ??? · Seal Guardian: ???';
    }
    denizens.append(dKick, dList);

    const propsBox = document.createElement('div');
    propsBox.className = 'archives-info-card';
    propsBox.dataset.seen = visited ? '1' : '0';
    const pKick = document.createElement('p');
    pKick.className = 'info-card-kicker';
    pKick.textContent = 'CHAMBER ARCHITECTURE';
    const pList = document.createElement('p');
    pList.className = 'info-card-body';
    if (visited) {
      const biomeProps = catalog.obstacles.biomes[stage.id];
      pList.textContent = biomeProps
        ? `Cover: ${biomeProps.pillar} · Ground Hazard: ${biomeProps.hazard} · Volatile Vessel: ${biomeProps.volatile}.`
        : 'Standard alchemical foundry obstacles.';
    } else {
      pList.textContent = 'Cover: ??? · Ground Hazard: ??? · Volatile Vessel: ???';
    }
    propsBox.append(pKick, pList);

    details.append(denizens, propsBox);
    card.append(head, lore, details);
    wrap.appendChild(card);
  });

  return wrap;
}

function buildExchangeLore(): HTMLElement {
  const grid = document.createElement('div');
  grid.className = 'archives-cards-grid cols-2';
  const weights = catalog.loop.rarityWeight;

  const tiers: { rarity: ItemRarity; title: string; weight: number; desc: string }[] = [
    {
      rarity: 'common',
      title: 'Common Tablets · Base Matter',
      weight: weights.common,
      desc: 'Pure, foundational alchemical grafts—tendons, slag plating, lead plumbum, and cinnabar leeches. They carry no anatomical drawback and form the backbone of every working.',
    },
    {
      rarity: 'uncommon',
      title: 'Uncommon Tablets · Refined Humors',
      weight: weights.uncommon,
      desc: 'Quicksilver draughts, spasmodic nerves, and bellows hearts. Scarcer distillations that accelerate your cooldowns and sharpen critical detonations without corrupting the vessel.',
    },
    {
      rarity: 'rare',
      title: 'Rare Tablets · Volatile Bargains',
      weight: weights.rare,
      desc: 'Double-edged masterworks such as Vitriol Veins, Parasitic Alembic, and the Astrologer’s Ocular. They grant dramatic surges in offensive power or haste at the direct cost of vitality, stride, or vessel size.',
    },
    {
      rarity: 'lunar',
      title: 'Lunar Covenants · Forbidden Heresy',
      weight: weights.lunar,
      desc: 'The Pale Moon Covenant (+75% Damage, +50% Crit Damage, −40% Max HP, +20% Vessel Size). An unforgiven heresy against the Great Work that turns the vessel into a fragile, cataclysmic conduit.',
    },
  ];

  for (const t of tiers) {
    const card = document.createElement('article');
    card.className = `archives-info-card rarity-border-${t.rarity}`;
    const kicker = document.createElement('p');
    kicker.className = `info-card-kicker rarity-text-${t.rarity}`;
    kicker.textContent = `${t.rarity.toUpperCase()} · DROP WEIGHT ${Math.round(t.weight * 100)}%`;
    const title = document.createElement('h4');
    title.className = 'info-card-title';
    title.textContent = t.title;
    const body = document.createElement('p');
    body.className = 'info-card-body';
    body.textContent = t.desc;
    card.append(kicker, title, body);
    grid.appendChild(card);
  }

  return grid;
}

/* ==========================================================================
   TAB 3: BESTIARY OF THE DROSS (ENTITIES LORE & DOSSIER)
   ========================================================================== */

function buildBestiaryView(): HTMLElement {
  const layout = document.createElement('div');
  layout.className = 'archives-split-layout';

  const leftCol = document.createElement('div');
  leftCol.className = 'archives-split-left';

  const filterBar = document.createElement('div');
  filterBar.className = 'archives-filter-bar';
  const filters: { id: 'all' | EntityRole; label: string }[] = [
    { id: 'all', label: `All (${catalog.entities.length})` },
    { id: 'fodder', label: 'Fodder' },
    { id: 'elite', label: 'Elites' },
    { id: 'boss', label: 'Guardians' },
  ];
  for (const f of filters) {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'archives-filter-pill';
    btn.dataset.active = f.id === activeEntityRole ? '1' : '0';
    btn.textContent = f.label;
    btn.addEventListener('click', () => {
      playSfx('click');
      activeEntityRole = f.id;
      const list = filteredEntities();
      if (!list.some((e) => e.id === selectedEntityId) && list[0]) {
        selectedEntityId = list[0].id;
      }
      renderStage();
    });
    filterBar.appendChild(btn);
  }
  leftCol.appendChild(filterBar);

  const rec = getRecords();
  const list = filteredEntities();
  const grid = document.createElement('div');
  grid.className = 'archives-entity-grid';

  const dossierWrap = document.createElement('aside');
  dossierWrap.className = 'archives-dossier parchment-box';
  dossierWrap.dataset.uiSprite = 'parchment-panel';

  const selected = catalog.entities.find((e) => e.id === selectedEntityId) ?? list[0] ?? catalog.entities[0];
  fillEntityDossier(dossierWrap, selected, rec);

  for (const entity of list) {
    const kills = rec.entityKills[entity.id] ?? 0;
    const seen = (rec.entityEncounters[entity.id] ?? 0) > 0 || kills > 0;
    const hasLore = (rec.entityLores[entity.id] ?? 0) > 0;

    const card = document.createElement('button');
    card.type = 'button';
    card.className = `archives-entity-card role-${entity.role}`;
    card.dataset.active = entity.id === selected.id ? '1' : '0';
    card.dataset.seen = seen ? '1' : '0';
    card.dataset.lore = hasLore ? '1' : '0';

    const artWrap = document.createElement('div');
    artWrap.className = 'entity-card-art';
    mountEntityArt(artWrap, entity.id, 'entity-card-canvas', seen ? entity.name : 'Unencountered Entity');

    const roleTag = document.createElement('span');
    roleTag.className = `entity-role-badge role-badge-${entity.role}`;
    roleTag.textContent = entity.role.toUpperCase();

    const name = document.createElement('span');
    name.className = 'entity-card-name';
    name.textContent = seen ? entity.name : '???';

    const tally = document.createElement('span');
    tally.className = 'entity-card-tally';
    tally.textContent = seen
      ? `Slain: ${kills.toLocaleString()}${hasLore ? ' · ☉' : ''}`
      : 'Unencountered';

    card.append(roleTag, artWrap, name, tally);
    card.addEventListener('click', () => {
      playSfx('click');
      selectedEntityId = entity.id;
      grid.querySelectorAll<HTMLElement>('.archives-entity-card').forEach((el) => {
        el.dataset.active = '0';
      });
      card.dataset.active = '1';
      fillEntityDossier(dossierWrap, entity, rec);
    });
    grid.appendChild(card);
  }

  leftCol.appendChild(grid);
  layout.append(leftCol, dossierWrap);
  return layout;
}

function filteredEntities(): EntityDef[] {
  if (activeEntityRole === 'all') return catalog.entities;
  return catalog.entities.filter((e) => e.role === activeEntityRole);
}

function fillEntityDossier(root: HTMLElement, entity: EntityDef, rec: ArchiveRecords): void {
  const kills = rec.entityKills[entity.id] ?? 0;
  const encounters = Math.max(kills, rec.entityEncounters[entity.id] ?? 0);
  const seen = encounters > 0 || kills > 0;
  const hasLore = (rec.entityLores[entity.id] ?? 0) > 0;

  const header = document.createElement('p');
  header.className = 'dossier-header';
  header.textContent = seen ? ROLE_LABEL[entity.role].toUpperCase() : 'UNENCOUNTERED ENTITY';

  const name = document.createElement('h2');
  name.className = 'hall-name';
  name.textContent = seen ? entity.name.toUpperCase() : '???';

  const subTitle = document.createElement('p');
  subTitle.className = 'archives-dossier-subtitle';
  subTitle.textContent = seen ? (entity.title ?? '') : 'Uncharted Dross of the Rifts';

  const stageWrap = document.createElement('div');
  stageWrap.className = 'archives-dossier-pedestal';
  stageWrap.dataset.seen = seen ? '1' : '0';
  mountEntityArt(stageWrap, entity.id, 'archives-dossier-canvas', seen ? entity.name : 'Unencountered Entity');

  const ledgerStrip = document.createElement('div');
  ledgerStrip.className = 'archives-dossier-ledger';
  const loreStatus = hasLore ? 'RECOVERED' : 'UNRECOVERED';
  ledgerStrip.innerHTML = `<span>ENCOUNTERED: <strong>${encounters.toLocaleString()}</strong></span><span>SLAIN: <strong>${kills.toLocaleString()}</strong></span><span>TREATISE: <strong>${loreStatus}</strong></span>`;

  const lore = document.createElement('p');
  if (!seen) {
    lore.className = 'hall-lore is-locked-lore';
    lore.textContent = 'Encounter this entity in the Rifts to chart its anatomy and combat behavior.';
  } else if (!hasLore) {
    lore.className = 'hall-lore is-locked-lore';
    lore.textContent =
      'Treatise Unrecovered — Slay this entity in the Rifts for a chance to recover its apocryphal lore scroll.';
  } else {
    lore.className = 'hall-lore';
    lore.textContent = entity.lore;
  }

  const statsGrid = document.createElement('div');
  statsGrid.className = 'hall-stats-grid';
  const habitats = entityHabitats(entity.id);
  const statRows: [string, string][] = seen
    ? [
        ['♥', `VITALITY: ${entity.stats.maxHp}`],
        ['🥾', `STRIDE: ${entity.stats.speed}`],
        ['⚔', `CONTACT: ${entity.contact.dps} DPS`],
        ['☿', `ESSENCE: +${entity.rewards.xp} XP`],
        ['◎', `CHAMBER: ${habitats}`],
        ['⟁', `AI: ${describeAiShort(entity)}`],
      ]
    : [
        ['♥', 'VITALITY: ???'],
        ['🥾', 'STRIDE: ???'],
        ['⚔', 'CONTACT: ???'],
        ['☿', 'ESSENCE: ???'],
        ['◎', 'CHAMBER: ???'],
        ['⟁', 'AI: ???'],
      ];
  for (const [icon, text] of statRows) {
    const cell = document.createElement('div');
    cell.className = 'hall-stat-cell';
    const ic = document.createElement('span');
    ic.className = 'hall-stat-icon';
    ic.textContent = icon;
    const tx = document.createElement('span');
    tx.className = 'hall-stat-text';
    tx.textContent = text;
    cell.append(ic, tx);
    statsGrid.appendChild(cell);
  }

  const behaviorNote = document.createElement('div');
  behaviorNote.className = 'archives-dossier-note';
  behaviorNote.textContent = seen
    ? describeEntityBehavior(entity)
    : 'Behavior unknown until encountered in the Rifts.';

  root.replaceChildren(header, name, subTitle, stageWrap, ledgerStrip, lore, statsGrid, behaviorNote);
}

function entityHabitats(entityId: string): string {
  const hits: string[] = [];
  for (const st of catalog.loop.stages) {
    if (
      st.fodder === entityId ||
      st.ranged === entityId ||
      st.sniper === entityId ||
      st.elite === entityId ||
      st.boss === entityId
    ) {
      hits.push(st.name);
    }
  }
  if (hits.length === catalog.loop.stages.length) return 'ALL CHAMBERS';
  return hits.length > 0 ? hits.join(', ').toUpperCase() : 'THE RIFTS';
}

function describeAiShort(entity: EntityDef): string {
  if (entity.ai.type === 'ranged') return 'RANGED SPIT';
  if (entity.ai.type === 'sniper') return 'ASTRAL BEAM';
  return 'RELENTLESS CHASE';
}

function describeEntityBehavior(entity: EntityDef): string {
  const parts: string[] = [];
  if (entity.ai.type === 'chase') {
    parts.push('Pursues the vessel directly across the flagstones.');
  } else if (entity.ai.type === 'ranged') {
    parts.push(
      `Maintains ${entity.ai.keep}–${entity.ai.range}px distance, telegraphs for ${entity.ai.windup}s, and fires a ${entity.ai.projectile.damage}-damage bolt every ${entity.ai.cooldown}s.`,
    );
  } else if (entity.ai.type === 'sniper') {
    parts.push(
      `Keeps ${entity.ai.keep}px distance and locks a sightline for ${entity.ai.windup}s before firing a ${entity.ai.damage}-damage beam. Solid pillars block the shot.`,
    );
  }
  if (entity.role === 'elite') {
    const nox = catalog.loop.noxious;
    const sh = catalog.loop.shielder;
    parts.push(
      `Protected by a +${Math.round(sh.percentHp * 100)}% regenerating Aether Shield. Slows on contact and ruptures ${nox.corpseDelay}s after death into a permanent acid hazard.`,
    );
  } else if (entity.role === 'boss') {
    parts.push('Manifests when the Transmutation Circle is fully charged. Slaying it opens the Rift.');
  }
  return parts.join(' ');
}

/* ==========================================================================
   TAB 4: RELIQUARY OF AUGMENTATIONS (ITEMS CODEX)
   ========================================================================== */

function buildReliquaryView(): HTMLElement {
  const layout = document.createElement('div');
  layout.className = 'archives-split-layout';

  const leftCol = document.createElement('div');
  leftCol.className = 'archives-split-left';

  const filterBar = document.createElement('div');
  filterBar.className = 'archives-filter-bar';
  const rarities: { id: 'all' | ItemRarity; label: string }[] = [
    { id: 'all', label: `All (${catalog.items.length})` },
    { id: 'common', label: 'Common' },
    { id: 'uncommon', label: 'Uncommon' },
    { id: 'rare', label: 'Rare' },
    { id: 'lunar', label: 'Lunar' },
  ];
  for (const r of rarities) {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'archives-filter-pill';
    btn.dataset.active = r.id === activeItemRarity ? '1' : '0';
    btn.textContent = r.label;
    btn.addEventListener('click', () => {
      playSfx('click');
      activeItemRarity = r.id;
      const list = filteredItems();
      if (!list.some((i) => i.id === selectedItemId) && list[0]) {
        selectedItemId = list[0].id;
      }
      renderStage();
    });
    filterBar.appendChild(btn);
  }
  leftCol.appendChild(filterBar);

  const rec = getRecords();
  const list = filteredItems();
  const grid = document.createElement('div');
  grid.className = 'archives-entity-grid';

  const dossierWrap = document.createElement('aside');
  dossierWrap.className = 'archives-dossier parchment-box';
  dossierWrap.dataset.uiSprite = 'parchment-panel';

  const selected = catalog.items.find((i) => i.id === selectedItemId) ?? list[0] ?? catalog.items[0];
  fillItemDossier(dossierWrap, selected, rec);

  for (const item of list) {
    const picks = rec.itemPicks[item.id] ?? 0;
    const seen = picks > 0;
    const unlockState = checkUnlockCondition(item.unlock, rec);

    const card = document.createElement('button');
    card.type = 'button';
    card.className = `archives-entity-card rarity-border-${item.rarity}`;
    card.dataset.active = item.id === selected.id ? '1' : '0';
    card.dataset.seen = seen ? '1' : '0';
    card.dataset.unlocked = unlockState.unlocked ? '1' : '0';

    const rarityBadge = document.createElement('span');
    rarityBadge.className = `entity-role-badge rarity-text-${item.rarity}`;
    rarityBadge.textContent = item.rarity.toUpperCase();

    const artWrap = document.createElement('div');
    artWrap.className = 'entity-card-art';
    const icon = makeItemIcon(item.id, seen ? item.name : 'Unencountered Relic', 'reliquary-card-icon', 64);
    icon.addEventListener('error', () => {
      icon.remove();
      const fb = document.createElement('span');
      fb.className = 'aug-card-fallback';
      fb.textContent = seen ? item.name.slice(0, 1).toUpperCase() : '?';
      artWrap.appendChild(fb);
    });
    artWrap.appendChild(icon);

    const name = document.createElement('span');
    name.className = 'entity-card-name';
    name.textContent = seen ? item.name : '???';

    const tally = document.createElement('span');
    tally.className = 'entity-card-tally';
    tally.textContent = seen
      ? `Bound: ×${picks}`
      : unlockState.unlocked
        ? 'Unencountered'
        : 'Sealed';

    card.append(rarityBadge, artWrap, name, tally);
    card.addEventListener('click', () => {
      playSfx('click');
      selectedItemId = item.id;
      grid.querySelectorAll<HTMLElement>('.archives-entity-card').forEach((el) => {
        el.dataset.active = '0';
      });
      card.dataset.active = '1';
      fillItemDossier(dossierWrap, item, rec);
    });
    grid.appendChild(card);
  }

  leftCol.appendChild(grid);
  layout.append(leftCol, dossierWrap);
  return layout;
}

function filteredItems(): ItemDef[] {
  if (activeItemRarity === 'all') return catalog.items;
  return catalog.items.filter((i) => i.rarity === activeItemRarity);
}

function fillItemDossier(root: HTMLElement, item: ItemDef, rec: ArchiveRecords): void {
  const picks = rec.itemPicks[item.id] ?? 0;
  const seen = picks > 0;
  const unlockState = checkUnlockCondition(item.unlock, rec);

  const header = document.createElement('p');
  header.className = 'dossier-header';
  header.textContent = seen
    ? `${item.rarity.toUpperCase()} AUGMENTATION`
    : unlockState.unlocked
      ? 'UNENCOUNTERED AUGMENTATION'
      : 'SEALED AUGMENTATION';

  const name = document.createElement('h2');
  name.className = 'hall-name';
  name.textContent = seen ? item.name.toUpperCase() : '???';

  const stageWrap = document.createElement('div');
  stageWrap.className = 'archives-dossier-pedestal';
  stageWrap.dataset.seen = seen ? '1' : '0';
  const icon = makeItemIcon(
    item.id,
    seen ? item.name : 'Unencountered Relic',
    'archives-dossier-item-icon',
    ITEM_CHOICE_PX,
  );
  icon.addEventListener('error', () => icon.remove());
  stageWrap.appendChild(icon);

  const ledgerStrip = document.createElement('div');
  ledgerStrip.className = 'archives-dossier-ledger';
  const statusLabel = seen ? item.stack.toUpperCase() : unlockState.unlocked ? 'UNBOUND' : 'SEALED';
  ledgerStrip.innerHTML = `<span>TIMES BOUND: <strong>×${picks.toLocaleString()}</strong></span><span>STATUS: <strong>${statusLabel}</strong></span>`;

  const hooksBox = document.createElement('div');
  hooksBox.className = 'archives-dossier-hooks';
  if (seen) {
    for (const hook of item.hooks) {
      const line = document.createElement('span');
      const formatted = formatHook(hook);
      line.className = formatted.up ? 'hook-up' : 'hook-down';
      line.textContent = formatted.text.toUpperCase();
      hooksBox.appendChild(line);
    }
  } else {
    const line = document.createElement('span');
    line.className = 'hook-down';
    line.textContent = 'ALCHEMICAL PROPERTIES UNCHARTED (???)';
    hooksBox.appendChild(line);
  }

  const lore = document.createElement('p');
  if (seen) {
    lore.className = 'hall-lore';
    lore.textContent = item.lore;
  } else if (!unlockState.unlocked && item.unlock) {
    lore.className = 'hall-lore is-locked-lore';
    lore.textContent = `Sealed Relic — Requirement: ${item.unlock.label} (${unlockState.progress}).`;
  } else {
    lore.className = 'hall-lore is-locked-lore';
    lore.textContent =
      'Unbound Augmentation — Bind this tablet during Vessel Ascension in the Rifts to inscribe its record.';
  }

  root.replaceChildren(header, name, stageWrap, ledgerStrip, hooksBox, lore);
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

/* ==========================================================================
   TAB 5: LEDGER OF WORKINGS (PERSISTENT STATISTICS & HISTORY)
   ========================================================================== */

function buildLedgerView(): HTMLElement {
  const wrap = document.createElement('div');
  wrap.className = 'archives-scroll-pane';
  const rec = getRecords();

  const headRow = document.createElement('div');
  headRow.className = 'archives-banner-row';
  headRow.appendChild(
    sectionBanner(
      'Ledger of Workings',
      'PERSISTENT TRANSMUTATION RECORDS',
      'Every vessel cast into the Rifts is inscribed here across sessions.',
    ),
  );

  const purgeBtn = document.createElement('button');
  purgeBtn.type = 'button';
  purgeBtn.className = confirmPurge ? 'plaque-btn purge-btn is-confirm' : 'plaque-btn purge-btn';
  purgeBtn.dataset.uiSprite = 'btn-plaque';
  const purgeLabel = document.createElement('span');
  purgeLabel.className = 'plaque-label';
  purgeLabel.textContent = confirmPurge ? 'CONFIRM PURGE?' : 'PURGE LEDGER';
  purgeBtn.appendChild(purgeLabel);
  purgeBtn.addEventListener('click', () => {
    if (!confirmPurge) {
      playSfx('click');
      confirmPurge = true;
      purgeBtn.classList.add('is-confirm');
      purgeLabel.textContent = 'CONFIRM PURGE?';
      return;
    }
    playSfx('error');
    resetRecords();
    confirmPurge = false;
    renderRibbon();
    renderStage();
  });
  headRow.appendChild(purgeBtn);
  wrap.appendChild(headRow);

  // 1. Lifetime Totals & Personal Bests
  const winRate =
    rec.totalRuns > 0 ? `${Math.round((rec.victories / rec.totalRuns) * 100)}%` : '0%';
  const furthestStageName =
    catalog.loop.stages[Math.min(rec.furthestStageIndex, catalog.loop.stages.length - 1)]?.name ??
    'Cinder Yard';

  const totalsSec = document.createElement('section');
  totalsSec.className = 'archives-panel';
  const totalsTitle = document.createElement('h3');
  totalsTitle.className = 'archives-section-title';
  totalsTitle.textContent = 'I. LIFETIME TOTALS & HALL OF RECORDS';
  totalsSec.appendChild(totalsTitle);

  const metricsGrid = document.createElement('div');
  metricsGrid.className = 'ledger-metrics-grid';
  const metrics: [string, string, string][] = [
    ['Total Workings', String(rec.totalRuns), `${rec.victories} Won · ${rec.defeats} Shattered · ${rec.abandons} Abandoned`],
    ['Completion Rate', winRate, `${rec.stagesCleared} Chambers Cleared`],
    ['Time in the Rifts', formatTime(rec.totalPlayTime), `Longest Working: ${formatTime(rec.longestRunTime)}`],
    [
      'Fastest Transmutation',
      rec.fastestVictoryTime !== null ? formatTime(rec.fastestVictoryTime) : '—',
      `Furthest Chamber: ${furthestStageName}`,
    ],
    [
      'Total Dross Slain',
      rec.totalKills.toLocaleString(),
      `${rec.fodderKills.toLocaleString()} Fodder · ${rec.eliteKills.toLocaleString()} Elites · ${rec.bossKills.toLocaleString()} Bosses`,
    ],
    [
      'Most Slain (Single Run)',
      rec.mostKillsInRun.toLocaleString(),
      `Highest Ascension: Lv ${rec.highestLevel}`,
    ],
    [
      'Total Damage Dealt',
      Math.round(rec.totalDamageDealt).toLocaleString(),
      `Peak Run Damage: ${Math.round(rec.mostDamageInRun).toLocaleString()}`,
    ],
    [
      'Total Damage Taken',
      Math.round(rec.totalDamageTaken).toLocaleString(),
      `Vitality Siphoned: +${Math.round(rec.totalHealingDone).toLocaleString()} HP`,
    ],
    [
      'Augmentations Bound',
      rec.totalItemsCollected.toLocaleString(),
      `${rec.totalGemsCollected.toLocaleString()} Mercury Drops Harvested`,
    ],
    [
      'Peak Difficulty',
      `×${rec.highestCoefficient.toFixed(2)}`,
      `${rec.totalLevelsGained.toLocaleString()} Total Ascensions`,
    ],
  ];

  for (const [label, value, hint] of metrics) {
    const card = document.createElement('div');
    card.className = 'ledger-metric-card';
    const k = document.createElement('span');
    k.className = 'ledger-metric-k';
    k.textContent = label;
    const v = document.createElement('strong');
    v.className = 'ledger-metric-v';
    v.textContent = value;
    const sub = document.createElement('span');
    sub.className = 'ledger-metric-sub';
    sub.textContent = hint;
    card.append(k, v, sub);
    metricsGrid.appendChild(card);
  }
  totalsSec.appendChild(metricsGrid);
  wrap.appendChild(totalsSec);

  // 2. Per-Survivor Breakdown
  const vesselSec = document.createElement('section');
  vesselSec.className = 'archives-panel';
  const vesselTitle = document.createElement('h3');
  vesselTitle.className = 'archives-section-title';
  vesselTitle.textContent = 'II. PERFORMANCE BY VESSEL';
  vesselSec.appendChild(vesselTitle);

  const vesselGrid = document.createElement('div');
  vesselGrid.className = 'archives-cards-grid cols-2';
  for (const survivor of catalog.survivors) {
    const sRec = rec.bySurvivor[survivor.id];
    const unlockState = checkUnlockCondition(survivor.unlock, rec);
    const unlocked = unlockState.unlocked;
    const runs = sRec?.runs ?? 0;
    const wins = sRec?.victories ?? 0;
    const sCard = document.createElement('div');
    sCard.className = 'archives-info-card with-art';
    sCard.dataset.seen = unlocked ? '1' : '0';

    const pBox = document.createElement('div');
    pBox.className = 'info-card-art';
    pBox.dataset.seen = unlocked ? '1' : '0';
    mountVesselArt(pBox, survivor.id, 'vessel-art portrait-art', unlocked ? survivor.name : 'Sealed Vessel');

    const copy = document.createElement('div');
    copy.className = 'info-card-copy';
    const kicker = document.createElement('p');
    kicker.className = 'info-card-kicker';
    kicker.textContent = unlocked ? (survivor.title ?? 'Vessel').toUpperCase() : 'SEALED VESSEL';
    const name = document.createElement('h4');
    name.className = 'info-card-title';
    name.textContent = unlocked ? survivor.name : '???';

    const chips = document.createElement('div');
    chips.className = 'archives-stat-chips';
    if (unlocked) {
      chips.append(
        makeStatChip('Workings', String(runs)),
        makeStatChip('Victories', String(wins)),
        makeStatChip('Slain', (sRec?.kills ?? 0).toLocaleString()),
        makeStatChip('Best Time', formatTime(sRec?.bestTime ?? 0)),
        makeStatChip('Fastest Win', sRec?.fastestVictory ? formatTime(sRec.fastestVictory) : '—'),
        makeStatChip('Peak Level', `Lv ${sRec?.highestLevel ?? 1}`),
      );
    } else {
      chips.append(
        makeStatChip('Status', `SEALED (${unlockState.progress})`),
        makeStatChip('Rite', survivor.unlock?.label ?? 'Locked'),
      );
    }
    copy.append(kicker, name, chips);
    sCard.append(pBox, copy);
    vesselGrid.appendChild(sCard);
  }
  vesselSec.appendChild(vesselGrid);
  wrap.appendChild(vesselSec);

  // 3. Recent Workings History
  const histSec = document.createElement('section');
  histSec.className = 'archives-panel';
  const histTitle = document.createElement('h3');
  histTitle.className = 'archives-section-title';
  histTitle.textContent = 'III. CHRONICLE OF RECENT WORKINGS';
  histSec.appendChild(histTitle);

  if (rec.recentRuns.length === 0) {
    const empty = document.createElement('p');
    empty.className = 'archives-empty-note';
    empty.textContent = 'No workings recorded yet. Commence a transmutation to inscribe the ledger.';
    histSec.appendChild(empty);
  } else {
    const list = document.createElement('div');
    list.className = 'ledger-history-list';
    for (const run of rec.recentRuns) {
      const row = document.createElement('div');
      row.className = `ledger-history-row outcome-${run.outcome}`;

      const badge = document.createElement('span');
      badge.className = `outcome-badge badge-${run.outcome}`;
      badge.textContent =
        run.outcome === 'victory'
          ? 'TRANSMUTED'
          : run.outcome === 'defeat'
            ? 'SHATTERED'
            : 'ABANDONED';

      const survivorName =
        catalog.survivors.find((s) => s.id === run.survivorId)?.name ?? run.survivorId;

      const summary = document.createElement('div');
      summary.className = 'history-summary';
      const mainLine = document.createElement('strong');
      mainLine.textContent = `${survivorName} · ${run.stageName}`;
      const subLine = document.createElement('span');
      subLine.textContent = `Duration ${formatTime(run.runTime)} · Lv ${run.level} · ×${run.coefficient.toFixed(2)} · ${run.kills} Slain · ${run.damageDealt.toLocaleString()} Dmg`;
      summary.append(mainLine, subLine);

      const itemsStrip = document.createElement('div');
      itemsStrip.className = 'history-items-strip';
      for (const inst of run.items) {
        try {
          const def = catalog.item(inst.id);
          itemsStrip.appendChild(
            makeItemChip(
              { id: def.id, name: def.name, stacks: inst.stacks, rarity: def.rarity },
              'item-chip history-chip',
              24,
            ),
          );
        } catch {
          /* ignore unknown old item id */
        }
      }

      row.append(badge, summary, itemsStrip);
      list.appendChild(row);
    }
    histSec.appendChild(list);
  }

  wrap.appendChild(histSec);
  return wrap;
}

/* ==========================================================================
   HELPERS
   ========================================================================== */

function sectionBanner(kickerText: string, titleText: string, subText: string): HTMLElement {
  const header = document.createElement('header');
  header.className = 'archives-section-banner';
  const kicker = document.createElement('p');
  kicker.className = 'info-card-kicker';
  kicker.textContent = kickerText.toUpperCase();
  const title = document.createElement('h2');
  title.className = 'archives-banner-title';
  title.textContent = titleText;
  const sub = document.createElement('p');
  sub.className = 'archives-banner-sub';
  sub.textContent = subText;
  header.append(kicker, title, sub);
  return header;
}

function makeStatChip(label: string, value: string): HTMLElement {
  const chip = document.createElement('span');
  chip.className = 'archives-stat-chip';
  const k = document.createElement('span');
  k.className = 'chip-k';
  k.textContent = `${label}:`;
  const v = document.createElement('strong');
  v.className = 'chip-v';
  v.textContent = value;
  chip.append(k, v);
  return chip;
}

function skillFor(survivor: SurvivorDef, slot: SkillSlot): SkillDef | null {
  const id = survivor.skills[slot];
  return id ? catalog.skill(id) : null;
}
