# NotebookLM snapshot

Snapshot herního designu pro **NotebookLM** a Gemini chat mimo Cursor.

`knowledge/` zůstává kanonickým zdrojem pravdy pro agenty v repozitáři.  
Tato složka je **kompletní export pro herního konzultanta**. Čísla v návrzích ber z JSON v `Godot/hermetic-rifts/data/catalog/`, ne z halucinací chatu.

**Klient:** Godot 4.7, projekt `Godot/hermetic-rifts/`.  
**Datum snapshotu:** 2026-11-17  
**Playable stav:** **3 komory** + Ouroboros cyklus, **3 unikátní bossové** s autorskými sadami útoků a vyvoláváním přisluhovačů, **2 schránky** po 4 dovednostech, **13 augmentací** se systémem kritických zásahů, **systém odemykání obsahu**, **The Archives** s trvalou účetní knihou (Ledger v `user://records.v1.json`), elitní afixy **Noxious nebo Shielder** (50/50), překážky ve 3 biomech, **Daily Rite**.

---

## Co nahrát do NotebookLM

Nahraj těchto **šest souborů** (ne README):

1. `00-consultant-brief.md` - role konzultanta, 6 zákonů designu, jak navrhovat nový obsah, slovník display vs interní ID
2. `01-game-design-spec.md` - kompletní herní specifikace (pohyb, souboj, komory, Ouroboros, itemy, director, HUD)
3. `02-catalog-numbers.md` - přesná čísla z Godot katalogu (entity, skilly, loop, překážky, itemy)
4. `03-scope-slice-vs-v1.md` - LIVE / TARGET v1 / ZAKÁZÁNO a tabulka nejčastějších omylů
5. `04-lore-archives-and-unlocks.md` - alchymistické pozadí Velkého díla, Chronicles, bestiář a pravidla odemykání
6. `05-behavior-and-systems.md` - AI, stacking, crit, director algoritmus, hold/portal/cycle, save a settings

> V NotebookLM otevři Notebook → Sources → Upload. Po nahrání ověř, že odpovědi citují tyto zdroje, nikoliv obecné mechaniky z Vampire Survivors či Risk of Rain 2.

---

## Jak aktualizovat

1. Po změnách v kódu, katalogu nebo pravidlech nejprve uprav `knowledge/` a `Godot/hermetic-rifts/data/catalog/*.json`.
2. Aktualizuj soubory v `notebooklm/` (hlavně tabulky v `02-catalog-numbers.md` a sekce ve specifikaci a v `05`).
3. V NotebookLM **odstraň staré sources** a nahraj těchto šest souborů znovu.
4. Aktualizuj datum snapshotu nahoře v souborech.

Nenahrávej složku `knowledge/` zároveň s touto složkou. Duplicitní zdroje matou jazykový model při rozlišování stavu LIVE a TARGET.
