# NBA_Project

![LeBron og Bronny James](images/LeNepotism.jpg)

Datasett og analyse av NBA-spillere, lønn og familierelasjoner.
Term paper i ECON3170/4170, høsten 2026.

## Kjør

Krever R versjon 4.3 eller nyere med pakkene dplyr, tidyr, ggplot2, scales og knitr, og
Quarto 1.4 eller nyere for rapportene. Fra prosjektroten:

```sh
Rscript scripts/01_build_player_data.R        # bygger datasettene i data/output_data/
Rscript scripts/02_analysis.R                 # figurer og tabeller til results/
quarto render reports/build_player_data.qmd   # bygger + kontrollerer + rapport
quarto render reports/analysis.qmd            # analyserapport
quarto render termpaper/NBA_familier_prosjekt.qmd   # oppgaven til PDF (typst)
```

`_quarto.yml` gjør at koden i `reports/` kjører fra prosjektroten, så alle
stier i qmd-filene er relative til roten.

Repoet inneholder alle råfiler som trengs (ca. 10 MB). Fra Kaggle-arkivet
til Walsh er bare de tre filene pipen leser tatt med (`player.csv`,
`common_player_info.csv`, `draft_history.csv`); resten av arkivet på 4 GB
er utelatt. `data/output_data/` og `results/` ligger i repoet for lesbarhet,
men gjenskapes identisk av scriptene.

## Struktur

```
README.md                   denne filen
_quarto.yml                 Quarto-innstillinger (kjør fra prosjektroten)

data/                       RÅFILER (endres aldri av koden)
  all_seasons.csv                        spiller–sesong 1996-97 til 2022-23
  NBA Player Stats and Salaries_2000-2025.csv
  NBA Player Salaries_2000-2025.csv
  archive_wyatt/csv/                     NBA-register: player.csv, common_player_info.csv, draft_history.csv
  father_son_list.csv, nba_siblings_list.csv   familielister
  name_aliases.csv                       manuell liste: kallenavn -> navn i registeret
  output_data/                GENERERT av scripts/01_build_player_data.R
    player_bio.csv                       én rad per spiller
    player_seasons.csv                   én rad per spiller og sesong
    family_relations.csv                 én rad per far–sønn- eller søskenpar

scripts/
  01_build_player_data.R         hele datapipen (bio + seasons + familier)
  helpers.R                   hjelpefunksjoner (navnenormalisering, ID-kobling)
  02_analysis.R                  analysen: figurer og tabeller fra output_data
  00_scrape_father_son_list.R   scraper far–sønn-listen fra Wikipedia (datainnsamling)
  00_make_siblings_list.R       lager søskenlisten fra FanSided-listen (datainnsamling)

reports/                    Quarto-rapporter og rendret HTML
  build_player_data.qmd       kjører datapipen og kontrollerer output
  analysis.qmd                kjører analysen og viser figurer og tabeller

results/                    GENERERT
  build_report.csv, name_matching_review.csv, family_relations_check.csv
  figures/                    figurer fra 02_analysis.R
  analysis/                   tabeller fra 02_analysis.R

docs/                       dokumentasjon
  VIKTIGE_BEMERKELSER.md      variabler, ID-regler og begrensninger i datasettene
  ARBEIDSLOGG.md              hva som ble gjort når, inkludert bruk av AI
  PENSUMKOBLING.md            hvor prosjektet bruker stoff fra forelesningene og seminarene
  PROSJEKTBESKRIVELSE_og_KILDER.md   mål, ideer og datakilder

termpaper/                  selve oppgaven: NBA_familier_prosjekt.qmd, references.bib, PDF
                            (figurer kopieres hit fra results/figures ved rendering)

archive/                    tidligere versjoner: gamle script, data, resultater og rapporter
                            fra før pipen ble skrevet om (brukes ikke av koden)
Skittentøy/                 kladd og forsøk underveis: scraping-script for lønn 1991–99,
                            lagrede nettsider, lister over manglende rader
```

`archive/` og `Skittentøy/` ligger i repoet for å vise arbeidsgangen, men
ingenting der brukes av de nåværende scriptene. `HowToTermpaper/`
(oppgavetekst og mal), HTML-rapportene og resten av Walsh-arkivet er holdt
utenfor med `.gitignore`.
