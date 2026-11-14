# Viktige bemerkelser om NBA-datasettene

Dette dokumentet beskriver ID-regler, kildevalg og begrensninger for
`player_bio.csv`, `player_seasons.csv` og `family_relations.csv` i
`data/output_data/`. Alle tre lages av `scripts/01_build_player_data.R`
(se `README.md` for hvordan man kjører). Kjør `reports/build_player_data.qmd` for
å bygge og kontrollere alt i ett.

## 1. Hvordan spillere identifiseres

`playerID` er felles nøkkel for alle tre filene. **Hver `playerID` i
`player_seasons.csv` og `family_relations.csv` finnes i `player_bio.csv`.**
Det er garantert av pipen: identiteten til hver (navn, sesong, alder)
avgjøres én gang og brukes i begge filer.

### To typer ID

| Prefiks | Eksempel | Betyr |
|---|---|---|
| `p_` | `p_2544` | NBA sin offisielle person-ID (fra `archive_wyatt/csv/player.csv`). |
| `n_` | `n_victor_wembanyama` | Navnebasert ID for spillere som ikke finnes i registeret. Først og fremst spillere som kom inn i ligaen etter at registeret ble hentet (2023), og G-League-/two-way-spillere som bare finnes i lønnsfilen. |

`id_source` i `player_bio.csv` sier hvor raden kommer fra: `nba_id`,
`name_only` (fra sesongkildene) eller `family_list_only` (bare nevnt i en
familieliste). Registeret `player.csv` kommer fra stats.nba.com og dekker
NBA/BAA fra 1946 til 2023. Spillere som bare spilte i ABA (f.eks. Rick Mount,
Collis Temple, Willie Sojourner), i NBL før 1946, eller som debuterte etter
2023, finnes ikke der og får derfor `n_`-ID. De er fullverdige rader i
`player_bio.csv` og inngår i familierelasjonene, men mangler biodata.

### Hvordan et navn kobles til en person

1. Navnet normaliseres (små bokstaver, ingen punktum/apostrof, `O.G.` =
   `OG`). `data/name_aliases.csv` oversetter kallenavn og feilstavinger
   (`Steve Smith` → `Steven Smith`, `Louis Williams` → `Lou Williams`).
2. Spillere i registeret med samme navn er kandidater. Finnes ingen,
   prøves navnet uten suffiks (`Perry Jones` → `Perry Jones III`).
3. Flere kandidater (f.eks. to `Marcus Williams`) skilles med karriereår,
   draftår og alder. Statsfilen oppgir alder per 1. februar, `all_seasons`
   per 1. juli; begge sammenlignes med fødselsdato i registeret.
4. Lønnsrader uten alder som fortsatt er tvetydige, får personen som er
   identifisert i nærmeste sesong. De som da fortsatt er tvetydige (4 rader),
   fjernes og listes i `results/name_matching_review.csv`.

Alle koblinger som ikke var en entydig treff, ligger i
`results/name_matching_review.csv` med kandidatene som ble vurdert. Nye
kallenavn legges til i `data/name_aliases.csv`, deretter kjøres pipen på nytt.

## 2. `player_bio.csv` (én rad per spiller)

| Kolonne | Innhold |
|---|---|
| `playerID`, `full_name`, `first_name`, `last_name` | Navn fra registeret. Suffiks som `Jr.` ligger i `last_name`. |
| `birthdate`, `birth_year` | Fra `common_player_info`. Mangler fødselsdato, er `birth_year` **estimert** fra alderen i sesongkildene (kan bomme med ett år). |
| `country`, `school`, `height_cm`, `weight_kg` | Fra `common_player_info`, fylt fra `all_seasons` der det mangler. |
| `draft_year`, `draft_round`, `draft_number` | Fra `common_player_info`, ellers `draft_history`. `NA` = udraftet eller ukjent. |
| `career_start`, `career_end` | Startår for første og siste sesong (2003 = 2003-04). For `n_`-spillere: første/siste sesong i våre kilder. Registeret stopper i 2023. |
| `greatest_75_flag` | 1 for NBA 75th Anniversary Team. |
| `familyID` | 0 = ingen registrert familie. Ellers deler alle i samme familie (far, sønner, brødre) samme nummer. |
| `father_dummy`, `son_dummy`, `brother_dummy` | 1 hvis spilleren har den rollen i minst én relasjon. |
| `same_name_flag` | 1 hvis en annen spiller i filen har samme navn (uten suffiks). Vær ekstra forsiktig med disse. |
| `id_source` | Se over. |

Kolonner som fantes tidligere, men er fjernet: `twin_dummy` (ingen kilde),
`other_flag` (uklar betydning).

## 3. `player_seasons.csv` (én rad per spiller og sesong)

`season` er sluttåret: `2020` = sesongen 2019-20. Dekker 1997–2025.

| Kolonner | Kilde |
|---|---|
| `full_name`, `first_name`, `last_name` | Fra `player_bio.csv` (samme stavemåte i alle sesonger). |
| `age`, `team_abbreviation`, `position`, `salary` | Statsfilen; `age`/lag fylles fra `all_seasons` når statsfilen mangler raden; `salary` fylles fra lønnsfilen. |
| `height_cm`, `weight_kg` | `all_seasons` (per sesong, ikke karriereverdi). |
| `games_played` … `pts_pg` | Statsfilen (per kamp). `games_played`, `pts_pg`, `reb_pg`, `ast_pg` fylles fra `all_seasons` der statsfilen mangler. |
| `net_rating`, `oreb_pct`, `dreb_pct`, `usg_pct`, `ts_pct`, `ast_pct` | `all_seasons` (1997–2023). |
| `in_stats`, `in_salary`, `in_all_seasons` | 1 hvis raden finnes i den kilden. Bruk disse til å avgrense utvalg. |
| `multi_team` | 1 hvis spilleren hadde flere lag samme sesong. `team_abbreviation` viser da alle lag (`CLE/BOS`), og statistikken er fra laget med flest kamper. |
| `id_match` | `nba_id` eller `name_only` (se del 1). |

Prosentvariabler har samme skala som kilden (0–1); ikke gang med 100.

### Dekning og hull man må vite om

- Statsfilen og lønnsfilen dekker 2000–2025, `all_seasons` 1997–2023. Rader
  fra bare `all_seasons` (1997–1999 og spillere uten lønnsdata) har `NA` for
  lønn, posisjon og de fleste statistikkfelt. Rader fra bare lønnsfilen har
  bare lønn.
- Statsfilen er tynn i 2000 og 2003–2005 (115–270 rader mot normalt 400–500),
  og enkeltspillere kan mangle i enkelte år (f.eks. LeBron James 2018 mangler
  i begge lønnsfiler). `NA` betyr «ikke i kilden», ikke null.
- Registeret (`player.csv`) stopper i 2023. Alle som debuterte senere har
  `n_`-ID og mangler fødselsdato og biodata.

## 4. `family_relations.csv` (én rad per relasjon)

| Kolonne | Innhold |
|---|---|
| `familyID` | Samme som i `player_bio.csv`. |
| `person1_playerID`, `person2_playerID` (+ navn) | For `father_son`: person1 er far, person2 er sønn. For `sibling`: ett par per rad, uten retning. |
| `relation_type` | `father_son` eller `sibling`. |
| `source` | `father_son_list.csv`, `nba_siblings_list.csv` eller `father_son_list.csv (shared father)` (to sønner med samme far regnes som brødre). |

Når far og sønn har samme navn (`Mike Dunleavy`), velges eldste kandidat som
far og yngste som sønn. Finnes bare én av dem i registeret, får den andre en
`n_`-rad. `results/family_relations_check.csv` viser hvordan hvert par ble
koblet; status `linked_father_reassigned_assumed` betyr at pipen antok at
personen i registeret er sønnen (gjelder Guokas og Vaughn).

## 5. Variabler som bare finnes i analysen

`scripts/02_analysis.R` lager noen variabler som ikke ligger i CSV-filene.
De viktigste:

| Variabel | Hvordan den lages | Brukes til |
|---|---|---|
| `first_season`, `last_season`, `n_seasons` | Første/siste sesong og antall sesonger per spiller i `player_seasons.csv` (altså innenfor 1997–2025, ikke hele karrieren) | Karrieretabellen |
| `debut_decade` (debuttiår) | `floor(first_season / 10) * 10`: 1997 → 1990, 2004 → 2000, 2019 → 2010. Bygger på første sesong i våre data, ikke på `career_start` i bio | Kontroll for epoke i regresjonen, fordi poeng, treere og lønn har endret seg over tid |
| `games_per_season`, `salary_per_season` | Totalt antall kamper / lønn delt på antall sesonger. Lønn i millioner USD | Sammenligninger mellom grupper |
| Karrieregjennomsnitt (`pts_pg`, `reb_pg`, …) | Gjennomsnitt over sesonger vektet med antall kamper | Sammenligninger mellom grupper og par |
| `height` | `height_cm` fra bio, ellers høyeste sesonghøyde fra `all_seasons` | Høydeanalysen og som kontroll |
| `nba_family`, `is_brother` | `familyID > 0` og `brother_dummy == 1` | Gruppeinndeling |
| `position` (primær) | Den posisjonen spilleren oftest er oppført med; `PF-C` regnes som `PF`; `Unknown` når ingen sesong har posisjon | Kontroll i regresjonen |
| `league_mean` per tiår | Gjennomsnittshøyde i bio etter tiåret for `career_start` (her brukes registeret, fordi fedrene spilte før 1997) | Referanse i høydeanalysen |

Gruppesammenligningene og karriereregresjonen bruker bare spillere med
minst 20 kamper i karrieren (`min_games`), og panelregresjonene bare
spiller-sesonger med minst 10 kamper (`min_games_season`), fordi få kamper
gir ekstreme per-kamp-verdier.

Panelet (`panel` i scriptet) har i tillegg `experience` = sesonger siden
NBA-debut (fra `career_start` i registeret, ellers første sesong i data), `season_f` = sesong som faktor (sesong-fixed-effects)
og `log_salary`. Lønnsmodellen i del 9 gir `predicted_salary`, `residual`
(i log-poeng: 0,69 = tjente dobbelt så mye som predikert) og `ratio` =
faktisk/predikert lønn.

## 6. Anbefalt bruk

- Koble filene på `playerID`. Bruk `in_stats`/`in_salary`/`in_all_seasons`
  til å velge rader med de variablene analysen trenger.
- For lønns- og prestasjonsanalyser: vurder å begrense til `id_match ==
  "nba_id"` eller sjekk `n_`-spillerne i `results/name_matching_review.csv`.
- For familieanalyser: `family_relations.csv` gir konkrete par, `familyID`
  grupperer hele familier.
