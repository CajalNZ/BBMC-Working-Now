#!/usr/bin/env Rscript

.libPaths(c("R_libs", .libPaths()))
suppressPackageStartupMessages({
  library(plumber)
})

pr <- plumber::plumb("egfr_slope_api.R")
port <- as.integer(Sys.getenv("PORT", "8787"))
pr$run(host = "0.0.0.0", port = port)
