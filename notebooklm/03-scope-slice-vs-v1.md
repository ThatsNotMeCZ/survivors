# survivors - LIVE vs TARGET vs ZAKÁZÁNO

Snapshot: **2026-11-17**.  
Když navrhuješ nový herní prvek nebo úpravu, vždy jej zařaď do jedné z těchto kategorií.

---

## LIVE (hratelné v Godot teď)

Aktuální build je kompletní **tříkomorový run** s komprimovaným časováním pro playtest. Klient: Godot 4.7.

- **Combat verb A:** Myš míří. Držet LMB pálí mířenou primární zbraň. RMB sekundární skill, Shift/Space dash s i-framy (CD 2.9 / 3.0 s), Q speciální úder, F Seal the Working, Esc/P pauza.
- **2 schránky:**
  - **Homunculus:** Skirmisher, odemčen od začátku. Ignis Bolt / Piercing Aether / Phase Step / Crucible Cull.
  - **The Penitent:** Caster/Controller, odemyká se porážkou Frost Sovereigna. Censer Lob / Brimstone Line / Ash Step / Condemnation Tether.
- **3 komory:** Cinder Yard → Cinder Heart. Rime Dock → Frost Sovereign. Glacial Tomb → Frost Emperor → zlatá brána **Ouroboros**.
- **Ouroboros / Cycle II:** Hold ve zlaté bráně vrací hráče do Cinder Yard s inventářem, XP a `runTime`. **F** nebo pauza → Seal the Working = Transmutation Complete.
- **Daily Rite:** UTC seed layoutu, kruhu a pořadí tablet. Combat RNG neseeduje.
- **Boss duel:** Director zastaví credit spawny. Bossové narážejí na pilíře. Unikátní telegraphované útoky, enrage 50 % HP, vlastní minioni.
- **Elitní afixy (50/50, jeden na elitu):**
  - **Noxious:** Contact slow ×0.5 na 1.1 s, corpse 0.5 s, pop, 6 s acid pool.
  - **Shielder:** Štít 30 % max HP, obnova po 5.0 s bez zásahu.
- **13 augmentací:** Common/Uncommon pozitivní, Rare/Lunar tradeoff. Crit 5 % / ×2. 6 itemů má unlock. Zamčené karty v draftu nejsou.
- **The Archives & Ledger:** 5 svazků. Persistence `user://records.v1.json`. Lore dropy 2.5 % / 25 % / 60 %.
- **Překážky ve 3 biomech:** 14 pilířů r=28, 8 hazardů r=68, 9 volatiles r=14, až 8 dynamických louží.
- **Audio:** Playlisty menu / stage / boss. Pauza pouští overlay over ducked bed. Settings bus Master / SFX / Music / Mute.
- **Alchemist's Desk:** Display mode, monitor, rozlišení, VSync, FPS cap, shake, reduce VFX.

---

## TARGET v1 (plná produkční verze)

- **Produkční časování:** Run ~15-20 minut (~5-6 minut na komoru, kruh v minutě ~4, hold ~60 s) místo komprimovaného slice.
- **Náhodný pool elitních afixů:** Elity budou losovat z širší sady (Burn, Chain Lightning, Noxious, Shielder). LIVE má jen Noxious nebo Shielder.
- **4. enemy archetyp:** Vedle chase / ranged / sniper čtvrtý výrazný vzorec chování.

---

## ZAKÁZÁNO

- Auto-aim nebo auto-fire na primární zbrani.
- Obrazovku mažící pasivní aury (orbital garlic) nebo evoluce, které smažou arénu.
- AFK výhry (stát za sloupem po celou dobu rituálu).
- Čisté generické `+damage` nebo `+HP` v Rare a Lunar bez tradeoffu.
- Kooperativní multiplayer ve v1 (tvar post-v1 existuje, shipping je otevřený).
- Přeplácaný pool 100+ itemů a 20 postav.
- Nekonečné prázdné louky bez překážek a hazardů.

---

## Časté omyly konzultantů

| Zastaralý předpoklad | Co je LIVE |
|---|---|
| Pack popisuje Phaser / HTML overlay / `localStorage` | **Godot 4.7**, Control UI, Ledger `user://records.v1.json` |
| Jen 2 stage a 2 bossové | **3 stage a 3 bossové**, po Emperorovi Ouroboros |
| Frost Emperor končí run | Run končí jen **Seal the Working**; hold v bráně = Cycle II |
| Bossové fázují skrz pilíře | **Bossové kolidují** s pilíři; laser a hitscan umírají na kameni |
| Každá elita má Noxious i Shielder | **50/50 jeden afix** |
| Noxious louže trvá do konce stage | Louže trvá **6 s** |
| Soft cap 32 fodder + 3 elity | **24 fodder + 6 elit + 1 boss** |
| Director `perSecond` 0.006 / `stageBonus` 0.35 | **0.0026 / 0** |
| Ignis Bolt CD 0.16 s, Phase Step CD 0.9 s | Bolt **0.28 s**, Phase Step **2.9 s** |
| Slag Carapace +25 % HP, Waxen Pinions +speed | Carapace **+12 % armor**, Pinions **+35 % hazard ward** |
| Vitriol Veins +60 % dmg | **+55 % damage, −25 % max HP** |
| Pale Moon +75 % dmg / −40 % HP | **+60 % eliteDamage, +75 % critDamage, −25 % armor, −25 % XP** |
| Elity mají jen Noxious | Také **Shielder** (jeden z nich) |
| Všechny itemy v draftu od startu | 6 augmentací a The Penitent mají unlock |
| Pilíř r=52 | Pilíř **r=28** |
