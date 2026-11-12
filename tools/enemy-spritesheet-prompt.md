# Gemini Prompts — Enemy Entity Spritesheets (jeden po druhém)

Prompty pro vygenerování spritesheetů 10 nepřátelských entit z [`web/src/data/entities.json`](../web/src/data/entities.json) podle [`knowledge/design/style.md`](../knowledge/design/style.md) a [`knowledge/tech/sprites.md`](../knowledge/tech/sprites.md).

Každý blok níže je **samostatný** — zkopíruj jeden, pošli, ulož výsledek, pak další. Každý prompt generuje **jeden horizontální strip 6 framů** (= přímo formát `entities/{id}.png`: idle = frame 0).

> Tip: pokud Gemini začne driftovat ve stylu, pošli prompt v novém chatu, nebo přilož už hotový sheet jako referenci stylu.

---

## 1. Ember Mite → `ember-mite.png` (24×24)

```text
Generate a single 2D pixel-art spritesheet for one enemy in a "Dark Hermetic Alchemy" survivor roguelite.

TECHNICAL RULES:
- One horizontal strip of exactly 6 equal square frames, left to right, same creature in every frame, same scale, same ground line.
- Frame order: [1: Idle] [2–4: Walk cycle] [5–6: Attack].
- Pure flat white background (#FFFFFF). No floor, no ground shadow, no fog, no gradients, no text, no labels, no frame borders.
- Generous white padding between frames so they slice cleanly.
- Chunky 16-bit pixel art at ~24x24 px scale (Blasphemous / Nuclear Throne / Vampire Survivors feel). Crisp 1px outline #120a0d.
- 3/4 top-down arena view, creature faces RIGHT. Readable silhouette over micro-detail.

CREATURE — EMBER MITE ("Scorched Dross", small fodder):
A clot of black ash and scorched slag that skitters out of cracked retorts. Brittle, jagged dark-iron and charcoal-red carapace (#5a2018, #3a1410), an exposed pulsing molten furnace core (#ff5522, #fff0c8), four sharp skittering slag legs.

FRAMES: 1 idle crouch, 3 skittering walk frames, 2 lunging bite / ember-burst attack frames.
```

---

## 2. Ember Spitter → `ember-spitter.png` (28×28)

```text
Generate a single 2D pixel-art spritesheet for one enemy in a "Dark Hermetic Alchemy" survivor roguelite.

TECHNICAL RULES:
- One horizontal strip of exactly 6 equal square frames, left to right, same creature in every frame, same scale, same ground line.
- Frame order: [1: Idle] [2–4: Walk cycle] [5–6: Attack].
- Pure flat white background (#FFFFFF). No floor, no ground shadow, no fog, no gradients, no text, no labels, no frame borders.
- Generous white padding between frames so they slice cleanly.
- Chunky 16-bit pixel art at ~28x28 px scale (Blasphemous / Nuclear Throne / Vampire Survivors feel). Crisp 1px outline #120a0d.
- 3/4 top-down arena view, creature faces RIGHT. Readable silhouette over micro-detail.

CREATURE — EMBER SPITTER ("Slag Bile Vessel", ranged fodder):
A LIVING, FLESHY creature — a bloated, toad-like / grub-like husk gorged on boiling sulfur. Think swollen burnt-flesh body, not an object.
- Body: lumpy, asymmetric, wrinkled charred hide (#4a2818, #2a1810) stretched tight over glowing sulfur bile sacs that bulge through cracks in the skin (#ff7a3a, #ffcc44).
- Head: low, squat, forward-thrust head with a wide drooling jaw, a throat pouch that swells with molten slag, and two or three small beady ember eyes (#fff4c8).
- Legs: two thick, stubby, clawed forelimbs dragging the heavy belly; hunched, crawling posture.
- Details: dripping molten slag from the mouth, a few smoking vents/pustules on the back, slightly sagging belly.

IMPORTANT — AVOID: do NOT draw a pot, vase, jar, urn, amphora, flask, bottle, or any ceramic/clay vessel. No symmetric round container shape, no rim or neck on top, no smooth glazed surface, no tripod stand. It must read instantly as an animal-like monster, not pottery.

FRAMES: 1 idle (throat pouch gently pulsing), 3 heavy belly-dragging crawl frames, 2 attack frames (throat swells huge, then jaw snaps open spitting a molten slag glob to the right).
```

---

## 3. Ember Warden → `ember-chaser.png` (40×40 nebo 48×48)

```text
Generate a single 2D pixel-art spritesheet for one enemy in a "Dark Hermetic Alchemy" survivor roguelite.

TECHNICAL RULES:
- One horizontal strip of exactly 6 equal square frames, left to right, same creature in every frame, same scale, same ground line.
- Frame order: [1: Idle] [2–4: Walk cycle] [5–6: Attack].
- Pure flat white background (#FFFFFF). No floor, no ground shadow, no fog, no gradients, no text, no labels, no frame borders.
- Generous white padding between frames so they slice cleanly.
- Chunky 16-bit pixel art at ~48x48 px scale (Blasphemous / Nuclear Throne / Vampire Survivors feel). Crisp 1px outline #120a0d.
- 3/4 top-down arena view, creature faces RIGHT. Readable silhouette over micro-detail.

CREATURE — EMBER WARDEN ("Furnace Overseer", Cinder elite):
A hulking amalgam of cast-iron ribs (#6a3a32) and noxious vitriol bound by an occult aether ward. Heavy furnace-plate shoulders with iron rivets (#9aa0a8), a jagged horned crown of heated brass/copper (#c45a3a), and an open ribcage exposing a volatile crimson-orange furnace heart (#ff5522) dripping green-tinted corrosive vitriol.

FRAMES: 1 imposing idle, 3 heavy stomping march frames, 2 violent furnace-slam attack frames.
```

---

## 4. Cinder Heart → `cinder-heart.png` (64×64 nebo 72×72)

```text
Generate a single 2D pixel-art spritesheet for one boss in a "Dark Hermetic Alchemy" survivor roguelite.

TECHNICAL RULES:
- One horizontal strip of exactly 6 equal square frames, left to right, same creature in every frame, same scale, same hover height (centered in each frame).
- Frame order: [1: Idle] [2–4: Float cycle] [5–6: Attack].
- Pure flat white background (#FFFFFF). No floor, no ground shadow, no fog, no gradients, no text, no labels, no frame borders.
- Generous white padding between frames so they slice cleanly.
- Chunky 16-bit pixel art at ~64x64 px scale (Blasphemous / Nuclear Throne / Vampire Survivors feel). Crisp 1px outline #120a0d.
- 3/4 top-down arena view, creature faces RIGHT. Readable silhouette over micro-detail.

CREATURE — CINDER HEART ("Core of the First Kiln", Stage 1 boss):
The living furnace heart that consumed its own alchemists, now hovering in the air, imprisoned inside a metal cage-shell. It has no legs and no body — it floats.
- The heart: a large, anatomical-ish, muscular heart made of molten matter — glowing white-hot to orange (#fff0c8, #ff7722, #ff5522) with darker cooling crust patches (#5a2018) and stubby severed artery stumps on top that vent sparks and smoke.
- The prison: a heavy shell of blackened cast iron and riveted furnace plate (#2a1814, #3a2018, #1a0c0a) wrapped tightly around the heart — curved iron bands, a few bolted plates and a grated front, with gaps and cracks through which the molten heart bulges and glows. Engraved alchemical sigils on the bands (#c45a3a). A few broken chains dangle from the bottom.
- Silhouette: compact, round/heart-shaped mass, clearly floating — embers and droplets of molten slag drip and fall from beneath it.

IMPORTANT — AVOID: no legs, no arms, no humanoid torso, no tower/monolith shape, no furnace building, no ground contact.

FRAMES:
1. Idle: heart mid-beat, floating.
2–4. Float cycle: slow vertical bob (up / middle / down) synced with a heartbeat — heart swells and pushes against the iron bands, then contracts; glow brightens on each beat.
5. Attack windup: heart swells violently, iron bands strain and glow red-hot, cracks widen with white light.
6. Attack release: massive pulse — molten light bursts out through every gap in the cage as a ring of fire/sparks.
```

---

## 5. Frost Mite → `frost-mite.png` (24×24)

```text
Generate a single 2D pixel-art spritesheet for one enemy in a "Dark Hermetic Alchemy" survivor roguelite.

TECHNICAL RULES:
- One horizontal strip of exactly 6 equal square frames, left to right, same creature in every frame, same scale, same ground line.
- Frame order: [1: Idle] [2–4: Walk cycle] [5–6: Attack].
- Pure flat white background (#FFFFFF). No floor, no ground shadow, no fog, no gradients, no text, no labels, no frame borders.
- Generous white padding between frames so they slice cleanly.
- Chunky 16-bit pixel art at ~24x24 px scale (Blasphemous / Nuclear Throne / Vampire Survivors feel). Crisp 1px outline #08101a.
- 3/4 top-down arena view, creature faces RIGHT. Readable silhouette over micro-detail.

CREATURE — FROST MITE ("Rime-Bitten Husk", small fodder):
Razor-sharp shards of alchemical salt and frozen mercury skittering in packs. Jagged deep-navy and glacial-blue crystalline shell (#1a3a52, #0e2438), a glowing cyan quicksilver core (#44ddff, #e8f6ff), spiky frost-crystal legs.

FRAMES: 1 idle, 3 rapid skittering walk frames, 2 crystalline lunge / shatter attack frames.
```

---

## 6. Frost Spitter → `frost-spitter.png` (28×28)

```text
Generate a single 2D pixel-art spritesheet for one enemy in a "Dark Hermetic Alchemy" survivor roguelite.

TECHNICAL RULES:
- One horizontal strip of exactly 6 equal square frames, left to right, same creature in every frame, same scale, same ground line.
- Frame order: [1: Idle] [2–4: Walk cycle] [5–6: Attack].
- Pure flat white background (#FFFFFF). No floor, no ground shadow, no fog, no gradients, no text, no labels, no frame borders.
- Generous white padding between frames so they slice cleanly.
- Chunky 16-bit pixel art at ~28x28 px scale (Blasphemous / Nuclear Throne / Vampire Survivors feel). Crisp 1px outline #08101a.
- 3/4 top-down arena view, creature faces RIGHT. Readable silhouette over micro-detail.

CREATURE — FROST SPITTER ("Brine Condenser", ranged fodder):
A LIVING creature — a bloated, tick-like / grub-like rime parasite engorged on freezing brine. Think a swollen living ice-beast / siphon-grub, not laboratory glassware.
- Body: lumpy, bloated abdomen with dark glacier-chitin and frozen rime hide (#163044, #0e2438) stretched tight over glowing pale-cyan pressurized brine sacs (#7ad4ff, #44ddff, #f4fbff) visible beneath frosty translucent plates.
- Head: low, hunched insectoid head with a long needle-sharp proboscis / siphon snout pointed forward-right, and small milky frost eyes (#f4fbff).
- Legs: four sharp, jointed insectoid claws (#102238, #2a4a66) dragging the heavy swollen belly; low, crawling posture.
- Details: dripping sub-zero brine from the proboscis, frosted rime spines along the back, pale icy vapor dripping from the seams.

IMPORTANT — AVOID: do NOT draw an alembic flask, glass bottle, test tube, retort, beaker, vial, perfume bottle, teapot, or static chemistry glassware. No symmetric round glass container shape, no cork or stopper, no copper distillation coil, no tripod lab stand. It must read instantly as an animal-like or insectoid monster, not laboratory equipment.

FRAMES: 1 idle (brine sac gently pulsing with pale light), 3 creeping / skittering crawl frames dragging its heavy abdomen, 2 attack frames (abdomen contracts hard to build pressure, then proboscis thrusts forward spitting a sharp needle-ice projectile to the right).
```

---

## 7. Frost Warden → `frost-warden.png` (40×40 nebo 52×52)

```text
Generate a single 2D pixel-art spritesheet for one enemy in a "Dark Hermetic Alchemy" survivor roguelite.

TECHNICAL RULES:
- One horizontal strip of exactly 6 equal square frames, left to right, same creature in every frame, same scale, same ground line.
- Frame order: [1: Idle] [2–4: Walk cycle] [5–6: Attack].
- Pure flat white background (#FFFFFF). No floor, no ground shadow, no fog, no gradients, no text, no labels, no frame borders.
- Generous white padding between frames so they slice cleanly.
- Chunky 16-bit pixel art at ~52x52 px scale (Blasphemous / Nuclear Throne / Vampire Survivors feel). Crisp 1px outline #08101a.
- 3/4 top-down arena view, creature faces RIGHT. Readable silhouette over micro-detail.

CREATURE — FROST WARDEN ("Cryo-Bound Sentinel", Rime elite):
A heavy dockside hulk armored in glacier-thick salt plate (#2a4a66) and pale rime-ice pauldrons, crowned with jagged frost spires (#7ad4ff). Its chest houses a freezing cryo-core (#44ddff) leaking caustic freezing brine.

FRAMES: 1 sentinel idle, 3 heavy armored march frames, 2 glacial crush attack frames.
```

---

## 8. Frost Sovereign → `frost-sovereign.png` (64×64 nebo 80×80)

```text
Generate a single 2D pixel-art spritesheet for one boss in a "Dark Hermetic Alchemy" survivor roguelite.

TECHNICAL RULES:
- One horizontal strip of exactly 6 equal square frames, left to right, same creature in every frame, same scale, same ground line.
- Frame order: [1: Idle] [2–4: Walk cycle] [5–6: Attack].
- Pure flat white background (#FFFFFF). No floor, no ground shadow, no fog, no gradients, no text, no labels, no frame borders.
- Generous white padding between frames so they slice cleanly.
- Chunky 16-bit pixel art at ~64x64 px scale (Blasphemous / Nuclear Throne / Vampire Survivors feel). Crisp 1px outline #08101a.
- 3/4 top-down arena view, creature faces RIGHT. Readable silhouette over micro-detail.

CREATURE — FROST SOVEREIGN ("Regent of the Frozen Dock", Stage 2 boss):
An ancient alchemical transmutation frozen mid-ascension when the sea-locks broke. A tall, regal, terrifying figure of deep abyssal stone and salt-armor (#1a3048, #163044), wearing an ornate wide crown of pale rime and ice spears (#7ad4ff, #dff6ff, #f4fbff), with a radiant cyan core (#55ffff) and frost-blade arms (#88c8e8).

FRAMES: 1 regal floating/standing idle, 3 advancing stride frames, 2 royal rime-cleave attack frames.
```

---

## 9. Frost Emperor → `frost-emperor.png` (64×64 nebo 90×90)

```text
Generate a single 2D pixel-art spritesheet for one boss in a "Dark Hermetic Alchemy" survivor roguelite.

TECHNICAL RULES:
- One horizontal strip of exactly 6 equal square frames, left to right, same creature in every frame, same scale, same ground line.
- Frame order: [1: Idle] [2–4: Walk cycle] [5–6: Attack].
- Pure flat white background (#FFFFFF). No floor, no ground shadow, no fog, no gradients, no text, no labels, no frame borders.
- Generous white padding between frames so they slice cleanly.
- Chunky 16-bit pixel art at ~90x90 px scale (Blasphemous / Nuclear Throne / Vampire Survivors feel). Crisp 1px outline #08101a.
- 3/4 top-down arena view, creature faces RIGHT. Readable silhouette over micro-detail.

CREATURE — FROST EMPEROR ("Monarch of Absolute Zero", Stage 3 finale boss, the largest enemy):
Entombed at the bottom of the Great Work where heat and motion cease; the final seal-keeper. A colossal, wide, heavily armored dreadnought-monarch of midnight glacier-iron (#102238, #183654), a massive multi-spired crown of pure white and cyan absolute-zero ice crystals (#ffffff, #77ffff, #3d8ad4), broad glacial shoulder bastions, and a blinding white-cyan heart (#77ffff, #ffffff).

FRAMES: 1 monolithic idle, 3 inexorable march frames, 2 absolute-zero nova / cataclysmic strike frames.
```

---

## 10. Astral Watcher → `enemy-astral-sniper.png` (28×28)

```text
Generate a single 2D pixel-art spritesheet for one enemy in a "Dark Hermetic Alchemy" survivor roguelite.

TECHNICAL RULES:
- One horizontal strip of exactly 6 equal square frames, left to right, same creature in every frame, same scale, same hover height.
- Frame order: [1: Idle] [2–4: Float cycle] [5–6: Attack].
- Pure flat white background (#FFFFFF). No floor, no ground shadow, no fog, no gradients, no text, no labels, no frame borders.
- Generous white padding between frames so they slice cleanly.
- Chunky 16-bit pixel art at ~28x28 px scale (Blasphemous / Nuclear Throne / Vampire Survivors feel). Crisp 1px outline #120a0d.
- 3/4 top-down arena view, creature faces RIGHT. Readable silhouette over micro-detail.

CREATURE — ASTRAL WATCHER ("Ocular of the Void", sniper fodder):
A disembodied occult brass-and-aether eye drifting at the edge of sight. Deep void-violet spherical housing (#2a1844, #4a2878) framed by four cardinal antique-brass astrolabe/compass prongs (#c4a35a), with a large glowing lavender-and-cyan iris (#b47aff, #f0e8ff, #44ddff) that focuses a celestial sightline.

FRAMES: 1 hovering idle, 3 drifting / rotating astrolabe-ring frames, 2 pupil-constriction / sightline-charge frames.
```

---

## Cílové soubory v projektu (`web/public/sprites/entities/`)

| # | Catalog ID | Název souboru | Doporučený frame size |
|---|---|---|---|
| 1 | `ember-mite` | `web/public/sprites/entities/ember-mite.png` | `24×24` |
| 2 | `ember-spitter` | `web/public/sprites/entities/ember-spitter.png` | `28×28` |
| 3 | `ember-chaser` | `web/public/sprites/entities/ember-chaser.png` | `40×40` nebo `48×48` |
| 4 | `cinder-heart` | `web/public/sprites/entities/cinder-heart.png` | `64×64` nebo `72×72` |
| 5 | `frost-mite` | `web/public/sprites/entities/frost-mite.png` | `24×24` |
| 6 | `frost-spitter` | `web/public/sprites/entities/frost-spitter.png` | `28×28` |
| 7 | `frost-warden` | `web/public/sprites/entities/frost-warden.png` | `40×40` nebo `52×52` |
| 8 | `frost-sovereign` | `web/public/sprites/entities/frost-sovereign.png` | `64×64` nebo `80×80` |
| 9 | `frost-emperor` | `web/public/sprites/entities/frost-emperor.png` | `64×64` nebo `90×90` |
| 10 | `enemy-astral-sniper` | `web/public/sprites/entities/enemy-astral-sniper.png` | `28×28` |
