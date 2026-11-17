# survivors - Game Design Spec (gameplay)

Snapshot: **2026-11-17**. Čísla v tabulkách musí přesně sedět s `02-catalog-numbers.md`.  
Klient: Godot 4.7, `Godot/hermetic-rifts/`.

Working title: **survivors**. Hall title: **Hermetic Rifts**.  
Žánr: 2D survivor-like. Hybrid **Vampire Survivors pacing** + **Risk of Rain 2 pressure**.  
Jeden run (target): **15-20 minut**. Live slice používá komprimované hodiny. Hráč hraje aktivně rukama.

Player-facing téma: **Dark Hermetic**. V rozhraní se používají hermetické názvy, nikoliv interní ID.  
Hráč ovládá alchemickou schránku (Vessel: Homunculus nebo The Penitent). XP = Mercury Drops / Essence. Zóna přežití = Transmutation Circle. Přechod mezi komorami = Rift. Po Frost Emperorovi zlatá brána **Ouroboros**.

---

## 1. Pitch

Pohybuješ se skrz hordu, která časem zhrubne, zrychlí a získá nebezpečnější schopnosti, nikoliv jen bezhlavý počet těl.  
Late game = méně těl, tvrdší elity s aetherickým štítem nebo jedem, přesně mířené hazardy a duel s bossem v aréně.

Power fantasy: v minutě 15 **aktivně prorážíš** hordou díky synergii dovedností a augmentací.

---

## 2. Co krademe a co necháváme

**Z Vampire Survivors bereme:**
- 15-20 min run, okamžitý nástup akce.
- Draft 1 ze 3 karet při každém postupu na nový level.
- Čitelný pixel art a syté vizuální telegrafy.
- Rychlý pocit snowballingu a alchymického růstu.

**Z Vampire Survivors necháváme:**
- Full auto střelbu do všech stran bez míření.
- Obrazovku mažící evoluce.
- Nekonečné prázdné louky bez překážek.

**Z Risk of Rain 2 bereme:**
- Časový koeficient obtížnosti.
- Monster Director s rozpočtem kreditů.
- Elitní afixy (Noxious, Shielder).
- Teleporter event (Transmutation Circle).
- Pohyb a dash jako primární nástroj přežití.
- Výrazné tradeoffs na silných itemech.

**Z Risk of Rain 2 necháváme:**
- 3D prostorovou navigaci.
- 100+ položkový item pool.
- Roster 20 postav a nutnost kooperace (v1 singleplayer).

---

## 3. Šest designových zákonů (Anti-Idle)

Žádný herní prvek se nesmí dostat do hry, pokud porušuje tyto body:

1. **Stání se trestá.**  
   LIVE: Astral Watcher laser (1.5 s zamčený telegraph, hitscan), Noxious contact slow + exploze mrtvoly + 6 s louže kyseliny, Shielder regenerace štítu po 5 s klidu, útoky bossů (meteority s lávou, Rime Prison root, Absolute Zero Pulse, Aether Laser).
2. **Aspoň jeden hráčský verb každých ~2 s.**  
   Primary útok je **player-aimed**. Auto-fire a auto-aim na primární zbrani jsou zakázané.
3. **Teleporter / Transmutation Circle.**  
   Kruh se nabíjí jen uvnitř poloměru. Nepřátelé se stahují do kruhu. AFK mimo kruh hru neposouvá.
4. **Kvalita nad kvantitou.**  
   Soft cap: 24 fodder + 6 elit + 1 boss. Během duelu Director zastaví kredity. Boss si líhne vlastní miniony.
5. **Itemy staví build a mají jasnou roli.**  
   Common a Uncommon jsou čistě pozitivní. Rare a Lunar mají tradeoff. Crit je LIVE (základ 5 % / ×2).
6. **Překážky jsou tlak, ne pasivní kryt.**  
   Pilíře lámou edge-kiting a pohlcují střely. Bossové do nich narážejí. Hazardy dávají slow a DPS. Volatiles detonují po mířeném zásahu hráče a 0.4 s telegraphu.

---

## 4. Combat verb (zamčeno)

**Locked A:** Hráč míří primární zbraní myší.

| Vstup | Akce | Chování |
|---|---|---|
| **WASD** | Pohyb | 8-směrný normalizovaný pohyb schránky |
| **Myš** | Míření | Schránka se otáčí a míří na herní kurzor |
| **Držet LMB** | Primary útok | Kontinuální střelba mířená na kurzor |
| **RMB** | Secondary skill | Mířený sekundární úder / paprsek / zóna |
| **Shift / Space** | Utility dash | Úhybný dash s plnými i-framy ve směru pohybu (stání: směr aim) |
| **Q** | Special / Ult | Mířený devastující zásah s delším cooldownem |
| **F** | Seal the Working | Po Frost Emperorovi uzavře Velké dílo |
| **Esc / P** | Pause | Otevře hermetické menu s inventářem a Archívem |

Primary **nikdy** nemíří samo. Primary **nikdy** nestřílí bez stisknutého tlačítka.  
Během dashe hráč **není** tělesně separován, takže dokáže proříznout obklíčení. I-framy ignorují contact damage, nepřátelské střely i exploze.

One-shot ochrana: pokud má hráč ≥ 90 % max HP a zásah by ho srazil pod 1 HP, zbude 1 HP a 0.25 s i-framů.

---

## 5. Struktura běhu

Hra se skládá ze **3 komor** Velkého díla. Po Frost Emperorovi se otevírá zlatá brána Ouroboros.

1. **Cinder Yard** - *Nigredo & Calcination* (vnější hutě a pece).
2. **Rime Dock** - *Albedo & Fixation* (podzemní mrazivé doky).
3. **Glacial Tomb** - *Rubedo & The Great Seal* (krypta věčného ledu).

### Průběh jedné stage

1. **Drop do arény.** Aréna 2560×2560 px. Kolem hráče: **14 pilířů, 8 hazardů, 9 volatilních nádob**. HUD: *The Seal Manifests*.
2. **Kiting a sběr esence.** Likvidace drobotiny, Mercury Drops, postupy na level.
3. **Příchod elit.** Po `firstEliteAt` Director spawnuje wardeny. Každá elita dostane **jeden** afix: Shielder nebo Noxious (50/50). Před zjevením kruhu žije nanejvýš 1 elita.
4. **Manifestace Transmutačního kruhu.** Souřadnice jsou rezervované už při startu stage, takže uvnitř kruhu neleží pilíře ani hazardy.
5. **Channeling (Hold).** Hráč stojí v kruhu a nabíjí jej. Mimo kruh se nabíjení zastaví. Swarm a elity se stahují dovnitř. HUD: *Channel the Transmutation Circle*. Chevron ukazuje na zónu mimo obrazovku.
6. **Boss duel.** Po 100 % charge se kruh uzavře a probudí se Strážce. Director **zastaví credit spawny**. Žijící fodder dokape přirozeně. HUD: *Slay the [Boss]*.
7. **Rift.** Po skolenení bosse se otevře portál (r=70, hold 1.4 s). Hráč se doplní na 100 % HP. Překážky, nepřátelé, gems, lore, projectiles a boss hazardy se vymažou. Nová stage vygeneruje biomové překážky.
8. **Ouroboros nebo pečeť.** Po Frost Emperorovi je brána zlatá (*Descend the Ouroboros*). Hold spustí **Cycle II**: Cinder Yard znovu, inventář / XP / `runTime` zůstávají, `stageGen` pokračuje, koeficient dál stoupá s časem. **F** nebo pauza → *Seal the Working* = **Transmutation Complete**. Nedosebrané lore fragmenty se při pečeti i při cyklu posbírají automaticky.

HP na 0 = **Vessel Shattered**. Opuštění z pauzy = **Vessel Dissolved**.

### Slice clocks (LIVE)

| Fáze | Cinder Yard | Rime Dock | Glacial Tomb |
|---|---|---|---|
| První elita | 25 s | 18 s | 14 s |
| Kruh se objeví | 55 s | 50 s | 50 s |
| Délka nabíjení | 20 s | 22 s | 25 s |
| Poloměr kruhu | 160 px | 150 px | 140 px |
| Boss | Cinder Heart | Frost Sovereign | Frost Emperor (Ouroboros) |

Produkční cíl (TARGET): ~6 min na komoru, kruh ~minuta 4, hold ~60 s.

### Daily Rite

Přepínač v The Hall. Zapnuto: `runSeed = hash('daily:' + UTC YYYY-MM-DD)`. Stejný den = stejný layout překážek, pozice kruhu a pořadí level-up karet. Director a combat RNG **není** seedovaný. Vypnuto: náhodný seed, vytiskne se na recapu.

---

## 6. Shell a uživatelské rozhraní

Rozhraní je Godot Control overlay nad SubViewport arény. Hráčské texty jdou přes `tr()` a `locale/en.csv`.

- **Main menu:** Titul **Hermetic Rifts**. *The Archives*, *Alchemist's Desk*, *Commence Transmutation* (Enter) otevře The Hall.
- **The Hall:** Lobby schránek. Levý sloupec: portréty (zamčená schránka tiskne **??? · SEALED**). Střed: 32px náhled. Pravý sloupec: dossier (titul, lore, 4 skilly). Nad CTA přepínač **Daily Rite**. CTA: *Commence Working* (Enter), nebo *Vessel Sealed*.
- **The Archives:** Plnoobrazovkový kodex z menu i pauzy. Pět svazků:
  - **I. Rites of Motion:** ovládání a 3 beaty Distillation / Convergence / Guardian.
  - **II. Chronicles:** Great Work / Vessels & Arts / Three Chambers.
  - **III. Bestiary:** 10 entit.
  - **IV. Reliquary:** 13 itemů, filtry rarit, unlocky.
  - **V. Ledger:** `user://records.v1.json`, osobní rekordy, posledních 10 běhů, dvoukrokové Purge Ledger. Neviděné názvy tisknou **???**.
- **Level-up:** Pozastaví sim. 3 tarotové tablety (rarity lemy), klávesy 1-3. Zamčené itemy v nabídce nejsou. Prázdný unlocked pool spadne na všechny itemy.
- **Pause:** Esc nebo P. *Simulation Paused* · Resume Sequence · The Archives · Settings · Abandon Vessel. Po Frost Emperorovi navíc *Seal the Working*. Inventář 32px chipy se stack countem. Nested dialogy (settings, archives, confirm) se odchází nejdřív.
- **Alchemist's Desk:** Display Mode (Windowed / Borderless / Exclusive), Monitor, Resolution, VSync, Frame Rate Limit, Master / SFX / Music, Mute, Screenshake, Reduce Effects. Persistuje `user://settings.v1.json`. Změna mode/monitor/resolution chce 15 s potvrzení.
- **HUD:** Horní střed zlatá plaketa cíle (Wait / Hold / Boss / Rift / Ouroboros). Horní vpravo hodiny, komora, Cycle, posuvník Dormant → Cataclysm. Dolní vlevo baňka HP + XP linka + Lv. Dolní střed 4 skilly s radiálním CD. Dolní vpravo mřížka 32×32 augmentací.
- **Recap:** Vessel Shattered / Transmutation Complete / Vessel Dissolved. Čas, level, koeficient, kills, bossové, damage, essence, Cycle, inventory, Discoveries & Archives. Copy Summary [C] dumpne pasteable řádek se Seed / Daily Rite. Run Again [Enter], Return to Hall [Esc].

Zaměřovač Homunculus: rtuťové závorky. The Penitent: liturgický kruh. Během unpaused runu je OS kurzor skrytý.

---

## 7. Schránky (Vessels)

### Homunculus (`runner`) - Skirmisher

- **Titul:** The Runner
- **Lore:** *Clay and quicksilver, stolen from a failed Great Work. You kite the dross until the seal holds.*
- **Základ:** Speed 280, Max HP 100, radius 14.
- **Styl:** Rychlý pohyb po obvodu, precizní střelba, prořezávání chumlu.

**Dovednosti:**
- **Ignis Bolt** (`bolt`) - Hold LMB, CD 0.28 s. Šíp speed 780, life 0.85 s, dmg 10. Zaniká při prvním nárazu.
- **Piercing Aether** (`skill-aether-pierce`) - Press RMB, CD 4.0 s. Pierce paprsek speed 1400, dmg 22, self-slow ×0.5 na 0.25 s.
- **Phase Step** (`dash`) - Press Shift/Space, CD 2.9 s. 210 px za 0.16 s, iframe 0.22 s.
- **Crucible Cull** (`skill-crucible-cull`) - Press Q, CD 12.0 s. Telegraph 0.7 s, r=45, dmg 95 na kurzor.

### The Penitent (`penitent`) - Caster / Controller

- **Titul:** The Caster
- **Lore:** *A monk who walked into the kiln and did not burn. He draws circles the horde must not cross.*
- **Odemčení:** Porazit Frost Sovereigna v Rime Docku.
- **Základ:** Speed 245, Max HP 135, radius 14.
- **Styl:** Zónování, lákání drobotiny, spoutávání elit a bossů.

**Dovednosti:**
- **Censer Lob** (`skill-censer-lob`) - Hold LMB, CD 0.42 s. Oblouk speed 420, life 1.1 s, dmg 14, `flyOver`, impact r=30.
- **Brimstone Line** (`skill-brimstone-line`) - Press RMB, CD 5.0 s. Šev 150×18, 2.4 s, slow fodder na 20 %, 2 DPS. Elity a bossové linku ignorují.
- **Ash Step** (`dash-ash-step`) - Press Shift/Space, CD 3.0 s. Dash 210 px, iframe 0.22 s, decoy 1.5 s. Fodder se vrhá na figurínu, elity ji ignorují.
- **Condemnation Tether** (`skill-condemn-tether`) - Press Q, CD 15.0 s. Řetěz speed 640, life 0.7 s. Fodder na dráze bere 45 dmg. První elita/boss: root 2.5 s, fodder na řetězu 28 DPS. Minutí cooldown vyplýtvá.

Žádná schránka nezačíná s itemy. Síla jen z level-up tablet.

---

## 8. XP a level-up

- Padlý nepřítel pouští Mercury Drop (nebo přímé XP).
- Fodder 3-6 XP podle entity. Elita = base XP × 2.5. Boss 50 / 75 / 120.
- Vzorec: `round(32 * 1.30^(level-1))`. Level 1 = 32 XP (~11 Ember Mites).
- Pickup 36 px, magnet od 88 px rychlostí 320 px/s.
- 3 karty vážené rarity: common 1.00, uncommon 0.55, rare 0.22, lunar 0.08.
- Zamčené augmentace z nabídky vypadnou. Duplikát `stack: none` by z nabídky vypadl; LIVE itemy mají `linear`, takže se stackují.

---

## 9. Augmentace

Staty, které itemy hýbou: `speed`, `maxHp`, `radius`, `damage`, `cooldown`, `critChance`, `critDamage`, `armor`, `hazardResist`, `hpRegen`, `pickupRadius`, `xpGain`, `aoeRadius`, `projSpeed`, `controlDuration`, `eliteDamage`. Plus `on-kill` heal a `on-crit` CD refund.

Filozofie: Common a Uncommon čistě pozitivní. Rare a Lunar s rizikem.

| Display | id | Rarity | Hook | Unlock |
|---|---|---|---|---|
| Cloven Sinew | `goat-hoof` | common | +15 % speed | - |
| Slag Carapace | `brittle-plate` | common | +12 % armor | - |
| Waxen Pinions | `wax-wings` | common | +35 % hazard ward | - |
| Lead Plumbum | `lead-core` | common | +25 max HP | - |
| Salt Effigy | `salt-ward` | common | −12 % hurtbox | Clear Cinder Yard |
| Cinnabar Leech | `cinnabar-leech` | common | +0.3 HP za kill | Slay 100 Dross |
| Spasmodic Nerve | `hair-trigger` | uncommon | −15 % cooldown | - |
| Bellows Heart | `overclock` | uncommon | +22 % AoE, +20 % proj speed | Slay Cinder Heart |
| Quicksilver Draught | `mercury-vial` | uncommon | +35 % magnet, +15 % XP | - |
| Vitriol Veins | `glass-cannon` | rare | +55 % dmg, −25 % max HP | - |
| Parasitic Alembic | `hungry-clip` | rare | +1 HP/s, +35 % rite duration, +25 % hurtbox | Slay 10 elites |
| Astrologer's Ocular | `calcined-lens` | rare | +25 % crit chance, −0.25 s CD on crit, −15 % speed | Slay 300 Dross |
| Pale Moon Covenant | `lunar-tithe` | lunar | +60 % elite/boss dmg, +75 % crit dmg, −25 % armor, −25 % XP | Clear Rime Dock |

Při změně max HP se aktuální HP posune o rozdíl max (min 1).

---

## 10. Monster Director

Koeficient: `1 + runTime * 0.0026` (`stageBonus` 0).  
Příjem kreditů: `3.0 * coefficient` za sekundu.  
Ceny: fodder 6, elite base 18 × `eliteCostMul` 3 = 54, sniper 18.  
Intervaly: fodder 1.6 s, elite 14 s, sniper 9 s (max 3).  
Spawn prstenec 460-900 px, nikdy blíž než 460. Pack 3-6 fodder, elita pack 1.  
~22 % fodder spawnů je ranged (Glacial Tomb 0.28).  
Šance mutace na elitu: `0.02 + (coeff−1)*0.12`, cap 0.40.  
Před kruhem max 1 elita, během Hold až 6.  
Boss freeze: Director neutrácí, dokud je boss naživu nebo po jeho smrti až do další stage.

---

## 11. Elity a bossové

### Elity

Každá elita má **jeden** afix (50/50):

- **Noxious:** Contact slow ×0.5 na 1.1 s. Po smrti 0.5 s corpse, pop r=40 dmg `8 * coeff`, louže 6 s (hazard r=68, 4 DPS, player speed ×0.65).
- **Shielder:** Štít 30 % max HP. Po 5 s bez zásahu se plně obnoví.

Vizuál: Shielder azurový outline, Noxious viridiánový pulz.

### Bossové

Bossové kolidují s pilíři. Enrage při 50 % HP. Vlastní minioni, ne Director.

1. **Cinder Heart** (HP 1650): Slag Spray fan, Falling Clinker meteor + láva, Kiln Brood (`ember-mite` ×3, max 6). Enrage CD ×0.75.
2. **Frost Sovereign** (HP 2100): Cryo Lance, Glacial Sweep kužel slow 0.22, Rime Prison root 1.6 s, Rime Brood. Enrage CD ×0.75.
3. **Frost Emperor** (HP 2800): Glacial Spear, Absolute Zero Pulse r=620, Aether Laser + trail louže, Imperial Guard, Brine Retinue. Enrage CD ×0.72.

---

## 12. Překážky

Aréna 2560×2560: 14+8+9 pevných + až 8 dynamických louží.

- **Pilíře r=28:** Solid vs hráč, fodder, elity **i bossové**. Blokují Bolt, spitter bolts, Astral Watcher laser i Aether Laser.
- **Hazardy r=68:** Bez kolize střel. Hráč ×0.65 speed a `4 * coeff` DPS. Dash / i-frame = čistý průchod. Fodder/elity ×0.85 speed. Noxious smrt spawne 6 s louži tohoto typu.
- **Volatiles r=14:** HP `25 * coeff`, damage jen hráčské skilly. Prime 0.4 s, exploze r=110, `45 * coeff` enemy, 18 flat hráči bez i-framů. Rime Dock navíc 2.0 s ×0.7 slow.

Keep-out při place: ≥160 od stěn, ≥200 od spawnu hráče, pilíř/hazard ≥230 od kruhu, volatile ≥200 od kruhu, ≥190 mezi sebou.
