import type { SpriteManifest } from '../view/sprite-types';

let uiSpriteSet: Set<string> | null = null;
let uiLoadPromise: Promise<Set<string>> | null = null;

export function uiSpriteSrc(id: string): string {
  return `sprites/ui/${id}.png`;
}

export async function loadUiSprites(): Promise<Set<string>> {
  if (uiSpriteSet) return uiSpriteSet;
  if (!uiLoadPromise) {
    uiLoadPromise = (async () => {
      try {
        const res = await fetch('sprites/manifest.json');
        if (!res.ok) return new Set<string>();
        const data: unknown = await res.json();
        if (!data || typeof data !== 'object') return new Set<string>();
        const manifest = data as SpriteManifest;
        return new Set<string>(manifest.ui ?? []);
      } catch {
        return new Set<string>();
      }
    })();
  }
  uiSpriteSet = await uiLoadPromise;
  return uiSpriteSet;
}

/**
 * Decorates a DOM element with a drop-in UI sprite if `public/sprites/ui/{id}.png` exists
 * in the manifest. Until that sprite is authored, the element stays in its CSS/SVG fallback state
 * (`data-has-ui-sprite="0"`).
 */
export function bindUiSprite(el: HTMLElement | null, id: string): void {
  if (!el) return;
  el.dataset.uiSprite = id;
  el.dataset.hasUiSprite = '0';
  void loadUiSprites().then((set) => {
    if (!el.isConnected || !set.has(id)) return;
    const src = uiSpriteSrc(id);
    const probe = new Image();
    probe.onload = () => {
      if (!el.isConnected) return;
      el.style.setProperty('--ui-sprite', `url("${src}")`);
      el.dataset.hasUiSprite = '1';
    };
    probe.src = src;
  });
}

/**
 * Binds all elements in the document carrying `[data-ui-sprite]` to their optional
 * `public/sprites/ui/{id}.png` asset.
 */
export function hydrateUiSprites(root: ParentNode = document): void {
  const nodes = root.querySelectorAll<HTMLElement>('[data-ui-sprite]');
  nodes.forEach((node) => {
    const id = node.dataset.uiSprite;
    if (id) bindUiSprite(node, id);
  });
}
