export const ITEM_ICON_PX = 24;
export const ITEM_CHIP_PX = 32;
export const ITEM_CHOICE_PX = 96;

export type ItemChipDef = {
  id: string;
  name: string;
  stacks: number;
  rarity: string;
};

export function itemSpriteSrc(id: string): string {
  return `sprites/items/${id}.png`;
}

export function makeItemIcon(
  id: string,
  name: string,
  className: string,
  displayPx?: number,
): HTMLImageElement {
  const img = document.createElement('img');
  img.className = className;
  img.alt = name;
  if (displayPx !== undefined) {
    img.width = displayPx;
    img.height = displayPx;
  }
  img.src = itemSpriteSrc(id);
  img.decoding = 'async';
  img.draggable = false;
  return img;
}

export function makeItemChip(
  item: ItemChipDef,
  className = 'item-chip',
  displayPx?: number,
): HTMLElement {
  const chip = document.createElement('span');
  chip.className = className;
  chip.dataset.rarity = item.rarity;
  chip.dataset.itemId = item.id;
  chip.title = item.stacks > 1 ? `${item.name} ×${item.stacks}` : item.name;
  const icon = makeItemIcon(item.id, item.name, 'item-chip-icon', displayPx);
  icon.addEventListener('error', () => {
    icon.remove();
    if (!chip.querySelector('.item-chip-fallback')) {
      const fallback = document.createElement('span');
      fallback.className = 'item-chip-fallback';
      fallback.textContent = item.name.slice(0, 1).toUpperCase();
      chip.prepend(fallback);
    }
  });
  chip.appendChild(icon);
  if (item.stacks > 1) {
    const stacks = document.createElement('span');
    stacks.className = 'item-chip-stacks';
    stacks.textContent = `x${item.stacks}`;
    chip.appendChild(stacks);
  }
  return chip;
}
