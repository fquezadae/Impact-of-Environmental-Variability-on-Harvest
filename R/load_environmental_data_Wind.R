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
ua_dt <- as.data.table(data.table::melt(ua, value.name = "ua"))
setnames(ua_dt, c("lon", "lat", "time", "ua"))
ua_dt[, date := as.Date("1950-01-01") + time / 24]
ua_dt[, time := NULL]

dimnames(va)  <- list(lon = lon, lat = lat, time = tim)
va_dt <- as.data.table(data.table::melt(va, value.name = "va"))
setnames(va_dt, c("lon", "lat", "time", "va"))
va_dt[, date := as.Date("1950-01-01") + time / 24]
va_dt[, time := NULL]

dt <- Reduce(function(x, y) merge(x, y, by = c("lon", "lat", "date")),
             list(ua_dt, va_dt))


%>% 
  filter(depth < 1) %>%
  mutate(current_speed = sqrt(uo^2 + vo^2),
         current_direction = atan2(vo, uo) * 180 / pi) %>% 
  select(-c("depth", "uo", "vo")) 


dt[, `:=`(
  year  = year(date),
  month = month(date)
)]

saveRDS(dt, file = "data/env/WindDaily_2012_2025.rds")

