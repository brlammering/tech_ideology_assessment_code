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
} else if(run_on_sample == FALSE) {
  # import full dataset
  contributors <- open_dataset("data/analysis/processed_contributors_parquet", format = "parquet") |> 
    to_duckdb(con, "processed_contributors_parquet")
} else {
  stop("Please specifiy whether you want to run this script on a sample or on the full dataset by setting the flag run_on_sample =")
}


# Univariate regressions: occupation ~ industry --------------------------

contributors |> 
    count(sic, sic_description, sort = TRUE)

contributors |> count(ritter_is_tech)

m2 <- lm("contributor.cfscore ~ ff49_is_tech", contributors)

m3 <- lm("contributor.cfscore ~ sector_ff49", contributors)

tab_model(m1, m2, m3)

contributors %>%
  summarise(
    na_ritter = sum(is.na(ritter_is_tech)),
    na_ff49 = sum(is.na(ff49_is_tech)),
    na_sector = sum(is.na(sector_ff49))
  )

contributors |> 
    count(ritter_is_tech)

AIC(m1, m2, m3)
BIC(m1, m2, m3)
anova(m1, m2, m3) 


# univariate regressions: cfscore ~ occupation ---------------------------



contributors |> colnames()

contributors |> # descriptive graphics first without controlling for anything
    ggplot(aes(x = occupation, y = contributor.cfscore)) +
    geom_boxplot()

m1 <- lm("contributor.cfscore ~ occupation", contributors)
summary(m1)
plot_model(m1, type = "pred")

residuen <- m1$residuals
fitted <- m1$fitted.values 
daten_streudiagramm <- data.frame(occupation = pull(contributors,  var = occupation), cfscore = pull(contributors, contributor.cfscore), fitted = fitted, residuen = residuen)

head(daten_streudiagramm)

ggplot(daten_streudiagramm, aes(fitted, residuen))+
  geom_point()+
  geom_smooth(method = "lm", se = F)+
  ggtitle("Residuenstreudiagramm", subtitle = "geschätzte Werte und Residuen")

car::leveneTest(residuen ~ occupation, data = daten_streudiagramm)


contributors |> count(occupation)

contributors |> 
    filter(ff49_is_tech == TRUE) |> 
    count(occupation)


contributors_en_man <- contributors |> 
    filter(occupation %in% c("engineer", "manager")) |> 
    collect()

contributors_en_man |> # descriptive graphics first without controlling for anything
    ggplot(aes(x = occupation, y = contributor.cfscore)) +
    geom_boxplot()

m1 <- lm("contributor.cfscore ~ occupation", contributors_en_man)
summary(m1)
plot_model(m1, type = "pred")

residuen <- m1$residuals
fitted <- m1$fitted.values 
daten_streudiagramm <- data.frame(occupation = pull(contributors_en_man, occupation), cfscore = pull(contributors_en_man, contributor.cfscore), fitted = fitted, residuen = residuen)

head(daten_streudiagramm)

ggplot(daten_streudiagramm, aes(fitted, residuen))+
  geom_point()+
  geom_smooth(method = "lm", se = F)+
  ggtitle("Residuenstreudiagramm", subtitle = "geschätzte Werte und Residuen")

car::leveneTest(residuen ~ occupation, data = daten_streudiagramm)


contributors |> 
    filter(occupation == "engineer") |> 
    ggplot(aes(contributor.cfscore)) +
    geom_density()

contributors |> 
    ggplot(aes(contributor.cfscore)) +
    geom_density()



# Multivariate regressions: cfscore ~ occupation + industry --------------

# controlling for industry via industry-dummies
m1 <- lm("contributor.cfscore ~ occupation + sector_ff49", contributors)
summary(m1)

library(sjPlot)
library(patchwork)

g1_1 <- plot_model(m1, type = "pred", terms = "occupation") +
    coord_flip() +
    theme_bw()
g1_2 <- plot_model(m1, type = "pred", terms = "sector_ff49") +
    coord_flip() +
    theme_bw()

g1_1
g1_2

# for both engineers and managers
m2 <- lm("contributor.cfscore ~ occupation + sector_ff49", contributors_en_man)
summary(m2)

g2_1 <- plot_model(m2, type = "pred", terms = "occupation") +
    coord_flip() +
    theme_bw()
g2_2 <- plot_model(m2, type = "pred", terms = "sector_ff49") +
    coord_flip() +
    theme_bw()

# only including sector_ff49 to see whether controlling for occupation explains a lot
m3 <- lm("contributor.cfscore ~ sector_ff49", contributors_en_man)
summary(m3)

g3 <- plot_model(m3, type = "pred", terms = "sector_ff49") +
    coord_flip() +
    theme_bw()

# compare the models

stargazer(m2, m3, type = "text")
tab_model(m2, m3)

library(patchwork)

g1_1 + g2_1

g1_2 + g2_2 + g3


contributors_e <- contributors |> filter(occupation == "engineer")
m1 <- lm("contributor.cfscore ~ sector_ff49", contributors_e)

contributors_m <- contributors |> filter(occupation == "manager")
m2 <- lm("contributor.cfscore ~ sector_ff49", contributors_m)

contributors_o <- contributors |> filter(occupation == "other")
m3 <- lm("contributor.cfscore ~ sector_ff49", contributors_o)

tab_model(m1, m2, m3)

g1 <- plot_model(m1) + labs(title = "filtering for engineers")
g2 <- plot_model(m2) + labs(title = "filtering for manager")
g3 <- plot_model(m3) + labs(title = "filtering for other")

g1 + g2 + g3


# computing the ICC
library(lme4)
library(lmerTest)
library(performance)
m0 <-lmer(contributor.cfscore ~ 1 + (1 | sector_ff49), data = contributors)
summary(m0)
icc(m0) # => 0.226, MLR is necessary

m1 <- lmer(contributor.cfscore ~ 1 + occupation + (1 | sector_ff49), contributors)
m2 <- lmer(contributor.cfscore ~ 1 + occupation + (1 + occupation | sector_ff49), data = contributors) # doesn't work because not enough data points - might work with the full sample though
# m3 <- lmer(contributor.cfscore ~ 1 + occupation + (0 + occupation | sector_ff49), contributors)
anova(m1, m2) # => die random slopes bringen etwas

plot_model(m1) +
  ylim(c(-0.5, 0.5)) +
  geom_hline(yintercept = 0, lty = "dashed")+
  theme_bw()

performance::check_model(m1)
performance::check_model(m2)

library(DHARMa)
sim_res <- simulateResiduals(m1)
plot(sim_res)



m3 <- lm(contributor.cfscore ~ 1 + occupation * ff49_is_tech, contributors)


contributors |> 
    colnames()

contributors |> 
    count(most.recent.contributor.city)

contributors |> 
    count(most.recent.contributor.zipcode)


tbl_mean_cfscore_per_city <- contributors |> 
    group_by(most.recent.contributor.city) |> 
    summarise(
        mean_cfscore_per_city = mean(contributor.cfscore)
    ) |> 
    select(most.recent.contributor.city, mean_cfscore_per_city)

contributors <- contributors |> 
    left_join(tbl_mean_cfscore_per_city, by = "most.recent.contributor.city") |> 
    compute()


m1 <- lmer(contributor.cfscore ~ 1 + (1 | most.recent.contributor.city), contributors)

summary(m1)



# Multivariate regressions: combining everything - cfscore ~ industry + gender + occupation + location ----

# CONSTRUCT A COMMON ESTIMATION SAMPLE HERE SO MODEL COMPARISON BECOMES POSSIBLE

variables_ces <- c("occupation", "most.recent.contributor.city", "sector_ff49", "contributor.gender")

contributors_ces <- contributors |>
    filter(if_all(all_of(variables_ces), ~ !is.na(.x)))

omitted_rows <- (contributors |> count() |> pull(n)) - (contributors_ces |> count() |> pull(n))

contributors_ces |> count()

message("The number of total omitted rows in the common estimation sample is: ", omitted_rows, " of ", contributors |> count() |> pull(n), " which represents ", 100 * omitted_rows / contributors |> count() |> pull(n), "% of the observations in the dataset")

# build models

m1 <- lmer(contributor.cfscore ~ occupation + (1 | most.recent.contributor.city), contributors_ces)
m2 <- lmer(contributor.cfscore ~ occupation + (1 | sector_ff49), contributors_ces)
m3 <- lmer(contributor.cfscore ~ occupation + (1 | sector_ff49) + (1 | most.recent.contributor.city), contributors_ces)
m4 <- lmer(contributor.cfscore ~ occupation + contributor.gender + (1 | most.recent.contributor.city), contributors_ces)
m5 <- lmer(contributor.cfscore ~ occupation + contributor.gender + (1 | sector_ff49), contributors_ces)
m6 <- lmer(contributor.cfscore ~ occupation + contributor.gender + (1 | sector_ff49) + (1 | most.recent.contributor.city), contributors_ces)

# evaluate and compare models
tab_model(m1, m4, m2, m5, m3, m6)
anova(m1, m4, m2, m5, m3, m6)
compare_performance(m1, m4, m2, m5, m3, m6)


p1 <- contributors |> 
    ggplot(
        aes(sector_ff49, fill = contributor.gender)
    ) +
    geom_bar(position = "fill") +
    theme_bw() +
    theme(axis.text.x = element_text(angle = 90)) +
    labs(title = "Gender distribution per industry",
    subtitle = "It differs enough to make a difference in the regression results")

p2 <- contributors |> 
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
"unobserved_(socialisation,...)" [latent,pos="-0.883,0.097"]
city [exposure,pos="1.734,-1.856"]
gender [pos="-3.190,0.097"]
ideology [outcome,pos="1.803,-0.010"]
industry [exposure,pos="-0.903,-1.263"]
occupation [exposure,pos="-0.862,1.677"]
"unobserved_(socialisation,...)" -> ideology
city -> ideology
gender -> "unobserved_(socialisation,...)"
gender -> industry
gender -> occupation
industry -> ideology
occupation -> ideology
}')

plot(dag)


# shutdown ---------------------------------------------------------------

dbDisconnect(con)
unlink("tmp", recursive = TRUE)