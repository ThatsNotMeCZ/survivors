# Audio

Files live in `public/audio/`. Phaser still boots with `audio.noAudio: true`; this is the layout for when audio binds. Settings already persist master / SFX / music / mute.

## Layout

| Path | Role |
|---|---|
| `sfx/ui/` | Hall, pause, settings, tablets, recap stings |
| `sfx/combat/` | Skills, hits, dashes, elite / boss |
| `sfx/world/` | Gems, Transmutation Circle, obstacles, death |
| `music/menu/` | Hall bed. Stops when a run starts. |
| `music/maps/{stage-id}/` | Stage bed. Ids match `loop.json` `stages[].id`. |
| `music/overlay/` | One shared chill layer. Pause and level select only. |

Slice maps: `cinder-yard`, `rime-dock`. A new stage gets a new `music/maps/{id}/` folder with the same id.

## Mix

Two music channels: **bed** and **overlay**. Overlay never replaces the bed.

| Screen | Bed | Overlay |
|---|---|---|
| Hall (menu) | `music/menu/` | off |
| Run / HUD | `music/maps/{stage}` | off |
| Pause | same map bed, ducked | `music/overlay/` |
| Level select | selected map bed, ducked | `music/overlay/` |

Level-up tablets stay on the map bed with overlay off — short pick, not a chill screen. Overlay is one file for every map; map identity stays in the ducked bed.

Crossfade beds on stage wipe (`beginStage`). Fade overlay in/out with pause / level select.

## Files

Looping beds: `bed.ogg`. Overlay: `chill.ogg`. SFX: kebab-case `.ogg`. Drop the file in the matching folder.

Overlay rides the music bus (`musicVolume` + mute). No extra slider.
