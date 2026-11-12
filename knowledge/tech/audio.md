# Audio

Files live in `web/public/audio/`. Phaser stays `audio.noAudio: true` — the hall boots before Phaser, so playback is a Web Audio bus in `web/src/audio/`. Settings (master / SFX / music / mute) drive that bus live.

## Layout

| Path | Role |
|---|---|
| `sfx/ui/` | Hall, pause, settings, tablets, recap stings |
| `sfx/combat/` | Skills, hits, dashes, elite / boss |
| `sfx/world/` | Gems, obstacles, death |
| `music/menu/` | Hall playlist. Stops when a run starts. |
| `music/maps/{stage-id}/` | Stage playlist. Ids match `loop.json` `stages[].id`. |
| `music/boss/{boss-id}/` | Boss playlist. Ids match `entities.json` boss id (`cinder-heart`, etc.). Crossfades with stage bed. |
| `music/overlay/` | Shared chill playlist. Pause (and nested pause screens) only. |

Live maps: `cinder-yard`, `rime-dock`, `glacial-tomb`. Live bosses: `cinder-heart`, `frost-sovereign`, `frost-emperor`. A new stage gets a new `music/maps/{id}/` folder with the same id. Boss tracks live in `music/boss/{boss-id}/`.

## Playlist

A folder is a playlist, not a single `bed.ogg`. Vite writes `web/public/audio/manifest.json` on `dev` / `build` by scanning those folders. SFX `volume` values already in the file survive a rescan.

- 1 track → loop
- 2+ → shuffle bag, no immediate repeat, ~1.2s crossfade on `ended`
- Prefer `.ogg`. If `Track.ogg` exists, `Track.mp3` is ignored
- Ignore `.zip`, `.gitkeep`, images

Drop a track in the folder, restart `bun run dev`, it plays.

## Mix

Two music channels: **bed** and **overlay**. Overlay never replaces the bed.

| Screen | Bed | Overlay |
|---|---|---|
| Hall (menu) | `music/menu/` | off |
| Run / HUD | `music/maps/{stage}` | off |
| Boss fight | `music/boss/{boss-id}` | off |
| Pause | same map bed, ducked | `music/overlay/` |
| Level select | selected map bed, ducked | `music/overlay/` |
| Level-up / recap | map bed | off |
| `?smoke=1` | silent | off |

Level-up tablets stay on the map bed with overlay off — short pick, not a chill screen. Overlay is shared across maps; map identity stays in the ducked bed.

Crossfade beds on stage wipe (`beginStage`) and when a boss spawns/dies (~1.2s crossfade). Fade overlay in/out with pause. Overlay rides the music bus (`musicVolume` + mute). No extra slider.

Browser autoplay: bed starts after the first click or key. Do not `AudioContext.resume()` on boot — Chrome logs a violation unless `navigator.userActivation.isActive` (or the unlock `pointerdown` / `keydown` listeners).

## SFX

Kebab-case `.ogg` in `sfx/{ui,combat,world}/`. Filename stem is the id (`click.ogg` → `click`). Swap the file, keep the name.

Each clip in `manifest.json` is `{ src, volume }`. `volume` is linear gain **0–2** (default **1**), multiplied with the SFX slider. Kenney packs land at different loudness — set `volume` per id, then refresh. Vite rescans folders on `dev` / `build` and **keeps** existing `volume` values; new files start at 1.

Kenney CC0 packs in `sources/kenney_*` are the current placeholders. Hits/deaths/muzzle/gems are rate-limited.

Sim emits FX only (`FX_HIT`, `FX_HURT`, `FX_GEM`, …). `ArenaScene.consumeFx` plays the sting. `web/src/sim/` does not import audio.
