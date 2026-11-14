export const PROMO_SHOTS = [
  'circle',
  'boss',
  'tablets',
  'hall',
  'archives',
  'cover',
  'banner',
] as const;

export type PromoShot = (typeof PROMO_SHOTS)[number];

export const COVER_PACKS = ['itch', 'gx', 'kong'] as const;

export type CoverPack = (typeof COVER_PACKS)[number];

export const COVER_SIZE: Record<CoverPack, { w: number; h: number }> = {
  itch: { w: 630, h: 500 },
  gx: { w: 1920, h: 1080 },
  kong: { w: 1000, h: 800 },
};

const PLAY_SHOTS: ReadonlySet<PromoShot> = new Set(['circle', 'boss', 'tablets']);

export function getPromoShot(): PromoShot | null {
  if (typeof window === 'undefined') return null;
  const raw = new URLSearchParams(window.location.search).get('promo');
  if (!raw) return null;
  return (PROMO_SHOTS as readonly string[]).includes(raw) ? (raw as PromoShot) : null;
}

export function getCoverPack(): CoverPack {
  if (typeof window === 'undefined') return 'itch';
  const raw = new URLSearchParams(window.location.search).get('pack');
  if (raw && (COVER_PACKS as readonly string[]).includes(raw)) return raw as CoverPack;
  return 'itch';
}

export function isPromoShot(): boolean {
  return getPromoShot() !== null;
}

export function isPromoPlayShot(): boolean {
  const shot = getPromoShot();
  return shot !== null && PLAY_SHOTS.has(shot);
}

export function applyPromoAttr(): void {
  if (typeof document === 'undefined') return;
  const shot = getPromoShot();
  if (!shot) {
    delete document.documentElement.dataset.promo;
    delete document.documentElement.dataset.coverPack;
    return;
  }
  document.documentElement.dataset.promo = shot;
  if (shot === 'cover') {
    document.documentElement.dataset.coverPack = getCoverPack();
  } else {
    delete document.documentElement.dataset.coverPack;
  }
}

export function markPromoReady(): void {
  if (typeof document === 'undefined') return;
  document.documentElement.dataset.promoReady = '1';
}
