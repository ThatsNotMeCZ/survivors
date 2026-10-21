# NotebookLM snapshot

Snapshot herního designu pro **NotebookLM** a Gemini chat mimo Cursor.

`knowledge/` zůstává kanonické pro agenty v Cursoru.  
Tato složka je **export pro konzultanta**. Čísla ber z JSON v `src/data/`, ne z chatu.

**Datum snapshotu:** 2026-10-21  
**Playable slice:** 2 stage + boss, **2 survivors** (4 skilly), 13 itemů, aimed primary, překážky, Astral Watcher, Noxious elite.

## Co nahrát do NotebookLM

Nahraj jen tyto čtyři soubory (ne README):

1. `00-consultant-brief.md` — role, zákony, jak navrhovat
2. `01-game-design-spec.md` — kompletní gameplay spec
3. `02-catalog-numbers.md` — přesná čísla z JSON
4. `03-scope-slice-vs-v1.md` — LIVE / TARGET / ZAKÁZÁNO

Notebook → Sources → Upload. Po nahrání ověř, že NotebookLM cituje tyto zdroje, ne obecný VS/RoR2 lore.

## Jak aktualizovat (2 minuty)

1. Po změně combat / itemů / directoru / loopu nejdřív uprav `knowledge/` a `src/data/*.json`.
2. Přepiš soubory v `notebooklm/` tak, aby seděly na kód (hlavně `02-catalog-numbers.md` a sekci 16 v specu).
3. V NotebookLM **smaž staré sources** a nahraj tyto čtyři soubory znovu.
4. Změň datum snapshotu nahoře v každém souboru.

Nenahrávej `knowledge/` zároveň s touto složkou. Duplicitní zdroje Gemini pletou LIVE a TARGET.

## Rozdíl proti snapshotu 2026-10-20

- **2 survivors LIVE:** Homunculus + The Penitent, každý 4 skilly
- Secondary (RMB) a ultimate (Q) **bound a mířené**
- Ignis Bolt cooldown **0.28 s** (ne 0.16)
- LIVE effecty: `projectile` / `dash` / `self-slow` / `delayed-strike` / `slow-line` / `tether`
- **Astral Watcher** sniper LIVE (max 2, cost 30, interval 7 s)
- **Noxious** na každé elitě LIVE (contact slow, corpse pop, permanent acid pool)
- Hall: výběr vesselu, 3 sloupce (Vessel Selection / Archives / Alchemist's Desk)
- Web Audio bus (Phaser `noAudio`)
