# NotebookLM snapshot

Snapshot herního designu pro **NotebookLM** a Gemini chat mimo Cursor.

`knowledge/` zůstává kanonické pro agenty v Cursoru.  
Tato složka je **export pro konzultanta**. Čísla ber z JSON v `src/data/`, ne z chatu.

**Datum snapshotu:** 2026-10-20  
**Playable slice:** 2 stage + boss, 1 survivor, 12 itemů, aimed primary, překážky.

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

## Rozdíl proti starému draftu (8 itemů)

Tento snapshot opravuje draft, který měl 8 itemů a žádné překážky:

- **12 itemů** live, včetně lunar **Pale Moon Covenant**
- Dark Hermetic názvy (Homunculus, Ignis Bolt, Phase Step, Transmutation Circle)
- Arena **obstacles** live (14 pillars, 8 hazards, 9 volatiles)
- Hall: Start, Vessel, How to play, Settings
- Anti-idle má **6. zákon** (překážky jsou tlak, ne cover)
- Spitter bolt damage **5** (ne 6/7)
- Stage 1 elite display: **Ember Warden**
