# Update 3 - Pixel Combat Shaders and Guiding Fissures

- Date: 2026-11-19
- Itch title: Update 3 - Pixel Combat Shaders and Guiding Fissures

## Itch HTML

```html
<h3>Every eruption, puddle, and fissure now snaps to the stone grid.</h3>
<p>
  Combat and arena shaders in the native Godot build now share the same 2-world-pixel grid, 4x4 Bayer dither cuts, and Resurrect 64 palette ramps as the Alchemical Vents. The itch HTML5 build stays on its existing shaders.
</p>
<hr>
<ul>
  <li>
    <strong>Seal Guardian Geysers and Hazards:</strong> Falling Clinker and alchemical geysers now telegraph with bubbling molten wells and erupt into a vertical pixel fountain with concentric splash ripples before settling into lava, frost, or caustic pools. Cinder Heart paces Slag Geyser casts with a longer cooldown and recovery window. Dash-slam telegraphs now render on the pixel grid.
  </li>
  <li>
    <strong>Elite Puddles and Surface Zones:</strong> Post-mortem noxious acid pools, molten burn trails, frozen patches, and smoke clouds splash outward, form a dark meniscus rim with popping pixel bubbles, and evaporate through dither erosion.
  </li>
  <li>
    <strong>Warden Ground-Slam and Encounter Pacing:</strong> Ember Wardens and Frost Wardens hold their raised-fist windup pose until the strike lands, then pound the floor from the point of impact with a scorched crater, concentric shockwave arcs, and flying debris chunks. Later-chamber enemies, wardens, specialists, and elites now gate behind higher difficulty thresholds so early Cinder Yard openings remain focused on kiln fodder.
  </li>
  <li>
    <strong>Vessel Workings and Guiding Fissures:</strong> Censer fireballs, Crucible seals, Brimstone flame walls, Hex Sigils, Censure Bells, and Solar Beams now render on the world-pixel grid. Seven arena-wide fissures pulse inward across the flagstones from the start of each stage to guide the vessel toward the Transmutation Circle and open portal.
  </li>
</ul>
```

## Player

- Boss geysers erupt with a two-layer magma or acid plume and leave palette-locked puddles.
- Elite acid puddles and burn trails splash in, bubble on the pixel grid, and erode cleanly as they expire.
- Ember Warden and Frost Warden slam effects match their ground-pound animation frame and leave cooling cracks.
- Player skill impacts, Brimstone lines, Hex Sigils, and beams match the pixel resolution of the arena floor.
- Seven long fissures across the arena floor pulse inward toward the Transmutation Circle and portal so the objective can be located from anywhere on the map, without the left-side cone seam artifact.

## Internal

- Added `Godot/hermetic-rifts/assets/shaders/fx_pixel.gdshaderinc` (`FX_CELL_PX = 2.0` via `u_quad_px`, Bayer threshold helper `fx_cut`, 5-stop Resurrect 64 ramps `fx_ramp` with `lut_sample`, sector-local `fx_fissure_field`, and parabolic `fx_debris_burst`).
- Added `Godot/hermetic-rifts/assets/shaders/boss_geyser.gdshader` and `FxIds.GEYSER_BURST` (`23`) emitted by `SimBossHazards` on `HAZ_METEOR` detonation.
- Rewrote `hazard_pool.gdshader`, `miasma_pool.gdshader`, `cleave_slash.gdshader`, `boss_shockwave.gdshader`, `skill_impact.gdshader`, `brimstone_line.gdshader`, and `boss_laser.gdshader` to use world-pixel quantization and Resurrect 64 ramps.
- Fixed the `-X` (`atan2` `+-PI`) cone artifact in `circle_cracks.gdshader` by evaluating trunk and fork offsets in sector-local coordinates (`along_px`, `perp_px`) and added 7 arena-wide guiding fissures (`u_guide_active`) pulsing inward toward the circle and portal.
- Updated `src/view/arena_view.gd` to sync cleaver animation frames with sim state (frame 4 during windup, frame 5 during strike), maintain a 0.45s fissure afterglow (`_cleave_tail`), render boss `dash_slam` telegraphs via pixel shaders, and pass `u_quad_px` to all combat FX materials.
- Added `scenes/debug/fx_gallery.tscn` and `src/tools/fx_gallery.gd` for automated shader and snapshot verification.
