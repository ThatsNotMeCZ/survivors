import type { SkillSlot } from '../data/schema';

export type SlotBits = Record<SkillSlot, boolean>;

/** View-filled, sim-consumed. No Phaser types. */
export type InputFrame = {
  moveX: number;
  moveY: number;
  aimX: number;
  aimY: number;
  held: SlotBits;
  pressed: SlotBits;
};

export function emptySlots(): SlotBits {
  return { primary: false, secondary: false, utility: false, special: false };
}

export function emptyCds(): Record<SkillSlot, number> {
  return { primary: 0, secondary: 0, utility: 0, special: 0 };
}

export function emptyInput(): InputFrame {
  return {
    moveX: 0,
    moveY: 0,
    aimX: 0,
    aimY: 0,
    held: emptySlots(),
    pressed: emptySlots(),
  };
}
