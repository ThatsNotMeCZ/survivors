# Update 2 — Distinct Seal Guardians

- Date: 2026-11-17
- Itch title: Update 2 — Distinct Seal Guardians

## Itch HTML

```html
<h3>Three seals, three workings.</h3>
<p>
  The chamber guardians no longer share a mite brood. Each duel now presses a different verb. This pass lives in the native Godot build. The itch HTML5 working still uses the previous kits.
</p>
<hr>
<ul>
  <li>
    <strong>Cinder Heart:</strong> Kiln Brood is gone. Falling Clinker leaves a wider lava disk. Slag Spray flies faster. The core is thinner, so the kiln does not outlast its threat.
  </li>
  <li>
    <strong>Frost Sovereign:</strong> Rime Brood still answers a failed Prison, but two mites at a time, three live at most.
  </li>
  <li>
    <strong>Frost Emperor:</strong> Imperial Guard and Brine Retinue are withdrawn. Absolute Zero arrives later, hits a smaller ring, and yields a breath before the spear or Aether Laser. The beam tracks slower.
  </li>
</ul>
<p>
  <em>Dash the pulse. Hide the beam behind stone. The monarch no longer fills the ice with husks.</em>
</p>
```

## Player

- Cinder Heart no longer summons Ember Mites. Lava pools are larger. The fight is shorter.
- Frost Sovereign still summons Frost Mites after Prison, in a smaller pack.
- Frost Emperor no longer summons mites or spitters. Absolute Zero is later and smaller, and does not chain straight into the laser.

## Internal

- Godot `data/catalog/entities.json` only. Phaser `web/src/data/entities.json` unchanged until a web-named pass.
- Cinder Heart: `maxHp` 1100, no `Kiln Brood`, fan speed 280, meteor/pool r=80, meteor CD 3.8.
- Frost Sovereign: Rime Brood `count` 2, `maxAlive` 3.
- Frost Emperor: dropped both summons. Pulse CD 16, r=420, dmg 28, slow 0.55/1.4s, `initialCooldown` 8, `recovery` 1.2. Laser `trackSpeed` 110, `hitRadius` 20, duration 1.8, `recovery` 1.2.
- `sim_boss.gd`: `initialCooldown` overrides first-cast delay. `recovery` floors every other attack CD when pulse windup ends or laser channel ends.
- Knowledge: `catalog.md`, `combat.md`, `gameloop.md`.
- `loop_smoke.gd` victory at runTime 351.6s (`godot --headless --path Godot/hermetic-rifts -s res://src/smoke/loop_smoke.gd`). First run died on Sovereign at 257s (kiter flake). MCP `play_scene` reached a live Cinder Yard drop. Full live Emperor duel not waited through; smoke still slews the last guardian on spawn.
