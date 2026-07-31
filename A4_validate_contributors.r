library(duckdb)
library(dplyr)
library(arrow)
library(tidyverse)
library(patchwork)
library(xtable)
library(glue)

# init

dir.create("tmp", recursive = TRUE, showWarnings = FALSE)

con <- dbConnect(duckdb("tmp/convert.duckdb"))

# set memory usage to 4GB max so it doesn't break
dbExecute(con, "SET memory_limit = '2GB'")
dbExecute(con, "SET max_temp_directory_size = '100GB'")

if(run_on_sample == TRUE) {
  # import sample 
  contributors <- open_dataset("data/analysis/processed_contributors_parquet_sample", format = "parquet") |> 
    to_duckdb(con, "processed_contributors_parquet_sample")
} else if(run_on_sample == FALSE) {
  # import full dataset
  contributors <- open_dataset("data/analysis/processed_contributors_parquet", format = "parquet") |> 
    to_duckdb(con, "processed_contributors_parquet")
} else {
  stop("Please specifiy whether you want to run this script on a sample or on the full dataset by setting the flag run_on_sample =")
}


# check function

check <- function(cond, msg) {
  if (!isTRUE(cond)) message("CHECK FAILED: ", msg)
  invisible(TRUE)
}

# Group sample size ------------------------------------------------------

t_descriptive_statistics_by_ff49_occupation <- contributors |> 
  group_by(ff49_abbr, occupation) |> 
  summarise(
    ff49_abbr = ff49_abbr,
    occupation = occupation,
    n = n(),
    mean_cfscore = mean(contributor.cfscore),
    sd_cfscore = sd(contributor.cfscore),
    na.rm = TRUE
  ) |> 
  arrange(desc(n)) |> 
  collect()

t_descriptive_statistics_by_ff49_occupation_smaller_20 <- t_descriptive_statistics_by_ff49_occupation |> 
  filter(
    n < 20
  ) |> 
  arrange(desc(n)) |> 
  collect()

check(
  t_descriptive_statistics_by_ff49_occupation_smaller_20 |> count() == 0,
  "There are Industry/Occupation groups with n < 20 in the data!"
)


# print the results to latex

print.xtable(xtable(
        t_descriptive_statistics_by_ff49_occupation,
        caption = "Descriptive Statistics by ff49",
    ),
    type = "latex",
    file = "results/descriptive_statistics_by_ff49_occupation.tex"
)

t_compare <- rbind(head(t_descriptive_statistics_by_ff49_occupation, 5), t_descriptive_statistics_by_ff49_occupation_smaller_20)

print.xtable(xtable(
        t_compare,
        caption = "Descriptive Statistics by ff49 that have n < 20 with first 5 others to compare sd",
    ),
    type = "latex",
    file = "results/descriptive_statistics_by_ff49_occupation_smaller_20.tex"
)

contributors |> 
  group_by(ff49_abbr, occupation) |> 
  summarize(
    ff49_abbr = ff49_abbr,
    occupation = occupation,
    n = n(),
    mean_cfscore = mean(contributor.cfscore),
    sd_cfscore = sd(contributor.cfscore),
    na.rm = TRUE
  ) |> 
  filter(
    n < 20
  ) |> 
  ungroup() |> 
  count() |> 
  collect() |> 
  deframe()



# Individual outlier -----------------------------------------------------

outliers <- contributors |> 
  filter(!between(contributor.cfscore, -3, 3)) |> 
  count() |>
  collect() |> 
  unlist()

check(
  outliers == 0,
  glue("There are {outliers} outlier outside the range -3 and 3!")
)
