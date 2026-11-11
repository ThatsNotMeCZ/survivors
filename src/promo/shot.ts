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

const PLAY_SHOTS: ReadonlySet<PromoShot> = new Set(['circle', 'boss', 'tablets', 'cover']);

export function getPromoShot(): PromoShot | null {
  if (typeof window === 'undefined') return null;
  const raw = new URLSearchParams(window.location.search).get('promo');
  if (!raw) return null;
  return (PROMO_SHOTS as readonly string[]).includes(raw) ? (raw as PromoShot) : null;
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
    return;
  }
  document.documentElement.dataset.promo = shot;
}

export function markPromoReady(): void {
  if (typeof document === 'undefined') return;
  document.documentElement.dataset.promoReady = '1';
}
