# sim/

CPU gameplay lives here: director, combat, movement, spatial hash, pools.

Nothing in this folder may import Phaser. View code reads sim state and draws it.

`world.ts` owns the tick. View passes an `InputFrame`; sim never reads the keyboard.

Skills and items come from `src/data/`. `skills.ts` dispatches effect types. `stats.ts` folds item hooks.
