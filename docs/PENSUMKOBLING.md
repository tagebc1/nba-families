# Pensumkobling: hvor prosjektet bruker stoff fra ECON3170/4170

Oppgaveteksten krever at prosjektet «draws on material from the course».
Denne oversikten viser hva fra hver forelesning og seminar som faktisk er
brukt, og hvor i koden det skjer. Bruk den når du skriver metodekapittelet og
AI-avsnittet. Nederst står ting kurset har lært som vi *ikke* bruker, med en
vurdering av om de er verdt å legge til før fristen.

## Brukt i prosjektet

| Forelesning | Tema | Hvor i prosjektet |
|---|---|---|
| L2 Programmering | Funksjoner med defaultverdier, `if/else`, `for`-løkker, vektorisering med `ifelse()`, logiske vektorer | `scripts/helpers.R`: `normalize_name()`, `split_name()`, `resolve_identity()` (løkke over ~25 000 unike navn/sesong-enheter med vektoriserte kandidatfiltre inni) |
| L2 Programmering | Algoritme skrevet fra bunnen | `01_build_player_data.R` del 5: union–find for `familyID` (koblede komponenter over far–sønn- og søskenkanter) |
| L3 Tidyverse | `filter`, `mutate`, `summarise(.by)`, `group_by`, `across`, `pivot_longer`/`pivot_wider`, piping | `scripts/02_analysis.R` gjennomgående; `pair_long()` bruker `pivot_longer` + `pivot_wider` for parvise sammenligninger |
| L3 Tidyverse | Tidy data: én rad per observasjon | `player_seasons.csv` (spiller × sesong) og `family_relations.csv` (én rad per relasjon) i stedet for `son1_ID`, `son2_ID`-kolonner |
| L3 Kodestil og mappestruktur | Mapper for data/kode/figurer/rapport, kommentarer som forklarer *hvorfor*, under 80–120 tegn | Prosjektstrukturen i `README.md`; kommentarene i `01_build_player_data.R` |
| L4 Visualisering | ggplot2-lag, `theme_minimal()`, `scales::label_dollar`, direkte etiketter, felles akse, ingen 3D, fargeblindvennlig palett | `02_analysis.R`: `fig01`–`fig06`; `save_fig()` |
| L4 Tabeller og Quarto | `knitr::kable()`, Quarto med `fig-cap`/`tbl-cap`, `echo: false` | `reports/analysis.qmd`, `reports/build_player_data.qmd` |
| L5 Digitale data | Tegnkoding: BOM i statsfilen, `iconv(..., "ASCII//TRANSLIT")` for «Nenê», UTF-8 | `read_input()` med `fileEncoding = "UTF-8-BOM"`; `normalize_name()` |
| L5 Digitale data | Flyttall: ikke test likhet på desimaltall | Aldersmatching bruker heltallsdifferanser med toleranse, ikke `==` |
| L5 Kodehåndverk | Kodeheadere (`# ---- `), forhåndsallokerte vektorer i løkker, vektorisering der det går | `resolve_identity()` forhåndsallokerer `out_id`, `out_type`; seksjonsheadere i begge script |
| L6 Data import | `na.strings`, kolonnesjekk før bruk, ikke rediger råfilen manuelt | `read_input()`, `require_columns()`; råfilene i `data/` er uendret, alle fikser ligger i kode eller i `name_aliases.csv` |
| L6 Datoer | `as.Date`, aldersberegning fra fødselsdato og referansedato | `age_diff()` i `helpers.R` (alder per 1. feb / 1. juli) |
| L6 Joins | `inner_join`, `left_join`, `bind_rows`, nøkler som ikke er unike gir dupliserte rader | `bind_rows` av tre kilder til `obs`; `match()`/`left_join` på `playerID`; navn-nøkkel er *ikke* unik, derfor hele identitetsløsningen |
| L6 «Challenging joins» | Probabilistisk matching når ID mangler: navn + fødselsdato, «hvor sannsynlig er det at dette er samme person» | Kjernen i `resolve_identity()`: navn → kandidater → karriereår, draftår, alder. Samme problem som slide 38 (1910-folketellingen uten personnummer) |
| L6 Web scraping | `rvest`: `read_html`, `html_elements`, `html_table` | `scripts/00_scrape_father_son_list.R` (Wikipedia-listen over andregenerasjons NBA-spillere) |
| L7 Relasjonsdatabaser | Flere tabeller koblet med nøkler i stedet for én stor tabell | Outputen er en liten relasjonsdatabase: `player_bio` (spiller), `player_seasons` (spiller × sesong), `family_relations` (par), alle koblet på `playerID` |
| L8 Modellering | `lm()` med faktorvariabler (dummyfella løses av R), tolkning av koeffisienter, `predict`/`broom` | Regresjonen i `02_analysis.R` del 8: sønn + bror + høyde + debuttiår + posisjon |
| L8 Bootstrap | Trekk med tilbakelegging, gjenta, bruk fordelingen som usikkerhetsmål | `cohens_d()`: 1 000 bootstrap-trekk gir 95 %-intervall for Cohen's d |
| L9 ML og økonomi | «Rows are not independent»: enheter som henger sammen må behandles sammen | Klyngede standardfeil på `familyID` (`cluster_vcov()`), fordi slektninger ikke er uavhengige observasjoner |
| L9 Prediksjon vs. kausalitet | ML/regresjon finner korrelasjoner; «what if»-spørsmål krever mer | Hele tolkningen av resultatene: forskjeller mellom dem som nådde NBA, ikke effekter av å ha NBA-familie (seleksjon/survivorship) |
| L10 Tekst | `stringr`/regex: `str_detect`-logikk, `\\b`, `perl = TRUE`, små bokstaver, fjerne tegnsetting | `normalize_name()`; alias-tabellen er i praksis en «dictionary» (L10, ordlister) |
| L11 LLM som måleinstrument | Pin modellen, valider mot kjente svar, stress-test, behandle output som støyete måling, arkiver output | `nba_siblings_list.csv` ble først laget med Gemini fra en nettside; sammenligning mot et eget parse-script (`00_make_siblings_list.R`) avslørte at KI-versjonen hadde slått sammen to Grant-familier. Nå lages filen av scriptet. Passer rett inn i AI-avsnittet |
| L11 Scraping ansvarlig | Les robots.txt, dokumenter hva som feilet | Arbeidsloggen: basketball-reference blokkerte, hoopshype hadde betalingsmur, derfor Kaggle |
| Seminar 1 | `t.test`, bootstrap av gjennomsnitt | Parvise t-tester i `pair_summary()`; bootstrap i `cohens_d()` |
| Seminar 4 | `lag()`, `left_join`, kumulative serier, stacked/line-charts med ggplot | `fig03` (kumulativ lønn med `cumsum`), `fig05` |
| Seminar 5 | Lang/bred omforming, slå sammen filer med ulik struktur, siste observasjon per enhet | `pivot_wider` i `pair_long()`, `slice_max` for primærposisjon |

## Ting kurset har lært som vi ikke bruker

| Tema | Vurdering |
|---|---|
| Tidyverse i datapipen | `01_build_player_data.R` er skrevet i base R (`read.csv`, `aggregate`, `match`), mens kurset bruker tidyverse. Koden er ryddig og uten avhengigheter, men det kan være verdt én setning i oppgaven om hvorfor (reproduserbarhet uten pakker, ytelse i løkken). En omskriving til tidyverse er ikke verdt tiden før fristen. |
| Nummererte scriptnavn (`00_`, `01_`, `02_`) | Gjort: `00_scrape_father_son_list.R` (datainnsamling, kjøres én gang), `01_build_player_data.R`, `02_analysis.R`. `helpers.R` er unummerert fordi den bare `source()`-es, ikke kjøres. |
| `readr::read_csv` / `read_rds` | Kurset foretrekker `read_csv` og å lagre analysedata som `.rds`. Vi bruker CSV for output fordi det skal kunne åpnes av andre; kan nevnes. |
| Train/test-splitt, LASSO, tidymodels (L8, seminar 6) | Prediksjon er ikke spørsmålet vårt. En liten prediksjonsøvelse (f.eks. predikere lønn fra statistikk, med og uten familiedummy, og sammenligne test-RMSE) ville vært «pensumnært», men er ikke nødvendig når datainnhentingen er hovedbidraget. Bare hvis du har tid til overs. |
| `modelsummary`/`texreg` for regresjonstabeller (L4) | Ikke installert. `kable` av en egen tabell er godt nok. |
| Git/GitHub (L6) | Prosjektet ligger i OneDrive uten versjonskontroll. Oppgaven tillater kode på GitHub som vedlegg; `archive/` og `docs/ARBEIDSLOGG.md` fungerer som manuell historikk. Verdt å nevne som lærdom. |
| Databaser/SQL, geodata, tekstanalyse, LLM-embeddings (L7, L10, L11) | Ikke relevant for spørsmålene. `archive_wyatt/nba.sqlite` finnes, men CSV-filene fra samme kilde er enklere. |
| Numerisk optimering (seminar 8) | Ikke relevant. |

## Forslag til formulering i metodekapittelet

Kjernen i prosjektet er et *record linkage*-problem (L6): tre kilder deler
ikke ID, bare navn, og navn er verken unike eller stavet likt. Løsningen
følger kursets oppskrift for «challenging joins»: normaliser nøkkelen,
finn kandidater, og bruk tilleggsinformasjon (fødselsdato, draftår,
karriereår) til å velge den mest sannsynlige. Alle usikre koblinger logges
til gjennomgang i stedet for å avgjøres stille. Analysen er beskrivende
(L9): gruppeforskjeller med bootstrap-intervaller, parvise tester innen
familier, og en regresjon med klyngede standardfeil som holder høyde,
epoke og posisjon fast. Ingen av delene tolkes som årsakseffekter.
