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

dates <- as.Date(as.POSIXct(tim, origin = "1990-01-01", tz = "UTC"))
day_index <- as.integer(dates - min(dates))
unique_dates <- unique(dates)


# --- Function to compute mean/min/max
day_stats <- function(x, idx) {
  tapply(x, idx, function(v) c(mean=mean(v, na.rm=TRUE),
                               min=min(v, na.rm=TRUE),
                               max=max(v, na.rm=TRUE)))
}

# --- Eastward (ua)
ua_day <- apply(ua, c(1,2), day_stats, idx=day_index)  # [lon,lat,stat,day]
ua_day <- aperm(ua_day, c(1,2,4,3))
dimnames(ua_day) <- list(lon=lon, lat=lat, date=unique_dates,
                         stat=c("mean","min","max"))

# --- Northward (va)
va_day <- apply(va, c(1,2), day_stats, idx=day_index)
va_day <- aperm(va_day, c(1,2,4,3))
dimnames(va_day) <- list(lon=lon, lat=lat, date=unique_dates,
                         stat=c("mean","min","max"))

# --- Convert to data.table (wide format)
ua_dt <- as.data.table(reshape2::melt(ua_day, value.name="ua"))
va_dt <- as.data.table(reshape2::melt(va_day, value.name="va"))


# Cast wide: each stat becomes a column
ua_dt <- dcast(ua_dt, lon + lat + date ~ stat, value.var="ua", fun.aggregate=mean)
setnames(ua_dt, c("mean","min","max"), c("ua_mean","ua_min","ua_max"))

va_dt <- dcast(va_dt, lon + lat + date ~ stat, value.var="va", fun.aggregate=mean)
setnames(va_dt, c("mean","min","max"), c("va_mean","va_min","va_max"))

# --- Merge eastward + northward
wind_dt <- merge(ua_dt, va_dt, by=c("lon","lat","date"))


# %>% 
#   filter(depth < 1) %>%
#   mutate(current_speed = sqrt(uo^2 + vo^2),
#          current_direction = atan2(vo, uo) * 180 / pi) %>% 
#   select(-c("depth", "uo", "vo")) 
# dt[, `:=`(
#   year  = year(date),
#   month = month(date)
# )]
# 
# saveRDS(dt, file = "data/env/WindDaily_2012_2025.rds")

