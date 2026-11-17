# survivors - chování a systémy (LIVE)

Snapshot: **2026-11-17**.  
Operativní popis toho, co Godot sim skutečně dělá. Čísla, která zde chybí, žijí v `02-catalog-numbers.md`.

---

## 1. Tick a fáze běhu

Sim je headless: `tick(state, InputFrame[], dt)`. Žádný `Input.*` uvnitř simu. Seedovaný `SimRng`. View jen kreslí stav.

Fáze `phase`:

| Fáze | Sim tická? | Poznámka |
|---|---|---|
| `play` | ano | HUD viditelný |
| `levelup` | ne | 3 tablety, klávesy 1-3 |
| `victory` | ne | Transmutation Complete recap |
| `defeat` | ne | Vessel Shattered recap |

Pauza (Esc/P) zastaví overlay tick. Nested pauza (settings, archives, abandon confirm) drží sim zastavenou. Level-up a recap polykají Esc.

Pořadí ticku (zjednodušeně): skills → pohyb hráče → projectiles → director → enemies → separation → obstacles → zones → boss hazardy → gems/lore → loop (koeficient, kruh, portál, smrt).

---

## 2. Koeficient, HP nepřátel, rychlost

`coefficient = 1 + runTime * 0.0026` (`stageBonus` 0, nezávisí na indexu komory).

Při spawnu nepřítele:

- HP = `maxHp * coefficient * (hpMul 2.4 pokud elita)`
- contact DPS = `dps * coefficient * (damageMul 1.5 pokud elita)`
- speed = `base * (1 + 0.035 * (coefficient − 1))`
- XP = `rewards.xp * (xpMul 2.5 pokud elita)`
- credits refund = `rewards.credits * (creditsMul 2.5 pokud elita)`
- radius elity × 1.25

Boss útoky a hazard DPS se násobí coefficient. Volatile HP a enemy exploze taky.

---

## 3. Director algoritmus

Každý tick, pokud **není** `boss_spawned` ani `boss_defeated`:

1. `credits += 3.0 * coefficient * dt`
2. Zkus fodder pack (interval 1.6 s). S `rangedChance` stage vybere spitter místo mite.
3. Zkus snipera (interval 9 s, max 3 živí, cost 18).
4. Po `firstEliteAt` zkus wardena (interval 14 s).

Každý pokus o skupinu:

- Elite cap = **1** dokud je kruh `hidden`, jinak **6**.
- Elite cost = `baseCost * 3.0`.
- Roll elity: `chance = clamp(0.02 + (coeff−1)*0.12, 0, 0.40)`.
- Elita: pack 1, odečti elite cost.
- Jinak fodder: pack 3-6, cap 24 živých, odečti `fodderCost` 6 za kus.
- Spawn v prstenci 460-900 px od hráče, spread 56 px.

Boss spawn Director ihned umlčí. Summon útoky bosse Director nepoužívají.

---

## 4. AI nepřátel

### Chase

Běží na hráče (fodder na Ash Step decoy, pokud žije). Drží se na `radius_self + radius_target + 6`. Contact DPS platí v `radii + 10`. Útok 0.35 s, CD 0.8 s. Melee overlap posouvá jen melee tělo, hráče ne. Fodder se odklání od pilířů (`deflect`). Root (tether) zastaví pohyb.

`fodderContactCap` 4: nanejvýš 4 fodder contact DPS se sčítají.

### Ranged (spitter)

Drží vzdálenost mezi `keep` a `range`. Windup telegraph (linie zamčená na pozici hráče v okamžiku startu), pak enemy projectile. Ember: range 280 / keep 200 / cd 2.1 / windup 0.4. Frost: 300 / 210 / 1.9 / 0.38. Střely umírají na pilíři.

### Sniper (Astral Watcher)

Drží `keep` 480. CD 3.2 s, windup 1.5 s, hitscan dmg 28 × coefficient, lineWidth 10. Pilíř přeruší paprsek. I-frame nebo uhnutí z linie neguje zásah. Low HP (8), vysoký kredit.

### Boss

Drží katalogové `keep` (230 / 260 / 280). Enrage při 50 % HP zkrátí cooldowny (`cooldownMul` 0.75 / 0.75 / 0.72). Koliduje s pilíři. Typy útoků:

| Typ | Chování |
|---|---|
| `bolt` | Jedna střela na hráče |
| `fan` | Vějíř N střel se `spread` |
| `meteor` | Telegraph, dopad, volitelná louže |
| `cone` | Výseč, lingering, slow |
| `prison` | Delay, kruh, root |
| `pulse` | Celoarénový kruh (r=620 u Emperor) |
| `laser` | Tracking beam `trackSpeed`, trail louže; `_clamp_beam` na pilíř |
| `summon` | `count` entit, `maxAlive` strop |

Boss hazard louže (meteor pool, laser trail, pulse) dávají DPS × coefficient a mohou slow. Sloup blokuje line-of-sight i u některých pool zásahů.

---

## 5. Skill effect typy

Nový skill musí použít jeden z těchto typů, nebo specifikovat nový sim case.

| Typ | Chování |
|---|---|
| `projectile` | Mířený bolt. `pierce` projde všechny. `flyOver` ignoruje těla a detonuje u kurzoru (`impactRadius`). |
| `dash` | Burst 210 px, duration 0.16 s, iframe 0.22 s. Směr = move, jinak aim. `decoyDuration` = Ash Step figurína (jen fodder). |
| `self-slow` | Násobek rychlosti hráče na dobu (Piercing Aether). |
| `delayed-strike` | Telegraph, pak AoE na kurzoru (Crucible Cull). |
| `slow-line` | Šev; `fodderOnly` = elity a bossové ignorují. |
| `tether` | Na dráze spaluje fodder (`fodderDamage`). První elita/boss: root + `fodderContactDps` na fodder, který se kotvy dotýká. Miss žere CD. |

Cooldown se násobí `cooldown_mul` ze stats. Hold primary pálí, dokud je LMB dole a CD hotové.

---

## 6. Stacking, armor, crit

`stack: linear` (všechny LIVE itemy): každý stack přičte hook znovu. `stack: none` by karty z draftu vyřadil, jakmile je hráč má.

Resolve `(base + add) * (1 + pct)` u speed, maxHp, radius.  
`damage_mul = (1 + add.damage) * (1 + pct.damage)`  
`cooldown_mul` stejně.  
Crit chance = clamp(0.05 + add + pct, 0, 1).  
Crit mul = max(1, 2.0 + add + pct).  
Armor = clamp(add.armor + pct.armor, −1, 0.75). Incoming: `raw * (1 − armor)`.  
Hazard: ještě `* (1 − hazardResist)`, resist clamp 0-0.85.  
Radius clamp 50 %-200 % base.  
`eliteDamage` násobí poškození do elit a bossů.

**Crit:** každý player hit rolluje `randf() < crit_chance`. Zásah × `crit_mul`. On-crit (Astrologer's Ocular) odečte 0.25 s × stacks ze **všech** slotů, které zrovna chladnou.

**On-kill:** Cinnabar Leech +0.3 HP × stacks, clamp na max HP.

**One-shot ochrana:** pokud HP ≥ 90 % max a zásah by srazil pod 1, zbude 1 HP a 0.25 s i-framů.

---

## 7. Kruh, rift, Ouroboros

Teleporter souřadnice se rezervují při `begin_stage` ze seedu (`run_seed XOR stage id XOR stage_index XOR stage_gen`). Dist 480-800 px od hráče, min 360.

Stavy kruhu: `hidden` → po `teleporterAt` `charging` → po `teleporterHold` uvnitř radiusu `done` + spawn bosse. Charge **jen** když je hráč uvnitř. Venku se nenabíjí a **neklesá**.

Po smrti bosse: `portal_open` na pozici kruhu (nebo mrtvoly, pokud je zapsaná). Hold 1.4 s v r=70. Venku se portal hold resetuje na 0.

- Ne-poslední komora: `begin_stage(index+1)`, HP na max, wipe světa, nové překážky.
- Poslední komora + hold: `cycle_index++`, `begin_stage(0)`, inventář/XP/`runTime` zůstávají. HUD: *Descend the Ouroboros* / *Stand in the gate for Cycle {n} · Press F to seal the working*.
- `can_seal`: portál otevřený, poslední komora, ještě ne `won`. F nebo pauza Seal the Working volá `complete_working` (victory, auto-collect lore).

Cycle numeral: 0 → I, 1 → II, … (římské).

---

## 8. Level-up nabídka

Pool = itemy v `unlocked_items` (splněný unlock na startu runu). Váha rarity z `rarityWeight`. Offer RNG je seedovaný (`run_seed XOR 0x51ED`), proto Daily Rite opakuje pořadí karet. Director a combat RNG (`combat_rng.randomize()`) seed z Daily Rite neberou.

3 unikátní karty. Prázdný unlocked pool → fallback na všechny itemy. Pick pauzuje sim. Další pending level ihned rolne novou trojici.

---

## 9. Překážky a těla

Circle vs circle push-out. Hráč, fodder, elity, **bossové** se z pilířů vytlačují. Hazard bez projectile kolize. Dash (`dash_remain` nebo `iframe_remain`) hazard ignoruje.

Volatile: damage jen hráčské skilly (Bolt/Pierce hit, Censer AoE, Cull, Brimstone, Tether). Enemy je nepoškodí. Prime 0.4 s, pak AoE. Rime Dock přidá slow 2 s ×0.7.

Noxious smrt: corpse 0.5 s → pop 8×coeff v r=40 → dynamický hazard na 6 s (pool max 8).

---

## 10. Persist a settings

**Ledger** `user://records.v1.json`: viz `04-lore-archives-and-unlocks.md` §4. Merge na konci runu (victory / defeat / abandon). Chamber unlock podle **návštěvy**. Purge maže vše.

**Settings** `user://settings.v1.json`:

| Klíč | Default |
|---|---|
| masterVolume | 0.7 |
| sfxVolume | 0.8 |
| musicVolume | 0.6 |
| muted | false |
| screenshake | true |
| reduceVfx | false |
| survivorId | `runner` |
| dailyRite | false |
| windowMode | `windowed` (`borderless` / `exclusive`) |
| screenIndex | 0 |
| resolutionW / H | 1920 × 1080 |
| vsync | `on` (`off` / `adaptive`) |
| maxFps | 0 (unlimited) |

Změna display mode / monitor / resolution: 15 s Keep / Revert.

Daily Rite seed: `hash('daily:' + UTC YYYY-MM-DD)`. Recap tiskne `#` + 4 hex znaky.

---

## 11. Audio (hráčsky)

Tři hudební vrstvy: menu bed, map bed podle `stage.id`, boss bed podle boss id. Pauza nechá map bed (ducked) a přidá chill overlay. Level-up stejný overlay. SFX: zásahy, dash, elita/boss, gems, UI tablety, recap stings. Mute tichí všechny bus.

---

## 12. Co v Godot LIVE není

- Online co-op (jen host stub).
- Steam Workshop loader (pack s `.gd` / native se odmítne).
- Locale mimo `en.csv`.
- UI rebindů (InputMap akce existují).
- Godot HTML5 export.
