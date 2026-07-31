# creates a directory with parquet files from the DIME_contributor data so that it is faster

# setup ------------------------------------------------------------------


library(duckdb)
library(dplyr)
library(arrow)
library(here)
library(tidyverse)
library(glue)

dir.create("tmp", recursive = TRUE, showWarnings = FALSE)
 
# persistent duckdb file so internal state spills to disk, not RAM
con <- dbConnect(duckdb(file.path("tmp", paste0("convert_", format(Sys.time(), "%Y%m%d%H%M%S"), ".duckdb"))))
 
# memory management: limit usage, force spilling to disk, single thread
dbExecute(con, "SET memory_limit = '8GB'")
dbExecute(con, "SET temp_directory = 'tmp'")
# dbExecute(con, "PRAGMA threads = NULL")
dbExecute(con, "SET preserve_insertion_order = false")


# helper functions -------------------------------------------------------

build_query <- function(csv_path, output_path, filename, limit_clause) {
  glue(r"(
    COPY (
      SELECT
        TRY_CAST("bonica.cid" AS BIGINT)                          AS "bonica.cid",
        "contributor.type"                                        AS "contributor.type",
        TRY_CAST("num.distinct" AS BIGINT)                        AS "num.distinct",
        "most.recent.contributor.name"                            AS "most.recent.contributor.name",
        "most.recent.contributor.address"                         AS "most.recent.contributor.address",
        "most.recent.contributor.city"                            AS "most.recent.contributor.city",
        "most.recent.contributor.zipcode"                         AS "most.recent.contributor.zipcode",
        "most.recent.contributor.state"                           AS "most.recent.contributor.state",
        TRY_CAST("most.recent.contributor.latitude" AS DOUBLE)    AS "most.recent.contributor.latitude",
        TRY_CAST("most.recent.contributor.longitude" AS DOUBLE)   AS "most.recent.contributor.longitude",
        "most.recent.contributor.occupation"                      AS "most.recent.contributor.occupation",
        "most.recent.contributor.employer"                        AS "most.recent.contributor.employer",
        "most.recent.transaction.id"                              AS "most.recent.transaction.id",
        TRY_CAST("most.recent.transaction.date" AS DATE)          AS "most.recent.transaction.date",
        "contributor.gender"                                      AS "contributor.gender",
        "is.corp"                                                 AS "is.corp",
        TRY_CAST("contributor.cfscore" AS DOUBLE)                 AS "contributor.cfscore",
        "is.projected"                                            AS "is.projected",
        TRY_CAST("first_cycle_active" AS BIGINT)                  AS "first_cycle_active",
        TRY_CAST("last_cycle_active" AS BIGINT)                   AS "last_cycle_active",
        TRY_CAST("amount.1980" AS DOUBLE)                         AS "amount.1980",
        TRY_CAST("amount.1982" AS DOUBLE)                         AS "amount.1982",
        TRY_CAST("amount.1984" AS DOUBLE)                         AS "amount.1984",
        TRY_CAST("amount.1986" AS DOUBLE)                         AS "amount.1986",
        TRY_CAST("amount.1988" AS DOUBLE)                         AS "amount.1988",
        TRY_CAST("amount.1990" AS DOUBLE)                         AS "amount.1990",
        TRY_CAST("amount.1992" AS DOUBLE)                         AS "amount.1992",
        TRY_CAST("amount.1994" AS DOUBLE)                         AS "amount.1994",
        TRY_CAST("amount.1996" AS DOUBLE)                         AS "amount.1996",
        TRY_CAST("amount.1998" AS DOUBLE)                         AS "amount.1998",
        TRY_CAST("amount.2000" AS DOUBLE)                         AS "amount.2000",
        TRY_CAST("amount.2002" AS DOUBLE)                         AS "amount.2002",
        TRY_CAST("amount.2004" AS DOUBLE)                         AS "amount.2004",
        TRY_CAST("amount.2006" AS DOUBLE)                         AS "amount.2006",
        TRY_CAST("amount.2008" AS DOUBLE)                         AS "amount.2008",
        TRY_CAST("amount.2010" AS DOUBLE)                         AS "amount.2010",
        TRY_CAST("amount.2012" AS DOUBLE)                         AS "amount.2012",
        TRY_CAST("amount.2014" AS DOUBLE)                         AS "amount.2014",
        TRY_CAST("amount.2016" AS DOUBLE)                         AS "amount.2016",
        TRY_CAST("amount.2018" AS DOUBLE)                         AS "amount.2018",
        TRY_CAST("amount.2020" AS DOUBLE)                         AS "amount.2020",
        TRY_CAST("amount.2022" AS DOUBLE)                         AS "amount.2022",
        TRY_CAST("amount.2024" AS DOUBLE)                         AS "amount.2024"
      FROM read_csv('{csv_path}',
                    all_varchar   = true,
                    nullstr       = ['\N', ''],
                    strict_mode   = false,
                    null_padding  = true,
                    parallel      = false,
                    encoding      = 'utf-8',
                    ignore_errors = true)
      {limit_clause}
    ) TO '{output_path}/{filename}.parquet' (FORMAT PARQUET)
  )")
}

decompress <- function(gz_path) {
  csv_path <- sub("\\.gz$", "", gz_path)
  if (file.exists(csv_path)) {
    message("Decompressed file already exists, skipping: ", csv_path)
  } else {
    message("Decompressing ", gz_path, "...")
    system(glue("gunzip -k {gz_path}"))
    message("✓ Decompressed to ", csv_path)
  }
  csv_path
}

# creates a seperate file with iconv so that duckdb loads the encoding correctly (it is very strict compared to, say, pandas or read.csv)

clean_encoding <- function(csv_path, from_encoding = "latin1") {
  csv_path_clean <- sub("\\.csv$", "_clean.csv", csv_path)
  if (file.exists(csv_path_clean)) {
    message("Cleaned file already exists, skipping: ", csv_path_clean)
  } else {
    message("Cleaning encoding (", from_encoding, " -> utf-8) for ", csv_path, "...")
    system(glue('iconv -f {from_encoding} -t utf-8//IGNORE "{csv_path}" > "{csv_path_clean}"'))
    message("✓ Cleaned file written to ", csv_path_clean)
  }
  csv_path_clean
}

# convert in chunks
convert_in_chunks <- function(csv_path, output_path, batch_size = 250000) {
 
  dir.create(output_path, recursive = TRUE, showWarnings = FALSE)
 
  offset    <- 0
  batch_num <- 0
 
  repeat {
    message("Processing batch ", batch_num, " (rows ", offset, " to ", offset + batch_size, ")...")
 
    rows_written <- dbExecute(con, build_query(
      csv_path     = csv_path,
      output_path  = output_path,
      filename     = glue("batch_{offset}"),
      limit_clause = glue("LIMIT {batch_size} OFFSET {offset}")
    ))
 
    if (rows_written == 0) {
      message("No more rows, done.")
      break
    }
 
    message("✓ batch_", offset, ".parquet written (", rows_written, " rows)")
    offset    <- offset + batch_size
    batch_num <- batch_num + 1
  }
 
  # validate: count rows written
  n_written <- dbGetQuery(con, glue("SELECT COUNT(*) FROM read_parquet('{output_path}/*.parquet')"))[[1]]
  message("✓ Validation: ", n_written, " rows written to ", output_path)
}


# main -------------------------------------------------------------------

gz_path  <- "data/raw/dime_contributors_1979_2024.csv.gz"
out_path <- "data/raw/raw_contributors_parquet"
  
csv_path       <- decompress(gz_path)
csv_path_clean <- clean_encoding(csv_path, from_encoding = "latin1")

# check if parquet files already exist and are complete, only then proceed
if(dir.exists(out_path)) {
  tryCatch({
    count_csv <- dbGetQuery(con, glue("SELECT COUNT(*) FROM read_csv('{csv_path_clean}',
                                       all_varchar = true,
                                       nullstr = ['\\N', ''],
                                       strict_mode = false,
                                       null_padding = true,
				       parallel=false,
                                       ignore_errors = true)"))[[1]]
    
    count_parquet <- dbGetQuery(con, glue("SELECT COUNT(*) FROM read_parquet('{out_path}/*.parquet')"))[[1]]
    
    out_file_already_exists <- (count_csv == count_parquet)
  }, error = function(e) {
    message("Error validating files: ", e$message)
    out_file_already_exists <<- FALSE  # Use <<- for outer scope
  })
} else {
  out_file_already_exists <- FALSE
}

if(out_file_already_exists == FALSE){
  unlink(out_path, recursive = TRUE)
  dir.create(out_path, recursive = TRUE, showWarnings = FALSE)
  
  convert_in_chunks(
    csv_path    = csv_path_clean,
    output_path = out_path,
    batch_size  = 1000000   # lowered from 1,000,000 to fit memory; lower further to 100000 if it still crashes
  )
  
  # remove decompressed + cleaned csv to free disk space
  message("Removing decompressed and cleaned CSV...")
  unlink(csv_path)
  unlink(csv_path_clean)
  message("✓ intermediate CSV files removed")
} else {
  message("Complete parquet file already exists. Not converting. Continuing...")
}


# cleanup ----------------------------------------------------------------

dbDisconnect(con, shutdown = TRUE)
unlink("tmp", recursive = TRUE)
