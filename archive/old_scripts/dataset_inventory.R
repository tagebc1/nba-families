suppressPackageStartupMessages({
  library(readr)
  library(stringr)
  library(dplyr)
})

project_root <- normalizePath(".")
data_dir <- file.path(project_root, "data")
wyatt_file <- file.path(data_dir, "archive_wyatt", "csv", "common_player_info.csv")
results_dir <- file.path(project_root, "results")
if (!dir.exists(results_dir)) dir.create(results_dir, recursive = TRUE)

root_csv_files <- list.files(
  path = data_dir,
  pattern = "\\.csv$",
  full.names = TRUE,
  recursive = FALSE
)
root_csv_files <- root_csv_files[!grepl("archive_wyatt", root_csv_files)]

csv_files <- sort(unique(c(root_csv_files, wyatt_file)))

extract_year_range <- function(x) {
  years <- suppressWarnings(as.numeric(str_extract(as.character(x), "\\d{4}")))
  years <- years[!is.na(years)]
  if (length(years) == 0) return(NA_character_)
  paste(min(years), max(years), sep = " to ")
}

has_season_variable <- function(df) {
  names_lower <- tolower(names(df))
  any(names_lower %in% c("season", "season_year", "season_id", "year"))
}

variable_overview <- lapply(csv_files, function(path) {
  df <- read_csv(path, show_col_types = FALSE, n_max = 0)
  data.frame(
    file = basename(path),
    folder = if (grepl("archive_wyatt", path)) "archive_wyatt/csv" else "data",
    variables = paste(names(df), collapse = "; "),
    stringsAsFactors = FALSE
  )
})
variable_overview <- bind_rows(variable_overview)

inventory <- lapply(csv_files, function(path) {
  df <- read_csv(path, show_col_types = FALSE)
  names_lower <- tolower(names(df))

  season_col <- names(df)[names_lower %in% c("season", "season_year", "season_id", "year")]
  if (length(season_col) == 0) {
    season_col <- names(df)[grepl("season", names_lower)]
  }

  draft_col <- names(df)[names_lower %in% c("draft_year")]
  if (length(draft_col) == 0) {
    draft_col <- names(df)[grepl("draft", names_lower)]
  }

  season_range <- if (length(season_col) > 0) extract_year_range(df[[season_col[1]]]) else NA_character_
  draft_range <- if (length(draft_col) > 0) extract_year_range(df[[draft_col[1]]]) else NA_character_

  dataset_type <- if (has_season_variable(df)) {
    "player-season"
  } else {
    "player-career"
  }

  data.frame(
    file = basename(path),
    dataset_type = dataset_type,
    n_observations = nrow(df),
    variables = paste(names(df), collapse = "; "),
    oldest_newest_season = season_range,
    draft_year_range = draft_range,
    stringsAsFactors = FALSE
  )
})
inventory <- bind_rows(inventory)

write_csv(variable_overview, file.path(results_dir, "csv_column_names_overview.csv"))
write_csv(inventory, file.path(results_dir, "dataset_inventory.csv"))

player_season_rows <- inventory[inventory$dataset_type == "player-season", , drop = FALSE]
player_career_rows <- inventory[inventory$dataset_type == "player-career", , drop = FALSE]

variable_table_lines <- c(
  "| Fil | Mappe | Variabler |",
  "| --- | --- | --- |",
  apply(variable_overview, 1, function(row) {
    paste0("| ", row["file"], " | ", row["folder"], " | ", row["variables"], " |")
  })
)

make_inventory_lines <- function(df) {
  if (nrow(df) == 0) {
    return(c("| Ingen filer |  |  |  |  |  |", "| --- | --- | --- | --- | --- | --- |"))
  }
  c(
    "| Fil | Nivå | Observasjoner | Variabler | Eldste/nyeste sesong | Draft year |",
    "| --- | --- | ---: | --- | --- | --- |",
    apply(df, 1, function(row) {
      paste0(
        "| ", row["file"], " | ", row["dataset_type"], " | ", row["n_observations"], " | ",
        row["variables"], " | ",
        ifelse(is.na(row["oldest_newest_season"]), "ikke tilgjengelig", row["oldest_newest_season"]),
        " | ",
        ifelse(is.na(row["draft_year_range"]), "ikke tilgjengelig", row["draft_year_range"]),
        " |"
      )
    })
  )
}

md_lines <- c(
  "# NBA datasetoversikt",
  "",
  "## Kategori",
  "",
  "Datasett blir klassifisert som `player-season` når filen inneholder en sesongrelatert variabel som `season`, `season_year`, `season_id` eller `year`. Hvis slike variabler mangler, klassifiseres datasettet som `player-career`.",
  "",
  "## 1) Player-season-data",
  "",
  make_inventory_lines(player_season_rows),
  "",
  "## 2) Player-career-data",
  "",
  make_inventory_lines(player_career_rows),
  "",
  "## 3) Variabelliste for alle relevante CSV-filer",
  "",
  variable_table_lines,
  "",
  "## 4) Kort beskrivelse",
  "",
  "- `player-season` er datasett som beskriver observasjoner pr. sesong eller per år.",
  "- `player-career` er datasett som beskriver spillere over hele karrieren og ofte inneholder variabler som `from_year`, `to_year`, `season_exp` eller `draft_year`.",
  "- Wyatt-arkivet brukes kun via `data/archive_wyatt/csv/common_player_info.csv` i denne oversikten.",
  ""
)

writeLines(md_lines, con = file.path(results_dir, "dataset_inventory.md"))

message("Finished. Files created in ", results_dir)
