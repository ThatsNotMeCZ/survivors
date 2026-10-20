# survivors — katalog čísel (LIVE JSON)

Snapshot: **2026-10-20**.  
Zdroj pravdy: `src/data/*.json`. Když tento soubor nesedí s JSON, věř JSON.

Tyto hodnoty jsou **LIVE**. Neměň je v návrhu, aniž bys označil, že jde o retune.

## World

| Klíč | Hodnota |
|---|---|
| Arena | 2560 × 2560 |
| Camera `viewZoom` | 2.5 |
| Default survivor | `runner` (Homunculus) |
| Max projectiles (world.json) | 128 |
| Hash cell | 128 px |

## Survivor Homunculus (`runner`)

| Stat | Base |
|---|---|
| Speed | 280 |
| Max HP | 100 |
| Hurtbox radius | 14 |
| Primary | `bolt` Ignis Bolt |
| Utility | `dash` Phase Step |
| Secondary / special | unbound |
| Starting items | none |

## Skills

### Ignis Bolt (`bolt`, primary, hold)

| | |
|---|---|
| Cooldown | 0.16 s |
| Projectile speed | 780 |
| Lifetime | 0.85 s |
| Radius | 5 |
| Damage | 10 |
| Pierce | none (hit = despawn) |

### Phase Step (`dash`, utility, press)

| | |
|---|---|
| Cooldown | 0.9 s |
| Distance | 210 |
| Duration | 0.16 s |
| I-frame | 0.22 s |
| Direction | move vector, else aim |

LIVE effect types: `projectile`, `dash`.

## Loop / XP / caps

| Klíč | Hodnota |
|---|---|
| XP base | 32 |
| XP growth | 1.30 (`round(32 * 1.30^(level-1))`) |
| Gem pickup | 36 |
| Gem magnet | 88 |
| Gem magnet speed | 320 |
| Max fodder | 32 |
| Max elites | 3 (před circle max 1) |
| Max gems | 64 |
| Fodder contact cap | 4 |
| Level choices | 3 |
| Portal radius | 70 |
| Portal hold | 1.4 s |

## Director / difficulty

| Klíč | Hodnota |
|---|---|
| Credit rate | 3.6 × coefficient / s |
| Fodder cost | 7 |
| Elite cost | 42 |
| Fodder interval | 0.5 s |
| Elite interval | 14 s |
| Spawn ring | 340–520 px |
| Coeff per second | 0.006 |
| Coeff per stage | 0.35 |
| Enemy speed per (coeff−1) | +5% |
| Formula | `1 + runTime * 0.006 + stageIndex * 0.35` |

Rarity weights: common 1.00, uncommon 0.55, rare 0.22, lunar 0.08.

## Stages

| | Cinder Yard | Rime Dock |
|---|---|---|
| id | `cinder-yard` | `rime-dock` |
| First elite | 15 s | 12 s |
| Circle on | 55 s | 50 s |
| Hold | 20 s | 22 s |
| Circle radius | 160 | 150 |
| Ranged chance | 0.22 | 0.22 |
| Fodder | `ember-mite` | `frost-mite` |
| Ranged | `ember-spitter` | `frost-spitter` |
| Elite | `ember-chaser` (Ember Warden) | `frost-warden` |
| Boss | `cinder-heart` | `frost-sovereign` |

## Enemies (base stats)

Spitter bolt damage je **5** u obou biomů (ne 6/7).

| id | Role | HP | Speed | Radius | Contact DPS | XP | Credits |
|---|---|---|---|---|---|---|---|
| `ember-mite` | fodder chase | 14 | 92 | 10 | 3 | 3 | 1 |
| `ember-spitter` | fodder ranged | 12 | 68 | 11 | 2 | 4 | 1 |
| `ember-chaser` | elite chase | 90 | 102 | 22 | 28 | 14 | 8 |
| `cinder-heart` | boss chase | 520 | 78 | 36 | 34 | 40 | 0 |
| `frost-mite` | fodder chase | 18 | 104 | 10 | 4 | 4 | 1 |
| `frost-spitter` | fodder ranged | 16 | 76 | 11 | 2 | 5 | 1 |
| `frost-warden` | elite chase | 140 | 90 | 24 | 34 | 18 | 9 |
| `frost-sovereign` | boss chase | 620 | 80 | 40 | 40 | 60 | 0 |

Ranged tuning:

| | Ember Spitter | Frost Spitter |
|---|---|---|
| range | 280 | 300 |
| keep | 200 | 210 |
| cooldown | 2.1 s | 1.9 s |
| windup | 0.4 s | 0.38 s |
| bolt speed | 240 | 260 |
| bolt lifetime | 1.35 s | 1.4 s |
| bolt radius | 6 | 6 |
| bolt damage | 5 | 5 |

## Items (12)

Stack = `linear`. Stats: `speed`, `maxHp`, `radius`, `damage`, `cooldown`.  
Vzorec: `(base + add) * (1 + pct)`.

| id | Display | Rarity | Hooks |
|---|---|---|---|
| `glass-cannon` | Vitriol Veins | uncommon | damage +40%, maxHp −15% |
| `goat-hoof` | Cloven Sinew | common | speed +14%, maxHp −6% |
| `brittle-plate` | Slag Carapace | common | maxHp +28%, speed −12% |
| `hair-trigger` | Spasmodic Nerve | uncommon | cooldown −15%, radius +12% |
| `overclock` | Bellows Heart | uncommon | damage +22%, cooldown +12% |
| `wax-wings` | Waxen Pinions | common | speed +16%, maxHp −8% |
| `hungry-clip` | Parasitic Alembic | rare | damage +28%, radius +14% |
| `lead-core` | Lead Plumbum | common | maxHp +18 (add), damage −8% |
| `mercury-vial` | Quicksilver Draught | uncommon | cooldown −18%, maxHp −12% |
| `calcined-lens` | Astrologer's Ocular | rare | damage +32%, speed −10% |
| `salt-ward` | Salt Effigy | common | radius −15%, damage −10% |
| `lunar-tithe` | Pale Moon Covenant | lunar | damage +75%, maxHp −35%, radius +18% |

## Obstacles

Counts: 14 pillars, 8 hazards, 9 volatiles.

| Klíč | Hodnota |
|---|---|
| Border pad | 160 |
| Player keep-out | 200 |
| Teleporter keep-out (pillar/hazard) | 230 |
| Volatile vs circle | 200 |
| Min spacing | 190 |
| Place retries | 80 |
| Pillar radius | 52 |
| Hazard radius | 68 |
| Hazard player speed | ×0.65 |
| Hazard enemy speed | ×0.85 |
| Hazard DPS | 4 × coefficient |
| Volatile radius | 22 |
| Volatile HP | 25 × coefficient |
| Prime | 0.4 s |
| Explosion radius | 110 |
| Enemy damage | 45 × coefficient |
| Player damage | 18 flat (iframe skip) |
| Rime slow | 2.0 s × 0.7 |

Display: Cinder = Obsidian Kiln / Slag Fissure / Brimstone Urn.  
Rime = Frozen Bollard / Brine Pool / Pressurized Rime Cask.

Bosové fázují skrz pillars. Hazard neničí projectiles. Volatile damage jen z player Bolt.

## Performance budget (design cap)

| Layer | Cap |
|---|---|
| Simulated enemies | 128 |
| Projectiles | 256 (budget) / 128 (world.json pool) |
| XP gems | 64 |
| Elites / bosses | 2–8 sprites |
| Obstacles | 31 |
| Target | 60 fps 1080p |

Slice žije pod budgetem: 32 fodder + 3 elite + 1 boss.
