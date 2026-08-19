#######################################################
# B3_prep_contributions.R
#######################################################

# preparation ------------------------------------------------------------

library(duckdb)
library(arrow)
library(dplyr)
library(glue)


# use a persistent duckdb file so internal state spills to disk, not RAM
if(!dir.exists("tmp")){
  dir.create("tmp", recursive = TRUE, showWarnings = FALSE)
}
con <- dbConnect(duckdb("tmp/convert.duckdb"))


# set memory usage to 4GB max so it doesn't break
dbExecute(con, "SET memory_limit = '2GB'")
dbExecute(con, "SET max_temp_directory_size = '100GB'")

target_cycles <- c(2016, 2020, 2024)
needed <- sort(unique(c(target_cycles, target_cycles - 2)))
final_root <- "data/raw/raw_contributions_parquet"

# import the files

stopifnot(is.logical(run_on_sample), length(run_on_sample) == 1, !is.na(run_on_sample))

dbExecute(con, glue("
  CREATE OR REPLACE VIEW contribs_raw AS
  SELECT * FROM read_parquet('{final_root}/**/*.parquet',
                             hive_partitioning = true,
                             hive_types = {{'cycle': 'BIGINT'}})"))

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
    semi_join(sample_ids, by = "bonica.cid")

}


# # In order for gender to be translated correctly from duckdb to r
# DIME_contributions <- DIME_contributions |> 
#   mutate(
#     contributor.gender = as.character(contributor.gender)  # dbplyr translates this to CAST(... AS VARCHAR)
#   ) |>
#   show_query()

# filter -----------------------------------------------------------------

DIME_contributions <- DIME_contributions |>
    filter(
        contributor.type == "I"
    )

# **Firms** ABANDONED ----------------------------------------------------

# see notes on why - merged into one step with industry



## **Industry**

source("AH_SIC_lookup.R")

# One-time only, before the first edgar_load() call:
USER_AGENT <- "Bruno Lammering brunolammering@outlook.de"

# First call downloads + builds (or restores from backup);
# later calls just read the cached parquet.
edgar_profiles <- edgar_load(n_workers = 2, n_chunks = 100, duckdb_threads = 1)
matcher        <- edgar_matcher(edgar_profiles)
matched_companies <- edgar_match(
  DIME_contributions |>
    select(contributor.employer) |>
    filter(!is.na(contributor.employer)) |> 
    distinct() |>
    collect() |>
    deframe(),
  matcher
)

# Optional but recommended after the first successful build -- snapshots
# profile_parts/ into backups/, so a future accidental rebuild recovers
# in seconds instead of hours.
edgar_backup()

# Attach SIC codes to the contributor table:


DIME_contributions <- DIME_contributions |>
  left_join(matched_companies,
            join_by(contributor.employer == employer_raw),
            copy = TRUE) |>
  compute()

# Diagnostic: match coverage and review queue size.
DIME_contributions |>
  count(status, match_type) |>
  arrange(desc(n))

# Spot-check the highest-frequency needs_review rows before trusting the
# downstream industry classification -- especially the tech employers
# the analysis actually hinges on.
matched_companies |>
  filter(status == "needs_review") |>
  count(match_type, employer_raw, matched_name, sort = TRUE) |>
  head(50)

DIME_contributions |> 
  filter(status == "needs_review") |> 
  count(contributor.employer, matched_name, sort = TRUE) |> 
  head(50)

# Drop the observations where there is no match or a needs_review match, because they usually don't fit

DIME_contributions <- DIME_contributions |> 
  filter(status != "no_match" & status != "needs_review") |> 
  collect()

# Tech Industry ----------------------------------------------------------

# # ritter NOT USED ANYMORE SEE NOTES
# ritter_tech_sic <- c(
#   "3559" = "Special Industry Machinery, NEC (incl. semiconductor manufacturing equipment)",
#   "3571" = "Electronic Computers",
#   "3572" = "Computer Storage Devices",
#   "3575" = "Computer Terminals",
#   "3576" = "Computer Communications Equipment",
#   "3577" = "Computer Peripheral Equipment, NEC",
#   "3578" = "Calculating and Accounting Machines",
#   "3661" = "Telephone & Telegraph Apparatus",
#   "3663" = "Radio & TV Broadcasting & Communications Equipment",
#   "3669" = "Communications Equipment, NEC",
#   "3674" = "Semiconductors & Related Devices",
#   "3812" = "Search, Detection, Navigation, Guidance Systems",
#   "3823" = "Industrial Instruments for Measurement, Display, and Control of Process Variables",
#   "3825" = "Instruments for Measuring & Testing of Electricity & Electrical Signals",
#   "3826" = "Laboratory Analytical Instruments",
#   "3827" = "Laboratory Apparatus & Furniture",
#   "3829" = "Measuring & Controlling Devices, NEC",
#   "4899" = "Communications Services, NEC",
#   "7370" = "Computer Services (general)",
#   "7371" = "Computer Programming Services",
#   "7372" = "Prepackaged Software",
#   "7373" = "Computer Integrated Systems Design",
#   "7374" = "Computer Processing & Data Preparation",
#   "7375" = "Information Retrieval Services",
#   "7377" = "Computer Rental & Leasing",
#   "7378" = "Computer Maintenance & Repair",
#   "7379" = "Computer Related Services, NEC"
# )

# ritter_tech_sic_extra <- c( # from ritters update - include or not? for now no
#   "3760" = "Guided Missiles, Space Vehicles & Parts (defense/aerospace tech)",
#   "3844" = "X-Ray Apparatus & Tubes & Related Irradiation Apparatus",
#   "7389" = "Services-Business Services, NEC (tech-relevant subset only)"
# )

# DIME_contributions <- DIME_contributions |> 
#     mutate(
#         ritter_is_tech = case_when(
#           sic_description %in% tech_sic ~ TRUE,
#           .default = FALSE
#           ) # Ritter bc the author of the papers is called like that
#     ) |> 
#     compute()


# ff12, ff48, ff49

source("AH_prep_fama_french_industry_matching.r")

ff_sic_lookup <- read_csv("data/raw/sic/sic_ff_lookup.csv")

ff_sic_lookup <- ff_sic_lookup |> 
  filter(in_sec == TRUE)

DIME_contributions <- DIME_contributions |> left_join(sic_lookup, by = c("sic" = "sic"))


DIME_contributions <- DIME_contributions |> 
    mutate(
        ff49_is_tech = case_when(
            ff49_abbr %in% c("Softw", "Hardw", "Chips") ~ TRUE, 
            .default = FALSE
        )
    ) |> 
    compute()


## **Occupation**

source("AH_get_occupation_lists.r")

engineer_list <- get_engineer_list()

engineer_regex <- paste(engineer_list, collapse = "|")

manager_list <- get_manager_list()

manager_regex <- paste(manager_list, collapse = "|")

DIME_contributions <- DIME_contributions |>
  mutate(
    engineer = str_detect(`contributor.occupation`, engineer_regex),
    manager = str_detect(`contributor.occupation`, manager_regex),
    other = !engineer & !manager & !is.na(`contributor.occupation`)
  ) |> 
  mutate(
      occupation = case_when(
          engineer == TRUE & manager == TRUE ~ "manager", # coding this as manager because it is the higher position (is it tho?)
          engineer == TRUE & manager == FALSE ~ "engineer",
          engineer == FALSE & manager == TRUE ~ "manager",
          other == TRUE ~ "other",
          .default = NA
      ) |> as.character()
  ) |> 
  compute()

DIME_contributions |> 
  count(occupation)

# Local ideological means ------------------------------------------------


tbl_mean_cfscore_per_city <- DIME_contributions |> 
    group_by(contributor.city) |> 
    summarise(
        mean_cfscore_per_city = mean(contributor.cfscore)
    ) |> 
    select(contributor.city, mean_cfscore_per_city)

tbl_mean_cfscore_per_zipcode <- DIME_contributions |> 
    group_by(contributor.zipcode) |> 
    summarise(
        mean_cfscore_per_zipcode = mean(contributor.cfscore)
    ) |> 
    select(contributor.zipcode, mean_cfscore_per_zipcode)

DIME_contributions <- DIME_contributions |> 
    left_join(tbl_mean_cfscore_per_city, by = "contributor.city") |> 
    left_join(tbl_mean_cfscore_per_zipcode, by = "contributor.zipcode") |> 
    compute()

# Dynamic cfscore means --------------------------------------------------

# get static candidate CFScores

# candidate_cfscores <- DIME_contributions |>
#   select(cycle, bonica.rid, candidate.cfscore) |>
#   filter(!is.na(candidate.cfscore)) |>
#   select(bonica.rid, candidate.cfscore) |>
#   distinct()

# DON'T NEED IT BECAUSE I CAN DIRECTLY USE THE CFSCORES FROM THE THING

# # exclude corporations, labor unions, and trade associations

# exclude <- cands |>
#   filter(igcat %in% c("C", "L", "T"), recipient.type == "comm") |>
#   select(bonica.rid, cycle) |>
#   distinct() |>
#   mutate(exclude = 1)

# => STEEL DOES THIS, I CAN'T DO IT HERE BECAUSE I DON'T USE THE RECIPIENT DATABASE (I COULD, I DON'T DO IT YET, IT IS EASIER THIS WAY)

dyn_cf_matcher <- DIME_contributions |> 
  mutate(cycle = cycle + 2) |>
  union_all(DIME_contributions) |> 
  mutate(amount = as.numeric(amount),
         amount_normalized = case_when(
           amount <= 0 ~ 0,
           amount > 0 & amount < 5000 ~ ceiling(amount / 100),
           amount >= 5000 ~ 50
         )) |> 
  select(amount_normalized, bonica.cid, cycle, transaction.type, transaction.id, bonica.rid, candidate.cfscore) |> 
  compute()

error <- dyn_cf_matcher |> 
  count(transaction.id) |> 
  filter(n != 2) |> 
  collect()

stopifnot(nrow(error) == 0)

indiv_by_cycle_init <- dyn_cf_matcher |> 
  filter(!is.na(bonica.cid), !is.na(candidate.cfscore), !is.na(amount_normalized), amount_normalized > 0,
         transaction.type %in% c("15", "15E", "15J", "15S", "15L", "24E", "24P")) |> 
  group_by(bonica.cid, cycle) |> 
  mutate(tot_cycle = sum(amount_normalized, na.rm = T)) |>
  ungroup() |>
  mutate(prop_of_total = amount_normalized / tot_cycle,
         cfscore_times_prop = candidate.cfscore * prop_of_total) |>
  group_by(bonica.cid, cycle) |>
  summarize(cfscore_dyn_cycle = sum(cfscore_times_prop, na.rm = T)) |>
  ungroup()

DIME_contributions <- DIME_contributions |>
  filter(bonica.cid %in% indiv_by_cycle_init$bonica.cid) |> # why filter here?
  left_join(indiv_by_cycle_init, join_by(bonica.cid, cycle))

# contributions_panel_of <- DIME_contributions |>
#  # filter(bonica.cid %in% indiv_by_cycle_init$bonica.cid) |>
#   left_join(indiv_by_cycle_init, join_by(bonica.cid, cycle))

############################################################################################# STEEL HERE

# # linearly interpolate missing scores

# the_panel <- top4000_panel_usa |>
#   filter(!is.na(cfscore_weighted_avg)) |>
#   mutate(longtime_donor = if_else(DirectorID %in% longtime_donors$DirectorID, 1, 0))

# indiv_by_cycle_interpolated <- tibble(DirectorID = unique(sort(the_panel$DirectorID))) |>
#   cross_join(tibble(cycle = seq(1982, 2022, by = 2))) |>
#   left_join(indiv_by_cycle_init) |>
#   group_by(DirectorID) |>
#   arrange(cycle, .by_group = TRUE) |>
#   mutate(cfscore_dyn = if (all(is.na(cfscore_dyn_cycle))) {
#     NA_real_  # if all values are NA, keep as NA
#   } else if (sum(!is.na(cfscore_dyn_cycle)) == 1) {
#     first(na.omit(cfscore_dyn_cycle))  # if only one value, replicate it
#   } else {
#     approx(
#       x = cycle, 
#       y = cfscore_dyn_cycle, 
#       xout = cycle, 
#       rule = 2
#     )$y  # standard interpolation
#   }) |>
#   ungroup() |>
#   filter(!is.na(cfscore_dyn)) |>
#   select(-cfscore_dyn_cycle)

# # add dynamic scores to panel

# the_panel <- the_panel |>
#   filter(DirectorID %in% indiv_by_cycle_interpolated$DirectorID) |>
#   mutate(cycle = if_else(year %% 2 == 0, year, year + 1)) |>
#   left_join(indiv_by_cycle_interpolated)

#############################################################################################

## save data, disconnect from the db

out_path <- "data/analysis/processed_contributions_parquet"

if(run_on_sample == TRUE) {

  DIME_contributions |> 
    write_parquet(glue("{out_path}_sample"), chunk_size = 250000)

} else if(run_on_sample == FALSE) {
  
  DIME_contributions |> 
    write_parquet(out_path, chunk_size = 250000)
}

# shutdown
dbDisconnect(con)
unlink("tmp", recursive = TRUE)
