# Reproducible NBA player-data merge.  This file is sourced by data_merging.qmd.
# It intentionally uses only base R so the workflow can run on a clean R install.

required_files <- c(
  "data/all_seasons.csv",
  "data/NBA Player Stats and Salaries_2000-2025.csv",
  "data/NBA Player Salaries_2000-2025.csv",
  "data/father_son_list.csv",
  "data/nba_siblings_list.csv",
  "data/archive_wyatt/csv/common_player_info.csv"
)
stopifnot(all(file.exists(required_files)))

read_csv <- function(path) read.csv(path, stringsAsFactors = FALSE, check.names = FALSE,
                                    na.strings = c("", "NA", "N/A", "null"))
need <- function(x, cols, label) {
  miss <- setdiff(cols, names(x))
  if (length(miss)) stop(label, " is missing columns: ", paste(miss, collapse = ", "))
}
clean <- function(x) {
  x <- tolower(trimws(as.character(x)))
  x[is.na(x)] <- ""
  x <- gsub("[’']", "", x)
  x <- gsub("[^a-z0-9]+", " ", x)
  trimws(x)
}
name_key <- function(x) {
  x <- clean(x)
  x <- gsub("\\b(jr|sr|ii|iii|iv|v|junior|senior)\\b", "", x)
  trimws(gsub(" +", " ", x))
}
display_name <- function(x) {
  x <- trimws(as.character(x))
  x[is.na(x)] <- ""
  x <- gsub("\\s*[,]+\\s*", " ", x)
  # Preserve generational suffixes in the displayed name. Remove only
  # punctuation-only tokens left by malformed source values.
  x <- gsub("(^|\\s)[[:punct:]]+(?=\\s|$)", " ", x, perl = TRUE)
  trimws(gsub(" +", " ", x))
}
is_valid_name <- function(x) grepl("[[:alnum:]]", display_name(x))
split_name <- function(x) {
  x <- display_name(x)
  if (!nzchar(x)) return(c("", ""))
  z <- strsplit(x, " +")[[1]]
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
  x <- trimws(as.character(x)); out <- suppressWarnings(as.integer(x))
  hy <- grepl("^[0-9]{4}-[0-9]{2,4}$", x)
  if (any(hy)) {
    a <- as.integer(sub("-.*", "", x[hy])); b <- sub("^[0-9]{4}-", "", x[hy])
    out[hy] <- ifelse(nchar(b) == 2, a + 1L, as.integer(b))
  }
  if (any(is.na(out) & nzchar(x))) stop("Could not interpret season values: ",
                                         paste(unique(x[is.na(out) & nzchar(x)])[1:5], collapse = ", "))
  out
}
num <- function(x) suppressWarnings(as.numeric(gsub(",", "", as.character(x))))
safe_max <- function(x) if (all(is.na(x))) NA_real_ else max(x, na.rm = TRUE)
first_nonmissing <- function(x) { x <- x[!is.na(x) & nzchar(as.character(x))]; if (length(x)) x[1] else NA }
hash_id <- function(x) paste0("p_name_", sprintf("%08x", as.integer(abs(sum(utf8ToInt(x) * seq_along(utf8ToInt(x)))) %% 2147483647)))

all_seasons <- read_csv(required_files[1]); stats <- read_csv(required_files[2])
salaries <- read_csv(required_files[3]); fathers <- read_csv(required_files[4])
siblings <- read_csv(required_files[5]); info <- read_csv(required_files[6])
if ("" %in% names(all_seasons)) names(all_seasons)[names(all_seasons) == ""] <- "source_row_id"
need(all_seasons, c("player_name","team_abbreviation","player_height","player_weight","gp","season"), "all_seasons")
need(stats, c("Player","Salary","Year","Pos","Team","G","GS","MP","FG","FGA","FG%","3P","3PA","3P%","2P","2PA","2P%","eFG%","FT","FTA","FT%","ORB","DRB","TRB","AST","STL","BLK","TOV","PTS"), "stats")
need(salaries, c("Player","Salary","Season"), "salaries")
need(info, c("person_id","first_name","last_name","birthdate","country","height","weight","draft_year","draft_round","draft_number","greatest_75_flag"), "common_player_info")

all_seasons$season <- season_end(all_seasons$season)
stats$season <- season_end(stats$Year)
salaries$season <- season_end(salaries$Season)
all_seasons$key <- name_key(all_seasons$player_name)
stats$key <- name_key(stats$Player); salaries$key <- name_key(salaries$Player)
info$source_name <- ifelse(
  !is.na(info$first_name) & nzchar(trimws(info$first_name)) &
    !is.na(info$last_name) & nzchar(trimws(info$last_name)),
  paste(info$first_name, info$last_name),
  ""
)
info$key <- name_key(info$source_name)

# Empty source names are not player records and must not receive a generated ID.
all_seasons <- all_seasons[nzchar(all_seasons$key), , drop = FALSE]
stats <- stats[nzchar(stats$key), , drop = FALSE]
salaries <- salaries[nzchar(salaries$key), , drop = FALSE]
info <- info[nzchar(info$key), , drop = FALSE]

name_counts <- table(info$key)
dup_keys <- names(name_counts[name_counts > 1])
unique_info <- names(which(table(info$key) == 1))
id_for_key <- function(k) {
  hit <- info[info$key == k, , drop = FALSE]
  if (nrow(hit) == 1) paste0("p_", hit$person_id) else hash_id(k)
}
all_keys <- unique(c(all_seasons$key, stats$key, salaries$key, info$key))
key_id <- setNames(vapply(all_keys, id_for_key, character(1)), all_keys)
all_seasons$playerID <- unname(key_id[all_seasons$key])
stats$playerID <- unname(key_id[stats$key]); salaries$playerID <- unname(key_id[salaries$key])
info$playerID <- unname(key_id[info$key])

# Salary source audit: standalone salary is preferred; stats salary is fallback.
salary_key <- paste(salaries$playerID, salaries$season)
salary_conflicts <- aggregate(Salary ~ playerID + season, salaries, function(x) length(unique(num(x)[!is.na(num(x))])) > 1)
names(salary_conflicts)[3] <- "conflict"
salary_one <- aggregate(Salary ~ playerID + season, salaries, function(x) first_nonmissing(num(x)))
names(salary_one)[3] <- "salary"
stats_salary <- aggregate(Salary ~ playerID + season, stats, function(x) first_nonmissing(num(x)))
names(stats_salary)[3] <- "stats_salary"

# One season row: stats are already per-player-season; duplicates are reduced
# deterministically (maximum games, and first non-missing rate fields).
stat_cols <- c("G","GS","MP","FG","FGA","FG%","3P","3PA","3P%","2P","2PA","2P%","eFG%","FT","FTA","FT%","ORB","DRB","TRB","AST","STL","BLK","TOV","PTS")
st <- stats[, c("playerID","season","Player","Pos","Team",stat_cols)]
st <- st[order(st$playerID, st$season), ]
grp <- split(seq_len(nrow(st)), paste(st$playerID, st$season, sep = "\r"))
st1 <- do.call(rbind, lapply(grp, function(ii) {
  z <- st[ii, , drop = FALSE]; o <- z[1, , drop = FALSE]
  for (j in stat_cols) o[[j]] <- if (j == "G" || j == "GS") safe_max(num(z[[j]])) else first_nonmissing(num(z[[j]]))
  o
}))
rownames(st1) <- NULL

# all_seasons supplies long historical coverage, heights, weights and team abbreviations.
ak <- aggregate(cbind(player_height, player_weight) ~ playerID + season, all_seasons,
                function(x) safe_max(num(x)))
team <- aggregate(cbind(team_abbreviation) ~ playerID + season, all_seasons, first_nonmissing)
names(team)[3] <- "team_abbreviation"
source_names <- aggregate(player_name ~ playerID + season, all_seasons, first_nonmissing)
names(source_names)[3] <- "source_full_name"
base_keys <- unique(rbind(st1[, c("playerID","season")], ak[, c("playerID","season")]))
seasons <- merge(base_keys, ak, all = TRUE); seasons <- merge(seasons, team, all = TRUE)
seasons <- merge(seasons, source_names, all = TRUE)
seasons <- merge(seasons, st1, by = c("playerID","season"), all = TRUE, sort = FALSE)
seasons <- merge(seasons, salary_one, by = c("playerID","season"), all = TRUE)
seasons <- merge(seasons, stats_salary, by = c("playerID","season"), all = TRUE)
seasons$salary <- ifelse(is.na(seasons$salary), seasons$stats_salary, seasons$salary)
seasons$season_height <- ifelse(is.na(seasons$player_height), NA, seasons$player_height)
seasons$season_weight <- ifelse(is.na(seasons$player_weight), NA, seasons$player_weight)
seasons$full_name <- ifelse(
  !is.na(seasons$Player) & nzchar(trimws(seasons$Player)),
  display_name(seasons$Player),
  display_name(seasons$source_full_name)
)
seasons$first_name <- ifelse(is.na(seasons$full_name), NA, vapply(seasons$full_name, function(x) split_name(x)[1], character(1)))
seasons$last_name <- ifelse(is.na(seasons$full_name), NA, vapply(seasons$full_name, function(x) split_name(x)[2], character(1)))
seasons <- seasons[is_valid_name(seasons$full_name), , drop = FALSE]
seasons$position <- seasons$Pos
seasons$team_full_name <- NA_character_; seasons$team_city <- NA_character_
map <- c(G="games_played", GS="games_started", MP="minutes_pg", FG="fgm_pg", FGA="fga_pg", "FG%"="fgpct_pg", "3P"="3pm_pg", "3PA"="3pa_pg", "3P%"="3p_pct", "2P"="2pm_pg", "2PA"="2pa_pg", "2P%"="2p_pct", "eFG%"="efg%", FT="ftm_pg", FTA="fta_pg", "FT%"="ftpct", ORB="oreb_pg", DRB="dreb_pg", TRB="treb_pg", AST="ast_pg", STL="stl_pg", BLK="blk_pg", TOV="tov_pg", PTS="pts_pg")
for (a in names(map)) seasons[[map[[a]]]] <- num(seasons[[a]])
seasons$net_rating <- NA_real_; seasons$oreb_pct <- NA_real_; seasons$dreb_pct <- NA_real_; seasons$usg_pct <- NA_real_; seasons$ts_pct <- NA_real_; seasons$ast_pct <- NA_real_
seasons <- seasons[, c("playerID","season","first_name","last_name","full_name","salary","position","season_height","season_weight","team_abbreviation","team_full_name","team_city",unname(map),"net_rating","oreb_pct","dreb_pct","usg_pct","ts_pct","ast_pct")]

# Bio uses common-player-info where available and max season height/weight.
bio_ids <- unique(c(seasons$playerID, info$playerID))
bio <- data.frame(playerID = bio_ids, stringsAsFactors = FALSE)
for (v in c("first_name","last_name","full_name","height","weight","country","draft_year","draft_round","draft_number","birthdate","greatest_75_flag")) bio[[v]] <- NA
for (i in seq_len(nrow(bio))) {
  id <- bio$playerID[i]; inf <- info[info$playerID == id, , drop=FALSE]; ss <- seasons[seasons$playerID == id, , drop=FALSE]
  if (nrow(inf)) {
    bio[i,c("first_name","last_name","country","draft_year","draft_round","draft_number","birthdate","greatest_75_flag")] <-
      inf[1,c("first_name","last_name","country","draft_year","draft_round","draft_number","birthdate","greatest_75_flag")]
    parsed <- split_name(paste(inf$first_name[1], inf$last_name[1]))
    bio$first_name[i] <- parsed[1]
    bio$last_name[i] <- parsed[2]
    bio$full_name[i] <- if (nzchar(parsed[1])) paste(parsed, collapse = " ") else NA
  }
  if ((is.na(bio$full_name[i]) || !nzchar(bio$full_name[i])) && nrow(ss)) {
    bio$first_name[i] <- ss$first_name[1]
    bio$last_name[i] <- ss$last_name[1]
    bio$full_name[i] <- display_name(ss$full_name[1])
  }
}
bio$height <- vapply(bio$playerID, function(id) safe_max(c(num(info$height[info$playerID==id]), seasons$season_height[seasons$playerID==id])), numeric(1))
bio$weight <- vapply(bio$playerID, function(id) safe_max(c(num(info$weight[info$playerID==id]), seasons$season_weight[seasons$playerID==id])), numeric(1))
bio$birthdate <- as.character(bio$birthdate); bio$birthdate[!grepl("^\\d{4}-\\d{2}-\\d{2}", bio$birthdate)] <- NA
bio$same_name_flag <- as.integer(bio$playerID %in% key_id[dup_keys])

# Relations are only linked when the normalized name identifies one person.
relation_name <- function(x) { k <- name_key(x); if (k %in% unique_info) unname(key_id[k]) else NA_character_ }
# The source currently has one son per row, but split cells defensively so a
# future scrape containing "A; B" or "A and B" cannot become one false name.
father_rows <- do.call(rbind, lapply(seq_len(nrow(fathers)), function(i) {
  sons <- trimws(unlist(strsplit(as.character(fathers$sons[i]), "\\s*(;|\\||\\band\\b)\\s*", perl=TRUE)))
  data.frame(father=fathers$father[i], sons=sons, stringsAsFactors=FALSE)
}))
fathers <- father_rows
fathers$father_id <- vapply(fathers$father, relation_name, character(1))
fathers$son_id <- vapply(fathers$sons, relation_name, character(1))
siblings$rel_id <- vapply(siblings$full_name, relation_name, character(1))
bio$familyID <- 0L; bio$father_dummy <- 0L; bio$son_dummy <- 0L; bio$brother_dummy <- 0L; bio$twin_dummy <- 0L
valid_f <- fathers[!is.na(fathers$father_id) & !is.na(fathers$son_id), ]
for (i in seq_len(nrow(valid_f))) { bio$father_dummy[bio$playerID==valid_f$father_id[i]] <- 1; bio$son_dummy[bio$playerID==valid_f$son_id[i]] <- 1 }
valid_s <- siblings[!is.na(siblings$rel_id), ]
bio$brother_dummy[bio$playerID %in% valid_s$rel_id] <- 1
family_values <- unique(siblings$family_id[!is.na(siblings$rel_id)])
for (f in family_values) { ids <- unique(siblings$rel_id[siblings$family_id==f & !is.na(siblings$rel_id)]); bio$familyID[bio$playerID %in% ids] <- as.integer(f) }
bio <- bio[,c("playerID","first_name","last_name","full_name","height","weight","country","draft_year","draft_round","draft_number","familyID","father_dummy","son_dummy","brother_dummy","twin_dummy","birthdate","greatest_75_flag","same_name_flag")]

dir.create("results", showWarnings=FALSE)
write.csv(bio, "data/player_bio.csv", row.names=FALSE, na="")
write.csv(seasons, "data/player_seasons.csv", row.names=FALSE, na="")
write.csv(data.frame(normalized_name=dup_keys), "results/name_duplicates.csv", row.names=FALSE)
write.csv(data.frame(father=fathers$father, sons=fathers$sons, father_id=fathers$father_id, son_id=fathers$son_id), "results/unmatched_family_relations.csv", row.names=FALSE)
write.csv(salary_conflicts[salary_conflicts$conflict,], "results/salary_conflicts.csv", row.names=FALSE)
merge_report <- data.frame(metric=c("all_seasons_rows","stats_rows","salary_rows","bio_rows","season_rows","duplicate_name_keys","unmatched_father_son_rows","unmatched_sibling_rows","salary_conflict_keys","season_min","season_max","missing_salary_rows","missing_birthdate_rows"),
 value=c(nrow(all_seasons),nrow(stats),nrow(salaries),nrow(bio),nrow(seasons),length(dup_keys),sum(is.na(fathers$father_id)|is.na(fathers$son_id)),sum(is.na(siblings$rel_id)),sum(salary_conflicts$conflict),min(seasons$season,na.rm=TRUE),max(seasons$season,na.rm=TRUE),sum(is.na(seasons$salary)),sum(is.na(bio$birthdate))))
write.csv(merge_report, "results/player_merge_report.csv", row.names=FALSE)
list(bio=bio, seasons=seasons, report=merge_report)
