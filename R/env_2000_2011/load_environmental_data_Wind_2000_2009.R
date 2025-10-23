###-----------------------------------###
###   Environmental covariates: Wind  ### 
###-----------------------------------###

rm(list = ls())
gc()

library(dplyr)
library(ncdf4)
library(data.table)
library(lubridate)
library(future.apply)   # para paralelizar

# Configurar plan de paralelización (ajusta "multisession" o "multicore" según tu SO)
plan(multisession, workers = parallel::detectCores() - 2)

usuario <- Sys.info()[["user"]]
dirdata <- paste0("C:/Users/", paste0(usuario, "/OneDrive - Universidad de Concepción/FONDECYT Iniciacion/Data/"))
f <- paste0(dirdata, "Environmental/2000-2011/cmems_obs-wind_glo_phy_my_l4_0.25deg_PT1H_multi-vars_80.88W-71.62W_41.88S-32.12S_2000-01-01-2009-10-31.nc")

# --- Open file (solo para dimensiones y tiempo)
nc <- nc_open(f)

lon <- ncvar_get(nc, "longitude")
lat <- ncvar_get(nc, "latitude")
tim <- ncvar_get(nc, "time")  # seconds since 1990-01-01
time_units <- ncatt_get(nc, "time", "units")$value
origin_str <- sub("seconds since ", "", time_units)
dates <- as.Date(as.POSIXct(tim, origin = origin_str, tz="UTC"))

nT <- length(tim)
block_size <- 24 * 30   # ~1 mes de datos horarios
nBlocks <- ceiling(nT / block_size)

nc_close(nc)  # cierro aquí, cada proceso abrirá su propio handler

# --- Función para procesar un bloque
process_block <- function(b) {
  nc <- nc_open(f)
  on.exit(nc_close(nc))
  
  start <- (b - 1) * block_size + 1
  count <- min(block_size, nT - start + 1)
  
  # leer solo bloque
  ua <- ncvar_get(nc, "eastward_wind", start = c(1,1,start), count = c(-1,-1,count))
  va <- ncvar_get(nc, "northward_wind", start = c(1,1,start), count = c(-1,-1,count))
  
  # calcular magnitudes
  spd <- sqrt(ua^2 + va^2)
  dir <- atan2(ua, va) * 180/pi
  dir[dir < 0] <- dir[dir < 0] + 360
  
  # aplanar a data.table
  dt <- data.table(
    lon = rep(lon, each = length(lat) * count),
    lat = rep(rep(lat, each = count), times = length(lon)),
    date = rep(dates[start:(start+count-1)], times = length(lon) * length(lat)),
    ua = as.vector(ua),
    va = as.vector(va),
    speed = as.vector(spd),
    direction = as.vector(dir)
  )
  
  # daily aggregation por pixel
  dt_daily <- dt[, .(
    ua_mean  = mean(ua, na.rm=TRUE),
    ua_min   = min(ua, na.rm=TRUE),
    ua_max   = max(ua, na.rm=TRUE),
    va_mean  = mean(va, na.rm=TRUE),
    va_min   = min(va, na.rm=TRUE),
    va_max   = max(va, na.rm=TRUE),
    speed_mean = mean(speed, na.rm=TRUE),
    speed_min  = min(speed, na.rm=TRUE),
    speed_max  = max(speed, na.rm=TRUE),
    dir_mean = atan2(mean(sin(direction*pi/180), na.rm=TRUE),
                     mean(cos(direction*pi/180), na.rm=TRUE)) * 180/pi,
    dir_min  = min(direction, na.rm=TRUE),
    dir_max  = max(direction, na.rm=TRUE)
  ), by=.(lon, lat, date)]
  
  dt_daily[dir_mean < 0, dir_mean := dir_mean + 360]
  
  return(dt_daily)
}

# --- Procesar en paralelo
wind_list <- future_lapply(seq_len(nBlocks), process_block)
wind_dt <- rbindlist(wind_list)

# --- Add year/month
wind_dt[, year  := year(date)]
wind_dt[, month := month(date)]

saveRDS(wind_dt, file = "data/env/2000-2011/WindDaily_2000_2009.rds")

plan(sequential)  # volver al plan normal
