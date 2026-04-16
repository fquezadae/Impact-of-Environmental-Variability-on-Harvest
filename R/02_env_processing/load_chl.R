###-----------------------------------------###
###   Environmental covariates: Chlorophyll ### 
###-----------------------------------------###

library(dplyr)
library(ncdf4)
library(data.table)
library(lubridate)

usuario <- Sys.info()[["user"]]
dirdata <- paste0("C:/Users/", paste0(usuario, "/OneDrive - Universidad de Concepción/FONDECYT Iniciacion/Data/"))
f <- paste0(dirdata, "Environmental/cmems_obs-oc_glo_bgc-plankton_my_l4-gapfree-multi-4km_P1D_CHL_80.98W-71.52W_41.98S-32.02S_2012-01-01-2025-08-20.nc")
  
nc <- ncdf4::nc_open(f)

## Dimensions ##
lon <- ncvar_get(nc, "longitude")
lat <- ncvar_get(nc, "latitude")
tim <- ncvar_get(nc, "time")

## Vars ##
var_names <- names(nc$var)
chl <- ncvar_get(nc, "CHL")

ncdf4::nc_close(nc)

dimnames(chl)  <- list(lon = lon, lat = lat, time = tim)
dt <- as.data.table(data.table::melt(chl, value.name = "chl"))
setnames(dt, c("lon", "lat", "time", "chl"))
dt[, date := as.Date("1900-01-01") + time]
dt[, time := NULL]
dt[, `:=`(
  year  = year(date),
  month = month(date)
)]

saveRDS(dt, file = "data/env/chlDaily_2012_2025.rds")

