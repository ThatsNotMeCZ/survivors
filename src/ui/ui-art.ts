import type { SpriteManifest, UiAtlasDef, UiRect, UiSpriteEntry } from '../view/sprite-types';

type LoadedUiAssets = {
  ids: Set<string>;
  atlas: UiAtlasDef | null;
  atlasImage: HTMLImageElement | null;
  atlasUrl: string;
};

let uiAssets: LoadedUiAssets | null = null;
let uiLoadPromise: Promise<LoadedUiAssets> | null = null;
const sliceUrlCache = new Map<string, string>();

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
