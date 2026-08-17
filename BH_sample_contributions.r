# script that samples DIME for subsequent analysis

library(duckdb)
library(arrow)
library(dplyr)

sample_contributions <- function(raw_path, raw_sample_path){
    # load data
    DIME_contributors <- open_dataset(raw_path, format = "parquet") |> 
        to_duckdb(con, "raw_contributors_parquet")

    # Sample for faster compute when testing scripts in the future
    DIME_contributors_sample <- dbGetQuery(con, "
    SELECT * FROM raw_contributors_parquet
    USING SAMPLE 250000 ROWS (reservoir, 123)
    ")

    DIME_contributors_sample |> count()

    unlink(raw_sample_path)

    # Write to a parquet file for further computing
    DIME_contributors_sample |>
        write_parquet(raw_sample_path)

    # shutdown
    rm(DIME_contributors)
    rm(DIME_contributors_sample)
    duckdb_unregister_arrow(con, "raw_contributors_parquet")
}