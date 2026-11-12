# Update 1 — The Ouroboros Loop & Daily Rite

- Date: 2026-11-12
- Itch title: Update 1 — The Ouroboros Loop & Daily Rite

## Itch HTML

```html
<h3>The serpent swallows its tail.</h3>
<p>
  The Frost Emperor no longer ends the working. Slay the monarch and a <strong>gold Ouroboros gate</strong> tears open on the ice. Stand in it to descend into <em>Cycle II</em> — Cinder Yard again, tablets intact, the coefficient still climbing with time. Or press <code>F</code> (or pause → <strong>Seal the Working</strong>) and complete the transmutation.
</p>
<hr>
<ul>
  <li>
    <strong>Ouroboros Cycle:</strong> After Stage 3, choose the loop or the seal. Inventory, level, and run clock persist. Copy Summary now prints <code>Cycle: II · Chamber: Rime Dock</code>.
  </li>
  <li>
    <strong>Daily Rite:</strong> In The Hall, toggle the Alchemical Seed. Today's UTC date locks obstacle layout, the Transmutation Circle, and the order of Hermetic Tablet offers. Paste <code>Seed: #A4F9</code> into the comments and compare workings.
  </li>
  <li>
    <strong>COPY SUMMARY [C]:</strong> Recap now includes Cycle, Chamber, and Seed. Daily runs also stamp the date.
  </li>
</ul>
<p>
  <em>Drop a comment with your summary. The Archives want the deepest Cycle you can hold.</em>
</p>
```

## Player

- Frost Emperor opens a gold portal instead of instantly winning.
- Hold 1.4s in the gate → Cycle II, Cinder Yard, build kept.
- F or pause **Seal the Working** → Transmutation Complete.
- Hall toggle **Daily Rite** shows today's `Seed: #A4F9 · YYYY-MM-DD`.
- COPY SUMMARY includes Cycle + Seed.

## Internal

- `World.cycleIndex`, `runSeed`, `dailyDate`, `offerRng`. Last-stage `stepPortal` wraps via `beginStage(0)`. `completeWorking` is the victory path.
- `updateCoefficient` unchanged (`stageBonus` stays 0). Difficulty on later cycles is continued `runTime * perSecond`.
- Layout RNG XORs `runSeed`. Level-up `weightedPick` uses `offerRng`; item pool sorted by id.
- Settings: `dailyRite`. Smoke seals the first Ouroboros gate so `smoke:loop` still reaches victory.
