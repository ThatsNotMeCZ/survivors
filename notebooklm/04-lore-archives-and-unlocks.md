# survivors - Lore, Archívy a systém odemykání

Snapshot: **2026-11-17**.  
Příručka světa, narativního designu a meta-systémů. Hráčské texty Chronicles jsou **verbatim** z `Godot/hermetic-rifts/locale/en.csv`.

---

## 1. Svět a téma: Dark Hermetic

Hra **survivors** (veřejně **Hermetic Rifts**) nestojí na generickém fantasy. Svět vychází z **temné renesanční alchymie**, esoterických traktátů a představy **Velkého díla (Magnum Opus)**, které se vymklo kontrole. Komory jsou plné vroucí strusky, zamrzlé rtuti a zkažené hmoty.

Hráč je to, co vyšlo z popela Magisteria. Pilotuje **Vessel** skrz zapečetěné komory nepovedeného díla. Jména si musí zasloužit, jinak Archív tiskne **???**.

### Tři komory Velkého díla

Každá stage odpovídá jedné fázi klasické transmutace:

1. **Cinder Yard (`cinder-yard`) - First Chamber · Nigredo & Calcination**  
   Vnější slévárna a pece. Vulkanická struska, obsidiánové pece, prasklé retorty, žhavá síra. Alchymisté zde shořeli, když se jádro pecí (`cinder-heart`) probudilo.
2. **Rime Dock (`rime-dock`) - Second Chamber · Albedo & Fixation**  
   Podzemní solný kanál. Zmrzlé kůly, ledové krápníky nasycené solí, praskající tlakové sudy. Branku střeží Regent doků (`frost-sovereign`).
3. **Glacial Tomb (`glacial-tomb`) - Final Chamber · Rubedo & The Great Seal**  
   Nejhlubší krypta v absolutní nule pro spoutání Císaře mrazu (`frost-emperor`). Zde se Velké dílo buď zapečetí, nebo se Vessel vrací hadem Ouroboros.

Prop názvy (pilíř / hazard / volatile):

| Komora | Pilíř | Hazard | Volatile |
|---|---|---|---|
| Cinder Yard | Obsidian Kiln | Slag Fissure | Brimstone Urn |
| Rime Dock | Frozen Bollard | Brine Pool | Pressurized Rime Cask |
| Glacial Tomb | Glacial Monolith | Permafrost Crevasse | Volatile Ice Chunk |

Smrt: **Vessel Shattered**. Vítězství: **Transmutation Complete** (*The Great Work Holds*). Opuštění: **Vessel Dissolved**.

---

## 2. Chronicles (verbatim z Archívu, svazek II)

Banner: *Hermetic Chronicles* / **APOCRYPHA OF THE GREAT WORK**  
*Treatises recovered from the outer foundry, the frozen sea-locks, and the sealed glacial vault.*

### I. The Great Work

**FOLIO I · THE SHATTERED CRUCIBLE - When the Magisterium Burned**

> The Great Work was meant to distill immortal quintessence from base lead, sulfur, and sea-salt. Instead, the Grand Crucible cracked at the midnight conjunction, flooding the subterranean vaults with volatile humors.

> The alchemists were consumed in the first flash of calcination. What remained in the ash were the failed transmutations—skittering clots of slag, brine-swollen husks, and the colossal furnace cores that now guard the lower seals.

**FOLIO II · MERCURY - The Circulation of Quicksilver**

> No natural flesh can breathe the fumes of the Rifts. Only constructed or consecrated Vessels—animated by refined quicksilver—can walk the flagstones without dissolving into dross.

> Every fallen abomination releases a bead of stolen Mercury. A Vessel that gathers them grows in potency, binding hermetic tablets into its frame.

**FOLIO III · TRANSMUTATION CIRCLES - Seals of Passage**

> Each chamber is locked by a heavy Transmutation Circle etched into the stone. Only when the chamber’s temporal alignment arrives can a Vessel stand inside the hexagram and channel its own vital heat into the ring.

> The channeling acts as a beacon: the chamber’s hordes converge on the circle, and the Seal Guardian awakens to crush the intruder before the Rift can tear open.

**FOLIO IV · THE THREE OPERATIONS - Nigredo, Albedo, Rubedo**

> The descent follows the three classical stages of hermetic transmutation: first Nigredo in the blackened ash of the Cinder Yard; second Albedo in the white salt-frost of the Rime Dock; and finally Rubedo in the deep Glacial Tomb.

> Slaying the Frost Emperor opens the gold Ouroboros. Seal the working there, or descend again — Cinder Yard, every tablet still bound, the chambers no kinder for the second passage.

### II. Vessels & Arts

Archív tiskne dossier odemčené schránky (titul, lore, 4 skilly). Zamčená schránka: *SEALED VESSEL · UNCONSECRATED FRAME* a *Vessel Sealed - Requirement: {label} ({progress}).*

- **Homunculus (`runner`) - The Runner**  
  *Clay and quicksilver, stolen from a failed Great Work. You kite the dross until the seal holds.*
- **The Penitent (`penitent`) - The Caster**  
  *A monk who walked into the kiln and did not burn. He draws circles the horde must not cross.*  
  Unlock: Slay the Frost Sovereign in the Rime Dock.

### III. The Three Chambers

Navštívená komora odhalí lore z katalogu, denizeny (hunts / spits / lances / warden / guardian) a props. Nenavštívená: *CHAMBER {n} · UNCHARTERED SEAL* a *Uncharted Chamber - Descend through the Rifts to unseal this chamber’s chronicle and survey its hazards.*

Komorové lore z katalogu:

- **Cinder Yard:** *The outer foundry where raw matter was burned to black ash. Obsidian kilns still vent superheated slag, and volatile brimstone urns litter the cracked flagstones.*
- **Rime Dock:** *A subterranean canal where alchemical salts and quicksilver were quenched in freezing brine. Frozen bollards block stray bolts while pressurized rime casks threaten to shatter in a numbing frost.*
- **Glacial Tomb:** *The deepest vault beneath the canal, sealed in eternal permafrost to contain the Frost Emperor. Here the Transmutation Circle demands the longest vigil before the Great Work is decided.*

Návštěva komory se zapisuje podle `stageIndex` (stačí **vejít**, nemusíš ji vyčistit). Backfill řetězí cinder → rime → glacial.

---

## 3. Bestiář (10 entit)

Všechny entity jsou pozůstatky nepovedených transmutací (**Dross**). Neviděná jména = **???**. Lore treatise se odemkne sebráním lore fragmentu (ne pouhým kill).

### Fodder

- **Ember Mite (`ember-mite`) - Scorched Dross.** *Clots of ash and failed calcination that skitter out of cracked retorts. Individually brittle, they swarm any warm vessel to strip its mercury.*
- **Ember Spitter (`ember-spitter`) - Slag Bile Vessel.** *Distended husks engorged on boiling sulfur. They circle the outer kiln perimeter, hurling globules of molten slag whenever a vessel slows its stride.*
- **Frost Mite (`frost-mite`) - Rime-Bitten Husk.** *Shards of alchemical salt and frozen mercury that skitter across the dockside stone. Quicker and harder than kiln mites, they hunt in tight, unforgiving packs.*
- **Frost Spitter (`frost-spitter`) - Brine Condenser.** *Hollowed alembic creatures that siphon freezing brine from the dock fissures and spit high-velocity needles of rime across the chamber.*
- **Astral Watcher (`enemy-astral-sniper`) - Ocular of the Void.** *A disembodied brass-and-aether eye that drifts at the edge of sight. It traces a thin celestial sightline before lancing the arena - only solid pillars can break its gaze.* Habitat: všechny komory.

### Elite hosté (základ elity)

- **Ember Warden (`ember-chaser`) - Furnace Overseer.** *A heavy amalgam of cast-iron ribs and stoked furnace slag built to herd failed transmutations. It charges across the flagstones with crushing momentum.*
- **Frost Warden (`frost-warden`) - Cryo-Bound Sentinel.** *Heavy dockside hulks armored in glacier-thick salt plate and quenched iron. Their relentless charge shatters brittle vessels that linger along the canal.*

Elita není nová katalogová entita. Warden (nebo jiný non-boss spawn) zmutuje a dostane Shielder nebo Noxious.

### Seal Guardians

- **Cinder Heart (`cinder-heart`) - Core of the First Kiln.** *The living furnace heart that consumed its own alchemists. It awakens only when the Transmutation Circle is charged, determined to melt every vessel back into raw clay.* Minioni: Kiln Brood.
- **Frost Sovereign (`frost-sovereign`) - Regent of the Frozen Dock.** *An ancient transmutation frozen mid-ascension when the sea-locks broke. Crowned in pale rime, it crushes any vessel that dares open the deeper Rift.* Minioni: Rime Brood.
- **Frost Emperor (`frost-emperor`) - Monarch of Absolute Zero.** *Entombed at the bottom of the Great Work where heat and motion cease. It is the final seal-keeper; to shatter its glacial hull is to complete the transmutation.* Minioni: Imperial Guard, Brine Retinue.

Bestiary chování (UI): chase *Runs straight at you.* Ranged *Keeps its distance and spits. Do not stand still.* Sniper *Draws a beam from the rim. Hide behind kilns, bollards, or monoliths.* Boss *Wakes when the Transmutation Circle is full. Slaying it opens the Rift, or completes the Great Work in the last chamber.*

---

## 4. The Archives (pět svazků)

1. **I. Rites of Motion** - ovládání (WASD, myš, LMB hold, RMB, Shift/Space, Q, 1/2/3, stand in ring, F, Esc/P) a tři beaty:
   - 01 Distillation: *Slay the lesser dross. Mercury Drops rise from the husks. Each ascent pauses the chamber and offers three tablets. Pick one.*
   - 02 Convergence: *When the Transmutation Circle appears, a chevron points you to it. Stand inside to charge. Step out and the seal cools.*
   - 03 The Guardian: *A full seal wakes the chamber’s Guardian. Slay it to tear open the Rift. After the Frost Emperor, stand in the gold gate for Cycle II, or press F (or pause → Seal the Working) to complete the transmutation.*
2. **II. Chronicles** - viz §2.
3. **III. Bestiary** - 10 entit, filtry Denizens / Guardians, vitality, habitat, treatise recovered/unrecovered, encountered/slain.
4. **IV. Reliquary** - 13 augmentací, rarity filtry, hooky, lore, Bound ×n. Sealed / Unbound / Bound. Neodemčený relic tiskne požadavek.
5. **V. Ledger** - persistuje v `user://records.v1.json` (verze 1). Purge Ledger je dvoukrokový confirm a maže celý soubor.

### Pole Ledgeru

Lifetime: `totalRuns`, `victories`, `defeats`, `abandons`, `totalPlayTime`, `totalKills`, `fodderKills`, `eliteKills`, `bossKills`, `totalDamageDealt`, `totalDamageTaken`, `totalHealingDone`, `totalGemsCollected`, `totalItemsCollected`, `totalLevelsGained`, `stagesCleared`, `longestRunTime`, `fastestVictoryTime`, `highestLevel`, `highestCoefficient`, `mostKillsInRun`, `mostDamageInRun`, `furthestStageIndex`.

Mapy: `bySurvivor`, `entityKills`, `entityEncounters`, `entityLores`, `itemPicks`, `stageVisits`, `stageClears`.

`recentRuns` (max 10): timestamp, outcome, survivorId, stageId/Name, runTime, level, coefficient, kills, bossesDefeated, damageDealt, items[{id, stacks}], cycleIndex, seedTag, dailyDate.

### Lore dropy

| Role | Šance |
|---|---|
| Fodder | 2.5 % |
| Elite | 25 % |
| Boss | 60 % |

Max 8 živých dropů. Jeden aktivní drop na entity id. Pickup zapisuje treatise do `entityLores`. Při Seal the Working a při Ouroboros wrap se zbylé dropy posbírají automaticky.

---

## 5. Systém odemykání

Obsah se neodemyká lobby měnou. Odemyká se splněním milníků během běhů. Zamčená augmentace **není v nabídce 3 karet**.

Typy `unlock`:

| Typ | Matcher | LIVE použití |
|---|---|---|
| `stage-clear` | `stageClears[stageId] >= count` | Salt Effigy (Cinder Yard), Pale Moon (Rime Dock) |
| `boss-kill` | `entityKills[entityId] >= count` | The Penitent (Frost Sovereign), Bellows Heart (Cinder Heart) |
| `total-kills` | `totalKills >= count` | Cinnabar Leech 100, Astrologer's Ocular 300 |
| `elite-kills` | `eliteKills >= count` | Parasitic Alembic 10 (matcher = všechny elity) |
| `victories` | `victories >= count` | v katalogu zatím žádný řádek |

### Zamčený obsah LIVE

| Prvek | Typ | Podmínka (display) |
|---|---|---|
| The Penitent | `boss-kill` | Slay the Frost Sovereign in the Rime Dock |
| Salt Effigy | `stage-clear` | Clear the Cinder Yard |
| Pale Moon Covenant | `stage-clear` | Clear the Rime Dock |
| Bellows Heart | `boss-kill` | Slay the Cinder Heart |
| Parasitic Alembic | `elite-kills` 10 | Slay 10 Noxious Elites (počítá každou elitu) |
| Cinnabar Leech | `total-kills` 100 | Slay 100 Dross across workings |
| Astrologer's Ocular | `total-kills` 300 | Slay 300 Dross across workings |

7 itemů startuje v poolu. 6 je gated.

---

## 6. Pokyny pro konzultanta při psaní lore

1. **Slovník:** vitriol, kalcinace, fixace, křivule (alembic), retort, sublimace, olovo (plumbum), rtuť (quicksilver / argent), síra (brimstone), rumělka (cinnabar), aether, lůj (tallow), struska (slag), Ouroboros, Vessel, Dross, Mercury Drop.  
   Vyhýbej se klišé: magické krystaly, elementálové, mana orby, STR/DEX.
2. **Tón:** Střídmé, chladné, vědecko-mystické deníkové zápisky alchymistů, kteří sledovali rozpad díla. Augmentace je fyzická substance vlitá, přišroubovaná nebo narostlá do schránky.
3. **Mechanické opodstatnění:** Lore vysvětluje hook. Vitriol Veins (+55 % dmg, −25 % HP): kyselina leptá nepřátele i nádobu. Astrologer's Ocular (+25 % crit, −0.25 s CD on crit, −15 % speed): těžký mosazný okulár na čele. Pale Moon: kacířství proti dílu posiluje údery na strážce a elity, ale odmítá ambientní insight (XP) a krunýř.
