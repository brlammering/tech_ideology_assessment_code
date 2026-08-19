
# load packages ----------------------------------------------------------

library(duckdb)
library(dplyr)
library(arrow)
library(tidyverse)
library(stargazer)
library(sjPlot)
library(patchwork)
library(xtable)
library(lme4)


# duckdb config ----------------------------------------------------------



dir.create("tmp", recursive = TRUE, showWarnings = FALSE)

con <- dbConnect(duckdb("tmp/convert.duckdb"))

# set memory usage to 4GB max so it doesn't break
dbExecute(con, "SET memory_limit = '2GB'")
dbExecute(con, "SET max_temp_directory_size = '100GB'")



# load data --------------------------------------------------------------


if(run_on_sample == TRUE) {
  # import sample 
  contributors <- open_dataset("data/analysis/processed_contributors_parquet_sample", format = "parquet") |> 
    to_duckdb(con, "processed_contributors_parquet_sample")

  contributions <- open_dataset("data/analysis/processed_contributions_parquet_sample", format = "parquet") |> 
    to_duckdb(con, "processed_contributions_parquet_sample")

} else if(run_on_sample == FALSE) {
  # import full dataset
  contributors <- open_dataset("data/analysis/processed_contributors_parquet", format = "parquet") |> 
    to_duckdb(con, "processed_contributors_parquet")

  contributions <- open_dataset("data/analysis/processed_contributions_parquet", format = "parquet") |> 
    to_duckdb(con, "processed_contributions_parquet")
} else {
  stop("Please specifiy whether you want to run this script on a sample or on the full dataset by setting the flag run_on_sample =")
}

# compute modelling dataset and pull into R

contributors <- contributors |> 
  collect() |> 
  mutate(
    ff49_is_tech = factor(ff49_is_tech, labels = c("Non-tech", "Tech")),
    ff49_name = factor(ff49_name)
  )


# construct a common estimation sample (if not already done so in A3)

contributors |> count()

variables_ces <- c("occupation", "most.recent.contributor.zipcode", "ff49_name", "contributor.gender")

contributors |>  
  mutate(
    NA_occupation = is.na(occupation),
    NA_ff49 = is.na(ff49_name),
    NA_city = is.na(most.recent.contributor.zipcode),
    NA_gender = is.na(contributor.gender)
    ) |> 
    count(NA_gender, NA_city, NA_occupation, NA_ff49, sort = TRUE)

contributors_ces <- contributors |>
    filter(if_all(all_of(variables_ces), ~ !is.na(.x)))

omitted_rows <- (contributors |> count() |> pull(n)) - (contributors_ces |> count() |> pull(n))

omitted_rows

contributors_ces |> count()

message("The number of total omitted rows in the common estimation sample is: ", omitted_rows, " of ", contributors |> count() |> pull(n), " which represents ", 100 * omitted_rows / contributors |> count() |> pull(n), "% of the observations in the dataset")

  
# H1: Tech employees are on average more liberal than employees in other firms ----

# Descriptive Dummy is_tech

p_ff49_is_tech <- contributors_ces |> 
    ggplot(aes(ff49_is_tech, contributor.cfscore)) +
    geom_boxplot() + 
    theme_bw() +
    theme(axis.text.x = element_text(angle = 90)) +
    labs(title = "Using FF49's classification (Softw, Hardw, Chips)")

contributors_ces <- contributors_ces |> 
  mutate(ff12_is_tech = ifelse(ff12 == 6, TRUE, FALSE)) |> 
  compute() # has many NAs - why?

p_ff12_is_tech <- contributors_ces |> 
    ggplot(aes(ff12_is_tech, contributor.cfscore)) +
    geom_boxplot() + 
    theme_bw() +
    theme(axis.text.x = element_text(angle = 90)) +
    labs(title = "Using FF12's classification (BusEq)")

p_ff12_is_tech + p_ff49_is_tech + plot_annotation(
  title = "Comparing employee ideology in the tech sector with others",
  subtitle = "from democrat (-) to republican (+)"
)

# Descriptive Comparisons of ff49

p_ff12_boxplot <- contributors_ces |> 
    ggplot(aes(ff12_abbr, contributor.cfscore, color = ff49_is_tech)) +
    geom_boxplot() + 
    theme_bw() +
    theme(axis.text.x = element_text(angle = 90)) +
    labs(title = "ff12")

p_ff49_boxplot <- contributors_ces |> 
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

p_ff12_density <- contributors_ces |>
  ggplot(aes(contributor.cfscore)) +
  geom_density() +
  facet_wrap(vars(ff12_abbr))

p_ff49_density <- contributors_ces |>
  ggplot(aes(contributor.cfscore)) +
  geom_density() +
  facet_wrap(vars(ff49_abbr))

p_ff12_density + p_ff49_density + plot_annotation(
  title = "Density of cfscores per industry"
)

# saving

ggsave("results/ideology_by_ff49_is_tech.pdf", p_ff49_is_tech)
ggsave("results/ideology_by_ff49_density.pdf", p_ff49_density)
ggsave("results/ideology_by_ff49_boxplot.pdf", p_ff49_boxplot)

# model based on is_tech

m1 <- lm("contributor.cfscore ~ ff49_is_tech", contributors_ces)
m2 <- lm("contributor.cfscore ~ occupation + ff49_is_tech", contributors_ces)
m3 <- lm("contributor.cfscore ~ mean_cfscore_per_zipcode + occupation + ff49_is_tech", contributors_ces)

stargazer(m1, m2, m3, type = "text")

g1_1 <- plot_model(m3, type = "pred", terms = "ff49_is_tech") +
    coord_flip() +
    theme_bw() +
    labs(
      title = "Influence of the industry on cfscore",
      subtitle = "term: contributor.cfscore ~ mean_cfscore_per_zipcode + occupation + ff49_is_tech")

# model based on ff49

m1 <- lm("contributor.cfscore ~ ff49_name", contributors_ces)
m2 <- lm("contributor.cfscore ~ occupation + ff49_name", contributors_ces)
m3 <- lm("contributor.cfscore ~ mean_cfscore_per_zipcode + occupation + ff49_name", contributors_ces)

stargazer(m1, m2, m3, type = "text")

# present the predictions


g1_2 <- plot_model(m3, type = "pred", terms = "ff49_name") +
    coord_flip() +
    theme_bw() +
    labs(
      title = "Influence of the industry on cfscore",
      subtitle = "term: contributor.cfscore ~ mean_cfscore_per_zipcode + occupation + ff49_name")

g1_1 + g1_2

# saving: 


# H2: Managers are more conservative than other occupation groups --------

# descriptive: comparisons en/man/other

contributors_ces |> 
  ggplot(aes(occupation, contributor.cfscore)) +
  geom_boxplot()

# models based on data filtered for occupation

m1 <- lm("contributor.cfscore ~ occupation + ff49_name", contributors_ces)
summary(m1)

g1_1 <- plot_model(m1, type = "pred", terms = "occupation") +
    coord_flip() +
    theme_bw() +
    labs(title = "cfscore ~ occupation + ff49, full table")

g1_2 <- plot_model(m1, type = "pred", terms = "ff49_name") +
    coord_flip() +
    theme_bw() +
    labs(title = "cfscore ~ occupation + ff49, full table")

g1_1 + g1_2

# for only engineers and managers

contributors_en_man <- contributors |> 
  filter(occupation %in% c("engineer", "manager"))

# filter as rigorously as contributors_ces

contributors_en_man_ces <- contributors_en_man |>
    filter(if_all(all_of(variables_ces), ~ !is.na(.x)))

# including only managers and engineers

m2 <- lm("contributor.cfscore ~ occupation + ff49_name", contributors_en_man_ces)
summary(m2)

g2_1 <- plot_model(m2, type = "pred", terms = "occupation") +
    coord_flip() +
    theme_bw() +
    labs(title = "cfscore ~ occupation + ff49, ONLY managers and engineers")

g2_2 <- plot_model(m2, type = "pred", terms = "ff49_name") +
    coord_flip() +
    theme_bw() +
    labs(title = "cfscore ~ occupation + ff49, ONLY managers and engineers")

# only including ff49_name to see whether controlling for occupation explains a lot or not
m3 <- lm("contributor.cfscore ~ ff49_name", contributors_en_man_ces)
summary(m3)

g3 <- plot_model(m3, type = "pred", terms = "ff49_name") +
    coord_flip() +
    theme_bw() +
    labs(title = "cfscore ~ ff49, ONLY managers and engineers")

# compare the models

stargazer(m1, m2, m3, type = "text")
tab_model(m1, m2, m3)

g1_1 + g2_1 + plot_annotation("Comparing effects of occupation on cfscore in differently filtered data")

g1_2 + g2_2 + g3 + plot_annotation("Comparing effects of ff49 on cfscore in differently filtered data")


# complete model: cfscore ~ occupation



m0 <- lmer(contributor.cfscore ~ 1 + (1 | ff49_name), contributors_ces)
m1 <- lmer(contributor.cfscore ~ occupation + (1 | ff49_name), contributors_ces)
m2 <- lmer(contributor.cfscore ~ occupation + (1 + occupation | ff49_name), contributors_ces)
m3 <- lmer(contributor.cfscore ~ occupation + mean_cfscore_per_zipcode + (1 | ff49_name), contributors_ces)
m4 <- lmer(contributor.cfscore ~ occupation + mean_cfscore_per_zipcode + (1 + occupation | ff49_name), contributors_ces)
m5 <- lmer(contributor.cfscore ~ occupation + mean_cfscore_per_zipcode + contributor.gender + (1 | ff49_name), contributors_ces)
m6 <- lmer(contributor.cfscore ~ occupation + mean_cfscore_per_zipcode + contributor.gender + (1 + occupation | ff49_name), contributors_ces)

# evaluate and compare models
tab_model(m0, m1, m2, m3, m4, m5, m6)
anova(m0, m1, m2, m3, m4, m5, m6)
compare_performance(m0, m1, m2, m3, m4, m5, m6)

# Include Gender or not?

p1 <- contributors_ces |> 
    ggplot(
        aes(ff49_abbr, fill = contributor.gender)
    ) +
    geom_bar(position = "fill") +
    theme_bw() +
    theme(axis.text.x = element_text(angle = 90)) +
    labs(title = "Gender distribution per industry",
    subtitle = "It differs enough to make a difference in the regression results")

p2 <- contributors_ces |> 
    ggplot(
        aes(occupation, fill = contributor.gender)
    ) +
    geom_bar(position = "fill") +
    theme_bw() +
    theme(axis.text.x = element_text(angle = 90)) +
    labs(title = "Gender distribution per occupation",
    subtitle = "Especially engineers are a lot more masculine than other")

p1 + p2

library(dagitty)

dag <- dagitty('dag {
bb="-3.98,-2.866,2.565,2.968"
X [latent,pos="-0.883,0.097"]
city [exposure,pos="1.734,-1.856"]
gender [pos="-3.190,0.097"]
ideology [outcome,pos="1.803,-0.010"]
industry [exposure,pos="-0.903,-1.263"]
occupation [exposure,pos="-0.862,1.677"]
X -> ideology
city -> ideology
gender -> X
gender -> industry
gender -> occupation
industry -> ideology
occupation -> ideology
city -> industry
}')

plot(dag)


# H3: Tech Managers are less conservative than other managers ------------

# descriptive

contributors_e_ces <- contributors_ces |> filter(occupation == "engineer")
contributors_m_ces <- contributors_ces |> filter(occupation == "manager")
contributors_o_ces <- contributors_ces |> filter(occupation == "other")

contributors_e_ces |> 
  ggplot(aes(ff49_abbr, contributor.cfscore)) +
  geom_boxplot() +
  theme_bw() +
  theme(axis.text.x = element_text(angle = 90)) +
  labs(title = "Comparing the ideologies of managers in different sectors")

# model: comparing the effect of industry in different occupations

m1 <- lm("contributor.cfscore ~ ff49_name", contributors_e_ces)

m2 <- lm("contributor.cfscore ~ ff49_name", contributors_m_ces)

m3 <- lm("contributor.cfscore ~ ff49_name", contributors_o_ces)

tab_model(m1, m2, m3)

g1 <- plot_model(m1) + labs(title = "filtering for engineers")
g2 <- plot_model(m2) + labs(title = "filtering for manager")
g3 <- plot_model(m3) + labs(title = "filtering for other")

g1 + g2 + g3 + plot_annotation("Comparing the effect of industry in different occupations")

# including location

m1 <- lm("contributor.cfscore ~ ff49_name", contributors_m_ces)
m2 <- lm("contributor.cfscore ~ mean_cfscore_per_zipcode + ff49_name", contributors_m_ces)

tab_model(m1, m2)

g1 <- plot_model(m1, type = "pred", terms = "ff49_name") + 
  coord_flip() +
  theme_bw() +
  labs(title = "excluding location")
g2 <- plot_model(m2, type = "pred", terms = "ff49_name") + 
  coord_flip() +
  theme_bw() + 
  labs(title = "including location")

g1 + g2 + plot_annotation("Comparing whether the effect disappears when controlling for location")

# model interaction terms: is_tech


m1 <- lm("contributor.cfscore ~ occupation", contributors_ces)
m2 <- lm("contributor.cfscore ~ occupation + ff49_is_tech", contributors_ces)
m3 <- lm("contributor.cfscore ~ occupation * ff49_is_tech", contributors_ces)

tab_model(m1, m2, m3)

# model interaction terms: ff49

m0 <- lmer(contributor.cfscore ~ 1 + (1 | ff49_name), contributors_ces)
m1 <- lmer(contributor.cfscore ~ occupation + (1 | ff49_name), contributors_ces)
m1i <- lmer(contributor.cfscore ~ occupation * ff49_name + (1 | ff49_name), contributors_ces)
m2 <- lmer(contributor.cfscore ~ occupation + (1 + occupation | ff49_name), contributors_ces)
m2i <- lmer(contributor.cfscore ~ occupation * ff49_name + (1 + occupation | ff49_name), contributors_ces)
m3 <- lmer(contributor.cfscore ~ occupation + mean_cfscore_per_zipcode + (1 | ff49_name), contributors_ces)
m3i <- lmer(contributor.cfscore ~ occupation * ff49_name + mean_cfscore_per_zipcode + (1 | ff49_name), contributors_ces)
m4 <- lmer(contributor.cfscore ~ occupation + mean_cfscore_per_zipcode + (1 + occupation | ff49_name), contributors_ces)
m4i <- lmer(contributor.cfscore ~ occupation * ff49_name + mean_cfscore_per_zipcode + (1 + occupation | ff49_name), contributors_ces)
m5 <- lmer(contributor.cfscore ~ occupation + mean_cfscore_per_zipcode + contributor.gender + (1 | ff49_name), contributors_ces)
m5i <- lmer(contributor.cfscore ~ occupation * ff49_name + mean_cfscore_per_zipcode + contributor.gender + (1 | ff49_name), contributors_ces)
m6 <- lmer(contributor.cfscore ~ occupation + mean_cfscore_per_zipcode + contributor.gender + (1 + occupation | ff49_name), contributors_ces)
m6i <- lmer(contributor.cfscore ~ occupation * ff49_name + mean_cfscore_per_zipcode + contributor.gender + (1 + occupation | ff49_name), contributors_ces)

tab_model(m0, m1, m1i, m2, m2i, m3, m3i, m4, m4i, m5, m5i, m6, m6i)


s1 <- lm("contributor.cfscore ~ occupation", contributors_ces)
s2 <- lm("contributor.cfscore ~ occupation + ff49_abbr", contributors_ces)
s3 <- lm("contributor.cfscore ~ occupation * ff49_abbr", contributors_ces)

tab_model(s1, s2, s3)
