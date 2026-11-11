import { markPromoReady } from './shot';

const STAGE_W = 630;

const ENV = '/sprites/env/atlas.png';
const ENV_W = 572;
const ENV_H = 1603;
const PENITENT = '/sprites/entities/penitent.png';
const HEART = '/sprites/entities/cinder-heart.png';
const MITE = '/sprites/entities/ember-mite.png';
const BOLT = '/sprites/fx/bolt.png';
const DASH = '/sprites/fx/dash.png';
const SHEETS = [ENV, PENITENT, HEART, MITE, BOLT, DASH];

const TILES: Record<string, { x: number; y: number }> = {
  t0: { x: 5, y: 5 },
  t1: { x: 75, y: 5 },
  t2: { x: 145, y: 5 },
  r0: { x: 5, y: 75 },
  r1: { x: 75, y: 75 },
  r2: { x: 145, y: 75 },
  r3: { x: 215, y: 75 },
};

const FLOOR: string[][] = [
  ['t0', 't1', 't2', 't0', 'r1', 't2'],
  ['t1', 'r0', 't0', 't2', 't1', 't0'],
  ['t2', 't0', 'r2', 't1', 't0', 't2'],
  ['t0', 't2', 't1', 'r3', 't2', 't0'],
  ['t1', 't0', 't2', 't0', 'r0', 't1'],
];

type Spr = {
  src: string;
  sheetW: number;
  sheetH: number;
  x: number;
  y: number;
  w: number;
  h: number;
  scale: number;
  left: number;
  top: number;
  z: number;
  rotate?: number;
  opacity?: number;
  flip?: boolean;
  className?: string;
};

export function mountCoverCompose(): void {
  if (document.getElementById('cover-compose')) return;
  document.body.appendChild(buildCover());
  void readyCover();
}

function buildCover(): HTMLElement {
  const root = el('div', 'cover-compose');
  const stage = el('div', 'cover-stage');
  stage.id = 'cover-stage';
  stage.setAttribute('aria-hidden', 'true');

  paintFloor(stage);

  stage.appendChild(
    spr({
      src: ENV,
      sheetW: ENV_W,
      sheetH: ENV_H,
      x: 5,
      y: 370,
      w: 128,
      h: 128,
      scale: 2,
      left: 470,
      top: 340,
      z: 1,
    }),
  );

  stage.appendChild(
    spr({
      src: ENV,
      sheetW: ENV_W,
      sheetH: ENV_H,
      x: 5,
      y: 720,
      w: 320,
      h: 315,
      scale: 2,
      left: -5,
      top: 36,
      z: 2,
    }),
  );

  stage.appendChild(el('div', 'cover-glow'));

  for (const spec of actors()) stage.appendChild(spr(spec));

  stage.appendChild(el('div', 'cover-vignette'));
  stage.appendChild(titleBlock());
  root.appendChild(stage);
  return root;
}

function paintFloor(stage: HTMLElement): void {
  const scale = 2;
  const cell = 64 * scale;
  for (let row = 0; row < FLOOR.length; row += 1) {
    const line = FLOOR[row];
    if (!line) continue;
    for (let col = 0; col < line.length; col += 1) {
      const key = line[col];
      if (!key) continue;
      const tile = TILES[key];
      if (!tile) continue;
      stage.appendChild(
        spr({
          src: ENV,
          sheetW: ENV_W,
          sheetH: ENV_H,
          x: tile.x,
          y: tile.y,
          w: 64,
          h: 64,
          scale,
          left: -32 + col * cell,
          top: -24 + row * cell,
          z: 0,
        }),
      );
    }
  }
}

function actors(): Spr[] {
  return [
    sprMite(4, 188, 318, 5),
    sprMite(1, 348, 392, 5),
    sprMite(2, 92, 286, 5),
    sprMite(0, 412, 268, 5),
    {
      src: HEART,
      sheetW: 516,
      sheetH: 86,
      x: 430,
      y: 0,
      w: 86,
      h: 86,
      scale: 5,
      left: 272,
      top: 98,
      z: 6,
    },
    {
      src: PENITENT,
      sheetW: 240,
      sheetH: 48,
      x: 192,
      y: 0,
      w: 48,
      h: 48,
      scale: 8,
      left: -52,
      top: 168,
      z: 7,
      opacity: 0.22,
      className: 'cover-afterimage',
    },
    {
      src: PENITENT,
      sheetW: 240,
      sheetH: 48,
      x: 192,
      y: 0,
      w: 48,
      h: 48,
      scale: 8,
      left: 10,
      top: 136,
      z: 8,
    },
    {
      src: DASH,
      sheetW: 32,
      sheetH: 29,
      x: 0,
      y: 0,
      w: 32,
      h: 29,
      scale: 4,
      left: 78,
      top: 378,
      z: 9,
      rotate: 28,
      opacity: 0.9,
    },
    {
      src: BOLT,
      sheetW: 32,
      sheetH: 29,
      x: 0,
      y: 0,
      w: 32,
      h: 29,
      scale: 4,
      left: 196,
      top: 214,
      z: 9,
      rotate: -32,
    },
    {
      src: BOLT,
      sheetW: 32,
      sheetH: 29,
      x: 0,
      y: 0,
      w: 32,
      h: 29,
      scale: 4,
      left: 238,
      top: 168,
      z: 9,
      rotate: -40,
    },
    {
      src: BOLT,
      sheetW: 32,
      sheetH: 29,
      x: 0,
      y: 0,
      w: 32,
      h: 29,
      scale: 4,
      left: 274,
      top: 206,
      z: 9,
      rotate: -22,
    },
    sprEmber(96, 92, 4),
    sprEmber(520, 140, 4),
    sprEmber(430, 60, 5),
    sprEmber(300, 430, 4),
    sprEmber(40, 360, 3),
  ];
}

function sprMite(frame: number, left: number, top: number, z: number): Spr {
  return {
    src: MITE,
    sheetW: 144,
    sheetH: 24,
    x: frame * 24,
    y: 0,
    w: 24,
    h: 24,
    scale: 3,
    left,
    top,
    z,
  };
}

function sprEmber(left: number, top: number, scale: number): Spr {
  return {
    src: ENV,
    sheetW: ENV_W,
    sheetH: ENV_H,
    x: 15,
    y: 1600,
    w: 8,
    h: 8,
    scale,
    left,
    top,
    z: 10,
    opacity: 0.85,
  };
}

function titleBlock(): HTMLElement {
  const wrap = el('div', 'cover-title');
  wrap.style.width = px(STAGE_W);
  const brand = el('div', 'cover-brand');
  brand.appendChild(el('span', '', 'HERMETIC'));
  brand.appendChild(el('span', '', 'RIFTS'));
  wrap.appendChild(brand);
  return wrap;
}

function spr(spec: Spr): HTMLDivElement {
  const node = el('div', `cover-spr${spec.className ? ` ${spec.className}` : ''}`);
  const sc = spec.scale;
  node.style.width = px(spec.w * sc);
  node.style.height = px(spec.h * sc);
  node.style.left = px(spec.left);
  node.style.top = px(spec.top);
  node.style.zIndex = String(spec.z);
  node.style.backgroundImage = `url("${spec.src}")`;
  node.style.backgroundSize = `${px(spec.sheetW * sc)} ${px(spec.sheetH * sc)}`;
  node.style.backgroundPosition = `-${px(spec.x * sc)} -${px(spec.y * sc)}`;
  const transforms: string[] = [];
  if (spec.rotate) transforms.push(`rotate(${spec.rotate}deg)`);
  if (spec.flip) transforms.push('scaleX(-1)');
  if (transforms.length > 0) node.style.transform = transforms.join(' ');
  if (spec.opacity != null) node.style.opacity = String(spec.opacity);
  return node;
}

function el(tag: string, className: string, text?: string): HTMLDivElement {
  const node = document.createElement(tag) as HTMLDivElement;
  if (className) node.className = className;
  if (text) node.textContent = text;
  return node;
}

function px(n: number): string {
  return `${n}px`;
}

async function readyCover(): Promise<void> {
  try {
    await document.fonts.load('700 48px BillJilly');
    await document.fonts.ready;
    await Promise.all(SHEETS.map(decodeSheet));
  } catch {
    /* capture still needs a ready flag */
  }
  requestAnimationFrame(() => {
    requestAnimationFrame(() => markPromoReady());
  });
}

function decodeSheet(src: string): Promise<void> {
  const img = new Image();
  img.src = src;
  return img.decode();
}
