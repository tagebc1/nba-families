# NBA Project: dataset overview

Dette prosjektet inneholder flere CSV-filer med NBA-data. For å gjøre datasettet lettere å forstå og bruke, er filene klassifisert etter om de beskriver observasjoner per sesong (`player-season`) eller over en spillerkarriere (`player-career`).

## Kategorisering

-   `player-season`: filen inneholder en sesongrelatert variabel som `season`, `season_year`, `season_id` eller `year`.
-   `player-career`: filen mangler sesongvariabel og beskriver i stedet spillerkarriere eller persondata.
-   Wyatt-arkivet brukes kun gjennom `data/archive_wyatt/csv/common_player_info.csv`.

## Player-season datasets

Disse filene har sesonginformasjon og er dermed klassifisert som `player-season`.

| File | Observations | Variables | Oldest / newest seasons | Draft years |
|---------------|--------------:|---------------|---------------|---------------|
| `all_seasons.csv` | 12,844 | `...1; player_name; team_abbreviation; age; player_height; player_weight; college; country; draft_year; draft_round; draft_number; gp; pts; reb; ast; net_rating; oreb_pct; dreb_pct; usg_pct; ts_pct; ast_pct; season` | 1996 to 2022 | 1963 to 2022 |
| `NBA Player Salaries_2000-2025.csv` | 12,386 | `Player; Salary; Season` | 2000 to 2025 | ikke tilgjengelig |
| `NBA Player Stats and Salaries_2000-2025.csv` | 10,473 | `Player; Salary; Year; Pos; Age; Team; G; GS; MP; FG; FGA; FG%; 3P; 3PA; 3P%; 2P; 2PA; 2P%; eFG%; FT; FTA; FT%; ORB; DRB; TRB; AST; STL; BLK; TOV; PF; PTS` | 2000 to 2025 | ikke tilgjengelig |

## Player-career datasets

Disse filene mangler sesongkolonne og er derfor klassifisert som `player-career`.

| File | Observations | Variables | Oldest / newest season | Draft year |
|---------------|--------------:|---------------|---------------|---------------|
| `common_player_info.csv` | 4,171 | `person_id; first_name; last_name; display_first_last; display_last_comma_first; display_fi_last; player_slug; birthdate; school; country; last_affiliation; height; weight; season_exp; jersey; position; rosterstatus; games_played_current_season_flag; team_id; team_name; team_abbreviation; team_code; team_city; playercode; from_year; to_year; dleague_flag; nba_flag; games_played_flag; draft_year; draft_round; draft_number; greatest_75_flag` | ikke tilgjengelig | 1947 to 2022 |
| `father_son_list.csv` | 113 | `father; sons` | ikke tilgjengelig | ikke tilgjengelig |
| `nba_siblings_list.csv` | 157 | `person_id; family_id; first_name; last_name; full_name` | ikke tilgjengelig | ikke tilgjengelig |

## Variabler i hver CSV-fil

| File | Folder | Variables |
|------------------------|------------------------|------------------------|
| `all_seasons.csv` | `data` | `...1; player_name; team_abbreviation; age; player_height; player_weight; college; country; draft_year; draft_round; draft_number; gp; pts; reb; ast; net_rating; oreb_pct; dreb_pct; usg_pct; ts_pct; ast_pct; season` |
| `common_player_info.csv` | `data/archive_wyatt/csv` | `person_id; first_name; last_name; display_first_last; display_last_comma_first; display_fi_last; player_slug; birthdate; school; country; last_affiliation; height; weight; season_exp; jersey; position; rosterstatus; games_played_current_season_flag; team_id; team_name; team_abbreviation; team_code; team_city; playercode; from_year; to_year; dleague_flag; nba_flag; games_played_flag; draft_year; draft_round; draft_number; greatest_75_flag` |
| `father_son_list.csv` | `data` | `father; sons` |
| `NBA Player Salaries_2000-2025.csv` | `data` | `Player; Salary; Season` |
| `NBA Player Stats and Salaries_2000-2025.csv` | `data` | `Player; Salary; Year; Pos; Age; Team; G; GS; MP; FG; FGA; FG%; 3P; 3PA; 3P%; 2P; 2PA; 2P%; eFG%; FT; FTA; FT%; ORB; DRB; TRB; AST; STL; BLK; TOV; PF; PTS` |
| `nba_siblings_list.csv` | `data` | `person_id; family_id; first_name; last_name; full_name` |
| `nba-salaries.csv` | `data` | `rank; name; position; team; salary; season` |

## Kort oppsummering

-   `player-season`-filene er de som har tydelig sesonginformasjon og er mest relevante for tidsserie- eller sesongbasert analyse.
-   `player-career`-filene er mer person- og karriereorienterte og brukes typisk til analyse av spillernes livsløp, draft-status eller historiske bakgrunnsdata.
-   `draft year` er tilgjengelig i `all_seasons.csv` og `common_player_info.csv`, mens flere sesongbaserte filer ikke inneholder denne variabelen.