# Analysis of NBA families: size, earnings, fathers vs sons, brothers, height.
# Family-level results are shown as figures; the paired and group comparisons
# are reported as tables (results/analysis/*.csv).
#
# Reads data/output_data/*.csv (built by scripts/01_build_player_data.R) and
# writes figures to results/figures/ and tables to results/analysis/.
# Run from the project root:  Rscript scripts/02_analysis.R
# Everything is also available as objects after source("scripts/02_analysis.R").

suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(ggplot2); library(scales)
})
options(dplyr.summarise.inform = FALSE)
dir.create("results/figures", showWarnings = FALSE, recursive = TRUE)
dir.create("results/analysis", showWarnings = FALSE, recursive = TRUE)

bio       <- read.csv("data/output_data/player_bio.csv", stringsAsFactors = FALSE)
seasons   <- read.csv("data/output_data/player_seasons.csv", stringsAsFactors = FALSE)
relations <- read.csv("data/output_data/family_relations.csv", stringsAsFactors = FALSE)

# ---------------------------------------------------------------------------
# Plot style: one palette, fixed roles, recessive grid.
# ---------------------------------------------------------------------------
col_family  <- "#2a78d6"   # players with NBA family / sons / younger
col_other   <- "#9a9a94"   # comparison group
theme_set(theme_minimal(base_size = 12) +
            theme(panel.grid.minor = element_blank(),
                  panel.grid.major.x = element_blank(),
                  panel.grid.major = element_line(colour = "grey90"),
                  plot.title.position = "plot",
                  plot.title = element_text(face = "bold"),
                  legend.position = "top"))
save_fig <- function(p, name, w = 8, h = 5) {
  ggsave(file.path("results/figures", paste0(name, ".png")), p, width = w, height = h, dpi = 150, bg = "white")
  invisible(p)
}
save_tbl <- function(x, name) {
  write.csv(x, file.path("results/analysis", paste0(name, ".csv")), row.names = FALSE)
  invisible(x)
}
musd <- function(x) paste0("$", format(round(x / 1e6), big.mark = ","), "M")

# ---------------------------------------------------------------------------
# 1. Career table: one row per player with season data (1997-2025)
# ---------------------------------------------------------------------------
wmean <- function(x, w) if (all(is.na(x))) NA_real_ else weighted.mean(x, w, na.rm = TRUE)
stat_cols <- c("pts_pg", "reb_pg", "ast_pg", "stl_pg", "blk_pg", "tov_pg", "minutes_pg",
               "fg_pct", "fg3_pct", "ft_pct", "ts_pct", "usg_pct", "net_rating")
career <- seasons %>%
  mutate(games_played = coalesce(games_played, 0)) %>%
  group_by(playerID) %>%
  summarise(
    first_season = min(season), last_season = max(season),
    n_seasons = n_distinct(season),
    seasons_with_stats = sum(!is.na(pts_pg)),
    games_total = sum(games_played),
    games_per_season = games_total / n_seasons,
    across(all_of(stat_cols), ~ wmean(.x, pmax(games_played, 1))),
    salary_total = if (all(is.na(salary))) NA_real_ else sum(salary, na.rm = TRUE),
    salary_seasons = sum(!is.na(salary)),
    salary_per_season = salary_total / pmax(salary_seasons, 1) / 1e6,   # in million USD
    height_season = suppressWarnings(max(height_cm, na.rm = TRUE))
  ) %>%
  mutate(height_season = ifelse(is.finite(height_season), height_season, NA_real_)) %>%
  left_join(bio %>% select(playerID, full_name, birth_year, height_cm, familyID,
                           father_dummy, son_dummy, brother_dummy, id_match = id_source),
            by = "playerID") %>%
  mutate(height = coalesce(height_cm, height_season),
         nba_family = familyID > 0)
stat_labels <- c(pts_pg = "Points per game", reb_pg = "Rebounds per game", ast_pg = "Assists per game",
                 stl_pg = "Steals per game", blk_pg = "Blocks per game", tov_pg = "Turnovers per game",
                 minutes_pg = "Minutes per game", fg_pct = "Field goal %", fg3_pct = "Three-point %",
                 ft_pct = "Free throw %", ts_pct = "True shooting %", usg_pct = "Usage %",
                 net_rating = "Net rating", games_per_season = "Games per season",
                 n_seasons = "Seasons in data", salary_per_season = "Salary per season ($M)",
                 height = "Height (cm)")

# ---------------------------------------------------------------------------
# 2. Families: size, total earnings, development over time
# ---------------------------------------------------------------------------
family_members <- bio %>% filter(familyID > 0) %>%
  left_join(career %>% select(playerID, n_seasons, salary_total, first_season, last_season), by = "playerID")
families <- family_members %>%
  group_by(familyID) %>%
  summarise(
    family_name = { ln <- names(sort(table(last_name), decreasing = TRUE)); ln[1] },
    members = paste(full_name, collapse = ", "),
    n_members = n(),
    n_with_data = sum(!is.na(n_seasons)),
    family_salary = sum(salary_total, na.rm = TRUE),
    top_earner = ifelse(all(is.na(salary_total)), NA_character_, full_name[which.max(coalesce(salary_total, 0))]),
    top_earner_share = ifelse(family_salary > 0, max(coalesce(salary_total, 0)) / family_salary, NA_real_),
    first_season = suppressWarnings(min(first_season, na.rm = TRUE)),
    last_season = suppressWarnings(max(last_season, na.rm = TRUE))
  ) %>% rename(salary_total = family_salary) %>% arrange(desc(salary_total))
save_tbl(families, "families")

# Largest families (by members in the family lists).
fig_family_size <- families %>%
  filter(n_members >= 3) %>%
  arrange(n_members, family_name) %>%
  mutate(label = paste0(family_name, " (", n_members, ")"),
         label = factor(label, levels = label)) %>%
  ggplot(aes(x = n_members, y = label)) +
  geom_col(fill = col_family, width = 0.7) +
  geom_text(aes(label = members), hjust = 0, nudge_x = 0.05, size = 3, colour = "grey30") +
  scale_x_continuous(expand = expansion(mult = c(0, 1.6)), breaks = 0:5) +
  labs(title = "Largest NBA families (three or more players)",
       x = "Players in the family", y = NULL) +
  theme(panel.grid.major.y = element_blank())
save_fig(fig_family_size, "fig01_family_size", 9, 5)

# Highest-earning families, with the top earner's share.
top_fam <- families %>% slice_max(salary_total, n = 12) %>%
  mutate(family_name = factor(family_name, levels = rev(family_name)))
fig_family_salary <- ggplot(top_fam, aes(x = salary_total, y = family_name)) +
  geom_col(fill = col_other, width = 0.7) +
  geom_col(aes(x = salary_total * top_earner_share), fill = col_family, width = 0.7) +
  geom_text(aes(label = paste0(musd(salary_total), "  (", top_earner, " ", percent(top_earner_share, 1), ")")),
            hjust = 0, nudge_x = 5e6, size = 3, colour = "grey30") +
  scale_x_continuous(labels = label_dollar(scale = 1e-6, suffix = "M"),
                     expand = expansion(mult = c(0, 0.6))) +
  labs(title = "Highest-earning NBA families, salaries 2000-2025",
       subtitle = "Blue = the family's top earner, grey = the rest of the family",
       x = "Total salary", y = NULL) +
  theme(panel.grid.major.y = element_blank())
save_fig(fig_family_salary, "fig02_family_salary", 9, 5.5)

# Cumulative family earnings over time for the top six families.
top6 <- families %>% slice_max(salary_total, n = 6)
fam_time <- seasons %>%
  inner_join(bio %>% select(playerID, familyID), by = "playerID") %>%
  filter(familyID %in% top6$familyID, !is.na(salary)) %>%
  group_by(familyID, season) %>% summarise(salary = sum(salary)) %>%
  group_by(familyID) %>% arrange(season) %>% mutate(cum_salary = cumsum(salary)) %>% ungroup() %>%
  left_join(top6 %>% select(familyID, family_name), by = "familyID")
fam_cols <- setNames(c("#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4", "#6250d6"),
                     top6$family_name)
fig_family_time <- ggplot(fam_time, aes(season, cum_salary, colour = family_name)) +
  geom_line(linewidth = 1) +
  geom_text(data = fam_time %>% group_by(family_name) %>% slice_max(season, n = 1),
            aes(label = family_name), hjust = 0, nudge_x = 0.3, size = 3.2, show.legend = FALSE) +
  scale_colour_manual(values = fam_cols) +
  scale_y_continuous(labels = label_dollar(scale = 1e-6, suffix = "M")) +
  scale_x_continuous(breaks = seq(2000, 2025, 5), expand = expansion(mult = c(0.02, 0.15))) +
  labs(title = "Cumulative salary of the six highest-earning families",
       x = "Season (end year)", y = "Cumulative salary", colour = NULL)
save_fig(fig_family_time, "fig03_family_cumulative", 9, 5)

# Individuals versus families.
top_players <- career %>% filter(!is.na(salary_total)) %>%
  slice_max(salary_total, n = 10) %>%
  select(full_name, salary_total, salary_seasons, nba_family)
save_tbl(top_players, "top_earning_players")
entities <- bind_rows(
  top_players %>% transmute(name = full_name, type = "Single player", salary_total),
  families %>% slice_max(salary_total, n = 10) %>% transmute(name = paste(family_name, "family"), type = "Family", salary_total)
) %>% slice_max(salary_total, n = 15) %>% arrange(salary_total) %>%
  mutate(name = factor(name, levels = name))
fig_entities <- ggplot(entities, aes(salary_total, name, fill = type)) +
  geom_col(width = 0.7) +
  geom_text(aes(label = musd(salary_total)), hjust = 0, nudge_x = 5e6, size = 3, colour = "grey30") +
  scale_fill_manual(values = c("Single player" = col_other, "Family" = col_family)) +
  scale_x_continuous(labels = label_dollar(scale = 1e-6, suffix = "M"), expand = expansion(mult = c(0, 0.2))) +
  labs(title = "Top earners 2000-2025: single players and families side by side",
       x = "Total salary", y = NULL, fill = NULL) +
  theme(panel.grid.major.y = element_blank())
save_fig(fig_entities, "fig04_players_vs_families", 9, 5.5)

# Family presence over time: share of players each season with NBA family.
fam_share <- seasons %>%
  left_join(bio %>% select(playerID, familyID), by = "playerID") %>%
  group_by(season) %>%
  summarise(players = n(), with_family = sum(familyID > 0), share = with_family / players)
fig_fam_share <- ggplot(fam_share, aes(season, share)) +
  geom_line(colour = col_family, linewidth = 1) +
  geom_point(colour = col_family, size = 1.8) +
  scale_y_continuous(labels = label_percent(accuracy = 1), limits = c(0, NA)) +
  labs(title = "Share of players each season with an NBA father, son or brother",
       x = "Season (end year)", y = "Share of players")
save_fig(fig_fam_share, "fig05_family_share_over_time", 8, 4.5)
save_tbl(fam_share, "family_share_by_season")

# ---------------------------------------------------------------------------
# 3. Paired comparisons: a helper used for fathers vs sons and older vs younger
# ---------------------------------------------------------------------------
pair_stats <- c("pts_pg", "reb_pg", "ast_pg", "minutes_pg", "games_per_season", "n_seasons",
                "ts_pct", "net_rating", "salary_per_season")
# One row per pair and stat, with values for person a and b.
pair_long <- function(pairs, a_label, b_label) {
  pairs %>%
    inner_join(career %>% select(playerID, all_of(pair_stats)) %>% rename_with(~ paste0("a_", .x), -playerID),
               by = c("a" = "playerID")) %>%
    inner_join(career %>% select(playerID, all_of(pair_stats)) %>% rename_with(~ paste0("b_", .x), -playerID),
               by = c("b" = "playerID")) %>%
    pivot_longer(c(starts_with("a_"), starts_with("b_")), names_to = c("who", "stat"),
                 names_pattern = "^(a|b)_(.*)$") %>%
    mutate(who = ifelse(who == "a", a_label, b_label)) %>%
    pivot_wider(names_from = who, values_from = value)
}
# Paired summary per stat: mean difference b - a, paired t-test, Wilcoxon.
pair_summary <- function(long, a_label, b_label) {
  long %>% group_by(stat) %>%
    summarise(
      n_pairs = sum(!is.na(.data[[a_label]]) & !is.na(.data[[b_label]])),
      mean_a = mean(.data[[a_label]], na.rm = TRUE),
      mean_b = mean(.data[[b_label]], na.rm = TRUE),
      mean_diff = mean(.data[[b_label]] - .data[[a_label]], na.rm = TRUE),
      share_b_higher = mean(.data[[b_label]] > .data[[a_label]], na.rm = TRUE),
      p_paired_t = tryCatch(t.test(.data[[b_label]], .data[[a_label]], paired = TRUE)$p.value, error = function(e) NA_real_),
      p_wilcoxon = tryCatch(suppressWarnings(wilcox.test(.data[[b_label]], .data[[a_label]], paired = TRUE)$p.value), error = function(e) NA_real_)
    ) %>%
    rename(!!paste0("mean_", a_label) := mean_a, !!paste0("mean_", b_label) := mean_b) %>%
    mutate(stat = factor(stat, levels = pair_stats)) %>% arrange(stat)
}
# ---------------------------------------------------------------------------
# 4. Fathers versus sons (pairs where both have season data)
# ---------------------------------------------------------------------------
fs_pairs <- relations %>% filter(relation_type == "father_son") %>%
  transmute(a = person1_playerID, b = person2_playerID, father = person1_full_name, son = person2_full_name)
fs_long <- pair_long(fs_pairs, "Father", "Son")
fs_summary <- pair_summary(fs_long, "Father", "Son")
save_tbl(fs_summary, "father_vs_son_paired")
save_tbl(fs_long %>% filter(stat == "pts_pg") %>% select(father, son, Father, Son), "father_vs_son_pairs_pts")
# Unpaired version: every father with data versus every son with data.
fs_groups <- career %>%
  filter(father_dummy == 1 | son_dummy == 1, seasons_with_stats > 0) %>%
  mutate(role = case_when(father_dummy == 1 & son_dummy == 1 ~ "Both", father_dummy == 1 ~ "Father", TRUE ~ "Son")) %>%
  filter(role != "Both")
fs_unpaired <- fs_groups %>% group_by(role) %>%
  summarise(n = n(), across(c(pts_pg, reb_pg, ast_pg, minutes_pg, n_seasons, ts_pct, net_rating), ~ mean(.x, na.rm = TRUE)))
save_tbl(fs_unpaired, "father_vs_son_unpaired")

# ---------------------------------------------------------------------------
# 5. Brothers versus everyone else, and NBA family versus no NBA family
# ---------------------------------------------------------------------------
group_stats <- c("pts_pg", "reb_pg", "ast_pg", "stl_pg", "blk_pg", "tov_pg", "minutes_pg",
                 "games_per_season", "n_seasons", "fg_pct", "fg3_pct", "ft_pct", "ts_pct",
                 "usg_pct", "net_rating", "salary_per_season", "height")
# Standardised mean difference (Cohen's d) with a bootstrap 95% interval.
cohens_d <- function(x, g, B = 1000, seed = 4170) {
  ok <- !is.na(x) & !is.na(g); x <- x[ok]; g <- g[ok]
  d_of <- function(x, g) {
    a <- x[g]; b <- x[!g]
    (mean(a) - mean(b)) / sqrt(((length(a) - 1) * var(a) + (length(b) - 1) * var(b)) / (length(a) + length(b) - 2))
  }
  set.seed(seed)
  boot <- replicate(B, { i <- sample(length(x), replace = TRUE); d_of(x[i], g[i]) })
  c(d = d_of(x, g), lo = unname(quantile(boot, 0.025)), hi = unname(quantile(boot, 0.975)),
    n_group = sum(g), n_other = sum(!g), mean_group = mean(x[g]), mean_other = mean(x[!g]))
}
effect_table <- function(data, flag, flag_label) {
  bind_rows(lapply(group_stats, function(s) {
    r <- cohens_d(data[[s]], data[[flag]])
    data.frame(stat = s, label = stat_labels[[s]], t(r))
  })) %>% mutate(group = flag_label)
}
min_games <- 20   # players with fewer career games have noisy per-game averages
players <- career %>% filter(seasons_with_stats > 0, games_total >= min_games) %>%
  mutate(is_brother = brother_dummy == 1, has_family = nba_family)
eff_brothers <- effect_table(players, "is_brother", "Brothers vs other players")
eff_family   <- effect_table(players, "has_family", "NBA family vs no NBA family")
effects <- bind_rows(eff_brothers, eff_family)
save_tbl(effects, "effect_sizes")

# ---------------------------------------------------------------------------
# 6. Older versus younger brothers (pairs with birth years and data for both)
# ---------------------------------------------------------------------------
sib_pairs <- relations %>% filter(relation_type == "sibling") %>%
  transmute(p1 = person1_playerID, p2 = person2_playerID) %>%
  mutate(by1 = bio$birth_year[match(p1, bio$playerID)], by2 = bio$birth_year[match(p2, bio$playerID)]) %>%
  filter(!is.na(by1), !is.na(by2), by1 != by2) %>%             # same year = twins or unknown order
  transmute(a = ifelse(by1 < by2, p1, p2), b = ifelse(by1 < by2, p2, p1),
            older = bio$full_name[match(a, bio$playerID)], younger = bio$full_name[match(b, bio$playerID)],
            age_gap = abs(by1 - by2))
sib_long <- pair_long(sib_pairs, "Older", "Younger")
sib_summary <- pair_summary(sib_long, "Older", "Younger")
save_tbl(sib_summary, "older_vs_younger_paired")
save_tbl(sib_long %>% filter(stat == "pts_pg") %>% select(older, younger, age_gap, Older, Younger), "older_vs_younger_pairs_pts")
# ---------------------------------------------------------------------------
# 7. Height: are sons taller than their fathers?
# ---------------------------------------------------------------------------
heights <- fs_pairs %>%
  mutate(h_father = career$height[match(a, career$playerID)], h_son = career$height[match(b, career$playerID)],
         h_father = coalesce(h_father, bio$height_cm[match(a, bio$playerID)]),
         h_son = coalesce(h_son, bio$height_cm[match(b, bio$playerID)]),
         start_father = bio$career_start[match(a, bio$playerID)],
         start_son = bio$career_start[match(b, bio$playerID)]) %>%
  filter(!is.na(h_father), !is.na(h_son)) %>%
  mutate(diff = h_son - h_father)
# Benchmark: league mean height by debut decade, so the generational trend can be separated out.
league_height <- bio %>% filter(!is.na(height_cm), !is.na(career_start)) %>%
  mutate(decade = floor(career_start / 10) * 10) %>%
  group_by(decade) %>% summarise(league_mean = mean(height_cm), n = n())
heights <- heights %>%
  mutate(league_father = league_height$league_mean[match(floor(start_father / 10) * 10, league_height$decade)],
         league_son = league_height$league_mean[match(floor(start_son / 10) * 10, league_height$decade)],
         diff_vs_league = (h_son - league_son) - (h_father - league_father))
height_summary <- data.frame(
  n_pairs = nrow(heights),
  mean_father = mean(heights$h_father), mean_son = mean(heights$h_son),
  mean_diff = mean(heights$diff), share_son_taller = mean(heights$diff > 0),
  p_paired_t = t.test(heights$h_son, heights$h_father, paired = TRUE)$p.value,
  mean_diff_vs_league = mean(heights$diff_vs_league, na.rm = TRUE),
  p_vs_league = t.test(heights$diff_vs_league)$p.value)
save_tbl(height_summary, "height_father_vs_son")
save_tbl(league_height, "league_height_by_decade")
save_tbl(heights %>% select(father, son, h_father, h_son, diff), "height_pairs")
fig_league_height <- ggplot(league_height %>% filter(decade >= 1950), aes(decade, league_mean)) +
  geom_line(colour = col_other) + geom_point(colour = col_family, size = 2.5) +
  labs(title = "Mean height of NBA players by debut decade", x = "Debut decade", y = "Mean height (cm)") +
  theme(panel.grid.major.x = element_line(colour = "grey90"))
save_fig(fig_league_height, "fig06_league_height", 7, 4)

# ---------------------------------------------------------------------------
# 8a. Career-level regression: son / brother differences, all else equal
#
# y = b0 + b1*son + b2*brother + height + debut decade + position + e
# Standard errors are clustered on familyID (players without family are their
# own cluster), because relatives are not independent observations. The
# coefficients describe differences among players who reached the NBA; they
# are not causal effects of having NBA family (survivorship/selection).
# ---------------------------------------------------------------------------
primary_position <- seasons %>% filter(!is.na(position)) %>%
  mutate(position = sub("-.*", "", position)) %>%
  count(playerID, position) %>% group_by(playerID) %>% slice_max(n, n = 1, with_ties = FALSE) %>%
  select(playerID, position)
reg_data <- players %>%
  left_join(primary_position, by = "playerID") %>%
  mutate(son = as.integer(son_dummy == 1), brother = as.integer(brother_dummy == 1),
         debut_decade = factor(floor(first_season / 10) * 10),
         position = factor(coalesce(position, "Unknown")),
         cluster = ifelse(familyID > 0, paste0("f", familyID), playerID)) %>%
  filter(!is.na(height))

# Cluster-robust (CR1) covariance for an lm fit.
cluster_vcov <- function(fit, cluster) {
  X <- model.matrix(fit); e <- residuals(fit)
  cluster <- cluster[as.integer(rownames(X))]
  G <- length(unique(cluster)); n <- nrow(X); k <- ncol(X)
  meat <- Reduce(`+`, lapply(split(seq_len(n), cluster), function(i) {
    u <- crossprod(X[i, , drop = FALSE], e[i]); u %*% t(u) }))
  bread <- solve(crossprod(X))
  (G / (G - 1)) * ((n - 1) / (n - k)) * bread %*% meat %*% bread
}
run_reg <- function(outcome) {
  f <- as.formula(paste(outcome, "~ son + brother + height + debut_decade + position"))
  fit <- lm(f, data = reg_data)
  V <- cluster_vcov(fit, reg_data$cluster)
  se <- sqrt(diag(V))
  data.frame(outcome = outcome, term = names(coef(fit)), estimate = coef(fit), se_cluster = se,
             t = coef(fit) / se, p = 2 * pt(-abs(coef(fit) / se), df = fit$df.residual),
             n = nobs(fit), r_squared = summary(fit)$r.squared, row.names = NULL)
}
reg_outcomes <- c("pts_pg", "ast_pg", "reb_pg", "minutes_pg", "n_seasons", "salary_per_season", "ts_pct", "net_rating")
regressions <- bind_rows(lapply(reg_outcomes, run_reg))
save_tbl(regressions, "regression_all_terms")
reg_summary <- regressions %>% filter(term %in% c("son", "brother")) %>%
  mutate(outcome = stat_labels[outcome],
         mean_other = sapply(reg_outcomes, function(o) mean(reg_data[[o]][reg_data$son == 0 & reg_data$brother == 0], na.rm = TRUE))[match(outcome, stat_labels[reg_outcomes])]) %>%
  select(outcome, term, estimate, se_cluster, p, n, mean_other)
save_tbl(reg_summary, "regression_son_brother")

# Twins: too few pairs for a model; listed descriptively.
twin_pairs <- relations %>% filter(relation_type == "sibling") %>%
  mutate(bd1 = bio$birthdate[match(person1_playerID, bio$playerID)],
         bd2 = bio$birthdate[match(person2_playerID, bio$playerID)]) %>%
  filter(!is.na(bd1), !is.na(bd2), nzchar(bd1), bd1 == bd2) %>%
  transmute(twin_1 = person1_full_name, twin_2 = person2_full_name, birthdate = bd1,
            pts_1 = career$pts_pg[match(person1_playerID, career$playerID)],
            pts_2 = career$pts_pg[match(person2_playerID, career$playerID)],
            seasons_1 = career$n_seasons[match(person1_playerID, career$playerID)],
            seasons_2 = career$n_seasons[match(person2_playerID, career$playerID)])
save_tbl(twin_pairs, "twins")

# ---------------------------------------------------------------------------
# 8b. Panel regression with season fixed effects
#
# Same question on the player-season panel: one row per player and season,
# a dummy for every season (so league-wide changes in scoring, three-point
# shooting and salary levels are held fixed), plus age, height and position.
# Player fixed effects would absorb son/brother (they never change within a
# player), so season fixed effects are the right choice here. Standard errors
# are clustered on family (players without family are their own cluster).
# ---------------------------------------------------------------------------
min_games_season <- 10
panel <- seasons %>%
  filter(in_stats == 1, !is.na(games_played), games_played >= min_games_season) %>%
  left_join(bio %>% select(playerID, familyID, son_dummy, brother_dummy), by = "playerID") %>%
  left_join(career %>% select(playerID, first_season, height), by = "playerID") %>%
  left_join(bio %>% select(playerID, career_start), by = "playerID") %>%
  mutate(son = as.integer(son_dummy == 1), brother = as.integer(brother_dummy == 1),
         nba_family = familyID > 0,
         # Seasons since the NBA debut. career_start (register) is the start year of
         # the first season, also before 1997; players outside the register fall
         # back to their first season in the data.
         experience = (season - 1) - coalesce(career_start, first_season - 1),
         position = factor(coalesce(sub("-.*", "", position), "Unknown")),
         season_f = factor(season),
         cluster = ifelse(familyID > 0, paste0("f", familyID), playerID),
         log_salary = ifelse(!is.na(salary) & salary > 0, log(salary), NA_real_))

# Fit an lm on complete cases and return coefficients with clustered SE.
fit_clustered <- function(formula, data, cluster_var = "cluster") {
  vars <- all.vars(formula)
  d <- data[complete.cases(data[, vars]), ]
  d <- as.data.frame(d); rownames(d) <- NULL
  fit <- lm(formula, data = d)
  V <- cluster_vcov(fit, d[[cluster_var]])
  se <- sqrt(diag(V))
  list(fit = fit, data = d,
       table = data.frame(term = names(coef(fit)), estimate = coef(fit), se_cluster = se,
                          t = coef(fit) / se, p = 2 * pt(-abs(coef(fit) / se), df = fit$df.residual),
                          n = nobs(fit), n_clusters = length(unique(d[[cluster_var]])),
                          r_squared = summary(fit)$r.squared, row.names = NULL))
}
panel_outcomes <- c("pts_pg", "ast_pg", "reb_pg", "minutes_pg", "ts_pct", "net_rating", "log_salary")
panel_labels <- c(stat_labels, log_salary = "Log salary")
panel_regressions <- bind_rows(lapply(panel_outcomes, function(y) {
  f <- as.formula(paste(y, "~ son + brother + height + age + I(age^2) + position + season_f"))
  r <- fit_clustered(f, panel)
  r$table %>% mutate(outcome = y, n_players = n_distinct(r$data$playerID),
                     mean_other = mean(r$data[[y]][r$data$son == 0 & r$data$brother == 0]))
}))
save_tbl(panel_regressions, "regression_panel_all_terms")
panel_summary <- panel_regressions %>% filter(term %in% c("son", "brother")) %>%
  mutate(outcome = panel_labels[outcome]) %>%
  select(outcome, term, estimate, se_cluster, p, n, n_players, mean_other)
save_tbl(panel_summary, "regression_panel_son_brother")

# ---------------------------------------------------------------------------
# 9. Over- and underpaid players: salary given performance
#
# Step 1: predict log salary from the season's box score, age, experience
# (seasons since NBA debut), position and season (a dummy per season).
# Experience and age are in because
# the NBA pay scale depends on them by rule (rookie-scale and maximum
# contracts), not only on performance.
# Step 2: the residual is how much more (+) or less (-) a player earned than
# players with the same numbers. Averaged per player it ranks over- and
# underpaid careers.
# Step 3: add the family dummies to the same model to get the family pay
# premium given performance. This is in-sample description, and a contract
# is signed before the seasons it pays for, so part of a residual is timing.
# ---------------------------------------------------------------------------
pay_formula <- log_salary ~ pts_pg + reb_pg + ast_pg + stl_pg + blk_pg + tov_pg +
  minutes_pg + games_played + age + I(age^2) + experience + I(experience^2) +
  position + season_f
pay_fit <- fit_clustered(pay_formula, panel)
pay <- pay_fit$data %>%
  mutate(predicted_salary = exp(fitted(pay_fit$fit)),
         residual = residuals(pay_fit$fit),       # log points: 0.69 = earned twice the prediction
         ratio = salary / predicted_salary)
save_tbl(pay_fit$table %>% filter(!grepl("^season_f", term)), "salary_model_terms")
save_tbl(data.frame(metric = c("n_player_seasons", "n_players", "r_squared", "rmse_log"),
                    value = c(nobs(pay_fit$fit), n_distinct(pay$playerID),
                              summary(pay_fit$fit)$r.squared, sqrt(mean(pay$residual^2)))),
         "salary_model_fit")

# Most over- and underpaid player-seasons.
pay_seasons <- pay %>%
  transmute(full_name, season, team_abbreviation, age, pts_pg, reb_pg, ast_pg, minutes_pg,
            salary, predicted_salary, ratio, residual, nba_family)
save_tbl(pay_seasons %>% slice_max(residual, n = 15), "overpaid_seasons")
save_tbl(pay_seasons %>% slice_min(residual, n = 15), "underpaid_seasons")

# Careers: mean residual over at least five paid seasons.
pay_careers <- pay %>%
  group_by(playerID, full_name, nba_family) %>%
  summarise(seasons = n(), salary_total = sum(salary), predicted_total = sum(predicted_salary),
            mean_residual = mean(residual), ratio = salary_total / predicted_total) %>%
  ungroup() %>% filter(seasons >= 5)
save_tbl(pay_careers %>% arrange(desc(mean_residual)), "salary_residuals_careers")
top_pay <- bind_rows(
  pay_careers %>% slice_max(mean_residual, n = 10) %>% mutate(group = "Overpaid"),
  pay_careers %>% slice_min(mean_residual, n = 10) %>% mutate(group = "Underpaid")) %>%
  mutate(pct = ratio - 1) %>%
  arrange(pct) %>%
  mutate(label = ifelse(nba_family, paste0(full_name, " *"), full_name),
         label = factor(label, levels = label))
fig_pay <- ggplot(top_pay, aes(x = pct, y = label, fill = group)) +
  geom_col(width = 0.7) +
  geom_text(aes(label = percent(pct, 1), hjust = ifelse(pct > 0, -0.15, 1.15)), size = 3, colour = "grey30") +
  scale_fill_manual(values = c("Overpaid" = col_family, "Underpaid" = col_other)) +
  scale_x_continuous(labels = label_percent(), expand = expansion(mult = 0.25)) +
  labs(title = "Most over- and underpaid careers, salary relative to performance",
       subtitle = "Career salary versus the model's prediction from box score, age, experience, position\nand season. At least five paid seasons. * = player with NBA family",
       x = "Salary relative to prediction", y = NULL, fill = NULL) +
  theme(panel.grid.major.y = element_blank(), panel.grid.major.x = element_line(colour = "grey90"))
save_fig(fig_pay, "fig07_salary_over_underpaid", 9, 7)

# Family pay premium: same model plus the family dummies.
premium_fit <- fit_clustered(update(pay_formula, . ~ . + son + brother), panel)
premium <- premium_fit$table %>% filter(term %in% c("son", "brother")) %>%
  mutate(premium_pct = exp(estimate) - 1,
         lo_pct = exp(estimate - 1.96 * se_cluster) - 1, hi_pct = exp(estimate + 1.96 * se_cluster) - 1)
save_tbl(premium, "salary_premium_family")
# Mean residual by group, with a cluster-robust interval from a regression on group dummies.
resid_groups <- bind_rows(
  fit_clustered(residual ~ 1, pay %>% filter(!nba_family))$table %>% mutate(group = "No NBA family"),
  fit_clustered(residual ~ 1, pay %>% filter(son == 1))$table %>% mutate(group = "Sons"),
  fit_clustered(residual ~ 1, pay %>% filter(brother == 1))$table %>% mutate(group = "Brothers"),
  fit_clustered(residual ~ 1, pay %>% filter(nba_family))$table %>% mutate(group = "Any NBA family")) %>%
  transmute(group, mean_residual = estimate, se_cluster, n, n_clusters,
            pct = exp(estimate) - 1, lo = exp(estimate - 1.96 * se_cluster) - 1, hi = exp(estimate + 1.96 * se_cluster) - 1)
save_tbl(resid_groups, "salary_residual_by_group")
fig_pay_family <- resid_groups %>%
  mutate(group = factor(group, levels = rev(c("No NBA family", "Any NBA family", "Sons", "Brothers")))) %>%
  ggplot(aes(x = pct, y = group)) +
  geom_vline(xintercept = 0, colour = "grey60") +
  geom_errorbar(aes(xmin = lo, xmax = hi), width = 0, colour = "grey55", orientation = "y") +
  geom_point(aes(colour = group == "No NBA family"), size = 3) +
  scale_colour_manual(values = c(`TRUE` = col_other, `FALSE` = col_family), guide = "none") +
  scale_x_continuous(labels = label_percent(), expand = expansion(mult = 0.1)) +
  labs(title = "Salary relative to performance, by family group",
       subtitle = "Mean residual from the salary model (player-seasons, 2000-2025) with cluster-robust 95% interval",
       x = "Salary relative to prediction", y = NULL) +
  theme(panel.grid.major.y = element_blank(), panel.grid.major.x = element_line(colour = "grey90"))
save_fig(fig_pay_family, "fig08_salary_residual_family", 8, 4)

# ---------------------------------------------------------------------------
# 10. Known-answer checks, so the reader can see the data behave as expected
# ---------------------------------------------------------------------------
checks <- list(
  lebron_salary = career$salary_total[career$full_name == "LeBron James"],
  lebron_seasons_with_salary = career$salary_seasons[career$full_name == "LeBron James"],
  curry_family = families$members[grepl("Stephen Curry", families$members)],
  james_family_total = families$salary_total[grepl("LeBron James", families$members)],
  lebron_share_of_james_family = families$top_earner_share[grepl("LeBron James", families$members)],
  dunleavy_father_son = relations %>% filter(grepl("Dunleavy", person1_full_name)) %>% select(person1_full_name, person2_full_name, relation_type),
  n_players_with_data = nrow(players),
  n_families = nrow(families)
)
save_tbl(data.frame(check = c("LeBron James total salary 2000-2025 in data", "LeBron seasons with salary",
                              "Curry family members", "James family total salary", "LeBron share of James family",
                              "Players with stats", "Families"),
                    value = c(musd(checks$lebron_salary), checks$lebron_seasons_with_salary, checks$curry_family,
                              musd(checks$james_family_total), percent(checks$lebron_share_of_james_family, 1),
                              checks$n_players_with_data, checks$n_families)), "known_answer_checks")

cat("Families:", nrow(families), " | players with stats:", nrow(players),
    " | father-son pairs with data:", n_distinct(fs_long$a),
    " | sibling pairs with data:", n_distinct(sib_long$a), " | height pairs:", nrow(heights), "\n")
cat("Figures written to results/figures, tables to results/analysis\n")
