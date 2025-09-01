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
f <- paste0(dirdata, "Environmental/cmems_obs-wind_glo_phy_my_l4_0.125deg_PT1H_multi-vars_77.94W-71.56W_41.94S-32.06S_2012-01-01-2025-04-19.nc")


## Open NCDF4 file

nc <- ncdf4::nc_open(f)

## Dimensions ##
lon <- ncvar_get(nc, "longitude")
lat <- ncvar_get(nc, "latitude")
tim <- ncvar_get(nc, "time")

## Vars ##
var_names <- names(nc$var)
ua <- ncvar_get(nc, "eastward_wind")
va <- ncvar_get(nc, "northward_wind")

ncatt_get(nc, "time", "units")
ncdf4::nc_close(nc)

# --- Convert hours → day index


library(ncdf4)
library(data.table)

# --- Open file
nc <- nc_open(f)

lon <- ncvar_get(nc, "longitude")
lat <- ncvar_get(nc, "latitude")
tim <- ncvar_get(nc, "time")  # seconds since 1990-01-01

ua <- ncvar_get(nc, "eastward_wind")   # [lon, lat, time]
va <- ncvar_get(nc, "northward_wind")

time_units <- ncatt_get(nc, "time", "units")$value
nc_close(nc)

# --- Time conversion
dates <- as.Date(as.POSIXct(tim, origin = "1990-01-01", tz = "UTC"))
day_index <- as.integer(dates - min(dates))
unique_dates <- unique(dates)

# --- Compute wind speed + direction
wind_speed <- sqrt(ua^2 + va^2)
wind_direction <- atan2(ua, va) * 180/pi
wind_direction[wind_direction < 0] <- wind_direction[wind_direction < 0] + 360

# --- Function for daily stats
day_stats <- function(x, idx) {
  tapply(x, idx, function(v) c(mean=mean(v, na.rm=TRUE),
                               min=min(v, na.rm=TRUE),
                               max=max(v, na.rm=TRUE)))
}

# --- Aggregate daily
wind_speed_day <- apply(wind_speed, c(1,2), day_stats, idx=day_index)
wind_speed_day <- aperm(wind_speed_day, c(1,2,4,3))
dimnames(wind_speed_day) <- list(lon=lon, lat=lat, date=unique_dates,
                            stat=c("mean","min","max"))

wind_direction_day <- apply(wind_direction, c(1,2), day_stats, idx=day_index)
wind_direction_day <- aperm(wind_direction_day, c(1,2,4,3))
dimnames(wind_direction_day) <- list(lon=lon, lat=lat, date=unique_dates,
                                stat=c("mean","min","max"))

# --- Convert to data.table
speed_dt <- as.data.table(reshape2::melt(wind_speed_day, value.name="wind_speed"))
speed_dt <- dcast(speed_dt, lon + lat + date ~ stat, value.var="wind_speed")
setnames(speed_dt, c("mean","min","max"), c("wind_speed_mean","wind_speed_min","wind_speed_max"))

direction_dt <- as.data.table(reshape2::melt(wind_direction_day, value.name="wind_direction"))
direction_dt <- dcast(direction_dt, lon + lat + date ~ stat, value.var="wind_direction")
setnames(direction_dt, c("mean","min","max"),
         c("wind_dir_mean","wind_dir_min","wind_dir_max"))

# --- Merge
wind_dt <- merge(speed_dt, direction_dt, by=c("lon","lat","date"))

# --- Add year & month
wind_dt[, year  := year(date)]
wind_dt[, month := month(date)]

saveRDS(dt, file = "data/env/WindDaily_2012_2025.rds")

