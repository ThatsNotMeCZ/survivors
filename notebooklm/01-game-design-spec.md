# survivors — Game Design Spec (gameplay)

Snapshot: **2026-11-05**. Čísla v tabulkách musí přesně sedět s `02-catalog-numbers.md`.

Working title: **survivors**. Hall title: **Hermetic Rifts**.  
Žánr: 2D survivor-like. Hybrid **Vampire Survivors pacing** + **Risk of Rain 2 pressure**.  
Jeden run (target): **15–20 minut**. Hráč hraje aktivně rukama, nesleduje build, jak vyhrává za něj.

Player-facing téma: **Dark Hermetic**. V rozhraní se používají hermetické názvy, nikoliv interní ID.  
Hráč ovládá alchemickou schránku (Vessel — Homunculus nebo The Penitent), která spaluje a čistí nečistoty (Dross / Failed Transmutations). XP = Mercury Drops / Essence, zóna přežití = Transmutation Circle, přechod mezi komorami = Rift.

---

## 1. Pitch

Nejsi v pasivním orbitálu, který bezmyšlenkovitě čistí obrazovku. **Pohybuješ se skrz hordu, která časem zhrubne, zrychlí a získá nebezpečnější schopnosti, nikoliv jen bezhlavý počet těl.**  
Late game = méně těl, tvrdší elity s aetherickými štíty a jedem, přesně mířené hazardy a epický souboj s bossem v aréně.

Power fantasy zůstává: v minutě 15 **aktivně prorážíš** hordou díky synergii svých dovedností a augmentací. Nesedíš v koutě a nesleduješ AFK generátor čísel.

---

## 2. Co krademe / co necháváme

**Z Vampire Survivors bereme:**
- 15–20 min run, okamžitý nástup akce.
- Draft 1 ze 3 karet při každém postupu na nový level.
- Čitelný pixel art a syté vizuální telegrafy.
- Rychlý pocit snowballingu a alchymického růstu.

**Z Vampire Survivors necháváme:**
- Full auto střelbu do všech stran bez míření.
- Obrazovku mažící evoluce, které smažou celou herní plochu.
- Nekonečné prázdné louky bez překážek a struktury.

**Z Risk of Rain 2 bereme:**
- Časový koeficient obtížnosti (Difficulty Coefficient), který neúprosně stoupá.
- Monster Director pracující s rozpočtem kreditů.
- Elitní nepřátele s brutálními modifikátory (Noxious jed, Shielder štít).
- Teleporter event (Transmutation Circle) vyžadující obranu pevného bodu.
- Pohyb a dash jako primární nástroj přežití.
- Výrazné tradeoffs na silných itemech.

**Z Risk of Rain 2 necháváme:**
- 3D prostorovou navigaci a bloudění.
- 100+ položkový nepřehledný item pool.
- Roster 20 postav a nutnost kooperace (ve v1 čistý singleplayer).

---

## 3. Šest designových zákonů (Anti-Idle)

Žádný herní prvek se nesmí dostat do hry, pokud porušuje tyto body:

1. **Stání se trestá.**  
   LIVE: Astral Watcher laser (1.5 s zamčený telegraph, okamžitý hitscan), Noxious contact slow + exploze mrtvoly + trvalá louže kyseliny, Shielder regenerace štítu při nečinnosti, útoky bossů (meteority s lávou, rime prison root, absolute zero pulse přes celou arénu, stopovací aether laser).
2. **Aspoň jeden hráčský verb každých ~2 s.**  
   Primary útok je **player-aimed** (mířený myší). Auto-fire a auto-aim na primární zbrani jsou zakázané.
3. **Teleporter / Transmutation Circle.**  
   Na ploše arény se aktivuje kruh. Nabíjí se pouze tehdy, když hráč stojí uvnitř jeho poloměru. Nepřátelé se stahují přímo do kruhu. AFK pobyt mimo kruh hru neposouvá.
4. **Kvalita nad kvantitou.**  
   Soft cap živých nepřátel je ~80–120 (v slice 32 fodder + 3 elity + 1 boss). Během duelu s bossem Director **zastaví generování kreditů**, takže se souboj nezvrhne v nekonečný spam drobotiny; boss si sám vyvolává své přisluhovače.
5. **Itemy staví build a mají jasnou roli.**  
   Common a Uncommon augmentace jsou čistě pozitivní stavební kameny. Rare a Lunar augmentace jsou drsné dvousečné meče s výrazným rizikem. Zaveden byl systém kritických zásahů (`critChance`, `critDamage`). Žádný item nesmí zajistit automatickou výhru bez hraní.
6. **Překážky jsou tlak, ne pasivní kryt.**  
   Pilíře lámou edge-kiting a pohlcují střely, ale bossové jimi procházejí. Hazardy udělují slow a DPS. Volatiles detonují pouze po mířeném zásahu hráče a 0.4 s telegraphu. Kyselina z elit zmenšuje prostor v kruhu.

---

## 4. Combat verb (zamčeno)

**Locked A:** Hráč míří primární zbraní myší.

| Vstup | Akce | Chování |
|---|---|---|
| **WASD** | Pohyb | 8-směrný normalizovaný pohyb schránky |
| **Myš** | Míření | Schránka se otáčí a míří na herní kurzor |
| **Držet LMB** | Primary útok | Kontinuální střelba mířená na kurzor |
| **RMB** | Secondary skill | Mířený sekundární úder / paprsek / zóna |
| **Shift / Space** | Utility dash | Úhybný dash s plnými i-framy ve směru pohybu |
| **Q** | Special / Ult | Mířený devastující zásah s delším cooldownem |
| **Esc** | Pause | Otevře hermetické menu s přehledem augmentací a archivu |

Primary **nikdy** nemíří samo. Primary **nikdy** nestřílí bez stisknutého tlačítka.  
Během dashe hráč **není** tělesně separován, takže dokáže proříznout obklíčení. Během i-framů hráč ignoruje jak contact damage potvor, tak letící nepřátelské střely i exploze.

---

## 5. Struktura běhu (Run Structure)

Hra se skládá ze **3 komor (stages)** Velkého díla (The Great Work):
1. **Stage 1: Cinder Yard** — *Nigredo & Calcination* (vnější hutě a pece, žár a popel).
2. **Stage 2: Rime Dock** — *Albedo & Fixation* (podzemní mrazivé doky, solné krystaly a rtuť).
3. **Stage 3: Glacial Tomb** — *Rubedo & The Great Seal* (nejhlubší krypta věčného ledu, finální pečeť).

### Průběh jedné stage:
1. **Drop do arény:** Hráč začíná v aréně 2560×2560 px. Kolem něj je vygenerováno **14 pilířů, 8 hazardů a 9 volatilních nádob**. HUD hlásí: `Seal manifests in M:SS`.
2. **Kiting a sběr esence:** Likvidace drobotiny (Mites, Spitters), sběr Mercury Drops, postupy na level.
3. **Příchod elit:** Director v daném čase spawne první elitu s Noxious jedem a Shielder štítem.
4. **Manifestace Transmutačního kruhu:** V předem daném čase se v aréně rozsvítí Transmutation Circle. Souřadnice jsou vyhrazeny již při startu stage, takže se uvnitř kruhu nenachází pilíře ani hazardy.
5. **Channeling kruhu (Hold):** Hráč stojí v kruhu a nabíjí jej na 100 %. Mimo kruh se nabíjení pozastaví. Swarm a elity se stahují dovnitř.
6. **Boss Duel:** Po dokončení channelingu se kruh uzavře a v aréně se probudí Strážce komory (Boss). V té chvíli Director **zastaví credit spawny**, aby aréna patřila epickému duelu. Boss používá unikátní telegraphované útoky, fázuje skrz sloupy, při 50 % HP vstoupí do enrage a vyvolává vlastní miniony.
7. **Rift (Trhlina):** Po skolenení bosse se otevře Rift. Vstup a podržení pozice na 1.4 s přenese hráče do další komory. Všechny předchozí překážky a louže se vymažou, životy hráče se doplní na 100 % a nová stage vygeneruje čerstvé překážky daného biomu.
8. **Vítězství (Transmutation Complete):** Porážka třetího bosse (Frost Emperor) v Glacial Tomb završuje Velké dílo — nastává triumf a závěrečný souhrn běhu.

### Časové osy komor (Slice Clocks):

| Fáze | Stage 1: Cinder Yard | Stage 2: Rime Dock | Stage 3: Glacial Tomb |
|---|---|---|---|
| **První elita** | 15 s | 12 s | 10 s |
| **Kruh se objeví** | 55 s | 50 s | 50 s |
| **Délka nabíjení kruhu** | 20 s | 22 s | 25 s |
| **Poloměr kruhu** | 160 px | 150 px | 140 px |
| **Boss arény** | Cinder Heart | Frost Sovereign | Frost Emperor (Konec hry) |

---

## 6. Shell a uživatelské rozhraní

Veškeré rozhraní je postaveno v HTML/CSS (`src/ui/`) přes canvas rendereru.

- **Hlavní sál (The Hall):** Titul **Hermetic Rifts**. Třísloupcové rozhraní zasazené do aetherického WebGL fragment shaderu (kouř a rotující transmutační sigilie).
  - Levý sloupec: Volba schránky (Vessel Selection), Archiv (The Archives), Alchymistův stůl (Settings).
  - Prostřední sloupec: 32px živý pixel-art náhled schránky s podstavcem.
  - Pravý sloupec: Pergamenový spis schránky (Dossier) s titulem, lore a 4 sloty dovedností včetně podrobných vysvětlivek.
  - Tlačítko **Commence Transmutation** (Enter) zahájí rituál.
- **The Archives (`#archives`):** Plnoobrazovkový kodex s 5 svazky:
  - **I. Rites of Motion:** Herní zákony, ovládání, práce s kruhem a překážkami.
  - **II. Chronicles:** Příběh Velkého díla, popisy schránek a tří komor.
  - **III. Bestiary:** Všech 10 entit s animovaným pixel-art náhledem, kompletními statistikami, popisem AI, lore a počtem střetnutí/zabití.
  - **IV. Reliquary:** Všech 13 augmentací s filtry rarit, hooky, stohováním, lore a počtem voleb.
  - **V. Ledger:** Trvalá statistika uložená v `localStorage` (`survivors.records.v1`), osobní rekordy, historie posledních běhů a bezpečné pročištění archivu.
- **Odemykání obsahu (Progression):**
  - Schránka *The Penitent* je uzamčena, dokud hráč neskolí Frost Sovereigna v Rime Docku.
  - Šest vybraných augmentací se odemyká herními činy (porážka bossů, zabíjení drossu, dokončení komor). Zamčené augmentace se v nabídce level-upu neobjeví.
- **Výběr augmentace (Level-up):** Pozastaví simulační smyčku. Zobrazí 3 hermetické karty (styl tarotových desek s raritními lemy, ikonami a detailním popisem hooků i lore). Klávesy 1–3 nebo kliknutí provedou volbu.
- **HUD během hry:**
  - Horní střed: Plaketa aktuálního cíle s procentuálním ukazatelem (Wait / Hold / Boss / Rift).
  - Horní vpravo: Hodiny běhu a název komory.
  - Dolní vlevo: Skleněná alchymistická baňka s tekutinou života (HP) + číselný údaj, tenká rtuťová linka zkušeností (XP) a úroveň.
  - Dolní střed: 4 sloty skillů s radiálním odpočtem cooldownu a zábleskem i-framů.
  - Dolní vpravo: Kompaktní mřížka 32×32 px sebraných augmentací s počtem stacků (sloupce se dynamicky přizpůsobují, aby nezakrývaly hrací plochu).

---

## 7. Schránky (Vessels)

### 1. Homunculus (`runner`) — Skirmisher
- **Titul:** The Runner
- **Lore:** *Clay and quicksilver, stolen from a failed Great Work. You kite the dross until the seal holds.*
- **Základní statistiky:** Rychlost 280, Max HP 100, Hurtbox poloměr 14 px.
- **Zaměřovač:** Rtuťové přesné závorky (`runner`).
- **Styl boje:** Rychlý pohyb po obvodu, precizní střelba, prořezávání chumlu fázovým krokem.

**Dovednosti:**
- **Primary:** `Ignis Bolt` (`bolt`) — Hold LMB, CD 0.28 s. Rychlý plamenný šíp (speed 780, lifetime 0.85 s, damage 10). Zaniká při prvním nárazu.
- **Secondary:** `Piercing Aether` (`skill-aether-pierce`) — Press RMB, CD 4.0 s. Paprsek ukradeného nebe (speed 1400, damage 22), který propálí všechny nepřátele v přímce, za cenu krátkého zpomalení kroku (50 % slow na 0.25 s).
- **Utility:** `Phase Step` (`dash`) — Press Shift/Space, CD 0.9 s. Rychlý posun o 210 px trvající 0.16 s s 0.22 s nezranitelností (i-frames).
- **Special:** `Crucible Cull` (`skill-crucible-cull`) — Press Q, CD 12.0 s. Alchymistický úder z nebes na pozici kurzoru. Po 0.7 s telegraphu dopadne úder o poloměru 45 px s drtivým poškozením 95.

### 2. The Penitent (`penitent`) — Caster / Controller
- **Titul:** The Caster
- **Lore:** *A monk who walked into the kiln and did not burn. He draws circles the horde must not cross.*
- **Odemčení:** Porazit Frost Sovereigna v Rime Docku.
- **Základní statistiky:** Rychlost 245, Max HP 135, Hurtbox poloměr 14 px.
- **Zaměřovač:** Liturgický vysvěcený kruh (`penitent`).
- **Styl boje:** Zónování arény, lákání drobotiny do pastí, spoutávání nebezpečných elit a bossů.

**Dovednosti:**
- **Primary:** `Censer Lob` (`skill-censer-lob`) — Hold LMB, CD 0.42 s. Vrh těžké kadidelnice obloukem (speed 420, lifetime 1.1 s, damage 14). Létá nad hlavami nepřátel (`flyOver`) a roztříští se až u kurzoru s plošným výbuchem o poloměru 30 px.
- **Secondary:** `Brimstone Line` (`skill-brimstone-line`) — Press RMB, CD 5.0 s. Vytvoří před sebou sírový šev (150×18 px) trvající 2.4 s. Zpomalí drobotinu na 20 % rychlosti a uděluje 2 DPS. Elity a bossové linku ignorují.
- **Utility:** `Ash Step` (`dash-ash-step`) — Press Shift/Space, CD 1.1 s. Dash o 210 px s i-framy (0.22 s), který na původním místě zanechá popelovou figurínu (decoy) na 1.5 s. Drobotina se vrhá na figurínu, elity ji ignorují.
- **Special:** `Condemnation Tether` (`skill-condemn-tether`) — Press Q, CD 15.0 s. Vrhne těžký řetěz (speed 640, lifetime 0.7 s). První zasažená elita nebo boss je znehybněna (root) na 2.5 s a veškerá drobotina dotýkající se spoutaného cíle je pálena za 18 DPS. Minutí nebo zásah řadového nepřítele cooldown vyplýtvá.

---

## 8. Systém zkušeností a růst (XP & Level-up)

- Každý padlý nepřítel upustí rtuťovou kapku esence (**Mercury Drop**).
- Hodnoty esence: Drobotina 3–5 XP, Elity 14–18 XP, Bossové 50–120 XP.
- Vzorec pro potřebné XP: `round(32 * 1.30^(level - 1))`. První level vyžaduje 32 XP (~8–11 potvor).
- Magnet na kapky: základní dosah sebrání 36 px, magnetické pole od 88 px (přitahuje rychlostí 320 px/s).
- Postup na nový level okamžitě pozastaví simulaci a předloží **3 karty augmentací** vážené podle rarit:
  - Common: váha 1.00
  - Uncommon: váha 0.55
  - Rare: váha 0.22
  - Lunar: váha 0.08
- Zamčené augmentace jsou z nabídky vyřazeny, dokud nejsou splněny jejich podmínky v archivu.

---

## 9. Augmentace (Itemy & Staty)

Systém statistik podporuje:
- `speed` — rychlost pohybu schránky
- `maxHp` — maximální životy (při změně se aktuální HP posouvá úměrně)
- `radius` — velikost kolizního hurtboxu hráče (menší = lépe kličkuje)
- `damage` — multiplikátor síly útoků
- `cooldown` — zkrácení doby nabíjení schopností
- `critChance` — šance na kritický úder
- `critDamage` — bonusové poškození při kritickém zásahu
- `on-kill` — přímé léčení za každého zabitého nepřítele

### Filozofie vyvážení:
- **Common & Uncommon:** Čistě pozitivní esence, základ každého funkčního buildu.
- **Rare & Lunar:** Extrémní síla vykoupená citelnou slabinou.

### Seznam 13 augmentací:

1. **Cloven Sinew** (`goat-hoof`, Common): +14% speed. *Rychlost kroků po spáleništi.*
2. **Slag Carapace** (`brittle-plate`, Common): +25% max HP. *Pláty strusky chránící jádro.*
3. **Waxen Pinions** (`wax-wings`, Common): +12% speed. *Křídla z loje odlehčující schránku.*
4. **Lead Plumbum** (`lead-core`, Common): +25 max HP (add). *Olověné závaží kotvící životní sílu.*
5. **Salt Effigy** (`salt-ward`, Common): −12% hurtbox radius. *Vysušená silueta, která proklouzne mezi střelami.* (Unlock: Dokončit Cinder Yard).
6. **Cinnabar Leech** (`cinnabar-leech`, Common): +0.25 HP za každé zabití. *Pijavice sající zbytky esence.* (Unlock: Zabít 100 nepřátel).
7. **Spasmodic Nerve** (`hair-trigger`, Uncommon): −15% cooldown. *Zrychlené alchymistické reflexy.*
8. **Bellows Heart** (`overclock`, Uncommon): +16% damage, +35% crit damage. *Alchymistické dmychadlo rozdmýchávající plamen.* (Unlock: Porazit Cinder Heart).
9. **Quicksilver Draught** (`mercury-vial`, Uncommon): −12% cooldown, +6% speed. *Zředěná rtuť v tepnách schránky.*
10. **Vitriol Veins** (`glass-cannon`, Rare): +60% damage, −25% max HP. *Kyselina leptající nepřátele i vlastní schránku.*
11. **Parasitic Alembic** (`hungry-clip`, Rare): −30% cooldown, +25% hurtbox radius. *Dravá destilace zrychlující kouzla, která však nafukuje siluetu.* (Unlock: Zabít 10 Noxious elit).
12. **Astrologer's Ocular** (`calcined-lens`, Rare): +30% crit chance, +50% crit damage, −18% speed. *Hvězdářský okulár odhalující pukliny v tělech za cenu pomalého kroku.* (Unlock: Zabít 300 nepřátel).
13. **Pale Moon Covenant** (`lunar-tithe`, Lunar): +75% damage, +50% crit damage, −40% max HP, +20% hurtbox radius. *Kacířská smlouva s bledým měsícem nabízející nesmírnou ničivost za cenu křehké a zranitelné skořápky.* (Unlock: Dokončit Rime Dock).

---

## 10. Monster Director a eskalace

Obtížnost se neřídí tupým násobením počtu monster na obrazovce. Řídí ji **Monster Director**:
- Obtížnostní koeficient: `1 + runTime * 0.006 + stageIndex * 0.35`.
- Příjem kreditů: `3.6 * coefficient` za sekundu.
- Nákupní ceny: Drobotina 7 kreditů (interval 0.5 s), Elita 42 kreditů (interval 14.0 s), Sniper 30 kreditů (interval 7.0 s).
- Bezpečná zóna spawnu: Nepřátelé se rodí v prstenci 460–900 px od hráče, nikdy blíž než 460 px.
- **Boss Duel Freeze:** V momentě probuzení bosse Director přestane utrácet kredity.

---

## 11. Elity a Boss Souboje

### Elitní nepřátelé
Každá elita v aréně disponuje dvěma modifikátory:
- **Noxious:** Při dotyku zpomalí hráče na 50 % rychlosti (1.1 s). Po smrti se 0.5 s chvěje, vybuchne (r=40 px, damage `8 * coeff`) a zanechá trvalou louži kyseliny (r=68 px, 4 DPS, slow ×0.65) trvající až do konce stage.
- **Shielder:** Spawne se s aetherickým štítem o hodnotě +30 % max HP. Pokud není 5 sekund zasažena, štít se plně zregeneruje.

### Souboje s Bossovskými Strážci
Bossové se chovají jako inteligentní arénoví protivníci:
- Fázují skrz pilíře (hráč se za nimi nemůže natrvalo schovat).
- Při 50 % HP vstoupí do enrage (cooldowny se zkrátí o ~25 %).
- Vyvolávají vlastní miniony namísto náhodného spawnu directoru.

1. **Cinder Heart (Stage 1):** HP 1650. Útočí pětičlennou vějířovitou salvou lávy (`Slag Spray`), vyvolává padající meteority zanechávající lávové pasti (`Falling Clinker`) a líhne útočné Mity (`Kiln Brood`).
2. **Frost Sovereign (Stage 2):** HP 2100. Pálí rychlá ledová kopí (`Cryo Lance`), metá mrazivý kužel zpomalující krok na 22 % (`Glacial Sweep`), uvězňuje hráče v ledové kleci (`Rime Prison`) a vyvolává mrazivé Mity (`Rime Brood`).
3. **Frost Emperor (Stage 3):** HP 2800. Finální vládce absolutní nuly. Vrhá těžké ledové oštěpy (`Glacial Spear`), vysílá arénový pulz o poloměru 620 px (`Absolute Zero Pulse`), zaměřuje rotující termální laser (`Aether Laser`) zanechávající stopu mrazivých louží a vyvolává imperiální gardu (Mites i Spitters).

---

## 12. Překážky a prostředí

Aréna o rozměrech 2560×2560 px obsahuje 31 pevných překážek + až 8 dynamických louží:
- **Pilíře (Pillars, r=28 px):** Pevné překážky blokující pohyb hráče i nepřátel. Pohlcují běžné střely i smrtící paprsky sniperů.
- **Hazardy (Hazards, r=68 px):** Trhliny a louže zpomalující krok a udělující průběžné poškození. Během úhybného dashe (i-framů) je hráč ignoruje.
- **Volatiles (r=14 px):** Tlakové nádoby reagující pouze na mířené útoky hráče. Po vyčerpání životů a 0.4 s telegraphu explodují v poloměru 110 px a udělí masivní poškození nepřátelům.

Každá komora má své vlastní vizuální a tematické varianty překážek (Obsidian Kiln v pecích, Frozen Bollard v docích, Glacial Monolith v hrobce).
