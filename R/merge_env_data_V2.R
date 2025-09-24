# ---------------------------------------------- #
# Environmental covariates: Chunked merge (0.125°)
# ---------------------------------------------- #

rm(list = ls()); gc()

library(data.table)
library(lubridate)


#-----------------------------
# Load datasets
#-----------------------------
usuario <- Sys.info()[["user"]]
dirdata <- paste0("C:/Users/", usuario, "/OneDrive - Universidad de Concepción/FONDECYT Iniciacion/Data/")

glo_dt <- readRDS("data/env/glorysDaily_2012_2025.rds")    # 0.083° ~ finer than wind
chl_dt <- readRDS("data/env/chlDaily_2012_2025.rds")       # 4 km ~ finest
win_dt <- readRDS("data/env/WindDaily_2012_2025.rds")      # 0.125° ~ coarsest (10km ap)

# -------- Settings --------
coarse_res <- 0.125
out_file   <- "data/env/env_panel_0.125deg_daily_2012_2025.rds"

# -------- Helpers --------

# lightweight coercion + keep only required columns
.keep_and_normalize <- function(dt, keep_cols) {
  setDT(dt)
  # force date to IDate for smaller footprint
  if (!inherits(dt$date, "IDate")) dt[, date := as.IDate(date)]
  # drop everything else to cut RAM
  keep_cols <- intersect(keep_cols, names(dt))
  dt[, ..keep_cols]
}

# add coarse grid columns (computed once per chunk)
.add_coarse <- function(dtm, res = 0.125) {
  dtm[, lon_coarse := floor(lon / res) * res + res/2]
  dtm[, lat_coarse := floor(lat / res) * res + res/2]
}

# month-by-month aggregator to 0.125° by lon,lat,date
agg_month_to_coarse <- function(dtm, var_cols, res = 0.125) {
  .add_coarse(dtm, res)
  # group only by lon/lat/date (year & month implied by date)
  out <- dtm[
    , c(
      list(lon = unique(lon_coarse),
           lat = unique(lat_coarse),
           date = unique(date)),
      lapply(.SD, mean, na.rm = TRUE)
    ),
    by = .(lon_coarse, lat_coarse, date),
    .SDcols = var_cols
  ][, .(lon, lat, date, .SD), .SDcols = var_cols]
  out[]
}

# a generic chunked aggregator for any source table
aggregate_chunked <- function(dt, var_cols, label, res = 0.125) {
  message(">>> Aggregating ", label, " ...")
  dt <- .keep_and_normalize(dt, c("lon", "lat", "date", var_cols))
  dt[, ym := as.IDate(paste0(year(date), "-", month(date), "-01"))]
  months <- sort(unique(dt$ym))
  
  res_list <- vector("list", length(months))
  for (i in seq_along(months)) {
    m <- months[i]
    message(sprintf("[%s] %d/%d", as.character(m), i, length(months)))
    dtm <- dt[ym == m, .(lon, lat, date, .SD), .SDcols = var_cols]
    res_list[[i]] <- agg_month_to_coarse(dtm, var_cols, res)
    rm(dtm); gc(verbose = FALSE)
  }
  ans <- rbindlist(res_list, use.names = TRUE)
  setkey(ans, lon, lat, date)
  message("<<< Done ", label, ": ", format(nrow(ans), big.mark = ","), " rows")
  ans
}

# -------- Variable selection (robust to name differences) --------

# GLORYS typical vars
glo_vars <- intersect(names(glo_dt), c("sst", "so", "current_speed", "current_direction"))
# CHL typical var
chl_vars <- intersect(names(chl_dt), c("chl"))

# WIND typical vars (be flexible: pick what exists)
win_vars <- intersect(names(win_dt), c("speed_mean", "speed_min", "speed_max",
                                       "dir_mean", "dir_min", "dir_max"))

stopifnot(length(glo_vars) > 0, length(chl_vars) > 0, length(win_vars) > 0)

# -------- Aggregate each dataset (chunked) --------
glo_agg <- aggregate_chunked(glo_dt, glo_vars, "GLORYS", res = coarse_res)
chl_agg <- aggregate_chunked(chl_dt, chl_vars, "CHL",    res = coarse_res)
win_agg <- aggregate_chunked(win_dt, win_vars, "WIND",   res = coarse_res)

# -------- Merge all on lon, lat, date --------
env_panel <- Reduce(
  function(x, y) merge(x, y, by = c("lon","lat","date"), all = TRUE),
  list(glo_agg, chl_agg, win_agg)
)
setkey(env_panel, lon, lat, date)

# Optional: sanity checks
message("Merged rows: ", format(nrow(env_panel), big.mark = ","))
message("Columns: ", paste(names(env_panel), collapse = ", "))

# -------- Save --------
dir.create(dirname(out_file), recursive = TRUE, showWarnings = FALSE)
saveRDS(env_panel, out_file)
message("Saved: ", out_file)

# Tip: if the result is still too large for RAM later,
# you can write monthly files instead of one big RDS:
# for (m in unique(env_panel[, as.IDate(paste0(year(date), "-", month(date), "-01"))])) {
#   saveRDS(env_panel[date >= m & date < (m %m+ months(1))],
#           sprintf("data/env/env_panel_%s.rds", format(m, "%Y-%m")))
# }
