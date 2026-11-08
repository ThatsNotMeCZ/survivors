import type { SpriteManifest, UiAtlasDef, UiNineSliceDef, UiRect, UiSpriteEntry } from '../view/sprite-types';

type LoadedUiAssets = {
  ids: Set<string>;
  atlas: UiAtlasDef | null;
  atlasImage: HTMLImageElement | null;
  atlasUrl: string;
};

let uiAssets: LoadedUiAssets | null = null;
let uiLoadPromise: Promise<LoadedUiAssets> | null = null;
const sliceUrlCache = new Map<string, string>();
const centerSliceUrlCache = new Map<string, string>();

type CenterSliceBinding = {
  entry: UiSpriteEntry;
  atlasImage: HTMLImageElement;
  scale: number;
};

const centerSliceElements = new Map<HTMLElement, CenterSliceBinding>();
let centerSliceObserver: ResizeObserver | null = null;

function getCenterSliceObserver(): ResizeObserver | null {
  if (typeof ResizeObserver === 'undefined') return null;
  if (!centerSliceObserver) {
    centerSliceObserver = new ResizeObserver((entries) => {
      for (const entry of entries) {
        const el = entry.target as HTMLElement;
        const binding = centerSliceElements.get(el);
        if (!binding || !el.isConnected) {
          centerSliceObserver?.unobserve(el);
          centerSliceElements.delete(el);
          continue;
        }
        renderCenterSliceElement(el, binding);
      }
    });
  }
  return centerSliceObserver;
}

function render5BandSliceDataUrl(
  img: HTMLImageElement,
  rect: UiRect,
  ns: UiNineSliceDef,
  dstW: number,
  dstH: number,
): string {
  const key = `${rect.x},${rect.y},${rect.w},${rect.h}:${dstW}x${dstH}`;
  const cached = centerSliceUrlCache.get(key);
  if (cached) return cached;

  const frameW = rect.w;
  const frameH = rect.h;
  const m = ns.margins;
  const c = ns.center ?? {
    x: Math.round(frameW / 2),
    y: Math.round(frameH / 2),
    w: 0,
    h: 0,
  };

  // Fixed source cuts
  const sw0 = m.left;
  const sw1 = Math.max(0, c.x - m.left);
  const sw2 = c.w;
  const sw3 = Math.max(0, frameW - m.right - (c.x + c.w));
  const sw4 = m.right;

  const sh0 = m.top;
  const sh1 = Math.max(0, c.y - m.top);
  const sh2 = c.h;
  const sh3 = Math.max(0, frameH - m.bottom - (c.y + c.h));
  const sh4 = m.bottom;

  // Source offsets (relative to rect.x, rect.y)
  const srcXs = [0, sw0, c.x, c.x + c.w, frameW - m.right];
  const srcWs = [sw0, sw1, sw2, sw3, sw4];
  const srcYs = [0, sh0, c.y, c.y + c.h, frameH - m.bottom];
  const srcHs = [sh0, sh1, sh2, sh3, sh4];

  // Destination widths
  const dw0 = sw0;
  const dw2 = sw2;
  const dw4 = sw4;
  const remW = Math.max(0, dstW - (dw0 + dw2 + dw4));
  const dw1 = Math.floor(remW / 2);
  const dw3 = remW - dw1;

  // Destination heights
  const dh0 = sh0;
  const dh2 = sh2;
  const dh4 = sh4;
  const remH = Math.max(0, dstH - (dh0 + dh2 + dh4));
  const dh1 = Math.floor(remH / 2);
  const dh3 = remH - dh1;

  const dstXs = [0, dw0, dw0 + dw1, dw0 + dw1 + dw2, dw0 + dw1 + dw2 + dw3];
  const dstWs = [dw0, dw1, dw2, dw3, dw4];
  const dstYs = [0, dh0, dh0 + dh1, dh0 + dh1 + dh2, dh0 + dh1 + dh2 + dh3];
  const dstHs = [dh0, dh1, dh2, dh3, dh4];

  const canvas = document.createElement('canvas');
  canvas.width = Math.max(1, dstW);
  canvas.height = Math.max(1, dstH);
  const ctx = canvas.getContext('2d');
  if (ctx) {
    ctx.imageSmoothingEnabled = false;
    for (let yi = 0; yi < 5; yi++) {
      const dy = dstYs[yi];
      const dh = dstHs[yi];
      const sy = rect.y + srcYs[yi];
      const sh = srcHs[yi];
      if (dh <= 0 || sh <= 0) continue;

      for (let xi = 0; xi < 5; xi++) {
        const dx = dstXs[xi];
        const dw = dstWs[xi];
        const sx = rect.x + srcXs[xi];
        const sw = srcWs[xi];
        if (dw <= 0 || sw <= 0) continue;

        ctx.drawImage(img, sx, sy, sw, sh, dx, dy, dw, dh);
      }
    }
  }

  const url = canvas.toDataURL('image/png');
  centerSliceUrlCache.set(key, url);
  return url;
}

function renderCenterSliceElement(el: HTMLElement, binding: CenterSliceBinding): void {
  const rect = el.getBoundingClientRect();
  const measuredW = Math.round(rect.width);
  const measuredH = Math.round(rect.height);

  const prevW = el.dataset.uiSliceW;
  const prevH = el.dataset.uiSliceH;

  if ((measuredW === 0 || measuredH === 0) && prevW && prevH) {
    return;
  }

  const scale = binding.scale > 0 ? binding.scale : 1;
  const dstW = Math.max(binding.entry.idle.w, measuredW > 0 ? Math.round(measuredW / scale) : binding.entry.idle.w);
  const dstH = Math.max(binding.entry.idle.h, measuredH > 0 ? Math.round(measuredH / scale) : binding.entry.idle.h);

  if (prevW === String(dstW) && prevH === String(dstH)) {
    return;
  }

  const ns = binding.entry.nineSlice!;
  const idleUrl = render5BandSliceDataUrl(binding.atlasImage, binding.entry.idle, ns, dstW, dstH);
  const hoverUrl = render5BandSliceDataUrl(binding.atlasImage, binding.entry.hover, ns, dstW, dstH);
  const activeUrl = render5BandSliceDataUrl(binding.atlasImage, binding.entry.active, ns, dstW, dstH);

  el.style.setProperty('--ui-slice-idle', `url("${idleUrl}")`);
  el.style.setProperty('--ui-slice-hover', `url("${hoverUrl}")`);
  el.style.setProperty('--ui-slice-active', `url("${activeUrl}")`);
  el.dataset.uiSliceW = String(dstW);
  el.dataset.uiSliceH = String(dstH);
  el.dataset.hasUiCenterSlice = '1';
  el.dataset.hasUiSlice = '0';
  el.dataset.hasUiStates = '1';
  el.dataset.hasUiSprite = '1';
}

export function uiSpriteSrc(id: string): string {
  return resolveDocUrl(`sprites/ui/${id}.png`);
}

function resolveDocUrl(relPath: string): string {
  if (typeof document !== 'undefined' && document.baseURI) {
    try {
      return new URL(relPath, document.baseURI).href;
    } catch {
      return relPath;
    }
  }
  return relPath;
}

function loadImage(src: string): Promise<HTMLImageElement | null> {
  return new Promise((resolve) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = () => resolve(null);
    img.src = src;
  });
}

async function ensureUiAssets(): Promise<LoadedUiAssets> {
  if (uiAssets) return uiAssets;
  if (!uiLoadPromise) {
    uiLoadPromise = (async (): Promise<LoadedUiAssets> => {
      try {
        const res = await fetch(resolveDocUrl('sprites/manifest.json'), { cache: 'no-cache' });
        if (!res.ok) {
          return { ids: new Set<string>(), atlas: null, atlasImage: null, atlasUrl: '' };
        }
        const data: unknown = await res.json();
        if (!data || typeof data !== 'object') {
          return { ids: new Set<string>(), atlas: null, atlasImage: null, atlasUrl: '' };
        }
        const manifest = data as SpriteManifest;
        const atlas = manifest.uiAtlas ?? null;
        const ids = new Set<string>([
          ...(manifest.ui ?? []),
          ...Object.keys(atlas?.frames ?? {}),
        ]);
        let atlasImage: HTMLImageElement | null = null;
        let atlasUrl = '';
        if (atlas && atlas.src) {
          atlasUrl = resolveDocUrl(atlas.src);
          atlasImage = await loadImage(atlasUrl);
        }
        return { ids, atlas, atlasImage, atlasUrl };
      } catch {
        return { ids: new Set<string>(), atlas: null, atlasImage: null, atlasUrl: '' };
      }
    })();
  }
  uiAssets = await uiLoadPromise;
  return uiAssets;
}

export async function loadUiSprites(): Promise<Set<string>> {
  const assets = await ensureUiAssets();
  return assets.ids;
}

function extractSliceDataUrl(img: HTMLImageElement, rect: UiRect): string {
  const key = `${rect.x},${rect.y},${rect.w},${rect.h}`;
  const cached = sliceUrlCache.get(key);
  if (cached) return cached;
  const canvas = document.createElement('canvas');
  canvas.width = Math.max(1, rect.w);
  canvas.height = Math.max(1, rect.h);
  const ctx = canvas.getContext('2d');
  if (ctx) {
    ctx.imageSmoothingEnabled = false;
    ctx.drawImage(img, rect.x, rect.y, rect.w, rect.h, 0, 0, rect.w, rect.h);
  }
  const url = canvas.toDataURL('image/png');
  sliceUrlCache.set(key, url);
  return url;
}

function formatAtlasSize(atlasW: number, atlasH: number, rect: UiRect): string {
  const sx = (atlasW / Math.max(1, rect.w)) * 100;
  const sy = (atlasH / Math.max(1, rect.h)) * 100;
  return `${sx.toFixed(4)}% ${sy.toFixed(4)}%`;
}

function formatAtlasPos(atlasW: number, atlasH: number, rect: UiRect): string {
  const dx = atlasW - rect.w;
  const dy = atlasH - rect.h;
  const px = dx > 0 ? (rect.x / dx) * 100 : 0;
  const py = dy > 0 ? (rect.y / dy) * 100 : 0;
  return `${px.toFixed(4)}% ${py.toFixed(4)}%`;
}

function applyAtlasEntry(
  el: HTMLElement,
  atlas: UiAtlasDef,
  atlasImage: HTMLImageElement,
  atlasUrl: string,
  entry: UiSpriteEntry,
): void {
  el.style.setProperty('--ui-aspect', `${entry.idle.w} / ${entry.idle.h}`);

  if (entry.nineSlice) {
    const ns = entry.nineSlice;
    const scale = ns.scale ?? 1;

    if (ns.center) {
      const binding: CenterSliceBinding = {
        entry,
        atlasImage,
        scale,
      };
      centerSliceElements.set(el, binding);
      renderCenterSliceElement(el, binding);
      getCenterSliceObserver()?.observe(el);
      return;
    }

    const m = ns.margins;
    const idleUrl = extractSliceDataUrl(atlasImage, entry.idle);
    const hoverUrl = extractSliceDataUrl(atlasImage, entry.hover);
    const activeUrl = extractSliceDataUrl(atlasImage, entry.active);

    el.style.setProperty('--ui-slice-idle', `url("${idleUrl}")`);
    el.style.setProperty('--ui-slice-hover', `url("${hoverUrl}")`);
    el.style.setProperty('--ui-slice-active', `url("${activeUrl}")`);
    el.style.setProperty('--ui-slice-insets', `${m.top} ${m.right} ${m.bottom} ${m.left}`);
    el.style.setProperty(
      '--ui-slice-widths',
      `${Math.round(m.top * scale)}px ${Math.round(m.right * scale)}px ${Math.round(m.bottom * scale)}px ${Math.round(m.left * scale)}px`,
    );
    el.style.setProperty('--ui-slice-repeat', ns.repeat ?? 'stretch');
    el.style.setProperty(
      '--ui-expandable-rect',
      `${ns.expandable.x}px ${ns.expandable.y}px ${ns.expandable.w}px ${ns.expandable.h}px`,
    );

    el.dataset.hasUiSlice = '1';
    el.dataset.hasUiStates = '1';
    el.dataset.hasUiSprite = '1';
    return;
  }

  el.style.setProperty('--ui-sprite', `url("${atlasUrl}")`);
  el.style.setProperty('--ui-bg-size', formatAtlasSize(atlas.width, atlas.height, entry.idle));
  el.style.setProperty('--ui-bg-pos', formatAtlasPos(atlas.width, atlas.height, entry.idle));
  el.style.setProperty('--ui-bg-size-hover', formatAtlasSize(atlas.width, atlas.height, entry.hover));
  el.style.setProperty('--ui-bg-pos-hover', formatAtlasPos(atlas.width, atlas.height, entry.hover));
  el.style.setProperty('--ui-bg-size-active', formatAtlasSize(atlas.width, atlas.height, entry.active));
  el.style.setProperty('--ui-bg-pos-active', formatAtlasPos(atlas.width, atlas.height, entry.active));

  el.dataset.hasUiSlice = '0';
  el.dataset.hasUiStates = '1';
  el.dataset.hasUiSprite = '1';
}

/**
 * Decorates a DOM element with a UI sprite from `public/sprites/ui/atlas.png` (or standalone
 * `public/sprites/ui/{id}.png` fallback). Until that sprite is authored, the element stays
 * in its CSS/SVG fallback state (`data-has-ui-sprite="0"`).
 */
export function bindUiSprite(el: HTMLElement | null, id: string): void {
  if (!el) return;
  el.dataset.uiSprite = id;
  if (!el.dataset.hasUiSprite) {
    el.dataset.hasUiSprite = '0';
  }
  void ensureUiAssets().then((assets) => {
    if (!el.isConnected || !assets.ids.has(id)) return;

    const entry = assets.atlas?.frames[id];
    if (assets.atlas && assets.atlasImage && entry) {
      applyAtlasEntry(el, assets.atlas, assets.atlasImage, assets.atlasUrl, entry);
      return;
    }

    const src = uiSpriteSrc(id);
    void loadImage(src).then((img) => {
      if (!img || !el.isConnected) return;
      el.style.setProperty('--ui-sprite', `url("${src}")`);
      el.style.setProperty('--ui-bg-size', '100% 100%');
      el.style.setProperty('--ui-bg-pos', '0% 0%');
      el.style.setProperty('--ui-aspect', `${img.naturalWidth || 1} / ${img.naturalHeight || 1}`);
      el.dataset.hasUiSlice = '0';
      el.dataset.hasUiStates = '0';
      el.dataset.hasUiSprite = '1';
    });
  });
}

/**
 * Binds all elements in the document carrying `[data-ui-sprite]` to their optional
 * UI atlas frame or `public/sprites/ui/{id}.png` asset.
 */
export function hydrateUiSprites(root: ParentNode = document): void {
  const nodes = root.querySelectorAll<HTMLElement>('[data-ui-sprite]');
  nodes.forEach((node) => {
    const id = node.dataset.uiSprite;
    if (id) bindUiSprite(node, id);
  });
}
