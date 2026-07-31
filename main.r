############################################################
# main.r for data reproduction
#
# This script reinstalls the data from scratch, exports it to parquet and computes QOIs on a sample of 250000
# observations. It should not delete valuable old data, though this might happen.
#############################################################

# change this flag to FALSE in order to compute the whole dataset. Tweak the memory settings in A3 before doing so, it might save a lot of time

run_on_sample <- TRUE 

# it might be good to create a function in order to see which of the
# necessary files for the analysis are already created and which have
# to be created on scratch

# execution of the files in order

message("Running A1)")

source("A1_get_contributors.R")

message("Running A2)")

source("A2_transform_to_parquet_contributors.r")

message("Running A3)")

source("A3_prep_contributors.r")

message("Running E1)")

source("E1_explore_descriptive.R")

message("Running E2)")

source("E2_inferential.R")
