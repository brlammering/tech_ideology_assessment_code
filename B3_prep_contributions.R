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

target_cycles <- c(2016, 2020)
needed <- sort(unique(c(target_cycles, target_cycles - 2)))

# import the files
if(run_on_sample == TRUE) {
  # raw_sample_path <- glue("{in_path}_sample")

  # # create sample if it doesn't exist
  # if(!file.exists(raw_sample_path)){
  #   source("BH_sample_contributions.r")
  #   sample_contributions(raw_path = in_path, raw_sample_path = raw_sample_path)
  # }

  # # import sample 
  # DIME_contributions <- open_dataset(raw_sample_path, format = "parquet") |> 
  #   to_duckdb(con, glue("raw_contributions_sample_{filename}"))

  stop("Sample not configured yet!")

} else if(run_on_sample == FALSE) {

  DIME_contributions <- tbl(con, "read_parquet('data/raw/raw_contributions_parquet/**/*.parquet',
                  hive_partitioning = true,
                  hive_types = {'cycle': 'BIGINT'})") |>
    filter(cycle %in% !!needed)

} else {
  stop("Please specifiy if you want to run this script on a sample or on the full dataset by setting the flag run_on_sample =")
}


# In order for gender to be translated correctly from duckdb to r
DIME_contributions <- DIME_contributions |> 
  mutate(
    contributor.gender = as.character(contributor.gender)  # dbplyr translates this to CAST(... AS VARCHAR)
  ) |>
  show_query()

DIME_contributions <- DIME_contributions |>
  mutate(
    contributor.gender = as.character(contributor.gender)  # dbplyr translates this to CAST(... AS VARCHAR)
  ) |>
  compute()


# rename -----------------------------------------------------------------



# filter -----------------------------------------------------------------

DIME_contributions <- DIME_contributions |>
    filter(
        contributor.type == "I",
        !is.na(contributor.cfscore),
        !is.na(most.recent.contributor.employer)
    ) |> 
    compute()

DIME_contributions |> count() |> collect()



# **Firms** ABANDONED ----------------------------------------------------

# see notes on why - merged into one step with industry



## **Industry**

source("AH_SIC_lookup.R")

# One-time only, before the first edgar_load() call:
USER_AGENT <- "Bruno Lammering brunolammering@outlook.de"

# Three lines. First call downloads + builds (or restores from backup);
# later calls just read the cached parquet.
edgar_profiles <- edgar_load(n_workers = 2, n_chunks = 100, duckdb_threads = 1)
matcher        <- edgar_matcher(edgar_profiles)
matched_companies <- edgar_match(
  DIME_contributions |>
    select(most.recent.contributor.employer) |>
    filter(!is.na(most.recent.contributor.employer)) |> 
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
            join_by(most.recent.contributor.employer == employer_raw),
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


# Drop the observations where there is no match or a needs_review match, because they usually don't fit either

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
    engineer = str_detect(`most.recent.contributor.occupation`, engineer_regex),
    manager = str_detect(`most.recent.contributor.occupation`, manager_regex),
    other = !engineer & !manager & !is.na(`most.recent.contributor.occupation`)
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

## **Local ideological means**




# Dynamic cfscore means --------------------------------------------------

## save data, disconnect from the db

if(run_on_sample == TRUE) {

  DIME_contributions |> 
    write_parquet(glue("{out_path}_sample"), chunk_size = 250000)

} else if(run_on_sample == FALSE) {
  
  DIME_contributions |> 
    write_parquet(out_path, chunk_size = 250000)


# shutdown
dbDisconnect(con)
unlink("tmp", recursive = TRUE)
