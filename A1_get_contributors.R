# 1_get_DIME_data.R
# creates and calls a function to get two databases from https://data.stanford.edu/dime 
# saves it in /data/raw/

# check dependencies -----------------------------------------------------

library(arrow)
library(here)
library(duckdb)
library(dbplyr)
library(dplyr)


# helper functions -------------------------------------------------------

#' Download DIME data if not already present
#'
#' @param data_dir Path to directory where data should be stored
#' @param url URL to download from
#' @param filename Name of the file to save (with extension)
#'
#' @return Invisibly returns TRUE
#'
download_data <- function(
    data_dir = "data/raw",
    url,
    filename) {
  
  file_path <- file.path(data_dir, filename)

  # Check if file already exists
  if (file.exists(file_path)) {
    message("Data file already exists at: ", file_path)
    return(invisible(TRUE))
  }
  
  # Create directory if it doesn't exist
  if (!dir.exists(data_dir)) {
    dir.create(data_dir, recursive = TRUE)
  }
  
  message("Downloading DIME data from: ", url)
  message("Saving to: ", file_path)
  
  # Download the file
  tryCatch(
    expr = {
      # Use system curl directly—handles Dropbox redirects better than R's download.file()
      status <- system(paste("curl -L -o", shQuote(file_path), shQuote(url)))
      if (status != 0) stop("curl exited with status ", status)
      message("Download completed successfully!")
      invisible(TRUE)
    },
    error = function(e) {
      stop("Failed to download file: ", conditionMessage(e))
    }
  )
}


# get the data from the website ------------------------------------------

## download all contributors
download_data(
  url = "https://www.dropbox.com/scl/fi/c5z45dm2g8u9ihfi7uce8/dime_contributors_1979_2024.csv.gz?rlkey=janwvetndyxe4t8tm2v5a6wbu&dl=1",
  filename = "dime_contributors_1979_2024.csv.gz"
)

# ## download all data from 2016
# download_data(
#   url = "https://www.dropbox.com/scl/fi/qg5vezrx876cmu7u9hehr/contribDB_2016.csv.gz?rlkey=dsl4htd0ovr8hyn7xwctel0a0&dl=1",
#   filename = "contribDB_2016.csv.gz"
# )