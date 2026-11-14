# Create the independent player-season register.
# Safe matches reuse player_bio.csv IDs; other observations receive stable
# season-only IDs and remain visible for later review.

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
clean_text <- function(x) {
  x <- trimws(as.character(x)); x[is.na(x)] <- ""
  x <- sub("^\ufeff", "", x, perl = TRUE)
  x <- gsub("[’']", "", x)
  x <- gsub("[^[:alnum:]]+", " ", x)
  trimws(tolower(gsub(" +", " ", x)))
}
display_name <- function(x) {
  x <- trimws(as.character(x)); x[is.na(x)] <- ""
  trimws(gsub(" +", " ", gsub("\\s*[,]+\\s*", " ", x)))
}
name_parts <- function(x) {
  z <- strsplit(display_name(x), " +")[[1]]
  if (!length(z) || !nzchar(z[1])) return(c("", ""))
  suffix <- grepl("^(jr|sr|ii|iii|iv|v)\\.?$", z[length(z)],
                  ignore.case = TRUE)
  if (length(z) == 1) {
    c(z[1], "")
  } else if (suffix && length(z) >= 3) {
    c(paste(z[seq_len(length(z) - 2)], collapse = " "),
      paste(z[(length(z) - 1):length(z)], collapse = " "))
  } else {
    c(paste(z[-length(z)], collapse = " "), z[length(z)])
  }
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
number <- function(x) suppressWarnings(as.numeric(gsub(",", "", as.character(x))))
first_value <- function(x) {
  x <- x[!is.na(x) & nzchar(as.character(x))]
  if (length(x)) x[1] else NA
}
max_number <- function(x) {
  x <- number(x)
  if (all(is.na(x))) NA_real_ else max(x, na.rm = TRUE)
}
stable_id <- function(key) {
  chars <- utf8ToInt(key)
  value <- abs(sum(chars * seq_along(chars))) %% 2147483647
  paste0("season_name_", sprintf("%08x", as.integer(value)))
}
inputs <- c(
  all_seasons = "data/all_seasons.csv",
  stats = "data/NBA Player Stats and Salaries_2000-2025.csv",
  salaries = "data/NBA Player Salaries_2000-2025.csv",
  bio = "data/player_bio.csv"
)
if (!all(file.exists(inputs)))
  stop("Missing input file(s): ", paste(names(inputs)[!file.exists(inputs)], collapse = ", "))

all_seasons <- read_csv(inputs[["all_seasons"]])
stats <- read_csv(inputs[["stats"]])
salaries <- read_csv(inputs[["salaries"]])
bio <- read_csv(inputs[["bio"]])
names(all_seasons)[1] <- "source_row_id"
names(stats)[1] <- "Player"
require_columns(all_seasons, c("player_name", "team_abbreviation", "player_height",
                               "player_weight", "gp", "season"), "all_seasons")
require_columns(stats, c("Player", "Salary", "Year", "Pos", "Team", "G", "GS", "MP",
                         "FG", "FGA", "FG%", "3P", "3PA", "3P%", "2P", "2PA",
                         "2P%", "eFG%", "FT", "FTA", "FT%", "ORB", "DRB", "TRB",
                         "AST", "STL", "BLK", "TOV", "PTS"), "stats")
require_columns(salaries, c("Player", "Salary", "Season"), "salaries")
require_columns(bio, c("playerID", "full_name"), "player_bio")

all_seasons$season <- season_end(all_seasons$season)
stats$season <- season_end(stats$Year)
salaries$season <- season_end(salaries$Season)
all_seasons$raw_name <- display_name(all_seasons$player_name)
stats$raw_name <- display_name(stats$Player)
salaries$raw_name <- display_name(salaries$Player)
bio$raw_name <- display_name(bio$full_name)
all_seasons$key <- clean_text(all_seasons$raw_name)
stats$key <- clean_text(stats$raw_name)
salaries$key <- clean_text(salaries$raw_name)
bio$key <- clean_text(bio$raw_name)

bio_counts <- table(bio$key)
bio_unique <- names(bio_counts[bio_counts == 1 & nzchar(names(bio_counts))])
bio_ids <- setNames(bio$playerID[match(bio_unique, bio$key)], bio_unique)
assign_ids <- function(keys) {
  status <- ifelse(keys %in% bio_unique, "matched_bio",
                   ifelse(keys %in% names(bio_counts), "ambiguous_bio", "unmatched_bio"))
  ids <- vapply(seq_along(keys), function(i) {
    if (status[i] == "matched_bio") unname(bio_ids[keys[i]]) else stable_id(keys[i])
  }, character(1))
  list(id = ids, status = status)
}

for (d in list(all_seasons, stats, salaries)) {
  if (any(!nzchar(d$key))) warning("Blank source names were found and excluded.")
}
all_seasons <- all_seasons[nzchar(all_seasons$key), , drop = FALSE]
stats <- stats[nzchar(stats$key), , drop = FALSE]
salaries <- salaries[nzchar(salaries$key), , drop = FALSE]
all_match <- assign_ids(all_seasons$key)
stats_match <- assign_ids(stats$key)
salary_match <- assign_ids(salaries$key)
all_seasons$playerID <- all_match$id
stats$playerID <- stats_match$id
salaries$playerID <- salary_match$id

linkage <- unique(rbind(
  data.frame(raw_name = all_seasons$raw_name, normalized_name = all_seasons$key,
             season = all_seasons$season, playerID = all_seasons$playerID,
             linkage_status = all_match$status, source = "all_seasons"),
  data.frame(raw_name = stats$raw_name, normalized_name = stats$key,
             season = stats$season, playerID = stats$playerID,
             linkage_status = stats_match$status, source = "stats"),
  data.frame(raw_name = salaries$raw_name, normalized_name = salaries$key,
             season = salaries$season, playerID = salaries$playerID,
             linkage_status = salary_match$status, source = "salaries")
))
linkage$reason <- ifelse(linkage$linkage_status == "matched_bio",
                         "unique normalized full-name match",
                         ifelse(linkage$linkage_status == "ambiguous_bio",
                                "multiple bio rows share normalized name",
                                "no bio row shares normalized name"))

salary_one <- aggregate(Salary ~ playerID + season, salaries,
                         function(x) first_value(number(x)))
names(salary_one)[3] <- "salary_primary"
stats_salary <- aggregate(Salary ~ playerID + season, stats,
                           function(x) first_value(number(x)))
names(stats_salary)[3] <- "salary_stats"
salary_conflicts <- merge(salary_one, stats_salary,
                          by = c("playerID", "season"), all = TRUE)
salary_conflicts$conflict_status <- ifelse(
  !is.na(salary_conflicts$salary_primary) &
    !is.na(salary_conflicts$salary_stats) &
    salary_conflicts$salary_primary != salary_conflicts$salary_stats,
  "conflict", "no_conflict")
salary_conflicts$selected_salary <- ifelse(!is.na(salary_conflicts$salary_primary),
                                           salary_conflicts$salary_primary,
                                           salary_conflicts$salary_stats)

stat_cols <- c("G", "GS", "MP", "FG", "FGA", "FG%", "3P", "3PA", "3P%",
               "2P", "2PA", "2P%", "eFG%", "FT", "FTA", "FT%", "ORB", "DRB",
               "TRB", "AST", "STL", "BLK", "TOV", "PTS")
st <- stats[, c("playerID", "season", "raw_name", "Pos", "Team", stat_cols)]
groups <- split(seq_len(nrow(st)), paste(st$playerID, st$season, sep = "\r"))
st_one <- do.call(rbind, lapply(groups, function(ii) {
  z <- st[ii, , drop = FALSE]; out <- z[1, , drop = FALSE]
  for (col in stat_cols)
    out[[col]] <- if (col %in% c("G", "GS")) max_number(z[[col]]) else first_value(number(z[[col]]))
  out
}))
rownames(st_one) <- NULL

ak <- aggregate(cbind(player_height, player_weight) ~ playerID + season,
                all_seasons, function(x) max_number(x))
historical <- aggregate(
  cbind(raw_name, team_abbreviation, gp, pts, reb, ast, net_rating, oreb_pct,
        dreb_pct, usg_pct, ts_pct, ast_pct) ~ playerID + season,
  all_seasons, first_value
)
names(historical)[3:ncol(historical)] <- c(
  "historical_name", "historical_team", "historical_gp", "historical_pts",
  "historical_reb", "historical_ast", "historical_net_rating", "historical_oreb_pct",
  "historical_dreb_pct", "historical_usg_pct", "historical_ts_pct",
  "historical_ast_pct"
)
salary_names <- aggregate(raw_name ~ playerID + season, salaries, first_value)
names(salary_names)[3] <- "salary_name"
keys <- unique(rbind(
  st_one[, c("playerID", "season")],
  ak[, c("playerID", "season")],
  salary_names[, c("playerID", "season")]
))
seasons <- merge(keys, ak, by = c("playerID", "season"), all = TRUE)
seasons <- merge(seasons, historical, by = c("playerID", "season"), all = TRUE)
seasons <- merge(seasons, salary_names, by = c("playerID", "season"), all = TRUE)
seasons <- merge(seasons, st_one, by = c("playerID", "season"), all = TRUE)
seasons <- merge(seasons, salary_conflicts[, c("playerID", "season", "selected_salary")],
                 by = c("playerID", "season"), all = TRUE)
seasons$full_name <- ifelse(!is.na(seasons$raw_name) & nzchar(seasons$raw_name),
                            seasons$raw_name,
                            ifelse(!is.na(seasons$historical_name) &
                                     nzchar(seasons$historical_name),
                                   seasons$historical_name,
                                   seasons$salary_name))
parts <- t(vapply(seasons$full_name, name_parts, character(2)))
seasons$first_name <- parts[, 1]; seasons$last_name <- parts[, 2]
seasons$salary <- seasons$selected_salary
seasons$position <- seasons$Pos
seasons$team_abbreviation <- ifelse(
  !is.na(seasons$Team) & nzchar(seasons$Team),
  seasons$Team,
  seasons$historical_team
)
map <- c(G = "games_played", GS = "games_started", MP = "minutes_pg",
         FG = "fgm_pg", FGA = "fga_pg", "FG%" = "fgpct_pg", "3P" = "3pm_pg",
         "3PA" = "3pa_pg", "3P%" = "3p_pct", "2P" = "2pm_pg",
         "2PA" = "2pa_pg", "2P%" = "2p_pct", "eFG%" = "efg%",
         FT = "ftm_pg", FTA = "fta_pg", "FT%" = "ftpct", ORB = "oreb_pg",
         DRB = "dreb_pg", TRB = "treb_pg", AST = "ast_pg", STL = "stl_pg",
         BLK = "blk_pg", TOV = "tov_pg", PTS = "pts_pg")
for (source_col in names(map)) seasons[[map[[source_col]]]] <- number(seasons[[source_col]])
seasons$games_played <- ifelse(is.na(seasons$games_played),
                               number(seasons$historical_gp), seasons$games_played)
seasons$treb_pg <- ifelse(is.na(seasons$treb_pg),
                          number(seasons$historical_reb), seasons$treb_pg)
seasons$ast_pg <- ifelse(is.na(seasons$ast_pg),
                         number(seasons$historical_ast), seasons$ast_pg)
seasons$pts_pg <- ifelse(is.na(seasons$pts_pg),
                         number(seasons$historical_pts), seasons$pts_pg)
for (col in c("net_rating", "oreb_pct", "dreb_pct", "usg_pct", "ts_pct", "ast_pct")) {
  seasons[[col]] <- number(seasons[[paste0("historical_", col)]])
}
seasons <- seasons[, c("playerID", "season", "first_name", "last_name", "full_name",
                       "salary", "position", "player_height", "player_weight",
                       "team_abbreviation",
                       unname(map), "net_rating", "oreb_pct", "dreb_pct",
                       "usg_pct", "ts_pct", "ast_pct")]
names(seasons)[names(seasons) == "player_height"] <- "season_height"
names(seasons)[names(seasons) == "player_weight"] <- "season_weight"
matched_ids <- unique(linkage$playerID[linkage$linkage_status == "matched_bio"])
ambiguous_ids <- unique(linkage$playerID[linkage$linkage_status == "ambiguous_bio"])
seasons$playerID_status <- ifelse(seasons$playerID %in% matched_ids, "matched_bio",
                                  ifelse(seasons$playerID %in% ambiguous_ids,
                                         "ambiguous_bio", "unmatched_bio"))

review_dir <- file.path("results", "review_player_seasons")
dir.create(review_dir, recursive = TRUE, showWarnings = FALSE)
dir.create("results", showWarnings = FALSE)
write.csv(seasons, "data/player_seasons.csv", row.names = FALSE, na = "")
write.csv(linkage, file.path(review_dir, "player_seasons_linkage.csv"),
          row.names = FALSE, na = "")
write.csv(salary_conflicts[salary_conflicts$conflict_status == "conflict", ],
          file.path(review_dir, "player_seasons_salary.csv"), row.names = FALSE, na = "")
duplicate_review <- data.frame(
  playerID = character(), season = integer(), source = character(),
  reduction_rule = character(), stringsAsFactors = FALSE
)
write.csv(duplicate_review, file.path(review_dir, "player_seasons_duplicates.csv"),
          row.names = FALSE, na = "")

team_values <- unique(rbind(
  data.frame(playerID = all_seasons$playerID, season = all_seasons$season,
             team = all_seasons$team_abbreviation),
  data.frame(playerID = stats$playerID, season = stats$season, team = stats$Team)
))
team_values <- team_values[!is.na(team_values$team) & nzchar(team_values$team), ]
team_counts <- aggregate(team ~ playerID + season, team_values,
                         function(x) length(unique(x)))
multi_team_keys <- sum(team_counts$team > 1)

matched <- sum(seasons$playerID_status == "matched_bio")
fallback <- sum(seasons$playerID_status != "matched_bio")
report <- data.frame(
  metric = c("all_seasons_input_rows", "stats_input_rows", "salary_input_rows",
             "output_rows", "unique_players", "season_min", "season_max",
             "matched_bio_rows", "fallback_rows", "unmatched_bio_links",
             "ambiguous_bio_links", "missing_salary_rows", "missing_performance_rows",
             "missing_team_rows", "multi_team_keys", "salary_conflict_keys"),
  value = c(nrow(all_seasons), nrow(stats), nrow(salaries), nrow(seasons),
            length(unique(seasons$playerID)), min(seasons$season), max(seasons$season),
            matched, fallback,
            sum(linkage$linkage_status == "unmatched_bio"),
            sum(linkage$linkage_status == "ambiguous_bio"),
            sum(is.na(seasons$salary)), sum(is.na(seasons$games_played)),
            sum(is.na(seasons$team_abbreviation)),
            multi_team_keys,
            sum(salary_conflicts$conflict_status == "conflict")))
write.csv(report, "results/player_seasons_report.csv", row.names = FALSE, na = "")
stopifnot(!anyDuplicated(paste(seasons$playerID, seasons$season)),
          all(seasons$playerID_status == "matched_bio" |
              grepl("^season_name_[0-9a-f]+$", seasons$playerID)),
          all(seasons$playerID[seasons$playerID_status == "matched_bio"] %in% bio$playerID))
invisible(list(seasons = seasons, report = report, linkage = linkage))
