# NBA datasetoversikt

## Kategori

Datasett blir klassifisert som `player-season` når filen inneholder en sesongrelatert variabel som `season`, `season_year`, `season_id` eller `year`. Hvis slike variabler mangler, klassifiseres datasettet som `player-career`.

## 1) Player-season-data

| Fil | Nivå | Observasjoner | Variabler | Eldste/nyeste sesong | Draft year |
| --- | --- | ---: | --- | --- | --- |
| all_seasons.csv | player-season | 12844 | ...1; player_name; team_abbreviation; age; player_height; player_weight; college; country; draft_year; draft_round; draft_number; gp; pts; reb; ast; net_rating; oreb_pct; dreb_pct; usg_pct; ts_pct; ast_pct; season | 1996 to 2022 | 1963 to 2022 |
| NBA Player Salaries_2000-2025.csv | player-season | 12386 | Player; Salary; Season | 2000 to 2025 | ikke tilgjengelig |
| NBA Player Stats and Salaries_2000-2025.csv | player-season | 10473 | Player; Salary; Year; Pos; Age; Team; G; GS; MP; FG; FGA; FG%; 3P; 3PA; 3P%; 2P; 2PA; 2P%; eFG%; FT; FTA; FT%; ORB; DRB; TRB; AST; STL; BLK; TOV; PF; PTS | 2000 to 2025 | ikke tilgjengelig |
| NBA Player Stats and Salaries_2010-2025.csv | player-season |  7298 | Player; Salary; Year; Pos; Age; Team; G; GS; MP; FG; FGA; FG%; 3P; 3PA; 3P%; 2P; 2PA; 2P%; eFG%; FT; FTA; FT%; ORB; DRB; TRB; AST; STL; BLK; TOV; PF; PTS | 2010 to 2025 | ikke tilgjengelig |
| nba-salaries.csv | player-season |  9456 | rank; name; position; team; salary; season | 2000 to 2020 | ikke tilgjengelig |

## 2) Player-career-data

| Fil | Nivå | Observasjoner | Variabler | Eldste/nyeste sesong | Draft year |
| --- | --- | ---: | --- | --- | --- |
| common_player_info.csv | player-career | 4171 | person_id; first_name; last_name; display_first_last; display_last_comma_first; display_fi_last; player_slug; birthdate; school; country; last_affiliation; height; weight; season_exp; jersey; position; rosterstatus; games_played_current_season_flag; team_id; team_name; team_abbreviation; team_code; team_city; playercode; from_year; to_year; dleague_flag; nba_flag; games_played_flag; draft_year; draft_round; draft_number; greatest_75_flag | ikke tilgjengelig | 1947 to 2022 |
| father_son_list.csv | player-career |  113 | father; sons | ikke tilgjengelig | ikke tilgjengelig |
| nba_siblings_list.csv | player-career |  157 | person_id; family_id; first_name; last_name; full_name | ikke tilgjengelig | ikke tilgjengelig |

## 3) Variabelliste for alle relevante CSV-filer

| Fil | Mappe | Variabler |
| --- | --- | --- |
| all_seasons.csv | data | ...1; player_name; team_abbreviation; age; player_height; player_weight; college; country; draft_year; draft_round; draft_number; gp; pts; reb; ast; net_rating; oreb_pct; dreb_pct; usg_pct; ts_pct; ast_pct; season |
| common_player_info.csv | archive_wyatt/csv | person_id; first_name; last_name; display_first_last; display_last_comma_first; display_fi_last; player_slug; birthdate; school; country; last_affiliation; height; weight; season_exp; jersey; position; rosterstatus; games_played_current_season_flag; team_id; team_name; team_abbreviation; team_code; team_city; playercode; from_year; to_year; dleague_flag; nba_flag; games_played_flag; draft_year; draft_round; draft_number; greatest_75_flag |
| father_son_list.csv | data | father; sons |
| NBA Player Salaries_2000-2025.csv | data | Player; Salary; Season |
| NBA Player Stats and Salaries_2000-2025.csv | data | Player; Salary; Year; Pos; Age; Team; G; GS; MP; FG; FGA; FG%; 3P; 3PA; 3P%; 2P; 2PA; 2P%; eFG%; FT; FTA; FT%; ORB; DRB; TRB; AST; STL; BLK; TOV; PF; PTS |
| NBA Player Stats and Salaries_2010-2025.csv | data | Player; Salary; Year; Pos; Age; Team; G; GS; MP; FG; FGA; FG%; 3P; 3PA; 3P%; 2P; 2PA; 2P%; eFG%; FT; FTA; FT%; ORB; DRB; TRB; AST; STL; BLK; TOV; PF; PTS |
| nba_siblings_list.csv | data | person_id; family_id; first_name; last_name; full_name |
| nba-salaries.csv | data | rank; name; position; team; salary; season |

## 4) Kort beskrivelse

- `player-season` er datasett som beskriver observasjoner pr. sesong eller per år.
- `player-career` er datasett som beskriver spillere over hele karrieren og ofte inneholder variabler som `from_year`, `to_year`, `season_exp` eller `draft_year`.
- Wyatt-arkivet brukes kun via `data/archive_wyatt/csv/common_player_info.csv` i denne oversikten.

