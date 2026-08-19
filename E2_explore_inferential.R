##########################################
# E2_inferential.R
##########################################


# load packages ----------------------------------------------------------

library(duckdb)
library(dplyr)
library(arrow)
library(tidyverse)
library(stargazer)
library(sjPlot)
library(patchwork)
library(xtable)


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


# Multivariate regressions: cfscore ~ occupation + industry --------------

m1 <- lm("contributor.cfscore ~ occupation + ff49_name", contributors)
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


# contributors_en_man <- contributors |> 
#   filter(occupation %in% c("engineer", "manager")) |> 
#   show_query()
#
# DOESN'T WORK BECAUSE OF ARROW-DUCKDB CONNECTION ERROR WHEN FILTERING FOR TWO CONDITIONS
# 
# Workaround:

if(run_on_sample == TRUE) {
  contributors_en_man <- dbGetQuery(con, "SELECT * FROM read_parquet('data/analysis/processed_contributors_parquet_sample')
WHERE occupation = 'engineer' OR occupation = 'manager'")
} else {
  contribturos_en_man <- dbGetQuery(con, "SELECT * FROM read_parquet('data/analysis/processed_contributors_parquet')
WHERE occupation = 'engineer' OR occupation = 'manager'")
}

# including only only managers and engineers

m2 <- lm("contributor.cfscore ~ occupation + ff49_name", contributors_en_man)
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
m3 <- lm("contributor.cfscore ~ ff49_name", contributors_en_man)
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




# comparing the effect of industry in different occupations

contributors_e <- contributors |> filter(occupation == "engineer")
m1 <- lm("contributor.cfscore ~ ff49_name", contributors_e)

contributors_m <- contributors |> filter(occupation == "manager")
m2 <- lm("contributor.cfscore ~ ff49_name", contributors_m)

contributors_o <- contributors |> filter(occupation == "other")
m3 <- lm("contributor.cfscore ~ ff49_name", contributors_o)

tab_model(m1, m2, m3)

g1 <- plot_model(m1) + labs(title = "filtering for engineers")
g2 <- plot_model(m2) + labs(title = "filtering for manager")
g3 <- plot_model(m3) + labs(title = "filtering for other")

g1 + g2 + g3 + plot_annotation("Comparing the effect of industry in different occupations")
  
  
  
# Multilevel Models ------------------------------------------------------


# computing the ICC
library(lme4)
library(lmerTest)
library(performance)
m0 <-lmer(contributor.cfscore ~ 1 + (1 | ff49_name), data = contributors)
summary(m0)
icc(m0)

m1 <- lmer(contributor.cfscore ~ 1 + occupation + (1 | ff49_name), contributors)
m2 <- lmer(contributor.cfscore ~ 1 + occupation + (1 + occupation | ff49_name), data = contributors)
# m3 <- lmer(contributor.cfscore ~ 1 + occupation + (0 + occupation | ff49_name), contributors) # not really necessary
anova(m1, m2)
tab_model(m1, m2)

plot_model(m1) +
  ylim(c(-0.5, 0.5)) +
  geom_hline(yintercept = 0, lty = "dashed")+
  theme_bw()

performance::check_model(m1)
performance::check_model(m2)

library(DHARMa)
sim_res <- simulateResiduals(m1)
plot(sim_res)


# univariate regressions: cfscore ~ location -----------------------------

# overview over the zipcodes and cities

contributors |> 
    colnames()

contributors |> 
    count(most.recent.contributor.city) |> 
    arrange(desc(n))

contributors |> 
    count(most.recent.contributor.zipcode) |> 
     arrange(desc(n))

contributors |> 
  filter(
    !is.na(most.recent.contributor.city),
    !is.na(most.recent.contributor.zipcode),
    most.recent.contributor.zipcode != "0"
  ) |> 
  count(most.recent.contributor.zipcode, sort = TRUE)

# compute the zipcode and city means

tbl_mean_cfscore_per_city <- contributors |> 
    group_by(most.recent.contributor.city) |> 
    summarise(
        mean_cfscore_per_city = mean(contributor.cfscore)
    ) |> 
    select(most.recent.contributor.city, mean_cfscore_per_city)

tbl_mean_cfscore_per_zipcode <- contributors |> 
    group_by(most.recent.contributor.zipcode) |> 
    summarise(
        mean_cfscore_per_zipcode = mean(contributor.cfscore)
    ) |> 
    select(most.recent.contributor.zipcode, mean_cfscore_per_zipcode)

contributors <- contributors |> 
    left_join(tbl_mean_cfscore_per_city, by = "most.recent.contributor.city") |> 
    compute()

contributors <- contributors |> 
    left_join(tbl_mean_cfscore_per_zipcode, by = "most.recent.contributor.zipcode") |> 
    compute()

# compare

m1 <- lmer(contributor.cfscore ~ 1 + (1 | most.recent.contributor.city), contributors)
m2 <- lm("contributor.cfscore ~ 1 + mean_cfscore_per_city", contributors)
m3 <- lmer(contributor.cfscore ~ 1 + (1 | most.recent.contributor.zipcode), contributors)
m4 <- lm("contributor.cfscore ~ 1 + mean_cfscore_per_zipcode", contributors)


tab_model(m1, m2, m3, m4)


# Multilevel regressions: combining everything - cfscore ~ industry + gender + occupation + location ----

# construct a common estimation sample (if not already done so in A3)

contributors |> count()

variables_ces <- c("occupation", "most.recent.contributor.zipcode", "ff49_name", "contributor.gender")

contributors |> 
  summarise(
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

# build models to evaluate the impact of occupation on cfscore (H2)

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
        aes(ff49_name, fill = contributor.gender)
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



# shutdown ---------------------------------------------------------------

dbDisconnect(con)
unlink("tmp", recursive = TRUE)