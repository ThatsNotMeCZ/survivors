# Plán publikace a propagace demo verze na itch.io — *Hermetic Rifts*

Tento dokument slouží jako kompletní checklist, stylistický manuál (napojený přímo na paletu z `src/ui/theme.css`), copywritingový balíček a marketingový playbook pro vydání hratelného HTML5 dema **Hermetic Rifts** na itch.io.

---

## 1. Technická příprava HTML5 buildu (Před nahráním)

Itch.io hostuje webové hry v `<iframe>` na subdoméně `html.itch.zone`. Protože hra běží na **Phaser 4 (WebGL)** + **HTML UI overlay** (`src/ui/`) a využívá `localStorage` (`survivors.records.v1`), je potřeba ohlídat následující:

### 1.1 Build & Balíček
1. **Relativní cesty:** V `vite.config.ts` už je nastaveno `base: './'`, takže assety (`public/sprites/`, `public/audio/`) se v subdoménovém iframe načtou správně.
2. **Jednokrokový produkční build + zabalení pro itch.io:**
   ```bash
   bun run build:itch
   ```
   Tento skript automaticky spustí headless smoke test (`bun run smoke:loop`), provede čistý TypeScript + Vite build (`bun run build`), zkontroluje přítomnost manifestů a zabalí **obsah** složky `dist/` přímo do kořene archivu **`hermetic-rifts-itch.zip`** (takže `index.html` leží na nejvyšší úrovni ZIPu, jak vyžaduje itch.io).
3. **Alternativa přes itch.io Butler CLI:**
   - Pokud nahráváš časté hotfixy, můžeš použít `butler push dist uzivatel/hermetic-rifts:html5`, který nahrává pouze změněné bloky a nerozbije URL ani statistiky.

### 1.2 Nastavení v itch.io Dashboardu (Edit Game → Uploads / Embed Options)
- **Kind of project:** `HTML` (Playable in browser) — **Kritické!** Na itch.io má HTML5 verze oproti `.exe` ke stažení **8× až 15× vyšší konverzi** z návštěvníka na hráče, protože odpadá tření se stahováním a SmartScreen varováním.
- **Embed options:**
  - **Viewport dimensions:** `1280 × 720` px (nebo `1066 × 600` px, aby se vešlo na menší notebooky bez ořezu) + zaškrtnout **Fullscreen button** a **Automatically start on page load: OFF** (nechceme, aby lidem začal hrát zvuk nebo se kradl fokus při čtení stránky; tlačítko *Click to Run* navíc funguje jako první user-gesture pro odemknutí Web Audio API).
  - **SharedArrayBuffer support:** Nezaškrtávat, pokud ho nutně nepotřebuješ (COOP/COEP hlavičky občas rozbíjí externí fonty nebo analytiku).
  - **Mobile friendly:** Nezaškrtávat (hra vyžaduje `WASD` + míření myší).
  - **Frame options:** Zaškrtnout *Scrollbars: Hidden*.

### 1.3 Fokus klávesnice, Fullscreen a `Escape / P` v iframe (Vyřešeno v kódu)
- V prohlížeči na itch.io klávesa `Escape` ve Fullscreen režimu nejprve vyskočí z Fullscreenu (výchozí chování prohlížeče), teprve druhý `Escape` vyvolá `Simulation Paused`.
- **Implementováno ve hře:**
  - Klávesa **`P`** funguje jako plnohodnotná alternativa k `Esc` pro pauzu i návrat do hry (aniž by shodila Fullscreen).
  - V *Alchemist's Desk (Settings)* je přímo tlačítko **Toggle Fullscreen** (`Fullscreen Chamber`).
  - Stisk `Space` (Dash) a šipek během hraní má blokovaný výchozí scroll stránky (`preventDefault` + Phaser `addCapture`), takže neposouvá stránku itch.io pod hrou.
  - Při kliknutí mimo iframe (`blur`) nebo přepnutí záložky (`visibilitychange`) se hra automaticky zapauzuje.

---

## 2. Stylizace stránky na itch.io (Dark Hermetic Theme)

Vzhled stránky musí plynule navazovat na atmosféru **The Hall** (`src/ui/theme.css`). Vyhni se výchozí bílé šabloně itch.io.

### 2.1 Barvy v editoru tématu (Edit Theme)
Použij přesné hex kódy z tvého `src/ui/theme.css`:

| Prvek v itch.io Theme Editoru | Hex kód | Token v `theme.css` | Poznámka |
|---|---|---|---|
| **Background** (Pozadí stránky) | `#0c0a0d` | `--ink` | Hluboká inkoustová čerň na okrajích |
| **Background 2** (Sloupec obsahu) | `#140e12` | `--chamber` | Tmavý alchymistický kámen s lehkýmfialovo-rudým podtónem |
| **Text** (Hlavní text) | `#e8dcc8` | `--parchment` | Čitelný pergamenový odstín, neunavuje oči |
| **Links** (Odkazy & nadpisy) | `#c4a35a` | `--brass` | Mosazná zlatá |
| **Link Hover / Accent** | `#e5c878` | `--brass-bright` | Rozžhavená mosaz |
| **Button / Highlight** | `#b82934` | `--alizarin-hot` | Alchymistický rumělkovo-karmínový akcent |
| **Secondary / Borders** | `#2c272e` | `--stone-mid` | Jemné ohraničení bloků |

### 2.2 Typografie (Edit Theme → Font)
- **Header Font:** `Cinzel` (je přímo v Google Fonts nabídce na itch.io a shoduje se s `@fontsource/cinzel` v projektu!).
- **Body Font:** `Source Sans 3` (nebo `Source Sans Pro` / `Inter`), velikost `Normal` nebo `Large`.

### 2.3 Vlastní CSS (pokud máš na účtu povolené Custom CSS)
Pokud nemáš Custom CSS aktivní, stačí o něj napsat na support itch.io (bývá schváleno během 1–2 dnů) – i bez něj ale výše uvedené barvy udělají 90 % práce. S Custom CSS přidej:
```css
.wrapper {
  border: 1px solid #5c4520;
  box-shadow: 0 0 60px rgba(12, 10, 13, 0.95), 0 0 20px rgba(196, 163, 90, 0.12);
}
h1, h2, h3 {
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: #e5c878;
  border-bottom: 1px solid #5c4520;
  padding-bottom: 6px;
}
```

### 2.4 Vizuální assety stránky (Co musíš vyexportovat)

Hotový balík: [`promo/itch/`](../promo/itch/) (mapa nahrání v [`promo/itch/README.md`](../promo/itch/README.md)). Přegenerování:

```bash
bun run capture:itch
```

1. **Cover Image (`630 × 500 px`) — NEJDŮLEŽITĚJŠÍ ASSET:**
   - **Proč rozhoduje o všem:** V katalogu *New & Popular* lidé scrollují přes desítky her za vteřinu. Statický screenshot z dálky tam zanikne. Katalog itch.io cover GIFy téměř nepoužívá — listing bere **statický PNG**.
   - **Doporučení:** Složený still z authored sprite (`promo/itch/cover.png`, 630×500). Ne gameplay crop, ne GIF. Motion nech v page GIFech (`gif-circle.gif`, `gif-boss.gif`).
   - **Co na něm musí být:** Velký *The Penitent* (idle + Phase Step afterimage) proti *Cinder Heart* (attack frame) na *Transmutation Circle*, mosazný nápis **HERMETIC RIFTS** v BillJilly. Silueta musí číst i v náhledu ~315×250. Přegenerování: `bun scripts/capture-itch.ts cover`.
2. **Banner na vršek stránky (`960 × 240 px`):**
   - Tmavé pozadí z *The Hall* (fialovo-kouřový shader + transmutační pečeť) a uprostřed logo **HERMETIC RIFTS**.
3. **3–5 Screenshotů + 2 GIFy přímo v textu stránky (Pravidlo 3 sekund):**
   - Screenshot 1: **Intenzivní boj na Transmutation Circle** (ukazuje HUD, difikultní lištu *Dormant → Cataclysm* a shaderové elity).
   - Screenshot 2: **Boss Duel** (*Cinder Heart* nebo *Frost Sovereign* s telegraphem útoku a vlastním spawnováním).
   - Screenshot 3: **Výběr Hermetic Tablets (Level-up)** — detailní panel s +zeleným / −červeným hookem a 96px ikonami.
   - Screenshot 4: **The Hall & The Archives** — otevřený Bestiář nebo Relikviář (okamžitě signalizuje vysokou produkční hodnotu, ne rychlokvašku z game jamu).

---

## 3. Texty na itch.io stránku (Copywriting Ready-to-Paste)

Na itch.io je naprostým standardem **angličtina** (95 % publika). Níže máš kompletní texty připravené přímo k překopírování, postavené na vašem herním designu a loru.

### 3.1 Základní metadata
- **Title:** `Hermetic Rifts (Demo)`
- **Project URL:** `https://tvoje-jmeno.itch.io/hermetic-rifts`
- **Short description / Tagline (max 140 znaků — zobrazuje se pod coverem v katalogu):**
  > *Dark-alchemy action roguelite. Aim every rite, hold the seal, survive what the Magisterium left ???.*
- **Genre:** `Action` (Primary), `Shooter` / `Roguelike`
- **Tags (využij všech 10 povolených slotů — přesně podle toho, co hráči na itch.io filtrují):**
  `roguelite`, `bullet-heaven`, `survivors-like`, `action-roguelike`, `twin-stick-shooter`, `pixel-art`, `dark-fantasy`, `alchemy`, `top-down`, `singleplayer`

### 3.2 Hlavní text stránky (Description — vlož přímo do HTML režimu `<>` v editoru na itch.io)

Hlas popisu = Steam About This Game, Dark Hermetic. Krátký hook, pak čitelné feature bullets. Lehké `???` (redacted pečetě jako Hall / Bestiary / Reliquary, ne UI hláška „locked“). Žádné design-doc seznamy (coefficient ladder, skill ids, elite mechanics, prop lists). Nezmiňovat jiné hry. Druhou Vessel nepojmenovávat.

V itch.io editoru klikni v liště popisu na ikonu **`<>` (Edit HTML)** a vlož následující čisté HTML (používá pouze tagy povolené itch.io sanitizerem):

```html
<h3><em>The Magisterium burned. You are what walked out of the ash.</em></h3>
<p>
  <strong>Hermetic Rifts</strong> is a dark-alchemy action roguelite. You pilot a Vessel through the sealed chambers of a failed Great Work: aim every rite, slip through the swarm, and stand in the Transmutation Circle when the seal finally shows itself.
</p>
<p>
  Time does not merely fill the floor with bodies. The chamber hardens. Elites hunt. A Guardian wakes to keep the Rift shut. Names you have not earned still print as <em>???</em>.
</p>
<hr>
<h2>About this demo</h2>
<ul>
  <li>
    <strong>You aim.</strong> Move with WASD, fire along the cursor, dash through the blow. Standing still is how a Vessel dies.
  </li>
  <li>
    <strong>Hold the seal.</strong> When the Transmutation Circle opens, channel it while the horde converges. Then you fight the Seal Guardian alone.
  </li>
  <li>
    <strong>Two Vessels.</strong> The Homunculus is clay and quicksilver, already waiting. A second name stays <em>??? · SEALED</em> until you earn it.
  </li>
  <li>
    <strong>Hermetic Tablets.</strong> Graft them into your frame as you level. The kind ones help. The rare ones cut both ways.
  </li>
  <li>
    <strong>Two chambers, and a third still sealed.</strong> Scorched Cinder Yard. Frozen Rime Dock. What lies below remains <em>???</em>.
  </li>
  <li>
    <strong>The Archives.</strong> A codex of what you have killed, bound, and not yet recovered.
  </li>
</ul>
<p>
  A full descent is a handful of minutes, right in the browser. No download.
</p>
<hr>
<h2>Controls</h2>
<table>
  <thead>
    <tr>
      <th align="left">Input</th>
      <th align="left">Action</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>WASD / Arrows</strong></td>
      <td>Move</td>
    </tr>
    <tr>
      <td><strong>Mouse + Left Click</strong></td>
      <td>Aim and fire</td>
    </tr>
    <tr>
      <td><strong>Right Click</strong></td>
      <td>Secondary rite</td>
    </tr>
    <tr>
      <td><strong>Space / Shift</strong></td>
      <td>Dash</td>
    </tr>
    <tr>
      <td><strong>Q</strong></td>
      <td>Ultimate</td>
    </tr>
    <tr>
      <td><strong>1 / 2 / 3</strong></td>
      <td>Pick a tablet on level-up</td>
    </tr>
    <tr>
      <td><strong>P / Esc</strong></td>
      <td>Pause (use <strong>P</strong> in fullscreen)</td>
    </tr>
    <tr>
      <td><strong>C</strong> (run recap)</td>
      <td>Copy run summary</td>
    </tr>
  </tbody>
</table>
<hr>
<p>
  If a working goes well, or if it shatters, paste the run summary in the comments. The Archives are listening.
</p>
```

---

## 4. Ideální čas a den pro publikování na itch.io

Na itch.io funguje algoritmus sekcí **New & Popular** a **Fresh Games** na kombinaci **stáří od publikace (decay)** a **rychlosti kliknutí / hodnocení / komentářů v prvních 6–12 hodinách**.

### 4.1 Kritické pravidlo č. 1: Nikdy nepublikuj "Draft", který ležel týden jako Public
- Jakmile poprvé přepneš *Visibility & Access* z `Draft / Restricted` na `Public`, zapíše se interní `published_at` timestamp.
- **Postup:** Celou stránku si v klidu postav a otestuj v režimu **Restricted (Secret URL)** — pošli ji 3–5 kamarádům na otestování v prohlížeči. Teprve v hodinu ostrého launche přepni na **Public**.

### 4.2 Nejlepší den v týdnu
- **Ideál: Úterý, Středa nebo Čtvrtek.**
  - *Proč:* Američtí i evropští hráči a streameři/YouTubeři (kteří pravidelně točí "Best Free Itch.io Roguelikes of the Week") hledají obsah v polovině týdne.
- **Dobrá alternativa: Pátek odpoledne** (těsně před víkendovým náporem hráčů, *pokud* přes víkend zrovna nekončí obří game jam jako GMTK nebo Ludum Dare, který zaplaví *Newest* stovkami her za minutu – vždy mrkni na `itch.io/jams`!).
- **Kdy NEPUBLIKOVAT:** Neděle večer a Pondělí dopoledne (nejnižší organický traffic).

### 4.3 Nejlepší hodina (v našem časovém pásmu CET / CEST)
- **Zlaté okno: 16:00 – 18:00 CET (Praha/Bratislava)** *(což je 10:00 – 12:00 EST / 07:00 – 09:00 PST)*.
- **Proč:**
  1. Zachytíš evropskou odpolední/večerní špičku hned po vydání.
  2. Během prvních 2–3 hodin nasbíráš první přehrání, lajky a komentáře od přátel a z prvních postů.
  3. Když se kolem **19:00–22:00 CET** naplno rozjede americká špička (největší zdroj trafficu na itch.io), tvoje hra už má počáteční engagement a algoritmus ji vytáhne do **New & Popular** v kategorii *Action / Roguelike* + *Play in Browser*.

---

## 5. Jak hru odpromovat, aby "nezapadla" (Zero-Budget Indie Playbook)

Samotné stisknutí tlačítka *Publish* na itch.io přinese ~50–150 zobrazení z kategorie *Newest*. Aby se hra dostala do **New & Popular** (kde se organický traffic násobí na tisíce přehrání a přitahuje YouTubery), musíš v prvních **24 hodinách** přivést externí impulz a udržet hráče u hraní v prohlížeči.

### 5.1 Máš obrovskou neférovou výhodu: Hra běží v prohlížeči!
Na Redditu nebo Discordu lidé **nesnáší** klikat na odkazy, kde musí stahovat `.zip` od neznámého vývojáře. Věta:
> **"Playable right in your browser (no download, no login, ~5 min run)"**
zvyšuje míru prokliku z Redditu a Discordu **5× až 10×**. Tuto větu dávej do každého příspěvku!

### 5.2 Harmonogram v den vydání (Hodinu po hodině)

1. **T-0 (16:30 CET) — Publikace na itch.io + 1. Devlog:**
   - Přepni hru na **Public**.
   - **Okamžitě (do 15 minut) vydáš na itch.io krátký Devlog post** typu *Major Update / Release Announcement* ("Hermetic Rifts Playable Demo is Live!").
   - *Proč:* Itch.io má samostatný **Devlog feed** na hlavní stránce. Tím získáš **dva** nezávislé vstupy do feedu najednou (samotný katalog her + Devlog kanál).
2. **T+15 min — Aktivace prvních 5–10 hodnocení a komentářů:**
   - Pošli odkaz 5–10 kamarádům / testerům s prosbou: *„Zahrajte si 1 run v prohlížeči, dejte hře Rating (5★) a napište pod stránku 1 komentář, jaký build jste hráli.“*
   - *Proč:* Algoritmus itch.io extrémně silně váží **počet komentářů a hodnocení za časovou jednotku**. Hra s 8 komentáři a 6 hodnoceními v první hodině přeskočí 95 % ostatních novinek.
3. **T+30 min — Reddit vlna (Nejvyšší konverze pro tento žánr):**
   - Nekašli na obecné subreddity s miliony lidí, kde post zapadne za 2 minuty. Cílíš na **žánrové subreddity**, kde hráči aktivně hledají nové bullet-heaven / roguelite hry v prohlížeči:
     - `r/roguelites` *(Extrémně přátelská komunita k indie vývojářům, milují Risk of Rain 2 inspiraci!)*
     - `r/SurvivorsLike` *(Přesná cílovka pro hry, které posouvají Vampire Survivors dál)*
     - `r/WebGames` *(Sem můžeš postnout přímý odkaz na hratelnou webovou hru – často vygeneruje 500–2 000 přehrání za jediný den!)*
     - `r/PlayMyGame` a `r/DestroyMyGame` *(Na r/DestroyMyGame dostaneš drsný, ale extrémně cenný feedback + desítky okamžitých přehrání)*
     - `r/IndieGaming` / `r/gamedev` (v sobotním *Screenshot Saturday* vlákně)
   - **Jak psát post na Reddit, aby nevypadal jako reklama:**
     - **Nikdy** nedávej do příspěvku jen YouTube odkaz. Nahraj **nativní 20–30s MP4 video** přímo do Redditu (okamžitá akce od 1. sekundy: *Phase Step* skrz elity + boss duel + krátký prostřih na *Hermetic Tablets* výběr).
     - **Titulek postav na jasném designovém háčku (Hooku):**
       > *"I loved Vampire Survivors' 20-minute pacing, but hated how late-game turns into standing still. So I built a dark-alchemy roguelite with Risk of Rain 2's Stage Director, teleporter holdouts, and aimed combat — playable in your browser!"*
     - Odkaz na itch.io dej do **prvního komentáře** pod video společně s krátkým popisem.

### 5.3 Kde jinde hru ukázat (Dny 2 až 7)

1. **Mikro-YouTubeři a Streameři (Curators of "Free Itch.io Roguelikes"):**
   - Na YouTube a Twitchi existují desítky tvůrců (s 1 000 až 50 000 odběrateli), kteří se specializují výhradně na *action roguelites / bullet heaven / itch.io gems* (např. kanály v duchu *Retromation*, *Wanderbots*, *SplatterCatGaming*, *Olexa*, *Dex*, a desítky menších kanálů, které najdeš vyhledáním `"itch.io roguelite"` za poslední měsíc).
   - **Proč jsou zlatý důl:** Protože tvoje hra má **15–20min loop (v demu stlačený)**, běží plynule, má **vlastní UI v Cinzelu / BillJilly**, **The Archives** a **2 postavy**, vypadá ve videu jako hotový prémiový titul.
   - **Šablona krátkého e-mailu (max 5 vět + GIF v těle e-mailu):**
     > **Subject:**Hermetic Rifts — Dark-Alchemy Action Roguelite (RoR2 Director × VS Pacing) [Playable Demo]
     >
     > Hi [Name],
     > Since you cover action roguelites and bullet-heavens, I wanted to share **Hermetic Rifts** — a fast-paced dark-alchemy roguelite we just dropped on itch.io.
     > Instead of passive screen-clearing orbitals, it uses **aimed combat**, a **Risk of Rain 2-style credit director** (fewer bodies late-game, deadlier Shielder/Noxious elites), **Transmutation Circle holdouts**, and dedicated **1v1 stage boss duels**.
     > It features 2 playable Vessels, 13 trade-off Relics, and a full in-game Bestiary/Codex.
     > **Play directly in browser (or grab a build): [Itch.io Link]**
     > Happy to send raw assets or answer anything if you check it out!

2. **Itch.io Community & Collections:**
   - Přidej hru do komunitních vláken *Release Announcements* přímo na itch.io fóru (`itch.io/board/10019/release-announcements`).
   - Sleduj otevřené **Showcase / Non-competitive Jams** na itch.io (např. *Roguelike Celebration*, *Bullet Heaven Jam*, *Pixel Art Showcase*), kam lze vložit rozpracovanou hru — zařazení do jamu přivádí stovky přímých hodnocení od ostatních vývojářů.

3. **Vestavěná virální smyčka přímo ve hře (Implementováno):**
   - Na obrazovkách **Transmutation Complete** (výhra) a **Vessel Shattered** (smrt) je tlačítko **`COPY SUMMARY [C]`**, které zkopíruje do schránky textový přepis runu s emoji ikonami:
     ```text
     ⚗️ HERMETIC RIFTS — TRANSMUTATION COMPLETE 🜂
     Vessel: The Homunculus · Chamber: Rime Dock
     Time: 04:42 · Lv 11 · Coeff: ×2.35
     Dross Slain: 312 · Bosses Slain: 2
     Damage Dealt: 48,920 · Essence: 184
     Relics: Cinnabar Leech ×2, Lead Core ×3
     ```
   - Hráči na itch.io milují vkládat svoje vítězné recap texty do komentářů pod hrou — a každý takový komentář dál krmí algoritmus itch.io!

4. **Pravidlo 2. vlny (Týden po vydání — Patch 0.1.1):**
   - Nevyplácej všechen obsah v den 1. Po 5–7 dnech vydej menší update (např. vybalancování 2 relikvií na základě komentářů, nová elita nebo drobný QoL v *The Archives*) a publikuj na itch.io **Devlog #2 ("Update 0.1.1 — Community Balance & Fixes")**.
   - Každý publikovaný Devlog s přiloženým updatem znovu vystřelí hru do sekce *Recently Updated* a *Devlog Feed*.

---

## 6. Rychlý předstartovní Checklist

- [ ] Spuštěn `bun run build:itch` (proběhl smoke test, build i vygenerování `hermetic-rifts-itch.zip`).
- [ ] Ověřeno, že v produkčním buildu není zapnutý `?dev=1` ani `?smoke=1` jako default a hra startuje v **Main Menu / The Hall**.
- [ ] Zkontrolována hlasitost hudby a SFX při prvním spuštění (aby výchozí hlasitost v prohlížeči neodpálila uši).
- [ ] Nahrán `hermetic-rifts-itch.zip` (s `index.html` v kořeni) a otestován v režimu *Restricted* v Chrome i Firefoxu (včetně Fullscreen přepnutí, klávesy `P` / `Esc` a tlačítka `COPY SUMMARY [C]`).
- [ ] Nastaveny barvy stránky podle `src/ui/theme.css` (`#0c0a0d`, `#140e12`, `#c4a35a`, `#e8dcc8`, font `Cinzel`).
- [x] Vizuální pack v `promo/itch/` (`bun run capture:itch`): cover PNG 630×500 (Penitent vs Cinder Heart), banner 960×240, 4 screenshoty (circle / boss / tablets / archives) + 2 page GIFy. Zbývá nahrát do itch dashboardu.
- [ ] Vyplněno všech 10 tagů + HTML popis stránky (přes `<>` v editoru) s tabulkou ovládání a výzvou ke komentářům.
- [ ] Připraveno 25s nativní gameplay video pro Reddit (`r/roguelites`, `r/SurvivorsLike`, `r/WebGames`).
- [ ] Publikováno v **Úterý / Středu / Čtvrtek mezi 16:00–18:00 CET** + do 15 minut vydán úvodní Devlog post.
