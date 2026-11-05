# survivors — LIVE vs TARGET vs ZAKÁZÁNO

Snapshot: **2026-11-05**.  
Když navrhuješ nový herní prvek nebo úpravu, vždy jej zařaď do jedné z těchto kategorií.

---

## LIVE (Plně hratelné v kódu teď)

Aktuální build představuje kompletní **tříkomorový hratelný run** s komprimovaným časováním pro playtestování:

- **Combat verb A:** Hráč míří myší. Držet LMB pálí mířenou primární zbraň. RMB sekundární skill, Shift/Space úhybný dash s i-framy, Q speciální úder.
- **2 schránky (Survivors):**
  - **Homunculus:** Skirmisher, odemčen od začátku, přesný rtuťový zaměřovač. Skilly: Ignis Bolt / Piercing Aether / Phase Step / Crucible Cull.
  - **The Penitent:** Caster/Controller, odemyká se porážkou Frost Sovereigna, liturgický kruhový zaměřovač. Skilly: Censer Lob / Brimstone Line / Ash Step / Condemnation Tether.
- **3 komory (Stages):**
  - Stage 1: Cinder Yard (*Nigredo & Calcination*) → Boss: Cinder Heart.
  - Stage 2: Rime Dock (*Albedo & Fixation*) → Boss: Frost Sovereign.
  - Stage 3: Glacial Tomb (*Rubedo & The Great Seal*) → Boss: Frost Emperor → Dokončení Velkého díla.
- **Boss Duel System:**
  - V momentě příchodu bosse Director **zastaví credit spawny** (žádný nový fodder, spitters ani elity).
  - Bossové fázují skrz pilíře a mají unikátní telegraphované útoky (salvy lávy, meteority s loužemi, mrazivé kužely, ledové vězení, arénový pulz r=620, rotující aether laser).
  - Enrage při 50 % HP (zkrácení cooldownů o ~25 %).
  - Bossové si sami líhnou vlastní miniony (Kiln Brood, Rime Brood, Imperial Guard, Brine Retinue).
- **Elitní modifikátory (LIVE na každé elitě):**
  - **Noxious:** Contact slow ×0.5 na 1.1 s, exploze mrtvoly po 0.5 s, trvalá louže kyseliny (hazard r=68) až do konce stage.
  - **Shielder:** Extra aetherický štít o hodnotě +30 % max HP, který se po 5.0 s bez poškození plně obnoví.
- **13 hermetických augmentací (Itemů):**
  - Vyvážení: Common a Uncommon jsou pozitivní stavební kameny, Rare a Lunar jsou silné dvousečné meče s rizikem.
  - Systém kritických zásahů (`critChance`, `critDamage`).
  - Systém odemykání: 6 augmentací vyžaduje splnění podmínek (zabití bossů, elit, drossu, dokončení komory).
- **The Archives & Ledger:**
  - Plnoobrazovkový kodex (`#archives`) přístupný z menu i pauzy: 5 svazků (Rites of Motion, Chronicles, Bestiary s 10 entitami, Reliquary s 13 itemy, Persistent Ledger s trvalými statistikami v `localStorage`).
  - Lore fragmenty padající z nepřátel (2.5 % fodder, 25 % elita, 60 % boss).
- **Arénové překážky ve 3 biomech:**
  - 14 pilířů (r=28 px), 8 hazardů (r=68 px), 9 volatilních nádob (r=14 px) + až 8 dynamických louží kyseliny.
  - Odlišné modely a názvy pro Cinder Yard, Rime Dock i Glacial Tomb.
- **Audiovizuální podoba:**
  - Aetherický WebGL fragment shader v pozadí Sálu (The Hall).
  - GLSL shadery pro boss hazardy a arénové efekty.
  - Vlastní skladby pro menu, stage a jednotlivé bossy přes Web Audio bus.

---

## TARGET v1 (Plánováno pro plnou produkční verzi v1)

- **Produkční časování:** Prodloužení délky runu na standardních ~15–20 minut (~5–6 minut na komoru, kruh v minutě ~4, hold ~60 s) namísto současného zrychleného playtest tempa.
- **Náhodný roll elitních afixů:** Elity budou náhodně losovat mezi modifikátory (Burn, Chain Lightning, Noxious, Shielder) namísto současné kombinace Noxious + Shielder na každé elitě.
- **4. enemy archetyp:** Rozšíření trojice chase / ranged / sniper o čtvrtý výrazný archetyp chování nepřátel.

---

## ZAKÁZÁNO (Nikdy nenavrhovat)

- Auto-aim nebo auto-fire na primární zbrani. Hráč musí aktivně mířit a držet střelbu.
- Obrazovku mažící pasivní aury (orbital garlic) nebo evoluce, které smažou celou arénu.
- AFK výhry (stát za sloupem po celou dobu rituálu, nechat miniony umírat o zeď).
- Čisté generické `+damage` nebo `+HP` augmentace v kategorii Rare a Lunar bez odpovídajícího rizika či tradeoffu.
- Kooperativní multiplayer (ve v1 je hra striktní singleplayer zážitek).
- Přeplácaný pool 100+ zbytečných itemů a 20 postav.
- Nekonečné prázdné travnaté louky bez překážek, krytů a hazardů.

---

## Časté omyly konzultantů (Pozor na záměny!)

| Zastaralý předpoklad / Chyba | Co je LIVE ve skutečnosti |
|---|---|
| Jen 2 stage a 2 bossové | **3 stage a 3 unikátní bossové** (včetně Glacial Tomb & Frost Emperor) |
| Bossové jsou jen tupí chase chodiči | **Bossové mají unikátní sady útoků**, enrage fází, hazardy a miniony |
| Director dál spawnuje během bosse | **Director spawny kreditů ZASTAVÍ**, duel je čistý |
| Všechny itemy mají negativní postih | **Common a Uncommon jsou čistě pozitivní**, Rare a Lunar mají tradeoff |
| Elity mají jen Noxious jed | **Elity mají Noxious jed i Shielder regenerující štít** |
| Pilíř má poloměr 52 px | **Pilíř má poloměr 28 px** (přizpůsobeno přesné kolizi) |
| Ignis Bolt má cooldown 0.16 s | **Ignis Bolt má cooldown 0.28 s** |
| Žádný systém odemykání | **The Penitent a 6 itemů mají unlock podmínky** v Archívu |
| Všechny itemy jsou od začátku v nabídce | **Zamčené itemy se v draftu neobjeví**, dokud nesplníš podmínku |
