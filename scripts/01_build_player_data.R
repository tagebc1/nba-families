# Build the project datasets from the raw files in data/:
#
#   data/output_data/player_bio.csv        one row per player (career level)
#   data/output_data/player_seasons.csv    one row per player and season
#   data/output_data/family_relations.csv  one row per father-son / sibling pair
#
# Every playerID in player_seasons.csv exists in player_bio.csv. Identity is
# resolved ONCE per (name, season, age) and reused for both files, so the
# two can always be joined on playerID.
#
# Run from the project root:  Rscript scripts/01_build_player_data.R
# Review files are written to results/.

options(stringsAsFactors = FALSE)
source("scripts/helpers.R")

paths <- list(
  players     = "data/archive_wyatt/csv/player.csv",
  cpi         = "data/archive_wyatt/csv/common_player_info.csv",
  draft       = "data/archive_wyatt/csv/draft_history.csv",
  all_seasons = "data/all_seasons.csv",
  stats       = "data/NBA Player Stats and Salaries_2000-2025.csv",
  salaries    = "data/NBA Player Salaries_2000-2025.csv",
  father_son  = "data/father_son_list.csv",
  siblings    = "data/nba_siblings_list.csv",
  aliases     = "data/name_aliases.csv",
  out_dir     = "data/output_data",
  results     = "results"
)
stopifnot(all(file.exists(unlist(paths[1:9]))))
dir.create(paths$out_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(paths$results, showWarnings = FALSE, recursive = TRUE)

# ---------------------------------------------------------------------------
# 1. Read inputs
# ---------------------------------------------------------------------------
players  <- read_input(paths$players)
cpi      <- read_input(paths$cpi)
draft    <- read_input(paths$draft)
hist     <- read_input(paths$all_seasons)
stats    <- read_input(paths$stats)
salaries <- read_input(paths$salaries)
fathers  <- read_input(paths$father_son)
siblings <- read_input(paths$siblings)
aliases  <- read_input(paths$aliases)

require_columns(players, c("id", "full_name"), "player.csv")
require_columns(cpi, c("person_id", "display_first_last", "birthdate", "school",
                       "country", "height", "weight", "from_year", "to_year",
                       "draft_year", "draft_round", "draft_number",
                       "greatest_75_flag"), "common_player_info")
require_columns(draft, c("person_id", "season", "round_number", "overall_pick"), "draft_history")
require_columns(hist, c("player_name", "team_abbreviation", "age", "player_height",
                        "player_weight", "college", "country", "draft_year",
                        "draft_round", "draft_number", "gp", "pts", "reb", "ast",
                        "net_rating", "oreb_pct", "dreb_pct", "usg_pct",
                        "ts_pct", "ast_pct", "season"), "all_seasons")
require_columns(stats, c("Player", "Salary", "Year", "Pos", "Age", "Team", "G",
                         "GS", "MP", "FG", "FGA", "FG%", "3P", "3PA", "3P%",
                         "2P", "2PA", "2P%", "eFG%", "FT", "FTA", "FT%", "ORB",
                         "DRB", "TRB", "AST", "STL", "BLK", "TOV", "PF", "PTS"),
                "stats")
require_columns(salaries, c("Player", "Salary", "Season"), "salaries")
require_columns(fathers, c("father", "sons"), "father_son_list")
require_columns(siblings, c("family_id", "full_name"), "nba_siblings_list")
require_columns(aliases, c("source_name", "canonical_name"), "name_aliases")

# Aliases map a spelling used in a season source to the spelling used in the
# player register ("Steve Smith" -> "Steven Smith"). Applied on keys.
alias_map <- setNames(normalize_name(aliases$canonical_name),
                      normalize_name(aliases$source_name))
apply_alias <- function(key) ifelse(key %in% names(alias_map), alias_map[key], key)

# ---------------------------------------------------------------------------
# 2. Person register: every NBA player id (player.csv), enriched with
#    common_player_info (birthdate, career years, bio) and draft_history.
# ---------------------------------------------------------------------------
players <- players[!is.na(players$id) & !duplicated(players$id), ]
players$full_name <- clean_display(players$full_name)
players <- players[nzchar(players$full_name), ]
cpi <- cpi[!duplicated(cpi$person_id), ]
draft <- draft[order(draft$season), ]
draft <- draft[!duplicated(draft$person_id), ]
mc <- match(players$id, cpi$person_id)
md <- match(players$id, draft$person_id)
cpi_draft_year <- suppressWarnings(as.integer(cpi$draft_year[mc]))

persons <- data.frame(
  playerID     = paste0("p_", players$id),
  full_name    = players$full_name,
  birthdate    = substr(as.character(cpi$birthdate[mc]), 1, 10),
  country      = cpi$country[mc],
  school       = cpi$school[mc],
  height_cm    = height_to_cm(cpi$height[mc]),
  weight_kg    = lbs_to_kg(cpi$weight[mc]),
  draft_year   = ifelse(!is.na(cpi_draft_year), cpi_draft_year, as.integer(draft$season[md])),
  draft_round  = ifelse(!is.na(cpi_draft_year), suppressWarnings(as.integer(cpi$draft_round[mc])),
                        as.integer(draft$round_number[md])),
  draft_number = ifelse(!is.na(cpi_draft_year), suppressWarnings(as.integer(cpi$draft_number[mc])),
                        as.integer(draft$overall_pick[md])),
  career_start = suppressWarnings(as.integer(cpi$from_year[mc])),
  career_end   = suppressWarnings(as.integer(cpi$to_year[mc])),
  greatest_75_flag = ifelse(cpi$greatest_75_flag[mc] %in% "Y", 1L, 0L),
  id_source    = "nba_id"
)
persons$birth_year <- suppressWarnings(as.integer(substr(persons$birthdate, 1, 4)))
persons$name_key <- normalize_name(persons$full_name)
persons$name_key_stripped <- normalize_name(persons$full_name, strip_suffix = TRUE)
# Second spelling from common_player_info ("Sun Yue" vs "Sun Sun").
alt <- clean_display(cpi$display_first_last[mc])
persons$alt_key <- ifelse(is.na(alt) | !nzchar(alt), persons$name_key, normalize_name(alt))
persons$alt_key_stripped <- ifelse(is.na(alt) | !nzchar(alt), persons$name_key_stripped,
                                   normalize_name(alt, strip_suffix = TRUE))
persons$from_year <- persons$career_start
persons$to_year <- persons$career_end
last_source_year <- max(persons$to_year, na.rm = TRUE)
persons_match <- persons
persons_match$birthdate <- as.Date(persons$birthdate)

# ---------------------------------------------------------------------------
# 3. Season observations from the three season sources (long format)
# ---------------------------------------------------------------------------
stats$season    <- season_end_year(stats$Year)
salaries$season <- season_end_year(salaries$Season)
hist$season     <- season_end_year(hist$season)
stats$raw_name    <- clean_display(stats$Player)
salaries$raw_name <- clean_display(salaries$Player)
hist$raw_name     <- clean_display(hist$player_name)
stats    <- stats[nzchar(stats$raw_name), ]
salaries <- salaries[nzchar(salaries$raw_name), ]
hist     <- hist[nzchar(hist$raw_name), ]
stats$Age <- to_number(stats$Age)
hist$age  <- to_number(hist$age)

obs <- rbind(
  data.frame(source = "stats", raw_name = stats$raw_name, season = stats$season,
             age = stats$Age, age_ref = "feb", row = seq_len(nrow(stats))),
  data.frame(source = "salary", raw_name = salaries$raw_name, season = salaries$season,
             age = NA_real_, age_ref = NA_character_, row = seq_len(nrow(salaries))),
  data.frame(source = "all_seasons", raw_name = hist$raw_name, season = hist$season,
             age = hist$age, age_ref = "jul", row = seq_len(nrow(hist)))
)
obs$name_key <- apply_alias(normalize_name(obs$raw_name))
obs$name_key_stripped <- normalize_name(obs$name_key, strip_suffix = TRUE)

# Two rows with the same name in the same season but different ages are two
# different people (two "Marcus Williams" in 2008-09), so identity is
# resolved per (name, season, age). Salary rows carry no age; they borrow
# the stats-file age for that name and season when it is unique.
stats_age <- aggregate(age ~ name_key + season, obs[obs$source == "stats", ],
                       function(a) if (length(unique(a)) == 1) a[1] else NA_real_)
need <- obs$source == "salary"
obs$age[need] <- stats_age$age[match(paste(obs$name_key[need], obs$season[need]),
                                     paste(stats_age$name_key, stats_age$season))]
obs$age_ref[need & !is.na(obs$age)] <- "feb"
obs$unit <- paste(obs$name_key, obs$season, obs$age, obs$age_ref, sep = "|")
units <- obs[!duplicated(obs$unit), c("unit", "name_key", "name_key_stripped", "season", "age", "age_ref")]

units <- resolve_identity(units, persons_match, last_source_year = last_source_year)
units <- resolve_by_nearest_season(units, persons_match)
obs$playerID   <- units$playerID[match(obs$unit, units$unit)]
obs$match_type <- units$match_type[match(obs$unit, units$unit)]

# Rows that stay ambiguous (a salary row for a name shared by two players in
# the same period) cannot be attributed and are dropped from the outputs.
obs_all <- obs
ambiguous <- grepl("ambiguous", obs$match_type)
dropped <- obs[ambiguous, ]
obs <- obs[!ambiguous, ]

# ---------------------------------------------------------------------------
# 4. Players not found in the register get a name-based ID (n_<name>).
#    Mostly rookies who entered after the register snapshot.
# ---------------------------------------------------------------------------
unresolved <- is.na(obs$playerID)
obs$playerID[unresolved] <- paste0("n_", gsub(" ", "_", obs$name_key_stripped[unresolved]))
obs$id_match <- ifelse(unresolved, "name_only", "nba_id")

hist_rows <- obs$source == "all_seasons"
hist_by_id <- split(hist[obs$row[hist_rows & unresolved], ], obs$playerID[hist_rows & unresolved])
name_only <- do.call(rbind, lapply(unique(obs$playerID[unresolved]), function(id) {
  rows <- obs[obs$playerID == id, ]
  h <- hist_by_id[[id]]
  val <- function(col) if (!is.null(h)) single_value(h[[col]]) else NA_character_
  data.frame(
    playerID = id, full_name = most_common(rows$raw_name), birthdate = NA_character_,
    country = val("country"), school = val("college"),
    height_cm = NA_real_, weight_kg = NA_real_,
    draft_year = suppressWarnings(as.integer(val("draft_year"))),
    draft_round = suppressWarnings(as.integer(val("draft_round"))),
    draft_number = suppressWarnings(as.integer(val("draft_number"))),
    career_start = min(rows$season) - 1L, career_end = max(rows$season) - 1L,
    greatest_75_flag = 0L,
    id_source = "name_only",
    # Birth year estimated from the ages reported in the season sources.
    birth_year = if (any(!is.na(rows$age)))
      as.integer(round(median(rows$season - rows$age, na.rm = TRUE))) else NA_integer_,
    name_key = NA_character_, name_key_stripped = NA_character_,
    alt_key = NA_character_, alt_key_stripped = NA_character_,
    from_year = NA_integer_, to_year = NA_integer_)
}))
if (!is.null(name_only)) {
  name_only$name_key <- normalize_name(name_only$full_name)
  name_only$name_key_stripped <- normalize_name(name_only$full_name, strip_suffix = TRUE)
  name_only$alt_key <- name_only$name_key
  name_only$alt_key_stripped <- name_only$name_key_stripped
}
bio <- rbind(persons, name_only)

# Register players without a birthdate get a birth year estimated from the
# ages reported in the season sources (same rule as for name-only players).
est <- aggregate(by ~ playerID, cbind(obs[!is.na(obs$age), "playerID", drop = FALSE],
                                      by = obs$season[!is.na(obs$age)] - obs$age[!is.na(obs$age)]),
                 function(x) as.integer(round(median(x))))
gap <- is.na(bio$birth_year) & bio$playerID %in% est$playerID
bio$birth_year[gap] <- est$by[match(bio$playerID[gap], est$playerID)]

# Fill bio gaps from all_seasons (one consistent value per player only).
hist_bio <- cbind(playerID = obs$playerID[hist_rows], hist[obs$row[hist_rows],
                  c("college", "country", "draft_year", "draft_round", "draft_number")])
hist_bio <- aggregate(hist_bio[-1], hist_bio["playerID"], single_value)
mh <- match(bio$playerID, hist_bio$playerID)
fill_from_hist <- function(target, source) {
  gap <- is.na(bio[[target]]) & !is.na(mh)
  value <- hist_bio[[source]][mh[gap]]
  if (is.numeric(bio[[target]])) value <- suppressWarnings(as.integer(value))
  bio[[target]][gap] <<- value
}
fill_from_hist("school", "college"); fill_from_hist("country", "country")
fill_from_hist("draft_year", "draft_year"); fill_from_hist("draft_round", "draft_round")
fill_from_hist("draft_number", "draft_number")

# ---------------------------------------------------------------------------
# 5. Family relations (father-son list and sibling list)
# ---------------------------------------------------------------------------
# Candidate bio rows for a family-list name: exact name first, then the name
# without "Sr."/"Jr."/"III".
family_hits <- function(name) {
  key <- apply_alias(normalize_name(name))
  hits <- which(bio$name_key == key)
  if (!length(hits)) hits <- which(bio$name_key_stripped == normalize_name(key, strip_suffix = TRUE))
  hits
}
# Generation score: lower = older. Birth year, else draft year, else first season.
generation <- function(rows) {
  g <- bio$birth_year[rows]
  g <- ifelse(is.na(g), bio$draft_year[rows] - 20L, g)
  ifelse(is.na(g), bio$career_start[rows] - 22L, g)
}
oldest   <- function(rows) rows[order(generation(rows), na.last = TRUE)[1]]
youngest <- function(rows) rows[order(-generation(rows), na.last = TRUE)[1]]
# Identical names (two "Mike Dunleavy") are separated by generation: a
# father is the oldest candidate, a son the youngest.
find_person <- function(name, role = c("any", "father", "son")) {
  role <- match.arg(role)
  hits <- family_hits(name)
  if (!length(hits)) return(NA_integer_)
  if (length(hits) == 1) return(hits)
  key <- normalize_name(name)
  if (role == "any") role <- if (grepl("\\bsr\\b", key, perl = TRUE)) "father" else
    if (grepl("\\b(jr|ii|iii|iv)\\b", key, perl = TRUE)) "son" else "any"
  if (role == "any") return(hits[1])
  if (role == "father") oldest(hits) else youngest(hits)
}
# Append a bio row for a family-list name that no source contains. The suffix
# is kept in the ID so "Bill Hosket Sr." and "Bill Hosket Jr." stay apart.
add_person <- function(name) {
  add <- bio[NA_integer_, ]
  add$playerID <- paste0("n_", gsub(" ", "_", normalize_name(name)))
  add$full_name <- clean_display(name)
  add$greatest_75_flag <- 0L
  add$id_source <- "family_list_only"
  add$name_key <- add$alt_key <- normalize_name(name)
  add$name_key_stripped <- add$alt_key_stripped <- normalize_name(name, strip_suffix = TRUE)
  if (add$playerID %in% bio$playerID) stop("Duplicate family ID: ", add$playerID)
  bio <<- rbind(bio, add)
  nrow(bio)
}
family_names <- clean_display(c(fathers$father, fathers$sons, siblings$full_name))
family_names <- unique(family_names[nzchar(family_names)])
for (nm in family_names) if (is.na(find_person(nm))) add_person(nm)

# Father-son pairs are resolved jointly. When both names land on the same
# person, the name that matched exactly keeps it; the other end takes another
# candidate with the same name if one exists, otherwise gets a new row. If
# neither name matched exactly the existing person is assumed to be the son
# (the sources are newest-heavy) and the pair is flagged for review.
pairs <- do.call(rbind, lapply(seq_len(nrow(fathers)), function(i) {
  f_name <- fathers$father[i]; s_name <- fathers$sons[i]
  f <- find_person(f_name, "father"); s <- find_person(s_name, "son")
  status <- "linked"
  if (f == s) {
    f_exact <- bio$name_key[f] == normalize_name(f_name)
    s_exact <- bio$name_key[s] == normalize_name(s_name)
    if (f_exact && !s_exact) {
      alt_s <- setdiff(family_hits(s_name), f)
      s <- if (length(alt_s)) youngest(alt_s) else add_person(s_name)
      status <- "linked_son_reassigned"
    } else {
      alt_f <- setdiff(family_hits(f_name), s)
      f <- if (length(alt_f)) oldest(alt_f) else add_person(f_name)
      status <- if (s_exact) "linked_father_reassigned" else "linked_father_reassigned_assumed"
    }
  }
  data.frame(person1 = f, person2 = s, person1_name = f_name, person2_name = s_name,
             relation_type = "father_son", source = "father_son_list.csv", status = status)
}))
# Siblings: a name with several namesakes takes the candidate closest in
# generation to the other siblings in the group. A candidate without any
# birth/draft/career information counts as 12 years off, so it wins only
# when every known namesake is implausibly far away.
resolve_sibling_group <- function(names) {
  hits <- lapply(names, family_hits)
  known <- unlist(hits[lengths(hits) == 1])
  ref <- if (length(known)) median(generation(known), na.rm = TRUE) else NA_real_
  vapply(hits, function(h) {
    if (length(h) <= 1) return(if (length(h)) h else NA_integer_)
    if (is.na(ref)) return(h[1])
    dist <- abs(generation(h) - ref); dist[is.na(dist)] <- 12
    h[which.min(dist)]
  }, integer(1))
}
sibling_edges <- do.call(rbind, lapply(split(siblings, siblings$family_id), function(g) {
  idx <- unique(resolve_sibling_group(g$full_name))
  idx <- idx[!is.na(idx)]
  if (length(idx) < 2) return(NULL)
  pr <- combn(idx, 2)
  data.frame(person1 = pr[1, ], person2 = pr[2, ],
             person1_name = bio$full_name[pr[1, ]], person2_name = bio$full_name[pr[2, ]],
             relation_type = "sibling", source = "nba_siblings_list.csv", status = "linked")
}))
# Sons who share a father are siblings too.
shared <- split(pairs$person2, pairs$person1)
derived <- do.call(rbind, lapply(shared, function(s) {
  s <- unique(s); if (length(s) < 2) return(NULL)
  pr <- combn(s, 2)
  data.frame(person1 = pr[1, ], person2 = pr[2, ],
             person1_name = bio$full_name[pr[1, ]], person2_name = bio$full_name[pr[2, ]],
             relation_type = "sibling", source = "father_son_list.csv (shared father)",
             status = "linked")
}))
edges <- rbind(pairs, sibling_edges, derived)
edges <- edges[edges$person1 != edges$person2, ]
pair_key <- ifelse(edges$relation_type == "sibling",
                   paste(pmin(edges$person1, edges$person2), pmax(edges$person1, edges$person2)),
                   paste(edges$person1, edges$person2))
edges <- edges[!duplicated(paste(edges$relation_type, pair_key)), ]

# familyID: connected components over all relation edges (union-find).
comp <- seq_len(nrow(bio))
find_root <- function(i) { while (comp[i] != i) i <- comp[i]; i }
for (i in seq_len(nrow(edges))) {
  a <- find_root(edges$person1[i]); b <- find_root(edges$person2[i])
  if (a != b) comp[max(a, b)] <- min(a, b)
}
roots <- vapply(seq_len(nrow(bio)), find_root, integer(1))
in_family <- seq_len(nrow(bio)) %in% c(edges$person1, edges$person2)
bio$familyID <- 0L
bio$familyID[in_family] <- as.integer(factor(roots[in_family]))
is_father_son <- edges$relation_type == "father_son"
bio$father_dummy  <- as.integer(seq_len(nrow(bio)) %in% edges$person1[is_father_son])
bio$son_dummy     <- as.integer(seq_len(nrow(bio)) %in% edges$person2[is_father_son])
bio$brother_dummy <- as.integer(seq_len(nrow(bio)) %in%
                                  c(edges$person1[!is_father_son], edges$person2[!is_father_son]))
family_relations <- data.frame(
  familyID = bio$familyID[edges$person1],
  person1_playerID = bio$playerID[edges$person1],
  person1_full_name = bio$full_name[edges$person1],
  person2_playerID = bio$playerID[edges$person2],
  person2_full_name = bio$full_name[edges$person2],
  relation_type = edges$relation_type,
  source = edges$source
)

# ---------------------------------------------------------------------------
# 6. Write player_bio.csv and family_relations.csv
# ---------------------------------------------------------------------------
bio$same_name_flag <- as.integer(ave(bio$playerID, bio$name_key_stripped, FUN = length) > 1)
names_split <- split_name(bio$full_name)
bio$first_name <- names_split$first_name
bio$last_name  <- names_split$last_name
bio_cols <- c("playerID", "full_name", "first_name", "last_name", "birthdate",
              "birth_year", "country", "school", "height_cm", "weight_kg",
              "draft_year", "draft_round", "draft_number", "career_start",
              "career_end", "greatest_75_flag", "familyID", "father_dummy",
              "son_dummy", "brother_dummy", "same_name_flag", "id_source")
bio_out <- bio[order(bio$last_name, bio$first_name), bio_cols]
if (anyDuplicated(bio_out$playerID))
  stop("Duplicate playerID in bio: ",
       paste(unique(bio_out$playerID[duplicated(bio_out$playerID)]), collapse = ", "))
write.csv(bio_out, file.path(paths$out_dir, "player_bio.csv"), row.names = FALSE, na = "")
write.csv(family_relations, file.path(paths$out_dir, "family_relations.csv"), row.names = FALSE, na = "")

# ---------------------------------------------------------------------------
# 7. Build player_seasons.csv: one row per playerID and season
# ---------------------------------------------------------------------------
n_input <- c(stats = nrow(stats), salaries = nrow(salaries), hist = nrow(hist))
stats    <- stats[obs$row[obs$source == "stats"], ]
salaries <- salaries[obs$row[obs$source == "salary"], ]
hist     <- hist[obs$row[obs$source == "all_seasons"], ]
stats$playerID    <- obs$playerID[obs$source == "stats"]
salaries$playerID <- obs$playerID[obs$source == "salary"]
hist$playerID     <- obs$playerID[obs$source == "all_seasons"]

# A player with several rows in one season (traded mid-season) keeps the row
# with most games; all team codes are kept as "BOS/CLE".
collapse_multi <- function(df, games_col, team_col) {
  df <- df[order(df$playerID, df$season, -to_number(df[[games_col]])), ]
  k <- paste(df$playerID, df$season)
  teams <- tapply(df[[team_col]], k, function(t) paste(unique(t[!is.na(t)]), collapse = "/"))
  n <- tapply(k, k, length)
  df <- df[!duplicated(k), ]
  k <- paste(df$playerID, df$season)
  df[[team_col]] <- unname(teams[k])
  df$multi_team <- as.integer(n[k] > 1)
  df
}
stats_one <- collapse_multi(stats, "G", "Team")
hist_one  <- collapse_multi(hist, "gp", "team_abbreviation")
salary_dups <- sum(duplicated(paste(salaries$playerID, salaries$season)))
salary_one <- salaries[!duplicated(paste(salaries$playerID, salaries$season)), ]

ps <- unique(rbind(stats_one[c("playerID", "season")], salary_one[c("playerID", "season")],
                   hist_one[c("playerID", "season")]))
ps <- ps[order(ps$season, ps$playerID), ]
k  <- paste(ps$playerID, ps$season)
ms <- match(k, paste(stats_one$playerID, stats_one$season))
mw <- match(k, paste(salary_one$playerID, salary_one$season))
mh <- match(k, paste(hist_one$playerID, hist_one$season))
mb <- match(ps$playerID, bio$playerID)
first_non_na <- function(a, b) ifelse(is.na(a), b, a)

ps$full_name  <- bio$full_name[mb]
ps$first_name <- bio$first_name[mb]
ps$last_name  <- bio$last_name[mb]
ps$age        <- first_non_na(stats_one$Age[ms], hist_one$age[mh])
ps$team_abbreviation <- first_non_na(stats_one$Team[ms], hist_one$team_abbreviation[mh])
ps$position   <- stats_one$Pos[ms]
ps$salary     <- first_non_na(to_number(stats_one$Salary[ms]), to_number(salary_one$Salary[mw]))
ps$height_cm  <- round(to_number(hist_one$player_height[mh]), 1)
ps$weight_kg  <- round(to_number(hist_one$player_weight[mh]), 1)
stat_map <- c(G = "games_played", GS = "games_started", MP = "minutes_pg",
              FG = "fgm_pg", FGA = "fga_pg", "FG%" = "fg_pct",
              "3P" = "fg3m_pg", "3PA" = "fg3a_pg", "3P%" = "fg3_pct",
              "2P" = "fg2m_pg", "2PA" = "fg2a_pg", "2P%" = "fg2_pct", "eFG%" = "efg_pct",
              FT = "ftm_pg", FTA = "fta_pg", "FT%" = "ft_pct",
              ORB = "oreb_pg", DRB = "dreb_pg", TRB = "reb_pg", AST = "ast_pg",
              STL = "stl_pg", BLK = "blk_pg", TOV = "tov_pg", PF = "pf_pg", PTS = "pts_pg")
for (src in names(stat_map)) ps[[stat_map[[src]]]] <- to_number(stats_one[[src]][ms])
# all_seasons fills the basic counting stats where the stats file has none.
ps$games_played <- first_non_na(ps$games_played, to_number(hist_one$gp[mh]))
ps$pts_pg <- first_non_na(ps$pts_pg, to_number(hist_one$pts[mh]))
ps$reb_pg <- first_non_na(ps$reb_pg, to_number(hist_one$reb[mh]))
ps$ast_pg <- first_non_na(ps$ast_pg, to_number(hist_one$ast[mh]))
for (col in c("net_rating", "oreb_pct", "dreb_pct", "usg_pct", "ts_pct", "ast_pct"))
  ps[[col]] <- to_number(hist_one[[col]][mh])
ps$in_stats <- as.integer(!is.na(ms))
ps$in_salary <- as.integer(!is.na(mw))
ps$in_all_seasons <- as.integer(!is.na(mh))
ps$multi_team <- as.integer(first_non_na(stats_one$multi_team[ms], hist_one$multi_team[mh]) %in% 1)
ps$id_match <- bio$id_source[mb]

ps_cols <- c("playerID", "season", "full_name", "first_name", "last_name", "age",
             "team_abbreviation", "position", "salary", "height_cm", "weight_kg",
             unname(stat_map), "net_rating", "oreb_pct", "dreb_pct", "usg_pct",
             "ts_pct", "ast_pct", "in_stats", "in_salary", "in_all_seasons",
             "multi_team", "id_match")
ps <- ps[, ps_cols]
stopifnot(!anyDuplicated(paste(ps$playerID, ps$season)),
          all(ps$playerID %in% bio_out$playerID))
write.csv(ps, file.path(paths$out_dir, "player_seasons.csv"), row.names = FALSE, na = "")

# ---------------------------------------------------------------------------
# 8. Review files and report
# ---------------------------------------------------------------------------
# Every (name, season, age) that was not a plain unique match, with the
# candidates that were considered, so the matching can be checked by hand.
cand_text <- function(key_stripped) {
  c1 <- persons[persons$name_key_stripped == key_stripped | persons$alt_key_stripped == key_stripped, ]
  if (!nrow(c1)) return("")
  paste(sprintf("%s (%s, born %s, draft %s, %s-%s)", c1$full_name, c1$playerID,
                c1$birth_year, c1$draft_year, c1$career_start, c1$career_end), collapse = "; ")
}
rev <- units[units$match_type != "exact", ]
rev$candidates <- vapply(rev$name_key_stripped, cand_text, character(1))
rev$assigned_playerID <- obs$playerID[match(rev$unit, obs$unit)]
rev$sources <- vapply(rev$unit, function(u) paste(unique(obs_all$source[obs_all$unit == u]), collapse = "/"), character(1))
rev$raw_names <- vapply(rev$unit, function(u) paste(unique(obs_all$raw_name[obs_all$unit == u]), collapse = " | "), character(1))
rev <- rev[order(rev$match_type, rev$name_key, rev$season),
           c("raw_names", "season", "age", "age_ref", "sources", "match_type",
             "n_candidates", "assigned_playerID", "candidates")]
write.csv(rev, file.path(paths$results, "name_matching_review.csv"), row.names = FALSE, na = "")

# Salary disagreement between the two salary sources (information only).
both <- !is.na(ms) & !is.na(mw)
salary_conflicts <- sum(to_number(stats_one$Salary[ms[both]]) != to_number(salary_one$Salary[mw[both]]), na.rm = TRUE)

# Family relation check: how each listed father-son pair was resolved.
fam_check <- data.frame(
  father = pairs$person1_name, son = pairs$person2_name,
  father_playerID = bio$playerID[pairs$person1], father_birth_year = bio$birth_year[pairs$person1],
  son_playerID = bio$playerID[pairs$person2], son_birth_year = bio$birth_year[pairs$person2],
  status = pairs$status)
fam_check$status[!is.na(fam_check$father_birth_year) & !is.na(fam_check$son_birth_year) &
                   fam_check$father_birth_year >= fam_check$son_birth_year] <- "check_birth_years"
write.csv(fam_check, file.path(paths$results, "family_relations_check.csv"), row.names = FALSE, na = "")
stopifnot(all(fam_check$father_playerID != fam_check$son_playerID))

report <- data.frame(metric = c(
  "input_rows_player_register", "input_rows_stats", "input_rows_salaries", "input_rows_all_seasons",
  "bio_players", "bio_nba_id", "bio_name_only", "bio_family_list_only",
  "bio_same_name_players", "bio_in_a_family",
  "season_rows", "season_rows_nba_id", "season_rows_name_only", "source_rows_dropped_ambiguous",
  "season_rows_in_stats", "season_rows_in_salary", "season_rows_in_all_seasons",
  "season_rows_multi_team", "season_min", "season_max",
  "match_review_rows", "salary_source_conflicts", "salary_duplicate_rows_dropped",
  "family_relations", "families"),
  value = c(nrow(players), n_input[["stats"]], n_input[["salaries"]], n_input[["hist"]],
            nrow(bio_out), sum(bio_out$id_source == "nba_id"), sum(bio_out$id_source == "name_only"),
            sum(bio_out$id_source == "family_list_only"),
            sum(bio_out$same_name_flag == 1), sum(bio_out$familyID > 0),
            nrow(ps), sum(ps$id_match == "nba_id"), sum(ps$id_match == "name_only"), nrow(dropped),
            sum(ps$in_stats), sum(ps$in_salary), sum(ps$in_all_seasons), sum(ps$multi_team),
            min(ps$season), max(ps$season), nrow(rev), salary_conflicts, salary_dups,
            nrow(family_relations), length(unique(family_relations$familyID))))
write.csv(report, file.path(paths$results, "build_report.csv"), row.names = FALSE)
print(report, row.names = FALSE)
cat("\nMatch types for unique (name, season, age) units:\n"); print(table(units$match_type))
cat(sprintf("\nWrote %s/player_bio.csv, player_seasons.csv, family_relations.csv\n", paths$out_dir))
