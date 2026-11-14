# Create the player-level NBA biography table from the three approved sources.
# Run from the project root with: Rscript scripts/create_player_bio.R

options(stringsAsFactors = FALSE)

inputs <- c(
  all_seasons = "data/all_seasons.csv",
  common_player_info = "data/archive_wyatt/csv/common_player_info.csv",
  salaries = "data/NBA Player Salaries_2000-2025.csv",
  father_son = "data/father_son_list.csv",
  siblings = "data/nba_siblings_list.csv"
)
output <- "data/player_bio.csv"
review_output <- "results/player_bio_review.csv"
family_review_output <- "results/father_son_verification.csv"
relations_output <- "data/family_relations.csv"
relations_review_output <- "results/family_relations_verification.csv"
dir.create("results", showWarnings = FALSE, recursive = TRUE)

read_input <- function(path) read.csv(path, check.names = FALSE, stringsAsFactors = FALSE,
                                      na.strings = c("", "NA", "N/A", "null"))
required <- list(
  all_seasons = c("player_name", "college", "country", "draft_year", "draft_round", "draft_number", "season"),
  common_player_info = c("person_id", "first_name", "last_name", "display_first_last",
                         "birthdate", "school", "country", "draft_year", "draft_round",
                         "draft_number", "greatest_75_flag"),
  salaries = c("Player", "Salary", "Season"),
  father_son = c("father", "sons"),
  siblings = c("person_id", "family_id", "full_name")
)
stopifnot(all(file.exists(inputs)))
dat <- lapply(inputs, read_input)
for (nm in names(dat)) {
  missing <- setdiff(required[[nm]], names(dat[[nm]]))
  if (length(missing)) stop(nm, " is missing columns: ", paste(missing, collapse = ", "))
}

blank <- function(x) is.na(x) | !nzchar(trimws(as.character(x)))
clean_display <- function(x) {
  x <- trimws(as.character(x)); x[is.na(x)] <- ""
  x <- gsub("\\s*,\\s*", " ", x)
  x <- gsub("(^|\\s)[[:punct:]]+(?=\\s|$)", " ", x, perl = TRUE)
  trimws(gsub("\\s+", " ", x))
}
normalized <- function(x) {
  x <- tolower(clean_display(x))
  x <- gsub("[’']", "", x)
  x <- gsub("[-_/]", " ", x)
  x <- gsub("[^a-z0-9 ]", " ", x)
  x <- gsub("\\b(jr|sr|ii|iii|iv|v|junior|senior)\\b", " ", x)
  trimws(gsub("\\s+", " ", x))
}
relation_key <- function(x) {
  x <- tolower(clean_display(x))
  x <- gsub("[’']", "", x)
  x <- gsub("[-_/]", " ", x)
  x <- gsub("[^a-z0-9 ]", " ", x)
  trimws(gsub("\\s+", " ", x))
}
first_value <- function(x) {
  x <- as.character(x); x <- x[!blank(x)]
  if (length(x)) trimws(x[1]) else NA_character_
}
split_name <- function(full) {
  z <- strsplit(clean_display(full), " +")[[1]]
  if (!length(z) || !nzchar(z[1])) return(c("", ""))
  suffix <- grepl("^(jr|sr|ii|iii|iv|v)\\.?$", z[length(z)], ignore.case = TRUE)
  if (length(z) == 1) c(z[1], z[1]) else if (suffix && length(z) > 2)
    c(paste(z[seq_len(length(z) - 2)], collapse = " "),
      paste(z[(length(z) - 1):length(z)], collapse = " "))
  else c(paste(z[-length(z)], collapse = " "), z[length(z)])
}
stable_id <- function(key) {
  bytes <- utf8ToInt(key)
  paste0("family_", paste(sprintf("%02x", (bytes %% 256)), collapse = ""))
}
review <- data.frame(issue_type = character(), playerID = character(),
                     full_name = character(), normalized_name = character(),
                     issue_reason = character(), source = character(),
                     stringsAsFactors = FALSE)
add_review <- function(type, id = NA_character_, full = NA_character_, key = NA_character_,
                       reason, source) {
  review <<- rbind(review, data.frame(issue_type = type, playerID = id,
    full_name = full, normalized_name = key, issue_reason = reason, source = source,
    stringsAsFactors = FALSE))
}

asrc <- dat$all_seasons
isrc <- dat$common_player_info
ssrc <- dat$salaries
fsrc <- dat$father_son
sibsrc <- dat$siblings
asrc$normalized_name <- normalized(asrc$player_name)
ssrc$normalized_name <- normalized(ssrc$Player)
isrc$source_full_name <- ifelse(!blank(isrc$display_first_last), isrc$display_first_last,
                                paste(isrc$first_name, isrc$last_name))
isrc$source_full_name <- clean_display(isrc$source_full_name)
isrc$normalized_name <- normalized(isrc$source_full_name)
asrc <- asrc[nzchar(asrc$normalized_name), , drop = FALSE]
ssrc <- ssrc[nzchar(ssrc$normalized_name), , drop = FALSE]
isrc <- isrc[nzchar(isrc$normalized_name), , drop = FALSE]

# Reduce season sources to unique normalized names before matching.
season_keys <- unique(asrc$normalized_name)
salary_keys <- unique(ssrc$normalized_name)
all_keys <- unique(c(isrc$normalized_name, season_keys, salary_keys))

# One deterministic career record per person_id.
person_ids <- unique(as.character(isrc$person_id))
person_ids <- person_ids[!blank(person_ids)]
career <- do.call(rbind, lapply(person_ids, function(pid) {
  z <- isrc[as.character(isrc$person_id) == pid, , drop = FALSE]
  o <- z[1, , drop = FALSE]
  for (nm in names(o)) if (nm %in% names(z)) o[[nm]] <- first_value(z[[nm]])
  o$person_id <- pid
  o
}))
career$normalized_name <- normalized(career$source_full_name)
career <- career[nzchar(career$normalized_name), , drop = FALSE]
career_key_count <- table(career$normalized_name)

college_values <- lapply(all_keys, function(k) {
  vals <- unique(trimws(as.character(asrc$college[asrc$normalized_name == k])))
  vals <- sort(vals[!blank(vals)])
  if (length(vals) > 1) {
    add_review("school_conflict", key = k, reason =
      paste("Multiple all_seasons college values; selected deterministic first:", paste(vals, collapse = " | ")),
      source = "all_seasons.csv")
  }
  if (length(vals)) vals[1] else NA_character_
})
names(college_values) <- all_keys

# Names found only in all_seasons become deterministic fallback bio rows.
# Salary-only names remain review findings because salary is not a player register.
career_keys <- unique(career$normalized_name)
season_only_keys <- setdiff(season_keys, career_keys)
salary_only_keys <- setdiff(salary_keys, union(career_keys, season_keys))
for (k in salary_only_keys) {
  full <- clean_display(first_value(ssrc$Player[ssrc$normalized_name == k]))
  add_review("unmatched_name", NA_character_, full, k,
    "Name appears only in the salary source and is not added to player_bio",
    "NBA Player Salaries_2000-2025.csv")
}

rows <- lapply(seq_len(nrow(career)), function(i) {
  r <- career[i, , drop = FALSE]
  k <- r$normalized_name
  full <- clean_display(r$source_full_name)
  parts <- split_name(full)
  school <- if (length(college_values[[k]]) && !blank(college_values[[k]])) {
    college_values[[k]]
  } else {
    first_value(r$school)
  }
  birth <- first_value(r$birthdate)
  other <- as.integer(career_key_count[[k]] > 1)
  if (is.na(birth) || !nzchar(birth)) add_review("invalid_birthdate",
    paste0("p_", r$person_id), full, k,
    "Birthdate is missing; no value was imputed", "common_player_info.csv")
  else if (is.na(as.POSIXct(birth, format = "%Y-%m-%d %H:%M:%S", tz = "UTC")))
    add_review("invalid_birthdate", paste0("p_", r$person_id), full, k,
      paste("Birthdate is not parseable:", birth), "common_player_info.csv")
  if (length(unique(trimws(as.character(asrc$college[asrc$normalized_name == k]))[
    !blank(asrc$college[asrc$normalized_name == k])])) > 1) other <- 1L
  data.frame(
    playerID = paste0("p_", r$person_id), first_name = parts[1],
    last_name = parts[2], full_name = full, school = school,
    country = first_value(r$country), draft_year = first_value(r$draft_year),
    draft_round = first_value(r$draft_round), draft_number = first_value(r$draft_number),
    familyID = 0L, father_dummy = 0L, son_dummy = 0L, brother_dummy = 0L,
    twin_dummy = 0L, birthdate = birth, greatest_75_flag = first_value(r$greatest_75_flag),
    other_flag = other, stringsAsFactors = FALSE)
})
bio <- do.call(rbind, rows)

fallback_rows <- lapply(season_only_keys, function(k) {
  z <- asrc[asrc$normalized_name == k, , drop = FALSE]
  names_found <- sort(unique(clean_display(z$player_name)))
  full <- names_found[1]
  parts <- split_name(full)
  vals <- function(column) {
    x <- sort(unique(trimws(as.character(z[[column]]))))
    x <- x[!blank(x)]
    if (length(x) == 1) x else NA_character_
  }
  country <- vals("country")
  draft_year <- vals("draft_year")
  draft_round <- vals("draft_round")
  draft_number <- vals("draft_number")
  if (length(unique(trimws(as.character(z$country))[!blank(z$country)])) > 1)
    add_review("other_conflict", stable_id(k), full, k,
      "Multiple all_seasons country values; left fallback country as NA", "all_seasons.csv")
  if (length(unique(trimws(as.character(z$draft_year))[!blank(z$draft_year)])) > 1 ||
      length(unique(trimws(as.character(z$draft_round))[!blank(z$draft_round)])) > 1 ||
      length(unique(trimws(as.character(z$draft_number))[!blank(z$draft_number)])) > 1)
    add_review("other_conflict", stable_id(k), full, k,
      "Inconsistent all_seasons draft fields; left conflicting fallback fields as NA", "all_seasons.csv")
  add_review("unmatched_name", stable_id(k), full, k,
    "Unique valid all_seasons normalized name absent from common_player_info; included with deterministic fallback ID",
    "all_seasons.csv")
  data.frame(
    playerID = stable_id(k), first_name = parts[1], last_name = parts[2], full_name = full,
    school = college_values[[k]], country = country, draft_year = draft_year,
    draft_round = draft_round, draft_number = draft_number,
    familyID = 0L, father_dummy = 0L, son_dummy = 0L, brother_dummy = 0L,
    twin_dummy = 0L, birthdate = NA_character_, greatest_75_flag = NA_character_,
    other_flag = 1L, stringsAsFactors = FALSE)
})
if (length(fallback_rows)) bio <- rbind(bio, do.call(rbind, fallback_rows))

# Family lists are authoritative for relationship membership. Add a blank bio
# row for a listed father or son that is absent from every player source.
family_names <- unique(c(as.character(fsrc$father), as.character(fsrc$sons),
                         as.character(sibsrc$full_name)))
family_names <- clean_display(family_names[!blank(family_names)])
family_keys <- relation_key(family_names)
missing_family <- family_names[!family_keys %in% relation_key(bio$full_name)]
family_rows <- lapply(missing_family, function(full) {
  parts <- split_name(full)
  key <- relation_key(full)
  add_review("family_added", stable_id(key), full, key,
    "Family-list name was absent from player sources; added blank bio row",
    "father_son_list.csv")
  data.frame(
    playerID = stable_id(key), first_name = parts[1], last_name = parts[2],
    full_name = full, school = NA_character_, country = NA_character_,
    draft_year = NA_character_, draft_round = NA_character_,
    draft_number = NA_character_, familyID = 0L, father_dummy = 0L,
    son_dummy = 0L, brother_dummy = 0L, twin_dummy = 0L,
    birthdate = NA_character_, greatest_75_flag = NA_character_,
    other_flag = 1L, stringsAsFactors = FALSE)
})
if (length(family_rows)) bio <- rbind(bio, do.call(rbind, family_rows))

# Apply father/son flags and assign one family ID to each connected
# father-son component, including families with multiple listed children.
bio_keys <- relation_key(bio$full_name)
father_keys <- relation_key(fsrc$father)
son_keys <- relation_key(fsrc$sons)
explicit_brother_keys <- relation_key(sibsrc$full_name)
bio$father_dummy <- as.integer(bio_keys %in% father_keys)
bio$son_dummy <- as.integer(bio_keys %in% son_keys)
father_edges <- data.frame(person1 = father_keys, person2 = son_keys,
                           relation_type = "father_son",
                           source = "father_son_list.csv",
                           stringsAsFactors = FALSE)
father_edges <- father_edges[nzchar(father_edges$person1) & nzchar(father_edges$person2), ]
sibling_groups <- split(relation_key(sibsrc$full_name), sibsrc$family_id)
sibling_edges <- do.call(rbind, lapply(sibling_groups, function(members) {
  members <- unique(members[nzchar(members)])
  if (length(members) < 2) return(NULL)
  pairs <- combn(members, 2)
  data.frame(person1 = pairs[1, ], person2 = pairs[2, ],
             relation_type = "sibling",
             source = "nba_siblings_list.csv", stringsAsFactors = FALSE)
}))
father_sibling_groups <- split(son_keys, father_keys)
derived_sibling_edges <- do.call(rbind, lapply(father_sibling_groups, function(members) {
  members <- unique(members[nzchar(members)])
  if (length(members) < 2) return(NULL)
  pairs <- combn(members, 2)
  data.frame(person1 = pairs[1, ], person2 = pairs[2, ],
             relation_type = "sibling",
             source = "father_son_list.csv (shared father)",
             stringsAsFactors = FALSE)
}))
family_edges <- rbind(father_edges, sibling_edges, derived_sibling_edges)
family_edges <- family_edges[!duplicated(family_edges[c("person1", "person2",
                                                         "relation_type")]), , drop = FALSE]
brother_keys <- unique(c(explicit_brother_keys,
                         family_edges$person1[family_edges$relation_type == "sibling"],
                         family_edges$person2[family_edges$relation_type == "sibling"]))
bio$brother_dummy <- as.integer(bio_keys %in% brother_keys)
family_components <- list()
for (i in seq_len(nrow(family_edges))) {
  edge <- family_edges[i, ]
  hit <- which(vapply(family_components, function(x)
    edge$person1 %in% x || edge$person2 %in% x, logical(1)))
  if (!length(hit)) {
    family_components[[length(family_components) + 1L]] <- c(edge$person1, edge$person2)
  } else {
    family_components[[hit[1]]] <- unique(c(family_components[[hit[1]]],
                                             edge$person1, edge$person2))
    if (length(hit) > 1) {
      family_components[[hit[1]]] <- unique(unlist(family_components[hit]))
      family_components <- family_components[-hit[-1]]
    }
  }
}
bio$familyID <- 0L
for (i in seq_along(family_components)) {
  members <- family_components[[i]]
  bio$familyID[bio_keys %in% members] <- i
}
bio$normalized_name <- normalized(bio$full_name)
bio$same_name_flag <- as.integer(ave(bio$playerID, bio$normalized_name, FUN = length) > 1)
dup_keys <- unique(bio$normalized_name[bio$same_name_flag == 1])
for (k in dup_keys) {
  z <- bio[bio$normalized_name == k, ]
  add_review("name_duplicate", paste(z$playerID, collapse = " | "), paste(z$full_name, collapse = " | "),
             k, "More than one distinct output player has this normalized name",
             "combined player register")
}

# Verify every source relationship resolves to one or more bio rows and that
# all matching endpoints carry the expected flags and shared family ID.
family_verification <- do.call(rbind, lapply(seq_len(nrow(father_edges)), function(i) {
  edge <- father_edges[i, ]
  father_rows <- which(bio_keys == edge$person1)
  son_rows <- which(bio_keys == edge$person2)
  father_ok <- length(father_rows) > 0L &&
    all(bio$father_dummy[father_rows] == 1L)
  son_ok <- length(son_rows) > 0L &&
    all(bio$son_dummy[son_rows] == 1L)
  family_ok <- father_ok && son_ok &&
    all(bio$familyID[father_rows] == bio$familyID[son_rows]) &&
    all(bio$familyID[c(father_rows, son_rows)] != 0L)
  data.frame(
    father = as.character(fsrc$father[i]),
    son = as.character(fsrc$sons[i]),
    father_playerID = if (length(father_rows)) paste(bio$playerID[father_rows], collapse = " | ") else NA_character_,
    son_playerID = if (length(son_rows)) paste(bio$playerID[son_rows], collapse = " | ") else NA_character_,
    father_match_count = length(father_rows),
    son_match_count = length(son_rows),
    father_exists = length(father_rows) > 0L,
    son_exists = length(son_rows) > 0L,
    father_dummy_ok = father_ok,
    son_dummy_ok = son_ok,
    shared_familyID = family_ok,
    status = if (family_ok && length(father_rows) == 1L && length(son_rows) == 1L) {
      "linked"
    } else if (family_ok) {
      "linked_ambiguous_name"
    } else {
      "not_linked"
    },
    stringsAsFactors = FALSE
  )
}))
write.csv(family_verification, family_review_output, row.names = FALSE, na = "")
if (any(family_verification$status == "not_linked")) {
  failed <- family_verification[family_verification$status == "not_linked", ]
  stop("Father-son verification failed for ", nrow(failed),
       " relationship(s); see ", family_review_output)
}

relation_rows <- lapply(seq_len(nrow(family_edges)), function(i) {
  edge <- family_edges[i, ]
  person1_rows <- which(bio_keys == edge$person1)
  person2_rows <- which(bio_keys == edge$person2)
  relation_ok <- length(person1_rows) > 0L && length(person2_rows) > 0L &&
    all(bio$familyID[c(person1_rows, person2_rows)] != 0L) &&
    length(unique(bio$familyID[c(person1_rows, person2_rows)])) == 1L
  data.frame(
    relation_ID = paste0("rel_", paste(sprintf("%02x",
      utf8ToInt(paste(edge$relation_type, edge$person1, edge$person2, sep = "|")) %% 256),
      collapse = "")),
    familyID = if (relation_ok) bio$familyID[person1_rows[1]] else NA_integer_,
    person1_playerID = if (length(person1_rows)) paste(bio$playerID[person1_rows], collapse = " | ") else NA_character_,
    person1_full_name = if (length(person1_rows)) paste(bio$full_name[person1_rows], collapse = " | ") else NA_character_,
    person2_playerID = if (length(person2_rows)) paste(bio$playerID[person2_rows], collapse = " | ") else NA_character_,
    person2_full_name = if (length(person2_rows)) paste(bio$full_name[person2_rows], collapse = " | ") else NA_character_,
    relation_type = edge$relation_type,
    source = edge$source,
    person1_match_count = length(person1_rows),
    person2_match_count = length(person2_rows),
    status = if (!relation_ok) "not_linked" else if (length(person1_rows) == 1L &&
      length(person2_rows) == 1L) "linked" else "linked_ambiguous_name",
    stringsAsFactors = FALSE
  )
})
family_relations <- do.call(rbind, relation_rows)
write.csv(family_relations, relations_output, row.names = FALSE, na = "")
write.csv(family_relations, relations_review_output, row.names = FALSE, na = "")
if (any(family_relations$status == "not_linked")) {
  stop("Family relation verification failed; see ", relations_review_output)
}
bio$normalized_name <- NULL
bio <- bio[, c("playerID","first_name","last_name","full_name","school","country",
  "draft_year","draft_round","draft_number","familyID","father_dummy","son_dummy",
  "brother_dummy","twin_dummy","birthdate","greatest_75_flag","same_name_flag","other_flag")]
write.csv(bio, output, row.names = FALSE, na = "")
write.csv(review, review_output, row.names = FALSE, na = "")
cat(sprintf("Wrote %s (%d players) and %s (%d review rows)\n", output, nrow(bio),
            review_output, nrow(review)))
