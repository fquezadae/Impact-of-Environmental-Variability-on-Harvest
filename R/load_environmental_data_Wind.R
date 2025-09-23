###-----------------------------------###
###   Environmental covariates: Wind  ### 
###-----------------------------------###

rm(list = ls())
gc()

library(dplyr)
library(ncdf4)
library(data.table)
library(lubridate)

usuario <- Sys.info()[["user"]]
dirdata <- paste0("C:/Users/", paste0(usuario, "/OneDrive - Universidad de Concepción/FONDECYT Iniciacion/Data/"))
f <- paste0(dirdata, "Environmental/cmems_obs-wind_glo_phy_my_l4_0.125deg_PT1H_multi-vars_80.94W-71.56W_41.94S-32.06S_2012-01-01-2025-04-19.nc")

# --- Open file
nc <- nc_open(f)

lon <- ncvar_get(nc, "longitude")
lat <- ncvar_get(nc, "latitude")
tim <- ncvar_get(nc, "time")  # seconds since 1990-01-01

ua <- ncvar_get(nc, "eastward_wind")   # [lon, lat, time]
va <- ncvar_get(nc, "northward_wind")

time_units <- ncatt_get(nc, "time", "units")$value
nc_close(nc)

# --- Convert time
origin_str <- sub("seconds since ", "", time_units)
dates <- as.Date(as.POSIXct(tim, origin = origin_str, tz="UTC"))

# --- Expand to vectors
grid <- CJ(lon=lon, lat=lat, time=seq_along(tim))   # fast cross join
grid[, date := dates[time]]

# Fill values
grid[, ua := as.vector(ua)]
grid[, va := as.vector(va)]

gc()
# --- Compute derived vars
grid[, speed := sqrt(ua^2 + va^2)]
grid[, direction := atan2(ua, va) * 180/pi]
grid[direction < 0, direction := direction + 360]

gc()

# --- Daily aggregation
wind_dt <- grid[, .(
  ua_mean  = mean(ua, na.rm=TRUE),
  ua_min   = min(ua, na.rm=TRUE),
  ua_max   = max(ua, na.rm=TRUE),
  va_mean  = mean(va, na.rm=TRUE),
  va_min   = min(va, na.rm=TRUE),
  va_max   = max(va, na.rm=TRUE),
  speed_mean = mean(speed, na.rm=TRUE),
  speed_min  = min(speed, na.rm=TRUE),
  speed_max  = max(speed, na.rm=TRUE),
  # circular mean of direction:
  dir_mean = atan2(mean(sin(direction*pi/180), na.rm=TRUE),
                   mean(cos(direction*pi/180), na.rm=TRUE)) * 180/pi,
  dir_min  = min(direction, na.rm=TRUE),
  dir_max  = max(direction, na.rm=TRUE)
), by=.(lon, lat, date)]

# Normalize circular mean to [0,360)
wind_dt[dir_mean < 0, dir_mean := dir_mean + 360]

# --- Add year/month
wind_dt[, year  := year(date)]
wind_dt[, month := month(date)]


saveRDS(wind_dt, file = "data/env/WindDaily_2012_2025.rds")

