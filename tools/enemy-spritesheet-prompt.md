# Gemini Prompt — Enemy Entities Spritesheet

Prompt pro vygenerování spritesheetu všech 10 nepřátelských entit z [`src/data/entities.json`](../src/data/entities.json) podle lore a vizuálního stylu v [`knowledge/design/style.md`](../knowledge/design/style.md) a [`knowledge/tech/sprites.md`](../knowledge/tech/sprites.md).

---

## Master Prompt (všech 10 nepřátelských entit najednou)

```text
Generate a clean, crisp 2D top-down / 3/4 isometric pixel-art master spritesheet containing all entity animation frames for a "Dark Hermetic Alchemy" survivor roguelite game ("Hermetic Rifts").

CRITICAL TECHNICAL CONSTRAINTS:
- Background: Pure, solid, flat white background (#FFFFFF) across the entire canvas. No floor tiles, no cast shadows on the ground, no ambient fog, no gradients touching the background, no UI frames or text labels.
- Art Style: Chunky 16-bit / 32px-scale pixel art (Resurrect-64 / Blasphemous / Nuclear Throne / Vampire Survivors aesthetic). Crisp 1px dark outlines (#120a0d for Cinder/fire entities, #08101a for Rime/ice entities) so every silhouette pops cleanly against the #FFFFFF background.
- Orientation: All sprites face RIGHT (+X) in a 3/4 top-down arena perspective. Clear, readable silhouettes over micro-detail.
- Layout: Organize the sheet into 10 clean horizontal rows (1 row per enemy entity), with 6 evenly spaced animation frames per row from left to right:
  [Frame 1: Idle] [Frames 2–4: Walk / Float cycle] [Frames 5–6: Attack / Windup].
  Keep generous white padding (#FFFFFF) between every sprite and every row so they can be sliced cleanly.

ENTITIES TO INCLUDE (10 ROWS, TOP TO BOTTOM):

1. EMBER MITE ("Scorched Dross" — Small Fodder, ~24x24px scale)
   - Lore & Visuals: Clots of black ash, scorched slag, and failed calcination that skitter out of cracked retorts. Brittle, jagged dark-iron and charcoal-red carapace (#5a2018, #3a1410) with an exposed, pulsing molten orange-white furnace core (#ff5522, #fff0c8) and four sharp skittering slag legs.
   - Frames: 1 idle crouch, 3 skittering walk frames, 2 lunging bite/burst attack frames.

2. EMBER SPITTER ("Slag Bile Vessel" — Ranged Fodder, ~28x28px scale)
   - Lore & Visuals: Distended, bloated alchemical husks engorged on boiling sulfur and molten slag. Charred clay-and-soot vessel body (#4a2818) on three stubby tripod legs, topped with a cracked retort neck (#2a1810) and a glowing orange-yellow gaping maw (#ff7a3a, #fff4c8) brimming with molten sulfur globules.
   - Frames: 1 idle bubble, 3 heavy waddling walk frames, 2 bloated windup & slag-spitting frames.

3. EMBER WARDEN ("Furnace Overseer" — Cinder Elite, ~48x48px scale)
   - Lore & Visuals: A hulking amalgam of cast-iron ribs (#6a3a32) and noxious vitriol bound by an occult aether ward. Heavy furnace-plate shoulders with iron rivets (#9aa0a8), a jagged horned crown of heated brass/copper (#c45a3a), and an open ribcage exposing a volatile crimson-orange furnace heart (#ff5522) dripping with green-tinted corrosive vitriol.
   - Frames: 1 imposing idle, 3 heavy stomping march frames, 2 violent furnace-slam attack frames.

4. CINDER HEART ("Core of the First Kiln" — Stage 1 Boss, ~64x64px scale)
   - Lore & Visuals: The massive living furnace heart that consumed its own alchemists. A towering monolith of cracked obsidian kiln-stone and blackened cast iron (#2a1814, #3a2018), crowned with twin smokestack horns (#1a0c0a) and vertical iron grate slits, with a gigantic blinding white-hot molten core (#ff7722, #fff0c8) roaring inside its chest.
   - Frames: 1 breathing furnace idle, 3 earth-shaking stride/surge frames, 2 kiln-eruption / molten shockwave frames.

5. FROST MITE ("Rime-Bitten Husk" — Small Fodder, ~24x24px scale)
   - Lore & Visuals: Razor-sharp shards of alchemical salt and frozen mercury skittering in packs. Jagged deep-navy and glacial-blue crystalline shell (#1a3a52, #0e2438) with a glowing cyan quicksilver core (#44ddff, #e8f6ff) and spiky frost-crystal legs.
   - Frames: 1 idle, 3 rapid skittering walk frames, 2 crystalline lunge/shatter attack frames.

6. FROST SPITTER ("Brine Condenser" — Ranged Fodder, ~28x28px scale)
   - Lore & Visuals: Hollowed glass-and-iron alembic creatures (#163044) that siphon freezing brine and spit high-velocity needles of rime. Bulbous frosted flask body with tripod legs and a narrow condenser nozzle glowing with pale ice-blue brine (#7ad4ff, #f4fbff).
   - Frames: 1 idle, 3 creeping walk frames, 2 pressure-condense and ice-needle spit frames.

7. FROST WARDEN ("Cryo-Bound Sentinel" — Rime Elite, ~52x52px scale)
   - Lore & Visuals: Heavy dockside hulk armored in glacier-thick salt plate (#2a4a66) and pale rime-ice pauldrons, crowned with jagged frost spires (#7ad4ff). Its chest houses a freezing cryo-core (#44ddff) leaking caustic freezing brine.
   - Frames: 1 sentinel idle, 3 heavy armored march frames, 2 glacial crush attack frames.

8. FROST SOVEREIGN ("Regent of the Frozen Dock" — Stage 2 Boss, ~64x64px scale)
   - Lore & Visuals: An ancient alchemical transmutation frozen mid-ascension when the sea-locks broke. A tall, regal, terrifying figure of deep abyssal stone and salt-armor (#1a3048, #163044), wearing an ornate, wide crown of pale rime and ice spears (#7ad4ff, #dff6ff, #f4fbff), with a radiant cyan core (#55ffff) and frost-blade arms (#88c8e8).
   - Frames: 1 regal floating/standing idle, 3 advancing stride frames, 2 royal rime-cleave attack frames.

9. FROST EMPEROR ("Monarch of Absolute Zero" — Stage 3 Finale Boss, ~64x64px+ scale, largest entity)
   - Lore & Visuals: Entombed at the bottom of the Great Work where heat and motion cease; the final seal-keeper. A colossal, wider, heavily armored dreadnought-monarch of midnight glacier-iron (#102238, #183654), a massive multi-spired crown of pure white and cyan absolute-zero ice crystals (#ffffff, #77ffff, #3d8ad4), broad glacial shoulder bastions, and a blinding white-cyan heart (#77ffff, #ffffff).
   - Frames: 1 monolithic idle, 3 inexorable march frames, 2 absolute-zero nova / cataclysmic strike frames.

10. ASTRAL WATCHER ("Ocular of the Void" — Sniper Fodder, ~28x28px scale)
    - Lore & Visuals: A disembodied occult brass-and-aether eye that drifts at the edge of sight. Deep void-violet spherical housing (#2a1844, #4a2878) framed by four cardinal antique-brass astrolabe/compass prongs (#c4a35a), with a large glowing lavender-and-cyan iris (#b47aff, #f0e8ff, #44ddff) that focuses a celestial sightline.
    - Frames: 1 hovering idle, 3 drifting/rotating astrolabe ring frames, 2 pupil-constriction / laser-sightline charge frames.
```

---

## Cílové soubory v projektu (`public/sprites/entities/`)

| Řádek | Catalog ID | Název souboru | Doporučený frame size |
|---|---|---|---|
| 1 | `ember-mite` | `public/sprites/entities/ember-mite.png` | `24×24` |
| 2 | `ember-spitter` | `public/sprites/entities/ember-spitter.png` | `28×28` |
| 3 | `ember-chaser` | `public/sprites/entities/ember-chaser.png` | `40×40` nebo `48×48` |
| 4 | `cinder-heart` | `public/sprites/entities/cinder-heart.png` | `64×64` nebo `72×72` |
| 5 | `frost-mite` | `public/sprites/entities/frost-mite.png` | `24×24` |
| 6 | `frost-spitter` | `public/sprites/entities/frost-spitter.png` | `28×28` |
| 7 | `frost-warden` | `public/sprites/entities/frost-warden.png` | `40×40` nebo `52×52` |
| 8 | `frost-sovereign` | `public/sprites/entities/frost-sovereign.png` | `64×64` nebo `80×80` |
| 9 | `frost-emperor` | `public/sprites/entities/frost-emperor.png` | `64×64` nebo `90×90` |
| 10 | `enemy-astral-sniper` | `public/sprites/entities/enemy-astral-sniper.png` | `28×28` |
