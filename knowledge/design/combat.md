# Combat (locked)

Verb: **A — player aims primary.**

| Input | Action |
|---|---|
| WASD | move |
| Mouse | aim (character faces cursor) |
| Hold LMB | fire primary along aim |
| Shift / Space | Phase Step (`dash` skill) with i-frames |
| Esc | pause (HTML overlay; sim frozen) |

Primary never auto-aims and never fires without a held/pressed input. Screen-clear and orbital weapons are banned on primary.

Dash is a press skill: i-frames skip **contact damage and enemy projectiles**. Direction = move vector, or aim if standing. During dash the player is **not** body-separated, so the dash still cuts through a pack.

Secondary / special slots exist on the survivor but are unbound. Content: `knowledge/tech/catalog.md`.

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

Fodder spitters keep distance, telegraph a line (view aims at player position at windup start), then fire a team-tagged bolt. Player bolts hit enemies; enemy bolts hit the player. Standing still is punished by snipers, not by extra HP sponges.

Run (`ArenaScene`): director-spawned fodder + spitters + elites, teleporter hold, stage boss, arena obstacles. Primary never auto-aims.
