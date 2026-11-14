# Shared helper functions for the NBA data pipeline.
# Sourced by scripts/01_build_player_data.R. No side effects.

# Read a CSV without mangling column names such as "FG%" or "3P".
read_input <- function(path) {
  x <- read.csv(path, check.names = FALSE, stringsAsFactors = FALSE,
                na.strings = c("", "NA", "N/A", "null"),
                fileEncoding = "UTF-8-BOM")
  names(x) <- trimws(names(x))
  x
}

require_columns <- function(x, cols, label) {
  missing <- setdiff(cols, names(x))
  if (length(missing)) stop(label, " is missing columns: ",
                             paste(missing, collapse = ", "))
  invisible(TRUE)
}

to_number <- function(x) suppressWarnings(as.numeric(gsub(",", "", as.character(x))))

# "Shaquille O'Neal " -> "Shaquille O'Neal"; removes stray commas and
# collapses repeated spaces. Keeps suffixes such as "Jr." and "III".
clean_display <- function(x) {
  x <- as.character(x); x[is.na(x)] <- ""
  x <- gsub("\\s*,\\s*", " ", x)
  trimws(gsub("\\s+", " ", x))
}

# Matching key: ASCII, lower case, no punctuation. "O.G. Anunoby" and
# "OG Anunoby" give the same key. With strip_suffix = TRUE generational
# suffixes are dropped as well, so "Perry Jones III" -> "perry jones".
normalize_name <- function(x, strip_suffix = FALSE) {
  x <- iconv(clean_display(x), "UTF-8", "ASCII//TRANSLIT", sub = "")
  x <- tolower(x)
  x <- gsub("['`^~\"\\.]", "", x)          # drop apostrophes and periods
  x <- gsub("[^a-z0-9 ]", " ", x)           # every other symbol -> space
  x <- trimws(gsub("\\s+", " ", x))
  x <- gsub("\\b([a-z]) ([a-z])\\b", "\\1\\2", x, perl = TRUE)  # "a j price" -> "aj price"
  if (strip_suffix)
    x <- gsub("\\b(jr|sr|ii|iii|iv|v)\\b", " ", x, perl = TRUE)
  trimws(gsub("\\s+", " ", x))
}

# Split "Nick Smith Jr." into first = "Nick", last = "Smith Jr.".
# Single-word names ("Nene") get the same value in both fields.
split_name <- function(full) {
  parts <- strsplit(clean_display(full), " ")
  out <- t(vapply(parts, function(z) {
    if (!length(z) || !nzchar(z[1])) return(c("", ""))
    if (length(z) == 1) return(c(z, z))
    suffix <- grepl("^(jr|sr|ii|iii|iv|v)\\.?$", z[length(z)], ignore.case = TRUE)
    if (suffix && length(z) >= 3)
      c(paste(z[seq_len(length(z) - 2)], collapse = " "),
        paste(z[(length(z) - 1):length(z)], collapse = " "))
    else c(paste(z[-length(z)], collapse = " "), z[length(z)])
  }, character(2)))
  data.frame(first_name = out[, 1], last_name = out[, 2], stringsAsFactors = FALSE)
}

# Season as the end year: "1996-97" -> 1997, "2019-20" -> 2020, "2005" -> 2005.
season_end_year <- function(x) {
  x <- trimws(as.character(x))
  out <- suppressWarnings(as.integer(x))
  m <- grepl("^[0-9]{4}-[0-9]{2}$", x)
  out[m] <- as.integer(substr(x[m], 1, 4)) + 1L
  if (any(is.na(out) & nzchar(x)))
    stop("Unreadable season values: ", paste(head(unique(x[is.na(out)]), 5), collapse = ", "))
  out
}

# "6-10" (feet-inches) -> centimetres; pounds -> kilograms.
height_to_cm <- function(x) {
  p <- strsplit(as.character(x), "-")
  vapply(p, function(z) if (length(z) == 2) round((as.numeric(z[1]) * 12 + as.numeric(z[2])) * 2.54, 1) else NA_real_, numeric(1))
}
lbs_to_kg <- function(x) round(to_number(x) * 0.45359237, 1)

# Most frequent value of a character vector (ties -> alphabetical first).
most_common <- function(x) {
  x <- x[!is.na(x) & nzchar(x)]
  if (!length(x)) return(NA_character_)
  names(sort(table(x), decreasing = TRUE))[1]
}

# Single value if the non-missing values agree, otherwise NA.
single_value <- function(x) {
  x <- unique(trimws(as.character(x[!is.na(x) & nzchar(as.character(x))])))
  if (length(x) == 1) x else NA_character_
}

# ---------------------------------------------------------------------------
# Identity resolution
#
# obs:     one row per unique (name_key, season, age) seen in the season
#          sources. `age_ref` says which date the age refers to: "feb" (the
#          stats file reports age on 1 February of the season's end year) or
#          "jul" (all_seasons reports age on 1 July). NA when no age is known.
# persons: one row per NBA person with name_key / name_key_stripped (and an
#          optional alt_key / alt_key_stripped for a second spelling),
#          birthdate (Date or NA), draft_year, from_year, to_year.
#
# Rules:
#  1. Candidates are persons whose key equals the observed key. If that
#     gives nothing (or a rejected single candidate), retry with the
#     suffix-stripped key ("Perry Jones" -> "Perry Jones III").
#  2. Several candidates: drop those whose career cannot cover the season
#     (first season or draft after it; last season long before it), then
#     those whose age does not fit (exact birthdate: within 1 year; only a
#     draft year known: within 4 years; nothing known: kept). If one
#     candidate is left, or exactly one has an exact age match, accept it.
#     Otherwise the unit is "ambiguous".
#  3. One candidate: accept unless the age clearly contradicts it (exact age
#     off by more than 5 years, draft-based age off by more than 8).
#  4. resolve_by_nearest_season() then settles units that stayed ambiguous
#     (typically salary rows without an age) by taking the candidate who was
#     identified for the same name in the closest season.
# ---------------------------------------------------------------------------
resolve_identity <- function(obs, persons, last_source_year) {
  key_rows <- c(seq_len(nrow(persons)), seq_len(nrow(persons)))
  idx_exact <- split(key_rows, c(persons$name_key, persons$alt_key))
  idx_strip <- split(key_rows, c(persons$name_key_stripped, persons$alt_key_stripped))
  idx_exact <- lapply(idx_exact, unique); idx_strip <- lapply(idx_strip, unique)

  # Age difference between the observed age and each candidate's expected
  # age; attribute "kind" says how reliable it is.
  age_diff <- function(cands, season, age, ref) {
    exp_exact <- rep(NA_real_, length(cands))
    bd <- persons$birthdate[cands]
    has_bd <- !is.na(bd)
    if (any(has_bd)) {
      ref_date <- as.Date(paste0(season, if (identical(ref, "jul")) "-07-01" else "-02-01"))
      exp_exact[has_bd] <- floor(as.numeric(ref_date - bd[has_bd]) / 365.25)
    }
    exp_est <- season - (persons$draft_year[cands] - 20)
    d <- ifelse(has_bd, age - exp_exact, age - exp_est)
    list(d = d, kind = ifelse(has_bd, "exact", ifelse(!is.na(d), "draft", "none")))
  }

  pick <- function(cands, season, age, ref) {
    if (!length(cands)) return(list(id = NA_character_, type = "no_match", n = 0L))
    n_start <- length(cands)
    start <- season - 1L
    if (length(cands) > 1) {
      fy <- persons$from_year[cands]; ty <- persons$to_year[cands]; dy <- persons$draft_year[cands]
      too_early <- (!is.na(fy) & start < fy) | (!is.na(dy) & start < dy)
      too_late  <- !is.na(ty) & start > ty & ty < last_source_year - 1
      keep <- !(too_early | too_late)
      if (any(keep)) cands <- cands[keep]
    }
    if (length(cands) > 1 && !is.na(age)) {
      a <- age_diff(cands, season, age, ref)
      keep <- (a$kind == "exact" & abs(a$d) <= 1) | (a$kind == "draft" & abs(a$d) <= 4) | a$kind == "none"
      if (any(keep)) { cands <- cands[keep]; a$d <- a$d[keep]; a$kind <- a$kind[keep] }
      if (length(cands) > 1) {
        best <- which(a$kind == "exact" & a$d == 0)
        if (length(best) == 1) cands <- cands[best]
      }
    }
    if (length(cands) > 1) return(list(id = NA_character_, type = "ambiguous", n = n_start))
    # Single candidate: reject only when the age clearly contradicts it.
    # (Career years are not used here: salary rows can precede a player's
    # first NBA game and follow the last one.)
    if (!is.na(age)) {
      a <- age_diff(cands, season, age, ref)
      if ((a$kind == "exact" && abs(a$d) > 5) || (a$kind == "draft" && abs(a$d) > 8))
        return(list(id = NA_character_, type = "age_conflict", n = n_start))
    }
    list(id = persons$playerID[cands],
         type = if (n_start > 1) "disambiguated" else "exact", n = n_start)
  }

  out_id <- character(nrow(obs)); out_type <- character(nrow(obs)); out_n <- integer(nrow(obs))
  for (i in seq_len(nrow(obs))) {
    r <- pick(idx_exact[[obs$name_key[i]]], obs$season[i], obs$age[i], obs$age_ref[i])
    if (is.na(r$id) && r$type != "ambiguous") {
      r2 <- pick(idx_strip[[obs$name_key_stripped[i]]], obs$season[i], obs$age[i], obs$age_ref[i])
      if (!is.na(r2$id) || (r$type == "no_match" && r2$type != "no_match")) {
        r2$type <- paste0("suffix_", r2$type); r <- r2
      }
    }
    out_id[i] <- r$id; out_type[i] <- r$type; out_n[i] <- r$n
  }
  obs$playerID <- out_id
  obs$match_type <- out_type
  obs$n_candidates <- out_n
  obs
}

# Second pass for units left "ambiguous": among the candidates for the name,
# take the one identified in the nearest season (at most `max_gap` seasons
# away) if that choice is unique. Everything else stays ambiguous.
resolve_by_nearest_season <- function(units, persons, max_gap = 3) {
  amb <- which(grepl("ambiguous", units$match_type))
  ok <- units[!is.na(units$playerID), c("playerID", "season")]
  for (i in amb) {
    cands <- persons$playerID[persons$name_key_stripped == units$name_key_stripped[i] |
                              persons$alt_key_stripped == units$name_key_stripped[i]]
    gap <- vapply(cands, function(id) {
      s <- ok$season[ok$playerID == id]
      if (length(s)) min(abs(s - units$season[i])) else Inf
    }, numeric(1))
    best <- which(gap == min(gap) & gap <= max_gap)
    if (length(best) == 1) {
      units$playerID[i] <- cands[best]
      units$match_type[i] <- "nearest_season"
    }
  }
  units
}
