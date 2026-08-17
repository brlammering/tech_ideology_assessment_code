############################
# Computes descriptive results and results
############################


# setup ------------------------------------------------------------------



library(duckdb)
library(dplyr)
library(arrow)
library(tidyverse)
library(stargazer)
library(sjPlot)
library(patchwork)
library(xtable)

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


# make results directory

dir.create("results", recursive = TRUE, showWarnings = FALSE)


# compute unities for comparison -----------------------------------------

## get prominent candidate CFScores for candidate comparisons COPIED FROM STEEL

# cand_list <- c("cand140679", "cand1235", "cand1327", "cand1600", "cand1573", "cand1403", "cand149269", "cand147768",
#                "cand100270nominee", "cand221nominee")

# target_cands <- candidates %>%
#   filter(bonica.rid %in% cand_list) %>%
#   mutate(full_name = paste(fname, lname, sep = " ") %>% str_to_title()) %>%
#   select(full_name, recipient.cfscore) %>%
#   distinct() %>%
#   arrange(recipient.cfscore) %>%
#   mutate(full_name = case_when(full_name == "Marjorie Greene" ~ "Greene",
#                                full_name == "George Bush" ~ "Bush",
#                                full_name == "Bernard Sanders" ~ "Sanders",
#                                full_name == "Joseph Biden" ~ "Biden",
#                                full_name == "Alexandria Ocasio Cortez" ~ "AOC",
#                                full_name == "Sherrod Brown" ~ "Brown",
#                                full_name == "Joe Manchin" ~ "Manchin",
#                                full_name == "Lisa Murkowski" ~ "Murkowski",
#                                full_name == "Lindsey Graham" ~ "Graham",
#                                full_name == "Rand Paul" ~ "Paul",
#                                full_name == "Donald Trump" ~ "Trump",
#                                TRUE ~ full_name),
#          y = rep(c(-0.05, -0.1), times = 5))

# Compare occupations ----------------------------------------------------


# Compare industries -----------------------------------------------------


# dummies don't say much:

p_ff49_is_tech <- contributors |> 
    ggplot(aes(ff49_is_tech, contributor.cfscore)) +
    geom_boxplot() + 
    theme_bw() +
    theme(axis.text.x = element_text(angle = 90)) +
    labs(title = "Using FF49's classification (Softw, Hardw, Chips)")

contributors <- contributors |> 
  mutate(ff12_is_tech = ifelse(ff12 == 6, TRUE, FALSE)) |> 
  compute() # has many NAs - why?

p_ff12_is_tech <- contributors |> 
    ggplot(aes(ff12_is_tech, contributor.cfscore)) +
    geom_boxplot() + 
    theme_bw() +
    theme(axis.text.x = element_text(angle = 90)) +
    labs(title = "Using FF12's classification (BusEq)")

p_ff12_is_tech + p_ff49_is_tech + patchwork::plot_annotation("Comparing employee ideology in the tech sector with others")

# Do the different industry specifications differ meaningfully?

# boxplots are more powerful

p_ff12_boxplot <- contributors |> 
    ggplot(aes(ff12_abbr, contributor.cfscore, color = ff49_is_tech)) +
    geom_boxplot() + 
    theme_bw() +
    theme(axis.text.x = element_text(angle = 90)) +
    labs(title = "ff12")

p_ff49_boxplot <- contributors |> 
    ggplot(aes(ff49_abbr, contributor.cfscore, color = ff49_is_tech)) +
    geom_boxplot() + 
    theme_bw() +
    theme(axis.text.x = element_text(angle = 90)) +
    labs(title = "ff49")

p_ff12_boxplot / p_ff49_boxplot + plot_annotation(
  title = "Employee ideology by industrial sector", 
  subtitle = "from democrat (-) to republican (+)"
)

# densities even more so

p_ff12_density <- contributors |>
  ggplot(aes(contributor.cfscore)) +
  geom_density() +
  facet_wrap(vars(ff12_abbr))

p_ff49_density <- contributors |>
  ggplot(aes(contributor.cfscore)) +
  geom_density() +
  facet_wrap(vars(ff49_abbr))

p_ff12_density + p_ff49_density + plot_annotation(
  title = "Density of cfscores per industry"
)

# saving

ggsave("results/ideology_by_ritter_is_tech.pdf", p_ritter_is_tech)
ggsave("results/ideology_by_ff49_is_tech.pdf", p_ff49_is_tech)
ggsave("results/ideology_by_ff49_density.pdf", p_ff49_density)
ggsave("results/ideology_by_ff49_boxplot.pdf", p_ff49_boxplot)


# other descriptive stats -----------------------------------

# maybe a cor tab? but not very useful in this example....

# shutdown ---------------------------------------------------------------

dbDisconnect(con)
unlink("tmp", recursive = TRUE)