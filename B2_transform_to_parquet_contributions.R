# 02_convert.R
# Convert raw CSV.gz files to parquet format with explicit column types
# Uses TRY_CAST to handle malformed rows gracefully (returns NULL instead of crashing)
# Decompresses CSV first to allow DuckDB to seek efficiently, then converts in chunks

# IDEA FOR ALL OF THE CONTRIBUTIONS: DOWNLOAD, UNPACK, CONVERT TO PARQUET, THEN DELETE THE DOWNLOADED 
# AND UNPACKED FILE AND CONTINUE WITH THE NEXT - LIMIT DISK SPACE USE!!

library(dbplyr)
library(duckdb)
library(glue)
library(readr)

# --- setup ------------------------------------------------------------------

if(!dir.exists("data/raw/raw_contributions_parquet")){
  dir.create("data/raw/raw_contributions_parquet",recursive = TRUE, showWarnings = FALSE)
}

if(!dir.exists("tmp")){
  dir.create("tmp", recursive = TRUE, showWarnings = FALSE)
}

# use a persistent duckdb file so internal state spills to disk, not RAM
con <- dbConnect(duckdb(file.path("tmp", paste0("convert_", format(Sys.time(), "%Y%m%d%H%M%S"), ".duckdb"))))

# memory management: limit usage, force spilling to disk, 8 thread
dbExecute(con, "SET memory_limit = '8GB'")
dbExecute(con, "SET temp_directory = 'tmp'")
dbExecute(con, "PRAGMA threads = 1")
dbExecute(con, "SET preserve_insertion_order = false")

# --- helper: SELECT body with all casts -------------------------------------

# returns the full COPY ... TO statement
# limit_clause is injected as a string e.g. "LIMIT 10000" or "LIMIT 1000000 OFFSET 5000000"
build_query <- function(csv_path, output_path, filename, limit_clause) {
  glue(r"(
    COPY (
      SELECT
        cycle::BIGINT                                    AS cycle,
        "transaction.id"                                 AS "transaction.id",
        "transaction.type"                               AS "transaction.type",
        TRY_CAST(amount AS DOUBLE)                       AS amount,
        TRY_CAST(date AS DATE)                           AS date,
        TRY_CAST("bonica.cid" AS BIGINT)                 AS "bonica.cid",
        "contributor.name"                               AS "contributor.name",
        "contributor.lname"                              AS "contributor.lname",
        "contributor.fname"                              AS "contributor.fname",
        "contributor.mname"                              AS "contributor.mname",
        "contributor.suffix"                             AS "contributor.suffix",
        "contributor.title"                              AS "contributor.title",
        "contributor.ffname"                             AS "contributor.ffname",
        "contributor.type"                               AS "contributor.type",
        "contributor.gender"                             AS "contributor.gender",
        "contributor.address"                            AS "contributor.address",
        "contributor.city"                               AS "contributor.city",
        "contributor.state"                              AS "contributor.state",
        "contributor.zipcode"                            AS "contributor.zipcode",
        "contributor.occupation"                         AS "contributor.occupation",
        "contributor.employer"                           AS "contributor.employer",
        "occ.standardized"                               AS "occ.standardized",
        "is.corp"                                        AS "is.corp",
        "recipient.name"                                 AS "recipient.name",
        "bonica.rid"                                     AS "bonica.rid",
        "recipient.party"                                AS "recipient.party",
        "recipient.type"                                 AS "occ.standardized",
        "is.corp"                                        AS "is.corp",
        "recipient.name"                                 AS "recipient.name",
        "bonica.rid"                                     AS "recipient.type",
        "recipient.state"                                AS "recipient.state",
        seat                                             AS seat,
        "election.type"                                  AS "election.type",
        TRY_CAST(latitude AS DOUBLE)                     AS latitude,
        TRY_CAST(longitude AS DOUBLE)                    AS longitude,
        TRY_CAST("gis.confidence" AS DOUBLE)             AS "gis.confidence",
        "contributor.district"                           AS "contributor.district",
        censustract                                      AS censustract,
        "efec.memo"                                      AS "efec.memo",
        "efec.memo2"                                     AS "efec.memo2",
        "efec.transaction.id.orig"                       AS "efec.transaction.id.orig",
        "bk.ref.transaction.id"                          AS "bk.ref.transaction.id",
        "efec.org.orig"                                  AS "efec.org.orig",
        "efec.comid.orig"                                AS "efec.comid.orig",
        "efec.form.type"                                 AS "efec.form.type",
        TRY_CAST("excluded.from.scaling" AS BIGINT)      AS "excluded.from.scaling",
        TRY_CAST("contributor.cfscore" AS DOUBLE)        AS "contributor.cfscore",
        TRY_CAST("candidate.cfscore" AS DOUBLE)          AS "candidate.cfscore"
      FROM read_csv('{csv_path}',
                    all_varchar   = true,
                    nullstr       = ['\N', ''],
                    strict_mode   = false,
                    null_padding  = true,
                    parallel      = false,
                    ignore_errors = true)
      {limit_clause}
    ) TO '{output_path}/{filename}.parquet' (FORMAT PARQUET)
  )")
}

# --- helper: decompress csv.gz ----------------------------------------------

decompress <- function(gz_path) {
  csv_path <- sub("\\.gz$", "", gz_path)
  if (file.exists(csv_path)) {
    message("Decompressed file already exists, skipping: ", csv_path)
  } else {
    message("Decompressing ", gz_path, "...")
    system(glue("gunzip -k {gz_path}"))
    message("✓ Decompressed to ", csv_path)
  }
}

# --- helper: convert full csv in chunks via LIMIT/OFFSET --------------------

convert_in_chunks <- function(csv_path, output_path, batch_size = 250000) {

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


# helper: clean encoding -------------------------------------------------

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


# main -------------------------------------------------------------------

source("BH_get_filenames.r")

for(filename in filenames_list){
  gz_path <- glue("data/raw/raw_contributions_csv/{filename}.csv.gz")
  csv_path <- glue("data/raw/raw_contributions_csv/{filename}.csv")
  out_path <- glue("data/raw/raw_contributions_parquet/{filename}")

  if(!file.exists(gz_path) & !file.exists(csv_path)){

    stop("File not found, please run B1 first to download the necessary files!")

  } else {

    print("File found, decompressing...")

  }

  decompress(gz_path)

  conversion_ok <- TRUE
 
  tryCatch(
    expr = {
      convert_in_chunks(
        csv_path    = csv_path,
        output_path = out_path,
        batch_size  = 250000
      )
    },
    error = function(e) {
      message("✗ Conversion failed, likely an encoding issue: ", conditionMessage(e))
      conversion_ok <- FALSE
    }
  )
 
  if (!conversion_ok) {
 
    message("Retrying ", filename, " with cleaned encoding...")
 
    # wipe any partial batch_*.parquet files left over from the failed attempt,
    # otherwise the retry's rows get appended on top of a half-finished output dir
    unlink(out_path, recursive = TRUE)
 
    csv_path_clean <- clean_encoding(csv_path, from_encoding = "latin1")
 
    convert_in_chunks(
      csv_path    = csv_path_clean,
      output_path = out_path,
      batch_size  = 250000
    )
 
    message("Removing cleaned file...")
    unlink(csv_path_clean)
    message("✓ ", csv_path_clean, " removed")
  }


  # remove decompressed csv to free disk space
  message("Removing decompressed CSV...")
  unlink(csv_path)
  message("✓ ", csv_path, " removed")

  # # remove compressed csv.gz to free disk space
  # message("Removing compressed csv.gz...")
  # unlink(gz_path)
  # message("✓ ", gz_path, " removed")
}

# --- cleanup ----------------------------------------------------------------

dbDisconnect(con, shutdown = TRUE)
unlink("tmp", recursive = TRUE)

message("Done. Files written to ", out_path)
