# survivors — katalog čísel (LIVE JSON)

Snapshot: **2026-10-21**.  
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

## Survivors

### Homunculus (`runner`)

| Stat | Base |
|---|---|
| Speed | 280 |
| Max HP | 100 |
| Hurtbox radius | 14 |
| Primary | `bolt` Ignis Bolt |
| Secondary | `skill-aether-pierce` Piercing Aether |
| Utility | `dash` Phase Step |
| Special | `skill-crucible-cull` Crucible Cull |
| Starting items | none |

### The Penitent (`penitent`)

| Stat | Base |
|---|---|
| Speed | 245 |
| Max HP | 135 |
| Hurtbox radius | 14 |
| Primary | `skill-censer-lob` Censer Lob |
| Secondary | `skill-brimstone-line` Brimstone Line |
| Utility | `dash-ash-step` Ash Step |
| Special | `skill-condemn-tether` Condemnation Tether |
| Starting items | none |

## Skills

LIVE effect types: `projectile`, `dash`, `self-slow`, `delayed-strike`, `slow-line`, `tether`.

### Ignis Bolt (`bolt`, primary, hold)

| | |
|---|---|
| Cooldown | 0.28 s |
| Projectile speed | 780 |
| Lifetime | 0.85 s |
| Radius | 5 |
| Damage | 10 |
| Pierce | none (hit = despawn) |

### Piercing Aether (`skill-aether-pierce`, secondary, press)

| | |
|---|---|
| Cooldown | 4 s |
| Speed | 1400 |
| Lifetime | 0.45 s |
| Radius | 6 |
| Damage | 22 |
| Pierce | all in line |
| Self-slow | ×0.5 for 0.25 s |

### Phase Step (`dash`, utility, press)

| | |
|---|---|
| Cooldown | 0.9 s |
| Distance | 210 |
| Duration | 0.16 s |
| I-frame | 0.22 s |
| Direction | move vector, else aim |

### Crucible Cull (`skill-crucible-cull`, special, press)

| | |
|---|---|
| Cooldown | 12 s |
| Delay | 0.7 s |
| Radius | 45 |
| Damage | 95 |

### Censer Lob (`skill-censer-lob`, primary, hold)

| | |
|---|---|
| Cooldown | 0.42 s |
| Speed | 420 |
| Lifetime | 1.1 s |
| Radius | 7 |
| Damage | 14 |
| flyOver | true (over enemies) |
| impactRadius | 30 (splash at cursor) |

### Brimstone Line (`skill-brimstone-line`, secondary, press)

| | |
|---|---|
| Cooldown | 5 s |
| Length × width | 150 × 18 |
| Duration | 2.4 s |
| Slow | ×0.2 (fodder only) |
| Damage | 2 DPS |
| Offset | 56 |
| Elites / bosses | ignore |

### Ash Step (`dash-ash-step`, utility, press)

| | |
|---|---|
| Cooldown | 1.1 s |
| Distance / duration / iframe | 210 / 0.16 s / 0.22 s |
| Decoy | 1.5 s, fodder only |

### Condemnation Tether (`skill-condemn-tether`, special, press)

| | |
|---|---|
| Cooldown | 15 s |
| Speed | 640 |
| Lifetime | 0.7 s |
| Radius | 8 |
| Root | 2.5 s (first elite/boss) |
| Fodder contact DPS | 18 on rooted target |
| Miss / fodder hit | wastes cooldown |

## Loop / XP / caps

| Klíč | Hodnota |
|---|---|
| XP base | 32 |
| XP growth | 1.30 (`round(32 * 1.30^(level-1))`) |
| Gem pickup | 36 |
| Gem magnet | 88 |
| Gem magnet speed | 320 |
| Max fodder | 32 (snipery se počítají sem) |
| Max elites | 3 (před circle max 1) |
| Max snipers | 2 |
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
| Sniper cost | 30 |
| Fodder interval | 0.5 s |
| Elite interval | 14 s |
| Sniper interval | 7 s |
| Spawn ring | 340–520 px |
| Coeff per second | 0.006 |
| Coeff per stage | 0.35 |
| Enemy speed per (coeff−1) | +5% |
| Formula | `1 + runTime * 0.006 + stageIndex * 0.35` |

Rarity weights: common 1.00, uncommon 0.55, rare 0.22, lunar 0.08.

Po spawnu bosse: elity se nekupují. Fodder + snipery dál.

## Noxious (každá elite)

| Klíč | Hodnota |
|---|---|
| Contact slow | ×0.5 for 1.1 s |
| Corpse delay | 0.5 s |
| Pop radius | 40 |
| Pop damage | 8 × coefficient |
| Acid pool | `hazard` r=68, permanent until stage wipe |
| Dynamic hazard cap | 8 |

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
| Sniper | `enemy-astral-sniper` | `enemy-astral-sniper` |
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
| `enemy-astral-sniper` | fodder sniper | 8 | 36 | 10 | 1 | 6 | 2 |

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

Astral Watcher:

| | |
|---|---|
| keep | 480 |
| cooldown | 3.2 s |
| windup | 1.5 s |
| hitscan damage | 28 × coefficient |
| lineWidth | 10 |
| Pillars | block the laser |
| I-frames / step off line | negate |

## Items (13)

Stack = `linear`. Stats: `speed`, `maxHp`, `radius`, `damage`, `cooldown`.  
Vzorec: `(base + add) * (1 + pct)`. `on-kill` heals current HP on enemy death (not a resolveStats stat).

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
| `cinnabar-leech` | Cinnabar Leech | common | +0.2 HP on kill, radius +8% |

## Obstacles

Counts: 14 pillars, 8 hazards, 9 volatiles. Pool cap = 31 + 8 dynamic acid = **39**.

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
| Dynamic hazards | 8 (Noxious acid) |

Display: Cinder = Obsidian Kiln / Slag Fissure / Brimstone Urn.  
Rime = Frozen Bollard / Brine Pool / Pressurized Rime Cask.

Bosové fázují skrz pillars. Hazard neničí projectiles. Volatile damage jen z player Bolt. Sniper laser blokují pillars.

## Performance budget (design cap)

| Layer | Cap |
|---|---|
| Simulated enemies | 128 |
| Projectiles | 256 (budget) / 128 (world.json pool) |
| XP gems | 64 |
| Elites / bosses | 2–8 sprites |
| Obstacles | 31 placed + 8 dynamic |
| Target | 60 fps 1080p |

Slice žije pod budgetem: 32 fodder (vč. ≤2 sniperů) + 3 elite + 1 boss.
