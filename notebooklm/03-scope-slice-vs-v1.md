# survivors — LIVE vs TARGET vs ZAKÁZÁNO

Snapshot: **2026-10-20**.  
Když navrhuješ feature, nejdřív ji zařaď sem. Neoznačený návrh ber jako podezřelý.

## LIVE (playable teď)

Playtest slice, hodiny zkrácené.

- Combat verb **A**: mouse-aimed primary, hold LMB
- Homunculus (`runner`): Ignis Bolt + Phase Step
- 2 stage: Cinder Yard → Rime Dock, pak victory
- Director + difficulty coefficient
- 12 itemů s tradeoffem, včetně lunar Pale Moon Covenant
- Level-up 1 of 3, sim pause
- Transmutation Circle hold, pak stage boss, pak Rift (jen po stage 1)
- Ranged spitters ~22 %
- Arena obstacles: 14 pillars, 8 hazards, 9 volatiles
- Contact DPS (fodder cap 4), dash i-frames
- HTML hall / pause / HUD / recap / settings
- Dark Hermetic display copy
- GPU fodder, gems, sparks; sprite player/elite/boss/obstacles
- Soft slice cap: 32 fodder + 3 elite + 1 boss

## TARGET v1 (schváleno, není v kódu)

- 2 survivors, každý 4 skilly (primary, secondary, dash, ultimate)
- Secondary (RMB) a ultimate bound a **mířené**
- 4 enemy archetypes
- 3 elite modifiers: burn / chain lightning / poison slow (recolor + glyph)
- 3 stage + finale, produkční hodiny (~6 min/stage, circle ~min 4, hold ~60 s)
- Standing-still tresty navíc: telegraph elite hits, sniper archetype, corpse explosions
- Late game: méně těl, scarier elite
- 12 itemů s hookem už **je LIVE**; další item jen s novým hookem, ne jako doplnění kvóty

## ZAKÁZÁNO (ani jako experiment v návrhu)

- Auto-aim / auto-fire primary
- Orbital garlic, screen-delete evolutions, full-auto do všech směrů
- AFK win (stát venku kruhu, schovat se za pilíř, nechat orbital hrát)
- Čistý `+damage` / `+HP` / `+speed` bez ceny
- Co-op (v1)
- 100+ itemů
- Roster 20 survivorů
- Meta unlock tree / lobby shop
- Infinite empty lawn bez objectives
- Volatile, který bouchá sám od sebe nebo z contactu (musí to být aimed Bolt + telegraph)

## Časté záměny (nepleť Gemini)

| Není LIVE | Co je LIVE místo toho |
|---|---|
| 8 itemů | 12 itemů |
| Žádný lunar item | Pale Moon Covenant |
| Runner / Bolt / Dash jako hráčské názvy | Homunculus / Ignis Bolt / Phase Step |
| Prázdná aréna | 31 překážek |
| Telegraph elite hits, snipers, corpse explosions | jen v TARGET |
| 3 stage + finale | 2 stage slice |
| Hold 60 s | Hold 20 / 22 s |
| Elite modifiers burn/chain/poison | elite = větší chaseři |
| Secondary / ultimate | unbound |
| Spitter bolt 6 / 7 | bolt damage **5** |
| Elite stage 1 „Ember“ | **Ember Warden** (`ember-chaser`) |

## Produkční vs slice hodiny

| Beat | Slice Cinder / Rime | Produkce (v1) |
|---|---|---|
| Délka stage | ~1–2 min playtest | ~6 min |
| Circle on | 55 s / 50 s | ~minuta 4 |
| Hold | 20 s / 22 s | ~60 s |
| Stage count | 2 + last boss | 3 + finale |

Retune hodin = JSON v `loop.json`, ne nový systém.
