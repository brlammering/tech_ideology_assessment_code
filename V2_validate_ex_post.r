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
  stop("Please specifiy whether you want to run this script on a sample or on the full dataset by setting the flag run_on_sample")
}

# check validation mode if validating the real data

validation_mode <- FALSE

# check function

check <- function(cond, msg) {
  if(validation_mode == TRUE){
    if (!isTRUE(cond)) stop("CHECK FAILED: ", msg)
  } else {
    if (!isTRUE(cond)) message("CHECK FAILED: ", msg)
  }
  invisible(TRUE)
}


# Missings ---------------------------------------------------------------

cols <- colnames(contributors)

all_missings <- contributors |>
  filter(if_any(all_of(cols), ~ is.na(.x))) |> 
  collect()

all_missings

# Inspect occupation -----------------------------------------------------

# Check for NAs

occup_nas <- contributors |> filter(is.na(occupation)) |> count() |> collect() |> deframe()

if(!occup_nas == 0){
  occup_na_plot <- contributors |>
    ggplot(aes(x = occupation, y = contributor.cfscore)) +
      geom_boxplot()

  check(occup_nas == 0, glue("Occupation has {occup_nas} NAs! See the plot if they are meaningfully different than other groups"))
}



# univariate regressions: cfscore ~ occupation 

if(validation_mode == FALSE){
  contributors_occup_comp <- contributors |> 
    filter(
      !is.na(occupation),
      !is.na(contributor.cfscore)
    )
}


m1 <- lm("contributor.cfscore ~ occupation", contributors_occup_comp)

summary(m1)
plot_model(m1, type = "pred")


residuals <- residuals(m1)
fitted <- fitted(m1) 
daten_streudiagramm <- data.frame(occupation = pull(contributors_occup_comp,  var = occupation), cfscore = pull(contributors_occup_comp, contributor.cfscore), fitted = fitted, residuals = residuals)

head(daten_streudiagramm)

ggplot(daten_streudiagramm, aes(fitted, residuen))+
  geom_point()+
  geom_smooth(method = "lm", se = F)+
  ggtitle("Residuenstreudiagramm", subtitle = "geschätzte Werte und Residuen")

car::leveneTest(residuen ~ occupation, data = daten_streudiagramm)


# inspect industry -------------------------------------------------------


# Univariate regressions: cfscore ~ industry

## creates a tibble with the number of NAs per industry variable of interes

na_counter <- contributors |> 
  summarise(
    na_ff49_is_tech = sum(is.na(ff49_is_tech)),
    na_ff49 = sum(is.na(ff49_abbr)),
    na_ff48 = sum(is.na(ff48)),
    na_ff12 = sum(is.na(ff12))
  ) |> 
  collect()

## checks for the variables having no NAs, if they do and validation_mode is FALSE
## filtes for the variables of interest having no NAs (if TRUE it stops in check() anyways)

contributors_in_comp <- contributors

for(i in colnames(na_counter)){
  check(na_counter[i] == 0, glue("{i} is not zero!"))

  if(validation_mode == FALSE){
    j <- str_extract(i, "ff.*$")

    contributors_in_comp <- contributors_in_comp |> 
      filter(
        !is.na(j)
    )
  }
}

m1 <- lm("contributor.cfscore ~ ff49_is_tech", contributors_in_comp)

m2 <- lm("contributor.cfscore ~ ff49_abbr", contributors_in_comp)

m3 <- lm("contributor.cfscore ~ ff12_abbr", contributors_in_comp)

m4 <- lm("contributor.cfscore ~ ff48_abbr", contributors_in_comp)

tab_model(m1, m2, m3, m4)



AIC(m1, m2, m3, m4)
BIC(m1, m2, m3, m4)
anova(m1, m2, m3, m4) 

plot_model(m1) + plot_model(m2) + plot_model(m3) + plot_model(m4) + plot_annotation("Comparison of the validity of industries")


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
