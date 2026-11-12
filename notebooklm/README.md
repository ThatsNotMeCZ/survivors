# NotebookLM snapshot

Snapshot herního designu pro **NotebookLM** a Gemini chat mimo Cursor.

`knowledge/` zůstává kanonickým zdrojem pravdy pro agenty v repozitáři.  
Tato složka je **kompletní export pro herního konzultanta**. Čísla v návrzích ber z JSON v `web/src/data/`, ne z halucinací chatu.

**Datum snapshotu:** 2026-11-05  
**Playable stav:** **3 komory (stages)** + finále, **3 unikátní bossové** s autorskými sadami útoků a vyvoláváním přisluhovačů, **2 schránky (vessels)** po 4 dovednostech, **13 vyvážených augmentací** se systémem kritických zásahů, **systém odemykání obsahu**, **The Archives** s trvalou účetní knihou (Ledger), elitní nepřátelé s afixy **Noxious + Shielder**, překážky ve 3 biomech.

---

## Co nahrát do NotebookLM

Nahraj těchto **pět souborů** (ne README):

1. `00-consultant-brief.md` — role konzultanta, 6 zákonů designu, jak navrhovat nový obsah, slovník display vs interní ID
2. `01-game-design-spec.md` — kompletní herní specifikace (pohyb, souboj, komory, bossové, itemy, director, HUD)
3. `02-catalog-numbers.md` — přesná čísla ze zdrojových JSON souborů (entity, skilly, loop, překážky, itemy)
4. `03-scope-slice-vs-v1.md` — LIVE / TARGET v1 / ZAKÁZÁNO a tabulka nejčastějších omylů
5. `04-lore-archives-and-unlocks.md` — alchymistické pozadí Velkého díla, struktura Archívu, bestiář a pravidla odemykání

> V NotebookLM otevři Notebook → Sources → Upload. Po nahrání ověř, že odpovědi citují tyto zdroje, nikoliv obecné mechaniky z Vampire Survivors či Risk of Rain 2.

---

## Jak aktualizovat

1. Po změnách v kódu, JSON datech nebo pravidlech nejprve uprav `knowledge/` a `web/src/data/*.json`.
2. Aktualizuj soubory v `notebooklm/` (hlavně tabulky v `02-catalog-numbers.md` a sekce ve specifikaci).
3. V NotebookLM **odstraň staré sources** a nahraj těchto pět souborů znovu.
4. Aktualizuj datum snapshotu nahoře v souborech.

*Poznámka:* Nenahrávej složku `knowledge/` zároveň s touto složkou — duplicitní zdroje matou jazykový model při rozlišování stavu LIVE a TARGET.

---

## Rozdíly proti snapshotu 2026-10-21

- **3 plnohodnotné komory (Stages):** Přibyla finální komora **Glacial Tomb** (`glacial-tomb` — *Rubedo & The Great Seal*).
- **Kompletní Boss Duel System:**
  - V momentě spawnu bosse Director **zastaví credit spawny** drobotiny i elit; aréna patří souboji s bossem.
  - Všichni 3 bossové mají unikátní autorské kity útoků (salvy, padající meteority s lávou, mrazivé kužely, ledové vězení, celoarénový pulz r=620, rotující stopovací aether laser).
  - Bossové mají enrage fázi při 50 % HP a vyvolávají vlastní miniony (`Kiln Brood`, `Rime Brood`, `Imperial Guard`, `Brine Retinue`).
  - Vlastní GLSL shadery pro boss hazardy a arénové efekty.
- **Nový elitní afix Shielder:** Každá elita má kromě jedu **Noxious** (contact slow, exploze mrtvoly, louže kyseliny) také **Shielder** (+30 % max HP ve formě regenerujícího štítu po 5 s klidu).
- **Systém kritických zásahů (Crit System):** Statistiky `critChance` a `critDamage` jsou plně implementovány v simulaci, datech itemů i zobrazení.
- **Přepracování a vyvážení augmentací (13 itemů):**
  - Common a Uncommon položky jsou čistě pozitivní stavební kameny buildu.
  - Rare a Lunar položky jsou silné dvousečné meče s výraznými tradeoffs.
  - 6 augmentací má specifické odemykací podmínky (zabíjení bossů, elit, drossu, dokončení komor).
- **The Archives & Ledger:**
  - Plnoobrazovkový kodex s 5 svazky (Rites of Motion, Chronicles, Bestiary s 10 entitami, Reliquary s 13 itemy a trvalý Ledger v `localStorage`).
  - Lore fragmenty padající z nepřátel (2.5 % fodder, 25 % elita, 60 % boss).
- **Odemčení druhé postavy:** The Penitent vyžaduje pro své odemčení porážku Frost Sovereigna. Každá postava má vlastní zaměřovač na míru.
- **Překážky Glacial Tomb:** Přibyly unikátní varianty překážek pro 3. biom (Glacial Monolith r=28, Permafrost Crevasse r=68, Volatile Ice Chunk r=14). Poloměr pilířů v datech upraven na 28 px a volatilních nádob na 14 px.
- **Sál a vizuál:** Celoobrazovkový WebGL fragment shader v pozadí Sálu s aetherickým kouřem a sigiliemi.
- **Nový soubor pro konzultanta:** Vytvořen dedikovaný `04-lore-archives-and-unlocks.md` pro konzultace narativu a systémů odemykání.
