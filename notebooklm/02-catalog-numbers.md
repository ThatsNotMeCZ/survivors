# survivors - katalog čísel (LIVE JSON)

Snapshot: **2026-11-17**.  
Zdroj pravdy: `Godot/hermetic-rifts/data/catalog/*.json`. Když tento soubor nesedí s JSON, věř JSON.

Tyto hodnoty jsou **LIVE**. Neměň je v návrhu, aniž bys označil, že jde o retune.

---

## World (`world.json`)

| Klíč | Hodnota |
|---|---|
| Arena width × height | 2560 × 2560 px |
| Border insets (X / Y) | 21 px / 34 px |
| Camera `viewZoom` | 2.5 |
| Default survivor | `runner` (Homunculus) |
| Default enemy | `ember-chaser` (Ember Warden) |
| Max projectiles pool | 128 |

---

## Survivors (`survivors.json`)

### Homunculus (`runner`) - Skirmisher

- **Titul:** The Runner
- **Lore:** *Clay and quicksilver, stolen from a failed Great Work. You kite the dross until the seal holds.*
- **Crosshair:** `runner`
- **Unlock:** Výchozí (odemčen od začátku)
- **Starting items:** žádné

| Stat | Base hodnota |
|---|---|
| Speed | 280 |
| Max HP | 100 |
| Hurtbox radius | 14 px |
| Primary | `bolt` (Ignis Bolt) |
| Secondary | `skill-aether-pierce` (Piercing Aether) |
| Utility | `dash` (Phase Step) |
| Special | `skill-crucible-cull` (Crucible Cull) |

### The Penitent (`penitent`) - Caster / Controller

- **Titul:** The Caster
- **Lore:** *A monk who walked into the kiln and did not burn. He draws circles the horde must not cross.*
- **Crosshair:** `penitent`
- **Unlock:** `boss-kill` `frost-sovereign`, `stageId` `rime-dock` - *Slay the Frost Sovereign in the Rime Dock*
- **Starting items:** žádné

| Stat | Base hodnota |
|---|---|
| Speed | 245 |
| Max HP | 135 |
| Hurtbox radius | 14 px |
| Primary | `skill-censer-lob` (Censer Lob) |
| Secondary | `skill-brimstone-line` (Brimstone Line) |
| Utility | `dash-ash-step` (Ash Step) |
| Special | `skill-condemn-tether` (Condemnation Tether) |

---

## Skills (`skills.json`)

Implementované effect typy: `projectile`, `dash`, `self-slow`, `delayed-strike`, `slow-line`, `tether`.

| id | Display | Slot | Input | CD | Effect (klíčová čísla) |
|---|---|---|---|---|---|
| `bolt` | Ignis Bolt | primary | hold | 0.28 | projectile speed 780, life 0.85, r=5, dmg 10 |
| `skill-aether-pierce` | Piercing Aether | secondary | press | 4.0 | pierce projectile speed 1400, life 0.45, r=6, dmg 22 + self-slow ×0.5 na 0.25 s |
| `dash` | Phase Step | utility | press | 2.9 | dash 210 px, 0.16 s, iframe 0.22 s |
| `skill-crucible-cull` | Crucible Cull | special | press | 12.0 | delayed-strike delay 0.7, r=45, dmg 95 |
| `skill-censer-lob` | Censer Lob | primary | hold | 0.42 | flyOver projectile speed 420, life 1.1, r=7, dmg 14, impactRadius 30 |
| `skill-brimstone-line` | Brimstone Line | secondary | press | 5.0 | slow-line 150×18, dur 2.4, slowMul 0.2, dmg 2, fodderOnly, offset 56 |
| `dash-ash-step` | Ash Step | utility | press | 3.0 | dash 210 px, 0.16 s, iframe 0.22 s, decoyDuration 1.5 s |
| `skill-condemn-tether` | Condemnation Tether | special | press | 15.0 | tether speed 640, life 0.7, r=10, root 2.5 s, fodderDamage 45, fodderContactDps 28 |

---

## Loop, XP a limity (`loop.json`)

| Klíč | Hodnota |
|---|---|
| `xpBase` | 32 |
| `xpGrowth` | 1.30 |
| XP na level | `round(xpBase * xpGrowth^(level-1))` |
| `levelChoices` | 3 |
| `gemPickup` | 36 px |
| `gemMagnet` | 0 |
| `gemMagnetBonus` | 88 px |
| `gemMagnetSpeed` | 320 px/s |
| `maxGems` | 999 |
| `maxFodder` | 24 |
| `maxElites` | 6 (před kruhem cap 1) |
| `fodderContactCap` | 4 |
| `hashCell` | 128 px |
| `portalRadius` | 70 |
| `portalHold` | 1.4 s |

Rarity weights (level-up): common 1.00, uncommon 0.55, rare 0.22, lunar 0.08.

Lore drop chance: fodder 0.025, elite 0.25, boss 0.60. Live cap lore dropů: 8 (jeden aktivní drop na entity id).

---

## Director a obtížnost

`coefficient = 1 + runTime * perSecond + stageIndex * stageBonus`

| Klíč | Hodnota |
|---|---|
| `perSecond` | 0.0026 |
| `stageBonus` | 0 |
| `speedPerCoeff` | 0.035 |
| `creditRate` | 3.0 × coefficient / s |
| `fodderCost` | 6 |
| `eliteCost` | 18 |
| `sniperCost` | 18 |
| `fodderInterval` | 1.6 s |
| `eliteInterval` | 14 s |
| `sniperInterval` | 9 s |
| `maxSnipers` | 3 |
| `spawnMin` / `spawnMax` | 460 / 900 px |
| `spawnSafeRadius` | 460 px |
| `groupSizeMin` / `Max` | 3 / 6 |
| `eliteGroupSizeMin` / `Max` | 1 / 1 |
| `groupSpreadRadius` | 56 px |
| `eliteChanceBase` | 0.02 |
| `eliteChancePerCoeff` | 0.12 |
| `eliteChanceMax` | 0.40 |
| `eliteCostMul` | 3.0 |

Director **neutrácí**, když `boss_spawned` nebo `boss_defeated`.

HUD obtížnost (koeficient):

| Štítek | Rozsah |
|---|---|
| Dormant | 1.00-1.30 |
| Stirring | 1.30-1.65 |
| Tempered | 1.65-2.05 |
| Calcined | 2.05-2.55 |
| Volatile | 2.55-3.15 |
| Cataclysm | ≥ 3.15 |

---

## Elite modifikátory

Elity nejsou samostatné řádky katalogu. Jakýkoliv non-boss spawn může zmutovat. Afix se losuje **50/50**: jeden z dvojice, nikdy oba.

**Stat násobitele elity** (`loop.json` → `elite`): hpMul 2.4, damageMul 1.5, xpMul 2.5, creditsMul 2.5, radiusMul 1.25. HP, contact DPS a rychlost se navíc násobí `coefficient` (`speed = base * (1 + speedPerCoeff * (coeff − 1))`).

### Shielder

| Klíč | Hodnota |
|---|---|
| `percentHp` | 0.30 max HP jako štít |
| `delay` | 5.0 s bez zásahu, pak plná obnova štítu |

### Noxious

| Klíč | Hodnota |
|---|---|
| `contactSlowMul` | 0.5 |
| `contactSlowDuration` | 1.1 s |
| `corpseDelay` | 0.5 s |
| `popRadius` | 40 |
| `popDamage` | 8 × coefficient |
| `poolDuration` | 6.0 s (hazard r=68) |

---

## Stages

| id | Display | Kicker | Fodder | Ranged (šance) | Elite host | Sniper | Boss | firstEliteAt | teleporterAt | Hold | Radius |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `cinder-yard` | Cinder Yard | Nigredo & Calcination | `ember-mite` | `ember-spitter` 0.22 | `ember-chaser` | `enemy-astral-sniper` | `cinder-heart` | 25 s | 55 s | 20 s | 160 |
| `rime-dock` | Rime Dock | Albedo & Fixation | `frost-mite` | `frost-spitter` 0.22 | `frost-warden` | `enemy-astral-sniper` | `frost-sovereign` | 18 s | 50 s | 22 s | 150 |
| `glacial-tomb` | Glacial Tomb | Rubedo & The Great Seal | `frost-mite` | `frost-spitter` 0.28 | `frost-warden` | `enemy-astral-sniper` | `frost-emperor` | 14 s | 50 s | 25 s | 140 |

---

## Enemies (`entities.json`)

| id | Role | maxHp | speed | radius | contact dps | xp / credits | AI |
|---|---|---|---|---|---|---|---|
| `ember-mite` | fodder | 14 | 92 | 10 | 3 | 3 / 1 | chase |
| `ember-spitter` | fodder | 12 | 68 | 11 | 2 | 4 / 1 | ranged: range 280, keep 200, cd 2.1, windup 0.4, proj 240 / 1.35 / r6 / dmg 5 |
| `ember-chaser` | fodder (elite host) | 52 | 102 | 18 | 16 | 8 / 4 | chase |
| `cinder-heart` | boss | 1650 | 60 | 36 | 22 | 50 / 0 | boss keep 230 |
| `frost-mite` | fodder | 18 | 104 | 10 | 4 | 4 / 1 | chase |
| `frost-spitter` | fodder | 16 | 76 | 11 | 2 | 5 / 1 | ranged: range 300, keep 210, cd 1.9, windup 0.38, proj 260 / 1.4 / r6 / dmg 5 |
| `frost-warden` | fodder (elite host) | 80 | 90 | 20 | 20 | 10 / 5 | chase |
| `frost-sovereign` | boss | 2100 | 66 | 40 | 26 | 75 / 0 | boss keep 260 |
| `frost-emperor` | boss | 2800 | 70 | 45 | 30 | 120 / 0 | boss keep 280 |
| `enemy-astral-sniper` | fodder | 8 | 36 | 10 | 1 | 6 / 2 | sniper: keep 480, cd 3.2, windup 1.5, dmg 28, lineWidth 10 |

Chase melee: hold range = součet radiusů + 6, contact range = součet + 10, útok 0.35 s, CD 0.8 s.

---

## Boss útoky

Enrage všech tří: při 50 % HP. Cinder Heart a Frost Sovereign `cooldownMul` 0.75. Frost Emperor `cooldownMul` 0.72.

### Cinder Heart

| Útok | Typ | CD | Windup | Čísla |
|---|---|---|---|---|
| Slag Spray | fan | 3.2 | 0.6 | 5 střel, spread 50°, proj 230 / 2.0 / r9 / dmg 9 |
| Falling Clinker | meteor | 5.0 | 0.4 | delay 1.2, r=58, dmg 24, pool 4 s r=50 dps 8 slow 0.6 |
| Kiln Brood | summon | 9.0 | 0.35 | `ember-mite` ×3, maxAlive 6 |

### Frost Sovereign

| Útok | Typ | CD | Windup | Čísla |
|---|---|---|---|---|
| Cryo Lance | bolt | 2.2 | 0.45 | proj 360 / 1.8 / r9 / dmg 14 |
| Glacial Sweep | cone | 6.5 | 0.75 | lingering 0.55, range 320, angle 75°, dmg 12, slow 0.22 / 2.8 s |
| Rime Prison | prison | 8.5 | 0.35 | delay 1.15, r=64, dmg 16, root 1.6 s |
| Rime Brood | summon | 9.0 | 0.35 | `frost-mite` ×3, maxAlive 6 |

### Frost Emperor

| Útok | Typ | CD | Windup | Čísla |
|---|---|---|---|---|
| Glacial Spear | bolt | 2.4 | 0.4 | proj 400 / 1.9 / r10 / dmg 18 |
| Absolute Zero Pulse | pulse | 12.0 | 1.8 | r=620, dmg 48, slow 0.35 / 2.5 s |
| Aether Laser | laser | 9.5 | 0.8 | duration 2.4, trackSpeed 220, hitRadius 28, dps 28, trail 0.22 s, pool 3.5 s r=34 dps 7 slow 0.55 |
| Imperial Guard | summon | 10.0 | 0.35 | `frost-mite` ×3, maxAlive 6 |
| Brine Retinue | summon | 14.0 | 0.35 | `frost-spitter` ×2, maxAlive 3 |

Boss damage se násobí `coefficient`. Laser a hitscan umírají na pilíři.

---

## Augmentace (`items.json`)

13 položek. Stack `linear`. Hook ops: `add`, `pct`, `on-kill`, `on-crit`.

Základ crit (není v JSON survivors): **5 %** šance, **×2.0** násobek.

| id | Display | Rarity | Hooky | Unlock |
|---|---|---|---|---|
| `goat-hoof` | Cloven Sinew | common | +15 % speed | - |
| `brittle-plate` | Slag Carapace | common | +12 % armor | - |
| `wax-wings` | Waxen Pinions | common | +35 % hazardResist | - |
| `lead-core` | Lead Plumbum | common | +25 maxHp (add) | - |
| `salt-ward` | Salt Effigy | common | −12 % radius | `stage-clear` `cinder-yard` |
| `cinnabar-leech` | Cinnabar Leech | common | on-kill +0.3 HP | `total-kills` 100 |
| `hair-trigger` | Spasmodic Nerve | uncommon | −15 % cooldown | - |
| `overclock` | Bellows Heart | uncommon | +22 % aoeRadius, +20 % projSpeed | `boss-kill` `cinder-heart` |
| `mercury-vial` | Quicksilver Draught | uncommon | +35 % pickupRadius, +15 % xpGain | - |
| `glass-cannon` | Vitriol Veins | rare | +55 % damage, −25 % maxHp | - |
| `hungry-clip` | Parasitic Alembic | rare | +1 hpRegen, +35 % controlDuration, +25 % radius | `elite-kills` 10 |
| `calcined-lens` | Astrologer's Ocular | rare | +25 % critChance, on-crit −0.25 s CD, −15 % speed | `total-kills` 300 |
| `lunar-tithe` | Pale Moon Covenant | lunar | +60 % eliteDamage, +75 % critDamage, −25 % armor, −25 % xpGain | `stage-clear` `rime-dock` |

Display copy u Parasitic Alembic říká *Slay 10 Noxious Elites*. Matcher počítá **všechny** elity (`eliteKills`).

Stacking: `(base + add) * (1 + pct)` u speed / maxHp / radius. `damage_mul` a `cooldown_mul` začínají na 1. Armor clamp −1.0 … 0.75. Hazard resist clamp 0 … 0.85. Radius clamp 50 %-200 % base. Crit chance clamp 0-1. Crit mul min 1.0.

---

## Obstacles (`obstacles.json`)

| Klíč | Hodnota |
|---|---|
| pillar count | 14 |
| hazard count | 8 |
| volatile count | 9 |
| `dynamicHazards` | 8 |
| `borderPad` | 160 |
| `playerKeepOut` | 200 |
| `teleporterKeepOut` | 230 (pilíř, hazard) |
| `volatileTeleporterKeepOut` | 200 |
| `minSpacing` | 190 |
| `placeRetries` | 80 |
| pillar radius | 28 |
| hazard radius | 68 |
| hazard playerSpeedMul | 0.65 |
| hazard enemySpeedMul | 0.85 |
| hazard dps | 4 × coefficient |
| volatile radius | 14 |
| volatile hp | 25 × coefficient |
| volatile prime | 0.4 s |
| explosionRadius | 110 |
| enemyDamage | 45 × coefficient |
| playerDamage | 18 (flat) |
| rimeSlowDuration / mul | 2.0 s / 0.7 (jen Rime Dock) |

Biome display names:

| Stage | Pillar | Hazard | Volatile |
|---|---|---|---|
| Cinder Yard | Obsidian Kiln | Slag Fissure | Brimstone Urn |
| Rime Dock | Frozen Bollard | Brine Pool | Pressurized Rime Cask |
| Glacial Tomb | Glacial Monolith | Permafrost Crevasse | Volatile Ice Chunk |
