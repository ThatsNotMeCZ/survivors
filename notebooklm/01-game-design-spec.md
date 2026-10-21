# survivors — Game Design Spec (gameplay)

Snapshot: **2026-10-21**. Čísla v tabulkách musí sedět s `02-catalog-numbers.md`.

Working title: **survivors**. Hall title: **Hermetic Rifts**.  
Žánr: 2D survivor-like. Hybrid **Vampire Survivors pacing** + **Risk of Rain 2 pressure**.  
Jeden run (target): **15–20 minut**. Hráč hraje, nesleduje build, jak vyhrává.

Player-facing téma: **Dark Hermetic**. Display stringy, ne id.  
Jsi Vessel (Homunculus nebo The Penitent), kiteš failed transmutations. XP = Mercury Drops, hold = Transmutation Circle, exit = Rift.

## 1. Pitch

Nejsi v orbitálu, který čistí obrazovku. **Pohybuješ se skrz hordu, která časem zhrubne, ne jen zhoustne.** Late game = méně těl, horší elite, bod, který musíš držet.

Power fantasy zůstává: v minutě 15 **procházíš** hordou. Nesedíš a nesleduješ, jak umírá.

## 2. Co krademe / co necháváme

**Z Vampire Survivors bereme:** 15–20 min run, draft 1 ze 3 každých ~30–45 s, čitelné 32px sprity, rychlý pocit snowballu.

**Z Vampire Survivors necháváme:** full auto do všech směrů, evoluce, které smažou obrazovku, prázdný nekonečný trávník.

**Z Risk of Rain 2 bereme:** difficulty coefficient, monster director, elite, teleporter hold, pohyb jako HP, itemy, které mění verb (ne jen číslo).

**Z Risk of Rain 2 necháváme:** 3D, 100+ itemů, 20 survivorů, co-op (v1).

## 3. Šest designových zákonů (anti-idle)

Žádný feature se nesmí dostat do hry, pokud porušuje tyto body.

1. **Stání se trestá.** LIVE: Astral Watcher laser (1.5 s telegraph, hitscan), Noxious elite contact slow + corpse acid pool. Ne extra HP houby. (Burn / chain-lightning modifiers = TARGET.)
2. **Aspoň jeden hráčský verb každých ~2 s.** Primary je **player-aimed**. Auto-fire na primary je zakázaný.
3. **Teleporter.** Na stage se objeví zóna (Transmutation Circle). Charge jen uvnitř. Swarm jde *do zóny*. AFK venku nejde.
4. **Kvalita nad kvantitou.** Soft cap ~80–120 živých nepřátel. Late game = 6 elit, ne 600 kuřat.
5. **Itemy mají hook.** Příklad: `+40% dmg, −15% max HP`. Žádný orbital garlic, který vyřeší run.
6. **Překážky jsou tlak, ne cover.** Pilíře lámou edge-kiting a žerou bolty. Nesmí vzniknout AFK úkryt (bosové fázují skrz, spitters nutí pohyb). Hazard trestá stání (slow + DPS) a odměňuje timed dash. Volatile detonuje jen po **mířeném** Bolt a 0.4 s telegraphu — ne AFK screen-clear. Noxious acid na Holdu žere podlahu.

Zakázáno inventovat zbraně/itemy, které smažou obrazovku nebo umožní AFK win.

## 4. Combat verb (zamčeno)

**Locked A (2026-10-20):** hráč míří primary myší.

| Input | Akce |
|---|---|
| WASD | pohyb |
| Myš | aim (postava hledí na kurzor) |
| Držet LMB | střílet primary ve směru aim |
| RMB | secondary (aimed press) |
| Shift / Space | utility dash s i-frames |
| Q | ultimate (aimed press) |
| Esc | pause (HTML overlay, sim stojí) |

Primary **nikdy** nemíří samo. Primary **nikdy** nestřílí bez drženého/stisknutého inputu. Screen-clear a orbital zbraně na primary jsou zakázané.

Fallback jen kdyby browser aiming v playtestech byl špatný: varianta C (primary auto, secondary + ultimate mířené). Teď ne.

Během dash hráč **není** body-separated, takže dash řeže skrz pack. I-frames přeskakují contact damage i enemy projectiles.

## 5. Struktura runu

**Cíl produkce:** 3 stage + finale, ~6 min / stage, teleporter ~minuta 4, hold ~60 s.  
**Aktuální playable slice:** 2 stage + stage boss, hodiny zkrácené pro playtest.

### Jeden stage (pořadí beatů)

1. **Drop.** Kite fodder. Sbírej Mercury Drops. HUD: `Seal manifests in M:SS`. Při init stage se položí překážky: **14 pillars, 8 hazards, 9 volatiles** na aréně 2560×2560.
2. **Level-up.** HTML overlay, pick 1 of 3 item hooků + lore. Sim se pauzne.
3. **Director** utratí kredity za první elite, pak další během holdu. ~22 % fodder spawnu jsou ranged spitters. Zvlášť kupuje **Astral Watcher** (max 2, interval 7 s).
4. **Circle on.** Charge jen uvnitř kruhu. Swarm kráčí do zóny. HUD: `Channel the Transmutation Circle`. Off-screen chevron ukazuje na zónu. Souřadnice kruhu se **rezervují na startu stage**, aby keep-out překážek seděl.
5. **Stage boss.** HUD: `Slay the [Boss Name]`. Focus bar na elite/boss.
6. Po bossovi: **Descend the Rift** (chevron + pulzující kruh) na další biome, nebo victory na posledním stage.

Boss intro sting a stage interstitial jsou HTML title cards. **Nepauzují** combat. Přeskakují se na `?smoke=1` a `?dev=1`.

### Clocks aktuálního slice

| Beat | Stage 1 Cinder Yard | Stage 2 Rime Dock |
|---|---|---|
| First elite | 15 s | 12 s |
| Circle on | 55 s | 50 s |
| Hold | 20 s | 22 s |
| Boss | po holdu | po holdu (konec runu) |

## 6. Shell / flow mimo arénu

HTML overlay v `src/ui/`, ne Phaser text. Phaser startuje až po **Commence Transmutation**.  
`/?smoke=1` = GPU smoke (bez hallu). `/?dev=1` přeskočí hall a auto-startne run.

- **Hall (main menu):** title **Hermetic Rifts**. 3 sloupce — vlevo Vessel Selection / Archives / Alchemist's Desk, střed 32px vessel preview, vpravo dossier + 4 skill tooltips, **Commence Transmutation**. Enter startuje.
- **Vessel picker LIVE:** Homunculus nebo The Penitent. Volba se ukládá v settings.
- **Vessel dossier:** display name + title + lore + 4 skill ikony s hover hooky, žádná raw id.
- **Pause:** Esc během hry. Resume Sequence / Settings / Abandon Vessel. Sim neběží. Nested obrazovky (settings, how-to, abandon) jdou nejdřív zpět. Inventory strip (32px ikony + stack).
- **Cursor:** OS pointer schovaný během unpaused runu. Aim pořád z pozice myši, world crosshair zůstává. Žádný pointer lock.
- **Level-up:** klávesy 1–3 nebo klik. Tři hermetic tablety (96px ikony + shared detail panel).
- **Victory / Defeat:** Transmutation Complete / Vessel Shattered. Recap: vessel, time, level, bosses, inventory. Run again nebo hall.

Žádná meta-progrese, unlocky, obchody, co-op. Settings (master/SFX/music/mute/screenshake/reduce-VFX/selected vessel) se ukládají. Phaser zůstává `noAudio`; hudba a SFX jdou přes Web Audio.

## 7. Ovládání a pohyb

- Arena je ohraničená mapa **2560×2560**. Hráč ani enemy z ní nevyjdou.
- Pohyb je 8-dir analog (WASD normalizovaný).
- **Dash:** press skill. Směr = pohybový vektor. Pokud stojíš, směr = aim. I-frames přeskočí contact damage i enemy projectiles.
- Homunculus Phase Step: vzdálenost 210, trvání 0.16 s, i-frame 0.22 s, cooldown 0.9 s.
- Penitent Ash Step: stejný dash + 1.5 s fodder decoy (elity decoy ignorují), cooldown 1.1 s.
- Contact damage tresta stání. Fodder contact je capnutý (max 4 fodder source najednou), elite/boss contact cap nemá.

Kamera `viewZoom` 2.5, aby 32px četlo na 1080p. Vessel body kreslí 40px.

## 8. Survivors (aktuální slice)

Dva playable. v1 kvóta „2 survivors × 4 skilly“ je v slice **splněná**.

### Homunculus (`runner`) — fast skirmisher

- Speed 280, max HP 100, hurtbox radius 14
- Primary: **Ignis Bolt** (`bolt`)
- Secondary: **Piercing Aether** (`skill-aether-pierce`)
- Utility: **Phase Step** (`dash`)
- Special: **Crucible Cull** (`skill-crucible-cull`)
- Starting items: žádné

### The Penitent (`penitent`) — caster / controller

- Speed 245, max HP 135, hurtbox radius 14
- Primary: **Censer Lob** (`skill-censer-lob`)
- Secondary: **Brimstone Line** (`skill-brimstone-line`)
- Utility: **Ash Step** (`dash-ash-step`)
- Special: **Condemnation Tether** (`skill-condemn-tether`)
- Starting items: žádné

### Skill sloty

- `primary` = LMB (hold)
- `secondary` = RMB (aimed press)
- `utility` = Shift/Space (dash)
- `special` = Q (aimed press)

Skill je buď `hold` nebo `press` (rising edge).

### Homunculus kit

**Ignis Bolt** — hold LMB, cooldown 0.28 s. Projectile speed 780, lifetime 0.85 s, radius 5, damage 10. Bez pierce: zásah zabije projectile. Zásah do pilíře / intact volatile taky zahodí. Damage a cooldown se škálují itemy.

**Piercing Aether** — press RMB, cooldown 4 s. Ray speed 1400, lifetime 0.45 s, radius 6, damage 22, **pierce** všechny v linii. Zároveň 50 % self-slow na 0.25 s. Seřaď je, nebo plýtvej.

**Phase Step** — press Shift/Space. Dash 210 / 0.16 s / iframe 0.22 s / CD 0.9 s.

**Crucible Cull** — press Q, cooldown 12 s. 0.7 s telegraph, pak 45 px AoE na kurzoru, damage 95. Precision, ne nuke.

### The Penitent kit

**Censer Lob** — hold LMB, cooldown 0.42 s. Mortar: speed 420, lifetime 1.1 s, radius 7, damage 14. `flyOver` (létá nad nepřáteli), splash `impactRadius` 30 na dopadu u kurzoru.

**Brimstone Line** — press RMB, cooldown 5 s. Šev 150×18 px, 2.4 s, fodder-only slow ×0.2 + 2 DPS. Elity a bosové **ignorují**. Offset 56 před hráčem.

**Ash Step** — press Shift/Space. Dash jako Phase Step, CD 1.1 s, plus 1.5 s fodder decoy. Elity decoy ignorují.

**Condemnation Tether** — press Q, cooldown 15 s. Střela speed 640, lifetime 0.7 s, radius 8. První elite/boss zásah = root 2.5 s; fodder na rooted cíli hoří 18 DPS. Fodder zásah nebo miss **spálí cooldown**.

LIVE effect typy: `projectile` (volitelně `pierce`, `flyOver`, `impactRadius`), `dash` (volitelně `decoyDuration`), `self-slow`, `delayed-strike`, `slow-line`, `tether`. Jiný `type` musí hodit chybu při bootu, nesmí tiše no-op.

## 9. Level-up a XP

VS pacing, ne VS power.

- Zabití dropne **Mercury Drop** (XP gem).
- Pickup radius 36, magnet 88, magnet speed 320. Gem se přitáhne, pak sebere.
- XP na level: `round(32 * 1.30^(level-1))`. Level 1 potřebuje 32 XP (~11 Ember Mites, ne 4).
- Level-up **pauzne sim**. Offer = **3 unikátní itemy** z poolu, vážené raritu.
- Pick **1 of 3**. Pokud hráč naskákal víc levelů najednou, jde další offer.
- Pick nesmí být screen-clear.

Rarity váhy offeru:

| Rarity | Váha |
|---|---|
| common | 1.00 |
| uncommon | 0.55 |
| rare | 0.22 |
| lunar | 0.08 |

Lunar rarity je LIVE. V slice je jeden lunar item: **Pale Moon Covenant**.

## 10. Itemy (hooks only)

Každý draft item má tradeoff. Žádný čistý `+damage` win. Stackování: `linear` (každý další stack přičte stejný hook znovu).

Stats, které itemy sahají: `speed`, `maxHp`, `radius` (hurtbox hráče), `damage`, `cooldown`.  
Vzorec: `(base + add) * (1 + pct)`. Damage/cooldown jsou multipliery na primary.  
`on-kill` není stat: +HP za `killEnemy`, clamp na max HP.

Při změně max HP se aktuální HP posune o delta max HP (heal/hurt podle změny), nikdy pod 1, nikdy nad nové max.

### Katalog slice (13 itemů)

v1 target „12 itemů s hookem“ je v slice **splněný**. Další itemy jen s novým hookem, ne čistým číslem. `cinnabar-leech` je ten nový hook (`on-kill`).

| Display | id | Rarity | Hook |
|---|---|---|---|
| Vitriol Veins | `glass-cannon` | uncommon | +40% damage, −15% max HP |
| Cloven Sinew | `goat-hoof` | common | +14% speed, −6% max HP |
| Slag Carapace | `brittle-plate` | common | +28% max HP, −12% speed |
| Spasmodic Nerve | `hair-trigger` | uncommon | −15% cooldown, +12% hurtbox |
| Bellows Heart | `overclock` | uncommon | +22% damage, +12% cooldown (střílí pomaleji) |
| Waxen Pinions | `wax-wings` | common | +16% speed, −8% max HP |
| Parasitic Alembic | `hungry-clip` | rare | +28% damage, +14% hurtbox |
| Lead Plumbum | `lead-core` | common | +18 max HP, −8% damage |
| Quicksilver Draught | `mercury-vial` | uncommon | −18% cooldown, −12% max HP |
| Astrologer's Ocular | `calcined-lens` | rare | +32% damage, −10% speed |
| Salt Effigy | `salt-ward` | common | −15% hurtbox, −10% damage |
| Pale Moon Covenant | `lunar-tithe` | lunar | +75% damage, −35% max HP, +18% hurtbox |
| Cinnabar Leech | `cinnabar-leech` | common | +0.2 HP on kill, +8% hurtbox |

## 11. Director a obtížnost

Není VS spawn-more křivka. Je **RoR2 director**.

- Difficulty coefficient: `1 + runTime * 0.006 + stageIndex * 0.35`.
- Coefficient škáluje: HP enemy, contact DPS, damage enemy projectile, rychlost enemy (`+5% speed per (coeff-1)`), credit income directoru.
- Director sbírá kredity: `3.6 * coefficient` za sekundu.
- Kredity kupují **elity, snipery a bossy**, ne 2000 netopýrů. Fodder je textura a XP (taky se platí z kreditů, cost 7).

Spawn pravidla:

- Fodder: cost 7, interval 0.5 s, cap 32 živých (snipery se počítají do fodder capu).
- Elite: cost 42, interval 14 s. Před teleporterem max 1 elite, během holdu max 3.
- Sniper: cost 30, interval 7 s, max 2 živých. Kupuje se i po spawnu bosse.
- První elite až po `firstEliteAt`.
- Spawn ring 340–520 px od **hráče**; během teleporter holdu od **zóny** (swarm jde dovnitř).
- ~22 % fodder spawnu = ranged spitter stage.
- Po spawnu bosse se **elity přestanou kupovat**. Fodder a snipery dál tečou.

Soft living cap designu: ~80–120. Slice je přísnější (32 fodder včetně sniperů + 3 elite + 1 boss). XP gem cap 64. Projectile pool 128.

## 12. Nepřátelé

Tři role: **fodder**, **elite**, **boss**.  
Tři AI typy teď: **chase** (jdou na hráče; fodder peel na Ash Step decoy), **ranged** (držet vzdálenost, telegraph windup, vystřelit bolt), **sniper** (držet `keep`, 1.5 s laser telegraph, hitscan).

Ranged AI: přiblíží se na `range`, odchází pod `keep`, jinak krouží. Windup je čitelný telegraph (čára na pozici hráče v okamžiku startu windupu). Bolt trefil = damage, projectile zmizí.

Sniper AI: stojí na `keep` (480). 1.5 s červený/modrý laser zamčený na startu windupu, pak hitscan damage 28 × coefficient. Pilíře blokují linii. I-frames nebo úkrok z čáry = miss. Nízké HP, vysoký credit.

Kill reward: XP gem + kredity directoru (boss kredity 0).

Čísla níže jsou **base**. Ve hře se násobí coefficientem (HP, contact, enemy bolt, sniper hitscan, speed).

### Stage 1 — Cinder Yard (teplé, červené)

| Display | id | Role | Chování | HP | Speed | Contact DPS | XP |
|---|---|---|---|---|---|---|---|
| Ember Mite | `ember-mite` | fodder chase | tlačí se na hráče | 14 | 92 | 3 | 3 |
| Ember Spitter | `ember-spitter` | fodder ranged | range 280, keep 200, CD 2.1 s, windup 0.4 s, bolt dmg **5** | 12 | 68 | 2 | 4 |
| Ember Warden | `ember-chaser` | elite chase | Noxious chaser | 90 | 102 | 28 | 14 |
| Cinder Heart | `cinder-heart` | boss chase | stage boss | 520 | 78 | 34 | 40 |

### Stage 2 — Rime Dock (studené, modré, meaner)

| Display | id | Role | Chování | HP | Speed | Contact DPS | XP |
|---|---|---|---|---|---|---|---|
| Frost Mite | `frost-mite` | fodder chase | rychlejší/tvrdší mite | 18 | 104 | 4 | 4 |
| Frost Spitter | `frost-spitter` | fodder ranged | range 300, keep 210, CD 1.9 s, windup 0.38 s, bolt dmg **5** | 16 | 76 | 2 | 5 |
| Frost Warden | `frost-warden` | elite chase | Noxious tankier elite | 140 | 90 | 34 | 18 |
| Frost Sovereign | `frost-sovereign` | boss chase | run-end boss | 620 | 80 | 40 | 60 |

### Shared — oba biomy

| Display | id | Role | Chování | HP | Speed | Contact DPS | XP |
|---|---|---|---|---|---|---|---|
| Astral Watcher | `enemy-astral-sniper` | fodder sniper | keep 480, CD 3.2 s, windup 1.5 s, hitscan 28 | 8 | 36 | 1 | 6 |

### Noxious elite (LIVE, každá elite)

Každá elite spawne s **Noxious** (`elite-poison-slow`): zelený glyph.

- Contact: ×0.5 slow na 1.1 s.
- Smrt: 0.5 s corpse telegraph, pak pop r=40 / 8 × coefficient damage.
- Pak **permanent acid pool** (stejný `hazard`: r=68, ×0.65 player speed, 4 × coefficient DPS). Pool žije do stage wipe. Cap 8 dynamic hazards.
- Kill je **mimo** Transmutation Circle, jinak Hold ztrácí podlahu.

### Archetypy v1 (částečně LIVE)

- 3 AI LIVE: chase / ranged / sniper. **Čtvrtý archetype = TARGET.**
- 3 elite modifiers design:
  - červená = burn — TARGET
  - modrá = chain lightning — TARGET
  - zelená = Noxious poison slow — **LIVE** (zatím na každé elitě, ne random roll)

LIVE standing-still tresty: contact DPS, spitters, Astral Watcher laser, Noxious slow + acid, hazards, swarm do hold zóny.

## 13. Objectives (jeden vždycky)

HUD má středový objective. Přesně jeden:

1. **Wait** — `Seal manifests in M:SS` (countdown do spawnu zóny).
2. **Hold** — `Channel the Transmutation Circle` + % charge. Charge **jen když hráč stojí v kruhu**. Venku charge stojí (neklesá). Cinder radius 160 / hold 20 s. Rime radius 150 / hold 22 s.
3. **Boss** — `Slay the [Boss Name]` + % HP bosse. Chevron na bosse. Focus bar na elite/boss.
4. **Portal** — `Descend the Rift` + hold %. Portal spawn na místě kruhu. Radius 70, hold 1.4 s uvnitř. Venku hold reset na 0. Po holdu: nový stage, HP refill na max, wipe enemy/gem/projectile/**obstacles** (včetně acid pools), credits reset, coefficient dál roste s run time + stage bonus. Nový biome položí nové překážky.

Poslední boss mrtvý → **Transmutation Complete**, portal se neotevře.

HP na 0 → **Vessel Shattered**. Overlay: recap, Run again / hall.

## 14. HUD (player-facing)

Viditelné vždy:

- Stage name
- HP číslo + bar (alchemical flask)
- XP bar + `Lv N`
- 4 skill sloty (ready / cooldown sweep / i-frame flash, ikony `px-skill-{id}.png`)
- Run clock + biome
- Středový objective (+ detail % když hold/boss/portal)
- Sebrané itemy (32×32 grid, 6 sloupců, stack count)

Debug (F3 nebo `?debug=1`): FPS, difficulty coefficient. Není součást hráčského HUD.

Off-screen chevron: ukazuje Transmutation Circle / boss / Rift, když je mimo kameru.

VFX wow: hit spark, dash afterimage, death burst, ranged muzzle, sniper laser. Ne extra gameplay sprity.

## 15. Čitelnost / vizuální pravidla (hra, ne engine)

- Chunky **32px** pixel art. Vessel body **40px**. Silueta nad detailem.
- Kamera zoom 2.5, aby 32px četlo na 1080p.
- Fodder / gemy = malé tečky (GPU layer). Sniper má fialový tint.
- Player, elite, boss, obstacles = větší, čitelné sprity.
- Dva biomy vizuálně: Cinder Yard teplá červeň, Rime Dock studená modř.
- Homunculus = muscular clay brute. The Penitent = hooded robe.
- Transmutation Circle: dva pixelated rings + hexagram; charge plní outer arc.
- Ne HD cinematic postavy. Na 32px selžou.

### Překážky (LIVE)

Položí se na init stage. Fail = přeskočit zbytek, nikdy overlap.

Keep-out: ≥160 px od stěn, ≥200 px od player spawnu, pillars/hazards ≥230 px od středu kruhu, volatiles ≥200 px, mezi sebou ≥190 px center-to-center.

| Type | Cinder / Rime | Collision |
|---|---|---|
| `pillar` r=52 | Obsidian Kiln / Frozen Bollard | Solid vs player, fodder, elite. **Bosové fázují skrz.** Blokuje player Bolt i spitter bolty i sniper laser. |
| `hazard` r=68 | Slag Fissure / Brine Pool | Bolty létají nad. Hráč chůze: ×0.65 speed a `4 * coefficient` DPS. Během dash / iframe čistý průchod. Fodder/elite: ×0.85 speed v overlapu. Noxious corpse přidá stejný hazard (acid) na místě smrti. |
| `volatile` r=22 | Brimstone Urn / Pressurized Rime Cask | Lehký movement block, blokuje projectiles. HP `25 * coefficient`, damage **jen** z player Bolt. Na 0 HP → `primed` 0.4 s, pak `45 * coefficient` AoE r=110 na enemy a 18 flat na hráče bez iframe. Rime navíc 2.0 s ×0.7 slow. Pak pryč. |

## 16. Co je v aktuálním slice (playable teď)

- Aimed primary (verb A) + dash s i-frames
- **2 survivors**, každý 4 bound skilly (LMB / RMB / Shift-Space / Q)
- Homunculus: Ignis Bolt / Piercing Aether / Phase Step / Crucible Cull
- The Penitent: Censer Lob / Brimstone Line / Ash Step / Condemnation Tether
- Level-up 1 of 3, **13 itemů** s tradeoffem (včetně 1 lunar)
- 2 stage: Cinder Yard → Rime Dock
- Director, coefficient, fodder cap 32, elite cap 3, sniper max 2
- Transmutation Circle hold
- 2 stage bosse
- Rift mezi stage
- Ranged spitters (~22 %)
- Astral Watcher sniper
- Noxious na každé elitě (slow + corpse acid)
- Arena obstacles (14/8/9) + až 8 dynamic acid pools
- Hall s výběrem vesselu, pause, win/lose, HUD 4 sloty, settings
- Contact damage, i-frames, Mercury Drops
- Procedural 32px pixel art, GPU fodder/gemy/sparks
- Web Audio (menu / map / pause overlay playlisty)

## 17. v1 target (ještě není)

- 2 survivors × 4 skilly — **splněno v slice**
- 13 itemů s hookem — **splněno v slice**; další jen pokud mají nový verb-hook
- 4. enemy archetype (chase / ranged / sniper už LIVE)
- Elite modifiers burn / chain lightning (Noxious už LIVE; zatím na každé elitě, ne roll)
- 2 biomes, **3 stage + finale**
- ~20 min run, produkční hodiny (~6 min/stage, teleporter ~min 4, hold ~60 s)
- Late game: méně těl, scarier elite, ne 600 kuřat

## 18. Explicitně mimo scope v1

- Co-op
- 100+ itemů, evolutions, orbital garlic
- Auto-aim primary, screen-delete zbraně
- Meta unlock tree / lobby shop
- Character roster 20 survivorů
- AFK win buildy
- Pilíř jako safe AFK cover

## 19. Jak navrhovat nový obsah (pro konzultanta)

Nový content = data (survivor / skill / enemy / item / stage). Nové **chování** skillu potřebuje nový effect case.  
Při návrhu se ptej:

1. Nutí to hráče hýbat / mířit aspoň každé ~2 s?
2. Má item hook (tradeoff), nebo je to čisté číslo k AFK?
3. Je late pressure **kvalita** (elite, hold, telegraph), ne kvantita?
4. Maže to obrazovku? Pokud ano, zahodit.
5. Pasuje to na verb A (hráč míří primary)?
