###-----------------------------------###
###   Environmental covariates: Wind  ### 
###-----------------------------------###

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

ncdf4::nc_close(nc)

dimnames(ua)  <- list(lon = lon, lat = lat, time = tim)
ua_dt <- as.data.table(data.table::melt(so, value.name = "so"))
setnames(so_dt, c("lon", "lat", "depth", "time", "so"))
ua_dt[, date := as.Date("1950-01-01") + time / 24]
ua_dt[, time := NULL]

dimnames(sst)  <- list(lon = lon, lat = lat, time = tim)
sst_dt <- as.data.table(data.table::melt(sst, value.name = "sst"))
setnames(sst_dt, c("lon", "lat", "depth", "time", "sst"))
sst_dt[, date := as.Date("1950-01-01") + time / 24]
sst_dt[, time := NULL]

dimnames(uo)  <- list(lon = lon, lat = lat, dep = dep, time = tim)
uo_dt <- as.data.table(data.table::melt(uo, value.name = "uo"))
setnames(uo_dt, c("lon", "lat", "depth", "time", "uo"))
uo_dt[, date := as.Date("1950-01-01") + time / 24]
uo_dt[, time := NULL]

dimnames(vo)  <- list(lon = lon, lat = lat, dep = dep, time = tim)
vo_dt <- as.data.table(data.table::melt(vo, value.name = "vo"))
setnames(vo_dt, c("lon", "lat", "depth", "time", "vo"))
vo_dt[, date := as.Date("1950-01-01") + time / 24]
vo_dt[, time := NULL]


dt <- Reduce(function(x, y) merge(x, y, by = c("lon", "lat", "depth", "date")),
             list(so_dt, sst_dt, uo_dt, vo_dt)) %>% 
  filter(depth < 1) %>%
  mutate(current_speed = sqrt(uo^2 + vo^2),
         current_direction = atan2(vo, uo) * 180 / pi) %>% 
  select(-c("depth", "uo", "vo")) 


dt[, `:=`(
  year  = year(date),
  month = month(date)
)]

saveRDS(dt, file = "data/env/WindDaily_2012_2025.rds")

