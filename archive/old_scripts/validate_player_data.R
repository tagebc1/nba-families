# Validate NBA player data across multiple CSV sources
# This script compares names and values across datasets to flag
# suspicious entries and possible source problems.

library(readr)
library(dplyr)
library(stringr)
library(tidyr)
library(glue)

project_dir <- getwd()
data_dir <- file.path(project_dir, "data")
out_dir <- file.path(project_dir, "results")
dir.create(out_dir, showWarnings = FALSE)

normalize_name <- function(x) {
  x %>%
    str_to_lower() %>%
    str_replace_all("[[:punct:]]+", " ") %>%
    str_replace_all("\\s+", " ") %>%
    str_squish() %>%
    str_trim()
}

# 1) Read data
all_seasons <- read_csv(
  file.path(data_dir, "all_seasons.csv"),
  show_col_types = FALSE
)

salary_2000_2025 <- read_csv(
  file.path(data_dir, "NBA Player Salaries_2000-2025.csv"),
  show_col_types = FALSE
)

stats_and_salaries <- read_csv(
  file.path(data_dir, "NBA Player Stats and Salaries_2000-2025.csv"),
  show_col_types = FALSE
)

nba_salaries <- read_csv(
  file.path(data_dir, "nba-salaries.csv"),
  show_col_types = FALSE
)

archive_player <- read_csv(
  file.path(data_dir, "archive_wyatt", "csv", "player.csv"),
  show_col_types = FALSE
)

archive_common <- read_csv(
  file.path(data_dir, "archive_wyatt", "csv", "common_player_info.csv"),
  show_col_types = FALSE
)

# 2) Standardize names and season numbers
all_seasons_clean <- all_seasons %>%
  rename(player_name = player_name) %>%
  mutate(
    name_norm = normalize_name(player_name),
    season_year = as.integer(str_sub(season, 1, 4))
  ) %>%
  select(
    player_name,
    name_norm,
    season,
    season_year,
    team_abbreviation,
    gp,
    pts,
    reb,
    ast,
    everything()
  )

salary_2000_2025_clean <- salary_2000_2025 %>%
  rename(player_name = Player, salary = Salary, season_year = Year) %>%
  mutate(
    name_norm = normalize_name(player_name),
    salary = as.numeric(salary),
    season_year = as.integer(season_year)
  ) %>%
  select(player_name, name_norm, season_year, salary)

stats_and_salaries_clean <- stats_and_salaries %>%
  rename(player_name = Player, salary = Salary, season_year = Year) %>%
  mutate(
    name_norm = normalize_name(player_name),
    salary = as.numeric(salary),
    season_year = as.integer(season_year)
  ) %>%
  select(player_name, name_norm, season_year, salary)

nba_salaries_clean <- nba_salaries %>%
  rename(player_name = name, salary = salary, season_year = season) %>%
  mutate(
    name_norm = normalize_name(player_name),
    salary = as.numeric(salary),
    season_year = as.integer(season_year)
  ) %>%
  select(player_name, name_norm, season_year, salary)

archive_player_clean <- archive_player %>%
  mutate(
    name_norm = normalize_name(full_name),
    id = as.integer(id)
  ) %>%
  select(id, full_name, first_name, last_name, name_norm)

archive_common_clean <- archive_common %>%
  mutate(
    name_norm = normalize_name(paste(first_name, last_name)),
    birthdate = as.Date(str_sub(birthdate, 1, 10))
  ) %>%
  select(
    person_id,
    first_name,
    last_name,
    full_name = display_first_last,
    name_norm,
    birthdate,
    school,
    country,
    height,
    weight,
    position
  )

# 3) Compare names across sources
name_coverage <- all_seasons_clean %>%
  distinct(name_norm) %>%
  left_join(
    archive_common_clean %>%
      distinct(name_norm) %>%
      mutate(in_archive = TRUE),
    by = "name_norm"
  ) %>%
  mutate(in_archive = replace_na(in_archive, FALSE)) %>%
  summarise(
    total_players = n(),
    matched_in_archive = sum(in_archive),
    coverage_pct = round(100 * matched_in_archive / total_players, 2)
  )

# 4) Compare salary values across sources for same player-season
salary_compare <- all_seasons_clean %>%
  distinct(name_norm, season_year) %>%
  left_join(salary_2000_2025_clean, by = c("name_norm", "season_year")) %>%
  rename(salary_source_1 = salary) %>%
  left_join(stats_and_salaries_clean, by = c("name_norm", "season_year")) %>%
  rename(salary_source_2 = salary) %>%
  left_join(nba_salaries_clean, by = c("name_norm", "season_year")) %>%
  rename(salary_source_3 = salary) %>%
  mutate(
    source_count = rowSums(
      !is.na(across(c(salary_source_1, salary_source_2, salary_source_3)))
    ),
    any_match = source_count > 0,
    diff_1_2 = if_else(
      !is.na(salary_source_1) & !is.na(salary_source_2),
      abs(salary_source_1 - salary_source_2),
      NA_real_
    ),
    diff_1_3 = if_else(
      !is.na(salary_source_1) & !is.na(salary_source_3),
      abs(salary_source_1 - salary_source_3),
      NA_real_
    ),
    diff_2_3 = if_else(
      !is.na(salary_source_2) & !is.na(salary_source_3),
      abs(salary_source_2 - salary_source_3),
      NA_real_
    ),
    suspicious_salary = case_when(
      source_count >= 2 &
        ((!is.na(diff_1_2) & diff_1_2 > 1000000) |
          (!is.na(diff_1_3) & diff_1_3 > 1000000) |
          (!is.na(diff_2_3) & diff_2_3 > 1000000)) ~ TRUE,
      TRUE ~ FALSE
    )
  )

# 5) Flag suspicious names or duplicates
archive_duplicates <- archive_common_clean %>%
  count(name_norm, sort = TRUE) %>%
  filter(n > 1) %>%
  rename(n_records = n)

all_seasons_duplicates <- all_seasons_clean %>%
  count(name_norm, season_year, sort = TRUE) %>%
  filter(n > 1) %>%
  rename(n_rows = n)

# 6) Build a clean validation report
validation_report <- salary_compare %>%
  filter(any_match) %>%
  mutate(
    suspicious_salary = as.logical(suspicious_salary),
    name_norm = as.character(name_norm)
  ) %>%
  arrange(desc(suspicious_salary), desc(source_count))

# 7) Save outputs
write_csv(
  name_coverage,
  file.path(out_dir, "player_name_coverage_vs_archive.csv")
)
write_csv(validation_report, file.path(out_dir, "salary_validation_report.csv"))
write_csv(archive_duplicates, file.path(out_dir, "archive_name_duplicates.csv"))
write_csv(
  all_seasons_duplicates,
  file.path(out_dir, "all_seasons_name_duplicates.csv")
)

# 8) Print concise summary
cat("\nName coverage vs archive:\n")
print(name_coverage)

cat("\nSuspicious salary comparisons:\n")
print(
  validation_report %>%
    filter(suspicious_salary) %>%
    select(
      name_norm,
      season_year,
      salary_source_1,
      salary_source_2,
      salary_source_3,
      diff_1_2,
      diff_1_3,
      diff_2_3
    )
)

cat("\nArchive duplicate names:\n")
print(archive_duplicates)

cat("\nAll-seasons duplicate player-season rows:\n")
print(all_seasons_duplicates)

# 9) Notes:
# - The archive_wyatt data is a large official NBA database and typically has strong internal consistency.
# - Large salary differences across sources are more likely to reflect source differences, naming mismatches,
#   or a player whose team / salary record changes than a true error in the archive database.
# - This script is designed to highlight mismatches rather than silently trusting any single source.
