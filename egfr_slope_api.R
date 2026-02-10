#!/usr/bin/env Rscript

.libPaths(c("R_libs", .libPaths()))
suppressPackageStartupMessages({
  library(plumber)
  library(jsonlite)
})

source("Compute_Slope.R")

#* @filter cors
function(req, res) {
  res$setHeader("Access-Control-Allow-Origin", "*")
  res$setHeader("Access-Control-Allow-Methods", "POST, OPTIONS")
  res$setHeader("Access-Control-Allow-Headers", "Content-Type")
  if (req$REQUEST_METHOD == "OPTIONS") {
    res$status <- 200
    return(list())
  }
  plumber::forward()
}

parse_points <- function(points) {
  if (is.null(points) || length(points) < 1) return(data.frame())
  # jsonlite::fromJSON may return a data.frame for points
  if (is.data.frame(points)) {
    if (!all(c("date", "egfr") %in% names(points))) return(data.frame())
    df <- data.frame(
      date = as.Date(points$date),
      egfr = as.numeric(points$egfr)
    )
  } else if (is.list(points)) {
    # handle list of lists or list of named vectors
    get_field <- function(p, field) {
      if (is.list(p) && !is.null(p[[field]])) return(p[[field]])
      if (!is.null(names(p)) && field %in% names(p)) return(p[[field]])
      return(NA)
    }
    df <- data.frame(
      date = as.Date(sapply(points, function(p) get_field(p, "date"))),
      egfr = as.numeric(sapply(points, function(p) get_field(p, "egfr")))
    )
  } else {
    return(data.frame())
  }
  df <- df[order(df$date), ]
  df <- df[!is.na(df$date) & is.finite(df$egfr), ]
  df
}

compute_chronic_slope <- function(df, knot_days = 90) {
  if (nrow(df) < 3) return(list(error = "need_points"))
  span_days <- as.numeric(max(df$date) - min(df$date))
  if (span_days < 183) return(list(error = "need_span"))

  t0 <- min(df$date)
  time_years <- as.numeric(df$date - t0) / 365.25
  knot_years <- knot_days / 365.25
  spline <- pmax(time_years - knot_years, 0)

  fit <- lm(df$egfr ~ time_years + spline)
  coefs <- coef(fit)
  slope <- coefs[["time_years"]]
  if (!is.na(coefs[["spline"]])) slope <- slope + coefs[["spline"]]

  list(
    slope = as.numeric(slope),
    last_date = max(df$date),
    last_egfr = df$egfr[which.max(df$date)],
    knot_days = knot_days
  )
}

estimate_date_to_egfr10 <- function(last_date, last_egfr, slope_per_year) {
  if (!is.finite(slope_per_year)) return(list(status = "invalid"))
  if (last_egfr <= 10) return(list(status = "already"))
  if (slope_per_year >= 0) return(list(status = "not_declining"))
  years_to <- (10 - last_egfr) / slope_per_year
  if (!is.finite(years_to) || years_to < 0) return(list(status = "invalid"))
  date <- as.Date(last_date + years_to * 365.25)
  list(status = "ok", date = as.character(date))
}

get_empagliflozin_reduction_pct <- function(is_diab, acr_mgmmol) {
  acr_high <- acr_mgmmol >= 20
  if (is_diab && !acr_high) return(54)
  if (is_diab && acr_high) return(57)
  if (!is_diab && !acr_high) return(57)
  return(39)
}

#* @post /egfr-slope
#* @parser json
function(req, res) {
  body <- jsonlite::fromJSON(req$postBody)
  points <- body$points
  acr <- as.numeric(body$acr)
  is_diab <- isTRUE(body$diabetes)
  on_sglt2 <- isTRUE(body$on_sglt2)
  knot_days <- if (!is.null(body$knot_days)) as.numeric(body$knot_days) else 90

  df <- parse_points(points)
  result <- compute_chronic_slope(df, knot_days = knot_days)

  if (!is.null(result$error)) {
    return(list(ok = FALSE, error = result$error))
  }

  slope <- result$slope
  base_est <- estimate_date_to_egfr10(result$last_date, result$last_egfr, slope)

  adj_est <- list(status = "na")
  if (slope < 0) {
    reduction <- get_empagliflozin_reduction_pct(is_diab, acr)
    slope_adj <- slope * (1 - reduction/100)
    adj_est <- estimate_date_to_egfr10(result$last_date, result$last_egfr, slope_adj)
    adj_est$reduction_pct <- reduction
    adj_est$slope_adj <- slope_adj
  }

  list(
    ok = TRUE,
    slope = slope,
    last_date = as.character(result$last_date),
    last_egfr = result$last_egfr,
    knot_days = result$knot_days,
    date_to_egfr10 = base_est,
    date_to_egfr10_sglt2 = adj_est,
    on_sglt2 = on_sglt2
  )
}
