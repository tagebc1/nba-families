# Build the independent player-season register from the current source policy.

`%||%` <- function(x, y) if (is.null(x)) y else x
project_root <- if (basename(getwd()) == "NBA_Project") getwd() else
  dirname(normalizePath(sys.frame(1)$ofile %||% "scripts/create_player_seasons.R"))
if (!dir.exists(file.path(project_root, "data"))) project_root <- getwd()
setwd(project_root)

read_csv <- function(path) read.csv(path, stringsAsFactors = FALSE,
                                    check.names = FALSE,
                                    na.strings = c("", "NA", "N/A", "null"))
require_columns <- function(x, cols, label) {
  missing <- setdiff(cols, names(x))
  if (length(missing)) stop(label, " is missing columns: ",
                             paste(missing, collapse = ", "))
}
number <- function(x) suppressWarnings(as.numeric(gsub(",", "", as.character(x))))
first_value <- function(x) {
  x <- x[!is.na(x) & nzchar(as.character(x))]
  if (length(x)) x[1] else NA
}
display_name <- function(x) {
  x <- trimws(as.character(x)); x[is.na(x)] <- ""
  trimws(gsub(" +", " ", gsub("\\s*[,]+\\s*", " ", x)))
}
clean_name <- function(x) {
  x <- tolower(display_name(x))
  x <- gsub("[’']", "", x)
  trimws(gsub(" +", " ", gsub("[^[:alnum:]]+", " ", x)))
}
name_parts <- function(x) {
  z <- strsplit(display_name(x), " +")[[1]]
  if (!length(z) || !nzchar(z[1])) return(c("", ""))
  suffix <- grepl("^(jr|sr|ii|iii|iv|v)\\.?$", z[length(z)],
                  ignore.case = TRUE)
  if (length(z) == 1) c(z[1], "")
  else if (suffix && length(z) >= 3)
    c(paste(z[seq_len(length(z) - 2)], collapse = " "),
      paste(z[(length(z) - 1):length(z)], collapse = " "))
  else c(paste(z[-length(z)], collapse = " "), z[length(z)])
}
season_end <- function(x) {
  x <- trimws(as.character(x))
  out <- suppressWarnings(as.integer(x))
  m <- grepl("^[0-9]{4}-[0-9]{2,4}$", x)
  if (any(m)) {
    start <- as.integer(sub("-.*", "", x[m]))
    end <- sub("^[0-9]{4}-", "", x[m])
    out[m] <- ifelse(nchar(end) == 2, start + 1L, as.integer(end))
  }
  if (any(is.na(out) & nzchar(x)))
    stop("Could not interpret season values: ",
         paste(unique(x[is.na(out) & nzchar(x)])[1:5], collapse = ", "))
  out
}
stable_id <- function(source, season, key, row_number) {
  vapply(seq_along(key), function(i) {
    value <- paste(source[i], season[i], key[i], row_number[i], sep = "|")
    paste0("season_only_",
           paste(sprintf("%02x", utf8ToInt(value)), collapse = ""))
  }, character(1))
}

inputs <- c(
  stats = "data/NBA Player Stats and Salaries_2000-2025.csv",
  salaries = "data/NBA Player Salaries_2000-2025.csv",
  historical = "data/all_seasons.csv",
  bio = "data/player_bio.csv"
)
if (!all(file.exists(inputs)))
  stop("Missing input file(s): ",
       paste(names(inputs)[!file.exists(inputs)], collapse = ", "))

stats <- read_csv(inputs[["stats"]])
salaries <- read_csv(inputs[["salaries"]])
historical <- read_csv(inputs[["historical"]])
bio <- read_csv(inputs[["bio"]])
names(historical)[1] <- "source_row_id"
require_columns(stats, c("Player", "Salary", "Year", "Pos", "Team", "G", "GS",
                         "MP", "FG", "FGA", "FG%", "3P", "3PA", "3P%", "2P",
                         "2PA", "2P%", "eFG%", "FT", "FTA", "FT%", "ORB", "DRB",
                         "TRB", "AST", "STL", "BLK", "TOV", "PTS"), "stats")
require_columns(salaries, c("Player", "Salary", "Season"), "salaries")
require_columns(historical, c("player_name", "team_abbreviation", "player_height",
                              "player_weight", "gp", "pts", "reb", "ast",
                              "net_rating", "oreb_pct", "dreb_pct", "usg_pct",
                              "ts_pct", "ast_pct", "season"), "all_seasons")
require_columns(bio, c("playerID", "full_name"), "player_bio")

stats$season <- season_end(stats$Year)
salaries$season <- season_end(salaries$Season)
historical$season <- season_end(historical$season)
stats$raw_name <- display_name(stats$Player)
salaries$raw_name <- display_name(salaries$Player)
historical$raw_name <- display_name(historical$player_name)
bio$raw_name <- display_name(bio$full_name)
stats$key <- clean_name(stats$raw_name)
salaries$key <- clean_name(salaries$raw_name)
historical$key <- clean_name(historical$raw_name)
bio$key <- clean_name(bio$raw_name)

bio_counts <- table(bio$key)
bio_unique <- names(bio_counts[bio_counts == 1 & nzchar(names(bio_counts))])
bio_ids <- setNames(bio$playerID[match(bio_unique, bio$key)], bio_unique)
status_for <- function(key) ifelse(key %in% bio_unique, "matched_bio",
                                   ifelse(key %in% names(bio_counts),
                                          "ambiguous_not_in_bio",
                                          "created_not_in_bio"))
id_for <- function(source, season, key, duplicate_flag, row_number) {
  status <- status_for(key)
  ifelse(status == "matched_bio" & !duplicate_flag, unname(bio_ids[key]),
         stable_id(source, season, key, row_number))
}

stats <- stats[nzchar(stats$key) & stats$season >= 2000 & stats$season <= 2025, ]
salaries <- salaries[nzchar(salaries$key) & salaries$season >= 2000 &
                       salaries$season <= 2025, ]
historical <- historical[nzchar(historical$key) & historical$season != 1996, ]
stats$row_number <- seq_len(nrow(stats))
salaries$row_number <- seq_len(nrow(salaries))
historical$row_number <- seq_len(nrow(historical))

key_for <- function(name, season) paste(clean_name(name), season, sep = "\r")
stats$overlap_key <- key_for(stats$raw_name, stats$season)
salaries$overlap_key <- key_for(salaries$raw_name, salaries$season)
historical$overlap_key <- key_for(historical$raw_name, historical$season)
stats_key_counts <- table(stats$overlap_key)
salary_key_counts <- table(salaries$overlap_key)
historical_key_counts <- table(historical$overlap_key)
stats$name_season_duplicate_flag <- as.integer(
  stats_key_counts[stats$overlap_key] > 1)
salaries$name_season_duplicate_flag <- as.integer(
  salary_key_counts[salaries$overlap_key] > 1)
historical$name_season_duplicate_flag <- as.integer(
  historical_key_counts[historical$overlap_key] > 1)
stats$playerID <- id_for("stats", stats$season, stats$key,
                         stats$name_season_duplicate_flag, stats$row_number)
salaries$playerID <- id_for("salary", salaries$season, salaries$key,
                            salaries$name_season_duplicate_flag,
                            salaries$row_number)
historical$playerID <- id_for("all_seasons_historical",
                              historical$season, historical$key,
                              historical$name_season_duplicate_flag,
                              historical$row_number)
safe_stats_keys <- names(stats_key_counts[stats_key_counts == 1])
safe_salary_keys <- names(salary_key_counts[salary_key_counts == 1])
safe_overlap_keys <- intersect(unique(c(safe_stats_keys,
                                        bio_unique)), safe_salary_keys)

stat_cols <- c("G", "GS", "MP", "FG", "FGA", "FG%", "3P", "3PA", "3P%",
               "2P", "2PA", "2P%", "eFG%", "FT", "FTA", "FT%", "ORB", "DRB",
               "TRB", "AST", "STL", "BLK", "TOV", "PTS")
map <- c(G = "games_played", GS = "games_started", MP = "minutes_pg",
         FG = "fgm_pg", FGA = "fga_pg", "FG%" = "fgpct_pg", "3P" = "3pm_pg",
         "3PA" = "3pa_pg", "3P%" = "3p_pct", "2P" = "2pm_pg",
         "2PA" = "2pa_pg", "2P%" = "2p_pct", "eFG%" = "efg%",
         FT = "ftm_pg", FTA = "fta_pg", "FT%" = "ftpct", ORB = "oreb_pg",
         DRB = "dreb_pg", TRB = "treb_pg", AST = "ast_pg", STL = "stl_pg",
         BLK = "blk_pg", TOV = "tov_pg", PTS = "pts_pg")
output_cols <- c("playerID", "season", "first_name", "last_name", "full_name",
                 "salary", "position", "season_height", "season_weight",
                 "team_abbreviation", unname(map), "net_rating", "oreb_pct",
                 "dreb_pct", "usg_pct", "ts_pct", "ast_pct", "playerID_status",
                 "name_season_duplicate_flag")
blank_output <- function(n) {
  as.data.frame(setNames(replicate(length(output_cols), rep(NA, n),
                                    simplify = FALSE), output_cols),
                stringsAsFactors = FALSE, check.names = FALSE)
}
add_names <- function(out, names) {
  parts <- t(vapply(names, name_parts, character(2)))
  out$full_name <- names
  out$first_name <- parts[, 1]
  out$last_name <- parts[, 2]
  out
}

stats_one <- stats[stats$name_season_duplicate_flag == 1 |
                     !duplicated(stats$overlap_key), ]
stats_out <- blank_output(nrow(stats_one))
stats_out$playerID <- stats_one$playerID
stats_out$season <- stats_one$season
stats_out <- add_names(stats_out, stats_one$raw_name)
stats_out$salary <- number(stats_one$Salary)
stats_out$position <- stats_one$Pos
stats_out$team_abbreviation <- stats_one$Team
for (source_col in names(map))
  stats_out[[map[[source_col]]]] <- number(stats_one[[source_col]])
stats_out$playerID_status <- ifelse(
  stats_one$name_season_duplicate_flag == 1,
  "ambiguous_not_in_bio", status_for(stats_one$key))
stats_out$name_season_duplicate_flag <- stats_one$name_season_duplicate_flag

salary_only <- salaries[!(salaries$overlap_key %in% safe_overlap_keys), ]
salary_only <- salary_only[salary_only$name_season_duplicate_flag == 1 |
                             !duplicated(salary_only$overlap_key), ]
salary_out <- blank_output(nrow(salary_only))
salary_out$playerID <- salary_only$playerID
salary_out$season <- salary_only$season
salary_out <- add_names(salary_out, salary_only$raw_name)
salary_out$salary <- number(salary_only$Salary)
salary_out$playerID_status <- ifelse(
  salary_only$name_season_duplicate_flag == 1,
  "ambiguous_not_in_bio", status_for(salary_only$key))
salary_out$name_season_duplicate_flag <- salary_only$name_season_duplicate_flag

historical_only <- historical[!(historical$overlap_key %in%
                                  unique(c(stats$overlap_key, salaries$overlap_key))), ]
historical_only <- historical_only[historical_only$name_season_duplicate_flag == 1 |
                                     !duplicated(historical_only$overlap_key), ]
historical_out <- blank_output(nrow(historical_only))
historical_out$playerID <- historical_only$playerID
historical_out$season <- historical_only$season
historical_out <- add_names(historical_out, historical_only$raw_name)
historical_out$season_height <- number(historical_only$player_height)
historical_out$season_weight <- number(historical_only$player_weight)
historical_out$team_abbreviation <- historical_only$team_abbreviation
historical_out$games_played <- number(historical_only$gp)
historical_out$treb_pg <- number(historical_only$reb)
historical_out$ast_pg <- number(historical_only$ast)
historical_out$pts_pg <- number(historical_only$pts)
for (col in c("net_rating", "oreb_pct", "dreb_pct", "usg_pct", "ts_pct", "ast_pct"))
  historical_out[[col]] <- number(historical_only[[col]])
historical_out$playerID_status <- ifelse(
  historical_only$name_season_duplicate_flag == 1,
  "ambiguous_not_in_bio", status_for(historical_only$key))
historical_out$name_season_duplicate_flag <-
  historical_only$name_season_duplicate_flag

stats_ids <- paste(stats_out$playerID, stats_out$season)
salary_out <- salary_out[!(paste(salary_out$playerID, salary_out$season) %in%
                             stats_ids), , drop = FALSE]
salary_ids <- paste(salary_out$playerID, salary_out$season)
historical_out <- historical_out[!(
  paste(historical_out$playerID, historical_out$season) %in%
    c(stats_ids, salary_ids)), , drop = FALSE]

seasons <- rbind(stats_out, salary_out, historical_out)
seasons <- seasons[order(seasons$season, seasons$playerID), output_cols]
duplicate_keys <- paste(seasons$playerID, seasons$season)
if (anyDuplicated(duplicate_keys)) {
  repeated <- unique(duplicate_keys[duplicated(duplicate_keys)])
  stop("Duplicate playerID + season remains after source reduction: ",
       paste(head(repeated, 10), collapse = ", "))
}

review_dir <- file.path("results", "review_player_seasons")
dir.create(review_dir, recursive = TRUE, showWarnings = FALSE)
dir.create("results", showWarnings = FALSE)
linkage <- rbind(
  data.frame(raw_name = stats_one$raw_name, normalized_name = stats_one$key,
             season = stats_one$season, playerID = stats_one$playerID,
             playerID_status = status_for(stats_one$key),
             record_source = "stats", reason = "stats production row"),
  data.frame(raw_name = salary_only$raw_name, normalized_name = salary_only$key,
             season = salary_only$season, playerID = salary_only$playerID,
             playerID_status = status_for(salary_only$key),
             record_source = "salary_only", reason = "not in stats source"),
  data.frame(raw_name = historical_only$raw_name, normalized_name = historical_only$key,
             season = historical_only$season, playerID = historical_only$playerID,
             playerID_status = status_for(historical_only$key),
             record_source = "all_seasons_historical",
             reason = "not in newer source keys")
)
duplicate_rows <- function(source, keys) {
  keys <- keys[duplicated(keys)]
  data.frame(source = rep(source, length(keys)), overlap_key = keys,
             reduction_rule = rep("first source row kept", length(keys)),
             stringsAsFactors = FALSE)
}
duplicate_review <- rbind(
  duplicate_rows("stats", stats$overlap_key),
  duplicate_rows("salary", salaries$overlap_key),
  duplicate_rows("all_seasons", historical$overlap_key)
)
ambiguous_review <- linkage[linkage$playerID_status == "ambiguous_not_in_bio", ]
multi_team <- aggregate(Team ~ overlap_key, stats, function(x) {
  paste(unique(x[!is.na(x) & nzchar(x)]), collapse = "|")
})
names(multi_team)[2] <- "team_codes"
multi_team <- multi_team[grepl("\\|", multi_team$team_codes), ]
write.csv(seasons, "data/player_seasons.csv", row.names = FALSE, na = "")
write.csv(linkage, file.path(review_dir, "player_seasons_linkage.csv"),
          row.names = FALSE, na = "")
write.csv(duplicate_review, file.path(review_dir, "player_seasons_duplicates.csv"),
          row.names = FALSE, na = "")
write.csv(ambiguous_review, file.path(review_dir,
                                      "player_seasons_ambiguous_names.csv"),
          row.names = FALSE, na = "")
write.csv(multi_team, file.path(review_dir, "player_seasons_multi_team.csv"),
          row.names = FALSE, na = "")

missing_counts <- colSums(is.na(seasons))
report <- data.frame(
  metric = c("stats_input_rows", "salary_input_rows", "historical_input_rows",
             "stats_output_rows", "salary_only_output_rows",
             "historical_output_rows", "output_rows", "unique_players",
             "unique_player_season_keys", "matched_bio_rows",
             "created_not_in_bio_rows", "ambiguous_not_in_bio_rows",
             "duplicate_rows_reviewed", "multi_team_keys", "season_min",
             "season_max", paste0("missing_", names(missing_counts))),
  value = c(nrow(stats), nrow(salaries), nrow(historical), nrow(stats_out),
            nrow(salary_out), nrow(historical_out), nrow(seasons),
            length(unique(seasons$playerID)),
            length(unique(paste(seasons$playerID, seasons$season))),
            sum(seasons$playerID_status == "matched_bio"),
            sum(seasons$playerID_status == "created_not_in_bio"),
            sum(seasons$playerID_status == "ambiguous_not_in_bio"),
            nrow(duplicate_review), nrow(multi_team), min(seasons$season),
            max(seasons$season), as.integer(missing_counts)),
  stringsAsFactors = FALSE
)
write.csv(report, "results/player_seasons_report.csv", row.names = FALSE, na = "")
invisible(list(seasons = seasons, report = report, linkage = linkage))
