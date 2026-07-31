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

# Compare industries -----------------------------------------------------


# dummies don't say much:

p_ritter_is_tech <- contributors |> 
    ggplot(aes(ritter_is_tech, contributor.cfscore)) +
    geom_boxplot() + 
    theme_bw() +
    theme(axis.text.x = element_text(angle = 90)) +
    labs(title = "Comparing employee ideology in the tech sector with others, using Ritter's classification")

p_ff49_is_tech <- contributors |> 
    ggplot(aes(ff49_is_tech, contributor.cfscore)) +
    geom_boxplot() + 
    theme_bw() +
    theme(axis.text.x = element_text(angle = 90)) +
    labs(title = "Employees in the tech sector measured via Ritter's classification is more liberal than the median of all other people")


# boxplots, but especially density are more meaningful

p_ff49_boxplot <- contributors |> 
    ggplot(aes(sector_ff49, contributor.cfscore, color = ff49_is_tech)) +
    geom_boxplot() + 
    theme_bw() +
    theme(axis.text.x = element_text(angle = 90)) +
    labs(title = "Employee ideology by ff49 industrial sector", subtitle = "from democrat (-) to republican (+)")


p_ff49_density <- contributors |>
  ggplot(aes(contributor.cfscore)) +
  geom_density() +
  facet_wrap(vars(sector_ff49))


# displaying and saving

p_ritter_is_tech + p_ff49_is_tech + p_ff49_density + p_ff49_boxplot

ggsave("results/ideology_by_ritter_is_tech.pdf", p_ritter_is_tech)
ggsave("results/ideology_by_ff49_is_tech.pdf", p_ff49_is_tech)
ggsave("results/ideology_by_ff49_density.pdf", p_ff49_density)
ggsave("results/ideology_by_ff49_boxplot.pdf", p_ff49_boxplot)



# how many observations are we talking of? descriptive tables ------------



t_descriptive_statistics_by_ff49_occupation <- contributors |> 
  group_by(sector_ff49, occupation) |> 
  summarise(
    sector_ff49 = sector_ff49,
    occupation = occupation,
    n = n(),
    mean_cfscore = mean(contributor.cfscore),
    sd_cfscore = sd(contributor.cfscore),
    na.rm = TRUE
  ) |> 
  arrange(desc(n)) |> 
  collect()

t_descriptive_statistics_by_ff49_occupation_smaller_20 <- contributors |> 
  group_by(sector_ff49, occupation) |> 
  summarise(
    sector_ff49 = sector_ff49,
    occupation = occupation,
    n = n(),
    mean_cfscore = mean(contributor.cfscore),
    sd_cfscore = sd(contributor.cfscore),
    na.rm = TRUE
  ) |> 
  filter(
    n < 20
  ) |> 
  arrange(desc(n)) |> 
  collect()

# print the results to latex

print.xtable(xtable(
        t_descriptive_statistics_by_ff49_occupation,
        caption = "Descriptive Statistics by ff49",
    ),
    type = "latex",
    file = "results/descriptive_statistics_by_ff49_occupation"
)

print.xtable(xtable(
        t_descriptive_statistics_by_ff49_occupation_smaller_20,
        caption = "Descriptive Statistics by ff49 that have n < 20",
    ),
    type = "latex",
    file = "results/descriptive_statistics_by_ff49_occupation_smaller_20"
)

contributors |> 
  group_by(sector_ff49, occupation) |> 
  summarize(
    sector_ff49 = sector_ff49,
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


# other descriptive stats -----------------------------------

# maybe a cor tab? but not very useful in this example....

# shutdown ---------------------------------------------------------------

dbDisconnect(con)
unlink("tmp", recursive = TRUE)