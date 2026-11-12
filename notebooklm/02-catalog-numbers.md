# survivors — katalog čísel (LIVE JSON)

Snapshot: **2026-11-05**.  
Zdroj pravdy: `web/src/data/*.json`. Když tento soubor nesedí s JSON, věř JSON.

Tyto hodnoty jsou **LIVE**. Neměň je v návrhu, aniž bys označil, že jde o retune.

---

## World (`web/src/data/world.json`)

| Klíč | Hodnota |
|---|---|
| Arena width × height | 2560 × 2560 px |
| Border insets (X / Y) | 21 px / 34 px |
| Camera `viewZoom` | 2.5 |
| Default survivor | `runner` (Homunculus) |
| Default enemy | `ember-chaser` (Ember Warden) |
| Max projectiles pool | 128 |
| Hash cell | 128 px |

---

## Survivors (`web/src/data/survivors.json`)

### Homunculus (`runner`) — Skirmisher
- **Titul:** The Runner
- **Lore:** *Clay and quicksilver, stolen from a failed Great Work. You kite the dross until the seal holds.*
- **Crosshair:** `runner` (quicksilver/aether precision brackets)
- **Unlock:** Výchozí (odemčen od začátku)

| Stat | Base hodnota |
|---|---|
| Speed | 280 |
| Max HP | 100 |
| Hurtbox radius | 14 px |
| Primary | `bolt` (Ignis Bolt) |
| Secondary | `skill-aether-pierce` (Piercing Aether) |
| Utility | `dash` (Phase Step) |
| Special | `skill-crucible-cull` (Crucible Cull) |
| Starting items | none |

### The Penitent (`penitent`) — Caster / Controller
- **Titul:** The Caster
- **Lore:** *A monk who walked into the kiln and did not burn. He draws circles the horde must not cross.*
- **Crosshair:** `penitent` (consecrated liturgical ring)
- **Unlock:** `boss-kill` na `frost-sovereign` (*Slay the Frost Sovereign in the Rime Dock*)

| Stat | Base hodnota |
|---|---|
| Speed | 245 |
| Max HP | 135 |
| Hurtbox radius | 14 px |
| Primary | `skill-censer-lob` (Censer Lob) |
| Secondary | `skill-brimstone-line` (Brimstone Line) |
| Utility | `dash-ash-step` (Ash Step) |
| Special | `skill-condemn-tether` (Condemnation Tether) |
| Starting items | none |

---

## Skills (`web/src/data/skills.json`)

LIVE effect typy: `projectile`, `dash`, `self-slow`, `delayed-strike`, `slow-line`, `tether`.

### Ignis Bolt (`bolt`)
- **Slot / Input:** Primary / Hold LMB
- **Lore / Hook:** *A needle of fire. It only flies where you point.* Fires searing bolts of flame toward your cursor.
- **Cooldown:** 0.28 s
- **Effect (`projectile`):** Speed 780, lifetime 0.85 s, radius 5 px, damage 10, pierce: false (hit = despawn).

### Piercing Aether (`skill-aether-pierce`)
- **Slot / Input:** Secondary / Press RMB
- **Lore / Hook:** *A thin ray of stolen sky. Line them up or waste the breath.* Lances through every foe in a line, briefly steadying your stride.
- **Cooldown:** 4.0 s
- **Effect 1 (`projectile`):** Speed 1400, lifetime 0.45 s, radius 6 px, damage 22, `pierce: true` (vše v přímce).
- **Effect 2 (`self-slow`):** Mul 0.5 (zpomalení na 50 %) na 0.25 s.

### Phase Step (`dash`)
- **Slot / Input:** Utility / Press Shift nebo Space
- **Lore / Hook:** *The vessel slips between worlds for a breath.* Dash swiftly forward, phasing harmlessly through foes and projectiles.
- **Cooldown:** 0.9 s
- **Effect (`dash`):** Distance 210 px, duration 0.16 s, i-frame 0.22 s. Směr: pohybový vektor WASD, jinak kurzor.

### Crucible Cull (`skill-crucible-cull`)
- **Slot / Input:** Special / Press Q
- **Lore / Hook:** *A hammer of the Great Work, dropped where you will it.* Calls down a concentrated alchemical strike at the cursor after a brief delay.
- **Cooldown:** 12.0 s
- **Effect (`delayed-strike`):** Delay 0.7 s telegraph, impact radius 45 px, damage 95.

### Censer Lob (`skill-censer-lob`)
- **Slot / Input:** Primary / Hold LMB
- **Lore / Hook:** *Heavy glass, thrown in an arc. The air between you and the stain is empty.* Lobs a heavy censer over the horde that shatters on impact, scorching nearby foes.
- **Cooldown:** 0.42 s
- **Effect (`projectile`):** Speed 420, lifetime 1.1 s, radius 7 px, damage 14, `flyOver: true` (létá nad nepřáteli bez kolize), `impactRadius: 30` px (plošný dopad u kurzoru).

### Brimstone Line (`skill-brimstone-line`)
- **Slot / Input:** Secondary / Press RMB
- **Lore / Hook:** *A seam of sulfur drawn across the yard. The small ones fear it.* Draws a burning seam of sulfur that slows lesser foes crossing it.
- **Cooldown:** 5.0 s
- **Effect (`slow-line`):** Délka 150 px, šířka 18 px, duration 2.4 s, slow mul 0.2 (zpomalení na 20 %), damage 2 DPS, `fodderOnly: true` (elity a bosové ignorují), offset 56 px před hráčem.

### Ash Step (`dash-ash-step`)
- **Slot / Input:** Utility / Press Shift nebo Space
- **Lore / Hook:** *Leave a husk of ash. The mites chase the ghost.* Dash to safety while leaving an ash effigy that lures lesser foes.
- **Cooldown:** 1.1 s
- **Effect (`dash`):** Distance 210 px, duration 0.16 s, i-frame 0.22 s, `decoyDuration: 1.5` s (vábnička pro fodder, elity ignorují).

### Condemnation Tether (`skill-condemn-tether`)
- **Slot / Input:** Special / Press Q
- **Lore / Hook:** *A chain for the proud. Miss, and the working waits.* Hurls a binding chain that roots the first elite or boss struck and sears lesser foes.
- **Cooldown:** 15.0 s
- **Effect (`tether`):** Speed 640, lifetime 0.7 s, radius 8 px, `rootDuration: 2.5` s (na první zasaženou elitu nebo bosse), `fodderContactDps: 18` (fodder v kontaktu s rootnutým cílem hoří). Minutí nebo zásah fodderu spálí cooldown bez rootu.

---

## Loop, XP & Limity (`web/src/data/loop.json`)

| Klíč | Hodnota | Poznámka |
|---|---|---|
| XP base | 32 | Základ pro level 1 |
| XP growth | 1.30 | Vzorec: `round(32 * 1.30^(level - 1))` |
| Gem pickup radius | 36 px | Okamžité sebrání |
| Gem magnet radius | 88 px | Začne se přitahovat k hráči |
| Gem magnet speed | 320 px/s | Rychlost přitahování |
| Max fodder | 32 | Živých na mapě (snipery se počítají sem) |
| Max elites | 3 | Před spuštěním kruhu max 1, při holdu max 3 |
| Max gems | 64 | Na zemi |
| Fodder contact cap | 4 | Max počet fodder zdrojů udělujících contact DPS ve stejný moment |
| Level choices | 3 | Počet nabízených karet itemů |
| Portal radius | 70 px | Kruh Riftu |
| Portal hold | 1.4 s | Čas stání v portálu pro přechod |

### Šance na Lore kapky (`loreDropChance`)
- **Fodder:** 0.025 (2.5 %)
- **Elite:** 0.25 (25 %)
- **Boss:** 0.60 (60 %)

---

## Director & Obtížnost (`web/src/data/loop.json`)

| Klíč | Hodnota |
|---|---|
| Credit rate | 3.6 × coefficient / s |
| Fodder cost | 7 kreditů |
| Elite cost | 42 kreditů |
| Sniper cost | 30 kreditů |
| Fodder interval | 0.5 s |
| Elite interval | 14.0 s |
| Sniper interval | 7.0 s |
| Max snipers | 2 |
| Spawn min / max | 460 px / 900 px |
| Spawn safe radius | 460 px (nikdy nespawne blíže než 460 px k hráči) |
| Coeff per second | 0.006 / s |
| Coeff stage bonus | +0.35 za každou další stage |
| Enemy speed bonus | +5 % rychlosti za každých `(coeff - 1)` |
| Vzorec coefficientu | `1 + runTime * 0.006 + stageIndex * 0.35` |

**Zastavení directoru během souboje s bossem:**  
Jakmile se spawne boss dané stage (`world.bossSpawned`), Director **okamžitě zastaví veškeré utrácení kreditů** (žádný nový fodder, spitter, sniper ani elita). Žijící nepřátelé dožijí přirozeně, zatímco boss vyvolává své vlastní miniony přes summon útoky.

---

## Elite Modifiery (LIVE na každé elitě)

Každá elita má v aktuální verzi **oba** modifiery:

### 1. Noxious (`noxious` v `loop.json`)
- **Contact slow:** ×0.5 rychlost hráče na 1.1 s při dotyku.
- **Corpse delay:** 0.5 s telegraph po smrti elity.
- **Pop explosion:** Radius 40 px, damage `8 * coefficient`.
- **Permanent acid pool:** Vytvoří hazard louži (radius 68 px, ×0.65 player speed, `4 * coefficient` DPS) trvající až do konce stage (stage wipe).
- **Dynamic hazard cap:** max 8 louží najednou na mapě.

### 2. Shielder (`shielder` v `loop.json`)
- **Extra štít:** `percentHp: 0.3` (+30 % max HP ve formě aetherického štítu při spawnu).
- **Regenerace štítu:** Obnoví se na plnou hodnotu (30 % max HP) po 5.0 s (`delay: 5`) bez obdrženého zásahu.

---

## Stages (3 komory Great Work)

| Parametr | Stage 1: Cinder Yard | Stage 2: Rime Dock | Stage 3: Glacial Tomb |
|---|---|---|---|
| **id** | `cinder-yard` | `rime-dock` | `glacial-tomb` |
| **Kicker** | First Chamber · Nigredo & Calcination | Second Chamber · Albedo & Fixation | Final Chamber · Rubedo & The Great Seal |
| **First elite at** | 15 s | 12 s | 10 s |
| **Circle manifests at** | 55 s | 50 s | 50 s |
| **Circle hold duration** | 20 s | 22 s | 25 s |
| **Circle radius** | 160 px | 150 px | 140 px |
| **Ranged chance** | 0.22 (22 %) | 0.22 (22 %) | 0.28 (28 %) |
| **Fodder** | `ember-mite` | `frost-mite` | `frost-mite` |
| **Ranged fodder** | `ember-spitter` | `frost-spitter` | `frost-spitter` |
| **Sniper** | `enemy-astral-sniper` | `enemy-astral-sniper` | `enemy-astral-sniper` |
| **Elite** | `ember-chaser` (Ember Warden) | `frost-warden` | `frost-warden` |
| **Boss** | `cinder-heart` (Cinder Heart) | `frost-sovereign` (Frost Sovereign) | `frost-emperor` (Frost Emperor) |

---

## Enemies — Běžní a Elity (`web/src/data/entities.json`)

Hodnoty jsou **base** (ve hře se škálují difficulty coefficientem).

| id | Jméno | Titul | Role | HP | Speed | Radius | Contact DPS | XP | Credits |
|---|---|---|---|---|---|---|---|---|---|
| `ember-mite` | Ember Mite | Scorched Dross | fodder chase | 14 | 92 | 10 px | 3 | 3 | 1 |
| `ember-spitter` | Ember Spitter | Slag Bile Vessel | fodder ranged | 12 | 68 | 11 px | 2 | 4 | 1 |
| `ember-chaser` | Ember Warden | Furnace Overseer | elite chase | 90 | 102 | 22 px | 28 | 14 | 8 |
| `frost-mite` | Frost Mite | Rime-Bitten Husk | fodder chase | 18 | 104 | 10 px | 4 | 4 | 1 |
| `frost-spitter` | Frost Spitter | Brine Condenser | fodder ranged | 16 | 76 | 11 px | 2 | 5 | 1 |
| `frost-warden` | Frost Warden | Cryo-Bound Sentinel | elite chase | 140 | 90 | 24 px | 34 | 18 | 9 |
| `enemy-astral-sniper` | Astral Watcher | Ocular of the Void | fodder sniper | 8 | 36 | 10 px | 1 | 6 | 2 |

### Ranged chování (Spitters)
- **Ember Spitter:** range 280 px, keep 200 px, cooldown 2.1 s, windup 0.4 s, projektil: speed 240, lifetime 1.35 s, radius 6 px, damage 5.
- **Frost Spitter:** range 300 px, keep 210 px, cooldown 1.9 s, windup 0.38 s, projektil: speed 260, lifetime 1.4 s, radius 6 px, damage 5.

### Sniper chování (Astral Watcher)
- **Keep:** 480 px
- **Cooldown:** 3.2 s
- **Windup telegraph:** 1.5 s zamčený laser (šířka paprsku 10 px)
- **Hitscan damage:** 28 × coefficient
- **Obrana hráče:** Překážky (pillars) laser zastaví; i-frame dash nebo úkrok z čáry telegraphu ránu zcela neguje.

---

## Bosses — Unikátní Kity (`web/src/data/entities.json`)

Všichni bossové mají enrage mechaniku při 50 % HP (`cooldownMul` zkracuje cooldowny o 25–28 %) a vyvolávají své přisluhovače.

### 1. Cinder Heart (`cinder-heart`) — Stage 1 Boss
- **Titul:** Core of the First Kiln
- **Stats:** Max HP 1650, Speed 60, Radius 36 px, Contact DPS 22, XP 50, Credits 0
- **AI / Keep:** `type: "boss"`, keep 230 px
- **Enrage:** Při HP ≤ 50 % zkrácení cooldownů na ×0.75
- **Útoky:**
  1. `Slag Spray` (fan): Cooldown 3.2 s, windup 0.6 s, 5 projektilů v úhlu 50°, rychlost 230, lifetime 2.0 s, radius 9 px, damage 9.
  2. `Falling Clinker` (meteor): Cooldown 5.0 s, windup 0.4 s, delay 1.2 s, telegraph radius 58 px, dopadová damage 24. Zanechá lávovou louži na 4.0 s (radius 50 px, 8 DPS, slow ×0.6).
  3. `Kiln Brood` (summon): Cooldown 9.0 s, windup 0.35 s, vyvolá 3× `ember-mite` (max 6 živých z tohoto summonu).

### 2. Frost Sovereign (`frost-sovereign`) — Stage 2 Boss
- **Titul:** Regent of the Frozen Dock
- **Stats:** Max HP 2100, Speed 66, Radius 40 px, Contact DPS 26, XP 75, Credits 0
- **AI / Keep:** `type: "boss"`, keep 260 px
- **Enrage:** Při HP ≤ 50 % zkrácení cooldownů na ×0.75
- **Útoky:**
  1. `Cryo Lance` (bolt): Cooldown 2.2 s, windup 0.45 s, projektil: speed 360, lifetime 1.8 s, radius 9 px, damage 14.
  2. `Glacial Sweep` (cone): Cooldown 6.5 s, windup 0.75 s, lingering 0.55 s, dosah 320 px, úhel 75°, damage 12, slow ×0.22 na 2.8 s.
  3. `Rime Prison` (prison): Cooldown 8.5 s, windup 0.35 s, delay 1.15 s, radius 64 px, damage 16, root na 1.6 s.
  4. `Rime Brood` (summon): Cooldown 9.0 s, windup 0.35 s, vyvolá 3× `frost-mite` (max 6 živých z tohoto summonu).

### 3. Frost Emperor (`frost-emperor`) — Stage 3 Final Boss
- **Titul:** Monarch of Absolute Zero
- **Stats:** Max HP 2800, Speed 70, Radius 45 px, Contact DPS 30, XP 120, Credits 0
- **AI / Keep:** `type: "boss"`, keep 280 px
- **Enrage:** Při HP ≤ 50 % zkrácení cooldownů na ×0.72
- **Útoky:**
  1. `Glacial Spear` (bolt): Cooldown 2.4 s, windup 0.4 s, projektil: speed 400, lifetime 1.9 s, radius 10 px, damage 18.
  2. `Absolute Zero Pulse` (pulse): Cooldown 12.0 s, windup 1.8 s telegraph, obrovský pulz po aréně radius 620 px, damage 48, slow ×0.35 na 2.5 s.
  3. `Aether Laser` (laser): Cooldown 9.5 s, windup 0.8 s, trvání paprsku 2.4 s, tracking rotace speed 150 px/s, hit radius 28 px, 28 DPS. Každých 0.22 s zanechává za stopou mrazivé louže (duration 3.5 s, radius 34 px, 7 DPS, slow ×0.55).
  4. `Imperial Guard` (summon): Cooldown 10.0 s, windup 0.35 s, vyvolá 3× `frost-mite` (max 6 živých).
  5. `Brine Retinue` (summon): Cooldown 14.0 s, windup 0.35 s, vyvolá 2× `frost-spitter` (max 3 živých).

---

## Augmentace / Itemy (13) (`web/src/data/items.json`)

Stackování: `linear`.  
Podporované statistiky: `speed`, `maxHp`, `radius` (velikost hurtboxu hráče), `damage`, `cooldown`, `critChance`, `critDamage`.  
Vzorec: `(base + add) * (1 + pct)`. `on-kill` léčí přímo životy při zabití nepřítele (není součástí `resolveStats`).

### Pravidlo vyvážení:
- **Common & Uncommon:** Čistě pozitivní stavební kameny pro build.
- **Rare & Lunar:** Mocné oboustranné meče s výraznými tradeoffs.

| id | Jméno (Display) | Rarita | Hooky | Podmínka odemčení (Unlock) |
|---|---|---|---|---|
| `glass-cannon` | Vitriol Veins | rare | `damage` +60% (pct 0.6), `maxHp` −25% (pct -0.25) | Odemčeno od začátku |
| `goat-hoof` | Cloven Sinew | common | `speed` +14% (pct 0.14) | Odemčeno od začátku |
| `brittle-plate` | Slag Carapace | common | `maxHp` +25% (pct 0.25) | Odemčeno od začátku |
| `hair-trigger` | Spasmodic Nerve | uncommon | `cooldown` −15% (pct -0.15) | Odemčeno od začátku |
| `overclock` | Bellows Heart | uncommon | `damage` +16% (pct 0.16), `critDamage` +35% (pct 0.35) | `boss-kill`: `cinder-heart` (*Slay the Cinder Heart*) |
| `wax-wings` | Waxen Pinions | common | `speed` +12% (pct 0.12) | Odemčeno od začátku |
| `hungry-clip` | Parasitic Alembic | rare | `cooldown` −30% (pct -0.30), `radius` +25% (pct 0.25) | `elite-kills`: 10 (*Slay 10 Noxious Elites*) |
| `lead-core` | Lead Plumbum | common | `maxHp` +25 flat (add 25) | Odemčeno od začátku |
| `mercury-vial` | Quicksilver Draught | uncommon | `cooldown` −12% (pct -0.12), `speed` +6% (pct 0.06) | Odemčeno od začátku |
| `calcined-lens` | Astrologer's Ocular | rare | `critChance` +30% (pct 0.30), `critDamage` +50% (pct 0.50), `speed` −18% (pct -0.18) | `total-kills`: 300 (*Slay 300 Dross across workings*) |
| `salt-ward` | Salt Effigy | common | `radius` −12% (pct -0.12 zmenšení hurtboxu) | `stage-clear`: `cinder-yard` (*Clear the Cinder Yard*) |
| `lunar-tithe` | Pale Moon Covenant | lunar | `damage` +75% (pct 0.75), `critDamage` +50% (pct 0.50), `maxHp` −40% (pct -0.40), `radius` +20% (pct 0.20) | `stage-clear`: `rime-dock` (*Clear the Rime Dock*) |
| `cinnabar-leech` | Cinnabar Leech | common | `hp` +0.25 on kill (heal 0.25 HP za každého zabitého nepřítele) | `total-kills`: 100 (*Slay 100 Dross across workings*) |

---

## Obstacles / Překážky (`web/src/data/obstacles.json`)

Počty vygenerované při startu stage: **14 pilířů, 8 hazardů, 9 volatilních překážek** = 31 umístěných + až 8 dynamických louží kyseliny (Noxious) = pool max **39**.

| Klíč | Hodnota |
|---|---|
| Border pad | 160 px |
| Player keep-out | 200 px |
| Teleporter keep-out (pillar/hazard) | 230 px |
| Volatile vs teleporter circle | 200 px |
| Min spacing mezi překážkami | 190 px |
| Place retries | 80 |
| **Pillar radius** | **28 px** |
| **Hazard radius** | **68 px** |
| Hazard player speed mul | ×0.65 |
| Hazard enemy speed mul | ×0.85 |
| Hazard DPS | 4 × coefficient |
| **Volatile radius** | **14 px** |
| Volatile HP | 25 × coefficient |
| Volatile prime delay | 0.4 s |
| Volatile explosion radius | 110 px |
| Volatile damage to enemy | 45 × coefficient |
| Volatile damage to player | 18 flat (dash i-frame ránu neguje) |
| Volatile Rime slow | 2.0 s trvání, slow ×0.7 |
| Dynamic hazards cap | 8 (Noxious acid pools) |

### Biome varianty překážek:
- **Cinder Yard:** Obsidian Kiln (pillar) / Slag Fissure (hazard) / Brimstone Urn (volatile)
- **Rime Dock:** Frozen Bollard (pillar) / Brine Pool (hazard) / Pressurized Rime Cask (volatile)
- **Glacial Tomb:** Glacial Monolith (pillar) / Permafrost Crevasse (hazard) / Volatile Ice Chunk (volatile)

### Interakční pravidla:
- **Pilíře (Pillars):** Blokují pohyb hráče, fodderu i elit. **Bosové fázují skrz pilíře.** Blokují player Bolt, spitter bolty a Astral Watcher laser.
- **Hazards:** Projektily létají nad nimi bez ovlivnění. Pomalí hráče i potvory, hráče zraňují (pokud není v dash i-frame).
- **Volatiles:** Blokují projektily. Poškozují se **pouze hráčovým mířeným Boltem/útokem** (ne nepřítelem, ne pass-by). Po vyčerpání HP začne blikat 0.4 s telegraph a pak exploduje.
