export const SKILL_ICON_PX = 24;
export const SKILL_SLOT_PX = 40;

export function skillSpriteSrc(id: string): string {
  return `sprites/skills/${id}.png`;
}

export function makeSkillIcon(
  id: string,
  name: string,
  className: string,
  displayPx = SKILL_ICON_PX,
): HTMLImageElement {
  const img = document.createElement('img');
  img.className = className;
  img.alt = name;
  img.width = displayPx;
  img.height = displayPx;
  img.src = skillSpriteSrc(id);
  img.decoding = 'async';
  img.draggable = false;
  return img;
}
