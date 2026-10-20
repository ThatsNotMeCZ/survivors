# Combat (locked)

Verb: **A — player aims primary.**

| Input | Action |
|---|---|
| WASD | move |
| Mouse | aim (character faces cursor) |
| Hold LMB | fire primary along aim |
| Shift / Space | dash with i-frames (`utility` skill) |
| Esc | pause (HTML overlay; sim frozen) |

Primary never auto-aims and never fires without a held/pressed input. Screen-clear and orbital weapons are banned on primary.

Dash is a press skill: i-frames skip **contact damage and enemy projectiles**. Direction = move vector, or aim if standing. During dash the player is **not** body-separated, so the dash still cuts through a pack.

Secondary / special slots exist on the survivor but are unbound. Content: `knowledge/tech/catalog.md`.

## Bodies

CPU AABB + spatial hash. Enemies separate from each other; the player and enemies push apart while walking (player heavier). No Arcade/Matter on swarms. Contact DPS still applies on remaining overlap.

## Ranged

Fodder spitters keep distance, telegraph a line, then fire a team-tagged bolt. Player bolts hit enemies; enemy bolts hit the player. Standing still is punished by snipers, not by extra HP sponges.

Run (`ArenaScene`): director-spawned fodder + spitters + elites, teleporter hold, stage boss. Primary never auto-aims.
