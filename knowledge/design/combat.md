# Combat (locked)

Verb: **A — player aims primary.**

Gameplay reads **actions** (`move`, `aim`, `fire_primary`, `fire_secondary`, `utility`, `special`, `pause`). `aim` is a vector (mouse cursor or right stick). Default keyboard/mouse binds for the web client:

| Bind | Action |
|---|---|
| WASD | `move` |
| Mouse | `aim` (character faces aim) |
| Hold LMB | `fire_primary` along aim |
| RMB | `fire_secondary` (aimed press) |
| Shift / Space | `utility` dash with i-frames |
| Q | `special` (aimed press) |
| Esc / P | `pause` (web: HTML overlay; sim frozen). Use **P** in itch fullscreen so Esc does not drop fullscreen first |

Primary never auto-aims and never fires without a held/pressed input. Screen-clear and orbital weapons are banned on primary. Godot maps devices onto the same actions ([future.md](future.md)).

Dash is a press skill: i-frames skip **contact damage and enemy projectiles**. Direction = move vector, or aim if standing. During dash the player is **not** body-separated, so the dash still cuts through a pack.

Homunculus: Ignis Bolt / Piercing Aether / Phase Step / Crucible Cull. The Penitent: Censer Lob / Brimstone Line / Ash Step / Condemnation Tether. The Penitent starts sealed; unseal by slaying the Frost Sovereign in Rime Dock. Numbers: `web/src/data/skills.json`.

## Bodies

CPU AABB + spatial hash. Enemies separate from each other; the player and enemies push apart while walking (player heavier). Bosses shove fodder aside. No Arcade/Matter on swarms. Contact DPS still applies on remaining overlap.

Obstacles use **circle vs circle** push-out in sim (not Arcade). Numbers: `web/src/data/obstacles.json`. **Bosses collide with pillars** (they are pushed out — no phase-through). Pillar r=28, volatile r=14, hazard r=68.

| Type | Display (Cinder / Rime / Glacial) | Collision |
|---|---|---|
| `pillar` | Obsidian Kiln / Frozen Bollard / Glacial Monolith | Solid vs player, fodder, elites, **and bosses**. Blocks player Bolt and enemy Spitter bolts; hit spark on impact. Astral Watcher lasers die on stone. |
| `hazard` | Slag Fissure / Brine Pool / Permafrost Crevasse | No projectile collision (bolts fly over). Player walking: ×0.65 speed and `4 * difficultyCoefficient` DPS. Player **dashing** (`dashRemain > 0` or `iframeRemain > 0`): clean pass, no slow, no damage. Phase Step 210 vs diameter 136. Fodder/elites: ×0.85 speed while overlapping. Noxious death also spawns a 6s acid pool of this type. |
| `volatile` | Brimstone Urn / Pressurized Rime Cask / Volatile Ice Chunk | Slight movement block (r=14) and projectile block. HP `25 * coefficient`, damaged **only** by player skills (Bolt/Pierce direct hits, Censer Lob impact AoE, Crucible Cull, Brimstone Line, Condemnation Tether; enemies cannot damage volatiles). At 0 HP → `primed` 0.4s telegraph, then `45 * coefficient` AoE r=110 to all enemies and 18 flat to the player if inside without i-frames. **Rime Dock only** also applies 2.0s ×0.7 move slow. Removed after detonation. |

Volatiles are a skill-shot, not an AFK farm. Pillars break edge-kiting; they are not hide spots (fodder path around, spitters still shoot lines of sight that die on stone).

## Ranged

Fodder spitters keep distance, telegraph a line (view aims at player position at windup start), then fire a team-tagged bolt. Player bolts hit enemies; enemy bolts hit the player.

**Astral Watcher** (`enemy-astral-sniper`): off-ring sniper. 1.5s red/blue laser locked at windup start, then hitscan. Pillars block the line. I-frames or stepping off the line negate it. Low HP, high director credit.

## Elites

Any non-boss spawn can mutate. The elite then rolls **50/50**:

- **Shielder** — regenerating Aether Shield (30% max HP, recharges after 5s unharmed). Azure silhouette outline.
- **Noxious** — contact slow. On death, 0.5s corpse telegraph, then a pop and a **6s acid pool** (`hazard`). Kill them outside the Transmutation Circle or the Hold loses floor for the pool duration.

## Boss duel

Director credit spawns halt the moment the Seal Guardian appears. Unique `ai.type: "boss"` kits + summons; see `knowledge/tech/catalog.md`. Enrage at 50% HP. Custom GLSL hazards in `web/src/view/shaders/boss-shaders.ts`.

Run (`ArenaScene`): director-spawned fodder + spitters + snipers + Shielder/Noxious elites, teleporter hold, stage boss, arena obstacles. Primary never auto-aims.
