######################################################################
### B4_validate_contributions.R
######################################################################

#' This file reproduces the preparation of the dataset B4 and introduces
#' some measures for robustness as explicited in B3_notes / N3_notes

# preparation ------------------------------------------------------------

library(duckdb)
library(arrow)
library(dplyr)
library(glue)
library(xtable)


# use a persistent duckdb file so internal state spills to disk, not RAM
if(!dir.exists("tmp")){
  dir.create("tmp", recursive = TRUE, showWarnings = FALSE)
}
con <- dbConnect(duckdb("tmp/convert.duckdb"))


# set memory usage to 4GB max so it doesn't break

# dbExecute(con, "SET max_temp_directory_size = '200GB'")

dbExecute(con, "SET memory_limit = '16GB'")
dbExecute(con, "SET preserve_insertion_order = false")
dbExecute(con, "SET threads = 4")

target_cycles <- c(2016, 2020, 2024)
needed <- sort(unique(c(target_cycles, target_cycles - 2)))
final_root <- "data/raw/raw_contributions_parquet"

# import the files

stopifnot(is.logical(run_on_sample), length(run_on_sample) == 1, !is.na(run_on_sample))

cols_to_keep <- c(
  "bonica.cid", "bonica.rid", "cycle", "transaction.id", "transaction.type",
  "amount", "contributor.type", "contributor.employer", "contributor.occupation",
  "contributor.city", "contributor.zipcode", "contributor.cfscore",
  "candidate.cfscore", "contributor.gender"
)

col_list <- paste(DBI::dbQuoteIdentifier(con, cols_to_keep), collapse = ", ")

dbExecute(con, glue("
  CREATE OR REPLACE VIEW contribs_raw AS
  SELECT {col_list}
  FROM read_parquet('{final_root}/**/*.parquet',
                    hive_partitioning = true,
                    hive_types = {{'cycle': 'BIGINT'}})"))

dbGetQuery(con, "DESCRIBE contribs_raw")

DIME_contributions <- tbl(con, "contribs_raw") |>
  filter(cycle %in% !!needed)

if (run_on_sample) {
  
  sample_ids <- tbl(con, "contribs_raw") |>
    filter(cycle %in% !!needed) |>
    distinct(bonica.cid) |>
    slice_sample(n = 5000) |>
    compute()

  DIME_contributions <- tbl(con, "contribs_raw") |>
    filter(cycle %in% !!needed) |>
    semi_join(sample_ids, by = "bonica.cid") |> 
    compute()

}

# filter -----------------------------------------------------------------

DIME_contributions <- DIME_contributions |>
    filter(
        contributor.type == "I"
    )

# firms and industries ---------------------------------------------------

#' Robustness: 
#' Reports the rates of false positives and false negatives for 5 different 
#' thresholds.

source("AH_SIC_lookup.R")

USER_AGENT <- "Bruno Lammering brunolammering@outlook.de"

edgar_profiles <- edgar_load(n_workers = 2, n_chunks = 100, duckdb_threads = 1)
matcher        <- edgar_matcher(edgar_profiles)

distances_tbl <- tibble(
  id = 1:5,
  strict_dist = c(0.01, 0.02, 0.03, 0.04, 0.05),
  loose_dist = c(1, 1, 1, 1, 1)
)

for (i in distances_tbl$id) {
  k <- edgar_match(
    DIME_contributions |>
      select(contributor.employer) |>
      filter(!is.na(contributor.employer)) |> 
      distinct() |>
      collect() |>
      deframe(),
    matcher,
    strict_dist = distances_tbl$strict_dist[i],
    loose_dist = distances_tbl$loose_dist[i]
  )

  distances_tbl$match_propensity[i] <- k |> 
    summarise(match_propensity = sum(status == "auto_accept") / n()) |> 
    deframe()

  k_positives_filtered <- k |> 
    select(employer_raw, matched_name, status, match_type) |> 
    filter(match_type == "fuzzy", status == "auto_accept") |> 
    slice_head(n = 500) |> 
    print(n = 500)

  input_false_positives <- readline(glue("Please input the total number of false positives of the threshold {distances_tbl$strict_dist[i]} as evaluated by hand:"))

  k_negatives_filtered <- k |> 
    select(employer_raw, matched_name, status, match_type) |> 
    filter(status != "auto_accept") |> 
    slice_head(n = 500) |> 
    print(n = 500)

  input_false_negatives <- readline(glue("Please input the total number of false negatives of the threshold {distances_tbl$strict_dist[i]} as evaluated by hand :"))

  distances_tbl$false_positives[i] <- as.integer(input_false_positives)
  distances_tbl$false_negatives[i] <- as.integer(input_false_negatives)

  distances_tbl$false_positives_share[i] <- as.integer(input_false_positives) / nrow(k_positives_filtered)
  distances_tbl$false_negatives_share[i] <- as.integer(input_false_negatives) / nrow(k_negatives_filtered)
}

print(distances_tbl)

print.xtable(xtable(
        distances_tbl,
        caption = "Comparing different thresholds for the acceptance of the JW distance in the matching algorithm for employers",
    ),
    type = "latex",
    file = "results/robustness_firms_thresholds.tex"
)


#' Robustness: compare the matching with the real share of american employees working 
#' in public companies! => even though this probably doesn't say much because there might be 
#' other reasons for why they are less represented in the data, it gives an impression of 
#' how far off I am!

matched_companies <- edgar_match(
    DIME_contributions |>
      select(contributor.employer) |>
      filter(!is.na(contributor.employer)) |> 
      distinct() |>
      collect() |>
      deframe(),
    matcher,
    strict_dist = 0.03,
    loose_dist = 0.06
  )

matched_keep <- matched_companies |>
  filter(status == "auto_accept",
         nzchar(employer_raw)) |>
  distinct(employer_raw, .keep_all = TRUE)   # guard against fan-out

total_count <- DIME_contributions |> count() |> collect() |> deframe()

matched_count <- DIME_contributions |>
  inner_join(matched_keep, join_by(contributor.employer == employer_raw),
             copy = TRUE) |>
  mutate(contributor.employer_matched = matched_name) |> 
  count() |> 
  collect() |> 
  deframe()

match_propensity_tbl <- tibble(match_propensity = matched_count / total_count,
                          real_share_approx = 0.2)

print(match_propensity_tbl)

print.xtable(xtable(
        match_propensity_tbl,
        caption = "Match propensity of the employers in the dataset",
    ),
    type = "latex",
    file = "results/firm_match_propensity.tex"
)

# compute in the end

DIME_contributions <- DIME_contributions |>
  inner_join(matched_keep, join_by(contributor.employer == employer_raw),
             copy = TRUE) |>
  mutate(contributor.employer_matched = matched_name) |> 
  compute()

# Tech Industry ----------------------------------------------------------

#' Robustness Check by showing that a set of companies usually thought of as "Tech"
#' figure among the companies identified as "Tech" by me!
#' => take them from the fortune 500 technology list!

tech_companies <- c("Google", "Microsoft", "IBM", "Oracle", "Palantir") # and some more


# Dynamic cfscores -------------------------------------------------------

#' Show whether the total cfscores differ much from the dynamic ones, make
#' a descriptive timeline graphic of where they do and when - do you see a trend in 
#' polarization?
#' 
#' ggplot() +
#' geom_line(aes(cycle, dyn_cfscore), fill = 'blue') +
#' geom_line(aes(cycle, cfscore), fill = 'red')

# Local ideological means ------------------------------------------------

#' - validity: 
#'     - density
#'         - compare the two different ways of calculating the mean per zipcode (contributions and contributors)
#'         - compare the dynamic cfcsore means per cycle:
#'             - following @short, it should also polarize!
#'     - make a map
#'         - total: compare the means based on contributions and contributors
#'         - dynamic cfscore means: compare the years
#'             - => does something shift? some regions shifting ideology meaningfully? does it all look the same?

# Gender -----------------------------------------------------------------

#' Overview: Report the general gender distribution of the different industries