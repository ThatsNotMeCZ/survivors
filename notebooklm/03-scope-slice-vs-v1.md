# survivors — LIVE vs TARGET vs ZAKÁZÁNO

Snapshot: **2026-10-21**.  
Když navrhuješ feature, nejdřív ji zařaď sem. Neoznačený návrh ber jako podezřelý.

## LIVE (playable teď)

Playtest slice, hodiny zkrácené.

- Combat verb **A**: mouse-aimed primary, hold LMB
- **2 survivors**, každý 4 bound skilly
- Homunculus: Ignis Bolt / Piercing Aether / Phase Step / Crucible Cull
- The Penitent: Censer Lob / Brimstone Line / Ash Step / Condemnation Tether
- RMB secondary + Q ultimate, oba aimed press
- 2 stage: Cinder Yard → Rime Dock, pak victory
- Director + difficulty coefficient
- 13 itemů s tradeoffem, včetně lunar Pale Moon Covenant a on-kill Cinnabar Leech
- Level-up 1 of 3, sim pause
- Transmutation Circle hold, pak stage boss, pak Rift (jen po stage 1)
- Ranged spitters ~22 %
- Astral Watcher sniper (max 2)
- Noxious na každé elitě (contact slow, corpse pop, permanent acid)
- Arena obstacles: 14 pillars, 8 hazards, 9 volatiles + až 8 acid pools
- Contact DPS (fodder cap 4), dash i-frames
- HTML hall s výběrem vesselu / pause / HUD 4 sloty / recap / settings
- Dark Hermetic display copy (hall title Hermetic Rifts)
- GPU fodder, gems, sparks; sprite player/elite/boss/obstacles
- Web Audio bus (menu / map / pause overlay)
- Soft slice cap: 32 fodder + 3 elite + 1 boss

## TARGET v1 (schváleno, není v kódu)

- 2 survivors × 4 skilly — **už LIVE**
- 13 itemů s hookem — **už LIVE**; další item jen s novým hookem
- 4. enemy archetype (chase / ranged / sniper už LIVE)
- Elite modifiers burn (červená) a chain lightning (modrá)
- Noxious jako **roll mezi 3 modifiers**, ne default na každé elitě
- 3 stage + finale, produkční hodiny (~6 min/stage, circle ~min 4, hold ~60 s)
- Late game: méně těl, scarier elite

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
| 1 survivor, secondary/ultimate unbound | 2 survivors, 4 skilly bound |
| Ignis Bolt CD 0.16 s | **0.28 s** |
| Effecty jen `projectile` / `dash` | + `self-slow` / `delayed-strike` / `slow-line` / `tether` |
| Sniper / corpse explosions = TARGET | Astral Watcher + Noxious corpse acid = **LIVE** |
| Elite modifiers burn/chain/poison | jen **Noxious**, na každé elitě |
| 8 itemů | 13 itemů |
| Žádný lunar item | Pale Moon Covenant |
| Runner / Bolt / Dash jako hráčské názvy | Homunculus / Ignis Bolt / Phase Step |
| Prázdná aréna | 31 překážek + acid pools |
| 3 stage + finale | 2 stage slice |
| Hold 60 s | Hold 20 / 22 s |
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
