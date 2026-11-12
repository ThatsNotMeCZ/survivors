# Open questions

## Player verb (hands every second)

- A — player aims primary (most RoR2, strongest anti-idle)
- B — auto-aim, dash/position is the skill
- C — primary auto, secondary and ultimate are aimed

**Locked: A** (2026-10-20). Primary is player-aimed (mouse or aim vector). No auto-fire on primary. Fall back to C only if browser aiming feels bad in playtests. Touch and co-op do not unlock auto-aim.

See [combat.md](combat.md).

## Settled since lock

- **Three chambers live** (2026-11): Cinder Yard → Rime Dock → Glacial Tomb. Production remaining work is clock stretch, not a fourth biome.
- **Elite affixes live:** Shielder and Noxious, 50/50 on any non-boss spawn. Extra affixes (burn, chain) stay future — do not add them to the slice.
- **The Penitent** is unlockable (Frost Sovereign in Rime Dock), not a start vessel.
- **Bosses collide with pillars.** Phase-through was reverted so they cannot crush the player into stone.
- **Commons/uncommons are clean grafts.** Only rare and lunar cut both ways.
- **Dual client** (2026-11-12): Phaser `web/` ships itch. Godot 4.7 typed GDScript is the native sibling. itch stays Phaser (no second HTML5 ship). See [tech/clients.md](../tech/clients.md).
- **Godot language: typed GDScript** (2026-11-12; C# lock dropped before any `.cs` shipped). Agent-first. `.tscn` via Godot MCP / editor UndoRedo, never as text. See [tech/godot.md](../tech/godot.md).
- **Localization: Godot only.** `tr("KEY")` + `locale/*.csv`. Web stays English in TS/JSON.
- **Co-op shape:** post-v1 online 2–4, host authority, `Array[InputFrame]`. Not split-screen, not lockstep. See [future.md](future.md).
- **Workshop:** data packs only (JSON, sprites, locale, audio). No `.gd` / C# / native code from Workshop.
- **Controller:** Godot reads actions from day one. Rebind UI later.
- **Mobile:** post-Steam. Control UI + safe area now so touch can plug in later. itch "Mobile friendly" stays off.
