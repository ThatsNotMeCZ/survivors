# Environment Atlas (`public/sprites/env/atlas.json` + `atlas.png`)

Přehled rozměrů a mapování všech herních objektů prostředí pro Dark Hermetic survivor hru.

## Technický kontext
- **Velikost arény**: `2560 × 2560 px` (světové souřadnice)
- **Výchozí zoom kamery**: `viewZoom = 2.5` (renderuje s pixelovou ostrostí)
- **Základní mřížka podlahy**: dlaždice `64 × 64 px` (plocha 40 × 40 dlaždic)
- **Chování fallbacků**:
  - Pokud má objekt v `atlas.json` nulové rozměry (`"w": 0, "h": 0`) nebo chybí, hra automaticky použije procedurální vykreslování z `src/view/procedural-pixel-art.ts`.
  - Objekty s předponou `glacial-*` při nevyplnění automaticky zkouší odpovídající `rime-*` objekt a až poté procedurální fallback.
  - Snímek `*-hazard-1` při nevyplnění automaticky použije statický snímek `*-hazard-0`.

---

## Tabulka rozměrů a parametrů objektů

| Klíč v `atlas.json` | Herní název / Objekt | Kolizní rozměr ve světě | Ideální rozměr v atlasu (`w × h`) | Chování / Poznámka |
|---|---|---|---|---|
| **1. Podlahové dlaždice (Floor Tiles)** | | | | |
| `cinder-tile-0` | Cinder Yard paver (hlavní) | `64 × 64 px` | **`64 × 64 px`** | Čedič / sopečná dlažba. Pokud vyplníš jen tuto variantu, použije se pro všechny základní sloty. |
| `cinder-tile-1` | Cinder Yard paver (varianta 1) | `64 × 64 px` | **`64 × 64 px`** | Popraskaný kámen / uhlíky. |
| `cinder-tile-2` | Cinder Yard paver (varianta 2) | `64 × 64 px` | **`64 × 64 px`** | Uhlíkový blok s popelem. |
| `cinder-tile-3` | Cinder Yard paver (varianta 3) | `64 × 64 px` | **`64 × 64 px`** | Hladký lávový blok. |
| `cinder-tile-rune-0` | Cinder Yard runa (varianta 0) | `64 × 64 px` | **`64 × 64 px`** | Runová dlaždice – hexagram / hvězdicový sigil. Míchá se do podlahy (~12.5% výskyt). |
| `cinder-tile-rune-1` | Cinder Yard runa (varianta 1) | `64 × 64 px` | **`64 × 64 px`** | Runová dlaždice – plamenný trojúhelník síry. |
| `cinder-tile-rune-2` | Cinder Yard runa (varianta 2) | `64 × 64 px` | **`64 × 64 px`** | Runová dlaždice – solární pečeť. |
| `cinder-tile-rune-3` | Cinder Yard runa (varianta 3) | `64 × 64 px` | **`64 × 64 px`** | Runová dlaždice – alchymistický kelímek. |
| `rime-tile-0` | Rime Dock paver (hlavní) | `64 × 64 px` | **`64 × 64 px`** | Zmrzlá břidlice / přístavní molo. Fallback pro varianty 1–3. |
| `rime-tile-1` | Rime Dock paver (varianta 1) | `64 × 64 px` | **`64 × 64 px`** | Námraza / zmrzlá louže. |
| `rime-tile-2` | Rime Dock paver (varianta 2) | `64 × 64 px` | **`64 × 64 px`** | Zmrzlý břidlicový blok. |
| `rime-tile-3` | Rime Dock paver (varianta 3) | `64 × 64 px` | **`64 × 64 px`** | Popraskaný permafrost. |
| `rime-tile-rune-0` | Rime Dock runa (varianta 0) | `64 × 64 px` | **`64 × 64 px`** | Kyanová ledová runa – hexagram. Míchá se do podlahy (~12.5% výskyt). |
| `rime-tile-rune-1` | Rime Dock runa (varianta 1) | `64 × 64 px` | **`64 × 64 px`** | Kyanová ledová runa – mrazivý klín. |
| `rime-tile-rune-2` | Rime Dock runa (varianta 2) | `64 × 64 px` | **`64 × 64 px`** | Kyanová ledová runa – pečeť mola. |
| `rime-tile-rune-3` | Rime Dock runa (varianta 3) | `64 × 64 px` | **`64 × 64 px`** | Kyanová ledová runa – solankový uzel. |
| `glacial-tile-0` | Glacial Tomb paver (hlavní) | `64 × 64 px` | **`64 × 64 px`** | Hrobka v ledu. Při `0×0` přebírá `rime-tile-0`. |
| `glacial-tile-1` | Glacial Tomb paver (varianta 1) | `64 × 64 px` | **`64 × 64 px`** | Ledovcový blok. Fallback na `rime-tile-1`. |
| `glacial-tile-2` | Glacial Tomb paver (varianta 2) | `64 × 64 px` | **`64 × 64 px`** | Rytina krypty. Fallback na `rime-tile-2`. |
| `glacial-tile-3` | Glacial Tomb paver (varianta 3) | `64 × 64 px` | **`64 × 64 px`** | Hluboký led. Fallback na `rime-tile-3`. |
| `glacial-tile-rune-0` | Glacial Tomb runa (varianta 0) | `64 × 64 px` | **`64 × 64 px`** | Prastará kryptová runa 0. Fallback na `rime-tile-rune-0`. |
| `glacial-tile-rune-1` | Glacial Tomb runa (varianta 1) | `64 × 64 px` | **`64 × 64 px`** | Prastará kryptová runa 1. Fallback na `rime-tile-rune-1`. |
| `glacial-tile-rune-2` | Glacial Tomb runa (varianta 2) | `64 × 64 px` | **`64 × 64 px`** | Prastará kryptová runa 2. Fallback na `rime-tile-rune-2`. |
| `glacial-tile-rune-3` | Glacial Tomb runa (varianta 3) | `64 × 64 px` | **`64 × 64 px`** | Prastará kryptová runa 3. Fallback na `rime-tile-rune-3`. |
| **2. Okraje mapy (Arena Borders - 6ks)** | | | | |
| `cinder-border-h-0` | Cinder obrubník horizontální 0 | délka po obvodu | **`64 × 16 px`** (nebo `64 × 32 px` / `64 × 64 px`) | Vodorovný okraj (horní a dolní hrana). Míchá se s variantou `h-1`. |
| `cinder-border-h-1` | Cinder obrubník horizontální 1 | délka po obvodu | **`64 × 16 px`** (nebo `64 × 32 px` / `64 × 64 px`) | Druhá vodorovná varianta (např. prasklina, lávový průsak). Fallback na `h-0`. |
| `cinder-border-v-0` | Cinder obrubník vertikální 0 | výška po obvodu | **`16 × 64 px`** (nebo `32 × 64 px` / `64 × 64 px`) | Svislý okraj (levá a pravá hrana). Míchá se s variantou `v-1`. |
| `cinder-border-v-1` | Cinder obrubník vertikální 1 | výška po obvodu | **`16 × 64 px`** (nebo `32 × 64 px` / `64 × 64 px`) | Druhá svislá varianta. Fallback na `v-0`. |
| `cinder-border-corner-top` | Cinder roh horní | roh arény | **`16 × 16 px`** (nebo `32 × 32 px` / `64 × 64 px`) | Horní rohy (levý normálně, pravý horizontálně zrcadlený). |
| `cinder-border-corner-bottom` | Cinder roh spodní | roh arény | **`16 × 16 px`** (nebo `32 × 32 px` / `64 × 64 px`) | Spodní rohy (levý normálně, pravý horizontálně zrcadlený). |
| `rime-border-h-0` | Rime molo okraj horizontální 0 | délka po obvodu | **`64 × 16 px`** (nebo `64 × 32 px` / `64 × 64 px`) | Vodorovný okraj mola. Míchá se s `h-1`. |
| `rime-border-h-1` | Rime molo okraj horizontální 1 | délka po obvodu | **`64 × 16 px`** (nebo `64 × 32 px` / `64 × 64 px`) | Druhá vodorovná varianta mola. Fallback na `h-0`. |
| `rime-border-v-0` | Rime molo okraj vertikální 0 | výška po obvodu | **`16 × 64 px`** (nebo `32 × 64 px` / `64 × 64 px`) | Svislý okraj mola. Míchá se s `v-1`. |
| `rime-border-v-1` | Rime molo okraj vertikální 1 | výška po obvodu | **`16 × 64 px`** (nebo `32 × 64 px` / `64 × 64 px`) | Druhá svislá varianta mola. Fallback na `v-0`. |
| `rime-border-corner-top` | Rime roh horní | roh arény | **`16 × 16 px`** (nebo `32 × 32 px` / `64 × 64 px`) | Horní rohy mola. |
| `rime-border-corner-bottom` | Rime roh spodní | roh arény | **`16 × 16 px`** (nebo `32 × 32 px` / `64 × 64 px`) | Spodní rohy mola. |
| `glacial-border-h-0` | Glacial okraj ledu horizontální 0 | délka po obvodu | **`64 × 16 px`** (nebo `64 × 32 px` / `64 × 64 px`) | Fallback na `rime-border-h-0`. |
| `glacial-border-h-1` | Glacial okraj ledu horizontální 1 | délka po obvodu | **`64 × 16 px`** (nebo `64 × 32 px` / `64 × 64 px`) | Fallback na `rime-border-h-1`. |
| `glacial-border-v-0` | Glacial okraj ledu vertikální 0 | výška po obvodu | **`16 × 64 px`** (nebo `32 × 64 px` / `64 × 64 px`) | Fallback na `rime-border-v-0`. |
| `glacial-border-v-1` | Glacial okraj ledu vertikální 1 | výška po obvodu | **`16 × 64 px`** (nebo `32 × 64 px` / `64 × 64 px`) | Fallback na `rime-border-v-1`. |
| `glacial-border-corner-top` | Glacial ledový roh horní | roh arény | **`16 × 16 px`** (nebo `32 × 32 px` / `64 × 64 px`) | Fallback na `rime-border-corner-top`. |
| `glacial-border-corner-bottom` | Glacial ledový roh spodní | roh arény | **`16 × 16 px`** (nebo `32 × 32 px` / `64 × 64 px`) | Fallback na `rime-border-corner-bottom`. |
| **3. Sloupy / Překážky (Pillars)** | `radius: 52` | `průměr 104 px` | | |
| `cinder-pillar` | *Obsidian Kiln* | `104 × 104 px` | **`64 × 64 px`** (nebo `104 × 104 px`) | Černá sopečná pec s žhnoucími oranžovými runami. Hra automaticky škáluje sprite na `obs.radius * 2` (`104 px`). |
| `rime-pillar` | *Frozen Bollard* | `104 × 104 px` | **`64 × 64 px`** (nebo `104 × 104 px`) | Masivní zamrzlé přístavní pachole s ledovými runami. |
| `glacial-pillar` | *Glacial Monolith* | `104 × 104 px` | **`64 × 64 px`** (nebo `104 × 104 px`) | Starobylý ledovcový obelisk. Fallback na `rime-pillar`. |
| **4. Nebezpečné zóny (Hazards)** | `radius: 68` | `průměr 136 px` | | |
| `cinder-hazard-0` | *Slag Fissure* (snímek 1) | `136 × 136 px` | **`64 × 64 px`** (nebo `128 × 128 px`) | Lávová trhlina / vroucí struska. Škáluje se na `136 px`. |
| `cinder-hazard-1` | *Slag Fissure* (snímek 2) | `136 × 136 px` | **`64 × 64 px`** (nebo `128 × 128 px`) | Animační 2. snímek (střídá se po 0.25 s). Fallback na snímek 0. |
| `rime-hazard-0` | *Brine Pool* (snímek 1) | `136 × 136 px` | **`64 × 64 px`** (nebo `128 × 128 px`) | Louže mrznoucí toxické solanky. Škáluje se na `136 px`. |
| `rime-hazard-1` | *Brine Pool* (snímek 2) | `136 × 136 px` | **`64 × 64 px`** (nebo `128 × 128 px`) | Animační 2. snímek. Fallback na snímek 0. |
| `glacial-hazard-0` | *Permafrost Crevasse* (snímek 1) | `136 × 136 px` | **`64 × 64 px`** (nebo `128 × 128 px`) | Bezedná puklina v ledovci. Fallback na `rime-hazard-0`. |
| `glacial-hazard-1` | *Permafrost Crevasse* (snímek 2) | `136 × 136 px` | **`64 × 64 px`** (nebo `128 × 128 px`) | Animační 2. snímek. Fallback na `glacial-hazard-0` / `rime-hazard-1`. |
| **5. Výbušné objekty (Volatiles)** | `radius: 22` | `průměr 44 px` | | |
| `cinder-volatile` | *Brimstone Urn* | `44 × 44 px` | **`32 × 32 px`** (nebo `24 × 24 px` / `44 × 44 px`) | Sirná alchymistická urna s měděnými pásy. Při odpálení červeně pulzuje. |
| `rime-volatile` | *Pressurized Rime Cask* | `44 × 44 px` | **`32 × 32 px`** (nebo `24 × 24 px` / `44 × 44 px`) | Okovaný dřevěný sud ucházející mrazivý plyn. |
| `glacial-volatile` | *Volatile Ice Chunk* | `44 × 44 px` | **`32 × 32 px`** (nebo `24 × 24 px` / `44 × 44 px`) | Nestabilní krystal kryogenního ledu. Fallback na `rime-volatile`. |
| **6. Transmutační kruh & Rift brána** | | | | |
| `cinder-circle` | *Transmutation Circle* (Cinder) | `320 × 320 px` (`r=160`) | **`160 × 160 px`** (nebo `320 × 320 px`) | Podlahová alchymistická pečeť s hexagramem v barvách jantaru a zlata. Indikátor nabíjení se dokresluje dynamicky. |
| `rime-circle` | *Transmutation Circle* (Rime) | `300 × 300 px` (`r=150`) | **`160 × 160 px`** (nebo `300 × 300 px`) | Mrazivá pečeť v barvách stříbra a kyanu. |
| `glacial-circle` | *Transmutation Circle* (Glacial) | `280 × 280 px` (`r=140`) | **`160 × 160 px`** (nebo `280 × 280 px`) | Prastará runová pečeť krypty. Fallback na `rime-circle`. |
| `cinder-portal` | *The Rift* (Cinder brána) | `140 × 140 px` (`r=70`) | **`96 × 96 px`** (nebo `140 × 140 px`) | Výstupní trhlina po porážce bosse (oranžová/jantarová). |
| `rime-portal` | *The Rift* (Rime brána) | `140 × 140 px` (`r=70`) | **`96 × 96 px`** (nebo `140 × 140 px`) | Výstupní trhlina po porážce bosse (ledová/světle modrá). |
| `glacial-portal` | *The Rift* (Glacial brána) | `140 × 140 px` (`r=70`) | **`96 × 96 px`** (nebo `140 × 140 px`) | Výstupní trhlina po porážce bosse. Fallback na `rime-portal`. |
| **7. Ambientní částice** | | | | |
| `ambient-ash` | Popílek (Cinder) | `2–4 px` | **`8 × 8 px`** | Poloprůhledný šedý popílek poletující vzduchem. |
| `ambient-ember` | Jiskra (Cinder) | `1–4 px` | **`8 × 8 px`** | Svítící ohnivá jiskra stoupající vzhůru. |
| `ambient-snow` | Sníh (Rime / Glacial) | `2–4 px` | **`8 × 8 px`** | Sněhová vločka klesající k zemi. |
| `ambient-mist` | Mlha (Rime / Glacial) | `3–8 px` | **`16 × 16 px`** | Chladný cár mlhy. |

---

## Jak postupovat při nasazení grafiky

1. Vygenerovaný nebo nakreslený spritesheet ulož do:
   ```text
   public/sprites/env/atlas.png
   ```
2. Otevři soubor:
   ```text
   public/sprites/env/atlas.json
   ```
3. U každého objektu, který v atlasu máš, nahraď nulové souřadnice přesnými hodnotami (`x, y, w, h`) z obrázku.
   *Příklad:*
   ```json
   "cinder-pillar": { "x": 64, "y": 128, "w": 64, "h": 64 }
   ```
4. Objekty, které zatím nemáš nakreslené, nech na `{ "x": 0, "y": 0, "w": 0, "h": 0 }` – hra pro ně automaticky zachová procedurální grafiku bez chyb.
