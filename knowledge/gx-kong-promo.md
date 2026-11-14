# GX.games and Kongregate promo packs

Listing copy and images for the Phaser web demo live in `promo/gx-games/` and `promo/kongregate/`. Paste from those READMEs. This file only records where the packs live and how to recapture them.

itch.io stays the live demo host ([itch-io-release-plan.md](itch-io-release-plan.md)). These packs do not replace that ship path. They do not include zip builds.

## Packs

| Portal | Folder | Cover | Gallery |
|---|---|---|---|
| GX.games | [../promo/gx-games/](../promo/gx-games/) | `cover.png` 1920×1080, 16:9 | 4 gameplay PNGs, 1920×1080 |
| Kongregate | [../promo/kongregate/](../promo/kongregate/) | `icon.png` 1000×800, 5:4 | 5 PNGs, 1920×1080, including Hall |

Voice, title (`Hermetic Rifts (Demo)`), and `???` redaction match the itch listing. Do not name other games. Do not name the second Vessel.

Kongregate copy must not include outbound links. Confirm the AI disclosure in `promo/kongregate/README.md` before paste.

## Recapture

```bash
cd web
bunx playwright install chromium   # once
bun run capture:gx
bun run capture:kong
```

Local poses: `/?promo=cover&pack=gx` and `/?promo=cover&pack=kong`. Gameplay shots reuse `/?promo=circle|boss|tablets|archives`. Hall for Kongregate is `/?promo=hall`.

Do not ship `?promo=` as the play URL. Covers are composed stills in `web/src/promo/cover-compose.ts`, not gameplay crops.
