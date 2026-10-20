# Combat (locked)

Verb: **A — player aims primary.**

| Input | Action |
|---|---|
| WASD | move |
| Mouse | aim (character faces cursor) |
| Hold LMB | fire primary along aim |
| RMB | secondary (aimed press) |
| Shift / Space | utility dash with i-frames |
| Q | ultimate (aimed press) |
| Esc | pause (HTML overlay; sim frozen) |

Primary never auto-aims and never fires without a held/pressed input. Screen-clear and orbital weapons are banned on primary.

Dash is a press skill: i-frames skip **contact damage and enemy projectiles**. Direction = move vector, or aim if standing. During dash the player is **not** body-separated, so the dash still cuts through a pack.

Homunculus: Ignis Bolt / Piercing Aether / Phase Step / Crucible Cull. The Penitent: Censer Lob / Brimstone Line / Ash Step / Condemnation Tether. Numbers: `src/data/skills.json`.

## Bodies

CPU AABB + spatial hash. Enemies separate from each other; the player and enemies push apart while walking (player heavier). No Arcade/Matter on swarms. Contact DPS still applies on remaining overlap.

Obstacles use **circle vs circle** push-out in sim (not Arcade). Numbers: `src/data/obstacles.json`.

| Type | Display (Cinder / Rime) | Collision |
|---|---|---|
| `pillar` | Obsidian Kiln / Frozen Bollard | Solid vs player, fodder, elites. **Bosses phase through** (Cinder Heart, Frost Sovereign) so they never soft-lock. Blocks player Bolt and enemy Spitter bolts; hit spark on impact. |
| `hazard` | Slag Fissure / Brine Pool | No projectile collision (bolts fly over). Player walking: ×0.65 speed and `4 * difficultyCoefficient` DPS. Player **dashing** (`dashRemain > 0` or `iframeRemain > 0`): clean pass, no slow, no damage. Phase Step 210 vs diameter 136. Fodder/elites: ×0.85 speed while overlapping. |
| `volatile` | Brimstone Urn / Pressurized Rime Cask | Slight movement block (r=22) and projectile block. HP `25 * coefficient`, damaged **only** by player-aimed Bolt. At 0 HP → `primed` 0.4s telegraph, then `45 * coefficient` AoE r=110 to all enemies and 18 flat to the player if inside without i-frames. Rime Dock also applies 2.0s ×0.7 move slow. Removed after detonation. |

Volatiles are a skill-shot, not an AFK farm. Pillars break edge-kiting; they are not hide spots (fodder path around, bosses crush through, spitters still shoot lines of sight that die on stone).

## Ranged

Fodder spitters keep distance, telegraph a line (view aims at player position at windup start), then fire a team-tagged bolt. Player bolts hit enemies; enemy bolts hit the player.

**Astral Watcher** (`enemy-astral-sniper`): off-ring sniper. 1.5s red/blue laser locked at windup start, then hitscan. Pillars block the line. I-frames or stepping off the line negate it. Low HP, high director credit.

**Noxious elites** (`elite-poison-slow`): every elite. Contact applies a slow. On death, 0.5s corpse telegraph, then a pop and a **permanent acid pool** (`hazard`). Kill them outside the Transmutation Circle or the Hold loses floor.

Run (`ArenaScene`): director-spawned fodder + spitters + snipers + noxious elites, teleporter hold, stage boss, arena obstacles. Primary never auto-aims.
